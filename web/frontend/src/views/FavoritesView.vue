<script setup lang="ts">
import { useRouter } from 'vue-router'
import ProfessorCard from '../components/ProfessorCard.vue'
import StateView from '../components/StateView.vue'
import { useFavorites } from '../stores/localStore'

const router = useRouter()
const favorites = useFavorites()
const favoriteItems = favorites.favorites
</script>

<template>
  <section class="content-view">
    <div class="page-heading">
      <p>本地收藏</p>
      <h1>收藏</h1>
    </div>
    <StateView
      v-if="!favoriteItems.length"
      title="暂无收藏导师"
      message="在推荐结果或导师详情中点击收藏后，会显示在这里。"
      action-label="去搜索"
      @action="router.push('/home')"
    />
    <section v-else class="list-section">
      <ProfessorCard
        v-for="professor in favoriteItems"
        :key="professor.professor_id"
        :professor="professor"
        favorite
        @open="router.push(`/professor/${professor.professor_id}`)"
        @toggle-favorite="favorites.toggle(professor)"
      />
    </section>
  </section>
</template>
