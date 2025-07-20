<template>
  <div class="dashboard">
    <!-- 统计卡片 -->
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon customers">
          <el-icon size="32"><User /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.total_customers }}</div>
          <div class="stat-label">总客户数</div>
          <div class="stat-change positive">
            <el-icon><TrendCharts /></el-icon>
            +{{ stats.new_customers_today }} 今日新增
          </div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon nodes">
          <el-icon size="32"><Connection /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.total_nodes }}</div>
          <div class="stat-label">SOCKS5节点</div>
          <div class="stat-change">
            <el-icon><Monitor /></el-icon>
            {{ stats.active_nodes }} 在线
          </div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon services">
          <el-icon size="32"><Monitor /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ stats.total_services }}</div>
          <div class="stat-label">SS服务</div>
          <div class="stat-change positive">
            <el-icon><CircleCheck /></el-icon>
            {{ stats.running_services }} 运行中
          </div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon revenue">
          <el-icon size="32"><TrendCharts /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ formatBytes(stats.total_bandwidth) }}</div>
          <div class="stat-label">总流量</div>
          <div class="stat-change">
            <el-icon><Download /></el-icon>
            {{ formatBytes(stats.today_bandwidth) }} 今日
          </div>
        </div>
      </div>
    </div>

    <!-- 图表和列表区域 -->
    <div class="content-grid">
      <!-- 服务状态图表 -->
      <div class="chart-card">
        <div class="card-header">
          <h3>服务状态分布</h3>
          <el-button-group size="small">
            <el-button 
              :type="chartTimeRange === '7d' ? 'primary' : ''"
              @click="chartTimeRange = '7d'"
            >
              7天
            </el-button>
            <el-button 
              :type="chartTimeRange === '30d' ? 'primary' : ''"
              @click="chartTimeRange = '30d'"
            >
              30天
            </el-button>
          </el-button-group>
        </div>
        <div class="chart-container">
          <v-chart 
            :option="serviceStatusChartOption" 
            :loading="chartLoading"
            class="chart"
          />
        </div>
      </div>

      <!-- 最近活动 -->
      <div class="activity-card">
        <div class="card-header">
          <h3>最近活动</h3>
          <el-link type="primary" @click="$router.push('/logs')">
            查看全部
          </el-link>
        </div>
        <div class="activity-list">
          <div 
            v-for="activity in recentActivities" 
            :key="activity.id"
            class="activity-item"
          >
            <div class="activity-icon">
              <el-icon :color="getActivityColor(activity.type)">
                <component :is="getActivityIcon(activity.type)" />
              </el-icon>
            </div>
            <div class="activity-content">
              <div class="activity-title">{{ activity.title }}</div>
              <div class="activity-desc">{{ activity.description }}</div>
              <div class="activity-time">{{ formatTime(activity.created_at) }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 快速操作和系统信息 -->
    <div class="bottom-grid">
      <!-- 快速操作 -->
      <div class="quick-actions-card">
        <div class="card-header">
          <h3>快速操作</h3>
        </div>
        <div class="quick-actions">
          <el-button 
            type="primary" 
            size="large"
            @click="$router.push('/customers')"
            class="quick-action-btn"
          >
            <el-icon><Plus /></el-icon>
            添加客户
          </el-button>
          <el-button 
            type="success" 
            size="large"
            @click="$router.push('/nodes')"
            class="quick-action-btn"
          >
            <el-icon><Connection /></el-icon>
            添加节点
          </el-button>
          <el-button 
            type="warning" 
            size="large"
            @click="$router.push('/services')"
            class="quick-action-btn"
          >
            <el-icon><Monitor /></el-icon>
            创建服务
          </el-button>
          <el-button 
            type="info" 
            size="large"
            @click="handleSystemCheck"
            :loading="systemCheckLoading"
            class="quick-action-btn"
          >
            <el-icon><Tools /></el-icon>
            系统检查
          </el-button>
        </div>
      </div>

      <!-- 系统信息 -->
      <div class="system-info-card">
        <div class="card-header">
          <h3>系统信息</h3>
          <el-button 
            type="text" 
            size="small"
            @click="loadSystemInfo"
            :loading="systemInfoLoading"
          >
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>
        <div class="system-info">
          <div class="info-item">
            <span class="info-label">系统版本</span>
            <span class="info-value">{{ systemInfo.version }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">运行时间</span>
            <span class="info-value">{{ systemInfo.uptime }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">CPU使用率</span>
            <span class="info-value">{{ systemInfo.cpu_usage }}%</span>
          </div>
          <div class="info-item">
            <span class="info-label">内存使用</span>
            <span class="info-value">{{ systemInfo.memory_usage }}%</span>
          </div>
          <div class="info-item">
            <span class="info-label">磁盘使用</span>
            <span class="info-value">{{ systemInfo.disk_usage }}%</span>
          </div>
          <div class="info-item">
            <span class="info-label">Docker状态</span>
            <el-tag 
              :type="systemInfo.docker_status === 'running' ? 'success' : 'danger'"
              size="small"
            >
              {{ systemInfo.docker_status }}
            </el-tag>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { PieChart, LineChart } from 'echarts/charts'
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent
} from 'echarts/components'
import VChart from 'vue-echarts'
import { dashboardApi } from '@/api/dashboard'
import { formatTime, formatBytes } from '@/utils/format'

// 注册ECharts组件
use([
  CanvasRenderer,
  PieChart,
  LineChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent
])

// 响应式数据
const stats = ref({
  total_customers: 0,
  new_customers_today: 0,
  total_nodes: 0,
  active_nodes: 0,
  total_services: 0,
  running_services: 0,
  total_bandwidth: 0,
  today_bandwidth: 0
})

const recentActivities = ref([])
const systemInfo = ref({
  version: '1.0.0',
  uptime: '0天',
  cpu_usage: 0,
  memory_usage: 0,
  disk_usage: 0,
  docker_status: 'unknown'
})

const chartTimeRange = ref('7d')
const chartLoading = ref(false)
const systemCheckLoading = ref(false)
const systemInfoLoading = ref(false)

// 图表配置
const serviceStatusChartOption = computed(() => ({
  tooltip: {
    trigger: 'item',
    formatter: '{a} <br/>{b}: {c} ({d}%)'
  },
  legend: {
    orient: 'vertical',
    left: 'left'
  },
  series: [
    {
      name: '服务状态',
      type: 'pie',
      radius: '50%',
      data: [
        { value: stats.value.running_services, name: '运行中' },
        { value: stats.value.total_services - stats.value.running_services, name: '已停止' }
      ],
      emphasis: {
        itemStyle: {
          shadowBlur: 10,
          shadowOffsetX: 0,
          shadowColor: 'rgba(0, 0, 0, 0.5)'
        }
      }
    }
  ]
}))

// 方法
const loadDashboardData = async () => {
  try {
    const response = await dashboardApi.getStats()
    stats.value = response.data
  } catch (error) {
    console.error('加载仪表板数据失败:', error)
  }
}

const loadRecentActivities = async () => {
  try {
    const response = await dashboardApi.getRecentActivities()
    recentActivities.value = response.data
  } catch (error) {
    console.error('加载最近活动失败:', error)
  }
}

const loadSystemInfo = async () => {
  systemInfoLoading.value = true
  try {
    const response = await dashboardApi.getSystemInfo()
    systemInfo.value = response.data
  } catch (error) {
    console.error('加载系统信息失败:', error)
  } finally {
    systemInfoLoading.value = false
  }
}

const handleSystemCheck = async () => {
  systemCheckLoading.value = true
  try {
    await dashboardApi.systemCheck()
    ElMessage.success('系统检查完成')
    await loadSystemInfo()
  } catch (error) {
    ElMessage.error('系统检查失败')
  } finally {
    systemCheckLoading.value = false
  }
}

const getActivityIcon = (type) => {
  const iconMap = {
    'customer': 'User',
    'node': 'Connection',
    'service': 'Monitor',
    'system': 'Tools'
  }
  return iconMap[type] || 'InfoFilled'
}

const getActivityColor = (type) => {
  const colorMap = {
    'customer': '#409EFF',
    'node': '#67C23A',
    'service': '#E6A23C',
    'system': '#F56C6C'
  }
  return colorMap[type] || '#909399'
}

// 生命周期
onMounted(() => {
  loadDashboardData()
  loadRecentActivities()
  loadSystemInfo()
  
  // 定时刷新数据
  setInterval(loadDashboardData, 30000)
  setInterval(loadSystemInfo, 60000)
})
</script>

<style lang="scss" scoped>
.dashboard {
  padding: 0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  background: var(--el-bg-color);
  border-radius: 8px;
  padding: 24px;
  display: flex;
  align-items: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid var(--el-border-color-light);
  
  .stat-icon {
    width: 64px;
    height: 64px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 16px;
    
    &.customers { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
    &.nodes { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; }
    &.services { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white; }
    &.revenue { background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); color: white; }
  }
  
  .stat-content {
    flex: 1;
    
    .stat-value {
      font-size: 28px;
      font-weight: 600;
      color: var(--el-text-color-primary);
      line-height: 1;
    }
    
    .stat-label {
      font-size: 14px;
      color: var(--el-text-color-regular);
      margin: 4px 0;
    }
    
    .stat-change {
      font-size: 12px;
      color: var(--el-text-color-secondary);
      display: flex;
      align-items: center;
      gap: 4px;
      
      &.positive {
        color: var(--el-color-success);
      }
    }
  }
}

.content-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 24px;
  margin-bottom: 24px;
}

.chart-card, .activity-card {
  background: var(--el-bg-color);
  border-radius: 8px;
  padding: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid var(--el-border-color-light);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  
  h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: var(--el-text-color-primary);
  }
}

