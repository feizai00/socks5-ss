<template>
  <div class="nodes-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">节点管理</h1>
        <p class="page-description">管理所有SOCKS5代理节点，包括连接信息、状态监控和性能统计</p>
      </div>
      <div class="header-right">
        <el-button type="primary" @click="showCreateDialog = true">
          <el-icon><Plus /></el-icon>
          添加节点
        </el-button>
        <el-button @click="testAllNodes" :loading="testingAll">
          <el-icon><Connection /></el-icon>
          批量测试
        </el-button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-cards">
      <div class="stat-card">
        <div class="stat-icon total">
          <el-icon size="24"><Connection /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ nodeStats.total }}</div>
          <div class="stat-label">总节点数</div>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon online">
          <el-icon size="24"><CircleCheck /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ nodeStats.online }}</div>
          <div class="stat-label">在线节点</div>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon offline">
          <el-icon size="24"><CircleClose /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ nodeStats.offline }}</div>
          <div class="stat-label">离线节点</div>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon services">
          <el-icon size="24"><Monitor /></el-icon>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ nodeStats.services }}</div>
          <div class="stat-label">关联服务</div>
        </div>
      </div>
    </div>

    <!-- 筛选工具栏 -->
    <div class="filter-toolbar">
      <div class="filter-left">
        <el-input
          v-model="searchKeyword"
          placeholder="搜索节点名称、地址..."
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
          placeholder="节点状态"
          style="width: 120px"
          clearable
          @change="handleFilter"
        >
          <el-option label="在线" value="online" />
          <el-option label="离线" value="offline" />
          <el-option label="测试中" value="testing" />
        </el-select>
        
        <el-select
          v-model="regionFilter"
          placeholder="地区"
          style="width: 120px"
          clearable
          @change="handleFilter"
        >
          <el-option label="香港" value="HK" />
          <el-option label="美国" value="US" />
          <el-option label="日本" value="JP" />
          <el-option label="新加坡" value="SG" />
        </el-select>
      </div>
      
      <div class="filter-right">
        <el-button @click="handleRefresh" :loading="loading">
          <el-icon><Refresh /></el-icon>
          刷新
        </el-button>
      </div>
    </div>

    <!-- 节点列表 -->
    <div class="table-container">
      <el-table
        :data="filteredNodes"
        :loading="loading"
        @selection-change="handleSelectionChange"
        row-key="id"
        class="nodes-table"
      >
        <el-table-column type="selection" width="55" />
        
        <el-table-column prop="name" label="节点名称" width="150">
          <template #default="{ row }">
            <div class="node-name">
              <div class="name-text">{{ row.name }}</div>
              <div class="region-tag">{{ row.region }}</div>
            </div>
          </template>
        </el-table-column>
        
        <el-table-column prop="host" label="地址" width="150" />
        
        <el-table-column prop="port" label="端口" width="100" align="center" />
        
        <el-table-column prop="username" label="用户名" width="120" />
        
        <el-table-column prop="status" label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.status)" size="small">
              {{ getStatusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        
        <el-table-column prop="latency" label="延迟" width="100" align="center">
          <template #default="{ row }">
            <span v-if="row.latency" :class="getLatencyClass(row.latency)">
              {{ row.latency }}ms
            </span>
            <span v-else class="text-gray">-</span>
          </template>
        </el-table-column>
        
        <el-table-column prop="service_count" label="服务数" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.service_count > 0 ? 'success' : 'info'" size="small">
              {{ row.service_count || 0 }}
            </el-tag>
          </template>
        </el-table-column>
        
        <el-table-column prop="last_check" label="最后检测" width="180">
          <template #default="{ row }">
            {{ row.last_check ? formatTime(row.last_check) : '未检测' }}
          </template>
        </el-table-column>
        
        <el-table-column prop="notes" label="备注" min-width="150" show-overflow-tooltip />
        
        <el-table-column label="操作" width="250" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="testNode(row)" :loading="row.testing">
              测试
            </el-button>
            <el-button size="small" @click="viewNodeServices(row)">
              服务
            </el-button>
            <el-button size="small" type="warning" @click="editNode(row)">
              编辑
            </el-button>
            <el-button size="small" type="danger" @click="deleteNode(row)">
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
    <div v-if="selectedNodes.length > 0" class="batch-actions">
      <div class="batch-info">
        已选择 {{ selectedNodes.length }} 个节点
      </div>
      <div class="batch-buttons">
        <el-button @click="clearSelection">取消选择</el-button>
        <el-button type="primary" @click="batchTestNodes">
          批量测试
        </el-button>
        <el-button type="danger" @click="batchDeleteNodes">
          批量删除
        </el-button>
      </div>
    </div>

    <!-- 创建/编辑节点对话框 -->
    <el-dialog
      v-model="showCreateDialog"
      :title="editingNode ? '编辑节点' : '添加节点'"
      width="600px"
      @close="resetForm"
    >
      <el-form
        ref="nodeFormRef"
        :model="nodeForm"
        :rules="nodeRules"
        label-width="100px"
      >
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="节点名称" prop="name">
              <el-input v-model="nodeForm.name" placeholder="请输入节点名称" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="地区" prop="region">
              <el-select v-model="nodeForm.region" style="width: 100%">
                <el-option label="香港" value="HK" />
                <el-option label="美国" value="US" />
                <el-option label="日本" value="JP" />
                <el-option label="新加坡" value="SG" />
                <el-option label="英国" value="UK" />
                <el-option label="德国" value="DE" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-row :gutter="20">
          <el-col :span="16">
            <el-form-item label="服务器地址" prop="host">
              <el-input v-model="nodeForm.host" placeholder="请输入服务器IP或域名" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="端口" prop="port">
              <el-input-number
                v-model="nodeForm.port"
                :min="1"
                :max="65535"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="用户名" prop="username">
              <el-input v-model="nodeForm.username" placeholder="SOCKS5用户名" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="密码" prop="password">
              <el-input
                v-model="nodeForm.password"
                type="password"
                placeholder="SOCKS5密码"
                show-password
              />
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-form-item label="备注">
          <el-input
            v-model="nodeForm.notes"
            type="textarea"
            :rows="3"
            placeholder="节点备注信息"
          />
        </el-form-item>

        <el-form-item>
          <el-checkbox v-model="nodeForm.testAfterCreate">
            创建后立即测试连接
          </el-checkbox>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit" :loading="submitLoading">
          {{ editingNode ? '更新' : '创建' }}
        </el-button>
      </template>
    </el-dialog>

    <!-- 节点服务对话框 -->
    <el-dialog
      v-model="showServicesDialog"
      title="节点服务列表"
      width="800px"
    >
      <div v-if="selectedNode">
        <div class="node-info">
          <h3>{{ selectedNode.name }} ({{ selectedNode.host }}:{{ selectedNode.port }})</h3>
          <p>当前服务数量: {{ selectedNode.service_count || 0 }}</p>
        </div>
        
        <el-table :data="nodeServices" style="width: 100%">
          <el-table-column prop="port" label="SS端口" width="100" />
          <el-table-column prop="customer_name" label="客户" width="150" />
          <el-table-column prop="service_name" label="服务名称" width="150" />
          <el-table-column prop="status" label="状态" width="100">
            <template #default="{ row }">
              <el-tag :type="row.status === 'active' ? 'success' : 'danger'" size="small">
                {{ row.status === 'active' ? '运行中' : '已停止' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="created_at" label="创建时间" width="180">
            <template #default="{ row }">
              {{ formatTime(row.created_at) }}
            </template>
          </el-table-column>
          <el-table-column label="操作" width="120">
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
const testingAll = ref(false)
const searchKeyword = ref('')
const statusFilter = ref('')
const regionFilter = ref('')
const selectedNodes = ref([])
const editingNode = ref(null)
const selectedNode = ref(null)
const nodeServices = ref([])

// 分页
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)

// 对话框控制
const showCreateDialog = ref(false)
const showServicesDialog = ref(false)
const nodeFormRef = ref()

// 模拟节点数据
const nodes = ref([
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
    notes: '高速节点',
    testing: false
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
    notes: '稳定节点',
    testing: false
  },
  {
    id: 3,
    name: '日本节点1',
    region: 'JP',
    host: '10.0.0.50',
    port: 1080,
    username: 'user3',
    password: 'pass3',
    status: 'offline',
    latency: null,
    service_count: 0,
    last_check: Date.now() / 1000 - 3600,
    notes: '维护中',
    testing: false
  }
])

// 统计数据
const nodeStats = computed(() => {
  const total = nodes.value.length
  const online = nodes.value.filter(n => n.status === 'online').length
  const offline = nodes.value.filter(n => n.status === 'offline').length
  const services = nodes.value.reduce((sum, n) => sum + (n.service_count || 0), 0)
  
  return { total, online, offline, services }
})

// 表单数据
const nodeForm = reactive({
  name: '',
  region: '',
  host: '',
  port: 1080,
  username: '',
  password: '',
  notes: ''
})

// 表单验证规则
const nodeRules = {
  name: [
    { required: true, message: '请输入节点名称', trigger: 'blur' }
  ],
  region: [
    { required: true, message: '请选择地区', trigger: 'change' }
  ],
  host: [
    { required: true, message: '请输入服务器地址', trigger: 'blur' }
  ],
  port: [
    { required: true, message: '请输入端口', trigger: 'blur' }
  ],
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' }
  ]
}

// 计算属性
const filteredNodes = computed(() => {
  let result = nodes.value
  
  if (searchKeyword.value) {
    result = result.filter(node => 
      node.name.includes(searchKeyword.value) ||
      node.host.includes(searchKeyword.value)
    )
  }
  
  if (statusFilter.value) {
    result = result.filter(node => node.status === statusFilter.value)
  }
  
  if (regionFilter.value) {
    result = result.filter(node => node.region === regionFilter.value)
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
  selectedNodes.value = selection
}

const clearSelection = () => {
  selectedNodes.value = []
}

const handlePageChange = (page) => {
  currentPage.value = page
}

const handlePageSizeChange = (size) => {
  pageSize.value = size
  currentPage.value = 1
}

const testNode = async (node) => {
  node.testing = true
  
  // 模拟测试
  setTimeout(() => {
    const latency = Math.floor(Math.random() * 300) + 20
    const isOnline = Math.random() > 0.2
    
    node.status = isOnline ? 'online' : 'offline'
    node.latency = isOnline ? latency : null
    node.last_check = Date.now() / 1000
    node.testing = false
    
    ElMessage.success(`节点 ${node.name} 测试完成`)
  }, 2000)
}

const testAllNodes = async () => {
  testingAll.value = true
  
  // 模拟批量测试
  setTimeout(() => {
    nodes.value.forEach(node => {
      const latency = Math.floor(Math.random() * 300) + 20
      const isOnline = Math.random() > 0.15
      
      node.status = isOnline ? 'online' : 'offline'
      node.latency = isOnline ? latency : null
      node.last_check = Date.now() / 1000
    })
    
    testingAll.value = false
    ElMessage.success('批量测试完成')
  }, 3000)
}

const batchTestNodes = async () => {
  for (const node of selectedNodes.value) {
    await testNode(node)
  }
  ElMessage.success('批量测试完成')
}

const viewNodeServices = (node) => {
  selectedNode.value = node
  // 模拟节点服务数据
  nodeServices.value = [
    {
      id: 1,
      port: 10001,
      customer_name: '张三',
      service_name: '香港高速服务',
      status: 'active',
      created_at: Date.now() / 1000 - 86400 * 7
    },
    {
      id: 2,
      port: 10002,
      customer_name: '李四',
      service_name: '香港标准服务',
      status: 'active',
      created_at: Date.now() / 1000 - 86400 * 3
    }
  ]
  showServicesDialog.value = true
}

const editNode = (node) => {
  editingNode.value = node
  Object.assign(nodeForm, node)
  showCreateDialog.value = true
}

const deleteNode = async (node) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除节点 "${node.name}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    
    const index = nodes.value.findIndex(n => n.id === node.id)
    if (index > -1) {
      nodes.value.splice(index, 1)
      ElMessage.success('删除成功')
    }
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const batchDeleteNodes = async () => {
  try {
    await ElMessageBox.confirm(
      `确定要删除选中的 ${selectedNodes.value.length} 个节点吗？`,
      '确认批量删除',
      { type: 'warning' }
    )
    
    const ids = selectedNodes.value.map(n => n.id)
    nodes.value = nodes.value.filter(n => !ids.includes(n.id))
    selectedNodes.value = []
    ElMessage.success('批量删除成功')
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('批量删除失败')
    }
  }
}

const handleSubmit = async () => {
  if (!nodeFormRef.value) return
  
  try {
    await nodeFormRef.value.validate()
    submitLoading.value = true
    
    // 模拟API请求
    setTimeout(() => {
      if (editingNode.value) {
        // 更新节点
        const index = nodes.value.findIndex(n => n.id === editingNode.value.id)
        if (index > -1) {
          nodes.value[index] = { ...nodes.value[index], ...nodeForm }
        }
        ElMessage.success('节点更新成功')
      } else {
        // 创建节点
        const newNode = {
          id: Date.now(),
          ...nodeForm,
          status: 'offline',
          latency: null,
          service_count: 0,
          last_check: null,
          testing: false
        }
        nodes.value.unshift(newNode)
        ElMessage.success('节点创建成功')
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
  editingNode.value = null
  Object.assign(nodeForm, {
    name: '',
    region: '',
    host: '',
    port: 1080,
    username: '',
    password: '',
    notes: ''
  })
  if (nodeFormRef.value) {
    nodeFormRef.value.clearValidate()
  }
}

const getStatusType = (status) => {
  const statusMap = {
    'online': 'success',
    'offline': 'danger',
    'testing': 'warning'
  }
  return statusMap[status] || 'info'
}

const getStatusText = (status) => {
  const statusMap = {
    'online': '在线',
    'offline': '离线',
    'testing': '测试中'
  }
  return statusMap[status] || status
}

const getLatencyClass = (latency) => {
  if (latency < 100) return 'text-success'
  if (latency < 200) return 'text-warning'
  return 'text-danger'
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
.nodes-page {
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

.stat-icon.online {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
}

.stat-icon.offline {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.stat-icon.services {
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

.node-name {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.name-text {
  font-weight: 500;
}

.region-tag {
  font-size: 11px;
  color: #7f8c8d;
  background: #f8f9fa;
  padding: 2px 6px;
  border-radius: 4px;
  width: fit-content;
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

.text-gray {
  color: #909399;
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

.node-info {
  margin-bottom: 16px;
  padding: 16px;
  background: #f8f9fa;
  border-radius: 8px;
}

.node-info h3 {
  margin: 0 0 8px 0;
  color: #2c3e50;
}

.node-info p {
  margin: 0;
  color: #7f8c8d;
}

@media (max-width: 768px) {
  .nodes-page {
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
