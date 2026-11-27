<script setup>
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";

import { supabase } from "../supabase.js";
import { useContract } from "../composables/useContract.js";
import BottomNav from "../components/BottomNav.vue";

const route = useRoute();
const router = useRouter();

const {
  loading: contractLoading,
  error: contractError,
  user,
  contract,
  role,
  memberNo,
  installments,
  load: loadContract,
} = useContract();

// Supabase Storage bucket. Database table remains installment_slips.
const SLIP_BUCKET = "payment-slips";

const loading = ref(true);
const submitting = ref(false);
const errorMessage = ref("");
const successMessage = ref("");
const installment = ref(null);
const existingSlip = ref(null);
const selectedFile = ref(null);
const previewUrl = ref("");
const existingSlipUrl = ref("");
const note = ref("");
const fileInput = ref(null);

const installmentId = computed(() => String(route.params.id || "").trim());
const paymentAmount = computed(() => Number(installment.value?.amount || 0));
const hasSlip = computed(() => Boolean(existingSlip.value?.id));
const isOwner = computed(() => role.value === "owner");
const canSubmit = computed(
  () =>
    Boolean(installment.value?.id) &&
    Boolean(selectedFile.value) &&
    !hasSlip.value &&
    !submitting.value,
);
const statusText = computed(
  () =>
    ({
      pending: "รอชำระ",
      partial: "ชำระบางส่วน",
      submitted: "รอตรวจสอบ",
      paid: "ชำระแล้ว",
      rejected: "ไม่อนุมัติ",
    })[installment.value?.status] ||
    installment.value?.status ||
    "-",
);

const money = (value) =>
  new Intl.NumberFormat("th-TH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value || 0));

const formatFileSize = (bytes) => {
  const size = Number(bytes || 0);
  if (!size) return "-";
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
};

const formatDateTime = (value) => {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
};

const clearMessages = () => {
  errorMessage.value = "";
  successMessage.value = "";
};

const revokePreview = () => {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
    previewUrl.value = "";
  }
};

const loadInstallment = () => {
  const found = installments.value.find(
    (item) => String(item.id) === installmentId.value,
  );
  if (!found) throw new Error("ไม่พบข้อมูลงวดที่ต้องการชำระ");
  installment.value = found;
};

const createSlipUrl = async (storagePath) => {
  if (!storagePath) {
    existingSlipUrl.value = "";
    return;
  }
  const { data, error } = await supabase.storage
    .from(SLIP_BUCKET)
    .createSignedUrl(storagePath, 60 * 60);
  if (error) {
    console.error("createSignedUrl:", error);
    existingSlipUrl.value = "";
    return;
  }
  existingSlipUrl.value = data?.signedUrl || "";
};

const loadExistingSlip = async () => {
  existingSlip.value = null;
  existingSlipUrl.value = "";
  const { data, error } = await supabase
    .from("installment_slips")
    .select(
      "id,installment_id,uploaded_by,amount,storage_path,file_name,mime_type,file_size,note,created_at",
    )
    .eq("installment_id", installmentId.value)
    .maybeSingle();
  if (error) throw error;
  existingSlip.value = data || null;
  if (data?.storage_path) await createSlipUrl(data.storage_path);
};

const loadPage = async () => {
  loading.value = true;
  clearMessages();
  try {
    const ok = await loadContract();
    if (!ok)
      throw new Error(contractError.value || "ไม่สามารถโหลดข้อมูลสัญญาได้");
    loadInstallment();
    await loadExistingSlip();
  } catch (error) {
    console.error("Payment.loadPage:", error);
    errorMessage.value = error?.message || "โหลดข้อมูลไม่สำเร็จ";
  } finally {
    loading.value = false;
  }
};

const handleFileChange = (event) => {
  clearMessages();
  revokePreview();
  const file = event.target.files?.[0];
  if (!file) {
    selectedFile.value = null;
    return;
  }
  const allowedTypes = ["image/jpeg", "image/png", "image/webp"];
  if (!allowedTypes.includes(file.type)) {
    selectedFile.value = null;
    event.target.value = "";
    errorMessage.value = "รองรับเฉพาะไฟล์ JPG, PNG และ WEBP";
    return;
  }
  if (file.size > 10 * 1024 * 1024) {
    selectedFile.value = null;
    event.target.value = "";
    errorMessage.value = "ไฟล์ต้องมีขนาดไม่เกิน 10 MB";
    return;
  }
  selectedFile.value = file;
  previewUrl.value = URL.createObjectURL(file);
};

