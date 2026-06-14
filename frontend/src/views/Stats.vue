<template>
  <div>
    <el-tabs v-model="tab">
      <el-tab-pane label="馆藏库存" name="inventory">
        <el-table :data="inventory" v-loading="loading" border>
          <el-table-column prop="book_id" label="编号" width="80" />
          <el-table-column prop="isbn" label="ISBN" width="140" />
          <el-table-column prop="title" label="书名" />
          <el-table-column prop="author" label="作者" />
          <el-table-column prop="total_copies" label="馆藏" width="80" />
          <el-table-column prop="available_copies" label="可借" width="80" />
        </el-table>
      </el-tab-pane>

      <el-tab-pane label="在借明细" name="borrowing">
        <el-table :data="borrowing" v-loading="loading" border>
          <el-table-column prop="reader_name" label="读者" width="100" />
          <el-table-column prop="card_number" label="证号" width="120" />
          <el-table-column prop="book_title" label="书名" />
          <el-table-column prop="book_location" label="位置" width="100" />
          <el-table-column prop="borrow_date" label="借出" width="120" />
          <el-table-column prop="due_date" label="应还" width="120" />
        </el-table>
      </el-tab-pane>

      <el-tab-pane v-if="auth.isAdmin" label="逾期预警" name="overdue">
        <el-table :data="overdue" v-loading="loading" border>
          <el-table-column prop="lend_id" label="借阅号" width="90" />
          <el-table-column prop="reader_name" label="读者" width="100" />
          <el-table-column prop="phone" label="电话" width="140" />
          <el-table-column prop="book_title" label="书名" />
          <el-table-column prop="due_date" label="应还" width="120" />
          <el-table-column prop="overdue_days" label="逾期天数" width="100" />
        </el-table>
      </el-tab-pane>

      <el-tab-pane label="评价统计" name="reviews">
        <el-table :data="reviews" v-loading="loading" border>
          <el-table-column prop="book_id" label="编号" width="80" />
          <el-table-column prop="title" label="书名" />
          <el-table-column prop="review_count" label="评价数" width="90" />
          <el-table-column prop="avg_score" label="平均分" width="90" />
        </el-table>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import http from '../api'
import { auth } from '../store/auth'

const tab = ref('inventory')
const loading = ref(false)
const inventory = ref<any[]>([])
const borrowing = ref<any[]>([])
const overdue = ref<any[]>([])
const reviews = ref<any[]>([])

async function load(key: string) {
  loading.value = true
  try {
    const { data } = await http.get(`/api/stats/${key}`)
    if (key === 'inventory') inventory.value = data
    else if (key === 'borrowing') borrowing.value = data
    else if (key === 'overdue') overdue.value = data
    else if (key === 'reviews') reviews.value = data
  } finally {
    loading.value = false
  }
}

watch(tab, (t) => load(t))
onMounted(() => load('inventory'))
</script>
