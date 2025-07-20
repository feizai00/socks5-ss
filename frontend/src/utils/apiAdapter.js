// API适配器 - 根据环境变量选择使用模拟API还是真实API
import mockApi from './mockApi'
import realApi from '../api/index'

// 根据环境变量决定使用哪个API
// 优先检查localStorage中的强制设置，然后检查环境变量
const FORCE_USE_MOCK = localStorage.getItem('FORCE_USE_MOCK')
const USE_MOCK = FORCE_USE_MOCK !== null
  ? FORCE_USE_MOCK === 'true'
  : import.meta.env.VITE_USE_MOCK === 'true'

// 导出适配后的API
export const customerApi = USE_MOCK ? mockApi.customer : realApi.customer
export const nodeApi = USE_MOCK ? mockApi.node : realApi.node
export const serviceApi = USE_MOCK ? mockApi.service : realApi.service
export const statsApi = USE_MOCK ? mockApi.stats : realApi.stats
export const authApi = USE_MOCK ? mockApi.auth : realApi.auth
export const systemApi = USE_MOCK ? mockApi.system : realApi.system

// 默认导出
export default {
  customer: customerApi,
  node: nodeApi,
  service: serviceApi,
  stats: statsApi,
  auth: authApi,
  system: systemApi
}

// 工具函数：检查当前使用的API类型
export const isUsingMockApi = () => USE_MOCK

// 工具函数：获取API基础URL
export const getApiBaseUrl = () => import.meta.env.VITE_API_BASE_URL

// 工具函数：切换API模式（需要重新加载页面）
export const switchApiMode = (useMock) => {
  localStorage.setItem('FORCE_USE_MOCK', useMock.toString())
  window.location.reload()
}
