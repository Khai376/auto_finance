import { computed, ref } from 'vue'
import { supabase } from '../supabase.js'
export function useContract() {
  const loading = ref(false), error = ref(''), user = ref(null), membership = ref(null), installments = ref([])
  const contract = computed(() => membership.value?.contracts || null)
  const role = computed(() => membership.value?.role || '')
  const memberNo = computed(() => Number(membership.value?.member_no || 0))
  async function load() {
    loading.value = true; error.value = ''
    try {
      const { data: auth, error: authError } = await supabase.auth.getUser()
      if (authError) throw authError
      if (!auth.user) throw new Error('กรุณาเข้าสู่ระบบ')
      user.value = auth.user
      const { data: member, error: memberError } = await supabase.from('contract_members')
        .select('id,role,member_no,contract_id,active,contracts(id,car_name,contract_no,total_installments,default_installment_amount,active)')
        .eq('user_id', auth.user.id).eq('active', true).limit(1).maybeSingle()
      if (memberError) throw memberError
      if (!member) throw new Error('บัญชีนี้ยังไม่ได้ผูกกับสัญญา')
      if (!member.contracts) throw new Error('ไม่พบข้อมูลสัญญารถ')
      membership.value = member
      const { data, error: installmentError } = await supabase.from('installments')
        .select('id,contract_id,installment_no,amount,payer1_amount,payer2_amount,due_date,status,owner_note,verified_at')
        .eq('contract_id', member.contract_id).order('installment_no', { ascending: true })
      if (installmentError) throw installmentError
      installments.value = data || []
      return true
    } catch (e) {
      console.error('useContract.load:', e)
      error.value = e?.message || 'โหลดข้อมูลไม่สำเร็จ'
      return false
    } finally { loading.value = false }
  }
  return { loading, error, user, membership, contract, role, memberNo, installments, load }
}
