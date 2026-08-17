// 커밋 메시지 형식 규칙. 검사기는 commitlint 다. https://commitlint.js.org
//
// 검사:  bash tests/check-commit-msg.sh
// 훅:    commit-msg 가 같은 스크립트를 부른다. Justfile 을 거치지 않는다
//
// 사람이 읽는 원본은 docs/standards/commit-convention.md 다.
// 여기에는 그 문서에 적힌 것만 기계화한다. 새 규칙을 발명하지 않는다.
//
// config-conventional 기본값을 그대로 쓴다. 실측으로 확인한 것:
//   - fixup!, squash!, Merge branch ..., revert:, 한국어 제목은 전부 통과한다.
//     git commit --fixup 과 git rebase --autosquash 를 깨지 않으므로 예외 설정이 필요 없다
//   - subject-case 는 제목이 대문자 ASCII 토큰으로 시작하면 막는다. 그대로 둔다.
//     대가는 제목을 소문자로 시작해야 하는 것이고, 그것이 규약이다
//   - header-max-length 는 100 이다. .editorconfig 와 .rumdl.toml 의 줄 길이와 같은 값이라
//     따로 낮추지 않는다
//
// 제목의 금지 문자(가운뎃점, em dash 등)는 여기 없다. tests/check-commit-msg.sh 의
// notation 단계가 본다. 그 규칙의 출처는 docs/standards/writing-style.md 이고
// Conventional Commits 와 무관하며, node_modules 가 없어도 돌아야 하기 때문이다.

export default {
    extends: ["@commitlint/config-conventional"],
};
