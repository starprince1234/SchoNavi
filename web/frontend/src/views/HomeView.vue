<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Search, X } from 'lucide-vue-next'

const router = useRouter()
const prompt = ref('')
const maxLen = 1000

const examples = [
  '我想找计算机视觉方向的导师，最好在北京。',
  '我想做 AI 和医疗结合的研究，有没有适合的老师？',
  '推荐几个 NLP 和大模型安全方向的导师。',
  '我是自动化背景，想申请机器人方向博士。',
  '我想找江浙沪地区偏应用的人工智能导师。',
]

const tags = [
  '人工智能',
  '计算机视觉',
  '自然语言处理',
  '医学影像',
  '机器人',
  '网络安全',
  '生物信息',
  '材料计算',
  '北京',
  '上海',
  '江浙沪',
  '博士申请',
  '硕士申请',
]

function submit() {
  const value = prompt.value.trim()
  if (!value) return
  router.push({ path: '/recommendation', query: { q: value } })
}

function appendTag(tag: string) {
  prompt.value = prompt.value ? `${prompt.value} ${tag}` : tag
}
</script>

<template>
  <section class="home-view">
    <div class="page-heading">
      <p>导师推荐</p>
      <h1>用自然语言找到适合你的导师</h1>
    </div>
    <div class="search-surface">
      <textarea
        v-model="prompt"
        :maxlength="maxLen"
        rows="6"
        placeholder="例如：我想找医学影像和计算机视觉方向的导师，最好在上海，适合申请硕士。"
      />
      <div class="search-footer">
        <span>{{ prompt.length }} / {{ maxLen }}</span>
        <div class="button-row">
          <button class="secondary-button" type="button" :disabled="!prompt" @click="prompt = ''">
            <X :size="17" />清空
          </button>
          <button class="primary-button" type="button" :disabled="!prompt.trim()" @click="submit">
            <Search :size="18" />开始推荐
          </button>
        </div>
      </div>
    </div>
    <section class="plain-section">
      <h2>快捷标签</h2>
      <div class="chip-row">
        <button class="chip-button" v-for="tag in tags" :key="tag" type="button" @click="appendTag(tag)">
          {{ tag }}
        </button>
      </div>
    </section>
    <section class="plain-section">
      <h2>试试这些</h2>
      <button class="example-row" v-for="item in examples" :key="item" type="button" @click="prompt = item">
        {{ item }}
      </button>
    </section>
  </section>
</template>
