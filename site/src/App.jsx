import { useMemo, useState, useCallback, useEffect } from 'react'
import {
  ReactFlow,
  ReactFlowProvider,
  Background,
  Controls,
  Handle,
  Position,
  MarkerType,
  useReactFlow,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { nodes as NODE_DEFS, edges as EDGE_DEFS, steps as STEPS } from './steps.js'

// 커스텀 노드 — 이모지 + 제목 + 설명. kind별 색을 data-kind로 CSS에서 처리.
// 각 변마다 source/target 핸들을 둬서(8개) 엣지가 깔끔히 흐르게 한다.
// 핸들 id 규칙: 변(l/r/t/b) + 역할(s=source, t=target).
function StageNode({ data }) {
  return (
    <div className={`stage-node kind-${data.kind}`}>
      <Handle type="source" id="ls" position={Position.Left} />
      <Handle type="target" id="lt" position={Position.Left} />
      <Handle type="source" id="rs" position={Position.Right} />
      <Handle type="target" id="rt" position={Position.Right} />
      <Handle type="source" id="ts" position={Position.Top} />
      <Handle type="target" id="tt" position={Position.Top} />
      <Handle type="source" id="bs" position={Position.Bottom} />
      <Handle type="target" id="bt" position={Position.Bottom} />
      <div className="stage-emoji">{data.emoji}</div>
      <div className="stage-text">
        <div className="stage-title">{data.title}</div>
        <div className="stage-desc">{data.desc}</div>
      </div>
    </div>
  )
}

const nodeTypes = { stage: StageNode }

// step 인덱스까지 누적해서 보일 노드/엣지 id 집합을 구한다.
function visibleSets(stepIndex) {
  const nodeIds = new Set()
  const edgeIds = new Set()
  for (let i = 0; i <= stepIndex; i++) {
    STEPS[i].nodes.forEach((n) => nodeIds.add(n))
    STEPS[i].edges.forEach((e) => edgeIds.add(e))
  }
  return { nodeIds, edgeIds }
}

// step이 바뀔 때마다 보이는 노드 전체에 뷰를 다시 맞춘다.
function FitOnStep({ step }) {
  const { fitView } = useReactFlow()
  useEffect(() => {
    const t = setTimeout(() => fitView({ padding: 0.2, duration: 500 }), 60)
    return () => clearTimeout(t)
  }, [step, fitView])
  return null
}

function FlowApp() {
  const [step, setStep] = useState(0)
  const last = STEPS.length - 1

  const { nodeIds, edgeIds } = useMemo(() => visibleSets(step), [step])
  // 가장 최근 step에서 새로 등장한 노드 → 강조(하이라이트)
  const freshNodes = useMemo(() => new Set(STEPS[step].nodes), [step])

  const rfNodes = useMemo(
    () =>
      NODE_DEFS.filter((n) => nodeIds.has(n.id)).map((n) => ({
        id: n.id,
        type: 'stage',
        position: n.pos,
        data: { emoji: n.emoji, title: n.title, desc: n.desc, kind: n.kind },
        className: freshNodes.has(n.id) ? 'fresh' : '',
      })),
    [nodeIds, freshNodes],
  )

  const rfEdges = useMemo(
    () =>
      EDGE_DEFS.filter((e) => edgeIds.has(e.id)).map((e) => ({
        id: e.id,
        source: e.source,
        target: e.target,
        sourceHandle: e.sh,
        targetHandle: e.th,
        label: e.label,
        type: 'smoothstep',
        animated: !!e.loop,
        markerEnd: { type: MarkerType.ArrowClosed, width: 16, height: 16 },
        style: { strokeDasharray: '6 4' },
        className: e.pass ? 'edge-pass' : e.loop ? 'edge-loop' : 'edge-flow',
        labelBgPadding: [6, 3],
        labelBgBorderRadius: 4,
      })),
    [edgeIds],
  )

  const next = useCallback(() => setStep((s) => Math.min(s + 1, last)), [last])
  const prev = useCallback(() => setStep((s) => Math.max(s - 1, 0)), [])
  const reset = useCallback(() => setStep(0), [])

  // 키보드 ← → 지원
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'ArrowRight') next()
      else if (e.key === 'ArrowLeft') prev()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [next, prev])

  return (
    <div className="page">
      <header className="hero">
        <h1>consensus-build · 작동 방식</h1>
        <p>한 줄 요구사항이 기능정의서 → 구현 계획 → 코드까지 완주하는 과정을 단계별로 따라가 보세요.</p>
      </header>

      <div className="flow-wrap">
        <ReactFlow
          nodes={rfNodes}
          edges={rfEdges}
          nodeTypes={nodeTypes}
          fitView
          fitViewOptions={{ padding: 0.2 }}
          nodesDraggable={false}
          nodesConnectable={false}
          elementsSelectable={false}
          proOptions={{ hideAttribution: true }}
          minZoom={0.2}
          maxZoom={1.5}
        >
          <FitOnStep step={step} />
          <Background variant="dots" gap={22} size={1.4} color="#d3d7e0" />
          <Controls showInteractive={false} />
        </ReactFlow>
      </div>

      <div className="panel">
        <div className="panel-step">
          STEP {step + 1} / {STEPS.length}
        </div>
        <div className="panel-title">{STEPS[step].title}</div>
        <div className="panel-body">{STEPS[step].body}</div>
        <div className="panel-controls">
          <button onClick={prev} disabled={step === 0}>← 이전</button>
          {step === last ? (
            <button className="primary" onClick={reset}>↻ 처음부터</button>
          ) : (
            <button className="primary" onClick={next}>다음 →</button>
          )}
        </div>
        <div className="dots">
          {STEPS.map((_, i) => (
            <span
              key={i}
              className={`dot ${i === step ? 'active' : ''} ${i < step ? 'done' : ''}`}
              onClick={() => setStep(i)}
            />
          ))}
        </div>
      </div>

      <footer className="foot">
        <a href="https://github.com/NB3025/consensus-build">← 저장소로 돌아가기</a>
      </footer>
    </div>
  )
}

export default function App() {
  return (
    <ReactFlowProvider>
      <FlowApp />
    </ReactFlowProvider>
  )
}
