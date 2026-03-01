import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi } from '@/services/api';
import { searchWithLayout } from '@/utils/transliterate';
import './NewsList.css';

interface NewsItem {
  id: string;
  headline: string;
  text: string;
  format: string;
  is_real: boolean;
  media_url: string;
  source_name: string;
  published_date: string;
  author_comment: string;
  created_at: string;
}

export const NewsList = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<{ username: string; role: string } | null>(null);
  const [newsList, setNewsList] = useState<NewsItem[]>([]);
  const [filteredNews, setFilteredNews] = useState<NewsItem[]>([]);
  const [searchId, setSearchId] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    checkAuth().catch(console.error);
  }, []);

  useEffect(() => {
    if (searchId.trim()) {
      setFilteredNews(
        newsList.filter(item =>
          searchWithLayout(searchId, item.id) ||
          searchWithLayout(searchId, item.headline) ||
          (item.text && searchWithLayout(searchId, item.text))
        )
      );
    } else {
      setFilteredNews(newsList);
    }
  }, [searchId, newsList]);

  const checkAuth = async () => {
    try {
      const data = await authApi.checkAuth();
      if (data.authenticated) {
        setUser({ username: data.username, role: data.role });
        await loadNews();
      } else {
        navigate('/login');
      }
    } catch (err) {
      navigate('/login');
    }
  };

  const loadNews = async () => {
    try {
      const response = await fetch('/api/news/list');
      if (response.ok) {
        const data = await response.json();
        setNewsList(data);
      } else {
        setError('Ошибка загрузки новостей');
      }
    } catch (err) {
      setError('Ошибка сети');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await authApi.logout();
      navigate('/login');
    } catch (err) {
      console.error('Logout error:', err);
    }
  };

  const handleDelete = async (id: string, headline: string) => {
    if (!confirm(`Удалить новость "${headline}"?`)) {
      return;
    }

    try {
      const response = await fetch(`/api/news/${id}`, {
        method: 'DELETE',
      });

      if (response.ok) {
        setNewsList(prev => prev.filter(item => item.id !== id));
      } else {
        alert('Ошибка при удалении');
      }
    } catch (err) {
      alert('Ошибка сети');
    }
  };

  const handleRefreshDaily = async () => {
    if (!confirm('Обновить сегодняшний Daily Challenge? Все текущие прогрессы будут сброшены!')) {
      return;
    }

    try {
      const response = await fetch('/api/daily/refresh', {
        method: 'POST',
      });

      if (response.ok) {
        const data = await response.json();
        alert(`✅ Daily Challenge обновлён! Новостей: ${data.news_count}`);
      } else {
        const data = await response.json();
        alert(`Ошибка: ${data.detail || 'Не удалось обновить'}`);
      }
    } catch (err) {
      alert('Ошибка сети');
    }
  };

  if (!user) {
    return <div>Загрузка...</div>;
  }

  return (
    <div className="news-list-page">
      <div className="news-list-header">
        <h1>Список новостей</h1>
        <div className="news-list-header-actions">
          <input
            type="text"
            placeholder="Поиск по ID, заголовку или тексту..."
            value={searchId}
            onChange={(e) => setSearchId(e.target.value)}
            className="search-input"
          />
          <button onClick={() => navigate('/news/create')} className="btn-primary">
            Добавить новость
          </button>
          {user.role === 'admin' && (
            <button onClick={handleRefreshDaily} className="btn-refresh">
              🔄 Обновить Daily
            </button>
          )}
          <span className="user-info">
            {user.username} ({user.role})
          </span>
          <button className="logout-btn" onClick={handleLogout}>
            Выйти
          </button>
        </div>
      </div>

      <div className="news-list-content">
        {loading ? (
          <div className="loading">Загрузка...</div>
        ) : error ? (
          <div className="error-message">{error}</div>
        ) : filteredNews.length === 0 ? (
          <div className="empty-state">
            <p>{searchId ? 'Новость не найдена' : 'Новостей пока нет'}</p>
            {!searchId && (
              <button onClick={() => navigate('/news/create')} className="btn-primary">
                Создать первую новость
              </button>
            )}
          </div>
        ) : (
          <table className="news-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Заголовок</th>
                <th>Источник</th>
                <th>Формат</th>
                <th>Тип</th>
                <th>Дата публикации</th>
                <th>Создано</th>
                <th>Действия</th>
              </tr>
            </thead>
            <tbody>
              {filteredNews.map((item) => (
                <tr key={item.id}>
                  <td className="id-cell">
                    <code>{item.id.substring(0, 8)}...</code>
                  </td>
                  <td className="headline-cell">
                    <strong>{item.headline}</strong>
                    {item.text && (
                      <div className="text-preview">
                        {item.text.substring(0, 100)}
                        {item.text.length > 100 ? '...' : ''}
                      </div>
                    )}
                  </td>
                  <td>{item.source_name || '—'}</td>
                  <td>
                    <span className="format-badge">{item.format}</span>
                  </td>
                  <td>
                    <span className={`type-badge ${item.is_real ? 'type-real' : 'type-fake'}`}>
                      {item.is_real ? 'REAL' : 'FAKE'}
                    </span>
                  </td>
                  <td>
                    {item.published_date
                      ? new Date(item.published_date).toLocaleDateString('ru-RU')
                      : '—'}
                  </td>
                  <td>
                    {new Date(item.created_at).toLocaleDateString('ru-RU')}
                  </td>
                  <td className="actions-cell">
                    <button
                      onClick={() => navigate(`/news/edit/${item.id}`)}
                      className="btn-edit"
                    >
                      Редактировать
                    </button>
                    <button
                      onClick={() => handleDelete(item.id, item.headline)}
                      className="btn-delete"
                    >
                      Удалить
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};