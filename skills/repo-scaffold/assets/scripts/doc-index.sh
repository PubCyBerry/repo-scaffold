#!/usr/bin/env bash
# docs/를 OKF(Open Knowledge Format) 번들로 다룬다. 문서의 front matter를 검사하고,
# 디렉터리마다 index.md를, AGENTS.md에는 문서 색인 블록을 만든다.
# 규칙은 docs/standards/documentation.md에 있다.
#
#   bash scripts/doc-index.sh           # 색인을 다시 만든다
#   bash scripts/doc-index.sh --check   # 고치지 않고 검사만 한다. 어긋나면 종료 코드 1
#
# 의존: bash, find, sort, awk, cmp, tr. git은 쓰지 않는다.

set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
    "") mode="write" ;;
    --check) mode="check" ;;
    *)
        echo "usage: bash scripts/doc-index.sh [--check]" >&2
        exit 2
        ;;
esac

START='<!-- DOC-INDEX:START -->'
END='<!-- DOC-INDEX:END -->'

if [ ! -d docs ] || [ ! -f AGENTS.md ]; then
    echo "FAIL: docs/ and AGENTS.md must both exist" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 정렬 기준을 고정해야 운영체제가 달라도 같은 결과가 나온다.
export LC_ALL=C
find docs -type f -name '*.md' | sort > "$tmp/files"
find docs -type d | while IFS= read -r d; do mkdir -p "$tmp/out/$d"; done

