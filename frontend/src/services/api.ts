import axios, { AxiosError } from 'axios';
import type {
  DailyChallenge,
  DailyChallengeStats,
  AuthResponse,
  News
} from '@/types';

const api = axios.create({
  baseURL: '/api',
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Error handler
api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    // Silently ignore 401 on auth check - it's expected for non-moderators
    if (error.config?.url === '/auth/me' && error.response?.status === 401) {
      return Promise.reject(error);
    }

    if (error.response?.status === 401) {
      // Unauthorized - redirect to login if on moderation page
      if (window.location.pathname.startsWith('/moderation') &&
          window.location.pathname !== '/moderation/login') {
        window.location.href = '/moderation/login';
      }
    }
    return Promise.reject(error);
  }
);

// Daily Challenge API
export const dailyApi = {
  getToday: async (): Promise<DailyChallenge> => {
    const { data } = await api.get<DailyChallenge>('/daily');
    return data;
  },

  getByDate: async (date: string): Promise<DailyChallenge> => {
    const { data } = await api.get<DailyChallenge>(`/daily/${date}`);
    return data;
  },

  submitResults: async (challengeDate: string, correctCount: number): Promise<DailyChallengeStats> => {
    const formData = new FormData();
    formData.append('challenge_date', challengeDate);
    formData.append('correct_count', correctCount.toString());

    console.log('=== SUBMITTING ===');
    console.log('challengeDate:', challengeDate);
    console.log('correctCount:', correctCount);
    console.log('FormData entries:', Array.from(formData.entries()));

    const { data } = await api.post<DailyChallengeStats>('/daily/submit', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return data;
  },

  getStats: async (date?: string): Promise<DailyChallengeStats> => {
    const params = date ? { date } : {};
    const { data } = await api.get<DailyChallengeStats>('/daily/stats', { params });
    return data;
  },
};

// Auth API
export const authApi = {
  login: async (username: string, password: string): Promise<AuthResponse> => {
    const formData = new FormData();
    formData.append('username', username);
    formData.append('password', password);

    const { data } = await api.post<AuthResponse>('/auth/login', formData);
    return data;
  },

  logout: async (): Promise<void> => {
    await api.post('/auth/logout');
  },

  me: async (): Promise<AuthResponse> => {
    const { data } = await api.get<{ authenticated: boolean; moderator?: AuthResponse['moderator'] }>('/auth/me');

    if (!data.authenticated || !data.moderator) {
      throw new Error('Not authenticated');
    }

    return { moderator: data.moderator };
  },
};

// Moderation API (placeholder - will expand later)
export const moderationApi = {
  getNews: async (): Promise<News[]> => {
    const { data } = await api.get<News[]>('/moderation/api/news');
    return data;
  },

  addNews: async (newsData: FormData): Promise<News> => {
    const { data } = await api.post<News>('/moderation/api/news', newsData);
    return data;
  },
};

export default api;