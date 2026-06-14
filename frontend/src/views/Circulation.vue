<template>
  <div>
    <el-row :gutter="16">
      <el-col :span="8">
        <el-card header="办理借书">
          <el-form label-width="80px">
            <el-form-item label="读者编号"><el-input-number v-model="borrow.reader_id" :min="1" /></el-form-item>
            <el-form-item label="单册编号"><el-input-number v-model="borrow.copy_id" :min="1" /></el-form-item>
            <el-button type="primary" @click="doBorrow">借出</el-button>
          </el-form>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card header="办理还书">
          <el-form label-width="80px">
            <el-form-item label="借阅编号"><el-input-number v-model="ret.lend_id" :min="1" /></el-form-item>
            <el-button type="primary" @click="doReturn">归还</el-button>
          </el-form>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card header="缴纳罚单">
          <el-form label-width="80px">
            <el-form-item label="罚单编号"><el-input-number v-model="pay.penaltyId" :min="1" /></el-form-item>
            <el-button type="primary" @click="doPay">缴清</el-button>
          </el-form>
        </el-card>
      </el-col>
    </el-row>

    <el-tabs v-model="tab" style="margin-top: 16px">
      <el-tab-pane label="在借明细" name="active">
        <el-table :data="lends" v-loading="l.loading" border>
          <el-table-column prop="lend_id" label="借阅号" width="90" />
          <el-table-column prop="reader_name" label="读者" width="100" />
          <el-table-column prop="title" label="书名" />
          <el-table-column prop="location" label="位置" width="100" />
          <el-table-column prop="borrow_date" label="借出" width="120" />
          <el-table-column prop="due_date" label="应还" width="120" />
        </el-table>
      </el-tab-pane>
      <el-tab-pane label="罚单" name="penalty">
        <el-table :data="penalties" border>
          <el-table-column prop="penalty_id" label="罚单号" width="90" />
          <el-table-column prop="reader_name" label="读者" width="100" />
          <el-table-column prop="book_title" label="书名" />
          <el-table-column prop="amount" label="金额" width="90" />
          <el-table-column prop="status" label="状态" width="90" />
          <el-table-column label="操作" width="100">
            <template #default="{ row }">
              <el-button v-if="row.status === '未缴清'" link @click="quickPay(row.penalty_id)">缴清</el-button>
            </template>
          </el-table-column>
        </el-table>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import http from '../api'

const tab = ref('active')
const borrow = reactive({ reader_id: 1, copy_id: 1 })
const ret = reactive({ lend_id: 1 })
const pay = reactive({ penaltyId: 1 })

const l = reactive({ loading: false })
const lends = ref<any[]>([])
const penalties = ref<any[]>([])

async function loadLends() {
  l.loading = true
  try {
    const { data } = await http.get('/api/lend/active')
    lends.value = data
  } finally {
    l.loading = false
  }
}
async function loadPenalties() {
  const { data } = await http.get('/api/penalties')
  penalties.value = data
}

async function doBorrow() {
  await http.post('/api/lend/borrow', { reader_id: borrow.reader_id, copy_id: borrow.copy_id })
  ElMessage.success('借出成功')
  await loadLends()
}
async function doReturn() {
  await http.post('/api/lend/return', { lend_id: ret.lend_id })
  ElMessage.success('归还成功')
  await loadLends()
}
async function doPay() {
  await quickPay(pay.penaltyId)
}
async function quickPay(id: number) {
  await http.post(`/api/penalty/${id}/pay`)
  ElMessage.success('已缴清')
  await loadPenalties()
}

onMounted(async () => {
  await loadLends()
  await loadPenalties()
})
</script>
