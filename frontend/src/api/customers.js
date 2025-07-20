import { request } from '@/utils/request'

export const customersApi = {
  // 获取客户列表
  getCustomers(params = {}) {
    return request.get('/customers', params)
  },
  
  // 获取客户详情
  getCustomer(id) {
    return request.get(`/customers/${id}`)
  },
  
  // 创建客户
  createCustomer(data) {
    return request.post('/customers', data)
  },
  
  // 更新客户
  updateCustomer(id, data) {
    return request.put(`/customers/${id}`, data)
  },
  
  // 删除客户
  deleteCustomer(id) {
    return request.delete(`/customers/${id}`)
  },
  
  // 批量删除客户
  batchDeleteCustomers(ids) {
    return request.post('/customers/batch-delete', { ids })
  },
  
  // 获取客户的服务列表
  getCustomerServices(id, params = {}) {
    return request.get(`/customers/${id}/services`, params)
  },
  
  // 为客户分配服务
  assignService(customerId, serviceId, data = {}) {
    return request.post(`/customers/${customerId}/services/${serviceId}`, data)
  },
  
  // 取消客户服务分配
  unassignService(customerId, serviceId) {
    return request.delete(`/customers/${customerId}/services/${serviceId}`)
  },
  
  // 导出客户数据
  exportCustomers(params = {}) {
    return request.download('/customers/export', params, 'customers.xlsx')
  },
  
  // 导入客户数据
  importCustomers(file) {
    const formData = new FormData()
    formData.append('file', file)
    return request.upload('/customers/import', formData)
  },
  
  // 获取客户统计
  getCustomerStats() {
    return request.get('/customers/stats')
  }
}
