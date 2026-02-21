import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { authApi } from '@/services/api';
import './NewsCreate.css';

interface NewsFormData {
  headline: string;
  text: string;
  media_url: string;
  source_name: string;
  format: 'txt' | 'img' | 'img_txt';
  is_real: boolean;
  published_date: string;
  author_comment: string;
}

export const NewsEdit = () => {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const [user, setUser] = useState<{ username: string; role: string } | null>(null);
  const [formData, setFormData] = useState<NewsFormData>({
    headline: '',
    text: '',
    media_url: '',
    source_name: '',
    format: 'txt',
    is_real: false,
    published_date: new Date().toISOString().split('T')[0],
    author_comment: '',
  });
  const [loading, setLoading] = useState(true);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    checkAuth();
  }, []);

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
    if (!id) {
      setError('ID новости не указан');
      setLoading(false);
      return;
    }

    try {
      const response = await fetch(`/api/news/${id}`);
      if (response.ok) {
        const data = await response.json();
        setFormData({
          headline: data.headline,
          text: data.text || '',
          media_url: data.media_url || '',
          source_name: data.source_name || '',
          format: data.format,
          is_real: data.is_real,
          published_date: data.published_date || new Date().toISOString().split('T')[0],
          author_comment: data.author_comment || '',
        });
      } else {
        setError('Новость не найдена');
      }
    } catch (err) {
      setError('Ошибка загрузки');
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

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>
  ) => {
    const { name, value, type } = e.target;

    if (type === 'checkbox') {
      const checked = (e.target as HTMLInputElement).checked;
      setFormData(prev => ({ ...prev, [name]: checked }));
    } else {
      setFormData(prev => ({ ...prev, [name]: value }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    try {
      const formDataToSend = new FormData();
      formDataToSend.append('headline', formData.headline);
      formDataToSend.append('text', formData.text);
      formDataToSend.append('media_url', formData.media_url);
      formDataToSend.append('source_name', formData.source_name);
      formDataToSend.append('format', formData.format);
      formDataToSend.append('is_real', formData.is_real.toString());
      formDataToSend.append('published_date', formData.published_date);
      formDataToSend.append('author_comment', formData.author_comment);

      const response = await fetch(`/api/news/${id}`, {
        method: 'PUT',
        body: formDataToSend,
      });

      if (response.ok) {
        setSubmitted(true);
      } else {
        const data = await response.json();
        setError(data.error || 'Ошибка при обновлении новости');
      }
    } catch (err) {
      setError('Ошибка сети');
      console.error(err);
    }
  };

  const handleBackToList = () => {
    navigate('/news/list');
  };

  if (!user || loading) {
    return <div>Загрузка...</div>;
  }

  if (error && !formData.headline) {
    return (
      <div className="news-create-page">
        <div className="error-message" style={{ padding: '40px', textAlign: 'center' }}>
          <p>{error}</p>
          <button onClick={handleBackToList} className="submit-btn">
            Вернуться к списку
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="news-create-page">
      <div className="news-create-header">
        <div className="news-create-header-left">
          <button onClick={handleBackToList} className="btn-back">
            ← К списку новостей
          </button>
        </div>
        <div className="news-create-header-right">
          <span className="user-info">
            {user.username} ({user.role})
          </span>
          <button className="logout-btn" onClick={handleLogout}>
            Выйти
          </button>
        </div>
      </div>

      <div className="news-create-content">
        {/* Left column: Form */}
        <div className="news-create-form-column">
          <h2>Редактировать новость</h2>

          {!submitted ? (
            <form onSubmit={handleSubmit} className="news-create-form">
              <div className="form-field">
                <input
                  type="text"
                  name="headline"
                  placeholder="Заголовок"
                  value={formData.headline}
                  onChange={handleChange}
                  required
                />
              </div>

              <div className="form-field">
                <textarea
                  name="text"
                  placeholder="Текст новости"
                  rows={4}
                  value={formData.text}
                  onChange={handleChange}
                />
              </div>

              <div className="form-field">
                <input
                  type="text"
                  name="media_url"
                  placeholder="Ссылка на изображение"
                  value={formData.media_url}
                  onChange={handleChange}
                />
              </div>

              <div className="form-field">
                <input
                  type="text"
                  name="source_name"
                  placeholder="Источник"
                  value={formData.source_name}
                  onChange={handleChange}
                  required
                />
              </div>

              <div className="form-field">
                <textarea
                  name="author_comment"
                  placeholder="Комментарий автора (например: 'Эта новость была выдумана на основе...')"
                  rows={3}
                  value={formData.author_comment}
                  onChange={handleChange}
                />
              </div>

              <div className="form-field">
                <label>Формат:</label>
                <select name="format" value={formData.format} onChange={handleChange}>
                  <option value="txt">Только текст</option>
                  <option value="img">Только изображение</option>
                  <option value="img_txt">Текст + изображение</option>
                </select>
              </div>

              <div className="form-field">
                <label>
                  <input
                    type="checkbox"
                    name="is_real"
                    checked={formData.is_real}
                    onChange={handleChange}
                  />
                  Реальная новость
                </label>
              </div>

              <div className="form-field">
                <label htmlFor="published_date">Дата публикации:</label>
                <input
                  type="date"
                  name="published_date"
                  id="published_date"
                  value={formData.published_date}
                  onChange={handleChange}
                />
              </div>

              {error && <div className="error-message">{error}</div>}

              <button type="submit" className="submit-btn">
                Сохранить изменения
              </button>
            </form>
          ) : (
            <div className="success-message">
              <p>✅ Новость успешно обновлена!</p>
              <button onClick={handleBackToList} className="submit-btn">
                Вернуться к списку
              </button>
            </div>
          )}
        </div>

        {/* Right column: Preview */}
        <div className="news-create-preview-column">
          <h2>Превью</h2>
          <div className="question-card">
            <div className="question-card__counter">Превью</div>

            <h2 className="question-card__title">
              {formData.headline || 'Заголовок новости'}
            </h2>

            {formData.media_url && (
              <img
                src={formData.media_url}
                alt="Preview"
                className="question-card__image"
              />
            )}

            {formData.text && (
              <p className="question-card__content">{formData.text}</p>
            )}

            <div className="question-card__meta">
              Источник: {formData.source_name || 'Неизвестно'}
              {formData.published_date && (
                <> | Дата: {new Date(formData.published_date).toLocaleDateString('ru-RU')}</>
              )}
            </div>

            {formData.author_comment && (
              <div className="question-card__author-comment">
                <strong>Комментарий:</strong> {formData.author_comment}
              </div>
            )}

            {/* Truth badge for preview */}
            <div className="question-card__truth-badge">
              {formData.is_real ? 'REAL' : 'FAKE'}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};