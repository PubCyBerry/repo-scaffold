---
id: {{IDX_ID}}
title: {{IDX_TITLE}}
type: index
status: active
summary: {{PRODUCT_DIR}} 제품 종속 자료 진입점
scope:
  - {{DOCS_DIR}}/**
read_when:
  - {{PRODUCT_DIR}} 기반 컴포넌트를 다룰 때
  - 제품 종속 규칙과 공통 규칙을 구분해야 할 때
related:
  - index-docs
---

# {{IDX_TITLE}}

## 목적

{{PRODUCT_DIR}} 에 종속되는 규칙, 절차, 참고 자료를 모은다.
다른 스택의 컴포넌트에는 적용하지 않는다.

## 범위

[{{DOCS_DIR}}/]({{DOCS_DIR}}/index.md) 하위 전체.
스택과 무관하게 적용되는 규칙은 여기가 아니라 [docs/standards/](docs/standards/index.md) 에 둔다.

## 문서 목록

| 디렉터리 | 성격 |
| --- | --- |
| [standards/]({{DOCS_DIR}}/standards/index.md) | 제품 종속 작업 규칙 |
| [guides/]({{DOCS_DIR}}/guides/index.md) | 제품 관련 절차 |
| [references/]({{DOCS_DIR}}/references/index.md) | 제품 명세, 설치, 외부 자료 |

## 관련 문서

- [문서 인덱스](docs/index.md)
