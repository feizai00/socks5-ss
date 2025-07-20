<template>
  <div class="app-layout">
    <el-container>
      <!-- 侧边栏 -->
      <el-aside 
        :width="themeStore.sidebarCollapsed ? '64px' : '240px'"
        class="sidebar-container"
      >
        <div class="sidebar-logo">
          <img src="/logo.svg" alt="Logo" class="logo-img" />
          <h1 v-show="!themeStore.sidebarCollapsed" class="logo-title">
            Xray转换器
          </h1>
        </div>
        
        <el-menu
          :default-active="$route.path"
          :collapse="themeStore.sidebarCollapsed"
          :unique-opened="true"
          router
          class="sidebar-menu"
        >
          <el-menu-item
            v-for="route in menuRoutes"
            :key="route.path"
            :index="route.path"
          >
            <el-icon>
              <component :is="route.meta.icon" />
            </el-icon>
            <template #title>{{ route.meta.title }}</template>
          </el-menu-item>
        </el-menu>
      </el-aside>

      <el-container>
        <!-- 顶部导航栏 -->
        <el-header class="header-container">
          <div class="header-left">
            <el-button
              type="text"
              @click="themeStore.toggleSidebar"
              class="sidebar-toggle"
            >
              <el-icon size="20">
                <Expand v-if="themeStore.sidebarCollapsed" />
                <Fold v-else />
              </el-icon>
            </el-button>
            
            <el-breadcrumb separator="/">
              <el-breadcrumb-item
                v-for="item in breadcrumbs"
                :key="item.path"
                :to="item.path"
              >
                {{ item.title }}
              </el-breadcrumb-item>
            </el-breadcrumb>
          </div>

          <div class="header-right">
            <!-- 系统状态指示器 -->
            <div class="status-indicator">
              <el-badge :value="systemStats.running_services" type="success">
                <el-icon size="20"><Monitor /></el-icon>
              </el-badge>
            </div>

            <!-- 主题切换 -->
            <el-button
              type="text"
              @click="themeStore.toggleTheme"
              class="theme-toggle"
            >
              <el-icon size="18">
                <Sunny v-if="themeStore.isDark" />
                <Moon v-else />
              </el-icon>
            </el-button>

            <!-- 用户菜单 -->
            <el-dropdown @command="handleUserCommand" class="user-dropdown">
              <div class="user-info">
                <el-avatar :size="32" class="user-avatar">
                  {{ authStore.userName.charAt(0).toUpperCase() }}
                </el-avatar>
                <span v-show="!isMobile" class="user-name">
                  {{ authStore.userName }}
                </span>
                <el-icon><ArrowDown /></el-icon>
              </div>
              
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">
                    <el-icon><User /></el-icon>
                    个人资料
                  </el-dropdown-item>
                  <el-dropdown-item command="settings">
                    <el-icon><Setting /></el-icon>
                    系统设置
                  </el-dropdown-item>
                  <el-dropdown-item divided command="logout">
                    <el-icon><SwitchButton /></el-icon>
                    退出登录
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
        </el-header>

        <!-- 主内容区域 -->
        <el-main class="main-container">
          <div class="page-container">
            <router-view v-slot="{ Component, route }">
              <transition name="fade-transform" mode="out-in">
                <keep-alive :include="cachedViews">
                  <component :is="Component" :key="route.path" />
                </keep-alive>
              </transition>
            </router-view>
          </div>
        </el-main>
      </el-container>
    </el-container>

    <!-- 移动端遮罩 -->
    <div
      v-if="isMobile && !themeStore.sidebarCollapsed"
      class="mobile-mask"
      @click="themeStore.toggleSidebar"
    />
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore } from '@/stores/theme'
import { systemApi } from '@/api/system'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const themeStore = useThemeStore()

// 响应式数据
const systemStats = ref({
  running_services: 0,
  total_services: 0
})

const cachedViews = ref(['Dashboard', 'Customers', 'Nodes', 'Services'])
const isMobile = ref(false)

// 计算属性
const menuRoutes = computed(() => {
  return router.getRoutes()
    .find(r => r.name === 'Layout')
    ?.children?.filter(child => child.meta?.title && child.meta?.icon) || []
})

const breadcrumbs = computed(() => {
  const matched = route.matched.filter(item => item.meta?.title)
  return matched.map(item => ({
    path: item.path,
    title: item.meta.title
  }))
})

// 方法
const handleUserCommand = async (command) => {
  switch (command) {
    case 'profile':
      // 打开个人资料对话框
      break
    case 'settings':
      router.push('/system')
      break
    case 'logout':
      await authStore.logout()
      router.push('/login')
      break
  }
}

const loadSystemStats = async () => {
  try {
    const response = await systemApi.getStatus()
    systemStats.value = response.data
  } catch (error) {
    console.error('加载系统状态失败:', error)
  }
}

const checkMobile = () => {
  isMobile.value = window.innerWidth < 768
}

// 生命周期
onMounted(() => {
  loadSystemStats()
  checkMobile()
  window.addEventListener('resize', checkMobile)
  
  // 定时更新系统状态
  setInterval(loadSystemStats, 30000)
})
</script>

<style lang="scss" scoped>
.app-layout {
  height: 100vh;
  overflow: hidden;
}

.sidebar-container {
  background: var(--el-bg-color);
  border-right: 1px solid var(--el-border-color-light);
  transition: width 0.3s;
  overflow: hidden;
}

.sidebar-logo {
  display: flex;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid var(--el-border-color-lighter);
  
  .logo-img {
    width: 32px;
    height: 32px;
    margin-right: 12px;
  }
  
  .logo-title {
    font-size: 18px;
    font-weight: 600;
    color: var(--el-text-color-primary);
    margin: 0;
    white-space: nowrap;
  }
}

.sidebar-menu {
  border: none;
  height: calc(100vh - 65px);
  overflow-y: auto;
}

.header-container {
  background: var(--el-bg-color);
  border-bottom: 1px solid var(--el-border-color-light);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
}

.header-left {
  display: flex;
  align-items: center;
  
  .sidebar-toggle {
    margin-right: 16px;
    color: var(--el-text-color-regular);
  }
}

.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.status-indicator {
  display: flex;
  align-items: center;
  color: var(--el-text-color-regular);
}

.theme-toggle {
  color: var(--el-text-color-regular);
}

.user-dropdown {
  .user-info {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    padding: 4px 8px;
    border-radius: 4px;
    transition: background-color 0.3s;
    
    &:hover {
      background: var(--el-bg-color-page);
    }
  }
  
  .user-name {
    font-size: 14px;
    color: var(--el-text-color-primary);
  }
}

.main-container {
  background: var(--el-bg-color-page);
  padding: 0;
  overflow: hidden;
}

.page-container {
  height: 100%;
  overflow-y: auto;
  padding: 16px;
}

.mobile-mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.3);
  z-index: 999;
}

// 页面切换动画
.fade-transform-enter-active,
.fade-transform-leave-active {
  transition: all 0.3s;
}

.fade-transform-enter-from {
  opacity: 0;
  transform: translateX(30px);
}

.fade-transform-leave-to {
  opacity: 0;
  transform: translateX(-30px);
}

// 响应式设计
@media (max-width: 768px) {
  .sidebar-container {
    position: fixed;
    top: 0;
    left: 0;
    height: 100vh;
    z-index: 1000;
  }
  
  .header-left {
    .el-breadcrumb {
      display: none;
    }
  }
  
  .page-container {
    padding: 12px;
  }
}
</style>
