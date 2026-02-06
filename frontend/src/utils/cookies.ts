export const getCookie = (name: string): string | null => {
  const cookies = document.cookie.split(';');
  for (const cookie of cookies) {
    const [cookieName, cookieValue] = cookie.trim().split('=');
    if (cookieName === name) {
      return decodeURIComponent(cookieValue);
    }
  }
  return null;
};

export const setCookie = (name: string, value: string, expiresAt?: Date): void => {
  let cookieString = `${name}=${encodeURIComponent(value)}; path=/`;

  if (expiresAt) {
    cookieString += `; expires=${expiresAt.toUTCString()}`;
  }

  document.cookie = cookieString;
};

export const deleteCookie = (name: string): void => {
  document.cookie = `${name}=; path=/; max-age=0`;
};

export const getTodayDate = (): string => {
  const today = new Date();
  return today.toISOString().split('T')[0];
};

export const hasCompletedToday = (): boolean => {
  const today = getTodayDate();
  return document.cookie.includes(`challenge_${today}=completed`);
};

export const setChallengeCompleted = (): void => {
  const today = getTodayDate();
  const expires = new Date();
  expires.setHours(23, 59, 59, 999);
  setCookie(`challenge_${today}`, 'completed', expires);
};

export const saveProgress = (index: number, results: boolean[], date: string): void => {
  const today = getTodayDate();
  const progress = { index, results, date };
  const expires = new Date();
  expires.setHours(23, 59, 59, 999);
  setCookie(`challenge_progress_${today}`, JSON.stringify(progress), expires);
};

export const loadProgress = (): { index: number; results: boolean[]; date: string } | null => {
  const today = getTodayDate();
  const progressJson = getCookie(`challenge_progress_${today}`);

  if (!progressJson) return null;

  try {
    return JSON.parse(progressJson);
  } catch {
    return null;
  }
};

export const clearProgress = (): void => {
  const today = getTodayDate();
  deleteCookie(`challenge_progress_${today}`);
};

export const saveDetailedResults = (results: boolean[], newsData: any[], date: string): void => {
  const today = getTodayDate();
  const detailedResults = {
    results,
    newsData,
    date
  };
  const expires = new Date();
  expires.setHours(23, 59, 59, 999);
  setCookie(`challenge_results_${today}`, JSON.stringify(detailedResults), expires);
};

export const loadDetailedResults = (): { results: boolean[]; newsData: any[]; date: string } | null => {
  const today = getTodayDate();
  const resultsJson = getCookie(`challenge_results_${today}`);

  if (!resultsJson) return null;

  try {
    return JSON.parse(resultsJson);
  } catch {
    return null;
  }
};

export const clearDetailedResults = (): void => {
  const today = getTodayDate();
  deleteCookie(`challenge_results_${today}`);
};