import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useThemeStore = defineStore('theme', () => {
  // 状态
  const isDark = ref(false)
  const sidebarCollapsed = ref(false)
  const primaryColor = ref('#409EFF')
  
  // 切换主题
  const toggleTheme = () => {
    isDark.value = !isDark.value
    applyTheme()
    saveThemeToStorage()
  }
  
  // 应用主题
  const applyTheme = () => {
    const html = document.documentElement
    if (isDark.value) {
      html.classList.add('dark')
    } else {
      html.classList.remove('dark')
    }
  }
  
  // 切换侧边栏
  const toggleSidebar = () => {
    sidebarCollapsed.value = !sidebarCollapsed.value
    saveSidebarToStorage()
  }
  
  // 设置主色调
  const setPrimaryColor = (color) => {
    primaryColor.value = color
    document.documentElement.style.setProperty('--el-color-primary', color)
    saveThemeToStorage()
  }
  
  // 保存主题到本地存储
  const saveThemeToStorage = () => {
    localStorage.setItem('theme-dark', isDark.value.toString())
    localStorage.setItem('theme-primary-color', primaryColor.value)
  }
  
  // 保存侧边栏状态到本地存储
  const saveSidebarToStorage = () => {
    localStorage.setItem('sidebar-collapsed', sidebarCollapsed.value.toString())
  }
  
  // 从本地存储加载主题
  const loadThemeFromStorage = () => {
    const savedDark = localStorage.getItem('theme-dark')
    const savedColor = localStorage.getItem('theme-primary-color')
    const savedSidebar = localStorage.getItem('sidebar-collapsed')
    
    if (savedDark !== null) {
      isDark.value = savedDark === 'true'
    }
    
    if (savedColor) {
      primaryColor.value = savedColor
      setPrimaryColor(savedColor)
    }
    
    if (savedSidebar !== null) {
      sidebarCollapsed.value = savedSidebar === 'true'
    }
  }
  
  // 初始化主题
  const initTheme = () => {
    loadThemeFromStorage()
    applyTheme()
  }
  
  // 重置主题
  const resetTheme = () => {
    isDark.value = false
    primaryColor.value = '#409EFF'
    sidebarCollapsed.value = false
    
    applyTheme()
    setPrimaryColor('#409EFF')
    saveThemeToStorage()
    saveSidebarToStorage()
  }
  
  return {
    // 状态
    isDark,
    sidebarCollapsed,
    primaryColor,
    
    // 方法
    toggleTheme,
    toggleSidebar,
    setPrimaryColor,
    initTheme,
    resetTheme
  }
})
