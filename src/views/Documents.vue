<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue";
import { supabase } from "../supabase.js";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";

const { contract, user, load } = useContract();

const docs = ref([]);
const name = ref("");
const file = ref(null);
const fileInputKey = ref(0);
const message = ref("");
const messageType = ref("info");
const loading = ref(false);
const saving = ref(false);
const showPreview = ref(false);
const previewUrl = ref("");
const previewDoc = ref(null);

const fileName = computed(() => file.value?.name || "");
const fileSize = computed(() => formatFileSize(file.value?.size));

function formatFileSize(bytes) {
  const size = Number(bytes || 0);
  if (!size) return "";
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
}

function fileIcon(doc) {
  const type = String(doc?.type || "").toLowerCase();
  if (type.includes("pdf")) return "PDF";
  if (type.startsWith("image/")) return "IMG";
  return "DOC";
}

async function loadDocuments() {
  if (!contract.value?.contract_no) return;

  const { data, error } = await supabase
    .from("car_documents")
    .select("*")
    .eq("contract_no", contract.value.contract_no)
    .order("created_at", { ascending: false });

  if (error) throw error;
  docs.value = data || [];
}

async function init() {
  loading.value = true;
  message.value = "";

  try {
    const ok = await load();
    if (!ok) return;
    await loadDocuments();
  } catch (error) {
    console.error("Documents init:", error);
    messageType.value = "error";
    message.value = error?.message || "โหลดข้อมูลเอกสารไม่สำเร็จ";
  } finally {
    loading.value = false;
  }
}

function onFileChange(event) {
  file.value = event.target.files?.[0] || null;
  message.value = "";
}

function safeFileName(fileNameValue) {
  const rawExt = fileNameValue.includes(".")
    ? fileNameValue.split(".").pop()
    : "bin";
  const ext =
    String(rawExt)
      .toLowerCase()
      .replace(/[^a-z0-9]/g, "") || "bin";
  return `${crypto.randomUUID()}.${ext}`;
}

function clearForm() {
  name.value = "";
  file.value = null;
  fileInputKey.value += 1;
}

async function addDocument() {
  message.value = "";

  if (!name.value.trim()) {
    messageType.value = "error";
    message.value = "กรุณากรอกชื่อเอกสาร";
    return;
  }

  if (!file.value) {
    messageType.value = "error";
    message.value = "กรุณาเลือกไฟล์";
    return;
  }

  if (!contract.value?.id || !contract.value?.contract_no || !user.value?.id) {
    messageType.value = "error";
    message.value = "ไม่พบข้อมูลสัญญาหรือผู้ใช้งาน";
    return;
  }

  if (file.value.size > 20 * 1024 * 1024) {
    messageType.value = "error";
    message.value = "ไฟล์ต้องมีขนาดไม่เกิน 20 MB";
    return;
  }

  saving.value = true;
  let storagePath = null;

  try {
    storagePath = [
      contract.value.id,
      user.value.id,
      safeFileName(file.value.name),
    ].join("/");

    const { error: uploadError } = await supabase.storage
      .from("car-documents")
      .upload(storagePath, file.value, {
        contentType: file.value.type || undefined,
        upsert: false,
      });

    if (uploadError) throw uploadError;

    const { error: insertError } = await supabase.from("car_documents").insert({
      contract_no: contract.value.contract_no,
      user_id: user.value.id,
      uploaded_by: user.value.id,
      name: name.value.trim(),
      type: file.value.type || "application/octet-stream",
      file_path: storagePath,
    });

    if (insertError) {
      await supabase.storage.from("car-documents").remove([storagePath]);
      throw insertError;
    }

    clearForm();
    messageType.value = "success";
    message.value = "เพิ่มเอกสารเรียบร้อย";
    await loadDocuments();
  } catch (error) {
    console.error("Add document:", error);
    messageType.value = "error";
    message.value = error?.message || "เพิ่มเอกสารไม่สำเร็จ";
  } finally {
    saving.value = false;
  }
}

async function viewDocument(doc) {
  message.value = "";

  try {
    const { data, error } = await supabase.storage
      .from("car-documents")
      .createSignedUrl(doc.file_path, 300);

    if (error) throw error;
    if (!data?.signedUrl) throw new Error("ไม่พบ URL สำหรับเปิดเอกสาร");

    previewDoc.value = doc;
    previewUrl.value = data.signedUrl;
    showPreview.value = true;
    document.body.style.overflow = "hidden";
  } catch (error) {
    console.error("View document:", error);
    messageType.value = "error";
    message.value = error?.message || "เปิดเอกสารไม่สำเร็จ";
  }
}

