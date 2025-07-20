<template>
  <div class="customers-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">客户管理</h1>
        <p class="page-description">管理所有客户信息，包括微信号、联系方式和服务使用情况</p>
      </div>
      <div class="header-right">
        <el-button type="primary" @click="showCreateDialog = true">
          <el-icon><Plus /></el-icon>
          添加客户
        </el-button>
      </div>
    </div>

    <!-- 筛选工具栏 -->
    <div class="filter-toolbar">
      <div class="filter-left">
        <el-input
          v-model="searchKeyword"
          placeholder="搜索客户微信号、名称..."
          style="width: 300px"
          clearable
          @input="handleSearch"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
        
        <el-select
          v-model="statusFilter"
          placeholder="客户状态"
          style="width: 120px"
          clearable
          @change="handleFilter"
        >
          <el-option label="活跃" value="active" />
          <el-option label="暂停" value="suspended" />
          <el-option label="过期" value="expired" />
        </el-select>
      </div>
      
      <div class="filter-right">
        <el-button @click="handleRefresh" :loading="customersStore.loading">
          <el-icon><Refresh /></el-icon>
          刷新
        </el-button>
        <el-button @click="handleExport">
          <el-icon><Download /></el-icon>
          导出
        </el-button>
        <el-button @click="showImportDialog = true">
          <el-icon><Upload /></el-icon>
          导入
        </el-button>
      </div>
    </div>

    <!-- 客户列表 -->
    <div class="table-container">
      <el-table
        :data="customersStore.customers"
        :loading="customersStore.loading"
        @selection-change="handleSelectionChange"
        row-key="id"
        class="customers-table"
      >
        <el-table-column type="selection" width="55" />
        
        <el-table-column prop="wechat_id" label="微信号" width="150">
          <template #default="{ row }">
            <div class="wechat-info">
              <el-avatar :size="32" class="wechat-avatar">
                {{ row.wechat_name?.charAt(0) }}
              </el-avatar>
              <span class="wechat-id">{{ row.wechat_id }}</span>
            </div>
          </template>
        </el-table-column>
        
        <el-table-column prop="wechat_name" label="微信名称" width="150" />
        
        <el-table-column prop="service_count" label="服务数量" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.service_count > 0 ? 'success' : 'info'" size="small">
              {{ row.service_count || 0 }}
            </el-tag>
          </template>
        </el-table-column>
        
        <el-table-column prop="phone" label="电话" width="130" />
        
        <el-table-column prop="email" label="邮箱" width="180" />
        
        <el-table-column prop="status" label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.status)" size="small">
              {{ getStatusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        
        <el-table-column prop="created_at" label="创建时间" width="180">
          <template #default="{ row }">
            {{ formatTime(row.created_at) }}
          </template>
        </el-table-column>
        
        <el-table-column prop="notes" label="备注" min-width="150" show-overflow-tooltip />
        
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="viewCustomerServices(row)">
              服务
            </el-button>
            <el-button size="small" type="warning" @click="editCustomer(row)">
              编辑
            </el-button>
            <el-button size="small" type="danger" @click="deleteCustomer(row)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 分页 -->
    <div class="pagination-container">
      <el-pagination
        v-model:current-page="customersStore.pagination.page"
        v-model:page-size="customersStore.pagination.limit"
        :total="customersStore.total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, sizes, prev, pager, next, jumper"
        @size-change="handlePageSizeChange"
        @current-change="handlePageChange"
      />
    </div>

    <!-- 批量操作栏 -->
    <div v-if="selectedCustomers.length > 0" class="batch-actions">
      <div class="batch-info">
        已选择 {{ selectedCustomers.length }} 个客户
      </div>
      <div class="batch-buttons">
        <el-button @click="clearSelection">取消选择</el-button>
        <el-button type="danger" @click="batchDeleteCustomers">
          批量删除
        </el-button>
      </div>
    </div>

    <!-- 创建/编辑客户对话框 -->
    <CustomerDialog
      v-model="showCreateDialog"
      :customer="editingCustomer"
      @success="handleDialogSuccess"
    />

    <!-- 客户服务对话框 -->
    <CustomerServicesDialog
      v-model="showServicesDialog"
      :customer="selectedCustomer"
    />

    <!-- 导入对话框 -->
    <ImportDialog
      v-model="showImportDialog"
      title="导入客户数据"
      :api="customersApi.importCustomers"
      @success="handleImportSuccess"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useCustomersStore } from '@/stores/customers'
import { customersApi } from '@/api/customers'
import { formatTime, debounce } from '@/utils/format'
import CustomerDialog from '@/components/CustomerDialog.vue'
import CustomerServicesDialog from '@/components/CustomerServicesDialog.vue'
import ImportDialog from '@/components/ImportDialog.vue'

const customersStore = useCustomersStore()

// 响应式数据
const searchKeyword = ref('')
const statusFilter = ref('')
const selectedCustomers = ref([])
const editingCustomer = ref(null)
const selectedCustomer = ref(null)

// 对话框控制
const showCreateDialog = ref(false)
const showServicesDialog = ref(false)
const showImportDialog = ref(false)

// 搜索防抖
const handleSearch = debounce((keyword) => {
  customersStore.searchCustomers(keyword)
}, 500)

// 方法
const handleFilter = () => {
  customersStore.filterCustomers({ status: statusFilter.value })
}

const handleRefresh = () => {
  customersStore.fetchCustomers()
}

const handleExport = async () => {
  try {
    await customersApi.exportCustomers({
      ...customersStore.filters,
      ids: selectedCustomers.value.map(c => c.id)
    })
    ElMessage.success('导出成功')
  } catch (error) {
    ElMessage.error('导出失败')
  }
}

const handleSelectionChange = (selection) => {
  selectedCustomers.value = selection
}

const clearSelection = () => {
  selectedCustomers.value = []
}

const handlePageChange = (page) => {
  customersStore.changePage(page)
}

const handlePageSizeChange = (size) => {
  customersStore.changePageSize(size)
}

const viewCustomerServices = (customer) => {
  selectedCustomer.value = customer
  showServicesDialog.value = true
}

const editCustomer = (customer) => {
  editingCustomer.value = customer
  showCreateDialog.value = true
}

const deleteCustomer = async (customer) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除客户 "${customer.wechat_name}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    
    await customersStore.deleteCustomer(customer.id)
    ElMessage.success('删除成功')
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const batchDeleteCustomers = async () => {
  try {
    await ElMessageBox.confirm(
      `确定要删除选中的 ${selectedCustomers.value.length} 个客户吗？`,
      '确认批量删除',
      { type: 'warning' }
    )
    
    const ids = selectedCustomers.value.map(c => c.id)
    await customersStore.batchDeleteCustomers(ids)
    selectedCustomers.value = []
    ElMessage.success('批量删除成功')
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('批量删除失败')
    }
  }
}