.chart-container {
  height: 300px;
  
  .chart {
    width: 100%;
    height: 100%;
  }
}

.activity-list {
  max-height: 300px;
  overflow-y: auto;
}

.activity-item {
  display: flex;
  align-items: flex-start;
  padding: 12px 0;
  border-bottom: 1px solid var(--el-border-color-lighter);
  
  &:last-child {
    border-bottom: none;
  }
  
  .activity-icon {
    margin-right: 12px;
    margin-top: 2px;
  }
  
  .activity-content {
    flex: 1;
    
    .activity-title {
      font-size: 14px;
      font-weight: 500;
      color: var(--el-text-color-primary);
      margin-bottom: 4px;
    }
    
    .activity-desc {
      font-size: 12px;
      color: var(--el-text-color-regular);
      margin-bottom: 4px;
    }
    
    .activity-time {
      font-size: 11px;
      color: var(--el-text-color-secondary);
    }
  }
}

.bottom-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 24px;
}

.quick-actions-card, .system-info-card {
  background: var(--el-bg-color);
  border-radius: 8px;
  padding: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid var(--el-border-color-light);
}

.quick-actions {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 12px;
  
  .quick-action-btn {
    height: 60px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
}

.system-info {
  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 0;
    border-bottom: 1px solid var(--el-border-color-lighter);
    
    &:last-child {
      border-bottom: none;
    }
    
    .info-label {
      font-size: 14px;
      color: var(--el-text-color-regular);
    }
    
    .info-value {
      font-size: 14px;
      font-weight: 500;
      color: var(--el-text-color-primary);
    }
  }
}

// 响应式设计
@media (max-width: 1200px) {
  .content-grid, .bottom-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
  
  .quick-actions {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
