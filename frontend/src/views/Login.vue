<template>
  <div class="login">
    <el-card>
      <el-tabs v-model="tab">
        <el-tab-pane label="管理员" name="admin">
          <el-form label-width="70px">
            <el-form-item label="账号">
              <el-input v-model="form.username" />
            </el-form-item>
            <el-form-item label="密码">
              <el-input v-model="form.password" type="password" show-password />
            </el-form-item>
            <el-button type="primary" :loading="loading" @click="doLogin('admin')">登录</el-button>
          </el-form>
        </el-tab-pane>
        <el-tab-pane label="读者" name="reader">
          <el-form label-width="90px">
            <el-form-item label="读者证号">
              <el-input v-model="form.card" />
            </el-form-item>
            <el-button type="primary" :loading="loading" @click="doLogin('reader')">登录</el-button>
          </el-form>
        </el-tab-pane>
      </el-tabs>
      <p class="tip">演示：管理员 admin/admin123；读者证号 R2026001</p>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import http from '../api'
import { setAuth } from '../store/auth'

const router = useRouter()
const tab = ref('admin')
const loading = ref(false)
const form = reactive({ username: 'admin', password: '', card: '' })

async function doLogin(kind: 'admin' | 'reader') {
  loading.value = true
  try {
    const url = kind === 'admin' ? '/api/login/admin' : '/api/login/reader'
    const payload =
      kind === 'admin'
        ? { username: form.username, password: form.password }
        : { card_number: form.card }
    const { data } = await http.post(url, payload)
    setAuth(data.token, data.role)
    router.push('/')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f0f2f5;
}
.el-card {
  width: 400px;
}
.tip {
  color: #999;
  font-size: 12px;
  margin-top: 8px;
}
</style>
