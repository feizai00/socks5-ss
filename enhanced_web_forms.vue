<!-- 增强的Web端表单组件 - 支持完整的客户和节点管理 -->
<template>
  <div class="enhanced-xray-manager">
    <!-- 主导航标签页 -->
    <el-tabs v-model="activeTab" @tab-click="handleTabClick">
      <!-- 客户管理 -->
      <el-tab-pane label="客户管理" name="customers">
        <div class="tab-content">
          <!-- 工具栏 -->
          <div class="toolbar">
            <el-button type="primary" @click="showCustomerDialog = true">
              <el-icon><Plus /></el-icon>
              添加客户
            </el-button>
            <el-button @click="refreshCustomers">
              <el-icon><Refresh /></el-icon>
              刷新
            </el-button>
            <div class="toolbar-right">
              <el-input 
                v-model="customerSearch" 
                placeholder="搜索客户..."
                style="width: 200px;"
                @input="handleCustomerSearch"
              >
                <template #prefix>
                  <el-icon><Search /></el-icon>
                </template>
              </el-input>
            </div>
          </div>

          <!-- 客户列表 -->
          <el-table :data="customers" v-loading="customersLoading" style="width: 100%; margin-top: 20px;">
            <el-table-column prop="wechat_id" label="微信号" width="150" />
            <el-table-column prop="wechat_name" label="微信名称" width="150" />
            <el-table-column prop="service_count" label="使用服务数" width="100">
              <template #default="scope">
                <el-tag type="info">{{ scope.row.service_count || 0 }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="100">
              <template #default="scope">
                <el-tag :type="getCustomerStatusType(scope.row.status)">
                  {{ getCustomerStatusText(scope.row.status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="phone" label="电话" width="120" />
            <el-table-column prop="notes" label="备注" />
            <el-table-column prop="created_at" label="创建时间" width="180">
              <template #default="scope">
                {{ formatTime(scope.row.created_at) }}
              </template>
            </el-table-column>
            <el-table-column label="操作" width="200">
              <template #default="scope">
                <el-button size="small" @click="viewCustomerServices(scope.row)">
                  查看服务
                </el-button>
                <el-button size="small" type="warning" @click="editCustomer(scope.row)">
                  编辑
                </el-button>
                <el-button size="small" type="danger" @click="deleteCustomer(scope.row)">
                  删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-tab-pane>

      <!-- 节点管理 -->
      <el-tab-pane label="节点管理" name="nodes">
        <div class="tab-content">
          <!-- 工具栏 -->
          <div class="toolbar">
            <el-button type="primary" @click="showNodeDialog = true">
              <el-icon><Plus /></el-icon>
              添加节点
            </el-button>
            <el-button @click="refreshNodes">
              <el-icon><Refresh /></el-icon>
              刷新
            </el-button>
            <el-select v-model="nodeRegionFilter" placeholder="筛选地区" style="width: 150px; margin-left: 10px;">
              <el-option label="全部地区" value="" />
              <el-option 
                v-for="region in regions" 
                :key="region.id" 
                :label="region.flag_emoji + ' ' + region.name" 
                :value="region.id" 
              />
            </el-select>
          </div>

          <!-- 节点列表 -->
          <el-table :data="filteredNodes" v-loading="nodesLoading" style="width: 100%; margin-top: 20px;">
            <el-table-column prop="node_name" label="节点名称" width="150" />
            <el-table-column prop="socks5_number" label="SOCKS5编号" width="120" />
            <el-table-column prop="region" label="地区" width="100">
              <template #default="scope">
                <span>{{ scope.row.region?.flag_emoji }} {{ scope.row.region?.name }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="ip_address" label="IP地址" width="130" />
            <el-table-column prop="port" label="端口" width="80" />
            <el-table-column prop="username" label="用户名" width="100" />
            <el-table-column prop="password" label="密码" width="100">
              <template #default="scope">
                <span v-if="scope.row.showPassword">{{ scope.row.password }}</span>
                <span v-else>••••••••</span>
                <el-button 
                  type="text" 
                  size="small"
                  @click="toggleNodePasswordVisibility(scope.row)"
                >
                  <el-icon><View v-if="!scope.row.showPassword" /><Hide v-else /></el-icon>
                </el-button>
              </template>
            </el-table-column>
            <el-table-column prop="current_connections" label="连接数" width="80">
              <template #default="scope">
                <el-tag :type="scope.row.current_connections >= scope.row.max_connections ? 'danger' : 'success'">
                  {{ scope.row.current_connections }}/{{ scope.row.max_connections }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="expires_at" label="到期时间" width="180">
              <template #default="scope">
                <span :class="{ 'text-danger': isExpiringSoon(scope.row.expires_at) }">
                  {{ scope.row.expires_at ? formatTime(scope.row.expires_at) : '永久' }}
                </span>
              </template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="100">
              <template #default="scope">
                <el-tag :type="getNodeStatusType(scope.row.status)">
                  {{ getNodeStatusText(scope.row.status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="200">
              <template #default="scope">
                <el-button size="small" @click="viewNodeServices(scope.row)">
                  查看服务
                </el-button>
                <el-button size="small" type="warning" @click="editNode(scope.row)">
                  编辑
                </el-button>
                <el-button size="small" type="danger" @click="deleteNode(scope.row)">
                  删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-tab-pane>

      <!-- 服务管理 -->
      <el-tab-pane label="服务管理" name="services">
        <div class="tab-content">
          <!-- 工具栏 -->
          <div class="toolbar">
            <el-button type="primary" @click="showServiceDialog = true">
              <el-icon><Plus /></el-icon>
              创建服务
            </el-button>
            <el-button @click="refreshServices">
              <el-icon><Refresh /></el-icon>
              刷新
            </el-button>
            <el-button type="success" @click="batchAssignServices">
              <el-icon><Connection /></el-icon>
              批量分配
            </el-button>
          </div>

          <!-- 服务列表 -->
          <el-table :data="services" v-loading="servicesLoading" style="width: 100%; margin-top: 20px;">
            <el-table-column type="selection" width="55" />
            <el-table-column prop="port" label="SS端口" width="100" />
            <el-table-column prop="customer" label="客户信息" width="200">
              <template #default="scope">
                <div v-if="scope.row.customer">
                  <div>{{ scope.row.customer.wechat_name }}</div>
                  <small class="text-muted">{{ scope.row.customer.wechat_id }}</small>
                </div>
                <el-tag v-else type="info">未分配</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="node" label="节点信息" width="200">
              <template #default="scope">
                <div v-if="scope.row.node">
                  <div>{{ scope.row.node.region?.flag_emoji }} {{ scope.row.node.node_name }}</div>
                  <small class="text-muted">{{ scope.row.node.ip_address }}:{{ scope.row.node.port }}</small>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="service_name" label="服务名称" width="150" />
            <el-table-column prop="status" label="状态" width="100">
              <template #default="scope">
                <el-tag :type="getServiceStatusType(scope.row.status)">
                  {{ getServiceStatusText(scope.row.status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="expires_at" label="客户到期时间" width="180">
              <template #default="scope">
                <span :class="{ 'text-danger': isExpiringSoon(scope.row.expires_at) }">
                  {{ scope.row.expires_at ? formatTime(scope.row.expires_at) : '永久' }}
                </span>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="250">
              <template #default="scope">
                <el-button size="small" @click="viewServiceInfo(scope.row)">
                  连接信息
                </el-button>
                <el-button size="small" type="warning" @click="assignService(scope.row)">
                  分配客户
                </el-button>
                <el-button size="small" type="danger" @click="deleteService(scope.row)">
                  删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-tab-pane>
    </el-tabs>

    <!-- 添加客户对话框 -->
    <el-dialog v-model="showCustomerDialog" title="添加客户" width="500px">
      <el-form :model="newCustomer" label-width="100px">
        <el-form-item label="微信号" required>
          <el-input v-model="newCustomer.wechat_id" placeholder="请输入客户微信号" />
        </el-form-item>
        <el-form-item label="微信名称" required>
          <el-input v-model="newCustomer.wechat_name" placeholder="请输入客户微信名称" />
        </el-form-item>
        <el-form-item label="电话">
          <el-input v-model="newCustomer.phone" placeholder="请输入客户电话" />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input v-model="newCustomer.email" placeholder="请输入客户邮箱" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="newCustomer.status" style="width: 100%">
            <el-option label="活跃" value="active" />
            <el-option label="暂停" value="suspended" />
            <el-option label="过期" value="expired" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="newCustomer.notes" type="textarea" placeholder="客户备注信息" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCustomerDialog = false">取消</el-button>
        <el-button type="primary" @click="createCustomer" :loading="createCustomerLoading">
          创建客户
        </el-button>
      </template>
    </el-dialog>

    <!-- 添加节点对话框 -->
    <el-dialog v-model="showNodeDialog" title="添加SOCKS5节点" width="600px">
      <el-form :model="newNode" label-width="120px">
        <el-form-item label="节点名称" required>
          <el-input v-model="newNode.node_name" placeholder="请输入节点名称" />
        </el-form-item>
        <el-form-item label="SOCKS5编号" required>
          <el-input v-model="newNode.socks5_number" placeholder="请输入SOCKS5编号" />
        </el-form-item>
        <el-form-item label="地区" required>
          <el-select v-model="newNode.region_id" placeholder="请选择地区" style="width: 100%">
            <el-option 
              v-for="region in regions" 
              :key="region.id" 
              :label="region.flag_emoji + ' ' + region.name" 
              :value="region.id" 
            />
          </el-select>
        </el-form-item>
        <el-form-item label="IP地址" required>
          <el-input v-model="newNode.ip_address" placeholder="请输入SOCKS5 IP地址" />
        </el-form-item>
        <el-form-item label="端口" required>
          <el-input-number v-model="newNode.port" :min="1" :max="65535" style="width: 100%" />
        </el-form-item>
        <el-form-item label="用户名">
          <el-input v-model="newNode.username" placeholder="SOCKS5用户名(可选)" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="newNode.password" type="password" placeholder="SOCKS5密码(可选)" />
        </el-form-item>
        <el-form-item label="最大连接数">
          <el-input-number v-model="newNode.max_connections" :min="1" :max="100" style="width: 100%" />
        </el-form-item>
        <el-form-item label="带宽限制">
          <el-input-number v-model="newNode.bandwidth_limit" :min="1" style="width: 100%" />
          <span style="margin-left: 10px;">Mbps</span>
        </el-form-item>
        <el-form-item label="到期时间">
          <el-date-picker
            v-model="newNode.expires_at"
            type="datetime"
            placeholder="选择到期时间"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="newNode.notes" type="textarea" placeholder="节点备注信息" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showNodeDialog = false">取消</el-button>
        <el-button type="primary" @click="createNode" :loading="createNodeLoading">
          创建节点
        </el-button>
      </template>
    </el-dialog>

    <!-- 创建服务对话框 -->
    <el-dialog v-model="showServiceDialog" title="创建Shadowsocks服务" width="600px">
      <el-form :model="newService" label-width="120px">
        <el-form-item label="服务名称">
          <el-input v-model="newService.service_name" placeholder="请输入服务名称" />
        </el-form-item>
        <el-form-item label="SS端口" required>
          <el-input-number v-model="newService.port" :min="1" :max="65535" style="width: 100%" />
          <el-button @click="generateRandomPort" style="margin-left: 10px;">随机生成</el-button>
        </el-form-item>
        <el-form-item label="SS密码" required>
          <el-input v-model="newService.password" placeholder="请输入SS密码" />
          <el-button @click="generateRandomPassword" style="margin-left: 10px;">随机生成</el-button>
        </el-form-item>
        <el-form-item label="加密方法">
          <el-select v-model="newService.method" style="width: 100%">
            <el-option label="aes-256-gcm" value="aes-256-gcm" />
            <el-option label="aes-128-gcm" value="aes-128-gcm" />
            <el-option label="chacha20-poly1305" value="chacha20-poly1305" />
          </el-select>
        </el-form-item>
        <el-form-item label="SOCKS5节点" required>
          <el-select v-model="newService.socks5_node_id" placeholder="请选择SOCKS5节点" style="width: 100%">
            <el-option 
              v-for="node in availableNodes" 
              :key="node.id" 
              :label="`${node.region?.flag_emoji} ${node.node_name} (${node.current_connections}/${node.max_connections})`"
              :value="node.id"
              :disabled="node.current_connections >= node.max_connections"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="分配客户">
          <el-select v-model="newService.customer_id" placeholder="选择客户(可选)" style="width: 100%" clearable>
            <el-option 
              v-for="customer in customers" 
              :key="customer.id" 
              :label="`${customer.wechat_name} (${customer.wechat_id})`"
              :value="customer.id" 
            />
          </el-select>
        </el-form-item>
        <el-form-item label="客户到期时间">
          <el-date-picker
            v-model="newService.expires_at"
            type="datetime"
            placeholder="选择客户到期时间"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showServiceDialog = false">取消</el-button>
        <el-button type="primary" @click="createService" :loading="createServiceLoading">
          创建服务
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import axios from 'axios'

// 响应式数据
const activeTab = ref('customers')
const customers = ref([])
const nodes = ref([])
const services = ref([])
const regions = ref([])

const customerSearch = ref('')
const nodeRegionFilter = ref('')
const customersLoading = ref(false)
const nodesLoading = ref(false)
const servicesLoading = ref(false)

// 对话框控制
const showCustomerDialog = ref(false)
const showNodeDialog = ref(false)
const showServiceDialog = ref(false)

// 表单数据
const newCustomer = reactive({
  wechat_id: '',
  wechat_name: '',
  phone: '',
  email: '',
  status: 'active',
  notes: ''
})

const newNode = reactive({
  node_name: '',
  socks5_number: '',
  region_id: null,
  ip_address: '',
  port: null,
  username: '',
  password: '',
  max_connections: 1,
  bandwidth_limit: null,
  expires_at: null,
  notes: ''
})

const newService = reactive({
  service_name: '',
  port: null,
  password: '',
  method: 'aes-256-gcm',
  socks5_node_id: null,
  customer_id: null,
  expires_at: null
})

// 加载状态
const createCustomerLoading = ref(false)
const createNodeLoading = ref(false)
const createServiceLoading = ref(false)

// 计算属性
const filteredNodes = computed(() => {
  if (!nodeRegionFilter.value) return nodes.value
  return nodes.value.filter(node => node.region_id === nodeRegionFilter.value)
})

const availableNodes = computed(() => {
  return nodes.value.filter(node => 
    node.status === 'active' && node.current_connections < node.max_connections
  )
})

// 方法
const handleTabClick = (tab) => {
  if (tab.name === 'customers') {
    loadCustomers()
  } else if (tab.name === 'nodes') {
    loadNodes()
  } else if (tab.name === 'services') {
    loadServices()
  }
}

const loadCustomers = async () => {
  customersLoading.value = true
  try {
    const response = await axios.get('/api/customers')
    customers.value = response.data
  } catch (error) {
    ElMessage.error('加载客户列表失败')
  } finally {
    customersLoading.value = false
  }
}

const loadNodes = async () => {
  nodesLoading.value = true
  try {
    const response = await axios.get('/api/nodes')
    nodes.value = response.data.map(node => ({ ...node, showPassword: false }))
  } catch (error) {
    ElMessage.error('加载节点列表失败')
  } finally {
    nodesLoading.value = false
  }
}

const loadServices = async () => {
  servicesLoading.value = true
  try {
    const response = await axios.get('/api/services/enhanced')
    services.value = response.data
  } catch (error) {
    ElMessage.error('加载服务列表失败')
  } finally {
    servicesLoading.value = false
  }
}

const loadRegions = async () => {
  try {
    const response = await axios.get('/api/regions')
    regions.value = response.data
  } catch (error) {
    ElMessage.error('加载地区列表失败')
  }
}

// 工具函数
const formatTime = (timestamp) => {
  return new Date(timestamp * 1000).toLocaleString()
}

const isExpiringSoon = (timestamp) => {
  if (!timestamp) return false
  const now = Date.now() / 1000
  const threeDays = 3 * 24 * 60 * 60
  return timestamp - now < threeDays
}

const getCustomerStatusType = (status) => {
  const statusMap = { 'active': 'success', 'suspended': 'warning', 'expired': 'danger' }
  return statusMap[status] || 'info'
}

const getCustomerStatusText = (status) => {
  const statusMap = { 'active': '活跃', 'suspended': '暂停', 'expired': '过期' }
  return statusMap[status] || status
}

const generateRandomPort = () => {
  newService.port = Math.floor(Math.random() * 50000) + 10000
}

const generateRandomPassword = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let password = ''
  for (let i = 0; i < 16; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  newService.password = password
}

// 生命周期
onMounted(() => {
  loadRegions()
  loadCustomers()
})
</script>

<style scoped>
.enhanced-xray-manager {
  padding: 20px;
}

.tab-content {
  margin-top: 20px;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.toolbar-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.text-danger {
  color: #f56c6c;
}

.text-muted {
  color: #909399;
  font-size: 12px;
}
</style>
