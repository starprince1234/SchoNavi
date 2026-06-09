import type {
  ChatMessageResponse,
  ProfessorDetail,
  RecommendationResponse,
} from '../types/api'

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || '').replace(/\/$/, '')

function apiUrl(path: string) {
  return `${API_BASE_URL}${path}`
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
    ...init,
  })
  if (!response.ok) {
    let message = '服务异常，请稍后重试'
    try {
      const payload = await response.json()
      message = payload.detail || message
    } catch {
      // Keep the default message for non-JSON failures.
    }
    throw new Error(message)
  }
  return response.json() as Promise<T>
}

export function getRecommendations(prompt: string, sessionId?: string) {
  return request<RecommendationResponse>(apiUrl('/api/recommendations'), {
    method: 'POST',
    body: JSON.stringify({ prompt, session_id: sessionId }),
  })
}

export function getProfessor(professorId: string) {
  return request<ProfessorDetail>(apiUrl(`/api/professors/${encodeURIComponent(professorId)}`))
}

export function sendMessage(sessionId: string, message: string, professorId?: string) {
  return request<ChatMessageResponse>(apiUrl('/api/chat/messages'), {
    method: 'POST',
    body: JSON.stringify({
      session_id: sessionId,
      message,
      professor_id: professorId,
    }),
  })
}
