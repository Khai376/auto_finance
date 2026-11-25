import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../supabase.js'
import Login from '../views/Login.vue'
import Dashboard from '../views/Dashboard.vue'
import Payment from '../views/Payment.vue'
import Schedule from '../views/Schedule.vue'
import History from '../views/History.vue'
import Documents from '../views/Documents.vue'
import Settings from '../views/Settings.vue'
const routes = [
  { path: '/', redirect: '/dashboard' },
  { path: '/login', name: 'login', component: Login },
  { path: '/dashboard', name: 'dashboard', component: Dashboard, meta: { auth: true } },
  { path: '/payment/:id?', name: 'payment', component: Payment, meta: { auth: true } },
  { path: '/schedule', name: 'schedule', component: Schedule, meta: { auth: true } },
  { path: '/history', name: 'history', component: History, meta: { auth: true } },
  { path: '/documents', name: 'documents', component: Documents, meta: { auth: true } },
  { path: '/settings', name: 'settings', component: Settings, meta: { auth: true } },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
]
const router = createRouter({ history: createWebHashHistory(), routes })
router.beforeEach(async to => {
  const { data } = await supabase.auth.getSession()
  const loggedIn = Boolean(data.session)
  if (to.meta.auth && !loggedIn) return { name: 'login', query: { redirect: to.fullPath } }
  if (to.name === 'login' && loggedIn) return { name: 'dashboard' }
  return true
})
export default router
