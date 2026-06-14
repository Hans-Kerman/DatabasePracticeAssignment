import axios from 'axios'
import { ElMessage } from 'element-plus'
import { auth, logout } from './store/auth'

const http = axios.create({ baseURL: '/' })

http.interceptors.request.use((cfg) => {
  if (auth.token) cfg.headers.Authorization = `Bearer ${auth.token}`
  return cfg
})

http.interceptors.response.use(
  (r) => r,
  (err) => {
    if (err.response?.status === 401) logout()
    const msg = err.response?.data?.detail || err.message
    ElMessage.error(typeof msg === 'string' ? msg : '请求失败')
    return Promise.reject(err)
  },
)

export default http
