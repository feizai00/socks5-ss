<template>
  <div class="login-container">
    <div class="login-background">
      <div class="bg-animation"></div>
    </div>
    
    <div class="login-content">
      <div class="login-card">
        <div class="login-header">
          <div class="logo">
            <img src="/logo.svg" alt="Logo" class="logo-img" />
            <h1 class="logo-title">Xray转换器管理平台</h1>
          </div>
          <p class="login-subtitle">专业的SOCKS5到Shadowsocks代理转换管理</p>
        </div>

        <el-form
          ref="loginFormRef"
          :model="loginForm"
          :rules="loginRules"
          class="login-form"
          @submit.prevent="handleLogin"
        >
          <el-form-item prop="username">
            <el-input
              v-model="loginForm.username"
              placeholder="请输入用户名"
              size="large"
              prefix-icon="User"
              clearable
              @keyup.enter="handleLogin"
            />
          </el-form-item>

          <el-form-item prop="password">
            <el-input
              v-model="loginForm.password"
              type="password"
              placeholder="请输入密码"
              size="large"
              prefix-icon="Lock"
              show-password
              clearable
              @keyup.enter="handleLogin"
            />
          </el-form-item>

          <el-form-item>
            <div class="login-options">
              <el-checkbox v-model="loginForm.remember">
                记住我
              </el-checkbox>
              <el-link type="primary" :underline="false">
                忘记密码？
              </el-link>
            </div>
          </el-form-item>

          <el-form-item>
            <el-button
              type="primary"
              size="large"
              :loading="loginLoading"
              @click="handleLogin"
              class="login-button"
            >
              {{ loginLoading ? '登录中...' : '登录' }}
            </el-button>
          </el-form-item>
        </el-form>

        <div class="login-footer">
          <div class="system-info">
            <el-tag type="info" size="small">
              <el-icon><Monitor /></el-icon>
              系统版本 v1.0.0
            </el-tag>
          </div>
        </div>
      </div>
    </div>

    <!-- 功能特性展示 -->
    <div class="features-section">
      <div class="features-container">
        <h2>平台特性</h2>
        <div class="features-grid">
          <div class="feature-item">
            <el-icon size="32" color="#409EFF"><User /></el-icon>
            <h3>客户管理</h3>
            <p>完整的客户信息管理，支持微信号、联系方式等信息维护</p>
          </div>
          <div class="feature-item">
            <el-icon size="32" color="#67C23A"><Connection /></el-icon>
            <h3>节点管理</h3>
            <p>SOCKS5节点的全生命周期管理，支持地区分类和连接监控</p>
          </div>
          <div class="feature-item">
            <el-icon size="32" color="#E6A23C"><Monitor /></el-icon>
            <h3>服务监控</h3>
            <p>实时监控服务状态，自动化管理和故障恢复</p>
          </div>
          <div class="feature-item">
            <el-icon size="32" color="#F56C6C"><TrendCharts /></el-icon>
            <h3>数据统计</h3>
            <p>详细的使用统计和性能分析，助力业务决策</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

// 响应式数据
const loginFormRef = ref()
const loginLoading = ref(false)

const loginForm = reactive({
  username: '',
  password: '',
  remember: false
})

const loginRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度在 3 到 20 个字符', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 20, message: '密码长度在 6 到 20 个字符', trigger: 'blur' }
  ]
}

// 方法
const handleLogin = async () => {
  if (!loginFormRef.value) return
  
  try {
    const valid = await loginFormRef.value.validate()
    if (!valid) return
    
    loginLoading.value = true
    
    const result = await authStore.login({
      username: loginForm.username,
      password: loginForm.password
    })
    
    if (result.success) {
      ElMessage.success('登录成功')
      router.push('/')
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    console.error('登录失败:', error)
    ElMessage.error('登录失败，请检查网络连接')
  } finally {
    loginLoading.value = false
  }
}
</script>

<style lang="scss" scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  position: relative;
  overflow: hidden;
}

.login-background {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  z-index: 0;
  
  .bg-animation {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grid" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M 10 0 L 0 0 0 10" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="0.5"/></pattern></defs><rect width="100" height="100" fill="url(%23grid)"/></svg>');
    animation: float 20s ease-in-out infinite;
  }
}

@keyframes float {
  0%, 100% { transform: translateY(0px) rotate(0deg); }
  50% { transform: translateY(-20px) rotate(1deg); }
}

.login-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  position: relative;
  z-index: 1;
}

.login-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-radius: 16px;
  padding: 40px;
  width: 100%;
  max-width: 400px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
  
  .logo {
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 16px;
    
    .logo-img {
      width: 48px;
      height: 48px;
      margin-right: 12px;
    }
    
    .logo-title {
      font-size: 24px;
      font-weight: 600;
      color: #2c3e50;
      margin: 0;
    }
  }
  
  .login-subtitle {
    color: #7f8c8d;
    font-size: 14px;
    margin: 0;
  }
}

.login-form {
  .login-options {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
  }
  
  .login-button {
    width: 100%;
    height: 44px;
    font-size: 16px;
    font-weight: 500;
  }
}

.login-footer {
  margin-top: 24px;
  text-align: center;
  
  .system-info {
    .el-tag {
      background: rgba(64, 158, 255, 0.1);
      border: 1px solid rgba(64, 158, 255, 0.2);
    }
  }
}

.features-section {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px;
  position: relative;
  z-index: 1;
  
  .features-container {
    max-width: 500px;
    color: white;
    
    h2 {
      font-size: 28px;
      margin-bottom: 32px;
      text-align: center;
      font-weight: 300;
    }
  }
  
  .features-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }
  
  .feature-item {
    text-align: center;
    padding: 20px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    backdrop-filter: blur(5px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    
    h3 {
      font-size: 16px;
      margin: 12px 0 8px;
      font-weight: 500;
    }
    
    p {
      font-size: 13px;
      line-height: 1.5;
      opacity: 0.9;
      margin: 0;
    }
  }
}

// 响应式设计
@media (max-width: 1024px) {
  .login-container {
    flex-direction: column;
  }
  
  .features-section {
    order: -1;
    flex: none;
    padding: 20px;
    
    .features-grid {
      grid-template-columns: 1fr;
      gap: 16px;
    }
  }
  
  .login-content {
    flex: none;
    padding: 20px;
  }
}

@media (max-width: 768px) {
  .login-card {
    padding: 24px;
    margin: 0 16px;
  }
  
  .login-header {
    .logo {
      .logo-title {
        font-size: 20px;
      }
    }
  }
  
  .features-section {
    display: none;
  }
}

// 暗色主题适配
:deep(.dark) {
  .login-card {
    background: rgba(31, 41, 55, 0.95);
    color: #f3f4f6;
    
    .login-header {
      .logo-title {
        color: #f3f4f6;
      }
      
      .login-subtitle {
        color: #9ca3af;
      }
    }
  }
}
</style>