const handleDialogSuccess = () => {
  showCreateDialog.value = false
  editingCustomer.value = null
  customersStore.fetchCustomers()
}

const handleImportSuccess = () => {
  showImportDialog.value = false
  customersStore.fetchCustomers()
}

const getStatusType = (status) => {
  const statusMap = {
    'active': 'success',
    'suspended': 'warning',
    'expired': 'danger'
  }
  return statusMap[status] || 'info'
}

const getStatusText = (status) => {
  const statusMap = {
    'active': '活跃',
    'suspended': '暂停',
    'expired': '过期'
  }
  return statusMap[status] || status
}

// 监听搜索关键词
watch(searchKeyword, (newVal) => {
  if (newVal !== customersStore.filters.search) {
    handleSearch(newVal)
  }
})

// 生命周期
onMounted(() => {
  customersStore.fetchCustomers()
})
</script>

<style lang="scss" scoped>
.customers-page {
  padding: 0;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
  
  .header-left {
    .page-title {
      font-size: 24px;
      font-weight: 600;
      color: var(--el-text-color-primary);
      margin: 0 0 8px 0;
    }
    
    .page-description {
      color: var(--el-text-color-regular);
      margin: 0;
      font-size: 14px;
    }
  }
}

.filter-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding: 16px;
  background: var(--el-bg-color);
  border-radius: 8px;
  border: 1px solid var(--el-border-color-light);
  
  .filter-left {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .filter-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }
}

.table-container {
  background: var(--el-bg-color);
  border-radius: 8px;
  border: 1px solid var(--el-border-color-light);
  overflow: hidden;
}

.customers-table {
  .wechat-info {
    display: flex;
    align-items: center;
    gap: 8px;
    
    .wechat-avatar {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      font-weight: 500;
    }
    
    .wechat-id {
      font-family: monospace;
      font-size: 13px;
    }
  }
}

.pagination-container {
  display: flex;
  justify-content: center;
  margin-top: 24px;
}

.batch-actions {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--el-bg-color);
  border: 1px solid var(--el-border-color);
  border-radius: 8px;
  padding: 12px 24px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  gap: 16px;
  z-index: 1000;
  
  .batch-info {
    color: var(--el-text-color-primary);
    font-weight: 500;
  }
  
  .batch-buttons {
    display: flex;
    gap: 8px;
  }
}

// 响应式设计
@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    gap: 16px;
    align-items: stretch;
  }
  
  .filter-toolbar {
    flex-direction: column;
    gap: 12px;
    align-items: stretch;
    
    .filter-left {
      flex-direction: column;
      align-items: stretch;
    }
    
    .filter-right {
      justify-content: center;
    }
  }
  
  .customers-table {
    :deep(.el-table__body-wrapper) {
      overflow-x: auto;
    }
  }
  
  .batch-actions {
    left: 16px;
    right: 16px;
    transform: none;
    flex-direction: column;
    text-align: center;
  }
}
</style>
