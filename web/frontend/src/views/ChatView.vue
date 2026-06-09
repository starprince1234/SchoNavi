<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { SendHorizonal } from 'lucide-vue-next'
import { sendMessage } from '../api/client'
import ProfessorCard from '../components/ProfessorCard.vue'
import { useFavorites } from '../stores/localStore'
import type { Recommendation } from '../types/api'

interface ChatBubble {
  role: 'user' | 'assistant'
  content: string
  related: Recommendation[]
}

const route = useRoute()
const router = useRouter()
const favorites = useFavorites()
const sessionId = ref(String(route.query.sid || 's_web'))
const professorId = ref(route.query.pid ? String(route.query.pid) : undefined)
const message = ref(String(route.query.q || ''))
const loading = ref(false)
const error = ref('')
const bubbles = ref<ChatBubble[]>([
  {
    role: 'assistant',
    content: '可以继续问我推荐理由、相似导师，或补充地区/方向来重新收窄结果。',
    related: [],
  },
])
const listRef = ref<HTMLElement | null>(null)

async function submit() {
  const text = message.value.trim()
  if (!text || loading.value) return
  bubbles.value.push({ role: 'user', content: text, related: [] })
  message.value = ''
  loading.value = true
  error.value = ''
  await scrollToBottom()
  try {
    const response = await sendMessage(sessionId.value, text, professorId.value)
    bubbles.value.push({
      role: 'assistant',
      content: response.answer,
      related: response.related_recommendations,
    })
  } catch (err) {
    error.value = err instanceof Error ? err.message : '消息发送失败'
  } finally {
    loading.value = false
    await scrollToBottom()
  }
}

async function scrollToBottom() {
  await nextTick()
  listRef.value?.scrollTo({ top: listRef.value.scrollHeight, behavior: 'smooth' })
}

onMounted(() => {
  if (message.value.trim()) void submit()
})
</script>

<template>
  <section class="chat-view">
    <div class="page-toolbar">
      <div>
        <p>继续追问</p>
        <h1>推荐会话</h1>
      </div>
    </div>
    <div ref="listRef" class="chat-list">
      <div v-for="(bubble, index) in bubbles" :key="index" class="bubble" :class="bubble.role">
        <p>{{ bubble.content }}</p>
        <div v-if="bubble.related.length" class="embedded-list">
          <ProfessorCard
            v-for="professor in bubble.related"
            :key="professor.professor_id"
            :professor="professor"
            :favorite="favorites.isFavorite(professor.professor_id)"
            @open="router.push(`/professor/${professor.professor_id}?sid=${encodeURIComponent(sessionId)}`)"
            @toggle-favorite="favorites.toggle(professor)"
          />
        </div>
      </div>
      <p v-if="loading" class="loading-line">正在生成回答…</p>
      <p v-if="error" class="error-line">{{ error }}</p>
    </div>
    <form class="chat-input" @submit.prevent="submit">
      <input v-model="message" placeholder="例如：为什么推荐这位导师？有没有相似导师？" />
      <button class="primary-button" type="submit" :disabled="!message.trim() || loading">
        <SendHorizonal :size="18" />发送
      </button>
    </form>
  </section>
</template>
