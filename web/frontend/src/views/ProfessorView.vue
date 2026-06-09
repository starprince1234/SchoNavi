<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ExternalLink, MessageCircle } from 'lucide-vue-next'
import { getProfessor } from '../api/client'
import FieldChips from '../components/FieldChips.vue'
import StateView from '../components/StateView.vue'
import { useFavorites } from '../stores/localStore'
import type { ProfessorDetail } from '../types/api'

const route = useRoute()
const router = useRouter()
const favorites = useFavorites()
const loading = ref(true)
const error = ref('')
const professor = ref<ProfessorDetail | null>(null)

async function load() {
  loading.value = true
  error.value = ''
  try {
    professor.value = await getProfessor(String(route.params.id))
  } catch (err) {
    error.value = err instanceof Error ? err.message : '导师详情读取失败'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <section class="content-view">
    <StateView v-if="loading" title="正在读取导师详情…" />
    <StateView v-else-if="error" title="导师详情读取失败" :message="error" action-label="重试" @action="load" />
    <article v-else-if="professor" class="detail-layout">
      <div class="detail-header">
        <div>
          <p>导师详情</p>
          <h1>{{ professor.name }}</h1>
          <span>{{ professor.university || '学校暂无信息' }} · {{ professor.college || '学院暂无信息' }}</span>
        </div>
        <div class="button-row">
          <button class="secondary-button" type="button" @click="favorites.toggle(professor)">
            {{ favorites.isFavorite(professor.professor_id) ? '取消收藏' : '收藏导师' }}
          </button>
          <button
            class="primary-button"
            type="button"
            @click="router.push({ path: '/chat', query: { sid: route.query.sid || 's_detail', pid: professor.professor_id } })"
          >
            <MessageCircle :size="18" />追问
          </button>
        </div>
      </div>
      <section class="detail-section">
        <h2>研究方向</h2>
        <FieldChips :fields="professor.research_fields" />
      </section>
      <section class="detail-section">
        <h2>简介</h2>
        <p>{{ professor.bio || '暂无信息' }}</p>
      </section>
      <section class="detail-grid">
        <div><span>职称</span><p>{{ professor.title || '暂无信息' }}</p></div>
        <div><span>更新时间</span><p>{{ professor.updated_at || '暂无信息' }}</p></div>
        <div><span>数据质量</span><p>{{ professor.data_quality_score == null ? '暂无信息' : Math.round(professor.data_quality_score * 100) + '%' }}</p></div>
      </section>
      <div class="button-row">
        <a v-if="professor.homepage_url" class="secondary-button link-button" :href="professor.homepage_url" target="_blank" rel="noreferrer">
          <ExternalLink :size="18" />打开主页
        </a>
        <a v-if="professor.source_url" class="secondary-button link-button" :href="professor.source_url" target="_blank" rel="noreferrer">
          <ExternalLink :size="18" />查看来源
        </a>
      </div>
    </article>
  </section>
</template>
