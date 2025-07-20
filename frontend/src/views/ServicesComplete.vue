<template>
  <div class="services-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">服务管理</h1>
        <p class="page-description">管理所有Shadowsocks服务，包括端口分配、客户绑定和服务状态</p>
      </div>
      <div class="header-right">
        <el-button type="primary" @click="showCreateDialog = true">
          <el-icon><Plus /></el-icon>
          创建服务
        </el-button>
        <el-button @click="generateConfig" :loading="generatingConfig">
          <el-icon><Download /></el-icon>
          导出配置
        </el-button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-cards">
      <div class="stat-card">
        <div class="stat-icon total">
          <el-icon size="24"><Monitor /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ serviceStats.total }}</div>
          <div class="stat-label">总服务数</div>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon active">
          <el-icon size="24"><CircleCheck /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ serviceStats.active }}</div>
          <div class="stat-label">运行中</div>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon stopped">
          <el-icon size="24"><CircleClose /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ serviceStats.stopped }}</div>
          <div class="stat-label">已停止</div>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon ports">
          <el-icon size="24"><Connection /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ serviceStats.usedPorts }}</div>
          <div class="stat-label">已用端口</div>
        </div>
      </div>
    </div>

    <!-- 筛选工具栏 -->
    <div class="filter-toolbar">
      <div class="filter-left">
        <el-input
          v-model="searchKeyword"
          placeholder="搜索服务名称、客户、端口..."
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
          placeholder="服务状态"
          style="width: 120px"
          clearable
          @change="handleFilter"
        >
          <el-option label="运行中" value="active" />
          <el-option label="已停止" value="stopped" />
          <el-option label="已过期" value="expired" />
        </el-select>
        
        <el-select
          v-model="nodeFilter"
          placeholder="节点"
          style="width: 150px"
          clearable
          @change="handleFilter"
        >
          <el-option
            v-for="node in availableNodes"
            :key="node.id"
            :label="node.name"
            :value="node.id"
          />
        </el-select>
      </div>
      
      <div class="filter-right">
        <el-button @click="handleRefresh" :loading="loading">
          <el-icon><Refresh /></el-icon>
          刷新
        </el-button>
      </div>
    </div>

    <!-- 服务列表 -->
    <div class="table-container">
      <el-table
        :data="filteredServices"
        :loading="loading"
        @selection-change="handleSelectionChange"
        row-key="id"
        class="services-table"
      >
        <el-table-column type="selection" width="55" />
        
        <el-table-column prop="port" label="端口" width="100" align="center">
          <template #default="{ row }">
            <el-tag type="info" size="small">{{ row.port }}</el-tag>
          </template>
        </el-table-column>
        
        <el-table-column prop="service_name" label="服务名称" width="150" />
        
        <el-table-column prop="customer_name" label="客户" width="120">
          <template #default="{ row }">
            <div class="customer-info">
              <el-avatar :size="24" class="customer-avatar">
                {{ row.customer_name?.charAt(0) }}
              </el-avatar>
              <span class="customer-name">{{ row.customer_name }}</span>
            </div>
          </template>
        </el-table-column>
        
        <el-table-column prop="node_name" label="节点" width="120" />
        
        <el-table-column prop="method" label="加密方式" width="120" />
        
        <el-table-column prop="status" label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.status)" size="small">
              {{ getStatusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        
        <el-table-column prop="expires_at" label="到期时间" width="180">
          <template #default="{ row }">
            <span v-if="row.expires_at" :class="getExpiryClass(row.expires_at)">
              {{ formatTime(row.expires_at) }}
            </span>
            <span v-else class="text-success">永久</span>
          </template>
        </el-table-column>
        
        <el-table-column prop="traffic_used" label="流量使用" width="120" align="center">
          <template #default="{ row }">
            <div class="traffic-info">
              <div class="traffic-text">{{ formatTraffic(row.traffic_used) }}</div>
              <div v-if="row.traffic_limit" class="traffic-limit">
                / {{ formatTraffic(row.traffic_limit) }}
              </div>
            </div>
          </template>
        </el-table-column>
        
        <el-table-column prop="created_at" label="创建时间" width="180">
          <template #default="{ row }">
            {{ formatTime(row.created_at) }}
          </template>
        </el-table-column>
        
        <el-table-column label="操作" width="280" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="viewServiceConfig(row)">
              配置
            </el-button>
            <el-button 
              size="small" 
              :type="row.status === 'active' ? 'warning' : 'success'"
              @click="toggleServiceStatus(row)"
            >
              {{ row.status === 'active' ? '停止' : '启动' }}
            </el-button>
            <el-button size="small" type="warning" @click="editService(row)">
              编辑
            </el-button>
            <el-button size="small" type="danger" @click="deleteService(row)">
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
    <div v-if="selectedServices.length > 0" class="batch-actions">
      <div class="batch-info">
        已选择 {{ selectedServices.length }} 个服务
      </div>
      <div class="batch-buttons">
        <el-button @click="clearSelection">取消选择</el-button>
        <el-button type="success" @click="batchStartServices">
          批量启动
        </el-button>
        <el-button type="warning" @click="batchStopServices">
          批量停止
        </el-button>
        <el-button type="danger" @click="batchDeleteServices">
          批量删除
        </el-button>
      </div>
    </div>

    <!-- 创建/编辑服务对话框 -->
    <el-dialog
      v-model="showCreateDialog"
      :title="editingService ? '编辑服务' : '创建服务'"
      width="600px"
      @close="resetForm"
    >
      <el-form
        ref="serviceFormRef"
        :model="serviceForm"
        :rules="serviceRules"
        label-width="100px"
      >
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="服务名称" prop="service_name">
              <el-input v-model="serviceForm.service_name" placeholder="请输入服务名称" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="客户" prop="customer_id">
              <el-select v-model="serviceForm.customer_id" style="width: 100%" placeholder="选择客户">
                <el-option
                  v-for="customer in availableCustomers"
                  :key="customer.id"
                  :label="`${customer.wechat_name} (${customer.wechat_id})`"
                  :value="customer.id"
                />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="节点" prop="node_id">
              <el-select v-model="serviceForm.node_id" style="width: 100%" placeholder="选择节点">
                <el-option
                  v-for="node in availableNodes"
                  :key="node.id"
                  :label="`${node.name} (${node.region})`"
                  :value="node.id"
                />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="端口" prop="port">
              <el-input-number
                v-model="serviceForm.port"
                :min="1024"
                :max="65535"
                style="width: 100%"
                placeholder="自动分配"
              />
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="加密方式" prop="method">
              <el-select v-model="serviceForm.method" style="width: 100%">
                <el-option label="aes-256-gcm" value="aes-256-gcm" />
                <el-option label="chacha20-ietf-poly1305" value="chacha20-ietf-poly1305" />
                <el-option label="aes-128-gcm" value="aes-128-gcm" />
                <el-option label="aes-256-cfb" value="aes-256-cfb" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="密码" prop="password">
              <el-input
                v-model="serviceForm.password"
                placeholder="留空自动生成"
                show-password
              >
                <template #append>
                  <el-button @click="generatePassword">生成</el-button>
                </template>
              </el-input>
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="流量限制">
              <el-input-number
                v-model="serviceForm.traffic_limit"
                :min="0"
                style="width: 100%"
                placeholder="GB，0为无限制"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="到期时间">
              <el-date-picker
                v-model="serviceForm.expires_at"
                type="datetime"
                placeholder="选择到期时间"
                style="width: 100%"
                format="YYYY-MM-DD HH:mm:ss"
                value-format="X"
              />
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-form-item label="备注">
          <el-input
            v-model="serviceForm.notes"
            type="textarea"
            :rows="3"
            placeholder="服务备注信息"
          />
        </el-form-item>
        
        <el-form-item>
          <el-checkbox v-model="serviceForm.auto_start">
            创建后自动启动服务
          </el-checkbox>
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit" :loading="submitLoading">
          {{ editingService ? '更新' : '创建' }}
        </el-button>
      </template>
    </el-dialog>

    <!-- 服务配置对话框 -->
    <el-dialog
      v-model="showConfigDialog"
      title="服务配置信息"
      width="600px"
    >
      <div v-if="selectedService" class="config-container">
        <div class="config-section">
          <h3>基本信息</h3>
          <div class="config-item">
            <label>服务名称:</label>
            <span>{{ selectedService.service_name }}</span>
          </div>
          <div class="config-item">
            <label>服务器地址:</label>
            <span>{{ selectedService.server_host }}</span>
          </div>
          <div class="config-item">
            <label>端口:</label>
            <span>{{ selectedService.port }}</span>
          </div>
          <div class="config-item">
            <label>密码:</label>
            <span class="password-field">{{ selectedService.password }}</span>
            <el-button size="small" @click="copyToClipboard(selectedService.password)">
              复制
            </el-button>
          </div>
          <div class="config-item">
            <label>加密方式:</label>
            <span>{{ selectedService.method }}</span>
          </div>
        </div>
        
        <div class="config-section">
          <h3>连接配置</h3>
          <el-tabs>
            <el-tab-pane label="JSON配置" name="json">
              <el-input
                :model-value="generateJsonConfig(selectedService)"
                type="textarea"
                :rows="8"
                readonly
              />
              <div class="config-actions">
                <el-button @click="copyToClipboard(generateJsonConfig(selectedService))">
                  复制JSON配置
                </el-button>
              </div>
            </el-tab-pane>
            
            <el-tab-pane label="SS链接" name="ss">
              <el-input
                :model-value="generateSSUrl(selectedService)"
                readonly
              />
              <div class="config-actions">
                <el-button @click="copyToClipboard(generateSSUrl(selectedService))">
                  复制SS链接
                </el-button>
                <el-button @click="generateQRCode(selectedService)">
                  生成二维码
                </el-button>
              </div>
            </el-tab-pane>
          </el-tabs>
        </div>
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
const generatingConfig = ref(false)
const searchKeyword = ref('')
const statusFilter = ref('')
const nodeFilter = ref('')
const selectedServices = ref([])
const editingService = ref(null)
const selectedService = ref(null)

// 分页
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)

// 对话框控制
const showCreateDialog = ref(false)
const showConfigDialog = ref(false)
const serviceFormRef = ref()

// 模拟数据
const services = ref([
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
    traffic_used: 1024 * 1024 * 1024 * 2.5, // 2.5GB
    traffic_limit: 1024 * 1024 * 1024 * 100, // 100GB
    expires_at: Date.now() / 1000 + 86400 * 30,
    created_at: Date.now() / 1000 - 86400 * 7,
    notes: '高速节点服务'
  },
  {
    id: 2,
    port: 10002,
    service_name: '美国标准服务',
    customer_id: 2,
    customer_name: '李四',
    node_id: 2,
    node_name: '美国节点1',
    server_host: '192.168.1.100',
    method: 'chacha20-ietf-poly1305',
    password: 'def789012',
    status: 'active',
    traffic_used: 1024 * 1024 * 1024 * 5.2, // 5.2GB
    traffic_limit: 1024 * 1024 * 1024 * 50, // 50GB
    expires_at: Date.now() / 1000 + 86400 * 15,
    created_at: Date.now() / 1000 - 86400 * 3,
    notes: '标准服务'
  },
  {
    id: 3,
    port: 10003,
    service_name: '测试服务',
    customer_id: 3,
    customer_name: '王五',
    node_id: 3,
    node_name: '日本节点1',
    server_host: '10.0.0.50',
    method: 'aes-128-gcm',
    password: 'ghi345678',
    status: 'stopped',
    traffic_used: 1024 * 1024 * 100, // 100MB
    traffic_limit: 0, // 无限制
    expires_at: null,
    created_at: Date.now() / 1000 - 86400 * 1,
    notes: '测试用服务'
  }
])

