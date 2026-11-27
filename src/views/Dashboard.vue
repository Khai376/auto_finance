<script setup>
import { computed, onMounted } from "vue";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";

const {
  loading,
  error,
  contract,
  role,
  installments,
  load,
} = useContract();

/* =========================================================
 * จำนวนงวดที่ชำระแล้ว
 * ========================================================= */
const paidCount = computed(() => {
  return installments.value.filter((item) => item.status === "paid").length;
});

/* =========================================================
 * งวดที่ยังไม่ชำระ
 * ========================================================= */
const remaining = computed(() => {
  return installments.value.filter((item) => item.status !== "paid");
});

/* =========================================================
 * งวดปัจจุบัน / งวดถัดไป
 *
 * ให้ความสำคัญกับ:
 * partial
 * submitted
 * rejected
 *
 * ก่อน pending
 * ========================================================= */
const next = computed(() => {
  return (
    remaining.value.find((item) =>
      ["partial", "submitted", "rejected"].includes(item.status),
    ) ||
    remaining.value.find((item) => item.status === "pending") ||
    null
  );
});

/* =========================================================
 * ยอดคงเหลือทั้งหมด
 *
 * ใช้ยอดเต็มของแต่ละงวดจาก installments.amount
 * ========================================================= */
const remainingTotal = computed(() => {
  return remaining.value.reduce((total, item) => {
    return total + Number(item.amount || 0);
  }, 0);
});

/* =========================================================
 * เปอร์เซ็นต์การผ่อน
 * ========================================================= */
const progressPercent = computed(() => {
  const total = Number(contract.value?.total_installments || 0);

  if (!total) {
    return 0;
  }

  const percent = Math.round((paidCount.value / total) * 100);

  return Math.min(100, Math.max(0, percent));
});

/* =========================================================
 * Format เงิน
 * ========================================================= */
