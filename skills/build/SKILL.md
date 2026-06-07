---
name: build
description: 한 줄 기능 설명으로 기능정의서 + 구현 계획 + 코드 구현까지 자동 완주. Agent Teams 3명이 CRITICAL/MAJOR 이슈가 없을 때까지 자율 반복 검토.
argument-hint: [review-spec <기능정의서-경로> | review-impl <구현계획-경로> | plan <기능정의서-경로> | implement <구현계획-경로> | [sonnet|opus|haiku] <기능 설명>]
disable-model-invocation: true
---

# 기능정의서 + 구현 계획 + 코드 구현 자동 파이프라인

## 입력

$ARGUMENTS

### 입력 파싱 규칙

**모드 판별**: 첫 번째 단어로 모드를 결정한다.

#### 전체 파이프라인 모드
`/consensus-build:build [모델] <기능 설명>`

- 첫 번째 단어가 `review-spec`도 `review-impl`도 `plan`도 `implement`도 아닌 경우
- 모델명(sonnet, opus, haiku)이면 해당 모델 사용, 아니면 기본 opus
- Phase 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 전체 실행

#### 기능정의서 리뷰 전용 모드
`/consensus-build:build review-spec [모델] <기능정의서 파일경로>`

- 첫 번째 단어: `review-spec`
- 대상은 기능정의서 파일 (review-spec-prompt.md로 리뷰)
- Phase 0 → 2 → 5(리뷰 보고) 순서로 실행. 구현 없음.

#### 구현 계획 리뷰 전용 모드
`/consensus-build:build review-impl [모델] <구현계획 파일경로>`

- 첫 번째 단어: `review-impl`
- 대상은 구현 계획 파일 (review-impl-prompt.md로 리뷰)
- Phase 0 → 4 → 5(리뷰 보고) 순서로 실행. 구현 없음.

#### 계획+구현 모드
`/consensus-build:build plan [모델] <기능정의서 파일경로>`

- 첫 번째 단어: `plan`
- 기존 기능정의서를 읽고 Phase 0 → 3 → 4 → 5 → 6 → 7 순서로 실행.

#### 구현 전용 모드
`/consensus-build:build implement [모델] <구현계획 파일경로>`

- 첫 번째 단어: `implement`
- Phase 0 → 6 → 7 순서로 실행. 기존 구현 계획 파일을 읽고 바로 구현.

모든 모드에서 두 번째 단어가 모델명(sonnet, opus, haiku)이면 해당 모델 사용, 아니면 기본 opus.

파싱한 모델명을 기억하라. Agent Teams 호출 시 model 파라미터로 전달한다.

## 참조 파일

이 스킬은 아래 지원 파일들을 사용한다. 각 Phase에서 필요할 때 Read 도구로 읽어라.

- [review-spec-prompt.md](review-spec-prompt.md): 기능정의서 리뷰 시 Agent Teams에게 전달할 프롬프트
- [review-impl-prompt.md](review-impl-prompt.md): 구현 계획 리뷰 시 Agent Teams에게 전달할 프롬프트
- [aggregation-rules.md](aggregation-rules.md): Agent Teams 결과 취합 및 루프 판정 규칙
- [tdd-tidy.md](tdd-tidy.md): TDD AND TIDY FIRST 구현 원칙
- [self-review.md](self-review.md): Phase 6에서 각 TASK 완료 직후 점검할 체크리스트

## 절대 규칙

