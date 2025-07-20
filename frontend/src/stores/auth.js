import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/api/auth'
import { removeToken, setToken, getToken } from '@/utils/auth'

export const useAuthStore = defineStore('auth', () => {
  // 状态
  const token = ref('')
  const user = ref(null)
  const permissions = ref([])
  
  // 计算属性
  const isAuthenticated = computed(() => !!token.value && !!user.value)
  const userRole = computed(() => user.value?.role || 'user')
  const userName = computed(() => user.value?.username || '')
  
  // 登录
  const login = async (credentials) => {
    try {
      const response = await authApi.login(credentials)
      const { token: authToken, user: userInfo } = response.data
      
      // 保存认证信息
      token.value = authToken
      user.value = userInfo
      setToken(authToken)
      
      return { success: true }
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || '登录失败' 
      }
    }
  }
  
  // 登出
  const logout = async () => {
    try {
      await authApi.logout()
    } catch (error) {
      console.error('登出请求失败:', error)
    } finally {
      // 清除本地状态
      token.value = ''
      user.value = null
      permissions.value = []
      removeToken()
    }
  }
  
  // 获取用户信息
  const getUserInfo = async () => {
    try {
      const response = await authApi.getUserInfo()
      user.value = response.data
      return response.data
    } catch (error) {
      console.error('获取用户信息失败:', error)
      throw error
    }
  }
  
  // 初始化认证状态
  const initAuth = async () => {
    const savedToken = getToken()
    if (savedToken) {
      token.value = savedToken
      try {
        await getUserInfo()
      } catch (error) {
        // Token无效，清除认证状态
        await logout()
      }
    }
  }
  
  // 检查权限
  const hasPermission = (permission) => {
    if (userRole.value === 'admin') return true
    return permissions.value.includes(permission)
  }
  
  // 修改密码
  const changePassword = async (passwordData) => {
    try {
      await authApi.changePassword(passwordData)
      return { success: true }
    } catch (error) {
      return { 
        success: false, 
        message: error.response?.data?.message || '密码修改失败' 
      }
    }
  }
  
  return {
    // 状态
    token,
    user,
    permissions,
    
    // 计算属性
    isAuthenticated,
    userRole,
    userName,
    
    // 方法
    login,
    logout,
    getUserInfo,
    initAuth,
    hasPermission,
    changePassword
  }
})