const removeSelectedFile = () => {
  selectedFile.value = null;
  revokePreview();
  if (fileInput.value) fileInput.value.value = "";
};

const buildStoragePath = (file) => {
  const extension = file.name.split(".").pop()?.toLowerCase() || "jpg";

  // Storage policy expects the first folder to be contract_id (UUID),
  // not contract_no such as 35-6404576.
  const contractId = String(installment.value?.contract_id || "").trim();
  const userId = String(user.value?.id || "").trim();

  if (!contractId) {
    throw new Error("ไม่พบ Contract ID");
  }

  if (!userId) {
    throw new Error("ไม่พบ User ID");
  }

  return `${contractId}/${installmentId.value}/${userId}_${Date.now()}.${extension}`;
};

const removeStorageFile = async (path) => {
  if (!path) return;
  const { error } = await supabase.storage.from(SLIP_BUCKET).remove([path]);
  if (error) console.error("removeStorageFile:", error);
};

const submitPayment = async () => {
  if (submitting.value) return;
  clearMessages();
  if (hasSlip.value) {
    errorMessage.value = "งวดนี้มีการแนบสลิปเรียบร้อยแล้ว";
    return;
  }
  if (!selectedFile.value) {
    errorMessage.value = "กรุณาเลือกภาพสลิปก่อนบันทึก";
    return;
  }
  if (!installment.value?.id) {
    errorMessage.value = "ไม่พบข้อมูลงวดที่ต้องการชำระ";
    return;
  }

  submitting.value = true;
  let uploadedPath = "";

  try {
    const { data: latestSlip, error: checkError } = await supabase
      .from("installment_slips")
      .select("id")
      .eq("installment_id", installment.value.id)
      .maybeSingle();
    if (checkError) throw checkError;
    if (latestSlip?.id) {
      await loadExistingSlip();
      throw new Error("งวดนี้มีการแนบสลิปเรียบร้อยแล้ว");
    }

    uploadedPath = buildStoragePath(selectedFile.value);
    const { error: uploadError } = await supabase.storage
      .from(SLIP_BUCKET)
      .upload(uploadedPath, selectedFile.value, {
        cacheControl: "3600",
        upsert: false,
        contentType: selectedFile.value.type,
      });
    if (uploadError) throw uploadError;

    const { data: savedSlip, error: insertError } = await supabase
      .from("installment_slips")
      .insert({
        installment_id: installment.value.id,
        amount: paymentAmount.value,
        storage_path: uploadedPath,
        file_name: selectedFile.value.name,
        mime_type: selectedFile.value.type,
        file_size: selectedFile.value.size,
        note: note.value.trim() || null,
      })
      .select(
        "id,installment_id,uploaded_by,amount,storage_path,file_name,mime_type,file_size,note,created_at",
      )
      .single();

    if (insertError) {
      if (insertError.code === "23505") {
        await removeStorageFile(uploadedPath);
        uploadedPath = "";
        await loadExistingSlip();
        throw new Error("งวดนี้มีการแนบสลิปเรียบร้อยแล้ว ไม่สามารถแนบซ้ำได้");
      }
      throw insertError;
    }

    existingSlip.value = savedSlip;
    await createSlipUrl(savedSlip.storage_path);
    removeSelectedFile();
    note.value = "";
    await loadContract();
    loadInstallment();
    successMessage.value = "แนบสลิปเรียบร้อยแล้ว รอตรวจสอบการชำระ";
  } catch (error) {
    console.error("Payment.submitPayment:", error);
    if (uploadedPath && !existingSlip.value?.id)
      await removeStorageFile(uploadedPath);
    errorMessage.value =
      error?.code === "23505"
        ? "งวดนี้มีการแนบสลิปเรียบร้อยแล้ว ไม่สามารถแนบซ้ำได้"
        : error?.message || "ไม่สามารถแนบสลิปได้";
    if (error?.code === "23505") await loadExistingSlip();
  } finally {
    submitting.value = false;
  }
};

