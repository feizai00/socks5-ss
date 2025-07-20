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
        <el-button @click="handleRefresh" :loading="loading">
          <el-icon><Refresh /></el-icon>
          刷新
        </el-button>
      </div>
    </div>

    <!-- 客户列表 -->
    <div class="table-container">
      <el-table
        :data="filteredCustomers"
        :loading="loading"
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
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :total="total"
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
    <el-dialog
      v-model="showCreateDialog"
      :title="editingCustomer ? '编辑客户' : '添加客户'"
      width="500px"
      @close="resetForm"
    >
      <el-form
        ref="customerFormRef"
        :model="customerForm"
        :rules="customerRules"
        label-width="100px"
      >
        <el-form-item label="微信号" prop="wechat_id">
          <el-input v-model="customerForm.wechat_id" placeholder="请输入客户微信号" />
        </el-form-item>
        
        <el-form-item label="微信名称" prop="wechat_name">
          <el-input v-model="customerForm.wechat_name" placeholder="请输入客户微信名称" />
        </el-form-item>
        
        <el-form-item label="电话">
          <el-input v-model="customerForm.phone" placeholder="请输入客户电话" />
        </el-form-item>
        
        <el-form-item label="邮箱">
          <el-input v-model="customerForm.email" placeholder="请输入客户邮箱" />
        </el-form-item>
        
        <el-form-item label="状态">
          <el-select v-model="customerForm.status" style="width: 100%">
            <el-option label="活跃" value="active" />
            <el-option label="暂停" value="suspended" />
            <el-option label="过期" value="expired" />
          </el-select>
        </el-form-item>
        
        <el-form-item label="备注">
          <el-input
            v-model="customerForm.notes"
            type="textarea"
            :rows="3"
            placeholder="客户备注信息"
          />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit" :loading="submitLoading">
          {{ editingCustomer ? '更新' : '创建' }}
        </el-button>
      </template>
    </el-dialog>

    <!-- 客户服务对话框 -->
    <el-dialog
      v-model="showServicesDialog"
      title="客户服务列表"
      width="800px"
    >
      <div v-if="selectedCustomer">
        <div class="customer-info">
          <h3>{{ selectedCustomer.wechat_name }} ({{ selectedCustomer.wechat_id }})</h3>
          <p>当前服务数量: {{ selectedCustomer.service_count || 0 }}</p>
        </div>
        
        <el-table :data="customerServices" style="width: 100%">
          <el-table-column prop="port" label="端口" width="100" />
          <el-table-column prop="service_name" label="服务名称" width="150" />
          <el-table-column prop="status" label="状态" width="100">
            <template #default="{ row }">
              <el-tag :type="row.status === 'active' ? 'success' : 'danger'" size="small">
                {{ row.status === 'active' ? '运行中' : '已停止' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="expires_at" label="到期时间" width="180">
            <template #default="{ row }">
              {{ row.expires_at ? formatTime(row.expires_at) : '永久' }}
            </template>
          </el-table-column>
          <el-table-column label="操作" width="150">
            <template #default="{ row }">
              <el-button size="small" type="primary">
                查看详情
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'

// 响应式数据
const loading = ref(false)
const submitLoading = ref(false)
const searchKeyword = ref('')
const statusFilter = ref('')
const selectedCustomers = ref([])
const editingCustomer = ref(null)
const selectedCustomer = ref(null)
const customerServices = ref([])

// 分页
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)

// 对话框控制
const showCreateDialog = ref(false)
const showServicesDialog = ref(false)
const customerFormRef = ref()

// 模拟客户数据
const customers = ref([
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
  },
  {
    id: 3,
    wechat_id: 'user003',
    wechat_name: '王五',
    phone: '13800138003',
    email: 'wangwu@example.com',
    status: 'suspended',
    service_count: 0,
    notes: '暂停服务',
    created_at: Date.now() / 1000 - 86400 * 1
  }
])

// 表单数据
const customerForm = reactive({
  wechat_id: '',
  wechat_name: '',
  phone: '',
  email: '',
  status: 'active',
  notes: ''
})

// 表单验证规则
const customerRules = {
  wechat_id: [
    { required: true, message: '请输入微信号', trigger: 'blur' }
  ],
  wechat_name: [
    { required: true, message: '请输入微信名称', trigger: 'blur' }
  ]
}

// 计算属性
const filteredCustomers = computed(() => {
  let result = customers.value
  
  if (searchKeyword.value) {
    result = result.filter(customer => 
      customer.wechat_id.includes(searchKeyword.value) ||
      customer.wechat_name.includes(searchKeyword.value)
    )
  }
  
  if (statusFilter.value) {
    result = result.filter(customer => customer.status === statusFilter.value)
  }
  
  total.value = result.length
  
  // 分页
  const start = (currentPage.value - 1) * pageSize.value
  const end = start + pageSize.value
  return result.slice(start, end)
})