- 최종 Phase(전체: Phase 7, 기능정의서 리뷰: Phase 5, 구현계획 리뷰: Phase 5, 계획+구현: Phase 7, 구현: Phase 7) 완료 전에 **절대 종료하지 말 것**.
- 중간 Phase에서 사용자에게 묻고 **멈추지 말 것**. Needs Review 이슈는 자율 판단한다.
- 각 Phase 완료 시 상태 파일을 업데이트하고 **즉시 다음 Phase로 진행**할 것.
- **Phase를 임의로 건너뛰지 말 것.** 모드별로 정의된 Phase 순서를 정확히 따른다. 사용자 입력의 자연어 뉘앙스로 Phase를 생략하거나 재해석하지 말 것.
- 코드 구현(Phase 6)을 요약, 생략, 위임하지 말 것. 실제 코드를 작성하고 테스트를 통과시켜야 한다.
- **completed 필드는 최종 Phase(Phase 7 또는 리뷰 모드의 Phase 5) 완료 시에만 true로 변경한다.** 중간 Phase에서 completed를 true로 변경하지 말 것.
- **상태 파일 업데이트 시 Edit 도구로 변경할 필드만 수정한다.** 파일 전체를 Write 도구로 다시 쓰지 말 것 (Phase 0 초기 생성 시만 Write 사용).

---

## Phase 0: 초기화

파이프라인 시작 시 상태 파일을 생성한다. Write 도구로 `.claude/consensus-build-state.local.md`에 아래 내용을 **그대로** 작성한다. 플레이스홀더(`{...}`)만 실제 값으로 치환하고, **템플릿에 없는 필드를 절대 추가하지 말 것.** session_id, timestamp, feature_name 등 임의 필드를 추가하지 말 것. session_id는 stop hook이 자동으로 관리한다:

전체 파이프라인 모드:
```
active: true
mode: pipeline
phase: 1
completed: false
spec_file:
impl_file:
current_task:
tasks_completed: 0
tasks_total: 0
```

기능정의서 리뷰 전용 모드:
```
active: true
mode: review-spec
phase: 2
completed: false
review_file: {리뷰 대상 기능정의서 파일 경로}
```

구현 계획 리뷰 전용 모드:
```
active: true
mode: review-impl
phase: 4
completed: false
review_file: {리뷰 대상 구현 계획 파일 경로}
```

계획+구현 모드:
```
active: true
mode: plan
phase: 3
completed: false
spec_file: {기능정의서 파일 경로}
impl_file:
current_task:
tasks_completed: 0
tasks_total: 0
```

구현 전용 모드:
```
active: true
mode: implement
phase: 6
completed: false
impl_file: {구현 계획 파일 경로}
current_task:
tasks_completed: 0
tasks_total: 0
```

`.claude` 디렉토리가 없으면 생성한다.

상태 파일 생성 후, `docs/learnings.md`가 존재하면 Read 도구로 읽는다. **최근 5건의 학습 기록만** 로드하여 컨텍스트 소모를 제한한다 (2K 토큰 이내). 이 학습 내용은 이후 Phase에서 같은 실수를 반복하지 않기 위한 참고 자료로 활용한다. **30일 이상 경과한 항목은 `(Nd ago — 현재 유효한지 검증 필요)` 표시를 붙여 참고만 한다.**

또한, 프로젝트 루트의 `AGENTS.md` (또는 `CLAUDE.md`)에 `## Discovered Patterns` 섹션이 있으면 해당 섹션도 읽는다.

모드에 따라:
- 전체 파이프라인 → Phase 1로 즉시 진행
- 기능정의서 리뷰 전용 → Phase 2로 즉시 진행
- 구현 계획 리뷰 전용 → Phase 4로 즉시 진행
- 계획+구현 → Phase 3으로 즉시 진행
- 구현 전용 → Phase 6으로 즉시 진행

---

## Phase 1: 기능정의서 초안 생성

파싱한 기능 설명을 바탕으로 **상세하고 구체적인** 기능정의서를 작성하라.
추상적 서술을 피하고, 수치/일정/용어를 명확히 정의해야 리뷰가 의미 있다.

### 문서 구조 (모든 섹션 필수)

