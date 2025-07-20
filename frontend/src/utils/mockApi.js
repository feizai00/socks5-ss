// 模拟API服务
// 用于前端开发和测试，模拟后端API响应

// 模拟延迟
const delay = (ms = 500) => new Promise(resolve => setTimeout(resolve, ms))

// 模拟响应格式
const createResponse = (data, success = true, message = '') => ({
  success,
  data,
  message,
  timestamp: Date.now()
})

// 模拟数据存储
let mockData = {
  customers: [
    {
      id: 1,
      wechat_id: 'user001',
      wechat_name: '张三',
      phone: '13800138001',
      email: 'zhangsan@example.com',
      status: 'active',
      service_count: 2,
      notes: '重要客户',
      created_at: Date.now() / 1000 - 86400 * 7
    },
    {
      id: 2,
      wechat_id: 'user002',
      wechat_name: '李四',
      phone: '13800138002',
      email: 'lisi@example.com',
      status: 'active',
      service_count: 1,
      notes: '',
      created_at: Date.now() / 1000 - 86400 * 3
    }
  ],
  
  nodes: [
    {
      id: 1,
      name: '香港节点1',
      region: 'HK',
      host: '103.45.67.89',
      port: 1080,
      username: 'user1',
      password: 'pass1',
      status: 'online',
      latency: 45,
      service_count: 3,
      last_check: Date.now() / 1000 - 300,
      notes: '高速节点'
    },
    {
      id: 2,
      name: '美国节点1',
      region: 'US',
      host: '192.168.1.100',
      port: 1080,
      username: 'user2',
      password: 'pass2',
      status: 'online',
      latency: 180,
      service_count: 2,
      last_check: Date.now() / 1000 - 600,
      notes: '稳定节点'
    }
  ],
  
  services: [
    {
      id: 1,
      port: 10001,
      service_name: '香港高速服务',
      customer_id: 1,
      customer_name: '张三',
      node_id: 1,
      node_name: '香港节点1',
      server_host: '103.45.67.89',
      method: 'aes-256-gcm',
      password: 'abc123456',
      status: 'active',
      traffic_used: 1024 * 1024 * 1024 * 2.5,
      traffic_limit: 1024 * 1024 * 1024 * 100,
      expires_at: Date.now() / 1000 + 86400 * 30,
      created_at: Date.now() / 1000 - 86400 * 7,
      notes: '高速节点服务'
    }
  ]
}

// 客户管理API
export const customerApi = {
  // 获取客户列表
  async getCustomers(params = {}) {
    await delay()
    const { page = 1, pageSize = 20, search = '', status = '' } = params
    
    let customers = [...mockData.customers]
    
    // 搜索过滤
    if (search) {
      customers = customers.filter(c => 
        c.wechat_id.includes(search) || 
        c.wechat_name.includes(search)
      )
    }
    
    // 状态过滤
    if (status) {
      customers = customers.filter(c => c.status === status)
    }
    
    // 分页
    const total = customers.length
    const start = (page - 1) * pageSize
    const end = start + pageSize
    const data = customers.slice(start, end)
    
    return createResponse({
      list: data,
      total,
      page,
      pageSize
    })
  },
  
  // 创建客户
  async createCustomer(customerData) {
    await delay()
    
    const newCustomer = {
      id: Date.now(),
      ...customerData,
      service_count: 0,
      created_at: Date.now() / 1000
    }
    
    mockData.customers.unshift(newCustomer)
    
    return createResponse(newCustomer, true, '客户创建成功')
  },
  
  // 更新客户
  async updateCustomer(id, customerData) {
    await delay()
    
    const index = mockData.customers.findIndex(c => c.id === id)
    if (index === -1) {
      return createResponse(null, false, '客户不存在')
    }
    
    mockData.customers[index] = { ...mockData.customers[index], ...customerData }
    
    return createResponse(mockData.customers[index], true, '客户更新成功')
  },
  
  // 删除客户
  async deleteCustomer(id) {
    await delay()
    
    const index = mockData.customers.findIndex(c => c.id === id)
    if (index === -1) {
      return createResponse(null, false, '客户不存在')
    }
    
    mockData.customers.splice(index, 1)
    
    return createResponse(null, true, '客户删除成功')
  }
}