const money = (value) => {
  return new Intl.NumberFormat("th-TH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value || 0));
};

/* =========================================================
 * สถานะภาษาไทย
 * ========================================================= */
const statusText = (status) => {
  return (
    {
      paid: "ชำระแล้ว",
      pending: "รอชำระ",
      partial: "ชำระบางส่วน",
      submitted: "รอตรวจสอบ",
      rejected: "ไม่อนุมัติ",
    }[status] || status
  );
};

/* =========================================================
 * Icon สถานะ
 * ========================================================= */
const statusIcon = (status) => {
  if (status === "paid") {
    return "✓";
  }

  if (status === "submitted") {
    return "⌛";
  }

  if (status === "rejected") {
    return "!";
  }

  return "◷";
};

onMounted(async () => {
  await load();
});
</script>

<template>
  <main class="app-shell">
    <!-- =========================
         Loading
    ========================== -->
    <div v-if="loading" class="card state">
      กำลังโหลด...
    </div>

    <!-- =========================
         Error
    ========================== -->
    <div v-else-if="error" class="card alert error">
      {{ error }}
    </div>

    <!-- =========================
         Contract not found
    ========================== -->
    <div v-else-if="!contract" class="card alert error">
      ไม่พบข้อมูลสัญญา
    </div>

    <!-- =========================
         Dashboard
    ========================== -->
    <template v-else>
      <!-- HEADER -->
      <header class="app-header">
        <div>
          <small>🚘</small>

          <h1>
            ค่างวดรถของฉัน
          </h1>

          <p>
            จัดการทุกค่างวดได้ในที่เดียว
          </p>
        </div>

        <span class="bell">
          🔔
        </span>
      </header>

      <!-- =========================
           VEHICLE
      ========================== -->
      <section class="card vehicle">
        <div class="car-pic">
          🚙
        </div>

        <div class="vehicle-detail">
          <h2>
            {{ contract.car_name }}
          </h2>

          <p>
            สัญญา {{ contract.contract_no }}
          </p>
        </div>
      </section>

      <!-- =========================
           CONTRACT SUMMARY
      ========================== -->
      <section class="card summary-card">
        <div class="split">
          <div>
            <span>
              ชำระแล้ว
            </span>

            <strong>
              {{ paidCount }} /
              {{ contract.total_installments }}
              งวด
            </strong>
          </div>

          <div class="right">
            <span>
              งวดคงเหลือ
            </span>

            <strong>
              {{ remaining.length }} งวด
            </strong>
          </div>
        </div>

        <!-- Progress -->
        <div class="progress">
          <i
            :style="{
              width: progressPercent + '%',
            }"
          ></i>
        </div>

        <div class="remaining-total">
          <span>
            ยอดเงินเรียกเก็บคงเหลือ
          </span>

          <h2>
            {{ money(remainingTotal) }} บาท
          </h2>
        </div>
      </section>

      <!-- =========================
           NEXT INSTALLMENT
      ========================== -->
      <section
        v-if="next"
        class="card next-card"
      >
        <div class="next-head">
          <!-- หมายเลขงวด -->
          <div class="installment-box">
            <small>
              งวดที่
            </small>

            <b>
              {{ next.installment_no }}
            </b>
          </div>

          <!-- ยอดเต็มงวด -->
          <div class="next-detail">
            <span>
              ยอดงวดเต็ม
            </span>

            <h2>
              {{ money(next.amount) }} บาท
            </h2>

            <p>
              กำหนด {{ next.due_date || "-" }}
            </p>
          </div>
        </div>

        <!-- =========================================
             pending / partial / rejected

             คนที่ 1 หรือคนที่ 2
             สามารถเข้าหน้าแนบสลิปได้
        ========================================== -->
        <RouterLink
          v-if="
            ['pending', 'partial', 'rejected'].includes(
              next.status,
            )
          "
          class="btn pay full"
          :to="'/payment/' + next.id"
        >
          บันทึกชำระ / แนบสลิป
        </RouterLink>

        <!-- =========================================
             มีคนแนบสลิปแล้ว
        ========================================== -->
        <template v-else-if="next.status === 'submitted'">
          <div class="submitted-message">
            <span class="submitted-icon">
              ✓
            </span>

            <div>
              <strong>
                แนบสลิปแล้ว
              </strong>

              <small>
                รอตรวจสอบการชำระ
              </small>
            </div>
          </div>

          <!-- ทั้งสองคนสามารถเข้าไปดูได้ -->
          <RouterLink
            class="btn outline full"
            :to="'/payment/' + next.id"
          >
            ดูรายละเอียดสลิป
          </RouterLink>

          <!-- เจ้าของตรวจสอบ/อนุมัติ -->
          <RouterLink
            v-if="role === 'owner'"
            class="btn approve full"
            :to="'/payment/' + next.id"
          >
            ตรวจสอบสลิปและอนุมัติ
          </RouterLink>
        </template>
      </section>

      <!-- =========================
           กรณีผ่อนครบแล้ว
      ========================== -->
      <section
        v-else
        class="card complete-card"
      >
        <div class="complete-icon">
          ✓
        </div>

        <h3>
          ชำระครบแล้ว
        </h3>

        <p>
          ไม่มีงวดค้างชำระ
        </p>
      </section>

      <!-- =========================
           QUICK MENU
      ========================== -->
      <section class="quick">
        <RouterLink to="/schedule">
          <span class="quick-icon">
            ▦
          </span>

          <span>
            ตารางผ่อน
          </span>
        </RouterLink>

        <RouterLink to="/history">
          <span class="quick-icon">
            ▤
          </span>

          <span>
            ประวัติชำระ
          </span>
        </RouterLink>

        <RouterLink to="/documents">
          <span class="quick-icon">
            ▱
          </span>

          <span>
            เอกสารรถ
          </span>
        </RouterLink>

        <RouterLink to="/documents?add=1">
          <span class="quick-icon">
            ＋
          </span>

          <span>
            เพิ่มเอกสาร
          </span>
        </RouterLink>
      </section>

      <!-- =========================
           INSTALLMENT STATUS
      ========================== -->
      <section class="card status-card">
        <div class="section-title">
          <h3>
            สถานะการผ่อน
          </h3>

          <RouterLink to="/schedule">
            ดูทั้งหมด ›
          </RouterLink>
        </div>

        <div
          v-for="item in installments.slice(
            Math.max(0, paidCount - 1),
            paidCount + 2,
          )"
          :key="item.id"
          class="status-row"
        >
          <span
            class="status-icon"
            :class="item.status"
          >
            {{ statusIcon(item.status) }}
          </span>

          <div class="status-detail">
            <b>
              งวดที่ {{ item.installment_no }}
            </b>

            <!-- แสดงยอดเต็มของงวด -->
            <small>
              {{ money(item.amount) }} บาท
            </small>
          </div>

          <em
            :class="[
              'status-badge',
              item.status,
            ]"
          >
            {{ statusText(item.status) }}
          </em>
        </div>
      </section>

      <!-- =========================
           BOTTOM NAV
      ========================== -->
      <BottomNav />
    </template>
  </main>