```
# {기능명} 기능정의서

## 1. 개요
- 기능 한 줄 요약
- 핵심 가치 제안

## 2. 배경 및 목적
- 해결하려는 문제
- 현재 상태(As-Is)와 목표 상태(To-Be)
- 비즈니스 임팩트

## 3. 용어 정의
- 문서 전체에서 사용하는 핵심 용어와 그 정의를 표로 정리
- 이후 문서에서 이 용어를 일관되게 사용할 것

## 4. 사용자 스토리
- US-001, US-002... 형식
- As a {역할}, I want {기능}, So that {가치}

## 5. 기능 요구사항
- FR-001, FR-002... 형식
- 각 요구사항에 우선순위(P0/P1/P2), 관련 사용자 스토리 ID 포함
- 구체적 수치 포함 (예: 응답시간 200ms 이내, 최대 동시 접속 1000명)

## 6. 비기능 요구사항
- NFR-001, NFR-002... 형식
- 성능, 보안, 확장성, 가용성, 접근성 등
- 측정 가능한 기준 포함

## 7. 기술 설계
- 아키텍처 개요
- 주요 컴포넌트와 역할
- 기술 스택
- 시스템 간 연동 방식

## 8. 데이터 모델
- 주요 엔티티, 속성, 관계
- 테이블/스키마 설계 (필요시)

## 9. API 설계
- 주요 엔드포인트, 메서드, 요청/응답 형식
- 인증/인가 방식

## 10. UI/UX 고려사항
- 주요 화면 흐름
- 핵심 인터랙션
- 접근성 요구사항

## 11. 마일스톤 및 일정
- Phase 1, 2, 3... 단계별 구현 계획
- 각 단계의 산출물, 예상 기간, 의존 관계
- 구체적 날짜 또는 상대적 기간(예: 착수 후 2주)

## 12. 리스크 및 완화 방안
- RISK-001, RISK-002... 형식
- 발생 확률(H/M/L), 영향도(H/M/L), 완화 전략

## 13. 성공 지표
- 정량적 KPI, 목표값, 측정 방법, 측정 주기
- 기능 요구사항의 수치와 일관되게 작성할 것

## 14. 의존성
- 외부 시스템, 팀, 라이브러리 의존성
- 각 의존성의 리스크 수준

## 15. 범위 제외 사항
- 이번 스코프에 포함하지 않는 것
- 향후 고려 가능 여부
```

### 작성 규칙
- 수치를 언급할 때는 문서 전체에서 동일 수치를 일관되게 사용
- 타임라인의 순서와 의존 관계가 논리적으로 맞아야 함
- 용어 정의 섹션에서 정의한 용어를 이후 섹션에서 일관되게 사용
- 앞에서 세운 원칙/제약을 뒤에서 위반하지 않을 것
- 분석/근거와 결론/전략이 논리적으로 일치할 것

### 파일 저장
- 경로: `docs/feature-spec-{적절한-kebab-case-이름}.md`
- docs 디렉토리가 없으면 생성

Phase 1 완료 후 Edit 도구로 상태 파일을 업데이트한다: `phase: 1` → `phase: 2`, `spec_file:` → `spec_file: {생성한 기능정의서 경로}`. **즉시 Phase 2로 진행. 멈추지 말 것.**

---

## Phase 2: 기능정의서 자율 리뷰 루프

**기능정의서 리뷰 전용 모드(`review-spec`)에서는 이 Phase부터 시작한다.** 대상 파일은 입력 파싱에서 결정한 파일 경로를 사용. 전체 파이프라인 모드에서는 Phase 1에서 저장한 파일 경로를 사용.

**최대 5라운드**까지 반복한다. 라운드 번호를 Round 1부터 추적.

### Step 2.1: Agent Teams 3명 병렬 실행

Agent 도구를 사용하여 Agent Teams 3명을 **동시에(병렬로)** 실행하라.
동일한 지시와 동일한 내용을 주어 가중 투표 방식으로 검토 결과를 취합한다.

**중요: 각 Agent 호출 시 `model` 파라미터에 입력 파싱에서 결정한 모델명을 지정할 것.**

