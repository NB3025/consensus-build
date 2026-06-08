<h1 align="center">consensus-build marketplace</h1>

<p align="center">
  <b>consensus-build</b> 플러그인을 배포하는 Claude Code 마켓플레이스
</p>

<p align="center">
  <a href="plugins/consensus-build/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge" alt="License: MIT"></a>
  <a href="https://github.com/NB3025/consensus-build/stargazers"><img src="https://img.shields.io/github/stars/NB3025/consensus-build?style=for-the-badge&color=yellow" alt="Stars"></a>
  <img src="https://img.shields.io/badge/Claude_Code-marketplace-8A2BE2?style=for-the-badge" alt="Claude Code Marketplace">
</p>

---

이 저장소는 Claude Code **플러그인 마켓플레이스**입니다. 아래 플러그인을 담고 있습니다.

## 📦 수록 플러그인

| 플러그인 | 설명 | 문서 |
|----------|------|------|
| **consensus-build** | 한 줄 기능 설명만 주면 기능정의서 → 구현 계획 → 코드 구현까지 자동 완주. 각 단계에서 Agent 3명이 병렬·독립 검토하여 합의(consensus)에 이르고, CRITICAL/MAJOR 이슈가 사라질 때까지 자율 반복. | [📖 상세 문서](plugins/consensus-build/README.md) |

## ⚡ 설치

```
/plugin marketplace add NB3025/consensus-build
/plugin install consensus-build@consensus-build-marketplace
```

> 플러그인 본체가 이 repo 안(`plugins/consensus-build/`)에 함께 들어 있고, `marketplace.json`이 이를 상대경로(`./plugins/consensus-build`)로 가리킵니다. 따라서 마켓플레이스를 add할 때 받은 로컬 사본에서 플러그인을 바로 읽어, **별도 git clone 없이 SSH 키가 없어도 설치**됩니다.

설치 후 사용법·모드·작동 방식은 **[플러그인 상세 문서](plugins/consensus-build/README.md)**를 참고하세요.

## 🗂 저장소 구조

```
.
├── .claude-plugin/
│   └── marketplace.json          # 마켓플레이스 정의 (수록 플러그인 목록)
└── plugins/
    └── consensus-build/          # 플러그인 본체
        ├── .claude-plugin/
        │   └── plugin.json
        ├── skills/build/         # /consensus-build:build 슬래시 커맨드
        ├── hooks/                # Stop / PostToolUse hooks
        ├── README.md             # 플러그인 상세 문서
        └── LICENSE
```

## 🔧 로컬에서 검증

repo 루트(`marketplace.json`이 있는 곳)에서 실행합니다.

```
claude plugin validate .
claude plugin marketplace add ~/consensus-build
```

## 📄 License

MIT — [LICENSE](plugins/consensus-build/LICENSE) 참조.
