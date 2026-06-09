import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import FavoritesView from '../views/FavoritesView.vue'
import HistoryView from '../views/HistoryView.vue'
import RecommendationView from '../views/RecommendationView.vue'
import ProfessorView from '../views/ProfessorView.vue'
import ChatView from '../views/ChatView.vue'

export const router = createRouter({
  history: createWebHistory(),
  scrollBehavior() {
    return { top: 0 }
  },
  routes: [
    { path: '/', redirect: '/home' },
    { path: '/home', component: HomeView },
    { path: '/favorites', component: FavoritesView },
    { path: '/history', component: HistoryView },
    { path: '/recommendation', component: RecommendationView },
    { path: '/professor/:id', component: ProfessorView },
    { path: '/chat', component: ChatView },
  ],
})