각 Agent에게 기능정의서 파일 경로와 함께 [review-spec-prompt.md](review-spec-prompt.md)의 내용을 전달한다.
파일 경로의 `{Phase 1에서 저장한 파일 경로}` 부분을 실제 경로로 치환하여 전달할 것.

**라운드 독립성 규칙: 모든 라운드에서 각 Agent에게 전달하는 내용은 오직 (1) 기능정의서 파일 경로와 (2) review-spec-prompt.md의 내용뿐이어야 한다. Round 2 이상에서도 Round 1과 완전히 동일한 프롬프트를 사용한다. 다음 정보를 Agent 프롬프트에 절대 포함하지 말 것:**
- **라운드 번호** (예: "이것은 Round 3입니다", "3번째 리뷰입니다")
- **이전 라운드에서 발견된 이슈 또는 수정 내역** (예: "Round 1에서 섹션 3.10을 수정했습니다")
- **이전 라운드의 취합 결과 요약**
- **이전 라운드 수정 사항에 대한 검증/확인/포커스 지시** (예: "Round 2 수정이 올바른지 검증하라")
- **이전 라운드의 존재를 암시하는 기타 정보**

**Agent는 문서를 처음 보는 것처럼 독립적으로 검토해야 한다. 이 규칙은 Agent 호출에만 적용된다. 메인 에이전트는 Step 2.2 취합 시 이전 라운드 결과를 참조하여 반복 이슈를 판별한다.**

### Step 2.2: 결과 취합 및 루프

[aggregation-rules.md](aggregation-rules.md)의 절차를 따라 취합한다.
취합 결과를 `docs/review-round-{라운드번호}.md`에 저장한다.
Needs Review 이슈는 자동 반영하지 않고 기록만 해둔다 (Phase 5에서 자율 판단하여 반영).
루프 판정 기준에 따라 계속 또는 다음 Phase로 이동.

Phase 2 완료 후:
- **기능정의서 리뷰 전용 모드(`review-spec`)**: Edit 도구로 상태 파일의 `phase: 2` → `phase: 5`로 변경한다. **즉시 Phase 5로 진행. 멈추지 말 것.**
- **전체 파이프라인 모드**: Edit 도구로 상태 파일의 `phase: 2` → `phase: 3`으로 변경한다. **즉시 Phase 3으로 진행. 멈추지 말 것.**

---

## Phase 3: TDD-Tidy 기반 구현 계획 생성

Phase 2에서 확정된 기능정의서를 기반으로 구현 계획을 작성한다.
[tdd-tidy.md](tdd-tidy.md)의 원칙을 엄격히 준수하여 태스크를 설계한다.

### 문서 구조

```
# {기능명} 구현 계획

## 구현 원칙
- TDD 사이클: Red → Green → Refactor
- Tidy First: 구조적 변경과 행위적 변경을 분리
- 구조적 변경 먼저, 행위적 변경은 그 다음
- 각 커밋은 구조적 또는 행위적 중 하나만 포함

## 요구사항 추적 매트릭스
| 요구사항 ID | 요구사항 요약 | 관련 태스크 |
|-------------|-------------|-------------|
| FR-001      | ...         | TASK-003, TASK-004 |
| NFR-001     | ...         | TASK-007 |

## 구현 순서 개요
기능을 작은 증분(increment)으로 나누고, 각 증분은 아래 패턴을 따른다:
1. Structural: 필요한 구조 준비 (파일 생성, 인터페이스 정의, 리팩토링)
2. Red: 실패하는 테스트 작성
3. Green: 테스트를 통과시키는 최소 코드 작성
4. Refactor: 통과 후 코드 개선 (구조적 변경으로 분리)

## 태스크 목록

### TASK-001: {제목}
- **변경 유형**: Structural | Behavioral
- **TDD 단계**: Setup | Red | Green | Refactor
- **설명**: 이 태스크에서 수행할 작업
- **테스트**: (Red인 경우) 작성할 테스트와 예상 실패 이유
- **구현**: (Green인 경우) 테스트를 통과시키기 위한 최소 구현
- **의존성**: TASK-xxx (선행 태스크)
- **관련 요구사항**: FR-xxx, NFR-xxx
- **완료 기준**: 이 태스크가 완료된 상태의 정의
- **커밋 메시지 예시**: "structural: ..." 또는 "behavioral: ..."

### TASK-002: {제목}
...

## 태스크 의존성 그래프
TASK-001 → TASK-002 → TASK-003
                    ↘ TASK-004
(텍스트 기반 의존성 시각화)

## 테스트 전략
- 단위 테스트: 각 컴포넌트의 핵심 로직
- 통합 테스트: 컴포넌트 간 연동
- E2E 테스트: 사용자 시나리오 기반
- 테스트 커버리지 목표: 80% 이상
```