</template>

<style scoped>
/* =========================================================
   BASE
========================================================= */

.app-shell {
  min-height: 100vh;
  padding: 18px 16px 110px;
  background:
    linear-gradient(
      180deg,
      #3498eb 0px,
      #51c8ed 220px,
      #dff8ff 600px,
      #f4fcff 100%
    );
  color: #0e3265;
}

/* =========================================================
   HEADER
========================================================= */

.app-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  padding: 6px 2px 14px;
  color: #ffffff;
}

.app-header small {
  display: block;
  margin-bottom: 3px;
  font-size: 17px;
}

.app-header h1 {
  margin: 0;
  color: #ffffff;
  font-size: 24px;
  font-weight: 800;
  line-height: 1.2;
}

.app-header p {
  margin: 3px 0 0;
  color: rgba(255, 255, 255, 0.95);
  font-size: 14px;
  font-weight: 500;
}

.bell {
  padding-top: 13px;
  font-size: 18px;
}

/* =========================================================
   CARD
========================================================= */

.card {
  margin-bottom: 12px;
  padding: 18px;
  border-radius: 22px;
  background: #ffffff;
  box-shadow:
    0 7px 22px rgba(21, 81, 123, 0.06);
}

/* =========================================================
   VEHICLE
========================================================= */

.vehicle {
  display: flex;
  align-items: center;
  gap: 15px;
}

.car-pic {
  flex: 0 0 auto;
  font-size: 48px;
  line-height: 1;
}

.vehicle-detail {
  min-width: 0;
}

.vehicle h2 {
  margin: 0;
  color: #123469;
  font-size: 22px;
  font-weight: 800;
}

.vehicle p {
  margin: 3px 0 0;
  color: #294b75;
  font-size: 14px;
}

/* =========================================================
   SUMMARY
========================================================= */

.split {
  display: flex;
  justify-content: space-between;
  gap: 20px;
}

.split > div {
  min-width: 0;
}

.split span {
  display: block;
  margin-bottom: 2px;
  color: #36557e;
  font-size: 13px;
  font-weight: 600;
}

.split strong {
  display: block;
  color: #123469;
  font-size: 24px;
  font-weight: 800;
}

.split .right {
  text-align: right;
}

.progress {
  width: 100%;
  height: 10px;
  margin: 13px 0 17px;
  overflow: hidden;
  border-radius: 999px;
  background: #dce7ef;
}

.progress i {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: #318ce7;
  transition: width 0.3s ease;
}

.remaining-total span {
  display: block;
  color: #36557e;
  font-size: 13px;
  font-weight: 600;
}

.remaining-total h2 {
  margin: 9px 0 0;
  color: #123469;
  font-size: 24px;
  font-weight: 800;
}

/* =========================================================
   NEXT INSTALLMENT
========================================================= */

.next-card {
  padding: 16px 18px 18px;
}

.next-head {
  display: flex;
  align-items: center;
  gap: 22px;
  margin-bottom: 15px;
}

.installment-box {
  display: flex;
  width: 91px;
  height: 82px;
  flex: 0 0 91px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 15px;
  background:
    linear-gradient(
      135deg,
      #267cf0,
      #3eb8f4
    );
  color: #ffffff;
}

.installment-box small {
  font-size: 12px;
  font-weight: 700;
}

.installment-box b {
  margin-top: 1px;
  font-size: 39px;
  font-weight: 800;
  line-height: 1;
}

.next-detail {
  min-width: 0;
  flex: 1;
}

.next-detail span {
  color: #234a77;
  font-size: 13px;
  font-weight: 700;
}

.next-detail h2 {
  margin: 7px 0;
  color: #123469;
  font-size: 25px;
  font-weight: 800;
}

.next-detail p {
  margin: 0;
  color: #36557e;
  font-size: 14px;
}

/* =========================================================
   BUTTON
========================================================= */

.btn {
  display: flex;
  min-height: 44px;
  box-sizing: border-box;
  align-items: center;
  justify-content: center;
  border-radius: 13px;
  text-decoration: none;
  font-size: 15px;
  font-weight: 700;
}

.full {
  width: 100%;
}

.pay {
  color: #ffffff;
  background:
    linear-gradient(
      90deg,
      #ff9815,
      #ff6f0f
    );
}

