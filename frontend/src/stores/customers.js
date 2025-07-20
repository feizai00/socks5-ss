import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { customersApi } from '@/api/customers'

export const useCustomersStore = defineStore('customers', () => {
  // 状态
  const customers = ref([])
  const currentCustomer = ref(null)
  const loading = ref(false)
  const total = ref(0)
  const pagination = ref({
    page: 1,
    limit: 20
  })
  const filters = ref({
    search: '',
    status: '',
    wechat_id: ''
  })

  // 计算属性
  const activeCustomers = computed(() => 
    customers.value.filter(customer => customer.status === 'active')
  )
  
  const customerOptions = computed(() =>
    customers.value.map(customer => ({
      label: `${customer.wechat_name} (${customer.wechat_id})`,
      value: customer.id
    }))
  )

  // 获取客户列表
  const fetchCustomers = async (params = {}) => {
    loading.value = true
    try {
      const response = await customersApi.getCustomers({
        ...pagination.value,
        ...filters.value,
        ...params
      })
      
      customers.value = response.data.customers || response.data
      total.value = response.data.total || customers.value.length
      
      return response
    } catch (error) {
      console.error('获取客户列表失败:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  // 获取客户详情
  const fetchCustomer = async (id) => {
    try {
      const response = await customersApi.getCustomer(id)
      currentCustomer.value = response.data
      return response.data
    } catch (error) {
      console.error('获取客户详情失败:', error)
      throw error
    }
  }

  // 创建客户
  const createCustomer = async (data) => {
    try {
      const response = await customersApi.createCustomer(data)
      await fetchCustomers() // 刷新列表
      return response
    } catch (error) {
      console.error('创建客户失败:', error)
      throw error
    }
  }

  // 更新客户
  const updateCustomer = async (id, data) => {
    try {
      const response = await customersApi.updateCustomer(id, data)
      
      // 更新本地数据
      const index = customers.value.findIndex(c => c.id === id)
      if (index !== -1) {
        customers.value[index] = { ...customers.value[index], ...data }
      }
      
      if (currentCustomer.value?.id === id) {
        currentCustomer.value = { ...currentCustomer.value, ...data }
      }
      
      return response
    } catch (error) {
      console.error('更新客户失败:', error)
      throw error
    }
  }

  // 删除客户
  const deleteCustomer = async (id) => {
    try {
      const response = await customersApi.deleteCustomer(id)
      
      // 从本地列表中移除
      customers.value = customers.value.filter(c => c.id !== id)
      total.value = Math.max(0, total.value - 1)
      
      if (currentCustomer.value?.id === id) {
        currentCustomer.value = null
      }
      
      return response
    } catch (error) {
      console.error('删除客户失败:', error)
      throw error
    }
  }

  // 批量删除客户
  const batchDeleteCustomers = async (ids) => {
    try {
      const response = await customersApi.batchDeleteCustomers(ids)
      
      // 从本地列表中移除
      customers.value = customers.value.filter(c => !ids.includes(c.id))
      total.value = Math.max(0, total.value - ids.length)
      
      return response
    } catch (error) {
      console.error('批量删除客户失败:', error)
      throw error
    }
  }

  // 搜索客户
  const searchCustomers = async (keyword) => {
    filters.value.search = keyword
    pagination.value.page = 1
    return await fetchCustomers()
  }

  // 筛选客户
  const filterCustomers = async (filterData) => {
    filters.value = { ...filters.value, ...filterData }
    pagination.value.page = 1
    return await fetchCustomers()
  }

  // 分页
  const changePage = async (page) => {
    pagination.value.page = page
    return await fetchCustomers()
  }

  const changePageSize = async (limit) => {
    pagination.value.limit = limit
    pagination.value.page = 1
    return await fetchCustomers()
  }

  // 重置筛选
  const resetFilters = () => {
    filters.value = {
      search: '',
      status: '',
      wechat_id: ''
    }
    pagination.value.page = 1
  }

  // 获取客户的服务列表
  const fetchCustomerServices = async (customerId, params = {}) => {
    try {
      const response = await customersApi.getCustomerServices(customerId, params)
      return response.data
    } catch (error) {
      console.error('获取客户服务列表失败:', error)
      throw error
    }
  }

  // 为客户分配服务
  const assignServiceToCustomer = async (customerId, serviceId, data = {}) => {
    try {
      const response = await customersApi.assignService(customerId, serviceId, data)
      
      // 更新客户的服务数量
      const customer = customers.value.find(c => c.id === customerId)
      if (customer) {
        customer.service_count = (customer.service_count || 0) + 1
      }
      
      return response
    } catch (error) {
      console.error('分配服务失败:', error)
      throw error
    }
  }

  // 取消客户服务分配
  const unassignServiceFromCustomer = async (customerId, serviceId) => {
    try {
      const response = await customersApi.unassignService(customerId, serviceId)
      
      // 更新客户的服务数量
      const customer = customers.value.find(c => c.id === customerId)
      if (customer && customer.service_count > 0) {
        customer.service_count = customer.service_count - 1
      }
      
      return response
    } catch (error) {
      console.error('取消服务分配失败:', error)
      throw error
    }
  }

  return {
    // 状态
    customers,
    currentCustomer,
    loading,
    total,
    pagination,
    filters,
    
    // 计算属性
    activeCustomers,
    customerOptions,
    
    // 方法
    fetchCustomers,
    fetchCustomer,
    createCustomer,
    updateCustomer,
    deleteCustomer,
    batchDeleteCustomers,
    searchCustomers,
    filterCustomers,
    changePage,
    changePageSize,
    resetFilters,
    fetchCustomerServices,
    assignServiceToCustomer,
    unassignServiceFromCustomer
  }
})
