# consensus-build

한 줄 기능 설명만 주면 **기능정의서 → 구현 계획 → 코드 구현**까지 자동으로 완주하는 Claude Code 플러그인입니다. 각 단계에서 Agent Teams 3명이 병렬로 독립 검토하여 합의(consensus)에 이르고, CRITICAL/MAJOR 이슈가 사라질 때까지 자율 반복합니다. TDD + Tidy First 원칙으로 실제 코드를 작성하고 테스트를 통과시킵니다.

## 설치

```
/plugin marketplace add NB3025/consensus-build
/plugin install consensus-build@consensus-build-marketplace
```

> `NB3025/consensus-build`는 이 저장소의 GitHub `owner/repo`입니다. 포크했다면 본인 경로로 바꾸고, `.claude-plugin/marketplace.json`의 `source.repo`도 함께 수정하세요.

## 사용법

```
/consensus-build:build [모델] <기능 설명>
```

> 플러그인으로 설치된 스킬은 충돌 방지를 위해 항상 `플러그인명:스킬명` 형태로 호출됩니다. 그래서 커맨드가 `/consensus-build:build`입니다(`/` 입력 후 메뉴에서 선택해도 됩니다).

`모델`은 `opus`(기본) / `sonnet` / `haiku` 중 선택할 수 있습니다.

### 모드

| 호출 | 동작 |
|------|------|
| `/consensus-build:build [모델] <기능 설명>` | 전체 파이프라인 (Phase 0→7): 기능정의서·구현계획·코드까지 |
| `/consensus-build:build review-spec [모델] <기능정의서 경로>` | 기능정의서 리뷰만 |
| `/consensus-build:build review-impl [모델] <구현계획 경로>` | 구현계획 리뷰만 |
| `/consensus-build:build plan [모델] <기능정의서 경로>` | 기존 정의서 → 계획+구현 |
| `/consensus-build:build implement [모델] <구현계획 경로>` | 구현만 |

### 예시

```
/consensus-build:build 사용자가 이미지를 업로드하면 자동으로 태그를 다는 기능
/consensus-build:build sonnet review-spec docs/feature-spec-image-tagging.md
```

## 구성 요소

| 종류 | 내용 |
|------|------|
| Skill | `/consensus-build:build` 슬래시 커맨드 (`skills/build/`) |
| Hooks | Stop hook (파이프라인 완주 전 종료 차단), PostToolUse/PostToolUseFailure hook (Phase 6 테스트 성공·연속실패 추적) |

### Hook 동작 범위

모든 hook은 프로젝트의 `.claude/consensus-build-state.local.md` 상태 파일과 `session_id`로 가드됩니다. 파이프라인이 비활성이거나 다른 세션이면 즉시 통과(no-op)하므로, 플러그인을 설치해도 consensus-build와 무관한 작업에는 영향을 주지 않습니다.

## 산출물

파이프라인은 대상 프로젝트의 `docs/` 아래에 다음을 생성합니다.

- `feature-spec-{name}.md` — 기능정의서
- `impl-plan-{name}.md` — 구현 계획
- `decisions-log.md` — 자율 결정 로그
- `review-round-*.md`, `impl-review-round-*.md` — 리뷰 라운드 기록
- `learnings.md` — 학습 기록 (append)
- `src/`, `tests/` — 구현된 소스·테스트 코드

## 요구사항

- Claude Code
- `jq` 권장 (hook의 JSON 처리에 사용. 없으면 `python3` fallback)

## 로컬에서 검증

```
claude plugin validate .
claude plugin marketplace add ~/consensus-build
```