const availableCustomers = ref([
  { id: 1, wechat_id: 'user001', wechat_name: '张三' },
  { id: 2, wechat_id: 'user002', wechat_name: '李四' },
  { id: 3, wechat_id: 'user003', wechat_name: '王五' }
])

const availableNodes = ref([
  { id: 1, name: '香港节点1', region: 'HK', host: '103.45.67.89' },
  { id: 2, name: '美国节点1', region: 'US', host: '192.168.1.100' },
  { id: 3, name: '日本节点1', region: 'JP', host: '10.0.0.50' }
])

// 统计数据
const serviceStats = computed(() => {
  const total = services.value.length
  const active = services.value.filter(s => s.status === 'active').length
  const stopped = services.value.filter(s => s.status === 'stopped').length
  const usedPorts = services.value.length
  
  return { total, active, stopped, usedPorts }
})

// 表单数据
const serviceForm = reactive({
  service_name: '',
  customer_id: '',
  node_id: '',
  port: null,
  method: 'aes-256-gcm',
  password: '',
  traffic_limit: 0,
  expires_at: null,
  notes: '',
  auto_start: true
})

// 表单验证规则
const serviceRules = {
  service_name: [
    { required: true, message: '请输入服务名称', trigger: 'blur' }
  ],
  customer_id: [
    { required: true, message: '请选择客户', trigger: 'change' }
  ],
  node_id: [
    { required: true, message: '请选择节点', trigger: 'change' }
  ],
  method: [
    { required: true, message: '请选择加密方式', trigger: 'change' }
  ]
}

