<!-- Web端前端实现示例 - Vue.js 3 + Element Plus -->
<template>
  <div class="xray-converter-app">
    <!-- 登录页面 -->
    <div v-if="!isAuthenticated" class="login-container">
      <el-card class="login-card">
        <template #header>
          <h2>Xray SOCKS5 转换器</h2>
        </template>
        
        <el-form :model="loginForm" @submit.prevent="handleLogin">
          <el-form-item label="用户名">
            <el-input v-model="loginForm.username" placeholder="请输入用户名" />
          </el-form-item>
          
          <el-form-item label="密码">
            <el-input 
              v-model="loginForm.password" 
              type="password" 
              placeholder="请输入密码"
              @keyup.enter="handleLogin"
            />
          </el-form-item>
          
          <el-form-item>
            <el-button 
              type="primary" 
              :loading="loginLoading" 
              @click="handleLogin"
              style="width: 100%"
            >
              登录
            </el-button>
          </el-form-item>
        </el-form>
      </el-card>
    </div>

    <!-- 主应用界面 -->
    <div v-else class="main-app">
      <!-- 顶部导航栏 -->
      <el-header class="app-header">
        <div class="header-left">
          <h1>Xray SOCKS5 转换器</h1>
        </div>
        <div class="header-right">
          <el-badge :value="systemStatus.running_services" type="success">
            <el-button icon="Monitor" circle />
          </el-badge>
          <el-dropdown @command="handleUserAction">
            <el-button type="text">
              {{ user.username }}
              <el-icon><ArrowDown /></el-icon>
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-container>
        <!-- 侧边栏 -->
        <el-aside width="200px" class="app-sidebar">
          <el-menu 
            :default-active="activeMenu" 
            @select="handleMenuSelect"
            class="sidebar-menu"
          >
            <el-menu-item index="dashboard">
              <el-icon><Odometer /></el-icon>
              <span>仪表板</span>
            </el-menu-item>
            <el-menu-item index="services">
              <el-icon><Connection /></el-icon>
              <span>服务管理</span>
            </el-menu-item>
            <el-menu-item index="monitoring">
              <el-icon><Monitor /></el-icon>
              <span>系统监控</span>
            </el-menu-item>
            <el-menu-item index="backup">
              <el-icon><FolderOpened /></el-icon>
              <span>备份管理</span>
            </el-menu-item>
            <el-menu-item index="settings">
              <el-icon><Setting /></el-icon>
              <span>系统设置</span>
            </el-menu-item>
          </el-menu>
        </el-aside>

        <!-- 主内容区域 -->
        <el-main class="app-main">
          <!-- 仪表板 -->
          <div v-if="activeMenu === 'dashboard'" class="dashboard">
            <el-row :gutter="20">
              <el-col :span="6">
                <el-card class="status-card">
                  <div class="status-item">
                    <div class="status-value">{{ systemStatus.total_services }}</div>
                    <div class="status-label">总服务数</div>
                  </div>
                </el-card>
              </el-col>
              <el-col :span="6">
                <el-card class="status-card running">
                  <div class="status-item">
                    <div class="status-value">{{ systemStatus.running_services }}</div>
                    <div class="status-label">运行中</div>
                  </div>
                </el-card>
              </el-col>
              <el-col :span="6">
                <el-card class="status-card stopped">
                  <div class="status-item">
                    <div class="status-value">{{ systemStatus.stopped_services }}</div>
                    <div class="status-label">已停止</div>
                  </div>
                </el-card>
              </el-col>
              <el-col :span="6">
                <el-card class="status-card">
                  <div class="status-item">
                    <div class="status-value">{{ systemStatus.docker_status }}</div>
                    <div class="status-label">Docker状态</div>
                  </div>
                </el-card>
              </el-col>
            </el-row>

            <!-- 最近操作 -->
            <el-card class="recent-operations" style="margin-top: 20px;">
              <template #header>
                <span>最近操作</span>
              </template>
              <el-timeline>
                <el-timeline-item 
                  v-for="log in recentLogs" 
                  :key="log.id"
                  :timestamp="formatTime(log.created_at)"
                >
                  {{ log.action }} - {{ log.target }}
                </el-timeline-item>
              </el-timeline>
            </el-card>
          </div>

          <!-- 服务管理 -->
          <div v-if="activeMenu === 'services'" class="services-management">
            <!-- 工具栏 -->
            <div class="toolbar">
              <el-button type="primary" @click="showAddServiceDialog = true">
                <el-icon><Plus /></el-icon>
                添加服务
              </el-button>
              <el-button @click="refreshServices">
                <el-icon><Refresh /></el-icon>
                刷新
              </el-button>
              
              <div class="toolbar-right">
                <el-input 
                  v-model="searchQuery" 
                  placeholder="搜索服务..."
                  style="width: 200px;"
                  @input="handleSearch"
                >
                  <template #prefix>
                    <el-icon><Search /></el-icon>
                  </template>
                </el-input>
              </div>
            </div>

            <!-- 服务列表 -->
            <el-table 
              :data="services" 
              v-loading="servicesLoading"
              style="width: 100%; margin-top: 20px;"
            >
              <el-table-column prop="port" label="端口" width="100" />
              <el-table-column prop="password" label="密码" width="150">
                <template #default="scope">
                  <span v-if="scope.row.showPassword">{{ scope.row.password }}</span>
                  <span v-else>••••••••</span>
                  <el-button 
                    type="text" 
                    size="small"
                    @click="togglePasswordVisibility(scope.row)"
                  >
                    <el-icon><View v-if="!scope.row.showPassword" /><Hide v-else /></el-icon>
                  </el-button>
                </template>
              </el-table-column>
              <el-table-column prop="runtime_status" label="状态" width="100">
                <template #default="scope">
                  <el-tag 
                    :type="getStatusType(scope.row.runtime_status)"
                    size="small"
                  >
                    {{ getStatusText(scope.row.runtime_status) }}
                  </el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="remark" label="备注" />
              <el-table-column prop="created_at" label="创建时间" width="180">
                <template #default="scope">
                  {{ formatTime(scope.row.created_at) }}
                </template>
              </el-table-column>
              <el-table-column label="操作" width="200">
                <template #default="scope">
                  <el-button 
                    size="small" 
                    @click="viewServiceInfo(scope.row)"
                  >
                    查看
                  </el-button>
                  <el-button 
                    size="small" 
                    type="warning"
                    @click="toggleService(scope.row)"
                  >
                    {{ scope.row.runtime_status === 'running' ? '停止' : '启动' }}
                  </el-button>
                  <el-button 
                    size="small" 
                    type="danger"
                    @click="deleteService(scope.row)"
                  >
                    删除
                  </el-button>
                </template>
              </el-table-column>
            </el-table>

            <!-- 分页 -->
            <el-pagination
              v-model:current-page="currentPage"
              v-model:page-size="pageSize"
              :total="totalServices"
              :page-sizes="[10, 20, 50, 100]"
              layout="total, sizes, prev, pager, next, jumper"
              @size-change="handleSizeChange"
              @current-change="handleCurrentChange"
              style="margin-top: 20px; text-align: right;"
            />
          </div>
        </el-main>
      </el-container>
    </div>

    <!-- 添加服务对话框 -->
    <el-dialog 
      v-model="showAddServiceDialog" 
      title="添加新服务" 
      width="600px"
    >
      <el-form :model="newService" label-width="120px">
        <el-form-item label="监听端口">
          <el-input-number 
            v-model="newService.port" 
            :min="1" 
            :max="65535"
            placeholder="请输入端口号"
          />
        </el-form-item>
        
        <el-form-item label="密码">
          <el-input 
            v-model="newService.password" 
            placeholder="留空自动生成"
          />
          <el-button @click="generatePassword" style="margin-left: 10px;">
            生成密码
          </el-button>
        </el-form-item>
        
        <el-form-item label="SOCKS5代理">
          <div v-for="(server, index) in newService.socksServers" :key="index">
            <el-row :gutter="10">
              <el-col :span="8">
                <el-input v-model="server.address" placeholder="IP地址" />
              </el-col>
              <el-col :span="6">
                <el-input-number v-model="server.port" placeholder="端口" />
              </el-col>
              <el-col :span="6">
                <el-input v-model="server.username" placeholder="用户名(可选)" />
              </el-col>
              <el-col :span="4">
                <el-button 
                  type="danger" 
                  @click="removeSocksServer(index)"
                  :disabled="newService.socksServers.length === 1"
                >
                  删除
                </el-button>
              </el-col>
            </el-row>
          </div>
          <el-button @click="addSocksServer" style="margin-top: 10px;">
            添加SOCKS5代理
          </el-button>
        </el-form-item>
        
        <el-form-item label="备注">
          <el-input v-model="newService.remark" placeholder="服务备注信息" />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="showAddServiceDialog = false">取消</el-button>
        <el-button type="primary" @click="createService" :loading="createLoading">
          创建服务
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import axios from 'axios'

