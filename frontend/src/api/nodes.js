import { request } from '@/utils/request'

export const nodesApi = {
  // 获取节点列表
  getNodes(params = {}) {
    return request.get('/nodes', params)
  },
  
  // 获取节点详情
  getNode(id) {
    return request.get(`/nodes/${id}`)
  },
  
  // 创建节点
  createNode(data) {
    return request.post('/nodes', data)
  },
  
  // 更新节点
  updateNode(id, data) {
    return request.put(`/nodes/${id}`, data)
  },
  
  // 删除节点
  deleteNode(id) {
    return request.delete(`/nodes/${id}`)
  },
  
  // 批量删除节点
  batchDeleteNodes(ids) {
    return request.post('/nodes/batch-delete', { ids })
  },
  
  // 测试节点连接
  testNode(id) {
    return request.post(`/nodes/${id}/test`)
  },
  
  // 批量测试节点
  batchTestNodes(ids) {
    return request.post('/nodes/batch-test', { ids })
  },
  
  // 获取节点统计
  getNodeStats(id) {
    return request.get(`/nodes/${id}/stats`)
  },
  
  // 获取节点的服务列表
  getNodeServices(id, params = {}) {
    return request.get(`/nodes/${id}/services`, params)
  },
  
  // 获取地区列表
  getRegions() {
    return request.get('/regions')
  },
  
  // 创建地区
  createRegion(data) {
    return request.post('/regions', data)
  },
  
  // 更新地区
  updateRegion(id, data) {
    return request.put(`/regions/${id}`, data)
  },
  
  // 删除地区
  deleteRegion(id) {
    return request.delete(`/regions/${id}`)
  },
  
  // 导出节点数据
  exportNodes(params = {}) {
    return request.download('/nodes/export', params, 'nodes.xlsx')
  },
  
  // 导入节点数据
  importNodes(file) {
    const formData = new FormData()
    formData.append('file', file)
    return request.upload('/nodes/import', formData)
  },
  
  // 获取可用节点（用于创建服务时选择）
  getAvailableNodes(params = {}) {
    return request.get('/nodes/available', params)
  }
}
