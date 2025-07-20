import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { nodesApi } from '@/api/nodes'

export const useNodesStore = defineStore('nodes', () => {
  // 状态
  const nodes = ref([])
  const regions = ref([])
  const currentNode = ref(null)
  const loading = ref(false)
  const total = ref(0)
  const pagination = ref({
    page: 1,
    limit: 20
  })
  const filters = ref({
    search: '',
    region_id: '',
    status: ''
  })

  // 计算属性
  const activeNodes = computed(() => 
    nodes.value.filter(node => node.status === 'active')
  )
  
  const availableNodes = computed(() =>
    nodes.value.filter(node => 
      node.status === 'active' && 
      node.current_connections < node.max_connections
    )
  )
  
  const nodeOptions = computed(() =>
    availableNodes.value.map(node => ({
      label: `${node.region?.flag_emoji || ''} ${node.node_name} (${node.current_connections}/${node.max_connections})`,
      value: node.id,
      disabled: node.current_connections >= node.max_connections
    }))
  )
  
  const regionOptions = computed(() =>
    regions.value.map(region => ({
      label: `${region.flag_emoji} ${region.name}`,
      value: region.id
    }))
  )

  // 获取节点列表
  const fetchNodes = async (params = {}) => {
    loading.value = true
    try {
      const response = await nodesApi.getNodes({
        ...pagination.value,
        ...filters.value,
        ...params
      })
      
      nodes.value = response.data.nodes || response.data
      total.value = response.data.total || nodes.value.length
      
      return response
    } catch (error) {
      console.error('获取节点列表失败:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  // 获取地区列表
  const fetchRegions = async () => {
    try {
      const response = await nodesApi.getRegions()
      regions.value = response.data
      return response
    } catch (error) {
      console.error('获取地区列表失败:', error)
      throw error
    }
  }

  // 获取节点详情
  const fetchNode = async (id) => {
    try {
      const response = await nodesApi.getNode(id)
      currentNode.value = response.data
      return response.data
    } catch (error) {
      console.error('获取节点详情失败:', error)
      throw error
    }
  }

  // 创建节点
  const createNode = async (data) => {
    try {
      const response = await nodesApi.createNode(data)
      await fetchNodes() // 刷新列表
      return response
    } catch (error) {
      console.error('创建节点失败:', error)
      throw error
    }
  }

  // 更新节点
  const updateNode = async (id, data) => {
    try {
      const response = await nodesApi.updateNode(id, data)
      
      // 更新本地数据
      const index = nodes.value.findIndex(n => n.id === id)
      if (index !== -1) {
        nodes.value[index] = { ...nodes.value[index], ...data }
      }
      
      if (currentNode.value?.id === id) {
        currentNode.value = { ...currentNode.value, ...data }
      }
      
      return response
    } catch (error) {
      console.error('更新节点失败:', error)
      throw error
    }
  }

  // 删除节点
  const deleteNode = async (id) => {
    try {
      const response = await nodesApi.deleteNode(id)
      
      // 从本地列表中移除
      nodes.value = nodes.value.filter(n => n.id !== id)
      total.value = Math.max(0, total.value - 1)
      
      if (currentNode.value?.id === id) {
        currentNode.value = null
      }
      
      return response
    } catch (error) {
      console.error('删除节点失败:', error)
      throw error
    }
  }

  // 批量删除节点
  const batchDeleteNodes = async (ids) => {
    try {
      const response = await nodesApi.batchDeleteNodes(ids)
      
      // 从本地列表中移除
      nodes.value = nodes.value.filter(n => !ids.includes(n.id))
      total.value = Math.max(0, total.value - ids.length)
      
      return response
    } catch (error) {
      console.error('批量删除节点失败:', error)
      throw error
    }
  }

  // 测试节点连接
  const testNode = async (id) => {
    try {
      const response = await nodesApi.testNode(id)
      
      // 更新节点状态
      const node = nodes.value.find(n => n.id === id)
      if (node) {
        node.last_test_at = Date.now() / 1000
        node.test_result = response.data.success ? 'success' : 'failed'
      }
      
      return response
    } catch (error) {
      console.error('测试节点连接失败:', error)
      throw error
    }
  }

  // 批量测试节点
  const batchTestNodes = async (ids) => {
    try {
      const response = await nodesApi.batchTestNodes(ids)
      
      // 更新节点状态
      const now = Date.now() / 1000
      response.data.results?.forEach(result => {
        const node = nodes.value.find(n => n.id === result.id)
        if (node) {
          node.last_test_at = now
          node.test_result = result.success ? 'success' : 'failed'
        }
      })
      
      return response
    } catch (error) {
      console.error('批量测试节点失败:', error)
      throw error
    }
  }

  // 搜索节点
  const searchNodes = async (keyword) => {
    filters.value.search = keyword
    pagination.value.page = 1
    return await fetchNodes()
  }

  // 筛选节点
  const filterNodes = async (filterData) => {
    filters.value = { ...filters.value, ...filterData }
    pagination.value.page = 1
    return await fetchNodes()
  }

  // 分页
  const changePage = async (page) => {
    pagination.value.page = page
    return await fetchNodes()
  }

  const changePageSize = async (limit) => {
    pagination.value.limit = limit
    pagination.value.page = 1
    return await fetchNodes()
  }

  // 重置筛选
  const resetFilters = () => {
    filters.value = {
      search: '',
      region_id: '',
      status: ''
    }
    pagination.value.page = 1
  }

  // 获取节点统计
  const fetchNodeStats = async (id) => {
    try {
      const response = await nodesApi.getNodeStats(id)
      return response.data
    } catch (error) {
      console.error('获取节点统计失败:', error)
      throw error
    }
  }

  // 获取节点的服务列表
  const fetchNodeServices = async (nodeId, params = {}) => {
    try {
      const response = await nodesApi.getNodeServices(nodeId, params)
      return response.data
    } catch (error) {
      console.error('获取节点服务列表失败:', error)
      throw error
    }
  }

  // 创建地区
  const createRegion = async (data) => {
    try {
      const response = await nodesApi.createRegion(data)
      await fetchRegions() // 刷新地区列表
      return response
    } catch (error) {
      console.error('创建地区失败:', error)
      throw error
    }
  }

  // 更新地区
  const updateRegion = async (id, data) => {
    try {
      const response = await nodesApi.updateRegion(id, data)
      
      // 更新本地数据
      const index = regions.value.findIndex(r => r.id === id)
      if (index !== -1) {
        regions.value[index] = { ...regions.value[index], ...data }
      }
      
      return response
    } catch (error) {
      console.error('更新地区失败:', error)
      throw error
    }
  }

  // 删除地区
  const deleteRegion = async (id) => {
    try {
      const response = await nodesApi.deleteRegion(id)
      
      // 从本地列表中移除
      regions.value = regions.value.filter(r => r.id !== id)
      
      return response
    } catch (error) {
      console.error('删除地区失败:', error)
      throw error
    }
  }

  return {
    // 状态
    nodes,
    regions,
    currentNode,
    loading,
    total,
    pagination,
    filters,
    
    // 计算属性
    activeNodes,
    availableNodes,
    nodeOptions,
    regionOptions,
    
    // 方法
    fetchNodes,
    fetchRegions,
    fetchNode,
    createNode,
    updateNode,
    deleteNode,
    batchDeleteNodes,
    testNode,
    batchTestNodes,
    searchNodes,
    filterNodes,
    changePage,
    changePageSize,
    resetFilters,
    fetchNodeStats,
    fetchNodeServices,
    createRegion,
    updateRegion,
    deleteRegion
  }
})
