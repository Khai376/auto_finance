<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";

import { supabase } from "../supabase.js";
import BottomNav from "../components/BottomNav.vue";

const router = useRouter();

const loading = ref(true);
const loggingOut = ref(false);
const errorMessage = ref("");

const user = ref(null);

const loginName = computed(() => {
  const metadata = user.value?.user_metadata || {};

  return (
    metadata.full_name ||
    metadata.display_name ||
    metadata.name ||
    user.value?.email ||
    "ผู้ใช้งาน"
  );
});

const email = computed(() => {
  return user.value?.email || "-";
});

const lastSignIn = computed(() => {
  const value = user.value?.last_sign_in_at;

  if (!value) {
    return "-";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat("th-TH", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
});

const userInitial = computed(() => {
  const text = loginName.value || email.value || "U";

  return text
    .trim()
    .charAt(0)
    .toUpperCase();
});

const loadUser = async () => {
  loading.value = true;
  errorMessage.value = "";

  try {
    const {
      data,
      error,
    } = await supabase.auth.getUser();

    if (error) {
      throw error;
    }

    if (!data?.user) {
      router.replace("/login");
      return;
    }

    user.value = data.user;
  } catch (error) {
    console.error(
      "Settings.loadUser:",
      error,
    );

    errorMessage.value =
      error?.message ||
      "ไม่สามารถโหลดข้อมูลผู้ใช้งานได้";
  } finally {
    loading.value = false;
  }
};

const logout = async () => {
  if (loggingOut.value) {
    return;
  }

  loggingOut.value = true;
  errorMessage.value = "";

  try {
    const { error } =
      await supabase.auth.signOut();

    if (error) {
      throw error;
    }

    router.replace("/login");
  } catch (error) {
    console.error(
      "Settings.logout:",
      error,
    );

    errorMessage.value =
      error?.message ||
      "ไม่สามารถออกจากระบบได้";
  } finally {
    loggingOut.value = false;
  }
};

onMounted(loadUser);
</script>

<template>
  <main class="app-shell">

    <!-- HEADER -->

    <header class="page-head">

      <RouterLink
        to="/dashboard"
        class="back-btn"
      >
        ‹
      </RouterLink>

      <div>
        <h1>
          ตั้งค่า
        </h1>

        <p>
          บัญชีและการใช้งานระบบ
        </p>
      </div>

      <div class="head-icon">
        ⚙
      </div>

    </header>

    <!-- LOADING -->

    <section
      v-if="loading"
      class="card state"
    >
      <span class="loader"></span>

      กำลังโหลดข้อมูล...
    </section>

    <template v-else>

      <!-- ERROR -->

      <div
        v-if="errorMessage"
        class="message error-message"
      >
        <span>
          !
        </span>

        <p>
          {{ errorMessage }}
        </p>
      </div>

      <!-- PROFILE -->

      <section class="profile-card">

        <div class="avatar">
          {{ userInitial }}
        </div>

        <div class="profile-info">

          <span class="profile-label">
            บัญชีที่เข้าสู่ระบบ
          </span>

          <h2>
            {{ loginName }}
          </h2>

          <p>
            {{ email }}
          </p>

        </div>

        <div class="online-badge">
          <span></span>
          ออนไลน์
        </div>

      </section>

      <!-- ACCOUNT INFORMATION -->

      <section class="card">

        <div class="section-title">

          <div>
            <span>
              ACCOUNT
            </span>

            <h3>
              ข้อมูลบัญชี
            </h3>
          </div>

          <div class="section-icon">
            👤
          </div>

        </div>

        <!-- USER -->

        <div class="info-row">

          <div class="info-icon blue">
            Aa
          </div>

          <div class="info-content">

            <span>
              ชื่อ Login
            </span>

            <strong>
              {{ loginName }}
            </strong>

          </div>

        </div>

        <!-- EMAIL -->

        <div class="info-row">

          <div class="info-icon cyan">
            @
          </div>

          <div class="info-content">

            <span>
              Email
            </span>

            <strong>
              {{ email }}
            </strong>

          </div>

        </div>

        <!-- LAST LOGIN -->

        <div class="info-row">

          <div class="info-icon green">
            ◷
          </div>

          <div class="info-content">

            <span>
              เข้าสู่ระบบล่าสุด
            </span>

            <strong>
              {{ lastSignIn }}
            </strong>

          </div>

        </div>

      </section>

      <!-- SYSTEM -->

      <section class="card">

        <div class="section-title">

          <div>
            <span>
              SYSTEM
            </span>

            <h3>
              การใช้งานระบบ
            </h3>
          </div>

          <div class="section-icon">
            ⚙
          </div>

        </div>

        <div class="system-info">

          <div>
            <span>
              การยืนยันตัวตน
            </span>

            <strong>
              Supabase Auth
            </strong>
          </div>

          <div>
            <span>
              สถานะ
            </span>

            <strong class="active">
              พร้อมใช้งาน
            </strong>
          </div>

        </div>

        <p class="system-note">
          ข้อมูลสิทธิ์ ผู้ใช้งาน และสัญญา
          เชื่อมต่อกับ Supabase
        </p>

      </section>

      <!-- LOGOUT -->

      <section class="card logout-card">

        <div class="logout-info">

          <div class="logout-icon">
            ↪
          </div>

          <div>

            <strong>
              ออกจากระบบ
            </strong>

            <span>
              คุณจะต้องเข้าสู่ระบบใหม่
              เพื่อใช้งานครั้งถัดไป
            </span>

          </div>

        </div>

        <button
          type="button"
          class="logout-btn"
          :disabled="loggingOut"
          @click="logout"
        >

          <span
            v-if="loggingOut"
            class="small-loader"
          ></span>

          {{
            loggingOut
              ? "กำลังออกจากระบบ..."
              : "ออกจากระบบ"
          }}

        </button>

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

  padding:
    20px
    15px
    110px;

  color: #153b63;

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

/* HEADER */

.page-head {
  display: grid;

  grid-template-columns:
    42px
    1fr
    42px;

  align-items: center;

  gap: 11px;

  margin-bottom: 16px;

  color: #ffffff;
}

.page-head h1 {
  margin: 0;

  color: #ffffff;

  font-size: 25px;
  font-weight: 900;
}

.page-head p {
  margin: 2px 0 0;

  color:
    rgba(
      255,
      255,
      255,
      0.82
    );

  font-size: 10px;
}

.back-btn,
.head-icon {
  display: grid;

  width: 42px;
  height: 42px;

  place-items: center;

  border:
    1px solid
    rgba(
      255,
      255,
      255,
      0.24
    );

  border-radius: 14px;

  color: #ffffff;

  background:
    rgba(
      255,
      255,
      255,
      0.15
    );

  text-decoration: none;
}

.back-btn {
  font-size: 30px;
}

.head-icon {
  font-size: 19px;
}

/* CARD */

.card,
.profile-card {
  margin-bottom: 12px;

  padding: 17px;

  border:
    1px solid
    rgba(
      226,
      239,
      247,
      0.92
    );

  border-radius: 23px;

  background:
    rgba(
      255,
      255,
      255,
      0.97
    );

  box-shadow:
    0 11px 32px
    rgba(
      20,
      84,
      125,
      0.075
    );
}

/* PROFILE */

.profile-card {
  display: flex;

  align-items: center;

  gap: 12px;
}

.avatar {
  display: grid;

  width: 54px;
  height: 54px;

  flex: 0 0 54px;

  place-items: center;

  border-radius: 18px;

  color: #ffffff;

  background:
    linear-gradient(
      145deg,
      #1886e6,
      #3cbbe9
    );

  box-shadow:
    0 8px 18px
    rgba(
      28,
      135,
      211,
      0.2
    );

  font-size: 20px;
  font-weight: 900;
}

.profile-info {
  min-width: 0;

  flex: 1;
}

.profile-label {
  display: block;

  color: #8799a9;

  font-size: 8px;
  font-weight: 700;
}

.profile-info h2 {
  margin: 2px 0 0;

  overflow: hidden;

  color: #173c64;

  font-size: 15px;
  font-weight: 900;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.profile-info p {
  margin: 3px 0 0;

  overflow: hidden;

  color: #71889c;

  font-size: 9px;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.online-badge {
  display: flex;

  align-items: center;

  gap: 4px;

  padding:
    5px
    7px;

  border-radius: 99px;

  color: #228657;

  background: #e8f8ef;

  font-size: 8px;
  font-weight: 800;
}

.online-badge span {
  width: 6px;
  height: 6px;

  border-radius: 50%;

  background: #28ae67;
}

/* SECTION TITLE */

.section-title {
  display: flex;

  align-items: center;
  justify-content: space-between;

  margin-bottom: 8px;
}

.section-title span {
  display: block;

  color: #2384c5;

  font-size: 8px;
  font-weight: 900;

  letter-spacing: 0.8px;
}

.section-title h3 {
  margin: 2px 0 0;

  color: #15395f;

  font-size: 16px;
  font-weight: 900;
}

.section-icon {
  display: grid;

  width: 37px;
  height: 37px;

  place-items: center;

  border-radius: 12px;

  background: #eef8ff;

  font-size: 17px;
}

/* INFO */

.info-row {
  display: flex;

  min-height: 62px;

  align-items: center;

  gap: 11px;

  border-bottom:
    1px solid #edf2f5;
}

.info-row:last-child {
  border-bottom: none;
}

.info-icon {
  display: grid;

  width: 38px;
  height: 38px;

  flex: 0 0 38px;

  place-items: center;

  border-radius: 12px;

  font-size: 10px;
  font-weight: 900;
}

.info-icon.blue {
  color: #177ecc;
  background: #eaf6ff;
}

.info-icon.cyan {
  color: #1189a8;
  background: #e7f9fb;
}

.info-icon.green {
  color: #218956;
  background: #e8f8ef;
}

.info-content {
  min-width: 0;

  flex: 1;
}

.info-content span {
  display: block;

  color: #8799a9;

  font-size: 8px;
}

.info-content strong {
  display: block;

  margin-top: 2px;

  overflow-wrap: anywhere;

  color: #284c6d;

  font-size: 11px;
  font-weight: 800;
}

/* SYSTEM */

.system-info {
  display: grid;

  grid-template-columns:
    1fr
    1fr;

  gap: 8px;

  margin-top: 12px;
}

.system-info > div {
  padding: 11px;

  border-radius: 13px;

  background: #f5f9fc;
}

.system-info span {
  display: block;

  color: #8396a7;

  font-size: 8px;
}

.system-info strong {
  display: block;

  margin-top: 2px;

  color: #294d6e;

  font-size: 10px;
}

.system-info strong.active {
  color: #208956;
}

.system-note {
  margin:
    10px
    2px
    0;

  color: #8193a3;

  font-size: 8px;
  line-height: 1.5;
}

/* LOGOUT */

.logout-card {
  padding: 15px;
}

.logout-info {
  display: flex;

  align-items: center;

  gap: 10px;

  margin-bottom: 13px;
}

.logout-icon {
  display: grid;

  width: 40px;
  height: 40px;

  flex: 0 0 40px;

  place-items: center;

  border-radius: 13px;

  color: #d84c4c;

  background: #ffeded;

  font-size: 18px;
}

.logout-info strong {
  display: block;

  color: #3d5367;

  font-size: 11px;
}

.logout-info span {
  display: block;

  margin-top: 2px;

  color: #8999a7;

  font-size: 8px;
}

.logout-btn {
  display: flex;

  width: 100%;
  min-height: 44px;

  align-items: center;
  justify-content: center;

  gap: 7px;

  border:
    1px solid #f2b9b9;

  border-radius: 13px;

  color: #d84747;

  background: #fff4f4;

  font: inherit;

  font-size: 10px;
  font-weight: 900;

  cursor: pointer;
}

.logout-btn:disabled {
  opacity: 0.6;
}

/* MESSAGE */

.message {
  display: flex;

  align-items: center;

  gap: 8px;

  margin-bottom: 11px;

  padding: 11px;

  border-radius: 13px;
}

.message > span {
  display: grid;

  width: 25px;
  height: 25px;

  flex: 0 0 25px;

  place-items: center;

  border-radius: 50%;

  color: #ffffff;

  background: #df5555;

  font-size: 11px;
  font-weight: 900;
}

.message p {
  margin: 0;

  font-size: 9px;
}

.error-message {
  color: #a53d3d;

  background: #ffeded;
}

/* LOADING */

.state {
  display: flex;

  align-items: center;
  justify-content: center;

  gap: 8px;

  margin-top: 20px;

  color: #71899d;

  font-size: 10px;
}

.loader,
.small-loader {
  width: 18px;
  height: 18px;

  border:
    2px solid #dbeaf4;

  border-top-color: #258fe5;

  border-radius: 50%;

  animation:
    spin 0.8s linear infinite;
}

.small-loader {
  width: 15px;
  height: 15px;

  border-color:
    rgba(
      216,
      71,
      71,
      0.25
    );

  border-top-color: #d84747;
}

@keyframes spin {
  to {
    transform:
      rotate(360deg);
  }
}

/* ANDROID + IPHONE */

@media (max-width: 380px) {

  .app-shell {
    padding-right: 12px;
    padding-left: 12px;
  }

  .online-badge {
    padding:
      4px
      6px;

    font-size: 7px;
  }

  .system-info {
    grid-template-columns:
      1fr;
  }
}
</style>