// consensus-build 파이프라인의 단계 정의.
// Ralph 스타일: Next 버튼으로 각 단계를 하나씩 드러낸다.
// 각 step은 그 시점까지 "보이게 할" 노드/엣지 id 집합을 누적적으로 정의한다.

// 노드 좌표는 가로 흐름(왼→오른쪽), 리뷰 루프는 위로 분기시켜 사이클을 시각화한다.
export const nodes = [
  // id, 화면 라벨, 종류(kind), 위치
  { id: 'input',   kind: 'input',   emoji: '✍️', title: '입력',          desc: '한 줄 요구사항 또는 기존 문서 파일', pos: { x: 0,    y: 200 } },
  { id: 'spec',    kind: 'doc',     emoji: '📝', title: '기능정의서',     desc: 'Phase 1 · 15개 섹션 초안',          pos: { x: 260,  y: 200 } },
  { id: 'review1', kind: 'review',  emoji: '🔍', title: '리뷰',          desc: 'Phase 2 · Agent 3명 독립 검토·합의', pos: { x: 540,  y: 200 } },
  { id: 'fix1',    kind: 'fix',     emoji: '✏️', title: '수정',          desc: 'CRITICAL/MAJOR 이슈를 문서에 반영',  pos: { x: 540,  y: 40  } },
  { id: 'plan',    kind: 'doc',     emoji: '🗂', title: '구현 계획',      desc: 'Phase 3 · TDD+Tidy TASK 분해',       pos: { x: 840,  y: 200 } },
  { id: 'review2', kind: 'review',  emoji: '🔍', title: '리뷰',          desc: 'Phase 4 · 계획을 같은 방식으로 검토', pos: { x: 1120, y: 200 } },
  { id: 'fix2',    kind: 'fix',     emoji: '✏️', title: '수정',          desc: 'CRITICAL/MAJOR 이슈를 계획에 반영',  pos: { x: 1120, y: 40  } },
  { id: 'decide',  kind: 'doc',     emoji: '⚖️', title: '자율 판단',      desc: 'Phase 5 · Needs Review 이슈 결정',   pos: { x: 1420, y: 200 } },
  { id: 'code',    kind: 'build',   emoji: '⚙️', title: '코드 구현',      desc: 'Phase 6 · Red→Green→Refactor, 커밋', pos: { x: 1700, y: 200 } },
  { id: 'done',    kind: 'done',    emoji: '✅', title: '완료',          desc: 'Phase 7 · 학습 정리 · 최종 보고',     pos: { x: 1980, y: 200 } },
]

export const edges = [
  { id: 'e_in_spec',     source: 'input',   target: 'spec' },
  { id: 'e_spec_r1',     source: 'spec',    target: 'review1' },
  { id: 'e_r1_fix1',     source: 'review1', target: 'fix1',    label: 'CRITICAL/MAJOR 있음', loop: true },
  { id: 'e_fix1_r1',     source: 'fix1',    target: 'review1', label: '다시 리뷰',           loop: true },
  { id: 'e_r1_plan',     source: 'review1', target: 'plan',    label: 'PASS',                pass: true },
  { id: 'e_plan_r2',     source: 'plan',    target: 'review2' },
  { id: 'e_r2_fix2',     source: 'review2', target: 'fix2',    label: 'CRITICAL/MAJOR 있음', loop: true },
  { id: 'e_fix2_r2',     source: 'fix2',    target: 'review2', label: '다시 리뷰',           loop: true },
  { id: 'e_r2_decide',   source: 'review2', target: 'decide',  label: 'PASS',                pass: true },
  { id: 'e_decide_code', source: 'decide',  target: 'code' },
  { id: 'e_code_done',   source: 'code',    target: 'done' },
]

// 단계별 reveal 순서. 각 step에서 새로 등장하는 노드/엣지와 설명을 담는다.
export const steps = [
  {
    title: '입력을 받는다',
    body: '한 줄 요구사항 텍스트나 기존 문서 파일을 건네면 파이프라인이 시작됩니다.',
    nodes: ['input'],
    edges: [],
  },
  {
    title: 'Phase 1 — 기능정의서 초안',
    body: '요구사항을 15개 섹션(개요·요구사항·기술설계·데이터모델·API·리스크·성공지표 등)을 갖춘 상세 기능정의서로 펼칩니다.',
    nodes: ['spec'],
    edges: ['e_in_spec'],
  },
  {
    title: 'Phase 2 — 합의 리뷰',
    body: 'Agent 3명이 서로의 결과를 모른 채 독립적으로 기능정의서를 검토하고, 가중 투표로 이슈를 합의합니다.',
    nodes: ['review1'],
    edges: ['e_spec_r1'],
  },
  {
    title: '리뷰 → 수정 → 다시 리뷰',
    body: '합의된 🔴 CRITICAL/MAJOR 이슈를 문서에 반영(수정)하고, 그 결과를 다시 리뷰합니다. 중대 이슈가 사라지거나 최대 5라운드까지 반복합니다.',
    nodes: ['fix1'],
    edges: ['e_r1_fix1', 'e_fix1_r1'],
  },
  {
    title: 'Phase 3 — 구현 계획',
    body: '중대 이슈가 없으면(PASS) TDD+Tidy 원칙으로 기능정의서를 TASK 단위 구현 계획으로 분해합니다.',
    nodes: ['plan'],
    edges: ['e_r1_plan', 'e_plan_r2'],
  },
  {
    title: 'Phase 4 — 구현 계획도 같은 방식으로',
    body: '구현 계획 역시 Agent 3명의 합의 리뷰를 거치고, 이슈가 있으면 수정 후 재리뷰하는 동일한 루프를 돕니다.',
    nodes: ['review2', 'fix2'],
    edges: ['e_r2_fix2', 'e_fix2_r2'],
  },
  {
    title: 'Phase 5 — 자율 판단',
    body: '보류해 둔 Needs Review 이슈를 보수적 원칙으로 자율 판단해 문서에 최종 반영합니다. 사람에게 묻지 않습니다.',
    nodes: ['decide'],
    edges: ['e_r2_decide', 'e_decide_code'],
  },
  {
    title: 'Phase 6~7 — 코드 구현 후 완료',
    body: 'Red→Green→Refactor로 실제 코드와 테스트를 작성하고 TASK별로 커밋합니다. 모든 TASK 완주 후 학습을 정리하고 최종 보고합니다.',
    nodes: ['code', 'done'],
    edges: ['e_code_done'],
  },
]
