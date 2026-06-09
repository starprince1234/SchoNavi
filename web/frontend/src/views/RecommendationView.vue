<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { MessageCircle } from 'lucide-vue-next'
import { getRecommendations } from '../api/client'
import ProfessorCard from '../components/ProfessorCard.vue'
import QueryUnderstanding from '../components/QueryUnderstanding.vue'
import StateView from '../components/StateView.vue'
import { useFavorites, useHistory } from '../stores/localStore'
import type { RecommendationResponse } from '../types/api'

const route = useRoute()
const router = useRouter()
const favorites = useFavorites()
const history = useHistory()
const loading = ref(false)
const error = ref('')
const result = ref<RecommendationResponse | null>(null)
const recordedSession = ref('')

async function load() {
  const prompt = String(route.query.q || '').trim()
  if (!prompt) {
    router.replace('/home')
    return
  }
  loading.value = true
  error.value = ''
  try {
    result.value = await getRecommendations(prompt)
    if (result.value.session_id !== recordedSession.value) {
      history.add(prompt, result.value)
      recordedSession.value = result.value.session_id
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : '出错了，请稍后重试'
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(() => route.query.q, load)
</script>

<template>
  <section class="content-view">
    <div class="page-toolbar">
      <div>
        <p>推荐结果</p>
        <h1>{{ route.query.q }}</h1>
      </div>
      <button
        v-if="result?.recommendations.length"
        class="primary-button"
        type="button"
        @click="router.push({ path: '/chat', query: { sid: result.session_id } })"
      >
        <MessageCircle :size="18" />继续追问
      </button>
    </div>

    <StateView v-if="loading" title="正在为你匹配导师…" />
    <StateView v-else-if="error" title="服务异常" :message="error" action-label="重试" @action="load" />
    <StateView
      v-else-if="result && !result.recommendations.length"
      title="暂未找到完全符合条件的导师"
      message="可尝试放宽学校、地区或研究方向限制。"
      action-label="修改条件"
      @action="router.push('/home')"
    />
    <div v-else-if="result" class="result-stack">
      <QueryUnderstanding :understanding="result.query_understanding" />
      <section class="list-section">
        <ProfessorCard
          v-for="professor in result.recommendations"
          :key="professor.professor_id"
          :professor="professor"
          :favorite="favorites.isFavorite(professor.professor_id)"
          @open="router.push(`/professor/${professor.professor_id}?sid=${encodeURIComponent(result!.session_id)}`)"
          @toggle-favorite="favorites.toggle(professor)"
        />
      </section>
      <section v-if="result.follow_up_questions.length" class="plain-section">
        <h2>可以继续追问</h2>
        <button
          class="example-row"
          v-for="question in result.follow_up_questions"
          :key="question"
          type="button"
          @click="router.push({ path: '/chat', query: { sid: result!.session_id, q: question } })"
        >
          {{ question }}
        </button>
      </section>
    </div>
  </section>
</template>
