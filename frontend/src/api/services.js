import { request } from '@/utils/request'

export const servicesApi = {
  // 获取服务列表
  getServices(params = {}) {
    return request.get('/services/enhanced', params)
  },
  
  // 获取服务详情
  getService(id) {
    return request.get(`/services/${id}`)
  },
  
  // 创建服务
  createService(data) {
    return request.post('/services/enhanced', data)
  },
  
  // 更新服务
  updateService(id, data) {
    return request.put(`/services/${id}`, data)
  },
  
  // 删除服务
  deleteService(id) {
    return request.delete(`/services/${id}`)
  },
  
  // 批量删除服务
  batchDeleteServices(ids) {
    return request.post('/services/batch-delete', { ids })
  },
  
  // 启动服务
  startService(id) {
    return request.post(`/services/${id}/start`)
  },
  
  // 停止服务
  stopService(id) {
    return request.post(`/services/${id}/stop`)
  },
  
  // 重启服务
  restartService(id) {
    return request.post(`/services/${id}/restart`)
  },
  
  // 批量操作服务
  batchOperateServices(ids, action) {
    return request.post('/services/batch-operate', { ids, action })
  },
  
  // 获取服务连接信息
  getServiceConnectionInfo(id) {
    return request.get(`/services/${id}/connection-info`)
  },
  
  // 生成服务二维码
  generateServiceQRCode(id) {
    return request.get(`/services/${id}/qrcode`)
  },
  
  // 获取服务配置文件
  getServiceConfig(id) {
    return request.get(`/services/${id}/config`)
  },
  
  // 更新服务配置
  updateServiceConfig(id, config) {
    return request.put(`/services/${id}/config`, config)
  },
  
  // 获取服务日志
  getServiceLogs(id, params = {}) {
    return request.get(`/services/${id}/logs`, params)
  },
  
  // 获取服务统计
  getServiceStats(id) {
    return request.get(`/services/${id}/stats`)
  },
  
  // 测试服务连接
  testService(id) {
    return request.post(`/services/${id}/test`)
  },
  
  // 分配服务给客户
  assignServiceToCustomer(serviceId, customerId, data = {}) {
    return request.post(`/services/${serviceId}/assign`, { customerId, ...data })
  },
  
  // 取消服务分配
  unassignService(serviceId) {
    return request.post(`/services/${serviceId}/unassign`)
  },
  
  // 批量分配服务
  batchAssignServices(serviceIds, customerId, data = {}) {
    return request.post('/services/batch-assign', { serviceIds, customerId, ...data })
  },
  
  // 导出服务数据
  exportServices(params = {}) {
    return request.download('/services/export', params, 'services.xlsx')
  },
  
  // 导出服务配置
  exportServiceConfigs(ids) {
    return request.download('/services/export-configs', { ids }, 'service-configs.zip')
  },
  
  // 获取服务模板
  getServiceTemplates() {
    return request.get('/services/templates')
  },
  
  // 从模板创建服务
  createServiceFromTemplate(templateId, data) {
    return request.post(`/services/templates/${templateId}/create`, data)
  },
  
  // 克隆服务
  cloneService(id, data = {}) {
    return request.post(`/services/${id}/clone`, data)
  }
}