function closePreview() {
  showPreview.value = false;
  previewUrl.value = "";
  previewDoc.value = null;
  document.body.style.overflow = "";
}

function openFullPreview() {
  if (!previewUrl.value) return;
  window.open(previewUrl.value, "_blank", "noopener,noreferrer");
}

function onKeydown(event) {
  if (event.key === "Escape" && showPreview.value) closePreview();
}

function formatDate(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

onMounted(() => {
  init();
  window.addEventListener("keydown", onKeydown);
});

onUnmounted(() => {
  window.removeEventListener("keydown", onKeydown);
  document.body.style.overflow = "";
});
</script>

<template>
  <main class="app-shell">
    <header class="page-head">
      <RouterLink to="/dashboard" class="back-btn">‹</RouterLink>
      <div>
        <h1>เอกสารรถ</h1>
        <p>จัดเก็บเอกสารสำคัญของรถและสัญญา</p>
      </div>
      <div class="head-icon">▱</div>
    </header>

    <div v-if="message" :class="['message-box', messageType]">
      <span>{{ messageType === "success" ? "✓" : "!" }}</span>
      <p>{{ message }}</p>
    </div>

    <section v-if="contract" class="vehicle-strip">
      <div class="vehicle-icon">🚙</div>
      <div>
        <span>เอกสารสำหรับ</span>
        <strong>{{ contract.car_name }}</strong>
        <small>สัญญา {{ contract.contract_no }}</small>
      </div>
      <em>{{ docs.length }} ไฟล์</em>
    </section>

    <section class="card add-card">
      <div class="section-title">
        <div>
          <span>NEW DOCUMENT</span>
          <h2>เพิ่มเอกสาร</h2>
        </div>
        <div class="section-icon">＋</div>
      </div>

      <label class="field">
        <span>ชื่อเอกสาร</span>
        <div class="input-shell">
          <span class="input-icon">Aa</span>
          <input
            v-model="name"
            type="text"
            maxlength="120"
            placeholder="เช่น พ.ร.บ. / ประกัน / สำเนาทะเบียนรถ"
            :disabled="saving"
          />
        </div>
      </label>

      <label class="upload-box">
        <input
          :key="fileInputKey"
          type="file"
          accept="image/jpeg,image/png,image/webp,application/pdf"
          :disabled="saving"
          @change="onFileChange"
        />

        <template v-if="!file">
          <div class="upload-symbol">↑</div>
          <strong>เลือกไฟล์เอกสาร</strong>
          <small>รองรับ JPG, PNG, WEBP และ PDF · สูงสุด 20 MB</small>
        </template>

        <template v-else>
          <div class="selected-icon">✓</div>
          <div class="selected-copy">
            <strong>{{ fileName }}</strong>
            <small>{{ fileSize }}</small>
          </div>
        </template>
      </label>

      <button
        type="button"
        class="primary-btn"
        :disabled="saving"
        @click="addDocument"
      >
        <span v-if="saving" class="loader small-loader"></span>
        {{ saving ? "กำลังเพิ่มเอกสาร..." : "เพิ่มเอกสาร" }}
      </button>
    </section>

    <section class="card documents-card">
      <div class="list-head">
        <div>
          <span>MY DOCUMENTS</span>
          <h2>รายการเอกสาร</h2>
        </div>
        <b>{{ docs.length }}</b>
      </div>

      <div v-if="loading" class="state">
        <span class="loader"></span>
        กำลังโหลดเอกสาร...
      </div>

      <div v-else-if="!docs.length" class="empty-state">
        <div class="empty-icon">▱</div>
        <h3>ยังไม่มีเอกสาร</h3>
        <p>เอกสารที่เพิ่มจะแสดงอยู่ในรายการนี้</p>
      </div>

      <div v-else class="document-list">
        <article v-for="doc in docs" :key="doc.id" class="document-row">
          <div
            :class="[
              'doc-type',
              { pdf: String(doc.type || '').includes('pdf') },
            ]"
          >
            {{ fileIcon(doc) }}
          </div>

          <div class="document-detail">
            <strong>{{ doc.name }}</strong>
            <span>{{ formatDate(doc.created_at) }}</span>
            <small>{{
              String(doc.type || "ไฟล์เอกสาร")
                .replace("application/", "")
                .replace("image/", "")
            }}</small>
          </div>

          <button type="button" class="open-btn" @click="viewDocument(doc)">
            <span>เปิด</span>
            <b>›</b>
          </button>
        </article>
      </div>
    </section>

    <BottomNav />

    <Teleport to="body">
      <div
        v-if="showPreview"
        class="preview-overlay"
        @click.self="closePreview"
      >
        <section
          class="preview-modal"
          role="dialog"
          aria-modal="true"
          :aria-label="previewDoc?.name || 'ตัวอย่างเอกสาร'"
        >
          <header class="preview-head">
            <div>
              <span>DOCUMENT PREVIEW</span>
              <h3>{{ previewDoc?.name || "เอกสาร" }}</h3>
            </div>
            <button
              type="button"
              class="close-preview"
              aria-label="ปิด"
              @click="closePreview"
            >
              ×
            </button>
          </header>

          <div class="preview-body">
            <img
              v-if="String(previewDoc?.type || '').startsWith('image/')"
              :src="previewUrl"
              :alt="previewDoc?.name || 'เอกสาร'"
              class="preview-image"
            />
            <iframe
              v-else-if="String(previewDoc?.type || '').includes('pdf')"
              :src="previewUrl"
              class="preview-pdf"
              title="ตัวอย่างเอกสาร PDF"
            ></iframe>
            <div v-else class="unsupported-preview">
              <div>DOC</div>
              <strong>ไม่รองรับการแสดงตัวอย่างไฟล์ชนิดนี้</strong>
            </div>
          </div>

          <footer class="preview-actions">
            <button
              type="button"
              class="preview-secondary"
              @click="closePreview"
            >
              ปิด
            </button>
            <button
              type="button"
              class="preview-primary"
              @click="openFullPreview"
            >
              เปิดเต็มหน้าจอ
            </button>
          </footer>
        </section>
      </div>
    </Teleport>
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
      #4bc7e8 240px,
      #e9f9ff 610px,
      #f7fcfe 100%
    );
}
.page-head {
  display: grid;
  grid-template-columns: 42px 1fr 42px;
  align-items: center;
  gap: 11px;
  margin-bottom: 15px;
  color: #fff;
}
.page-head h1 {
  margin: 0;
  color: #fff;
  font-size: 25px;
  font-weight: 900;
  letter-spacing: -0.4px;
}
.page-head p {
  margin: 2px 0 0;
  color: rgba(255, 255, 255, 0.82);
  font-size: 10px;
}
.back-btn,
.head-icon {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 14px;
  color: #fff;
  background: rgba(255, 255, 255, 0.15);
  text-decoration: none;
  backdrop-filter: blur(10px);
}
.back-btn {
  font-size: 30px;
}
.head-icon {
  font-size: 20px;
}
.message-box {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 11px;
  padding: 11px 13px;
  border-radius: 14px;
  font-size: 10px;
  font-weight: 700;
}
.message-box > span {
  display: grid;
  width: 25px;
  height: 25px;
  flex: 0 0 25px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  font-size: 12px;
  font-weight: 900;
}
.message-box p {
  margin: 0;
}
.message-box.success {
  color: #176f45;
  background: #e7f8ef;
}
.message-box.success > span {
  background: #28ae67;
}
.message-box.error,
.message-box.info {
  color: #a53d3d;
  background: #ffeded;
}
.message-box.error > span,
.message-box.info > span {
  background: #df5555;
}
.vehicle-strip {
  display: flex;
  align-items: center;
  gap: 11px;
  margin-bottom: 12px;
  padding: 13px 15px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 10px 28px rgba(21, 84, 125, 0.08);
}
.vehicle-icon {
  display: grid;
  width: 46px;
  height: 46px;
  flex: 0 0 46px;
  place-items: center;
  border-radius: 15px;
  background: #eaf7ff;
  font-size: 27px;
}
.vehicle-strip > div:nth-child(2) {
  min-width: 0;
  flex: 1;
}
.vehicle-strip span,
.vehicle-strip small {
  display: block;
  color: #8094a6;
  font-size: 8px;
}
.vehicle-strip strong {
  display: block;
  margin: 2px 0;
  color: #173c64;
  font-size: 13px;
  font-weight: 900;
}
.vehicle-strip em {
  padding: 5px 8px;
  border-radius: 99px;
  color: #217dbd;
  background: #e9f6ff;
  font-size: 8px;
  font-style: normal;
  font-weight: 800;
  white-space: nowrap;
}
.card {
  margin-bottom: 12px;
  padding: 17px;
  border: 1px solid rgba(226, 239, 247, 0.92);
  border-radius: 23px;
  background: #fff;
  box-shadow: 0 11px 32px rgba(20, 84, 125, 0.075);
}
.section-title,
.list-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}
.section-title span,
.list-head span {
  display: block;
  color: #2284c8;
  font-size: 8px;
  font-weight: 900;
  letter-spacing: 0.9px;
}
.section-title h2,
.list-head h2 {
  margin: 2px 0 0;
  color: #15395f;
  font-size: 17px;
  font-weight: 900;
}
.section-icon {
  display: grid;
  width: 39px;
  height: 39px;
  place-items: center;
  border-radius: 13px;
  color: #fff;
  background: linear-gradient(145deg, #1886e6, #3bb9e8);
  font-size: 23px;
}
.list-head b {
  display: grid;
  min-width: 33px;
  height: 27px;
  padding: 0 7px;
  place-items: center;
  border-radius: 10px;
  color: #2584c4;
  background: #eaf6ff;
  font-size: 11px;
}
.field {
  display: block;
  margin-bottom: 12px;
}
.field > span {
  display: block;
  margin: 0 0 6px 2px;
  color: #536f88;
  font-size: 10px;
  font-weight: 800;
}
.input-shell {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 0 12px;
  border: 1px solid #dbe8f0;
  border-radius: 14px;
  background: #f9fcfe;
}
.input-icon {
  color: #2786c8;
  font-size: 10px;
  font-weight: 900;
}
.input-shell input {
  width: 100%;
  height: 46px;
  border: 0;
  outline: 0;
  color: #193d62;
  background: transparent;
  font: inherit;
  font-size: 12px;
}
.input-shell input::placeholder {
  color: #9babb8;
}
.upload-box {
  display: flex;
  min-height: 130px;
  padding: 15px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 1.5px dashed #9bcdee;
  border-radius: 17px;
  background: #f4faff;
  text-align: center;
  cursor: pointer;
}
.upload-box input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
}
.upload-symbol {
  display: grid;
  width: 43px;
  height: 43px;
  margin-bottom: 7px;
  place-items: center;
  border-radius: 14px;
  color: #fff;
  background: linear-gradient(145deg, #218ae4, #41bae8);
  font-size: 23px;
  font-weight: 800;
}
.upload-box > strong {
  color: #2d6592;
  font-size: 11px;
}
.upload-box > small {
  margin-top: 4px;
  color: #8ba0b1;
  font-size: 8px;
}
.selected-icon {
  display: grid;
  width: 43px;
  height: 43px;
  margin-bottom: 7px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #29ad69;
  font-size: 17px;
  font-weight: 900;
}
.selected-copy {
  max-width: 100%;
}
.selected-copy strong {
  display: block;
  overflow: hidden;
  color: #28567d;
  font-size: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.selected-copy small {
  display: block;
  margin-top: 3px;
  color: #8ba0b1;
  font-size: 8px;
}
.primary-btn {
  display: flex;
  width: 100%;
  min-height: 46px;
  margin-top: 12px;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: 0;
  border-radius: 14px;
  color: #fff;
  background: linear-gradient(100deg, #258fe5, #35b7e8);
  box-shadow: 0 8px 18px rgba(31, 139, 210, 0.18);
  font: inherit;
  font-size: 11px;
  font-weight: 900;
  cursor: pointer;
}
.primary-btn:disabled {
  opacity: 0.58;
  cursor: not-allowed;
}
.document-list {
  display: grid;
}
.document-row {
  display: grid;
  grid-template-columns: 45px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  min-height: 68px;
  padding: 10px 0;
  border-bottom: 1px solid #edf2f5;
}
.document-row:last-child {
  border-bottom: 0;
}
.doc-type {
  display: grid;
  width: 45px;
  height: 45px;
  place-items: center;
  border-radius: 14px;
  color: #2582c4;
  background: #eaf6ff;
  font-size: 9px;
  font-weight: 900;
}
.doc-type.pdf {
  color: #d04b4b;
  background: #ffeded;
}
.document-detail {
  min-width: 0;
}
.document-detail strong {
  display: block;
  overflow: hidden;
  color: #234968;
  font-size: 11px;
  font-weight: 900;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.document-detail span {
  display: block;
  margin-top: 3px;
  color: #8195a6;
  font-size: 8px;
}
.document-detail small {
  display: inline-block;
  margin-top: 4px;
  padding: 2px 5px;
  border-radius: 6px;
  color: #6e879a;
  background: #f2f6f8;
  font-size: 7px;
  text-transform: uppercase;
}
.open-btn {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 7px 8px;
  border: 0;
  border-radius: 10px;
  color: #237fc0;
  background: #eef8ff;
  font: inherit;
  font-size: 9px;
  font-weight: 800;
  cursor: pointer;
}
.open-btn b {
  font-size: 17px;
  font-weight: 400;
}
.state {
  display: flex;
  min-height: 110px;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: #7890a4;
  font-size: 10px;
}
.loader {
  width: 18px;
  height: 18px;
  border: 2px solid #dceaf4;
  border-top-color: #258fe5;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
.small-loader {
  width: 15px;
  height: 15px;
  border-color: rgba(255, 255, 255, 0.45);
  border-top-color: #fff;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
.empty-state {
  padding: 23px 10px;
  text-align: center;
}
.empty-icon {
  display: grid;
  width: 55px;
  height: 55px;
  margin: 0 auto 9px;
  place-items: center;
  border-radius: 18px;
  color: #2784c5;
  background: #eaf6ff;
  font-size: 25px;
}
.empty-state h3 {
  margin: 0;
  color: #1c4467;
  font-size: 14px;
}
.empty-state p {
  margin: 4px 0 0;
  color: #8497a7;
  font-size: 9px;
}
.preview-overlay {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  background: rgba(8, 28, 48, 0.72);
  backdrop-filter: blur(8px);
}
.preview-modal {
  display: flex;
  width: min(720px, 100%);
  max-height: 90vh;
  overflow: hidden;
  flex-direction: column;
  border: 1px solid rgba(255, 255, 255, 0.35);
  border-radius: 24px;
  background: #fff;
  box-shadow: 0 28px 80px rgba(0, 25, 48, 0.32);
}
.preview-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 15px;
  padding: 15px 17px;
  border-bottom: 1px solid #e8eef3;
}
.preview-head span {
  display: block;
  color: #2483c5;
  font-size: 8px;
  font-weight: 900;
  letter-spacing: 0.9px;
}
.preview-head h3 {
  max-width: 520px;
  margin: 3px 0 0;
  overflow: hidden;
  color: #183c60;
  font-size: 15px;
  font-weight: 900;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.close-preview {
  display: grid;
  width: 38px;
  height: 38px;
  flex: 0 0 38px;
  place-items: center;
  border: 0;
  border-radius: 12px;
  color: #49677f;
  background: #edf4f8;
  font-size: 25px;
  line-height: 1;
  cursor: pointer;
}
.preview-body {
  min-height: 260px;
  overflow: auto;
  flex: 1;
  background: #eaf1f5;
}
.preview-image {
  display: block;
  width: 100%;
  height: auto;
  max-height: 68vh;
  margin: auto;
  object-fit: contain;
  background: #152330;
}
.preview-pdf {
  display: block;
  width: 100%;
  height: 68vh;
  border: 0;
  background: #fff;
}
.unsupported-preview {
  display: flex;
  min-height: 330px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: #617a8f;
  text-align: center;
}
.unsupported-preview div {
  display: grid;
  width: 65px;
  height: 65px;
  place-items: center;
  border-radius: 18px;
  color: #fff;
  background: #2c89ca;
  font-size: 13px;
  font-weight: 900;
}
.unsupported-preview strong {
  font-size: 11px;
}
.preview-actions {
  display: grid;
  grid-template-columns: 1fr 1.4fr;
  gap: 9px;
  padding: 12px 15px;
  border-top: 1px solid #e8eef3;
  background: #fff;
}
.preview-actions button {
  min-height: 44px;
  border: 0;
  border-radius: 13px;
  font: inherit;
  font-size: 11px;
  font-weight: 900;
  cursor: pointer;
}
.preview-secondary {
  color: #315d7e;
  background: #eef5f9;
}
.preview-primary {
  color: #fff;
  background: linear-gradient(100deg, #258fe5, #35b7e8);
}
@media (max-width: 370px) {
  .app-shell {
    padding-right: 12px;
    padding-left: 12px;
  }
  .vehicle-strip em {
    display: none;
  }
  .document-row {
    grid-template-columns: 41px minmax(0, 1fr) auto;
  }
  .doc-type {
    width: 41px;
    height: 41px;
  }
  .open-btn span {
    display: none;
  }
  .open-btn {
    width: 31px;
    justify-content: center;
  }
}
</style>
