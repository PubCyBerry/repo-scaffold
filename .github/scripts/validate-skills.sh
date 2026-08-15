#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Validate every skill under skills/ against the repository contract.
#
# Checks, per skills/<dir>/:
#   1. SKILL.md exists and opens with a parseable YAML frontmatter block.
#   2. frontmatter.name == <dir>, and is kebab-case.
#   3. Required frontmatter fields are present and non-empty:
#        name, description, license,
#        metadata.kind, metadata.language, metadata.group, metadata.summary
#   4. description is at most DESCRIPTION_MAX characters (counted in
#      codepoints via jq, not bytes — the frontmatter is bilingual).
#   5. skill-card.md exists.
#   6. An eval task set exists and parses: evals/*.json, eval/*.json,
#      benchmark/evals.json, or any evals.json inside the skill dir.
#   7. The task set declares skill_name == <dir>, has a non-empty evals
#      list, every entry carries id/prompt/expected_skill/assertions, and
#      at least one entry is a negative case (expected_skill: null).
#      A task set with no negative case cannot detect over-triggering,
#      which is the failure mode that actually costs users context.
#   8. Every tests/*.sh parses under `bash -n`.
#
# Exit 0 when every skill passes; 1 with a per-failure report otherwise.
#
# Dependencies: bash, yq (mikefarah v4), jq, git.

set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

SKILLS_DIR="${SKILLS_DIR:-skills}"
DESCRIPTION_MAX="${DESCRIPTION_MAX:-1024}"

REQUIRED_FIELDS=(
  ".name"
  ".description"
  ".license"
  ".metadata.kind"
  ".metadata.language"
  ".metadata.group"
  ".metadata.summary"
)

failures=0
checked=0

fail() {
  printf '  ✗ %s\n' "$1"
  failures=$((failures + 1))
}

# Emit the YAML frontmatter block of a Markdown file on stdout.
# Returns non-zero when the file does not open with a `---` fence.
frontmatter() {
  awk '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit 1 }
    NR == 1 { next }
    /^---[[:space:]]*$/ { found = 1; exit }
    { print }
    END { if (!found) exit 1 }
  ' "$1"
}

# Codepoint length of stdin. jq counts unicode characters; wc -m depends
# on the locale and mawk's length() counts bytes, so neither is portable
# between a Git Bash workstation and an ubuntu-latest runner.
charlen() {
  tr '\n' ' ' | jq -Rs 'length'
}

# Locate a skill's eval task set. Mirrors the locations the catalog sync
# accepts, so a skill that passes here is never dropped for layout.
find_eval_file() {
  local dir="$1" f
  for f in "$dir"/evals/*.json "$dir"/eval/*.json "$dir"/benchmark/evals.json; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  f=$(find "$dir" -type f -name evals.json -print -quit 2>/dev/null)
  [ -n "$f" ] && { printf '%s\n' "$f"; return 0; }
  return 1
}

if [ ! -d "$SKILLS_DIR" ]; then
  echo "error: $SKILLS_DIR/ not found" >&2
  exit 1
fi

shopt -s nullglob
skill_dirs=("$SKILLS_DIR"/*/)
shopt -u nullglob

