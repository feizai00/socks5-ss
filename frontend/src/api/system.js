import { request } from '@/utils/request'

export const systemApi = {
  // 获取系统状态
  getStatus() {
    return request.get('/system/status')
  },
  
  // 获取系统配置
  getConfig() {
    return request.get('/system/config')
  },
  
  // 更新系统配置
  updateConfig(data) {
    return request.put('/system/config', data)
  },
  
  // 系统备份
  backup() {
    return request.post('/system/backup')
  },
  
  // 获取备份列表
  getBackups() {
    return request.get('/system/backups')
  },
  
  // 恢复备份
  restore(backupId) {
    return request.post(`/system/restore/${backupId}`)
  },
  
  // 获取日志
  getLogs(params) {
    return request.get('/system/logs', params)
  },
  
  // 清理系统
  cleanup() {
    return request.post('/system/cleanup')
  }
}