// 计算属性
const filteredServices = computed(() => {
  let result = services.value
  
  if (searchKeyword.value) {
    result = result.filter(service => 
      service.service_name.includes(searchKeyword.value) ||
      service.customer_name.includes(searchKeyword.value) ||
      service.port.toString().includes(searchKeyword.value)
    )
  }
  
  if (statusFilter.value) {
    result = result.filter(service => service.status === statusFilter.value)
  }
  
  if (nodeFilter.value) {
    result = result.filter(service => service.node_id === nodeFilter.value)
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
  selectedServices.value = selection
}

const clearSelection = () => {
  selectedServices.value = []
}

const handlePageChange = (page) => {
  currentPage.value = page
}

const handlePageSizeChange = (size) => {
  pageSize.value = size
  currentPage.value = 1
}

const generateConfig = () => {
  generatingConfig.value = true
  setTimeout(() => {
    generatingConfig.value = false
    ElMessage.success('配置导出成功')
  }, 1000)
}

const generatePassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let password = ''
  for (let i = 0; i < 12; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  serviceForm.password = password
}

const viewServiceConfig = (service) => {
  selectedService.value = service
  showConfigDialog.value = true
}

const toggleServiceStatus = async (service) => {
  const newStatus = service.status === 'active' ? 'stopped' : 'active'
  const action = newStatus === 'active' ? '启动' : '停止'
  
  try {
    await ElMessageBox.confirm(
      `确定要${action}服务 "${service.service_name}" 吗？`,
      `确认${action}`,
      { type: 'warning' }
    )
    
    service.status = newStatus
    ElMessage.success(`服务${action}成功`)
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error(`服务${action}失败`)
    }
  }
}

const editService = (service) => {
  editingService.value = service
  Object.assign(serviceForm, service)
  showCreateDialog.value = true
}

const deleteService = async (service) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除服务 "${service.service_name}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    
    const index = services.value.findIndex(s => s.id === service.id)
    if (index > -1) {
      services.value.splice(index, 1)
      ElMessage.success('删除成功')
    }
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const batchStartServices = async () => {
  for (const service of selectedServices.value) {
    if (service.status !== 'active') {
      service.status = 'active'
    }
  }
  ElMessage.success('批量启动成功')
}

const batchStopServices = async () => {
  for (const service of selectedServices.value) {
    if (service.status === 'active') {
      service.status = 'stopped'
    }
  }
  ElMessage.success('批量停止成功')
}

const batchDeleteServices = async () => {
  try {
    await ElMessageBox.confirm(
      `确定要删除选中的 ${selectedServices.value.length} 个服务吗？`,
      '确认批量删除',
      { type: 'warning' }
    )
    
    const ids = selectedServices.value.map(s => s.id)
    services.value = services.value.filter(s => !ids.includes(s.id))
    selectedServices.value = []
    ElMessage.success('批量删除成功')
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('批量删除失败')
    }
  }
}

