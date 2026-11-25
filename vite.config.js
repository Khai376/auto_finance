import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  // ถ้า deploy ที่ https://USERNAME.github.io/REPO/ ให้เปลี่ยนเป็น '/REPO/'
  // ถ้าใช้ Vercel/Netlify หรือ custom domain ให้ใช้ '/'
  base: process.env.GITHUB_PAGES === 'true' ? '/car-payment-system/' : '/'
})
