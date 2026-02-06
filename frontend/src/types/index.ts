export interface News {
  id: string;
  headline: string;
  text: string | null;
  media_url: string | null;
  source_name: string | null;
  published_date: string | null;
  is_real: boolean;
}

export interface DailyChallenge {
  challenge_date: string;
  news: News[];
  total_attempts?: number;
  total_correct?: number;
}

export interface DailyChallengeStats {
  total_attempts: number;
  total_correct: number;
  average_correct: number;
  average_percentage: number;
}

export interface Moderator {
  id: string;
  username: string;
  role: string;
  created_at: string;
}

export interface AuthResponse {
  moderator: Moderator;
}