if [ ${#skill_dirs[@]} -eq 0 ]; then
  echo "error: no skills found under $SKILLS_DIR/" >&2
  exit 1
fi

for dir in "${skill_dirs[@]}"; do
  dir="${dir%/}"
  name=$(basename "$dir")
  checked=$((checked + 1))
  before=$failures

  echo "── $name"

  # 1. SKILL.md + frontmatter
  if [ ! -f "$dir/SKILL.md" ]; then
    fail "$dir/SKILL.md is missing"
    continue
  fi

  fm=$(frontmatter "$dir/SKILL.md")
  if [ $? -ne 0 ] || [ -z "$fm" ]; then
    fail "$dir/SKILL.md has no closing YAML frontmatter block"
    continue
  fi

  if ! printf '%s\n' "$fm" | yq e 'true' >/dev/null 2>&1; then
    fail "$dir/SKILL.md frontmatter is not valid YAML"
    continue
  fi

  # 2. name matches the directory, and is kebab-case
  fm_name=$(printf '%s\n' "$fm" | yq -r '.name // ""')
  if [ "$fm_name" != "$name" ]; then
    fail "frontmatter name '$fm_name' does not match directory '$name'"
  fi
  if ! printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    fail "skill name '$name' is not kebab-case"
  fi

  # 3. required fields
  for field in "${REQUIRED_FIELDS[@]}"; do
    value=$(printf '%s\n' "$fm" | yq -r "$field // \"\"")
    if [ -z "$value" ] || [ "$value" = "null" ]; then
      fail "frontmatter is missing ${field#.}"
    fi
  done

  # 4. description length
  description=$(printf '%s\n' "$fm" | yq -r '.description // ""')
  if [ -n "$description" ]; then
    length=$(printf '%s' "$description" | charlen)
    if [ "$length" -gt "$DESCRIPTION_MAX" ]; then
      fail "description is $length characters (max $DESCRIPTION_MAX)"
    fi
  fi

  # 5. skill card
  [ -f "$dir/skill-card.md" ] || fail "$dir/skill-card.md is missing"

  # 6 + 7. eval task set
  if ! eval_file=$(find_eval_file "$dir"); then
    fail "no eval task set (expected $dir/evals/evals.json)"
  elif ! jq -e . "$eval_file" >/dev/null 2>&1; then
    fail "$eval_file is not valid JSON"
  else
    eval_name=$(jq -r '.skill_name // ""' "$eval_file")
    [ "$eval_name" = "$name" ] || fail "$eval_file declares skill_name '$eval_name', expected '$name'"

    count=$(jq -r '(.evals // []) | length' "$eval_file")
    if [ "$count" -eq 0 ]; then
      fail "$eval_file has an empty evals list"
    else
      malformed=$(jq -r '
        [ .evals[]
          | select(
              (has("id") | not) or (.id // "" | length == 0)
              or (has("prompt") | not) or (.prompt // "" | length == 0)
              or (has("expected_skill") | not)
              or (has("assertions") | not) or ((.assertions // []) | length == 0)
            )
          | .id // "<no id>"
        ] | join(", ")
      ' "$eval_file")
      [ -z "$malformed" ] || fail "$eval_file has incomplete entries: $malformed"

      negatives=$(jq -r '[ .evals[] | select(.expected_skill == null) ] | length' "$eval_file")
      [ "$negatives" -gt 0 ] || fail "$eval_file has no negative case (expected_skill: null)"
    fi
  fi

  # 8. shipped test scripts parse
  shopt -s nullglob
  for script in "$dir"/tests/*.sh; do
    bash -n "$script" 2>/dev/null || fail "$script has a syntax error"
  done
  shopt -u nullglob

  [ "$failures" -eq "$before" ] && echo "  ✓ ok"
done

# ── Catalog-only: every skills/ dir must be registered or excepted.
# Skipped in a source repo, which has no components.d/. This mirrors
# prune-orphans.sh, but reports instead of deleting — a PR should fail
# here rather than have the sync silently remove the directory later.
if [ -d components.d ]; then
  echo "── catalog registration"
  registered=$(mktemp)
  trap 'rm -f "$registered"' EXIT
  shopt -s nullglob
  for f in components.d/*.yml; do
    yq -r '.skills[]?.catalog_dir // ""' "$f" | grep -v '^$' >> "$registered" || true
  done
  shopt -u nullglob
  if [ -f catalog-exceptions.yml ]; then
    yq -r '.exceptions[]?.dir // ""' catalog-exceptions.yml | grep -v '^$' >> "$registered" || true
  fi

  unregistered=0
  for dir in "${skill_dirs[@]}"; do
    name=$(basename "${dir%/}")
    grep -qxF "$name" "$registered" || {
      fail "skills/$name has no components.d registration and no catalog-exceptions.yml entry"
      unregistered=1
    }
  done
  [ "$unregistered" -eq 0 ] && echo "  ✓ ok"
fi

echo
if [ "$failures" -gt 0 ]; then
  echo "FAIL — $failures problem(s) across $checked skill(s)"
  exit 1
fi
echo "PASS — $checked skill(s)"
