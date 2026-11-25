<script setup>
import { computed, onMounted } from "vue";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";
const { loading, error, contract, role, installments, load } = useContract();
const paidCount = computed(
  () => installments.value.filter((x) => x.status === "paid").length,
);
const remaining = computed(() =>
  installments.value.filter((x) => x.status !== "paid"),
);
const next = computed(
  () =>
    remaining.value.find((x) =>
      ["partial", "submitted", "rejected"].includes(x.status),
    ) ||
    remaining.value.find((x) => x.status === "pending") ||
    null,
);
const remainingTotal = computed(() =>
  remaining.value.reduce((s, x) => s + Number(x.amount || 0), 0),
);
const payer1Total = computed(() =>
  remaining.value.reduce((s, x) => s + Number(x.payer1_amount || 0), 0),
);
const payer2Total = computed(() =>
  remaining.value.reduce((s, x) => s + Number(x.payer2_amount || 0), 0),
);
const money = (v) =>
  new Intl.NumberFormat("th-TH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(v || 0));
const st = (s) =>
  ({
    paid: "ชำระแล้ว",
    pending: "รอชำระ",
    partial: "ชำระบางส่วน",
    submitted: "รอตรวจสอบ",
    rejected: "ไม่อนุมัติ",
  })[s] || s;
onMounted(load);
</script>
<template>
  <main class="app-shell">
    <div v-if="loading" class="card state">กำลังโหลด...</div>
    <div v-else-if="error" class="card alert error">{{ error }}</div>
    <div v-else-if="!contract" class="card alert error">ไม่พบข้อมูลสัญญา</div>
    <template v-else
      ><header class="app-header">
        <div>
          <small>🚘</small>
          <h1>ค่างวดรถของฉัน</h1>
          <p>จัดการทุกค่างวดได้ในที่เดียว</p>
        </div>
        <span class="bell">🔔</span>
      </header>
      <section class="card vehicle">
        <div class="car-pic">🚙</div>
        <div>
          <h2>{{ contract.car_name }}</h2>
          <p>สัญญา {{ contract.contract_no }}</p>
          <!-- <em>{{
            role === "owner" ? "คนที่ 2 · เจ้าของ" : "คนที่ 1 · ผู้ผ่อน"
          }}</em> -->
        </div>
      </section>
      <section class="card">
        <div class="split">
          <div>
            <span>ชำระแล้ว</span
            ><strong
              >{{ paidCount }} / {{ contract.total_installments }} งวด</strong
            >
          </div>
          <div class="right">
            <span>งวดคงเหลือ</span><strong>{{ remaining.length }} งวด</strong>
          </div>
        </div>
        <div class="progress">
          <i
            :style="{
              width:
                Math.round((paidCount / contract.total_installments) * 100) +
                '%',
            }"
          ></i>
        </div>
        <span>ยอดเงินเรียกเก็บคงเหลือ</span>
        <h2>{{ money(remainingTotal) }} บาท</h2>
      </section>
      <section class="card" v-if="role === 'owner'">
        <h3>ยอดรับผิดชอบรวม</h3>
        <div class="responsibility">
          <div>
            <span>👤 ผู้ผ่อนคนที่ 1</span><b>{{ money(payer1Total) }} บาท</b>
          </div>
          <div class="orange-soft">
            <span>👤 ผู้ผ่อนคนที่ 2</span><b>{{ money(payer2Total) }} บาท</b>
          </div>
        </div>
      </section>
      <section v-if="next" class="card">
        <div class="next-head">
          <div class="installment-box">
            <small>งวดที่</small><b>{{ next.installment_no }}</b>
          </div>
          <div v-if="role != 'owner'">
            <span >ยอดงวดรวม</span>
            <h2>{{ money(next.payer1_amount) }}  บาท</h2>
            <p>กำหนด {{ next.due_date || "-" }}</p>
          </div>
          <div v-if="role == 'owner'">
            <span >ยอดงวดรวม</span>
           <h2>{{ money(next.payer2_amount) }}  บาท</h2>
            <p>กำหนด {{ next.due_date || "-" }}</p>
          </div>
        </div>
       
        <RouterLink class="btn pay full" :to="'/payment/' + next.id"
          >บันทึกชำระ / แนบสลิป</RouterLink
        ><RouterLink
          v-if="role === 'owner'"
          class="btn outline full"
          :to="'/payment/' + next.id"
          >ตรวจสอบสลิปและอนุมัติ</RouterLink
        >
      </section>
      <section class="quick">
        <RouterLink to="/schedule">▦<span>ตารางผ่อน</span></RouterLink
        ><RouterLink to="/history">▤<span>ประวัติชำระ</span></RouterLink
        ><RouterLink to="/documents">▱<span>เอกสารรถ</span></RouterLink
        ><RouterLink to="/documents?add=1"
          >＋<span>เพิ่มเอกสาร</span></RouterLink
        >
      </section>
      <section class="card">
        <div class="section-title">
          <h3>สถานะการผ่อน</h3>
          <RouterLink to="/schedule">ดูทั้งหมด ›</RouterLink>
        </div>
        <div
          v-for="i in installments.slice(
            Math.max(0, paidCount - 1),
            paidCount + 2,
          )"
          :key="i.id"
          class="status-row"
        >
          <span class="status-icon">{{ i.status === "paid" ? "✓" : "◷" }}</span>
          <div>
            <b>งวดที่ {{ i.installment_no }}</b
            ><small>{{ money(i.amount) }} บาท</small>
          </div>
          <em :class="i.status">{{ st(i.status) }}</em>
        </div>
      </section>
      <BottomNav
    /></template>
  </main>
</template>
