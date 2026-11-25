<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase.js'
const email=ref(''), password=ref(''), error=ref(''), busy=ref(false), route=useRoute(), router=useRouter()
onMounted(async()=>{ const {data}=await supabase.auth.getSession(); if(data.session) router.replace('/dashboard') })
async function login(){
  busy.value=true; error.value=''
  try{
    const {data,error:e}=await supabase.auth.signInWithPassword({email:email.value.trim().toLowerCase(),password:password.value})
    if(e) throw e
    if(!data.session) throw new Error('ไม่พบ session หลังเข้าสู่ระบบ')
    await router.replace(typeof route.query.redirect==='string'?route.query.redirect:'/dashboard')
  }catch(e){error.value=e.message||'เข้าสู่ระบบไม่สำเร็จ'}finally{busy.value=false}
}
</script>
<template><main class="login-page"><form class="login-card" @submit.prevent="login"><div class="big-icon">🚘</div><h1>ค่างวดรถของฉัน</h1><p>เข้าสู่ระบบผู้ผ่อนหรือเจ้าของสัญญา</p><label>อีเมล<input v-model="email" type="email" autocomplete="username" required></label><label>รหัสผ่าน<input v-model="password" type="password" autocomplete="current-password" required></label><div v-if="error" class="alert error">{{error}}</div><button class="btn primary full" :disabled="busy">{{busy?'กำลังเข้าสู่ระบบ...':'เข้าสู่ระบบ'}}</button></form></main></template>
