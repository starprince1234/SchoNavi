<script setup lang="ts">
import { BookOpen, Clock3, Heart, Home, Navigation } from 'lucide-vue-next'
</script>

<template>
  <div class="app-shell">
    <aside class="sidebar">
      <RouterLink class="brand" to="/home" aria-label="SchoNavi home">
        <Navigation :size="24" />
        <span>SchoNavi</span>
      </RouterLink>
      <nav class="nav-list">
        <RouterLink to="/home"><Home :size="18" />首页</RouterLink>
        <RouterLink to="/favorites"><Heart :size="18" />收藏</RouterLink>
        <RouterLink to="/history"><Clock3 :size="18" />历史</RouterLink>
      </nav>
      <div class="sidebar-note">
        <BookOpen :size="18" />
        <span>用自然语言找到适合你的导师</span>
      </div>
    </aside>
    <main class="main-panel">
      <RouterView />
    </main>
  </div>
</template>
