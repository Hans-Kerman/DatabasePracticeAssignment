<template>
  <div>
    <el-form inline>
      <el-form-item label="搜索">
        <el-input v-model="q" placeholder="姓名/证号" clearable style="width: 200px" @keyup.enter="load" />
      </el-form-item>
      <el-button type="primary" @click="load">查询</el-button>
      <el-button @click="openAdd">新增读者</el-button>
    </el-form>

    <el-table v-loading="loading" :data="rows" border>
      <el-table-column prop="reader_id" label="编号" width="80" />
      <el-table-column prop="name" label="姓名" width="100" />
      <el-table-column prop="card_number" label="证号" width="120" />
      <el-table-column prop="phone" label="电话" />
      <el-table-column prop="valid_until" label="证件有效期" width="120" />
      <el-table-column prop="status" label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === '正常' ? 'success' : 'danger'">{{ row.status }}</el-tag>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="add.show" title="新增读者" width="460px">
      <el-form label-width="90px">
        <el-form-item label="姓名"><el-input v-model="add.form.name" /></el-form-item>
        <el-form-item label="证号"><el-input v-model="add.form.card_number" /></el-form-item>
        <el-form-item label="电话"><el-input v-model="add.form.phone" /></el-form-item>
        <el-form-item label="证件有效期"><el-input v-model="add.form.valid_until" placeholder="YYYY-MM-DD" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="add.show = false">取消</el-button>
        <el-button type="primary" @click="submitAdd">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import http from '../api'

const q = ref('')
const rows = ref<any[]>([])
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    const { data } = await http.get('/api/readers', { params: { q: q.value || undefined } })
    rows.value = data
  } finally {
    loading.value = false
  }
}

const add = reactive<{ show: boolean; form: any }>({
  show: false,
  form: { name: '', card_number: '', phone: '', valid_until: '' },
})
function openAdd() {
  add.show = true
}
async function submitAdd() {
  await http.post('/api/readers', add.form)
  ElMessage.success('已新增')
  add.show = false
  await load()
}

onMounted(load)
</script>
