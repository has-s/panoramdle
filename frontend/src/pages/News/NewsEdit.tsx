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

interface NewsMetadata {
  creator_username: string | null;
  editors: string[];
  created_at: string;
}

export const NewsEdit = () => {
  const navigate = useNavigate();
  const { id } = useParams();
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
  const [metadata, setMetadata] = useState<NewsMetadata>({
    creator_username: null,
    editors: [],
    created_at: '',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [imageError, setImageError] = useState(false);
  const [imageLoading, setImageLoading] = useState(false);

  useEffect(() => {
    const init = async () => {
      await checkAuth();
      if (id) {
        await loadNews();
      }
    };
    init();
  }, [id]);

  const checkAuth = async () => {
    try {
      const data = await authApi.checkAuth();
      if (data.authenticated) {
        setUser({ username: data.username, role: data.role });
      } else {
        navigate('/login');
      }
    } catch (err) {
      navigate('/login');
    }
  };

  const loadNews = async () => {
    setLoading(true);
    try {
      const response = await fetch(`/api/news/${id}`);
      if (!response.ok) {
        throw new Error('Новость не найдена');
      }
      const news = await response.json();

      setFormData({
        headline: news.headline,
        text: news.text || '',
        media_url: news.media_url || '',
        source_name: news.source_name || '',
        format: news.format,
        is_real: news.is_real,
        published_date: news.published_date || new Date().toISOString().split('T')[0],
        author_comment: news.author_comment || '',
      });

      // Сохраняем метаданные о создателе и редакторах
      setMetadata({
        creator_username: news.creator_username,
        editors: news.editors || [],
        created_at: news.created_at,
      });

      // Проверяем существующее фото
      if (news.media_url) {
        validateImage(news.media_url);
      }
    } catch (err) {
      setError('Ошибка загрузки новости');
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

  const validateImage = (url: string) => {
    if (!url) {
      setImageError(false);
      setImageLoading(false);
      return;
    }

    setImageLoading(true);
    setImageError(false);

    const img = new Image();
    img.onload = () => {
      setImageLoading(false);
      setImageError(false);
    };
    img.onerror = () => {
      setImageLoading(false);
      setImageError(true);
    };
    img.src = url;
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

      // Validate image when media_url changes
      if (name === 'media_url') {
        validateImage(value);
      }
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(false);

    // Block submission if image is broken
    if (imageError) {
      setError('Невозможно сохранить: изображение не загружается');
      return;
    }

    setSaving(true);

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
        setSuccess(true);
        setTimeout(() => {
          navigate('/news/list');
        }, 1500);
      } else {
        const data = await response.json();
        setError(data.error || 'Ошибка при обновлении новости');
      }
    } catch (err) {
      setError('Ошибка сети');
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  if (!user || loading) {
    return <div>Загрузка...</div>;
  }

  return (
    <div className="news-create-page">
      <div className="news-create-header">
        <span className="user-info">
          {user.username} ({user.role})
        </span>
        <button className="logout-btn" onClick={handleLogout}>
          Выйти
        </button>
      </div>

      <div className="news-create-content">
        {/* Left column: Form */}
        <div className="news-create-form-column">
          <h2>Редактировать новость</h2>

          {/* Metadata info */}
          <div style={{
            backgroundColor: '#f5f5f5',
            padding: '12px',
            borderRadius: '4px',
            marginBottom: '20px',
            fontSize: '14px',
            color: '#666',
          }}>
            {metadata.creator_username && (
              <div>Создатель: <strong>{metadata.creator_username}</strong></div>
            )}
            {metadata.editors.length > 0 && (
              <div>Изменено: <strong>{metadata.editors.join(', ')}</strong></div>
            )}
            {metadata.created_at && (
              <div style={{ marginTop: '8px', fontSize: '12px' }}>
                {new Date(metadata.created_at).toLocaleString('ru-RU')}
              </div>
            )}
          </div>

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
              {imageLoading && (
                <span className="image-status image-status-loading">
                  ⏳ Проверка изображения...
                </span>
              )}
              {imageError && (
                <span className="image-status image-status-error">
                  ⚠️ Ошибка: изображение не загружается!
                </span>
              )}
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
                placeholder="Комментарий автора"
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
            {success && <div className="success-message">✅ Новость успешно обновлена!</div>}

            <div style={{ display: 'flex', gap: '10px' }}>
              <button
                type="submit"
                className="submit-btn"
                disabled={saving || imageError}
              >
                {saving ? 'Сохранение...' : 'Сохранить'}
              </button>
              <button
                type="button"
                className="submit-btn"
                onClick={() => navigate('/news/list')}
                style={{ background: '#666' }}
              >
                Отмена
              </button>
            </div>
          </form>
        </div>

        {/* Right column: Preview */}
        <div className="news-create-preview-column">
          <h2>Превью</h2>
          <div className="question-card">
            <div className="question-card__counter">Превью</div>

            <h2 className="question-card__title">
              {formData.headline || 'Заголовок новости'}
            </h2>

            {formData.media_url && !imageError && (
              <img
                src={formData.media_url}
                alt="Preview"
                className="question-card__image"
                onError={() => setImageError(true)}
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

            <div className="question-card__truth-badge">
              {formData.is_real ? 'REAL' : 'FAKE'}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};