### 작성 규칙
- 기능정의서의 **모든 FR/NFR**이 최소 하나의 태스크에 매핑되어야 함
- 태스크 간 리소스명, 변수명, 설정값이 일관되어야 함
- 의존성 순서가 역행하면 안 됨 (A가 B에 의존하면 B가 먼저)
- 순환 의존이 없어야 함
- Structural 태스크와 Behavioral 태스크를 한 태스크에 섞지 말 것
- Red 태스크 바로 다음에 해당 Green 태스크가 와야 함
- 기능정의서에서 정의한 용어를 그대로 사용할 것

### 파일 저장
- 경로: `docs/impl-plan-{적절한-kebab-case-이름}.md`

Phase 3 완료 후 Edit 도구로 상태 파일을 업데이트한다: `phase: 3` → `phase: 4`, `impl_file:` → `impl_file: {생성한 구현 계획 경로}`. **즉시 Phase 4로 진행. 멈추지 말 것.**

---

## Phase 4: 구현 계획 자율 리뷰 루프

**구현 계획 리뷰 전용 모드(`review-impl`)에서는 이 Phase부터 시작한다.** 대상 파일은 입력 파싱에서 결정한 파일 경로를 사용.

**최대 5라운드**까지 반복한다. 라운드 번호를 Round 1부터 추적.

### Step 4.1: Agent Teams 3명 병렬 실행

Agent 도구를 사용하여 Agent Teams 3명을 **동시에(병렬로)** 실행하라.

**중요: 각 Agent 호출 시 `model` 파라미터에 입력 파싱에서 결정한 모델명을 지정할 것.**

각 Agent에게 구현 계획 파일 경로와 함께 [review-impl-prompt.md](review-impl-prompt.md)의 내용을 전달한다.
파일 경로의 플레이스홀더를 실제 경로로 치환하여 전달할 것.

**라운드 독립성 규칙: 모든 라운드에서 각 Agent에게 전달하는 내용은 오직 (1) 구현 계획 파일 경로와 (2) review-impl-prompt.md의 내용뿐이어야 한다. Round 2 이상에서도 Round 1과 완전히 동일한 프롬프트를 사용한다. 다음 정보를 Agent 프롬프트에 절대 포함하지 말 것:**
- **라운드 번호** (예: "이것은 Round 3입니다", "3번째 리뷰입니다")
- **이전 라운드에서 발견된 이슈 또는 수정 내역** (예: "Round 1에서 TASK-005를 수정했습니다")
- **이전 라운드의 취합 결과 요약**
- **이전 라운드 수정 사항에 대한 검증/확인/포커스 지시** (예: "Round 2 수정이 올바른지 검증하라")
- **이전 라운드의 존재를 암시하는 기타 정보**

**Agent는 문서를 처음 보는 것처럼 독립적으로 검토해야 한다. 이 규칙은 Agent 호출에만 적용된다. 메인 에이전트는 Step 4.2 취합 시 이전 라운드 결과를 참조하여 반복 이슈를 판별한다.**

### Step 4.2: 결과 취합 및 루프

