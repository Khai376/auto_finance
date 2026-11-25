import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ command }) => ({
  plugins: [vue()],

  // Local dev ใช้ /
  // Production build ใช้ /auto_finance/
  base: command === 'build'
    ? '/auto_finance/'
    : '/'
}))