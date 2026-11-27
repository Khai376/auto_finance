<script setup>
import { computed, onMounted, ref } from "vue";
import { supabase } from "../supabase.js";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";

const { loading, error, membership, load } = useContract();

const rows = ref([]);
const pageError = ref("");
const historyLoading = ref(false);

const totalPaid = computed(() =>
  rows.value
    .filter((item) => item.status === "paid")
    .reduce((sum, item) => sum + Number(item.amount || 0), 0),
);

const paidCount = computed(
  () => rows.value.filter((item) => item.status === "paid").length,
);

const money = (value) =>
  new Intl.NumberFormat("th-TH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value || 0));

const formatDateTime = (value) => {
  if (!value) return "-";

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";

  return new Intl.DateTimeFormat("th-TH", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
};

const statusText = (status) =>
  ({
    paid: "ชำระแล้ว",
    pending: "รอชำระ",
    partial: "ชำระบางส่วน",
    submitted: "รอตรวจสอบ",
    rejected: "ไม่อนุมัติ",
  })[status] ||
  status ||
  "-";

const statusIcon = (status) => {
  if (status === "paid") return "✓";
  if (status === "submitted") return "⌛";
  if (status === "rejected") return "!";
  return "◷";
};

async function init() {
  pageError.value = "";
  historyLoading.value = true;

  try {
    const ok = await load();
    if (!ok) return;

    const contractId = membership.value?.contract_id;
    if (!contractId) {
      pageError.value = "ไม่พบข้อมูลสัญญา";
      return;
    }

    const { data, error: queryError } = await supabase
      .from("installments")
      .select(
        `
        id,
        installment_no,
        amount,
        due_date,
        status,
        verified_at,
        installment_slips(
          id,
          amount,
          uploaded_by,
          storage_path,
          file_name,
          mime_type,
          file_size,
          note,
          created_at
        )
      `,
      )
      .eq("contract_id", contractId)
      .order("installment_no", { ascending: false });

    if (queryError) throw queryError;

    rows.value = (data || [])
      .filter((item) => item.installment_slips?.length)
      .map((item) => ({
        ...item,
        latestSlip: [...item.installment_slips].sort(
          (a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0),
        )[0],
      }));
  } catch (e) {
    console.error("History.init:", e);
    pageError.value = e?.message || "โหลดประวัติชำระไม่สำเร็จ";
  } finally {
    historyLoading.value = false;
  }
}

onMounted(init);
</script>

<template>
  <main class="app-shell">
    <header class="page-head">
      <RouterLink to="/dashboard" class="back-btn">‹</RouterLink>
      <div>
        <h1>ประวัติชำระ</h1>
        <p>รายการที่มีการแนบหลักฐานการชำระแล้ว</p>
      </div>
    </header>

    <div v-if="loading || historyLoading" class="card state">
      <span class="loader"></span>
      กำลังโหลดประวัติ...
    </div>

    <div v-else-if="error || pageError" class="card alert error">
      {{ pageError || error }}
    </div>

    <template v-else>
      <section class="summary-grid">
        <div class="summary-card primary-summary">
          <span>รายการที่มีสลิป</span>
          <strong>{{ rows.length }}</strong>
          <small>งวด</small>
        </div>

        <div class="summary-card">
          <span>ชำระสำเร็จ</span>
          <strong>{{ paidCount }}</strong>
          <small>งวด</small>
        </div>
      </section>

      <section v-if="rows.length" class="total-card">
        <div>
          <span>ยอดงวดที่ชำระสำเร็จ</span>
          <small>คำนวณจากยอดเต็มของงวดที่สถานะชำระแล้ว</small>
        </div>
        <strong>{{ money(totalPaid) }} <small>บาท</small></strong>
      </section>

      <section v-if="!rows.length" class="card empty-state">
        <div class="empty-icon">▤</div>
        <h2>ยังไม่มีประวัติชำระ</h2>
        <p>เมื่อมีการแนบสลิป รายการจะแสดงที่หน้านี้</p>
        <RouterLink to="/schedule" class="empty-btn">ดูตารางผ่อน</RouterLink>
      </section>

      <section v-else class="history-list">
        <RouterLink
          v-for="item in rows"
          :key="item.id"
          :to="'/payment/' + item.id"
          class="history-card"
        >
          <div class="history-top">
            <div :class="['status-icon', item.status]">
              {{ statusIcon(item.status) }}
            </div>

            <div class="history-title">
              <span>ค่างวด</span>
              <h2>งวดที่ {{ item.installment_no }}</h2>
              <small v-if="item.due_date">กำหนด {{ item.due_date }}</small>
            </div>

            <em :class="['status-badge', item.status]">
              {{ statusText(item.status) }}
            </em>
          </div>

          <div class="amount-box">
            <div>
              <span>ยอดเต็มของงวด</span>
              <strong>{{ money(item.amount) }} บาท</strong>
            </div>
            <div class="slip-count">
              <span>หลักฐาน</span>
              <strong>{{ item.installment_slips.length }} สลิป</strong>
            </div>
          </div>

          <div class="history-meta">
            <div>
              <span>แนบเมื่อ</span>
              <strong>{{ formatDateTime(item.latestSlip?.created_at) }}</strong>
            </div>

            <div>
              <span>ยอดในสลิป</span>
              <strong>{{ money(item.latestSlip?.amount) }} บาท</strong>
            </div>
          </div>

          <div class="open-row">
            <span>ดูรายละเอียดและหลักฐาน</span>
            <b>›</b>
          </div>
        </RouterLink>
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
  padding: 20px 15px 108px;
  color: #14385f;
  background:
    radial-gradient(
      circle at 90% 20px,
      rgba(255, 255, 255, 0.22),
      transparent 190px
    ),
    linear-gradient(
      180deg,
      #258fe5 0,
      #4bc7e8 230px,
      #e9f9ff 600px,
      #f7fcfe 100%
    );
}
.page-head {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
  color: #fff;
}
.page-head h1 {
  margin: 0;
  color: #fff;
  font-size: 25px;
  font-weight: 900;
  letter-spacing: -0.35px;
}
.page-head p {
  margin: 2px 0 0;
  color: rgba(255, 255, 255, 0.84);
  font-size: 10px;
}
.back-btn {
  display: flex;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 14px;
  color: #fff;
  background: rgba(255, 255, 255, 0.15);
  text-decoration: none;
  font-size: 30px;
}
.card {
  padding: 18px;
  border-radius: 22px;
  background: #fff;
  box-shadow: 0 11px 32px rgba(20, 84, 125, 0.08);
}
.summary-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 11px;
}
.summary-card {
  position: relative;
  overflow: hidden;
  padding: 16px;
  border: 1px solid rgba(226, 239, 247, 0.9);
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 8px 25px rgba(20, 84, 125, 0.06);
}
.summary-card span {
  display: block;
  color: #748ba1;
  font-size: 9px;
  font-weight: 700;
}
.summary-card strong {
  display: inline-block;
  margin-top: 4px;
  color: #173c64;
  font-size: 27px;
  font-weight: 900;
}
.summary-card small {
  margin-left: 3px;
  color: #71889d;
  font-size: 10px;
}
.primary-summary:after {
  position: absolute;
  right: -25px;
  bottom: -35px;
  width: 90px;
  height: 90px;
  border-radius: 50%;
  background: #eaf7ff;
  content: "";
}
.total-card {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 12px;
  padding: 15px 17px;
  border-radius: 20px;
  background: linear-gradient(115deg, #135fbd, #229fdf);
  box-shadow: 0 11px 25px rgba(25, 109, 183, 0.18);
  color: #fff;
}
.total-card span {
  display: block;
  font-size: 10px;
  font-weight: 800;
}
.total-card div small {
  display: block;
  margin-top: 3px;
  color: rgba(255, 255, 255, 0.72);
  font-size: 8px;
}
.total-card > strong {
  font-size: 20px;
  font-weight: 900;
  white-space: nowrap;
}
.total-card > strong small {
  font-size: 10px;
}
.history-list {
  display: grid;
  gap: 11px;
}
.history-card {
  display: block;
  padding: 15px;
  border: 1px solid rgba(226, 239, 247, 0.92);
  border-radius: 22px;
  color: inherit;
  background: #fff;
  box-shadow: 0 10px 30px rgba(20, 84, 125, 0.075);
  text-decoration: none;
}
.history-top {
  display: flex;
  align-items: center;
  gap: 10px;
}
.status-icon {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  place-items: center;
  border-radius: 14px;
  color: #fff;
  background: #2ab16b;
  font-size: 17px;
  font-weight: 900;
}
.status-icon.pending,
.status-icon.partial {
  background: #eba83b;
}
.status-icon.submitted {
  background: #4799d7;
}
.status-icon.rejected {
  background: #df5b5b;
}
.history-title {
  min-width: 0;
  flex: 1;
}
.history-title span {
  display: block;
  color: #8a9cac;
  font-size: 8px;
}
.history-title h2 {
  margin: 1px 0 0;
  color: #15395f;
  font-size: 15px;
  font-weight: 900;
}
.history-title small {
  display: block;
  margin-top: 2px;
  color: #7c91a4;
  font-size: 8px;
}
.status-badge {
  padding: 5px 8px;
  border-radius: 99px;
  font-size: 8px;
  font-style: normal;
  font-weight: 800;
  white-space: nowrap;
}
.status-badge.paid {
  color: #218956;
  background: #e8f8ef;
}
.status-badge.pending,
.status-badge.partial {
  color: #c57908;
  background: #fff3dc;
}
.status-badge.submitted {
  color: #1979bd;
  background: #e8f5ff;
}
.status-badge.rejected {
  color: #c74646;
  background: #ffeded;
}
.amount-box {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 15px;
  margin-top: 13px;
  padding: 12px;
  border-radius: 15px;
  background: #f5faff;
}
.amount-box span {
  display: block;
  color: #7890a5;
  font-size: 8px;
}
.amount-box strong {
  display: block;
  margin-top: 2px;
  color: #14385f;
  font-size: 15px;
  font-weight: 900;
}
.slip-count {
  text-align: right;
}
.slip-count strong {
  font-size: 11px;
  color: #2f76aa;
}
.history-meta {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding: 13px 2px 11px;
}
.history-meta > div:last-child {
  text-align: right;
}
.history-meta span {
  display: block;
  color: #8a9cac;
  font-size: 8px;
}
.history-meta strong {
  display: block;
  margin-top: 2px;
  color: #3c5c78;
  font-size: 9px;
  font-weight: 800;
}
.open-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 10px;
  border-top: 1px solid #edf2f5;
  color: #2383c6;
  font-size: 9px;
  font-weight: 800;
}
.open-row b {
  font-size: 20px;
  font-weight: 400;
}
.state,
.alert {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  margin-top: 25px;
  text-align: center;
}
.error {
  color: #bf3e3e;
}
.loader {
  width: 18px;
  height: 18px;
  border: 2px solid #dceaf4;
  border-top-color: #258fe5;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
.empty-state {
  margin-top: 7px;
  text-align: center;
}
.empty-icon {
  display: grid;
  width: 58px;
  height: 58px;
  margin: 0 auto 9px;
  place-items: center;
  border-radius: 18px;
  color: #258ad2;
  background: #e9f6ff;
  font-size: 27px;
}
.empty-state h2 {
  margin: 0;
  color: #173c64;
  font-size: 17px;
}
.empty-state p {
  margin: 5px 0 15px;
  color: #7e92a4;
  font-size: 10px;
}
.empty-btn {
  display: flex;
  min-height: 43px;
  align-items: center;
  justify-content: center;
  border-radius: 13px;
  color: #fff;
  background: linear-gradient(100deg, #258fe5, #35b7e8);
  text-decoration: none;
  font-size: 11px;
  font-weight: 800;
}
@media (max-width: 370px) {
  .app-shell {
    padding-right: 12px;
    padding-left: 12px;
  }
  .total-card {
    align-items: flex-start;
    flex-direction: column;
    gap: 7px;
  }
  .history-meta {
    grid-template-columns: 1fr;
  }
  .history-meta > div:last-child {
    text-align: left;
  }
  .summary-card {
    padding: 14px;
  }
}
</style>
