export interface QueryUnderstanding {
  research_interests: string[]
  preferred_locations: string[]
  preferred_universities: string[]
  degree_stage?: string | null
  uncertainties: string[]
}

export interface Recommendation {
  professor_id: string
  name: string
  university?: string | null
  college?: string | null
  title?: string | null
  research_fields: string[]
  homepage_url?: string | null
  match_level?: string | null
  match_score?: number | null
  reason: string
  limitations: string[]
}

export interface RecommendationResponse {
  session_id: string
  query_understanding: QueryUnderstanding
  recommendations: Recommendation[]
  follow_up_questions: string[]
}

export interface ProfessorDetail {
  professor_id: string
  name: string
  university?: string | null
  college?: string | null
  title?: string | null
  research_fields: string[]
  bio?: string | null
  homepage_url?: string | null
  source_url?: string | null
  updated_at?: string | null
  data_quality_score?: number | null
}

export interface ChatMessageResponse {
  session_id: string
  answer: string
  related_recommendations: Recommendation[]
}

export interface FavoriteItem {
  professor_id: string
  name: string
  university?: string | null
  college?: string | null
  title?: string | null
  research_fields: string[]
  homepage_url?: string | null
  saved_at: string
}

export interface HistoryItem {
  id: string
  prompt: string
  session_id: string
  recommendation_count: number
  summary: string
  created_at: string
}