const goBack = () => router.back();

onMounted(loadPage);
</script>

<template>
  <main class="payment-page">
    <header class="page-header">
      <button type="button" class="back-button" @click="goBack">‹</button>
      <div>
        <h1>ชำระค่างวด</h1>
        <p>แนบหลักฐานการชำระ</p>
      </div>
      <span class="header-icon">🧾</span>
    </header>

    <section v-if="loading || contractLoading" class="card state-card">
      <div class="loader"></div>
      <p>กำลังโหลดข้อมูล...</p>
    </section>

    <section v-else-if="!installment" class="card error-card">
      <div class="error-icon">!</div>
      <h2>ไม่สามารถโหลดข้อมูลได้</h2>
      <p>{{ errorMessage || contractError }}</p>
      <button type="button" class="btn secondary" @click="loadPage">
        ลองใหม่
      </button>
    </section>

    <template v-else>
      <section v-if="contract" class="card vehicle-card">
        <div class="vehicle-icon">🚙</div>
        <div>
          <h2>{{ contract.car_name }}</h2>
          <p>สัญญา {{ contract.contract_no }}</p>
        </div>
      </section>

      <section class="card installment-card">
        <div class="installment-main">
          <div class="installment-box">
            <small>งวดที่</small
            ><strong>{{ installment.installment_no }}</strong>
          </div>
          <div class="amount-info">
            <span>ยอดที่ต้องชำระ</span>
            <h2>{{ money(installment.amount) }} บาท</h2>
            <p>กำหนด {{ installment.due_date || "-" }}</p>
          </div>
        </div>
        <div class="status-row">
          <span>สถานะ</span
          ><strong :class="['status', installment.status]">{{
            statusText
          }}</strong>
        </div>
      </section>

      <div v-if="successMessage" class="message success-message">
        <span>✓</span>
        <div>{{ successMessage }}</div>
      </div>
      <div v-if="errorMessage && installment" class="message error-message">
        <span>!</span>
        <div>{{ errorMessage }}</div>
      </div>

      <section v-if="hasSlip" class="card slip-card">
        <div class="slip-header">
          <div class="success-circle">✓</div>
          <div>
            <h2>แนบสลิปแล้ว</h2>
            <p>มีการบันทึกหลักฐานของงวดนี้แล้ว</p>
          </div>
        </div>

        <a
          v-if="existingSlipUrl"
          :href="existingSlipUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="slip-preview"
        >
          <img
            v-if="existingSlip?.mime_type?.startsWith('image/')"
            :src="existingSlipUrl"
            alt="หลักฐานการชำระ"
          />
          <div v-else class="file-view">
            📄<strong>{{ existingSlip?.file_name }}</strong>
          </div>
        </a>

        <div class="slip-info">
          <div>
            <span>ยอดชำระ</span
            ><strong>{{ money(existingSlip.amount) }} บาท</strong>
          </div>
          <div>
            <span>วันที่แนบ</span
            ><strong>{{ formatDateTime(existingSlip.created_at) }}</strong>
          </div>
          <div>
            <span>ไฟล์</span><strong>{{ existingSlip.file_name }}</strong>
          </div>
          <div>
            <span>ขนาด</span
            ><strong>{{ formatFileSize(existingSlip.file_size) }}</strong>
          </div>
        </div>

        <div v-if="existingSlip.note" class="existing-note">
          <span>หมายเหตุ</span>
          <p>{{ existingSlip.note }}</p>
        </div>
        <a
          v-if="existingSlipUrl"
          :href="existingSlipUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="btn secondary"
          >ดูสลิปขนาดเต็ม</a
        >
        <div
          v-if="isOwner && installment.status === 'submitted'"
          class="owner-box"
        >
          <strong>👤 ผู้ผ่อนคนที่ 2</strong>
          <p>คุณสามารถตรวจสอบสลิปนี้ได้</p>
        </div>
      </section>

      <section v-else class="card upload-card">
        <div class="upload-title">
          <div>
            <h2>แนบหลักฐานการชำระ</h2>
            <p>ผู้ผ่อนคนที่ 1 หรือคนที่ 2 ใครแนบก็ได้</p>
          </div>
          <span>📎</span>
        </div>

        <label class="upload-area">
          <input
            ref="fileInput"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            :disabled="submitting"
            @change="handleFileChange"
          />
          <template v-if="!previewUrl">
            <div class="upload-plus">＋</div>
            <strong>เลือกภาพสลิป</strong
            ><small>JPG, PNG หรือ WEBP สูงสุด 10 MB</small>
          </template>
          <img
            v-else
            :src="previewUrl"
            alt="ภาพสลิปที่เลือก"
            class="preview-image"
          />
        </label>

        <div v-if="selectedFile" class="selected-file">
          <div class="file-icon">🖼️</div>
          <div class="file-detail">
            <strong>{{ selectedFile.name }}</strong
            ><small>{{ formatFileSize(selectedFile.size) }}</small>
          </div>
          <button
            type="button"
            class="remove-file"
            :disabled="submitting"
            @click="removeSelectedFile"
          >
            ×
          </button>
        </div>

        <div class="form-group">
          <label>หมายเหตุ <small>(ไม่บังคับ)</small></label>
          <textarea
            v-model="note"
            maxlength="500"
            rows="3"
            :disabled="submitting"
            placeholder="ระบุหมายเหตุเพิ่มเติม"
          ></textarea>
          <div class="count">{{ note.length }} / 500</div>
        </div>

        <div class="confirm-amount">
          <span>ยอดที่บันทึก</span
          ><strong>{{ money(paymentAmount) }} บาท</strong>
        </div>
        <button
          type="button"
          class="btn primary"
          :disabled="!canSubmit"
          @click="submitPayment"
        >
          <template v-if="submitting"
            ><span class="small-loader"></span>กำลังบันทึก...</template
          >
          <template v-else>แนบสลิป {{ money(paymentAmount) }} บาท</template>
        </button>
        <p class="warning-text">1 งวดสามารถแนบสลิปได้เพียง 1 ครั้ง</p>
      </section>

      <section class="payment-note-card">
        <span>👤</span>
        <div>
          <strong>{{
            memberNo === 1 ? "ผู้ผ่อนคนที่ 1" : "ผู้ผ่อนคนที่ 2"
          }}</strong
          ><small>ยอดที่แสดงเป็นยอดเต็มของงวด</small>
        </div>
      </section>

      <BottomNav />
    </template>
  </main>
