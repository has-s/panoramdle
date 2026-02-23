// frontend/src/utils/formatUrl.ts

export const formatSourceUrl = (url: string | null): string => {
  if (!url) return '';

  try {
    // Если это не URL, вернуть как есть
    if (!url.match(/^https?:\/\//)) {
      return url;
    }

    const urlObj = new URL(url);
    const hostname = urlObj.hostname;

    // Убираем www.
    let cleanHost = hostname.replace(/^www\./, '');

    // Для Telegram добавляем путь (канал/группу)
    if (cleanHost.includes('t.me') || cleanHost.includes('telegram')) {
      const pathParts = urlObj.pathname.split('/').filter(Boolean);
      if (pathParts.length > 0) {
        cleanHost = `t.me/${pathParts[0]}`;
      }
    }

    return cleanHost;
  } catch (error) {
    return url;
  }
};

export const isUrl = (str: string | null): boolean => {
  if (!str) return false;
  return /^https?:\/\//.test(str);
};