// 响应式数据
const isAuthenticated = ref(false)
const user = ref({})
const activeMenu = ref('dashboard')
const systemStatus = ref({
  total_services: 0,
  running_services: 0,
  stopped_services: 0,
  docker_status: 'unknown'
})

const loginForm = reactive({
  username: '',
  password: ''
})

const services = ref([])
const recentLogs = ref([])
const searchQuery = ref('')
const currentPage = ref(1)
const pageSize = ref(10)
const totalServices = ref(0)

const showAddServiceDialog = ref(false)
const newService = reactive({
  port: null,
  password: '',
  socksServers: [{ address: '', port: null, username: '', password: '' }],
  remark: ''
})

const loginLoading = ref(false)
const servicesLoading = ref(false)
const createLoading = ref(false)

// 计算属性
const filteredServices = computed(() => {
  if (!searchQuery.value) return services.value
  return services.value.filter(service => 
    service.port.toString().includes(searchQuery.value) ||
    (service.remark && service.remark.includes(searchQuery.value))
  )
})

// 方法
const handleLogin = async () => {
  loginLoading.value = true
  try {
    const response = await axios.post('/api/auth/login', loginForm)
    localStorage.setItem('token', response.data.token)
    user.value = response.data.user
    isAuthenticated.value = true
    ElMessage.success('登录成功')
    await loadDashboardData()
  } catch (error) {
    ElMessage.error(error.response?.data?.error || '登录失败')
  } finally {
    loginLoading.value = false
  }
}