const handleSubmit = async () => {
  if (!serviceFormRef.value) return
  
  try {
    await serviceFormRef.value.validate()
    submitLoading.value = true
    
    // 模拟API请求
    setTimeout(() => {
      if (editingService.value) {
        // 更新服务
        const index = services.value.findIndex(s => s.id === editingService.value.id)
        if (index > -1) {
          const customer = availableCustomers.value.find(c => c.id === serviceForm.customer_id)
          const node = availableNodes.value.find(n => n.id === serviceForm.node_id)
          
          services.value[index] = {
            ...services.value[index],
            ...serviceForm,
            customer_name: customer?.wechat_name,
            node_name: node?.name,
            server_host: node?.host
          }
        }
        ElMessage.success('服务更新成功')
      } else {
        // 创建服务
        const customer = availableCustomers.value.find(c => c.id === serviceForm.customer_id)
        const node = availableNodes.value.find(n => n.id === serviceForm.node_id)
        
        const newService = {
          id: Date.now(),
          ...serviceForm,
          customer_name: customer?.wechat_name,
          node_name: node?.name,
          server_host: node?.host,
          port: serviceForm.port || Math.floor(Math.random() * 10000) + 10000,
          password: serviceForm.password || generateRandomPassword(),
          status: serviceForm.auto_start ? 'active' : 'stopped',
          traffic_used: 0,
          created_at: Date.now() / 1000
        }
        services.value.unshift(newService)
        ElMessage.success('服务创建成功')
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
  editingService.value = null
  Object.assign(serviceForm, {
    service_name: '',
    customer_id: '',
    node_id: '',
    port: null,
    method: 'aes-256-gcm',
    password: '',
    traffic_limit: 0,
    expires_at: null,
    notes: '',
    auto_start: true
  })
  if (serviceFormRef.value) {
    serviceFormRef.value.clearValidate()
  }
}

const generateRandomPassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let password = ''
  for (let i = 0; i < 12; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return password
}

const generateJsonConfig = (service) => {
  return JSON.stringify({
    server: service.server_host,
    server_port: service.port,
    password: service.password,
    method: service.method,
    local_address: "127.0.0.1",
    local_port: 1080,
    timeout: 300
  }, null, 2)
}

const generateSSUrl = (service) => {
  const auth = btoa(`${service.method}:${service.password}`)
  return `ss://${auth}@${service.server_host}:${service.port}#${encodeURIComponent(service.service_name)}`
}

const copyToClipboard = async (text) => {
  try {
    await navigator.clipboard.writeText(text)
    ElMessage.success('已复制到剪贴板')
  } catch (error) {
    ElMessage.error('复制失败')
  }
}

const generateQRCode = (service) => {
  const ssUrl = generateSSUrl(service)
  ElMessage.info('二维码功能开发中...')
}

const getStatusType = (status) => {
  const statusMap = {
    'active': 'success',
    'stopped': 'danger',
    'expired': 'warning'
  }
  return statusMap[status] || 'info'
}

const getStatusText = (status) => {
  const statusMap = {
    'active': '运行中',
    'stopped': '已停止',
    'expired': '已过期'
  }
  return statusMap[status] || status
}

const getExpiryClass = (timestamp) => {
  const now = Date.now() / 1000
  const diff = timestamp - now
  
  if (diff < 0) return 'text-danger' // 已过期
  if (diff < 86400 * 7) return 'text-warning' // 7天内过期
  return 'text-success' // 正常
}

const formatTime = (timestamp) => {
  return new Date(timestamp * 1000).toLocaleString()
}

const formatTraffic = (bytes) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

// 生命周期
onMounted(() => {
  // 初始化数据
})
</script>

<style scoped>
.services-page {
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

.header-right {
  display: flex;
  gap: 12px;
}

.stats-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  display: flex;
  align-items: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: 1px solid #e6e6e6;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16px;
  color: white;
}

.stat-icon.total {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.stat-icon.active {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
}

.stat-icon.stopped {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.stat-icon.ports {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
}

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 24px;
  font-weight: 600;
  color: #2c3e50;
  line-height: 1;
}

.stat-label {
  font-size: 12px;
  color: #7f8c8d;
  margin-top: 4px;
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

.customer-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.customer-avatar {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  font-weight: 500;
}

.customer-name {
  font-size: 13px;
}

.traffic-info {
  text-align: center;
}

.traffic-text {
  font-weight: 500;
  color: #2c3e50;
}

.traffic-limit {
  font-size: 11px;
  color: #7f8c8d;
}

.text-success {
  color: #67c23a;
}

.text-warning {
  color: #e6a23c;
}

.text-danger {
  color: #f56c6c;
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

.config-container {
  max-height: 500px;
  overflow-y: auto;
}

.config-section {
  margin-bottom: 24px;
}

.config-section h3 {
  margin: 0 0 16px 0;
  color: #2c3e50;
  font-size: 16px;
  font-weight: 600;
}

.config-item {
  display: flex;
  align-items: center;
  margin-bottom: 12px;
  gap: 12px;
}

.config-item label {
  min-width: 100px;
  color: #7f8c8d;
  font-size: 14px;
}

.config-item span {
  flex: 1;
  color: #2c3e50;
}

.password-field {
  font-family: monospace;
  background: #f8f9fa;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 13px;
}

.config-actions {
  margin-top: 16px;
  display: flex;
  gap: 12px;
}

@media (max-width: 768px) {
  .services-page {
    padding: 16px;
  }
  
  .page-header {
    flex-direction: column;
    gap: 16px;
    align-items: stretch;
  }
  
  .header-right {
    justify-content: center;
  }
  
  .stats-cards {
    grid-template-columns: repeat(2, 1fr);
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
