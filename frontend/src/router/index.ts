import { createRouter, createWebHistory } from 'vue-router'
import { auth } from '../store/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: () => import('../views/Login.vue') },
    {
      path: '/',
      component: () => import('../layouts/MainLayout.vue'),
      children: [
        { path: '', redirect: '/books' },
        { path: 'books', component: () => import('../views/Books.vue') },
        { path: 'readers', component: () => import('../views/Readers.vue') },
        { path: 'circulation', component: () => import('../views/Circulation.vue') },
        { path: 'stats', component: () => import('../views/Stats.vue') },
      ],
    },
  ],
})

router.beforeEach((to) => {
  if (to.path !== '/login' && !auth.token) return '/login'
})

export default router
