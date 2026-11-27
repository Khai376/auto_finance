<script setup>
import { computed, nextTick, onMounted } from "vue";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";

const { loading, error, installments, load } = useContract();

const currentInstallment = computed(() =>
  installments.value.find((item) => item.status !== "paid") || null,
);

const money = (value) =>
  new Intl.NumberFormat("th-TH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value || 0));

const formatDate = (value) => {
  if (!value) return "-";
  const [year, month, day] = String(value).split("-");
  if (!year || !month || !day) return value;
  return `${day}/${month}/${year}`;
};

const statusText = (status) =>
  ({
    paid: "ชำระแล้ว",
    pending: "รอชำระ",
    partial: "ชำระบางส่วน",
    submitted: "รอตรวจสอบ",
    rejected: "ไม่อนุมัติ",
  })[status] || status;

const scrollToCurrentInstallment = async () => {
  await nextTick();
  if (!currentInstallment.value) return;

  window.setTimeout(() => {
    const element = document.getElementById(
      `installment-${currentInstallment.value.id}`,
    );

    element?.scrollIntoView({
      behavior: "smooth",
      block: "center",
    });
  }, 250);
};

onMounted(async () => {
  await load();
  await scrollToCurrentInstallment();
});
</script>

<template>
  <main class="app-shell">
    <header class="page-head">
      <RouterLink to="/dashboard" class="back-btn">‹</RouterLink>
      <div>
        <h1>ตารางผ่อน</h1>
        <p>กำหนดชำระและยอดเต็มของแต่ละงวด</p>
      </div>
    </header>

    <div v-if="loading" class="card state">กำลังโหลด...</div>
    <div v-else-if="error" class="card alert error">{{ error }}</div>

    <template v-else>
      <section class="summary-card">
        <div>
          <span>จำนวนงวดทั้งหมด</span>
          <strong>{{ installments.length }} <small>งวด</small></strong>
        </div>
        <div v-if="currentInstallment" class="current-summary">
          <span>งวดที่ต้องจัดการ</span>
          <strong>งวด {{ currentInstallment.installment_no }}</strong>
        </div>
        <div class="summary-icon">▦</div>
      </section>

      <section class="schedule-card">
        <div class="table-head">
          <span>งวด</span>
          <span>กำหนดชำระ</span>
          <span class="right">ยอดเต็ม</span>
        </div>

        <RouterLink
          v-for="item in installments"
          :id="`installment-${item.id}`"
          :key="item.id"
          :to="'/payment/' + item.id"
          :class="[
            'schedule-row',
            { current: item.id === currentInstallment?.id },
          ]"
        >
          <div class="installment-no">
            <span>งวด</span>
            <strong>{{ item.installment_no }}</strong>
          </div>

          <div class="due-date">
            <span>กำหนดชำระ</span>
            <strong>{{ formatDate(item.due_date) }}</strong>
            <small :class="['status', item.status]">{{ statusText(item.status) }}</small>
          </div>

          <div class="amount">
            <strong>{{ money(item.amount) }}</strong>
            <span>บาท</span>
          </div>

          <span class="arrow">›</span>
        </RouterLink>
      </section>

      <BottomNav />
    </template>
  </main>
</template>

