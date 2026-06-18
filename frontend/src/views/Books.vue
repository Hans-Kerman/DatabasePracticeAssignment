<template>
  <div>
    <el-form inline>
      <el-form-item label="关键字">
        <el-input v-model="q" placeholder="书名/作者/ISBN" clearable style="width: 200px" @keyup.enter="load" />
      </el-form-item>
      <el-form-item label="分类">
        <el-select v-model="cat" clearable placeholder="全部" style="width: 150px">
          <el-option v-for="c in cats" :key="c.category_id" :label="c.name" :value="c.category_id" />
        </el-select>
      </el-form-item>
      <el-button type="primary" @click="load">查询</el-button>
      <el-button v-if="auth.isAdmin" @click="openAdd">新增书目</el-button>
    </el-form>

    <el-table v-loading="loading" :data="rows" border>
      <el-table-column prop="isbn" label="ISBN" width="140" />
      <el-table-column prop="title" label="书名" />
      <el-table-column prop="author" label="作者" />
      <el-table-column prop="publisher" label="出版社" />
      <el-table-column label="操作" width="100">
        <template #default="{ row }">
          <el-button link @click="openDetail(row.book_id)">详情</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="detail.show" :title="detail.book?.title" width="680px">
      <div v-if="detail.book">
        <p>ISBN：{{ detail.book.isbn }} ｜ 作者：{{ detail.book.author }} ｜ 出版社：{{ detail.book.publisher }}</p>
        <p>馆藏 {{ detail.book.inventory?.total_copies }} 本，可借 {{ detail.book.inventory?.available_copies }} 本</p>
        <h4>单册</h4>
        <el-table :data="detail.book.copies" size="small" border>
          <el-table-column prop="copy_id" label="编号" width="80" />
          <el-table-column prop="location" label="位置" />
          <el-table-column prop="status" label="状态" width="100" />
        </el-table>
        <template v-if="auth.isAdmin">
          <el-divider />
          <el-form inline>
            <el-form-item label="数量"><el-input-number v-model="addCopies.count" :min="1" :max="100" /></el-form-item>
            <el-form-item label="位置"><el-input v-model="addCopies.location" style="width: 120px" /></el-form-item>
            <el-button type="primary" @click="submitAddCopies(detail.book.book_id)">批量入库</el-button>
          </el-form>
        </template>
        <h4>评价</h4>
        <el-table :data="detail.book.reviews" size="small" border>
          <el-table-column prop="reader_name" label="读者" width="100" />
          <el-table-column prop="score" label="评分" width="80" />
          <el-table-column prop="content" label="内容" />
        </el-table>
        <template v-if="!auth.isAdmin">
          <el-divider />
          <el-form inline>
            <el-form-item label="评分"><el-rate v-model="review.score" /></el-form-item>
            <el-form-item label="评价"><el-input v-model="review.content" style="width: 240px" /></el-form-item>
            <el-button type="primary" @click="postReview(detail.book.book_id)">发表</el-button>
          </el-form>
        </template>
      </div>
    </el-dialog>

    <el-dialog v-model="add.show" title="新增书目" width="500px">
      <el-form label-width="80px">
        <el-form-item label="ISBN"><el-input v-model="add.form.isbn" /></el-form-item>
        <el-form-item label="书名"><el-input v-model="add.form.title" /></el-form-item>
        <el-form-item label="作者"><el-input v-model="add.form.author" /></el-form-item>
        <el-form-item label="出版社"><el-input v-model="add.form.publisher" /></el-form-item>
        <el-form-item label="出版日期"><el-input v-model="add.form.pub_date" placeholder="YYYY-MM-DD" /></el-form-item>
        <el-form-item label="单价"><el-input-number v-model="add.form.price" :min="0" /></el-form-item>
        <el-form-item label="分类">
          <el-select v-model="add.form.category_ids" multiple style="width: 100%">
            <el-option v-for="c in cats" :key="c.category_id" :label="c.name" :value="c.category_id" />
          </el-select>
        </el-form-item>
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
import { auth } from '../store/auth'

const q = ref('')
const cat = ref<number | null>(null)
const cats = ref<any[]>([])
const rows = ref<any[]>([])
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    const params: Record<string, unknown> = {}
    if (q.value) params.q = q.value
    if (cat.value) params.category_id = cat.value
    const { data } = await http.get('/api/books', { params })
    rows.value = data
  } finally {
    loading.value = false
  }
}

const detail = reactive<{ show: boolean; book: any }>({ show: false, book: null })
async function openDetail(id: number) {
  const { data } = await http.get(`/api/books/${id}`)
  detail.book = data
  detail.show = true
}

const review = reactive({ score: 5, content: '' })
async function postReview(bookId: number) {
  await http.post('/api/reviews', { book_id: bookId, score: review.score, content: review.content })
  ElMessage.success('评价已发表')
  await openDetail(bookId)
}

const add = reactive<{ show: boolean; form: any }>({
  show: false,
  form: { isbn: '', title: '', author: '', publisher: '', pub_date: '', price: null, category_ids: [] },
})
function openAdd() {
  add.show = true
}
async function submitAdd() {
  await http.post('/api/books', add.form)
  ElMessage.success('已新增')
  add.show = false
  await load()
}

const addCopies = reactive({ count: 1, location: '' })
async function submitAddCopies(bookId: number) {
  await http.post(`/api/books/${bookId}/copies`, { count: addCopies.count, location: addCopies.location })
  ElMessage.success('已入库')
  await openDetail(bookId)
}

onMounted(async () => {
  const { data } = await http.get('/api/categories')
  cats.value = data
  await load()
})
</script>
