import Cookies from 'js-cookie'

const TOKEN_KEY = 'xray-converter-token'
const TOKEN_EXPIRES = 7 // 7天

// 获取token
export function getToken() {
  return Cookies.get(TOKEN_KEY) || localStorage.getItem(TOKEN_KEY)
}

// 设置token
export function setToken(token) {
  Cookies.set(TOKEN_KEY, token, { expires: TOKEN_EXPIRES })
  localStorage.setItem(TOKEN_KEY, token)
}

// 移除token
export function removeToken() {
  Cookies.remove(TOKEN_KEY)
  localStorage.removeItem(TOKEN_KEY)
}

// 检查token是否存在
export function hasToken() {
  return !!getToken()
}
