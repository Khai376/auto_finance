<script setup>
import { useRoute } from 'vue-router'
const route = useRoute()
const items = [['/dashboard','⌂','ภาพรวม'],['/history','▤','ประวัติ'],['/documents','▱','เอกสาร'],['/settings','⚙','ตั้งค่า']]
</script>
<template><nav class="bottom-nav"><RouterLink v-for="i in items" :key="i[0]" :to="i[0]" :class="{active:route.path===i[0]}"><b>{{i[1]}}</b><span>{{i[2]}}</span></RouterLink></nav></template>