// 方法
const handleSearch = () => {
  currentPage.value = 1
}

const handleFilter = () => {
  currentPage.value = 1
}

const handleRefresh = () => {
  loading.value = true
  setTimeout(() => {
    loading.value = false
    ElMessage.success('刷新成功')
  }, 1000)
}

const handleSelectionChange = (selection) => {
  selectedCustomers.value = selection
}

const clearSelection = () => {
  selectedCustomers.value = []
}

const handlePageChange = (page) => {
  currentPage.value = page
}

const handlePageSizeChange = (size) => {
  pageSize.value = size
  currentPage.value = 1
}

const viewCustomerServices = (customer) => {
  selectedCustomer.value = customer
  // 模拟客户服务数据
  customerServices.value = [
    {
      id: 1,
      port: 10001,
      service_name: '香港节点服务',
      status: 'active',
      expires_at: Date.now() / 1000 + 86400 * 30
    },
    {
      id: 2,
      port: 10002,
      service_name: '美国节点服务',
      status: 'active',
      expires_at: Date.now() / 1000 + 86400 * 15
    }
  ]
  showServicesDialog.value = true
}

const editCustomer = (customer) => {
  editingCustomer.value = customer
  Object.assign(customerForm, customer)
  showCreateDialog.value = true
}

const deleteCustomer = async (customer) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除客户 "${customer.wechat_name}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    
    const index = customers.value.findIndex(c => c.id === customer.id)
    if (index > -1) {
      customers.value.splice(index, 1)
      ElMessage.success('删除成功')
    }
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
    customers.value = customers.value.filter(c => !ids.includes(c.id))
    selectedCustomers.value = []
    ElMessage.success('批量删除成功')
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('批量删除失败')
    }
  }
}

const handleSubmit = async () => {
  if (!customerFormRef.value) return
  
  try {
    await customerFormRef.value.validate()
    submitLoading.value = true
    
    // 模拟API请求
    setTimeout(() => {
      if (editingCustomer.value) {
        // 更新客户
        const index = customers.value.findIndex(c => c.id === editingCustomer.value.id)
        if (index > -1) {
          customers.value[index] = { ...customers.value[index], ...customerForm }
        }
        ElMessage.success('客户更新成功')
      } else {
        // 创建客户
        const newCustomer = {
          id: Date.now(),
          ...customerForm,
          service_count: 0,
          created_at: Date.now() / 1000
        }
        customers.value.unshift(newCustomer)
        ElMessage.success('客户创建成功')
      }
      
      showCreateDialog.value = false
      resetForm()
      submitLoading.value = false
    }, 1000)
  } catch (error) {
    console.error('表单验证失败:', error)
  }
}

const resetForm = () => {
  editingCustomer.value = null
  Object.assign(customerForm, {
    wechat_id: '',
    wechat_name: '',
    phone: '',
    email: '',
    status: 'active',
    notes: ''
  })
  if (customerFormRef.value) {
    customerFormRef.value.clearValidate()
  }
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

const formatTime = (timestamp) => {
  return new Date(timestamp * 1000).toLocaleString()
}

// 生命周期
onMounted(() => {
  // 初始化数据
})
</script>

<style scoped>
.customers-page {
  padding: 24px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
}

.header-left .page-title {
  font-size: 24px;
  font-weight: 600;
  color: #2c3e50;
  margin: 0 0 8px 0;
}

.header-left .page-description {
  color: #7f8c8d;
  margin: 0;
  font-size: 14px;
}

.filter-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding: 16px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

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

.table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.wechat-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.wechat-avatar {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  font-weight: 500;
}

.wechat-id {
  font-family: monospace;
  font-size: 13px;
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
  background: white;
  border: 1px solid #e6e6e6;
  border-radius: 8px;
  padding: 12px 24px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  gap: 16px;
  z-index: 1000;
}

.batch-info {
  color: #2c3e50;
  font-weight: 500;
}

.batch-buttons {
  display: flex;
  gap: 8px;
}

.customer-info {
  margin-bottom: 16px;
  padding: 16px;
  background: #f8f9fa;
  border-radius: 8px;
}

.customer-info h3 {
  margin: 0 0 8px 0;
  color: #2c3e50;
}

.customer-info p {
  margin: 0;
  color: #7f8c8d;
}

@media (max-width: 768px) {
  .customers-page {
    padding: 16px;
  }
  
  .page-header {
    flex-direction: column;
    gap: 16px;
    align-items: stretch;
  }
  
  .filter-toolbar {
    flex-direction: column;
    gap: 12px;
    align-items: stretch;
  }
  
  .filter-left {
    flex-direction: column;
    align-items: stretch;
  }
  
  .filter-right {
    justify-content: center;
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
