<template>
  <div class="error-page">
    <div class="error-container">
      <div class="error-content">
        <div class="error-illustration">
          <div class="error-number">404</div>
          <div class="error-icon">
            <el-icon size="120" color="#E6A23C">
              <QuestionFilled />
            </el-icon>
          </div>
        </div>
        
        <div class="error-text">
          <h1 class="error-title">页面不存在</h1>
          <p class="error-description">
            抱歉，您访问的页面不存在或已被移除。
            <br>
            请检查URL是否正确，或返回首页继续浏览。
          </p>
        </div>
        
        <div class="error-actions">
          <el-button type="primary" size="large" @click="goHome">
            <el-icon><HomeFilled /></el-icon>
            返回首页
          </el-button>
          <el-button size="large" @click="goBack">
            <el-icon><Back /></el-icon>
            返回上页
          </el-button>
        </div>
        
        <div class="error-suggestions">
          <h3>您可以尝试：</h3>
          <ul>
            <li>检查URL拼写是否正确</li>
            <li>使用导航菜单浏览其他页面</li>
            <li>联系管理员获取帮助</li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router'

const router = useRouter()

const goHome = () => {
  router.push('/')
}

const goBack = () => {
  if (window.history.length > 1) {
    router.go(-1)
  } else {
    router.push('/')
  }
}
</script>

<style lang="scss" scoped>
.error-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
}

.error-container {
  max-width: 600px;
  width: 100%;
}

.error-content {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-radius: 16px;
  padding: 48px 32px;
  text-align: center;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.error-illustration {
  position: relative;
  margin-bottom: 32px;
  
  .error-number {
    font-size: 120px;
    font-weight: 900;
    color: #E6A23C;
    line-height: 1;
    margin-bottom: 16px;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.1);
  }
  
  .error-icon {
    opacity: 0.8;
  }
}

.error-text {
  margin-bottom: 32px;
  
  .error-title {
    font-size: 28px;
    font-weight: 600;
    color: #2c3e50;
    margin: 0 0 16px 0;
  }
  
  .error-description {
    font-size: 16px;
    color: #7f8c8d;
    line-height: 1.6;
    margin: 0;
  }
}

.error-actions {
  display: flex;
  justify-content: center;
  gap: 16px;
  margin-bottom: 32px;
  
  .el-button {
    padding: 12px 24px;
    font-size: 16px;
  }
}

.error-suggestions {
  text-align: left;
  background: rgba(64, 158, 255, 0.1);
  border-radius: 8px;
  padding: 20px;
  border: 1px solid rgba(64, 158, 255, 0.2);
  
  h3 {
    font-size: 16px;
    color: #409EFF;
    margin: 0 0 12px 0;
    font-weight: 600;
  }
  
  ul {
    margin: 0;
    padding-left: 20px;
    
    li {
      color: #606266;
      margin-bottom: 8px;
      line-height: 1.5;
      
      &:last-child {
        margin-bottom: 0;
      }
    }
  }
}

// 响应式设计
@media (max-width: 768px) {
  .error-content {
    padding: 32px 24px;
  }
  
  .error-illustration {
    .error-number {
      font-size: 80px;
    }
    
    .error-icon {
      :deep(.el-icon) {
        font-size: 80px !important;
      }
    }
  }
  
  .error-text {
    .error-title {
      font-size: 24px;
    }
    
    .error-description {
      font-size: 14px;
    }
  }
  
  .error-actions {
    flex-direction: column;
    align-items: center;
    
    .el-button {
      width: 100%;
      max-width: 200px;
    }
  }
}

// 暗色主题适配
:deep(.dark) {
  .error-content {
    background: rgba(31, 41, 55, 0.95);
    color: #f3f4f6;
    
    .error-text {
      .error-title {
        color: #f3f4f6;
      }
      
      .error-description {
        color: #9ca3af;
      }
    }
    
    .error-suggestions {
      background: rgba(59, 130, 246, 0.1);
      border-color: rgba(59, 130, 246, 0.2);
      
      h3 {
        color: #60a5fa;
      }
      
      ul li {
        color: #d1d5db;
      }
    }
  }
}
</style>
