import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginSimple.vue'),
    meta: {
      title: '登录'
    }
  },
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('@/views/DashboardSimple.vue'),
    meta: {
      title: '仪表板'
    }
  },
  {
    path: '/customers',
    name: 'Customers',
    component: () => import('@/views/CustomersComplete.vue'),
    meta: {
      title: '客户管理'
    }
  },
  {
    path: '/nodes',
    name: 'Nodes',
    component: () => import('@/views/NodesComplete.vue'),
    meta: {
      title: '节点管理'
    }
  },
  {
    path: '/services',
    name: 'Services',
    component: () => import('@/views/ServicesComplete.vue'),
    meta: {
      title: '服务管理'
    }
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('@/views/404.vue'),
    meta: {
      title: '页面不存在'
    }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  }
})

// 简化的路由守卫
router.beforeEach((to, from, next) => {
  // 设置页面标题
  document.title = to.meta.title ? `${to.meta.title} - Xray转换器管理平台` : 'Xray转换器管理平台'
  next()
})

export default router
