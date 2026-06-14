<template>
  <el-container style="height: 100vh">
    <el-aside width="200px" style="background: #304156">
      <div class="logo">图书管理系统</div>
      <el-menu :default-active="$route.path" router background-color="#304156" text-color="#bfcbd9" active-text-color="#409eff">
        <el-menu-item index="/books">书目列表</el-menu-item>
        <el-menu-item v-if="auth.isAdmin" index="/readers">读者管理</el-menu-item>
        <el-menu-item v-if="auth.isAdmin" index="/circulation">借还操作台</el-menu-item>
        <el-menu-item index="/stats">统计看板</el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="bar">
        <span>{{ auth.role === 'admin' ? '管理员' : '读者' }}</span>
        <el-button link @click="doLogout">退出登录</el-button>
      </el-header>
      <el-main><router-view /></el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { auth, logout } from '../store/auth'

const router = useRouter()
function doLogout() {
  logout()
  router.push('/login')
}
</script>

<style scoped>
.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  color: #fff;
  font-size: 16px;
}
.bar {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 16px;
  border-bottom: 1px solid #eee;
}
</style>
