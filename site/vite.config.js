import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// 빌드 산출물을 repo 루트의 docs/ 로 출력 (GitHub Pages source = docs/).
// base는 project pages 경로(https://NB3025.github.io/consensus-build/)에 맞춘다.
export default defineConfig({
  plugins: [react()],
  base: '/consensus-build/',
  build: {
    outDir: '../docs',
    emptyOutDir: true,
  },
})
