import { request } from '@/utils/request'

export const dashboardApi = {
  // 获取仪表板统计数据
  getStats() {
    return request.get('/dashboard/stats')
  },
  
  // 获取最近活动
  getRecentActivities(limit = 10) {
    return request.get('/dashboard/activities', { limit })
  },
  
  // 获取系统信息
  getSystemInfo() {
    return request.get('/dashboard/system-info')
  },
  
  // 系统检查
  systemCheck() {
    return request.post('/dashboard/system-check')
  },
  
  // 获取图表数据
  getChartData(type, timeRange = '7d') {
    return request.get('/dashboard/charts', { type, timeRange })
  }
}