[aggregation-rules.md](aggregation-rules.md)의 절차를 따라 취합한다.
취합 결과를 `docs/impl-review-round-{라운드번호}.md`에 저장한다.
Needs Review 이슈는 자동 반영하지 않고 기록만 해둔다 (Phase 5에서 자율 판단하여 반영).
루프 판정 기준에 따라 계속 또는 Phase 5로 이동.

Phase 4 완료 후 Edit 도구로 상태 파일의 `phase: 4` → `phase: 5`로 변경한다. **즉시 Phase 5로 진행. 멈추지 말 것.**

---

## Phase 5: Needs Review 자율 판단 + 문서 최종 반영

실행된 리뷰 Phase(Phase 2 및/또는 Phase 4)에서 기록해 둔 Needs Review 이슈를 자율 판단한다. 해당 모드에서 실행되지 않은 Phase의 이슈는 존재하지 않으므로 무시한다.

### 판단 절차

1. 각 Needs Review 이슈에 대해 **최선의 판단**을 내린다
2. 판단 근거를 명확히 기록한다
3. 판단 결과를 기능정의서와 구현 계획에 반영한다
4. 결정 로그를 `docs/decisions-log.md`에 저장한다

### 결정 로그 형식

```
# 자율 결정 로그

## 결정 원칙
- 사용자 경험 최적화 우선
- 기술적 안전성 우선 (불확실하면 보수적으로)
- 초기 버전은 단순하게, 복잡한 것은 이후 Phase로

## 결정 목록

### DEC-001: {이슈 제목}
- **원본 이슈**: {어느 Phase, 어느 Round에서 발견}
- **선택지**: A) ... B) ... C) ...
- **결정**: {선택한 옵션}
- **근거**: {왜 이 결정을 내렸는지}
- **반영 위치**: {어느 문서의 어느 섹션에 반영했는지}
- **사용자 확인 필요도**: 높음 | 보통 | 낮음
```

### 리뷰 전용 모드일 때 (review-spec 또는 review-impl)

리뷰 전용 모드에서는 Phase 5가 최종 단계이다. 리뷰 결과를 보고하고 상태 파일의 completed를 true로 변경한다.

```
# {기능정의서 | 구현 계획} 리뷰 완료

## 결과 요약
- 대상 파일: {리뷰 대상 파일 경로}
- 리뷰 유형: {기능정의서 리뷰 (review-spec-prompt.md) | 구현 계획 리뷰 (review-impl-prompt.md)}
- Agent Teams 모델: {사용된 모델명}
- 총 리뷰 라운드: {N}회
- 최종 상태: {PASS | 잔여 이슈 있음}

## 라운드별 이력
| 라운드 | 발견 이슈 | CRITICAL | MAJOR | MINOR | 수정 반영 |
|--------|-----------|----------|-------|-------|-----------|

## 잔여 이슈 (있는 경우)
- ⚪ Low Priority 또는 MINOR 이슈 목록
```

전체 파이프라인 / 계획+구현 / 구현 전용 모드에서는 Phase 5 완료 후 Edit 도구로 상태 파일의 `phase: 5` → `phase: 6`으로 변경한다. **즉시 Phase 6으로 진행. 멈추지 말 것.**

---

## Phase 6: TDD-Tidy 코드 구현

구현 계획(impl-plan)을 Read 도구로 읽고, TASK 순서대로 코드를 구현한다.
[tdd-tidy.md](tdd-tidy.md)의 원칙을 실제 코드에 적용한다.

### 구현 전용 모드일 때
입력 파싱에서 결정한 구현 계획 파일을 읽어 사용한다.

### 구현 절차

각 TASK에 대해:

**Structural 태스크**: 파일 생성, 디렉토리 구조 설정, 인터페이스 정의, 리팩토링 등 구조적 변경만 수행. 테스트를 실행하여 기존 동작이 변경되지 않았음을 확인.

