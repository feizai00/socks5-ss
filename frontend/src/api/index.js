// 真实API服务
// 当后端准备好时，替换mockApi的调用
import http from '@/utils/http'

// 客户管理API
export const customerApi = {
  // 获取客户列表
  async getCustomers(params = {}) {
    return await http.get('/customers', { params })
  },
  
  // 获取单个客户
  async getCustomer(id) {
    return await http.get(`/customers/${id}`)
  },
  
  // 创建客户
  async createCustomer(data) {
    return await http.post('/customers', data)
  },
  
  // 更新客户
  async updateCustomer(id, data) {
    return await http.put(`/customers/${id}`, data)
  },
  
  // 删除客户
  async deleteCustomer(id) {
    return await http.delete(`/customers/${id}`)
  },
  
  // 批量删除客户
  async batchDeleteCustomers(ids) {
    return await http.post('/customers/batch-delete', { ids })
  },
  
  // 获取客户的服务列表
  async getCustomerServices(customerId) {
    return await http.get(`/customers/${customerId}/services`)
  }
}

// 节点管理API
export const nodeApi = {
  // 获取节点列表
  async getNodes(params = {}) {
    return await http.get('/nodes', { params })
  },
  
  // 获取单个节点
  async getNode(id) {
    return await http.get(`/nodes/${id}`)
  },
  
  // 创建节点
  async createNode(data) {
    return await http.post('/nodes', data)
  },
  
  // 更新节点
  async updateNode(id, data) {
    return await http.put(`/nodes/${id}`, data)
  },
  
  // 删除节点
  async deleteNode(id) {
    return await http.delete(`/nodes/${id}`)
  },
  
  // 批量删除节点
  async batchDeleteNodes(ids) {
    return await http.post('/nodes/batch-delete', { ids })
  },
  
  // 测试节点连接
  async testNode(id) {
    return await http.post(`/nodes/${id}/test`)
  },
  
  // 批量测试节点
  async batchTestNodes(ids) {
    return await http.post('/nodes/batch-test', { ids })
  },
  
  // 获取节点的服务列表
  async getNodeServices(nodeId) {
    return await http.get(`/nodes/${nodeId}/services`)
  }
}

// 服务管理API
export const serviceApi = {
  // 获取服务列表
  async getServices(params = {}) {
    return await http.get('/services', { params })
  },
  
  // 获取单个服务
  async getService(id) {
    return await http.get(`/services/${id}`)
  },
  
  // 创建服务
  async createService(data) {
    return await http.post('/services', data)
  },
  
  // 更新服务
  async updateService(id, data) {
    return await http.put(`/services/${id}`, data)
  },
  
  // 删除服务
  async deleteService(id) {
    return await http.delete(`/services/${id}`)
  },
  
  // 批量删除服务
  async batchDeleteServices(ids) {
    return await http.post('/services/batch-delete', { ids })
  },
  
  // 启动服务
  async startService(id) {
    return await http.post(`/services/${id}/start`)
  },
  
  // 停止服务
  async stopService(id) {
    return await http.post(`/services/${id}/stop`)
  },
  
  // 重启服务
  async restartService(id) {
    return await http.post(`/services/${id}/restart`)
  },
  
  // 批量启动服务
  async batchStartServices(ids) {
    return await http.post('/services/batch-start', { ids })
  },
  
  // 批量停止服务
  async batchStopServices(ids) {
    return await http.post('/services/batch-stop', { ids })
  },
  
  // 获取服务配置
  async getServiceConfig(id) {
    return await http.get(`/services/${id}/config`)
  },
  
  // 生成服务配置文件
  async generateConfig(ids) {
    return await http.post('/services/generate-config', { ids })
  },
  
  // 获取服务统计
  async getServiceStats(id) {
    return await http.get(`/services/${id}/stats`)
  }
}

// 统计API
export const statsApi = {
  // 获取仪表板统计
  async getDashboardStats() {
    return await http.get('/stats/dashboard')
  },
  
  // 获取系统状态
  async getSystemStatus() {
    return await http.get('/stats/system')
  },
  
  // 获取流量统计
  async getTrafficStats(params = {}) {
    return await http.get('/stats/traffic', { params })
  }
}

// 认证API
export const authApi = {
  // 登录
  async login(credentials) {
    return await http.post('/auth/login', credentials)
  },
  
  // 登出
  async logout() {
    return await http.post('/auth/logout')
  },
  
  // 刷新token
  async refreshToken() {
    return await http.post('/auth/refresh')
  },
  
  // 获取用户信息
  async getUserInfo() {
    return await http.get('/auth/user')
  }
}

// 系统API
export const systemApi = {
  // 获取系统信息
  async getSystemInfo() {
    return await http.get('/system/info')
  },
  
  // 系统健康检查
  async healthCheck() {
    return await http.get('/system/health')
  },
  
  // 获取日志
  async getLogs(params = {}) {
    return await http.get('/system/logs', { params })
  }
}

// 导出所有API
export default {
  customer: customerApi,
  node: nodeApi,
  service: serviceApi,
  stats: statsApi,
  auth: authApi,
  system: systemApi
}