.outline {
  margin-top: 9px;
  border: 1px solid #4c9ff0;
  color: #287ed3;
  background: #ffffff;
}

.approve {
  margin-top: 9px;
  color: #ffffff;
  background: #26ad63;
}

/* =========================================================
   SUBMITTED
========================================================= */

.submitted-message {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 4px 0 12px;
  padding: 12px 13px;
  border-radius: 13px;
  background: #ecf9f2;
}

.submitted-icon {
  display: flex;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #ffffff;
  background: #28b468;
  font-weight: 800;
}

.submitted-message strong {
  display: block;
  color: #167849;
  font-size: 14px;
}

.submitted-message small {
  display: block;
  margin-top: 2px;
  color: #5d7d6e;
  font-size: 12px;
}

/* =========================================================
   QUICK MENU
========================================================= */

.quick {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-bottom: 12px;
}

.quick a {
  display: flex;
  min-width: 0;
  min-height: 86px;
  padding: 10px 5px;
  box-sizing: border-box;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 9px;
  border-radius: 17px;
  color: #23466d;
  background: #ffffff;
  text-align: center;
  text-decoration: none;
  font-size: 11px;
  font-weight: 600;
  box-shadow:
    0 6px 18px rgba(21, 81, 123, 0.04);
}

.quick-icon {
  color: #278bf0;
  font-size: 24px;
  font-weight: 500;
  line-height: 1;
}

/* =========================================================
   STATUS
========================================================= */

.section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 13px;
}

.section-title h3 {
  margin: 0;
  color: #123469;
  font-size: 17px;
  font-weight: 800;
}

.section-title a {
  color: #31557c;
  text-decoration: none;
  font-size: 12px;
  font-weight: 600;
}

.status-row {
  display: flex;
  min-height: 54px;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid #e4edf3;
}

.status-row:last-child {
  border-bottom: none;
}

.status-icon {
  display: flex;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #ffffff;
  background: #2ab569;
  font-size: 16px;
  font-style: normal;
  font-weight: 800;
}

.status-icon.rejected {
  background: #e95b5b;
}

.status-icon.submitted {
  background: #eaa428;
}

.status-detail {
  min-width: 0;
  flex: 1;
}

.status-detail b {
  display: block;
  color: #21456e;
  font-size: 14px;
}

.status-detail small {
  display: block;
  margin-top: 1px;
  color: #6e849c;
  font-size: 12px;
}

.status-badge {
  flex: 0 0 auto;
  padding: 5px 9px;
  border-radius: 9px;
  font-size: 11px;
  font-style: normal;
  font-weight: 700;
  white-space: nowrap;
}

.status-badge.paid {
  color: #29915a;
  background: #e5f8eb;
}

.status-badge.pending {
  color: #d7810d;
  background: #fff2d5;
}

.status-badge.partial {
  color: #d7810d;
  background: #fff2d5;
}

.status-badge.submitted {
  color: #177ccc;
  background: #e8f4ff;
}

.status-badge.rejected {
  color: #d34949;
  background: #ffebeb;
}

/* =========================================================
   COMPLETE
========================================================= */

.complete-card {
  text-align: center;
}

.complete-icon {
  display: flex;
  width: 54px;
  height: 54px;
  margin: 0 auto 9px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #ffffff;
  background: #2ab569;
  font-size: 26px;
  font-weight: 800;
}

.complete-card h3 {
  margin: 0;
  color: #123469;
}

.complete-card p {
  margin: 4px 0 0;
  color: #6e849c;
  font-size: 13px;
}

/* =========================================================
   STATE
========================================================= */

.state,
.alert {
  margin-top: 30px;
  text-align: center;
}

.error {
  color: #b93535;
}

/* =========================================================
   MOBILE
========================================================= */

@media (max-width: 380px) {
  .app-shell {
    padding-right: 12px;
    padding-left: 12px;
  }

  .card {
    padding: 15px;
  }

  .vehicle h2 {
    font-size: 19px;
  }

  .next-head {
    gap: 15px;
  }

  .installment-box {
    width: 82px;
    flex-basis: 82px;
  }

  .next-detail h2 {
    font-size: 21px;
  }

  .quick {
    gap: 6px;
  }

  .quick a {
    min-height: 80px;
    padding-right: 3px;
    padding-left: 3px;
    font-size: 10px;
  }

  .split strong {
    font-size: 21px;
  }
}
</style>