import { request } from '@/utils/request'

export const authApi = {
  // 登录
  login(data) {
    return request.post('/auth/login', data)
  },
  
  // 登出
  logout() {
    return request.post('/auth/logout')
  },
  
  // 获取用户信息
  getUserInfo() {
    return request.get('/auth/user')
  },
  
  // 修改密码
  changePassword(data) {
    return request.post('/auth/change-password', data)
  },
  
  // 刷新token
  refreshToken() {
    return request.post('/auth/refresh')
  }
}