<style scoped>
*{box-sizing:border-box}.app-shell{min-height:100vh;padding:20px 15px 105px;color:#153b63;background:linear-gradient(180deg,#258fe5 0,#49c4e7 210px,#eafaff 600px,#f7fcfe 100%)}.page-head{display:flex;align-items:center;gap:12px;margin-bottom:16px;color:#fff}.page-head h1{margin:0;color:#fff;font-size:25px;font-weight:900;letter-spacing:-.5px}.page-head p{margin:2px 0 0;color:rgba(255,255,255,.82);font-size:11px}.back-btn{display:flex;width:42px;height:42px;flex:0 0 42px;align-items:center;justify-content:center;border:1px solid rgba(255,255,255,.22);border-radius:14px;color:#fff;background:rgba(255,255,255,.15);text-decoration:none;font-size:30px}.summary-card{display:grid;grid-template-columns:1fr auto 51px;align-items:center;gap:14px;margin-bottom:12px;padding:17px 18px;border-radius:22px;background:rgba(255,255,255,.96);box-shadow:0 10px 30px rgba(20,84,125,.08)}.summary-card span{display:block;margin-bottom:3px;color:#748ba1;font-size:10px;font-weight:600}.summary-card strong{color:#123862;font-size:25px;font-weight:900}.summary-card strong small{font-size:12px}.current-summary{padding-left:14px;border-left:1px solid #e5eef4}.current-summary strong{font-size:13px;color:#1885d5}.summary-icon{display:flex;width:51px;height:51px;align-items:center;justify-content:center;border-radius:16px;color:#fff;background:linear-gradient(145deg,#1886e6,#3cbbe9);font-size:25px;box-shadow:0 8px 20px rgba(32,139,215,.2)}.schedule-card{overflow:hidden;margin-bottom:14px;border-radius:23px;background:#fff;box-shadow:0 12px 35px rgba(20,84,125,.08)}.table-head{display:grid;grid-template-columns:65px 1fr 105px;align-items:center;padding:13px 45px 10px 16px;color:#8a9cac;background:#f8fbfd;font-size:9px;font-weight:800}.table-head .right{text-align:right}.schedule-row{position:relative;display:grid;grid-template-columns:65px minmax(0,1fr) 105px 20px;min-height:75px;padding:10px 15px;align-items:center;color:inherit;text-decoration:none;border-bottom:1px solid #edf2f5;transition:background .15s ease,transform .15s ease}.schedule-row:last-child{border-bottom:none}.schedule-row:active{background:#f3f9fd}.schedule-row.current{background:linear-gradient(90deg,#eaf7ff 0,#f8fcff 45%,#fff 100%)}.schedule-row.current::before{position:absolute;top:9px;bottom:9px;left:0;width:4px;border-radius:0 7px 7px 0;background:#168ce2;content:""}.installment-no{display:flex;width:52px;height:52px;flex-direction:column;align-items:center;justify-content:center;border-radius:15px;background:#eef7ff}.installment-no span{color:#7194b4;font-size:8px;font-weight:700}.installment-no strong{margin-top:1px;color:#197ed0;font-size:19px;font-weight:900;line-height:1}.schedule-row.current .installment-no{background:linear-gradient(145deg,#1688e8,#38b9ea);box-shadow:0 6px 14px rgba(31,139,216,.2)}.schedule-row.current .installment-no span,.schedule-row.current .installment-no strong{color:#fff}.due-date{min-width:0}.due-date>span{display:block;color:#8799a9;font-size:8px}.due-date>strong{display:block;margin-top:2px;color:#294d70;font-size:11px;font-weight:800}.status{display:inline-block;margin-top:5px;padding:3px 6px;border-radius:99px;font-size:8px;font-weight:800}.status.paid{color:#218956;background:#e8f8ef}.status.pending,.status.partial{color:#c77a08;background:#fff3dd}.status.submitted{color:#197bbf;background:#e7f5ff}.status.rejected{color:#c74646;background:#ffeded}.amount{text-align:right}.amount strong{display:block;color:#123862;font-size:13px;font-weight:900;white-space:nowrap}.amount span{display:block;margin-top:1px;color:#8a9cad;font-size:8px}.arrow{color:#4097d1;text-align:right;font-size:22px;font-weight:300}.card{padding:18px;border-radius:22px;background:#fff}.state,.alert{margin-top:25px;text-align:center}.error{color:#c13e3e}@media(max-width:380px){.app-shell{padding-right:12px;padding-left:12px}.summary-card{grid-template-columns:1fr auto}.summary-icon{display:none}.schedule-row{grid-template-columns:58px minmax(0,1fr) 88px 16px;padding-right:11px;padding-left:11px}.table-head{grid-template-columns:58px 1fr 88px;padding-right:37px;padding-left:11px}.installment-no{width:47px;height:47px}.amount strong{font-size:11px}.current-summary{padding-left:10px}}
</style>
