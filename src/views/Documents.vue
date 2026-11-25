<script setup>
import { onMounted, ref } from 'vue'
import { supabase } from '../supabase.js'
import { useContract } from '../composables/useContract.js'
import BottomNav from '../components/BottomNav.vue'

const { contract, user, load } = useContract()

const docs = ref([])
const name = ref('')
const file = ref(null)
const fileInputKey = ref(0)
const message = ref('')
const loading = ref(false)
const saving = ref(false)

async function loadDocuments() {
  if (!contract.value?.contract_no) return

  const { data, error } = await supabase
    .from('car_documents')
    .select('*')
    .eq('contract_no', contract.value.contract_no)
    .order('created_at', { ascending: false })

  if (error) throw error
  docs.value = data || []
}

async function init() {
  loading.value = true
  message.value = ''

  try {
    const ok = await load()
    if (!ok) return
    await loadDocuments()
  } catch (error) {
    console.error('Documents init:', error)
    message.value = error?.message || 'โหลดข้อมูลเอกสารไม่สำเร็จ'
  } finally {
    loading.value = false
  }
}

function onFileChange(event) {
  file.value = event.target.files?.[0] || null
}

function safeFileName(fileName) {
  const rawExt = fileName.includes('.') ? fileName.split('.').pop() : 'bin'
  const ext = String(rawExt).toLowerCase().replace(/[^a-z0-9]/g, '') || 'bin'
  return `${crypto.randomUUID()}.${ext}`
}

async function addDocument() {
  message.value = ''

  if (!name.value.trim()) {
    message.value = 'กรุณากรอกชื่อเอกสาร'
    return
  }

  if (!file.value) {
    message.value = 'กรุณาเลือกไฟล์'
    return
  }

  if (!contract.value?.id || !contract.value?.contract_no || !user.value?.id) {
    message.value = 'ไม่พบข้อมูลสัญญาหรือผู้ใช้งาน'
    return
  }

  if (file.value.size > 20 * 1024 * 1024) {
    message.value = 'ไฟล์ต้องมีขนาดไม่เกิน 20 MB'
    return
  }

  saving.value = true
  let storagePath = null

  try {
    // Storage RLS expects: contract_uuid/user_uuid/file_name
    storagePath = [
      contract.value.id,
      user.value.id,
      safeFileName(file.value.name)
    ].join('/')

    const { error: uploadError } = await supabase.storage
      .from('car-documents')
      .upload(storagePath, file.value, {
        contentType: file.value.type || undefined,
        upsert: false
      })

    if (uploadError) throw uploadError

    // DB schema in this project requires BOTH user_id and uploaded_by.
    // car_documents links to the contract by contract_no (not contract_id).
    const { error: insertError } = await supabase
      .from('car_documents')
      .insert({
        contract_no: contract.value.contract_no,
        user_id: user.value.id,
        uploaded_by: user.value.id,
        name: name.value.trim(),
        type: file.value.type || 'application/octet-stream',
        file_path: storagePath
      })

    if (insertError) {
      // Avoid leaving an orphan file if the DB insert fails.
      await supabase.storage
        .from('car-documents')
        .remove([storagePath])
      throw insertError
    }

    name.value = ''
    file.value = null
    fileInputKey.value += 1
    message.value = 'เพิ่มเอกสารเรียบร้อย'
    await loadDocuments()
  } catch (error) {
    console.error('Add document:', error)
    message.value = error?.message || 'เพิ่มเอกสารไม่สำเร็จ'
  } finally {
    saving.value = false
  }
}

async function viewDocument(doc) {
  message.value = ''

  try {
    const { data, error } = await supabase.storage
      .from('car-documents')
      .createSignedUrl(doc.file_path, 60)

    if (error) throw error
    if (!data?.signedUrl) throw new Error('ไม่พบ URL สำหรับเปิดเอกสาร')

    window.open(data.signedUrl, '_blank', 'noopener,noreferrer')
  } catch (error) {
    console.error('View document:', error)
    message.value = error?.message || 'เปิดเอกสารไม่สำเร็จ'
  }
}

function formatDate(value) {
  if (!value) return '-'

  return new Intl.DateTimeFormat('th-TH', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

onMounted(init)
</script>

<template>
  <main class="app-shell">
    <header class="page-head">
      <RouterLink to="/dashboard">‹</RouterLink>
      <h1>เอกสารรถ</h1>
    </header>

    <div v-if="message" class="alert">
      {{ message }}
    </div>

    <section class="card">
      <h3>เพิ่มเอกสาร</h3>

      <label>
        ชื่อเอกสาร
        <input
          v-model="name"
          type="text"
          placeholder="เช่น พ.ร.บ. / ประกัน / สำเนาทะเบียนรถ"
          :disabled="saving"
        >
      </label>

      <label>
        ไฟล์เอกสาร
        <input
          :key="fileInputKey"
          type="file"
          accept="image/jpeg,image/png,image/webp,application/pdf"
          :disabled="saving"
          @change="onFileChange"
        >
      </label>

      <button
        type="button"
        class="btn primary full"
        :disabled="saving"
        @click="addDocument"
      >
        {{ saving ? 'กำลังเพิ่มเอกสาร...' : 'เพิ่มเอกสาร' }}
      </button>
    </section>

    <section class="card">
      <h3>รายการเอกสาร</h3>

      <div v-if="loading" class="state">
        กำลังโหลดเอกสาร...
      </div>

      <div v-else-if="!docs.length" class="state">
        ยังไม่มีเอกสาร
      </div>

      <template v-else>
        <article
          v-for="doc in docs"
          :key="doc.id"
          class="status-row"
        >
          <span class="status-icon">▱</span>

          <div>
            <b>{{ doc.name }}</b>
            <small>{{ formatDate(doc.created_at) }}</small>
          </div>

          <button
            type="button"
            class="btn secondary"
            @click="viewDocument(doc)"
          >
            เปิด
          </button>
        </article>
      </template>
    </section>

    <BottomNav />
  </main>
</template>