</template>

<style scoped>
.payment-page {
  min-height: 100vh;
  box-sizing: border-box;
  padding: 18px 16px 110px;
  color: #123469;
  background: linear-gradient(
    180deg,
    #3498eb 0,
    #52c4ec 230px,
    #dff7ff 610px,
    #f4fcff 100%
  );
}
.page-header {
  display: grid;
  grid-template-columns: 42px 1fr 42px;
  align-items: center;
  gap: 8px;
  margin-bottom: 14px;
  color: #fff;
}
.page-header h1 {
  margin: 0;
  color: #fff;
  font-size: 22px;
  font-weight: 800;
}
.page-header p {
  margin: 2px 0 0;
  color: rgba(255, 255, 255, 0.9);
  font-size: 12px;
}
.back-button {
  display: flex;
  width: 38px;
  height: 38px;
  padding: 0;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 12px;
  color: #fff;
  background: rgba(255, 255, 255, 0.2);
  font-family: inherit;
  font-size: 31px;
  cursor: pointer;
}
.header-icon {
  text-align: center;
  font-size: 22px;
}
.card {
  margin-bottom: 12px;
  padding: 18px;
  border-radius: 22px;
  background: #fff;
  box-shadow: 0 7px 22px rgba(21, 81, 123, 0.07);
}
.vehicle-card {
  display: flex;
  align-items: center;
  gap: 13px;
}
.vehicle-icon {
  font-size: 42px;
}
.vehicle-card h2 {
  margin: 0;
  color: #123469;
  font-size: 19px;
  font-weight: 800;
}
.vehicle-card p {
  margin: 3px 0 0;
  color: #607891;
  font-size: 12px;
}
.installment-main {
  display: flex;
  align-items: center;
  gap: 17px;
}
.installment-box {
  display: flex;
  width: 85px;
  height: 82px;
  flex: 0 0 85px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 17px;
  color: #fff;
  background: linear-gradient(135deg, #297ff0, #46bdf3);
}
.installment-box small {
  font-size: 12px;
  font-weight: 700;
}
.installment-box strong {
  margin-top: 2px;
  font-size: 36px;
  font-weight: 800;
  line-height: 1;
}
.amount-info {
  min-width: 0;
  flex: 1;
}
.amount-info span {
  color: #496987;
  font-size: 13px;
  font-weight: 600;
}
.amount-info h2 {
  margin: 6px 0;
  color: #123469;
  font-size: 25px;
  font-weight: 800;
}
.amount-info p {
  margin: 0;
  color: #667f98;
  font-size: 12px;
}
.status-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 15px;
  padding-top: 12px;
  border-top: 1px solid #e5edf3;
}
.status-row > span {
  color: #607891;
  font-size: 12px;
}
.status {
  padding: 5px 10px;
  border-radius: 9px;
  font-size: 11px;
}
.status.pending,
.status.partial {
  color: #cf7a09;
  background: #fff1d3;
}
.status.submitted {
  color: #1779c6;
  background: #e8f4ff;
}
.status.paid {
  color: #278d58;
  background: #e4f8eb;
}
.status.rejected {
  color: #d04747;
  background: #ffebeb;
}
.message {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 12px;
  padding: 11px 13px;
  border-radius: 13px;
  font-size: 12px;
  line-height: 1.5;
}
.message > span {
  display: flex;
  width: 25px;
  height: 25px;
  flex: 0 0 25px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  font-weight: 800;
}
.success-message {
  color: #176f45;
  background: #e7f8ef;
}
.success-message > span {
  background: #28ae67;
}
.error-message {
  color: #a53d3d;
  background: #ffeded;
}
.error-message > span {
  background: #df5555;
}
.upload-title {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 13px;
}
.upload-title h2 {
  margin: 0;
  color: #123469;
  font-size: 17px;
  font-weight: 800;
}
.upload-title p {
  margin: 4px 0 0;
  color: #71879c;
  font-size: 11px;
}
.upload-title > span {
  font-size: 23px;
}
.upload-area {
  display: flex;
  min-height: 190px;
  box-sizing: border-box;
  overflow: hidden;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border: 2px dashed #9ccdf2;
  border-radius: 17px;
  color: #307bbe;
  background: #f3faff;
  text-align: center;
  cursor: pointer;
}
.upload-area input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
}
.upload-plus {
  display: flex;
  width: 48px;
  height: 48px;
  margin-bottom: 8px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(135deg, #2d83ec, #43b8ed);
  font-size: 28px;
}
.upload-area strong {
  font-size: 14px;
}
.upload-area small {
  margin-top: 5px;
  color: #8295a7;
  font-size: 10px;
}
.preview-image {
  display: block;
  width: 100%;
  max-height: 380px;
  object-fit: contain;
  background: #edf5f8;
}
.selected-file {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 10px;
  padding: 10px;
  border-radius: 13px;
  background: #eef7ff;
}
.file-icon {
  font-size: 21px;
}
.file-detail {
  min-width: 0;
  flex: 1;
}
.file-detail strong {
  display: block;
  overflow: hidden;
  color: #254d74;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.file-detail small {
  display: block;
  margin-top: 2px;
  color: #8194a5;
  font-size: 10px;
}
.remove-file {
  display: flex;
  width: 30px;
  height: 30px;
  padding: 0;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 50%;
  color: #cf4b4b;
  background: #ffe4e4;
  font-size: 20px;
  cursor: pointer;
}
.form-group {
  margin-top: 15px;
}
.form-group label {
  display: block;
  margin-bottom: 6px;
  color: #315374;
  font-size: 12px;
  font-weight: 700;
}
.form-group label small {
  color: #8497a9;
  font-weight: 500;
}
.form-group textarea {
  width: 100%;
  min-height: 88px;
  box-sizing: border-box;
  padding: 11px;
  resize: vertical;
  border: 1px solid #d4e1eb;
  border-radius: 12px;
  outline: none;
  color: #173a62;
  background: #fff;
  font-family: inherit;
  font-size: 13px;
}
.form-group textarea:focus {
  border-color: #3995e7;
  box-shadow: 0 0 0 3px rgba(57, 149, 231, 0.1);
}
.count {
  margin-top: 3px;
  color: #8295a7;
  text-align: right;
  font-size: 9px;
}
.confirm-amount {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 14px 0 11px;
  padding: 12px;
  border-radius: 12px;
  background: #fff4df;
}
.confirm-amount span {
  color: #81602e;
  font-size: 11px;
}
.confirm-amount strong {
  color: #d67609;
  font-size: 17px;
  font-weight: 800;
}
.btn {
  display: flex;
  width: 100%;
  min-height: 46px;
  box-sizing: border-box;
  align-items: center;
  justify-content: center;
  gap: 7px;
  border: 0;
  border-radius: 13px;
  font-family: inherit;
  font-size: 14px;
  font-weight: 800;
  text-decoration: none;
  cursor: pointer;
}
.btn.primary {
  color: #fff;
  background: linear-gradient(90deg, #ff9915, #ff6f0f);
}
.btn.secondary {
  color: #267dcf;
  background: #eaf5ff;
}
.btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}
.warning-text {
  margin: 9px 0 0;
  color: #8596a6;
  text-align: center;
  font-size: 9px;
}
.slip-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
}
.success-circle {
  display: flex;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  background: #28b468;
  font-size: 20px;
  font-weight: 800;
}
.slip-header h2 {
  margin: 0;
  color: #197247;
  font-size: 17px;
}
.slip-header p {
  margin: 2px 0 0;
  color: #71879b;
  font-size: 11px;
}
.slip-preview {
  display: block;
  overflow: hidden;
  margin-bottom: 13px;
  border-radius: 14px;
  background: #edf5f8;
}
.slip-preview img {
  display: block;
  width: 100%;
  max-height: 420px;
  object-fit: contain;
}
.file-view {
  display: flex;
  min-height: 160px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: #56718b;
  font-size: 35px;
}
.file-view strong {
  font-size: 12px;
}
.slip-info > div {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 0;
  border-bottom: 1px solid #e8eef3;
}
.slip-info span {
  color: #71879b;
  font-size: 11px;
}
.slip-info strong {
  max-width: 65%;
  color: #294e74;
  text-align: right;
  overflow-wrap: anywhere;
  font-size: 11px;
}
.existing-note {
  margin: 11px 0;
  padding: 10px;
  border-radius: 11px;
  background: #f4f8fa;
}
.existing-note span {
  color: #71879b;
  font-size: 10px;
}
.existing-note p {
  margin: 3px 0 0;
  color: #315374;
  font-size: 12px;
}
.owner-box {
  margin-top: 11px;
  padding: 11px;
  border-radius: 12px;
  color: #35648c;
  background: #eef7ff;
}
.owner-box strong {
  font-size: 12px;
}
.owner-box p {
  margin: 3px 0 0;
  font-size: 10px;
}
.payment-note-card {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 12px;
  padding: 11px 14px;
  border-radius: 14px;
  color: #315776;
  background: rgba(255, 255, 255, 0.75);
}
.payment-note-card > span {
  font-size: 20px;
}
.payment-note-card strong {
  display: block;
  font-size: 11px;
}
.payment-note-card small {
  display: block;
  margin-top: 2px;
  color: #72889b;
  font-size: 9px;
}
.state-card,
.error-card {
  margin-top: 25px;
  text-align: center;
}
.state-card p,
.error-card p {
  color: #6f8598;
  font-size: 12px;
}
.error-card h2 {
  font-size: 17px;
}
.loader {
  width: 34px;
  height: 34px;
  margin: auto;
  border: 4px solid #dbeaf5;
  border-top-color: #328ee5;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
.small-loader {
  width: 17px;
  height: 17px;
  border: 2px solid rgba(255, 255, 255, 0.45);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
.error-icon {
  display: flex;
  width: 48px;
  height: 48px;
  margin: auto;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  background: #dd5454;
  font-size: 22px;
  font-weight: 800;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
@media (max-width: 380px) {
  .payment-page {
    padding-right: 12px;
    padding-left: 12px;
  }
  .card {
    padding: 15px;
  }
  .installment-main {
    gap: 12px;
  }
  .installment-box {
    width: 76px;
    flex-basis: 76px;
  }
  .amount-info h2 {
    font-size: 21px;
  }
}
</style>