// 节点管理API
export const nodeApi = {
  // 获取节点列表
  async getNodes(params = {}) {
    await delay()
    const { page = 1, pageSize = 20, search = '', status = '', region = '' } = params
    
    let nodes = [...mockData.nodes]
    
    // 搜索过滤
    if (search) {
      nodes = nodes.filter(n => 
        n.name.includes(search) || 
        n.host.includes(search)
      )
    }
    
    // 状态过滤
    if (status) {
      nodes = nodes.filter(n => n.status === status)
    }
    
    // 地区过滤
    if (region) {
      nodes = nodes.filter(n => n.region === region)
    }
    
    // 分页
    const total = nodes.length
    const start = (page - 1) * pageSize
    const end = start + pageSize
    const data = nodes.slice(start, end)
    
    return createResponse({
      list: data,
      total,
      page,
      pageSize
    })
  },
  
  // 创建节点
  async createNode(nodeData) {
    await delay()
    
    const newNode = {
      id: Date.now(),
      ...nodeData,
      status: 'offline',
      latency: null,
      service_count: 0,
      last_check: null
    }
    
    mockData.nodes.unshift(newNode)
    
    return createResponse(newNode, true, '节点创建成功')
  },
  
  // 更新节点
  async updateNode(id, nodeData) {
    await delay()
    
    const index = mockData.nodes.findIndex(n => n.id === id)
    if (index === -1) {
      return createResponse(null, false, '节点不存在')
    }
    
    mockData.nodes[index] = { ...mockData.nodes[index], ...nodeData }
    
    return createResponse(mockData.nodes[index], true, '节点更新成功')
  },
  
  // 删除节点
  async deleteNode(id) {
    await delay()
    
    const index = mockData.nodes.findIndex(n => n.id === id)
    if (index === -1) {
      return createResponse(null, false, '节点不存在')
    }
    
    mockData.nodes.splice(index, 1)
    
    return createResponse(null, true, '节点删除成功')
  },
  
  // 测试节点
  async testNode(id) {
    await delay(2000) // 模拟测试时间
    
    const index = mockData.nodes.findIndex(n => n.id === id)
    if (index === -1) {
      return createResponse(null, false, '节点不存在')
    }
    
    // 模拟测试结果
    const latency = Math.floor(Math.random() * 300) + 20
    const isOnline = Math.random() > 0.2
    
    mockData.nodes[index].status = isOnline ? 'online' : 'offline'
    mockData.nodes[index].latency = isOnline ? latency : null
    mockData.nodes[index].last_check = Date.now() / 1000
    
    return createResponse(mockData.nodes[index], true, '节点测试完成')
  }
}

// 服务管理API
export const serviceApi = {
  // 获取服务列表
  async getServices(params = {}) {
    await delay()
    const { page = 1, pageSize = 20, search = '', status = '', nodeId = '' } = params
    
    let services = [...mockData.services]
    
    // 搜索过滤
    if (search) {
      services = services.filter(s => 
        s.service_name.includes(search) || 
        s.customer_name.includes(search) ||
        s.port.toString().includes(search)
      )
    }
    
    // 状态过滤
    if (status) {
      services = services.filter(s => s.status === status)
    }
    
    // 节点过滤
    if (nodeId) {
      services = services.filter(s => s.node_id === parseInt(nodeId))
    }
    
    // 分页
    const total = services.length
    const start = (page - 1) * pageSize
    const end = start + pageSize
    const data = services.slice(start, end)
    
    return createResponse({
      list: data,
      total,
      page,
      pageSize
    })
  },
  
  // 创建服务
  async createService(serviceData) {
    await delay()
    
    const customer = mockData.customers.find(c => c.id === serviceData.customer_id)
    const node = mockData.nodes.find(n => n.id === serviceData.node_id)
    
    if (!customer || !node) {
      return createResponse(null, false, '客户或节点不存在')
    }
    
    const newService = {
      id: Date.now(),
      ...serviceData,
      customer_name: customer.wechat_name,
      node_name: node.name,
      server_host: node.host,
      port: serviceData.port || Math.floor(Math.random() * 10000) + 10000,
      password: serviceData.password || generateRandomPassword(),
      status: serviceData.auto_start ? 'active' : 'stopped',
      traffic_used: 0,
      created_at: Date.now() / 1000
    }
    
    mockData.services.unshift(newService)
    
    // 更新客户服务数量
    customer.service_count = (customer.service_count || 0) + 1
    
    // 更新节点服务数量
    node.service_count = (node.service_count || 0) + 1
    
    return createResponse(newService, true, '服务创建成功')
  },
  
  // 更新服务
  async updateService(id, serviceData) {
    await delay()
    
    const index = mockData.services.findIndex(s => s.id === id)
    if (index === -1) {
      return createResponse(null, false, '服务不存在')
    }
    
    mockData.services[index] = { ...mockData.services[index], ...serviceData }
    
    return createResponse(mockData.services[index], true, '服务更新成功')
  },
  
  // 删除服务
  async deleteService(id) {
    await delay()
    
    const index = mockData.services.findIndex(s => s.id === id)
    if (index === -1) {
      return createResponse(null, false, '服务不存在')
    }
    
    const service = mockData.services[index]
    
    // 更新客户服务数量
    const customer = mockData.customers.find(c => c.id === service.customer_id)
    if (customer) {
      customer.service_count = Math.max(0, (customer.service_count || 0) - 1)
    }
    
    // 更新节点服务数量
    const node = mockData.nodes.find(n => n.id === service.node_id)
    if (node) {
      node.service_count = Math.max(0, (node.service_count || 0) - 1)
    }
    
    mockData.services.splice(index, 1)
    
    return createResponse(null, true, '服务删除成功')
  },
  
  // 切换服务状态
  async toggleServiceStatus(id) {
    await delay()
    
    const index = mockData.services.findIndex(s => s.id === id)
    if (index === -1) {
      return createResponse(null, false, '服务不存在')
    }
    
    const service = mockData.services[index]
    service.status = service.status === 'active' ? 'stopped' : 'active'
    
    return createResponse(service, true, `服务${service.status === 'active' ? '启动' : '停止'}成功`)
  }
}

// 统计API
export const statsApi = {
  // 获取仪表板统计
  async getDashboardStats() {
    await delay()
    
    const stats = {
      customers: mockData.customers.length,
      nodes: mockData.nodes.length,
      services: mockData.services.length,
      active: mockData.services.filter(s => s.status === 'active').length
    }
    
    return createResponse(stats)
  }
}

// 工具函数
function generateRandomPassword() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let password = ''
  for (let i = 0; i < 12; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return password
}

// 导出所有API
export default {
  customer: customerApi,
  node: nodeApi,
  service: serviceApi,
  stats: statsApi
}