**Behavioral 태스크 (Red → Green → Refactor)**:
1. **Red**: 실패하는 테스트를 작성. Bash 도구로 테스트를 실행하여 실패를 확인.
2. **Green**: 테스트를 통과시키는 최소한의 코드 작성. Bash 도구로 테스트 실행하여 통과 확인.
3. **Refactor**: 중복 제거, 네이밍 개선 등. 테스트 실행하여 여전히 통과 확인.

### 구현 규칙

- 각 TASK 완료 후 **모든 테스트를 실행**하여 기존 테스트가 깨지지 않았는지 확인
- 각 TASK 완료 후 [self-review.md](self-review.md)를 Read 도구로 읽어 체크리스트를 점검한다. 미통과 항목이 있으면 즉시 수정하고 다시 점검. 모두 통과해야 다음 TASK로 진행한다.
- 각 TASK 완료 후 **배운 게 있을 때만** `docs/learnings.md`에 append한다 (실패한 접근법, 새로 발견한 패턴). 배운 게 없으면 기록하지 말 것 — 억지로 채우지 말 것. 이미 기록된 내용과 중복되면 생략. 형식은 Phase 7 Step 7.0과 동일.
- 각 TASK 완료 후 현재 TASK의 변경사항을 커밋한다. `git add .` 금지 — 변경한 파일만 개별 `git add`. `node_modules`, `.env`, `dist`, `build` 등 빌드 산출물/의존성 금지. `.gitignore`가 있으면 준수. 커밋 전 `git diff --cached`로 추가된 파일을 확인하여 의도하지 않은 파일이 포함되어 있으면 제거. 커밋 메시지는 구현 계획의 "커밋 메시지 예시"를 따르되 형식은 `<type>(<scope>): <설명>` (type: feat, fix, test, refactor, docs, chore). Structural TASK는 `refactor:` 프리픽스, Behavioral TASK는 `feat:`/`fix:`/`test:` 프리픽스를 사용. 커밋 전 모든 테스트가 통과하는 상태인지 확인한다. git 저장소가 아닌 경우 이 커밋 단계는 생략.
- 테스트 실패 시 즉시 수정. **테스트가 2회 연속 실패하면** PostToolUseFailure hook이 자동으로 `docs/learnings.md`에 실패 사실을 기록하고 systemMessage로 알려준다. 그때 **근본 원인을 분석하여** learnings.md의 해당 항목에 Why와 How to apply를 보완하라. 다른 접근을 우선 고려하되, 같은 방법의 미세 변형이 답일 수도 있음. hook이 동작하지 않는 경우 수동으로 기록하라.
- 테스트가 통과하는 상태에서만 다음 TASK로 진행
- TASK 간 의존성 순서를 준수
- 구현 중 구현 계획에 없는 추가 작업이 필요하면, 수행하되 `docs/impl-deviations.md`에 기록
- **모든 TASK가 완료될 때까지 멈추지 말 것. Sprint 단위, TASK 단위로 "계속할까요?"라고 묻지 말 것. 전체 TASK를 끝까지 완주한다.**
- 요구사항이 불명확한 경우에도 사용자에게 묻지 말 것. Phase 5의 자율 결정 원칙(보수적, 단순하게)을 따라 자체 판단하고 `docs/decisions-log.md`에 추가 기록한다.

### 진행 상황 추적

Phase 6 시작 시, 구현 계획 파일에서 `### TASK-` 패턴의 총 개수를 센다. Edit 도구로 상태 파일을 업데이트한다:
- `tasks_total: 0` → `tasks_total: {총 TASK 수}`
- `current_task:` → `current_task: TASK-001`

각 TASK 완료 후 Edit 도구로:
- `tasks_completed`를 1 증가
- `current_task`를 다음 TASK 번호로 변경

Phase 6 완료 후 Edit 도구로 상태 파일의 `phase: 6` → `phase: 7`로 변경한다. **즉시 Phase 7로 진행. 멈추지 말 것.**

---

## Phase 7: 학습 정리 + 최종 보고

모든 Phase가 완료된 후, **먼저 학습을 정리**하고 최종 보고를 출력한다.