# 1. 문서를 읽어 index.md와 AGENTS.md 블록을 $tmp/out에 만든다.
#    front matter가 어긋난 문서가 하나라도 있으면 아무것도 만들지 않고 실패한다.
OUT="$tmp/out" awk '
    function trim(s) {
        sub(/^[ \t]+/, "", s)
        sub(/[ \t]+$/, "", s)
        return s
    }

    # YAML 한 줄 값. 따옴표를 벗기고, 따옴표가 없으면 줄 끝 주석을 지운다.
    function scalar(s) {
        s = trim(s)
        if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) return substr(s, 2, length(s) - 2)
        sub(/[ \t]+#.*$/, "", s)
        return s
    }

    function fail(path, msg) {
        printf "FAIL: %s: %s\n", path, msg > "/dev/stderr"
        failed = 1
    }

    function parent(p) {
        sub(/\/[^\/]*$/, "", p)
        return p
    }

    function add_dir(d) {
        while (!(d in seen)) {
            seen[d] = 1
            dirs[++ndir] = d
            if (d == "docs") break
            d = parent(d)
        }
    }

    function read_doc(path,    line, n, closed, key) {
        type = title = desc = status = ""
        n = closed = 0
        while ((getline line < path) > 0) {
            sub(/\r$/, "", line)
            if (++n == 1) {
                if (line != "---") break
                continue
            }
            if (line == "---") {
                closed = 1
                break
            }
            if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/)) {
                key = substr(line, 1, RLENGTH - 1)
                line = scalar(substr(line, RLENGTH + 1))
                if (key == "type") type = line
                else if (key == "title") title = line
                else if (key == "description") desc = line
                else if (key == "status") status = line
            }
        }
        close(path)
        if (!closed) {
            fail(path, "missing front matter; start the file with a YAML block opened by ---")
            return
        }
        if (type == "") fail(path, "missing type")
        if (title == "") fail(path, "missing title")
        if (desc == "") fail(path, "missing description")
        if (title ~ /^[>|]/ || desc ~ /^[>|]/) fail(path, "title and description must each fit on one line")
    }

    # 삽입 정렬. 디렉터리 하나에 든 문서 수가 적어서 충분하다.
    function sort_dirs(    i, j, t) {
        for (i = 2; i <= ndir; i++) {
            t = dirs[i]
            for (j = i - 1; j >= 1 && dirs[j] > t; j--) dirs[j + 1] = dirs[j]
            dirs[j + 1] = t
        }
    }

    function sort_names(d,    i, j, t) {
        for (i = 2; i <= nname[d]; i++) {
            t = name[d, i]
            for (j = i - 1; j >= 1 && name[d, j] > t; j--) name[d, j + 1] = name[d, j]
            name[d, j + 1] = t
        }
    }

    BEGIN { add_dir("docs") }

    {
        path = $0
        base = path
        sub(/^.*\//, "", base)
        dir = parent(path)
        add_dir(dir)
        # index.md는 이 스크립트가 만든다. log.md는 OKF 예약 파일이라 front matter가 없다.
        if (base == "index.md") next
        name[dir, ++nname[dir]] = base
        if (base == "log.md") next
        read_doc(path)
        nc++
        cdir[nc] = dir
        cbase[nc] = base
        ctitle[nc] = title
        cdesc[nc] = desc
        cstatus[nc] = status
    }

    END {
        if (failed) exit 1
        sort_dirs()

        # index.md는 그 디렉터리 아래 문서 전체를 디렉터리별 절로 나눠 나열한다.
        for (i = 1; i <= ndir; i++) {
            d = dirs[i]
            f = ENVIRON["OUT"] "/" d "/index.md"
            # OKF는 번들 루트 index.md에만 front matter(버전 선언)를 허용한다.
            if (d == "docs") printf "---\nokf_version: \"0.2\"\n---\n\n" > f
            print "<!-- scripts/doc-index.sh가 만든다. 손으로 고치지 않는다. -->" > f
            listed = 0
            for (j = 1; j <= ndir; j++) {
                s = dirs[j]
                if (s != d && index(s, d "/") != 1) continue
                prefix = (s == d) ? "" : substr(s, length(d) + 2) "/"
                heading = 0
                for (k = 1; k <= nc; k++) {
                    if (cdir[k] != s) continue
                    if (!heading) {
                        printf "\n# %s\n\n", s > f
                        heading = listed = 1
                    }
                    link = prefix cbase[k]
                    gsub(/ /, "%20", link)
                    entry = "* [" ctitle[k] "](" link ") - " cdesc[k]
                    if (cstatus[k] != "" && cstatus[k] != "stable") entry = entry " (" cstatus[k] ")"
                    print entry > f
                }
            }
            if (!listed) printf "\n# %s\n\n아직 문서가 없다.\n", d > f
            close(f)
        }

        # AGENTS.md 블록은 파일 이름만 담는다. 설명은 index.md에 있다.
        line = "[Docs Index]|root: ./docs|IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for any tasks."
        for (i = 1; i <= ndir; i++) {
            d = dirs[i]
            name[d, ++nname[d]] = "index.md"
            sort_names(d)
            files = name[d, 1]
            for (k = 2; k <= nname[d]; k++) files = files "," name[d, k]
            line = line "|" (d == "docs" ? "." : substr(d, 6)) ":{" files "}"
        }
        print line > (ENVIRON["OUT"] "/agents-index")
    }
' "$tmp/files"

# 2. AGENTS.md의 표시 주석 사이를 새 블록으로 바꾼 사본을 만든다.
BLOCK="$(cat "$tmp/out/agents-index")" awk -v start="$START" -v end="$END" '
    { sub(/\r$/, "") }
    $0 == start {
        print
        print ""
        print "```text"
        print ENVIRON["BLOCK"]
        print "```"
        print ""
        skip = 1
        n++
        next
    }
    $0 == end {
        skip = 0
        n++
    }
    !skip { print }
    END { if (n != 2) exit 1 }
' AGENTS.md > "$tmp/AGENTS.md" || {
    echo "FAIL: AGENTS.md has no place for the docs index; add these two lines where it belongs:" >&2
    printf '  %s\n' "$START" "$END" >&2
    exit 1
}

# 3. 만든 결과와 저장소를 맞춘다. CRLF로 체크아웃된 파일도 내용이 같으면 같은 것으로 본다.
stale=0
update() {
    if [ -f "$2" ] && tr -d '\r' < "$2" | cmp -s - "$1"; then
        return 0
    fi
    if [ "$mode" = check ]; then
        echo "FAIL: $2 is out of date" >&2
        stale=1
    else
        cp "$1" "$2"
        echo "updated: $2"
    fi
}

while IFS= read -r f; do
    update "$tmp/out/$f" "$f"
done < <(cd "$tmp/out" && find docs -name index.md | sort)
update "$tmp/AGENTS.md" AGENTS.md

if [ "$stale" -eq 1 ]; then
    echo "run bash scripts/doc-index.sh to regenerate" >&2
    exit 1
fi
