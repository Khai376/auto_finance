<script setup>
import { computed, onMounted } from "vue";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";

const { loading, error, contract, role, installments, load } = useContract();

const paidCount = computed(
  () => installments.value.filter((item) => item.status === "paid").length,
);

const remaining = computed(() =>
  installments.value.filter((item) => item.status !== "paid"),
);

const next = computed(
  () =>
    remaining.value.find((item) =>
      ["partial", "submitted", "rejected"].includes(item.status),
    ) ||
    remaining.value.find((item) => item.status === "pending") ||
    null,
);

const remainingTotal = computed(() =>
  remaining.value.reduce((total, item) => total + Number(item.amount || 0), 0),
);

const progressPercent = computed(() => {
  const total = Number(contract.value?.total_installments || 0);
  if (!total) return 0;
  return Math.min(
    100,
    Math.max(0, Math.round((paidCount.value / total) * 100)),
  );
});

const visibleInstallments = computed(() => {
  const currentIndex = installments.value.findIndex(
    (item) => item.id === next.value?.id,
  );
  if (currentIndex >= 0) {
    return installments.value.slice(
      Math.max(0, currentIndex - 1),
      currentIndex + 2,
    );
  }
  return installments.value.slice(Math.max(0, installments.value.length - 3));
});

const money = (value) =>
  new Intl.NumberFormat("th-TH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value || 0));

const statusText = (status) =>
  ({
    paid: "ชำระแล้ว",
    pending: "รอชำระ",
    partial: "ชำระบางส่วน",
    submitted: "รอตรวจสอบ",
    rejected: "ไม่อนุมัติ",
  })[status] || status;

const statusIcon = (status) => {
  if (status === "paid") return "✓";
  if (status === "submitted") return "⌛";
  if (status === "rejected") return "!";
  return "◷";
};

onMounted(load);
</script>

<template>
  <main class="app-shell">
    <div v-if="loading" class="card state">กำลังโหลดข้อมูล...</div>
    <div v-else-if="error" class="card alert error">{{ error }}</div>
    <div v-else-if="!contract" class="card alert error">ไม่พบข้อมูลสัญญา</div>

    <template v-else>
      <header class="app-header">
        <div>
          <div class="eyebrow">MY CAR PAYMENT</div>
          <h1>ค่างวดรถของฉัน</h1>
          <p>ติดตามยอดและสถานะค่างวดได้ในที่เดียว</p>
        </div>
        <div class="header-mark">🚘</div>
      </header>

      <section class="card vehicle">
        <div class="car-pic">🚙</div>
        <div class="vehicle-detail">
          <span class="label">รถในสัญญา</span>
          <h2>{{ contract.car_name }}</h2>
          <p>เลขที่สัญญา {{ contract.contract_no }}</p>
        </div>
        <div class="vehicle-badge">ใช้งานอยู่</div>
      </section>

      <section class="card summary-card">
        <div class="summary-top">
          <div>
            <span class="label">ความคืบหน้า</span>
            <h2>{{ progressPercent }}%</h2>
          </div>
          <div class="summary-counts">
            <div>
              <span>ชำระแล้ว</span><strong>{{ paidCount }} งวด</strong>
            </div>
            <div>
              <span>คงเหลือ</span><strong>{{ remaining.length }} งวด</strong>
            </div>
          </div>
        </div>

        <div class="progress">
          <i :style="{ width: progressPercent + '%' }"></i>
        </div>

        <div class="balance-box">
          <div>
            <span>ยอดเงินเรียกเก็บคงเหลือ</span>
            <small>จาก {{ contract.total_installments }} งวดทั้งหมด</small>
          </div>
          <strong>{{ money(remainingTotal) }} <small>บาท</small></strong>
        </div>
      </section>

      <section v-if="next" class="card next-card">
        <div class="section-kicker">งวดปัจจุบัน</div>
        <div class="next-head">
          <div class="installment-box">
            <small>งวดที่</small>
            <b>{{ next.installment_no }}</b>
          </div>
          <div class="next-detail">
            <span>ยอดงวดเต็ม</span>
            <h2>{{ money(next.amount) }} บาท</h2>
            <p>กำหนดชำระ {{ next.due_date || "-" }}</p>
          </div>
          <em :class="['next-status', next.status]">{{
            statusText(next.status)
          }}</em>
        </div>

        <RouterLink
          v-if="['pending', 'partial', 'rejected'].includes(next.status)"
          class="btn pay full"
          :to="'/payment/' + next.id"
        >
          <span>แนบสลิปชำระงวดนี้</span><b>→</b>
        </RouterLink>

        <template v-else-if="next.status === 'submitted'">
          <div class="submitted-message">
            <span class="submitted-icon">✓</span>
            <div>
              <strong>แนบสลิปแล้ว</strong
              ><small>กำลังรอผู้ผ่อนคนที่ 2 ตรวจสอบ</small>
            </div>
          </div>
          <RouterLink class="btn outline full" :to="'/payment/' + next.id">
            ดูรายละเอียดสลิป
          </RouterLink>
          <RouterLink
            v-if="role === 'owner'"
            class="btn approve full"
            :to="'/payment/' + next.id"
          >
            ตรวจสอบและอนุมัติสลิป
          </RouterLink>
        </template>
      </section>

      <section v-else class="card complete-card">
        <div class="complete-icon">✓</div>
        <div>
          <h3>ชำระครบแล้ว</h3>
          <p>ไม่มีงวดค้างชำระ</p>
        </div>
      </section>

      <RouterLink to="/schedule" class="schedule-card">
        <div class="schedule-icon">▦</div>
        <div class="schedule-copy">
          <strong>ตารางผ่อน</strong>
          <span>ดูยอดเต็ม กำหนดชำระ และสถานะทุกงวด</span>
        </div>
        <div class="schedule-arrow">›</div>
      </RouterLink>

      <section class="card status-card">
        <div class="section-title">
          <div>
            <span class="section-kicker">ภาพรวมล่าสุด</span>
            <h3>สถานะการผ่อน</h3>
          </div>
          <RouterLink to="/schedule">ดูทั้งหมด</RouterLink>
        </div>

        <div
          v-for="item in visibleInstallments"
          :key="item.id"
          class="status-row"
        >
          <span class="status-icon" :class="item.status">{{
            statusIcon(item.status)
          }}</span>
          <div class="status-detail">
            <b>งวดที่ {{ item.installment_no }}</b>
            <small
              >{{ money(item.amount) }} บาท ·
              {{ item.due_date || "ไม่ระบุวัน" }}</small
            >
          </div>
          <em :class="['status-badge', item.status]">{{
            statusText(item.status)
          }}</em>
        </div>
      </section>

      <BottomNav />
    </template>
  </main>
</template>

<style scoped>
* {
  box-sizing: border-box;
}
.app-shell {
  min-height: 100vh;
  padding: 20px 16px 112px;
  color: #112f55;
  background:
    radial-gradient(
      circle at 90px 40px,
      rgba(255, 255, 255, 0.24),
      transparent 190px
    ),
    linear-gradient(
      180deg,
      #168ee2 0,
      #43c8e8 245px,
      #eafaff 640px,
      #f7fbfd 100%
    );
}
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 4px 4px 17px;
  color: #fff;
}
.eyebrow {
  margin-bottom: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.6px;
  opacity: 0.76;
}
.app-header h1 {
  margin: 0;
  font-size: 27px;
  font-weight: 900;
  letter-spacing: -0.5px;
}
.app-header p {
  margin: 4px 0 0;
  color: rgba(255, 255, 255, 0.86);
  font-size: 12px;
}
.header-mark {
  display: grid;
  width: 48px;
  height: 48px;
  place-items: center;
  border: 1px solid rgba(255, 255, 255, 0.32);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.16);
  font-size: 25px;
  backdrop-filter: blur(12px);
}
.card {
  margin-bottom: 13px;
  padding: 18px;
  border: 1px solid rgba(225, 239, 247, 0.9);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 12px 35px rgba(21, 85, 125, 0.08);
}
.vehicle {
  position: relative;
  display: flex;
  align-items: center;
  gap: 14px;
  overflow: hidden;
}
.vehicle:after {
  position: absolute;
  right: -32px;
  bottom: -48px;
  width: 130px;
  height: 130px;
  border-radius: 50%;
  background: #eef8ff;
  content: "";
}
.car-pic {
  display: grid;
  width: 60px;
  height: 60px;
  flex: 0 0 60px;
  place-items: center;
  border-radius: 18px;
  background: linear-gradient(145deg, #ecf8ff, #d9f0ff);
  font-size: 36px;
}
.vehicle-detail {
  z-index: 1;
  min-width: 0;
  flex: 1;
}
.label {
  display: block;
  margin-bottom: 2px;
  color: #7990a6;
  font-size: 10px;
  font-weight: 700;
}
.vehicle h2 {
  margin: 0;
  color: #102f59;
  font-size: 20px;
  font-weight: 900;
}
.vehicle p {
  margin: 4px 0 0;
  color: #637c95;
  font-size: 11px;
}
.vehicle-badge {
  z-index: 1;
  padding: 6px 9px;
  border-radius: 99px;
  color: #178857;
  background: #e8f9ef;
  font-size: 9px;
  font-weight: 800;
}
.summary-top {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}
.summary-top h2 {
  margin: 1px 0 0;
  color: #147ed4;
  font-size: 31px;
  line-height: 1;
  font-weight: 900;
}
.summary-counts {
  display: flex;
  gap: 22px;
}
.summary-counts div {
  text-align: right;
}
.summary-counts span {
  display: block;
  color: #8093a5;
  font-size: 9px;
}
.summary-counts strong {
  display: block;
  margin-top: 2px;
  color: #173c66;
  font-size: 13px;
}
.progress {
  height: 9px;
  margin: 16px 0 15px;
  overflow: hidden;
  border-radius: 99px;
  background: #e8f0f5;
}
.progress i {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #168de4, #3bc4e7);
  box-shadow: 0 0 12px rgba(30, 151, 222, 0.35);
  transition: width 0.3s ease;
}
.balance-box {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  padding-top: 1px;
}
.balance-box span {
  display: block;
  color: #315777;
  font-size: 11px;
  font-weight: 700;
}
.balance-box div small {
  display: block;
  margin-top: 3px;
  color: #8ca0b1;
  font-size: 9px;
}
.balance-box > strong {
  color: #102f59;
  text-align: right;
  font-size: 21px;
  font-weight: 900;
  white-space: nowrap;
}
.balance-box > strong small {
  font-size: 11px;
  font-weight: 700;
}
.section-kicker {
  margin-bottom: 9px;
  color: #2387ca;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.8px;
  text-transform: uppercase;
}
.next-card {
  padding: 17px 18px 18px;
}
.next-head {
  display: grid;
  grid-template-columns: 82px minmax(0, 1fr) auto;
  align-items: center;
  gap: 14px;
}
.installment-box {
  display: flex;
  width: 82px;
  height: 78px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 20px;
  color: #fff;
  background: linear-gradient(145deg, #158bf0, #36b9ee);
  box-shadow: 0 10px 22px rgba(29, 139, 224, 0.23);
}
.installment-box small {
  font-size: 10px;
  font-weight: 700;
}
.installment-box b {
  font-size: 34px;
  line-height: 1;
  font-weight: 900;
}
.next-detail {
  min-width: 0;
}
.next-detail span {
  color: #70869b;
  font-size: 10px;
  font-weight: 700;
}
.next-detail h2 {
  margin: 4px 0;
  color: #102f59;
  font-size: 23px;
  font-weight: 900;
  white-space: nowrap;
}
.next-detail p {
  margin: 0;
  color: #70869b;
  font-size: 10px;
}
.next-status {
  align-self: flex-start;
  padding: 5px 8px;
  border-radius: 99px;
  font-size: 9px;
  font-style: normal;
  font-weight: 800;
  white-space: nowrap;
}
.next-status.pending,
.next-status.partial {
  color: #c77a08;
  background: #fff3dc;
}
.next-status.submitted {
  color: #1879c2;
  background: #e9f5ff;
}
.next-status.rejected {
  color: #c44747;
  background: #ffeded;
}
.btn {
  display: flex;
  min-height: 48px;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 15px;
  padding: 0 16px;
  border-radius: 15px;
  text-decoration: none;
  font-size: 13px;
  font-weight: 800;
}
.full {
  width: 100%;
}
.pay {
  justify-content: space-between;
  color: #fff;
  background: linear-gradient(100deg, #ff9b24, #ff6e16);
  box-shadow: 0 9px 20px rgba(238, 116, 21, 0.18);
}
.pay b {
  font-size: 20px;
}
.outline {
  margin-top: 9px;
  border: 1px solid #b9dbf4;
  color: #237fc8;
  background: #f7fbff;
}
.approve {
  margin-top: 9px;
  color: #fff;
  background: linear-gradient(100deg, #21b06a, #159457);
}
.submitted-message {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 15px;
  padding: 12px;
  border-radius: 15px;
  background: #edf9f3;
}
.submitted-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #23af68;
  font-weight: 900;
}
.submitted-message strong {
  display: block;
  color: #167847;
  font-size: 12px;
}
.submitted-message small {
  display: block;
  margin-top: 2px;
  color: #668677;
  font-size: 9px;
}
.schedule-card {
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr) 28px;
  align-items: center;
  gap: 12px;
  margin-bottom: 13px;
  padding: 14px 16px;
  border: 1px solid rgba(217, 236, 248, 0.9);
  border-radius: 21px;
  color: #153b63;
  background: linear-gradient(120deg, #fff, #f2faff);
  box-shadow: 0 10px 30px rgba(21, 85, 125, 0.07);
  text-decoration: none;
}
.schedule-icon {
  display: grid;
  width: 52px;
  height: 52px;
  place-items: center;
  border-radius: 16px;
  color: #fff;
  background: linear-gradient(145deg, #197fe1, #35b7eb);
  font-size: 24px;
}
.schedule-copy {
  min-width: 0;
}
.schedule-copy strong {
  display: block;
  font-size: 15px;
  font-weight: 900;
}
.schedule-copy span {
  display: block;
  margin-top: 3px;
  color: #7890a6;
  font-size: 9px;
}
.schedule-arrow {
  color: #2591d7;
  text-align: right;
  font-size: 31px;
  font-weight: 300;
}
.section-title {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  margin-bottom: 10px;
}
.section-title .section-kicker {
  margin: 0 0 2px;
}
.section-title h3 {
  margin: 0;
  color: #14385e;
  font-size: 17px;
  font-weight: 900;
}
.section-title a {
  padding: 5px 8px;
  border-radius: 9px;
  color: #357ead;
  background: #f1f8fd;
  text-decoration: none;
  font-size: 9px;
  font-weight: 800;
}
.status-row {
  display: flex;
  min-height: 61px;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid #edf2f5;
}
.status-row:last-child {
  border-bottom: 0;
}
.status-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 12px;
  color: #fff;
  background: #28b16a;
  font-size: 14px;
  font-style: normal;
  font-weight: 900;
}
.status-icon.pending,
.status-icon.partial {
  background: #efae3a;
}
.status-icon.submitted {
  background: #499bd8;
}
.status-icon.rejected {
  background: #e45a5a;
}
.status-detail {
  min-width: 0;
  flex: 1;
}
.status-detail b {
  display: block;
  color: #244969;
  font-size: 12px;
}
.status-detail small {
  display: block;
  margin-top: 3px;
  overflow: hidden;
  color: #8295a6;
  font-size: 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.status-badge {
  padding: 5px 8px;
  border-radius: 99px;
  font-size: 9px;
  font-style: normal;
  font-weight: 800;
  white-space: nowrap;
}
.status-badge.paid {
  color: #208754;
  background: #e7f8ee;
}
.status-badge.pending,
.status-badge.partial {
  color: #c67808;
  background: #fff3dc;
}
.status-badge.submitted {
  color: #1979bd;
  background: #e8f5ff;
}
.status-badge.rejected {
  color: #c84444;
  background: #ffeded;
}
.complete-card {
  display: flex;
  align-items: center;
  gap: 13px;
}
.complete-icon {
  display: grid;
  width: 49px;
  height: 49px;
  place-items: center;
  border-radius: 17px;
  color: #fff;
  background: #25ae68;
  font-size: 22px;
  font-weight: 900;
}
.complete-card h3 {
  margin: 0;
  color: #183e62;
  font-size: 15px;
}
.complete-card p {
  margin: 3px 0 0;
  color: #7d91a3;
  font-size: 10px;
}
.state,
.alert {
  margin-top: 30px;
  text-align: center;
}
.error {
  color: #b93535;
}
@media (max-width: 380px) {
  .app-shell {
    padding-right: 12px;
    padding-left: 12px;
  }
  .card {
    padding: 15px;
  }
  .app-header h1 {
    font-size: 24px;
  }
  .vehicle-badge {
    display: none;
  }
  .next-head {
    grid-template-columns: 74px minmax(0, 1fr);
  }
  .installment-box {
    width: 74px;
    height: 72px;
  }
  .next-status {
    grid-column: 2;
    margin-top: -4px;
    justify-self: start;
  }
  .next-detail h2 {
    font-size: 20px;
  }
  .summary-counts {
    gap: 12px;
  }
  .balance-box {
    align-items: flex-start;
    flex-direction: column;
    gap: 5px;
  }
  .balance-box > strong {
    text-align: left;
  }
  .schedule-card {
    padding: 12px 14px;
  }
}
</style>