### Step 7.0: 학습 기록

이번 파이프라인에서 배운 것을 `docs/learnings.md`에 append한다.
Phase 6에서 즉시 기록한 항목이 있으면, 이를 재검토하여 병합·보완한다 (중복 항목은 하나로 통합).

```
## {날짜} — {기능명 또는 TASK 범위}

### 실패한 접근법
- {시도한 것}
  - Why: {왜 실패했는지}
  - How to apply: {다음에 이 상황에서 어떻게 할지}
- ...

### 발견한 패턴
- {패턴 이름}
  - Why: {왜 효과적인지 / 왜 중요한지}
  - How to apply: {어떤 상황에서 적용할지}
- ...
(성공 패턴도 여기에 포함. 기록 기준: "처음 시도했는데 바로 성공(비자명)" 또는 "실패 후 전환해서 성공"한 경우만)

### 다음에 다르게 할 것
- {1줄 조언}
```

**규칙:**
- 실패한 접근법은 최대 3개, 발견한 패턴은 최대 5개로 제한
- 이미 learnings.md에 기록된 내용과 중복되면 생략. Phase 6 즉시 기록과 유사한 항목은 병합
- 파일이 50건을 초과하면, 오래된 항목부터 삭제하여 최근 50건만 유지
- 3회 이상 반복 등장한 패턴은 `AGENTS.md` (또는 `CLAUDE.md`)의 `## Discovered Patterns` 섹션에 영구 기록한다. **승격 후 learnings.md에서 해당 항목을 제거한다.** 해당 섹션이 없으면 파일 끝에 생성한다.

`docs/learnings.md` 파일이 없으면 생성한다.

### Step 7.1: 최종 보고

### 전체 파이프라인 / 구현 전용 모드:

```
# 파이프라인 완료

## 결과 요약
- 기능정의서: {파일 경로}
- 구현 계획: {파일 경로}
- Agent Teams 모델: {모델명}

## 기능정의서 리뷰 (Phase 2)
- 총 리뷰 라운드: {N}회
- 최종 상태: {PASS}
| 라운드 | 발견 이슈 | CRITICAL | MAJOR | MINOR | 수정 반영 |
|--------|-----------|----------|-------|-------|-----------|

## 구현 계획 리뷰 (Phase 4)
- 총 리뷰 라운드: {N}회
- 최종 상태: {PASS}
| 라운드 | 발견 이슈 | CRITICAL | MAJOR | MINOR | 수정 반영 |
|--------|-----------|----------|-------|-------|-----------|

## 자율 결정 사항 (Phase 5)
- 총 결정: {N}건
- 사용자 확인 필요도 높음: {N}건
| # | 결정 | 근거 요약 | 확인 필요도 |
|---|------|----------|------------|

## 코드 구현 (Phase 6)
- 완료 TASK: {N}/{총 TASK 수}
- 테스트 결과: {통과/실패 수}
- 계획 대비 변경사항: {있음/없음} (docs/impl-deviations.md 참조)

## 생성된 파일 목록
- docs/feature-spec-{name}.md (기능정의서)
- docs/impl-plan-{name}.md (구현 계획)
- docs/decisions-log.md (자율 결정 로그)
- docs/impl-deviations.md (구현 중 계획 변경 사항, 있는 경우)
- docs/learnings.md (학습 기록 — append)
- docs/review-round-*.md (기능정의서 리뷰)
- docs/impl-review-round-*.md (구현 계획 리뷰)
- src/ (구현된 소스 코드)
- tests/ (테스트 코드)
```

### 사용자 확인 권장 사항

자율 결정 로그(docs/decisions-log.md) 중 **확인 필요도 "높음"** 항목을 나열하고, 변경이 필요하면 알려달라고 안내한다.

### 파이프라인 완료 처리

최종 보고 출력 후, 상태 파일의 completed를 true로 변경한다.
이것으로 Stop Hook이 다음 종료를 허용하게 된다.