const handleUserAction = (command) => {
  if (command === 'logout') {
    localStorage.removeItem('token')
    isAuthenticated.value = false
    user.value = {}
  }
}

const handleMenuSelect = (index) => {
  activeMenu.value = index
  if (index === 'services') {
    loadServices()
  } else if (index === 'dashboard') {
    loadDashboardData()
  }
}

const loadDashboardData = async () => {
  try {
    const [statusResponse, logsResponse] = await Promise.all([
      axios.get('/api/system/status'),
      axios.get('/api/logs?limit=5')
    ])
    systemStatus.value = statusResponse.data
    recentLogs.value = logsResponse.data
  } catch (error) {
    ElMessage.error('加载仪表板数据失败')
  }
}

const loadServices = async () => {
  servicesLoading.value = true
  try {
    const response = await axios.get('/api/services', {
      params: {
        page: currentPage.value,
        limit: pageSize.value,
        search: searchQuery.value
      }
    })
    services.value = response.data.services.map(service => ({
      ...service,
      showPassword: false
    }))
    totalServices.value = response.data.total
  } catch (error) {
    ElMessage.error('加载服务列表失败')
  } finally {
    servicesLoading.value = false
  }
}

const createService = async () => {
  createLoading.value = true
  try {
    await axios.post('/api/services', newService)
    ElMessage.success('服务创建成功')
    showAddServiceDialog.value = false
    resetNewService()
    loadServices()
  } catch (error) {
    ElMessage.error(error.response?.data?.error || '服务创建失败')
  } finally {
    createLoading.value = false
  }
}

const deleteService = async (service) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除端口 ${service.port} 的服务吗？`,
      '确认删除',
      { type: 'warning' }
    )
    
    await axios.delete(`/api/services/${service.id}`)
    ElMessage.success('服务删除成功')
    loadServices()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('服务删除失败')
    }
  }
}

// 工具函数
const formatTime = (timestamp) => {
  return new Date(timestamp * 1000).toLocaleString()
}

const getStatusType = (status) => {
  const statusMap = {
    'running': 'success',
    'stopped': 'warning',
    'missing': 'danger'
  }
  return statusMap[status] || 'info'
}

const getStatusText = (status) => {
  const statusMap = {
    'running': '运行中',
    'stopped': '已停止',
    'missing': '缺失'
  }
  return statusMap[status] || status
}

const generatePassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let password = ''
  for (let i = 0; i < 16; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  newService.password = password
}

// 生命周期
onMounted(() => {
  const token = localStorage.getItem('token')
  if (token) {
    axios.defaults.headers.common['Authorization'] = `Bearer ${token}`
    isAuthenticated.value = true
    loadDashboardData()
  }
})
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-card {
  width: 400px;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #fff;
  border-bottom: 1px solid #e6e6e6;
}

.status-card {
  text-align: center;
}

.status-value {
  font-size: 2em;
  font-weight: bold;
  color: #409eff;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
