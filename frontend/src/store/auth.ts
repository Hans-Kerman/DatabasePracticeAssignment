import { reactive } from 'vue'

const TOKEN_KEY = 'lib_token'
const ROLE_KEY = 'lib_role'

export const auth = reactive({
  token: localStorage.getItem(TOKEN_KEY) || '',
  role: localStorage.getItem(ROLE_KEY) || '',
  get isLogin() {
    return !!this.token
  },
  get isAdmin() {
    return this.role === 'admin'
  },
})

export function setAuth(token: string, role: string) {
  auth.token = token
  auth.role = role
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(ROLE_KEY, role)
}

export function logout() {
  auth.token = ''
  auth.role = ''
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(ROLE_KEY)
}
