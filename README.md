# ระบบค่างวดรถยนต์

- งวด 1-21 ถูกกำหนดเป็น “ชำระแล้ว” อัตโนมัติ
- เริ่มบันทึกการชำระที่งวด 22
- แนบสลิป ดูประวัติ ยอดคงเหลือ และงวดคงเหลือ
- เพิ่มและเปิดดูเอกสารรถ
- รุ่นนี้เก็บข้อมูลใน localStorage ของอุปกรณ์ เหมาะสำหรับใช้งานส่วนตัวเครื่องเดียว

## รันในเครื่อง
```bash
npm install
npm run dev
```

## Deploy GitHub Pages
1. เปลี่ยนชื่อ repo ใน `vite.config.js` จาก `/car-payment-system/` ให้ตรงชื่อ repository
2. รัน:
```bash
git init
git add .
git commit -m "initial car payment system"
git branch -M main
git remote add origin https://github.com/USERNAME/car-payment-system.git
git push -u origin main
GITHUB_PAGES=true npm run build
npm run deploy
```
3. GitHub > Settings > Pages > Source เลือก `Deploy from a branch` และเลือก `gh-pages / root`

## Deploy Vercel
นำ repository เข้า Vercel แล้วใช้ Build Command `npm run build` และ Output Directory `dist`
# auto_finance
# auto_finance
