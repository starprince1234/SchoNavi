import { computed, ref } from 'vue'
import type { FavoriteItem, HistoryItem, ProfessorDetail, Recommendation, RecommendationResponse } from '../types/api'

const FAVORITES_KEY = 'schonavi:favorites'
const HISTORY_KEY = 'schonavi:history'

const favorites = ref<FavoriteItem[]>(readArray<FavoriteItem>(FAVORITES_KEY))
const history = ref<HistoryItem[]>(readArray<HistoryItem>(HISTORY_KEY))

export function useFavorites() {
  const favoriteIds = computed(() => new Set(favorites.value.map((item) => item.professor_id)))

  function isFavorite(professorId: string) {
    return favoriteIds.value.has(professorId)
  }

  function toggle(source: Recommendation | ProfessorDetail) {
    const existing = favorites.value.findIndex((item) => item.professor_id === source.professor_id)
    if (existing >= 0) {
      favorites.value.splice(existing, 1)
    } else {
      favorites.value.unshift(toFavorite(source))
    }
    persist(FAVORITES_KEY, favorites.value)
  }

  return { favorites, isFavorite, toggle }
}

export function useHistory() {
  function add(prompt: string, result: RecommendationResponse) {
    const item: HistoryItem = {
      id: `${Date.now()}_${Math.random().toString(16).slice(2)}`,
      prompt,
      session_id: result.session_id,
      recommendation_count: result.recommendations.length,
      summary: result.recommendations.slice(0, 3).map((rec) => rec.name).join('、') || '暂无推荐结果',
      created_at: new Date().toISOString(),
    }
    history.value = [item, ...history.value.filter((entry) => entry.prompt !== prompt)].slice(0, 30)
    persist(HISTORY_KEY, history.value)
  }

  function remove(id: string) {
    history.value = history.value.filter((item) => item.id !== id)
    persist(HISTORY_KEY, history.value)
  }

  function clear() {
    history.value = []
    persist(HISTORY_KEY, history.value)
  }

  return { history, add, remove, clear }
}

function toFavorite(source: Recommendation | ProfessorDetail): FavoriteItem {
  return {
    professor_id: source.professor_id,
    name: source.name,
    university: source.university,
    college: source.college,
    title: source.title,
    research_fields: source.research_fields,
    homepage_url: source.homepage_url,
    saved_at: new Date().toISOString(),
  }
}

function readArray<T>(key: string): T[] {
  try {
    const raw = localStorage.getItem(key)
    return raw ? JSON.parse(raw) as T[] : []
  } catch {
    return []
  }
}

function persist<T>(key: string, value: T[]) {
  localStorage.setItem(key, JSON.stringify(value))
}

