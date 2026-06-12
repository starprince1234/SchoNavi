<script setup lang="ts">
import { ExternalLink, Heart, HeartOff } from 'lucide-vue-next'
import type { FavoriteItem, Recommendation } from '../types/api'
import FieldChips from './FieldChips.vue'

const props = defineProps<{
  professor: Recommendation | FavoriteItem
  favorite?: boolean
}>()

defineEmits<{
  open: [id: string]
  toggleFavorite: []
}>()

function matchText() {
  if ('match_level' in props.professor && props.professor.match_level) {
    return props.professor.match_score == null
      ? props.professor.match_level
      : `${props.professor.match_level} ${Math.round(props.professor.match_score * 100)}%`
  }
  return '已收藏'
}
</script>

<template>
  <article class="professor-card" @click="$emit('open', professor.professor_id)">
    <div class="card-topline">
      <div>
        <h3>{{ professor.name }}</h3>
        <p>{{ professor.university || '学校暂无信息' }} · {{ professor.college || '学院暂无信息' }}</p>
      </div>
      <span class="match-badge">{{ matchText() }}</span>
    </div>
    <FieldChips :fields="professor.research_fields" />
    <p v-if="'reason' in professor" class="reason">推荐理由：{{ professor.reason }}</p>
    <p v-if="'limitations' in professor && professor.limitations.length" class="limitations">
      {{ professor.limitations[0] }}
    </p>
    <div class="card-actions" @click.stop>
      <button class="icon-button" type="button" :title="favorite ? '取消收藏' : '收藏导师'" @click="$emit('toggleFavorite')">
        <HeartOff v-if="favorite" :size="18" />
        <Heart v-else :size="18" />
      </button>
      <a v-if="professor.homepage_url" class="icon-button" :href="professor.homepage_url" target="_blank" rel="noreferrer" title="打开主页">
        <ExternalLink :size="18" />
      </a>
    </div>
  </article>
</template>
