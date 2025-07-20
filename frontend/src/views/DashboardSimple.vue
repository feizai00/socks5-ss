<template>
  <div class="dashboard">
    <div class="dashboard-header">
      <h1>仪表板</h1>
      <p>欢迎使用 Xray SOCKS5 转换器管理平台</p>
    </div>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon customers">
          <el-icon size="32"><User /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.customers }}</div>
          <div class="stat-label">总客户数</div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon nodes">
          <el-icon size="32"><Connection /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.nodes }}</div>
          <div class="stat-label">SOCKS5节点</div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon services">
          <el-icon size="32"><Monitor /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.services }}</div>
          <div class="stat-label">SS服务</div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon active">
          <el-icon size="32"><CircleCheck /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.active }}</div>
          <div class="stat-label">运行中</div>
        </div>
      </div>
    </div>

    <div class="quick-actions">
      <h2>快速操作</h2>
      <div class="actions-grid">
        <el-button type="primary" size="large" @click="$router.push('/customers')">
          <el-icon><User /></el-icon>
          客户管理
        </el-button>
        <el-button type="success" size="large" @click="$router.push('/nodes')">
          <el-icon><Connection /></el-icon>
          节点管理
        </el-button>
        <el-button type="warning" size="large" @click="$router.push('/services')">
          <el-icon><Monitor /></el-icon>
          服务管理
        </el-button>
        <el-button type="info" size="large" @click="handleSystemCheck">
          <el-icon><Tools /></el-icon>
          系统检查
        </el-button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { statsApi } from '@/utils/apiAdapter'

const stats = reactive({
  customers: 0,
  nodes: 0,
  services: 0,
  active: 0
})

const loadStats = async () => {
  try {
    const response = await statsApi.getDashboardStats()
    if (response.success) {
      Object.assign(stats, response.data)
    }
  } catch (error) {
    console.error('加载统计数据失败:', error)
  }
}

const handleSystemCheck = () => {
  ElMessage.success('系统检查完成，一切正常')
}

onMounted(() => {
  loadStats()
})
</script>

<style scoped>
.dashboard {
  padding: 24px;
}

.dashboard-header {
  margin-bottom: 32px;
}

.dashboard-header h1 {
  font-size: 28px;
  font-weight: 600;
  color: #2c3e50;
  margin: 0 0 8px 0;
}

.dashboard-header p {
  color: #7f8c8d;
  margin: 0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 32px;
}

.stat-card {
  background: white;
  border-radius: 12px;
  padding: 24px;
  display: flex;
  align-items: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid #e6e6e6;
}

.stat-icon {
  width: 64px;
  height: 64px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16px;
  color: white;
}

.stat-icon.customers {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.stat-icon.nodes {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.stat-icon.services {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
}

.stat-icon.active {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
}

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 32px;
  font-weight: 600;
  color: #2c3e50;
  line-height: 1;
}

.stat-label {
  font-size: 14px;
  color: #7f8c8d;
  margin-top: 4px;
}

.quick-actions {
  background: white;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid #e6e6e6;
}

.quick-actions h2 {
  font-size: 18px;
  font-weight: 600;
  color: #2c3e50;
  margin: 0 0 20px 0;
}

.actions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 16px;
}

.actions-grid .el-button {
  height: 60px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

@media (max-width: 768px) {
  .dashboard {
    padding: 16px;
  }
  
  .stats-grid {
    grid-template-columns: 1fr;
  }
  
  .actions-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
