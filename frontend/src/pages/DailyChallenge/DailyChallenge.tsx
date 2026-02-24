import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { dailyApi, authApi } from '@/services/api';
import './DailyChallenge.css';
import {
  hasCompletedToday,
  setChallengeCompleted,
  saveProgress,
  loadProgress,
  clearProgress,
  getTodayDate,
  saveDetailedResults,
  loadDetailedResults
} from '@/utils/cookies';
import { formatSourceUrl, isUrl } from '@/utils/formatUrl';
import type { News, DailyChallengeStats } from '@/types';

export const DailyChallenge = () => {
  const navigate = useNavigate();
  const [dailyData, setDailyData] = useState<News[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [results, setResults] = useState<boolean[]>([]);
  const [challengeDate, setChallengeDate] = useState('');
  const [isModerator, setIsModerator] = useState(false);
  const [showWelcome, setShowWelcome] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [stats, setStats] = useState<DailyChallengeStats | null>(null);
  const [answered, setAnswered] = useState(false);
  const [currentNews, setCurrentNews] = useState<News | null>(null);
  const [isCorrect, setIsCorrect] = useState<boolean | null>(null);
  const [showResults, setShowResults] = useState(false);
  const [finalStats, setFinalStats] = useState<DailyChallengeStats | null>(null);
  const [showDetailedResults, setShowDetailedResults] = useState(false);
  const [savedResults, setSavedResults] = useState<{ results: boolean[]; newsData: News[] } | null>(null);

  useEffect(() => {
    document.title = 'Panoramdle - Daily Challenge';
    checkAuth();
    loadTodayStats();

    if (hasCompletedToday()) {
      const detailed = loadDetailedResults();
      if (detailed) {
        setSavedResults({
          results: detailed.results,
          newsData: detailed.newsData
        });
      }
    }
  }, []);

  useEffect(() => {
    if (dailyData.length > 0 && currentIndex < dailyData.length - 1) {
      const nextNews = dailyData[currentIndex + 1];
      if (nextNews?.media_url) {
        const img = new Image();
        img.src = nextNews.media_url;
      }
    }
  }, [currentIndex, dailyData]);

  const checkAuth = async () => {
    try {
      await authApi.me();
      setIsModerator(true);
    } catch {
      setIsModerator(false);
    }
  };

  const loadTodayStats = async () => {
    try {
      const today = getTodayDate();
      const statsData = await dailyApi.getStats(today);
      setStats(statsData);
    } catch (error) {
      console.error('Failed to load stats:', error);
    }
  };

  const startChallenge = async () => {
    if (hasCompletedToday()) {
      return;
    }

    setShowWelcome(false);
    setLoading(true);

    try {
      const response = await dailyApi.getToday();
      const newsData = response.news || [];
      setDailyData(newsData);
      setChallengeDate(response.challenge_date);

      if (newsData.length === 0) {
        setError('Нет доступных новостей');
        setLoading(false);
        return;
      }

      const savedProgress = loadProgress();
      if (savedProgress && savedProgress.date === response.challenge_date) {
        setCurrentIndex(savedProgress.index);
        setResults(savedProgress.results);
        setCurrentNews(newsData[savedProgress.index]);
      } else {
        setCurrentIndex(0);
        setResults([]);
        setCurrentNews(newsData[0]);
      }

      setLoading(false);
    } catch (err) {
      setError('Ошибка загрузки квиза');
      setLoading(false);
    }
  };

  const answer = (isReal: boolean) => {
    if (!currentNews) return;

    const correct = isReal === currentNews.is_real;
    const newResults = [...results, correct];
    setResults(newResults);
    setIsCorrect(correct);
    setAnswered(true);

    saveProgress(currentIndex, newResults, challengeDate);
  };

  const continueToNext = () => {
    const newIndex = currentIndex + 1;

    if (newIndex < dailyData.length) {
      setCurrentIndex(newIndex);
      setCurrentNews(dailyData[newIndex]);
      setAnswered(false);
      setIsCorrect(null);
      saveProgress(newIndex, results, challengeDate);
    } else {
      showResultsScreen();
    }
  };

  const showResultsScreen = async () => {
    const score = results.filter(Boolean).length;

    setChallengeCompleted();
    clearProgress();
    saveDetailedResults(results, dailyData, challengeDate);

    if (!isModerator) {
      try {
        const statsData = await dailyApi.submitResults(challengeDate, score);
        setFinalStats(statsData);
      } catch (error) {
        console.error('Failed to submit results:', error);
      }
    }

    setShowResults(true);
  };

    const handleRetry = () => {
      const today = getTodayDate();
      localStorage.removeItem(`challenge_results_${today}`);
      document.cookie = `challenge_${today}=; path=/; max-age=0`;
      setShowWelcome(true);
      setSavedResults(null);
      setShowDetailedResults(false);
      setShowResults(false);
      setDailyData([]);
      setResults([]);
      setCurrentIndex(0);
    };

  const copyNewsId = (newsId: string) => {
    navigator.clipboard.writeText(newsId).catch(err => {
      alert('Ошибка копирования: ' + err);
    });
  };

  if (hasCompletedToday() && showWelcome) {
    const score = savedResults ? savedResults.results.filter(Boolean).length : 0;
    const total = savedResults ? savedResults.results.length : 10;
    const percentage = total > 0 ? Math.round((score / total) * 100) : 0;

    let message = '';
    if (percentage === 100) message = 'Идеально!';
    else if (percentage >= 80) message = 'Отлично!';
    else if (percentage >= 60) message = 'Хорошо!';
    else if (percentage >= 40) message = 'Неплохо!';
    else message = 'Попробуйте ещё раз!';

    return (
      <div className="results-card">
        <div className="results-card__header">
          <h2 className="results-card__title">Вы уже прошли челлендж!</h2>
          {savedResults && (
            <>
              <div className="results-card__score">
                <span className="results-card__score-value">{score}</span>
                <span className="results-card__score-divider">/</span>
                <span className="results-card__score-total">{total}</span>
              </div>
              <p className="results-card__message">{message}</p>
            </>
          )}
        </div>

        {stats && stats.total_attempts > 0 && (
          <div className="results-card__stats">
            Средний результат сегодня: {stats.average_percentage}%
          </div>
        )}

        {savedResults && (
          <>
            <div className="results-card__actions">
              <button
                className="results-card__toggle"
                onClick={() => setShowDetailedResults(!showDetailedResults)}
              >
                {showDetailedResults ? 'Скрыть подробности' : 'Посмотреть подробнее'}
              </button>

              {isModerator && (
                <button
                  className="results-card__retry"
                  onClick={handleRetry}
                >
                  Пройти заново
                </button>
              )}
            </div>

            {showDetailedResults && (
              <div className="results-card__details">
                {savedResults.newsData.map((news, index) => (
                  <div
                    key={news.id}
                    className={`results-card__item ${savedResults.results[index] ? 'results-card__item--correct' : 'results-card__item--incorrect'}`}
                  >
                    <div className="results-card__item-header">
                      <span className="results-card__item-number">#{index + 1}</span>
                      <span className={`results-card__item-badge ${savedResults.results[index] ? 'results-card__item-badge--correct' : 'results-card__item-badge--incorrect'}`}>
                        {savedResults.results[index] ? '✓' : '✗'}
                      </span>
                    </div>
                    <div className="results-card__item-headline">{news.headline}</div>
                    <div className="results-card__item-meta">
                      <span>
                        Источник:{' '}
                        {isUrl(news.source_name) ? (
                          <a
                            href={news.source_name!}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="results-card__source-link"
                          >
                            {formatSourceUrl(news.source_name)}
                          </a>
                        ) : (
                          formatSourceUrl(news.source_name) || 'Неизвестно'
                        )}
                      </span>
                      <span className={`results-card__item-truth ${news.is_real ? 'results-card__item-truth--real' : 'results-card__item-truth--fake'}`}>
                        {news.is_real ? 'REAL' : 'FAKE'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </>
        )}

        <div className="results-card__footer">
          Возвращайтесь завтра за новыми новостями.
        </div>
      </div>
    );
  }

  if (showWelcome) {
    return (
      <div className="welcome-card">
        <div
          className="welcome-card__banner"
          onClick={() => isModerator && navigate('/moderation')}
          style={{ cursor: isModerator ? 'pointer' : 'default' }}
        >
          <span className="welcome-card__banner-text welcome-card__banner-text--main">BETA</span>
          <span className="welcome-card__banner-text welcome-card__banner-text--alt">
            {isModerator ? 'НА ПАНЕЛЬ' : 'NEW'}
          </span>
        </div>
        <h1 className="welcome-card__title">Panoramdle</h1>
        <p className="welcome-card__subtitle">Сможете отличить реальные новости от фейковых?</p>
        <ul className="welcome-card__rules">
          <li>10 новостей на сегодня</li>
          <li>Отметьте какие реальные, а какие фейковые</li>
          <li>Узнайте результат в конце</li>
          <li>Один шанс в день!</li>
        </ul>
        <button className="welcome-card__button" onClick={startChallenge}>
          Начать
        </button>
        <div className="welcome-card__badge">DAILY</div>
      </div>
    );
  }

  if (loading) {
    return <div>Загрузка квиза...</div>;
  }

  if (error) {
    return (
      <div>
        <h2>Ошибка загрузки</h2>
        <p>{error}</p>
      </div>
    );
  }

  if (showResults) {
    const score = results.filter(Boolean).length;
    const total = results.length;
    const percentage = Math.round((score / total) * 100);

    let message = '';
    if (percentage === 100) message = 'Идеально!';
    else if (percentage >= 80) message = 'Отлично!';
    else if (percentage >= 60) message = 'Хорошо!';
    else if (percentage >= 40) message = 'Неплохо!';
    else message = 'Попробуйте ещё раз!';

    return (
      <div className="results-card">
        <div className="results-card__header">
          <h2 className="results-card__title">Челлендж завершён!</h2>
          <div className="results-card__score">
            <span className="results-card__score-value">{score}</span>
            <span className="results-card__score-divider">/</span>
            <span className="results-card__score-total">{total}</span>
          </div>
          <p className="results-card__message">{message}</p>
        </div>

        {isModerator && (
          <div className="results-card__moderator-note">
            (Результаты модераторов не учитываются в статистике)
          </div>
        )}

        {!isModerator && finalStats && finalStats.total_attempts > 1 && (
          <div className="results-card__stats">
            Средний результат сегодня: {finalStats.average_percentage}%
          </div>
        )}

        <div className="results-card__actions">
          <button
            className="results-card__toggle"
            onClick={() => setShowDetailedResults(!showDetailedResults)}
          >
            {showDetailedResults ? 'Скрыть подробности' : 'Посмотреть подробнее'}
          </button>

          {isModerator && (
            <button
              className="results-card__retry"
              onClick={handleRetry}
            >
              Пройти заново
            </button>
          )}
        </div>

        {showDetailedResults && (
          <div className="results-card__details">
            {dailyData.map((news, index) => (
              <div
                key={news.id}
                className={`results-card__item ${results[index] ? 'results-card__item--correct' : 'results-card__item--incorrect'}`}
              >
                <div className="results-card__item-header">
                  <span className="results-card__item-number">#{index + 1}</span>
                  <span className={`results-card__item-badge ${results[index] ? 'results-card__item-badge--correct' : 'results-card__item-badge--incorrect'}`}>
                    {results[index] ? '✓' : '✗'}
                  </span>
                </div>
                <div className="results-card__item-headline">{news.headline}</div>
                <div className="results-card__item-meta">
                  <span>
                    Источник:{' '}
                    {isUrl(news.source_name) ? (
                      <a
                        href={news.source_name!}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="results-card__source-link"
                      >
                        {formatSourceUrl(news.source_name)}
                      </a>
                    ) : (
                      formatSourceUrl(news.source_name) || 'Неизвестно'
                    )}
                  </span>
                  <span className={`results-card__item-truth ${news.is_real ? 'results-card__item-truth--real' : 'results-card__item-truth--fake'}`}>
                    {news.is_real ? 'REAL' : 'FAKE'}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="results-card__footer">
          Возвращайтесь завтра за новым челленджем!
        </div>
      </div>
    );
  }

  if (!currentNews) {
    return <div>Загрузка...</div>;
  }

  return (
    <div className="question-card">
      <div className="question-card__counter">
        Вопрос {currentIndex + 1} из {dailyData.length}
      </div>

      {isModerator && (
        <div style={{ marginBottom: '10px', fontSize: '12px', color: '#999' }}>
          <span>ID: {currentNews.id}</span>
          <button onClick={() => copyNewsId(currentNews.id)} style={{ marginLeft: '10px', fontSize: '12px' }}>
            📋 Копировать
          </button>
        </div>
      )}

      <h2 className="question-card__title">{currentNews.headline}</h2>

      {currentNews.media_url && (
        <img
          src={currentNews.media_url}
          alt="Изображение новости"
          className="question-card__image"
          loading="lazy"
        />
      )}

      {currentNews.text && (
        <p className="question-card__content">
          {currentNews.text.split(' ').map((word, i) => {
            if (word.match(/^https?:\/\//) || word.match(/^[a-z0-9-]+\.[a-z]{2,}\//i)) {
              return (
                <span key={i}>
                  <a href={word.startsWith('http') ? word : `https://${word}`} target="_blank" rel="noopener noreferrer">
                    {word}
                  </a>{' '}
                </span>
              );
            }
            return <span key={i}>{word} </span>;
          })}
        </p>
      )}

      {answered && (
        <div className="question-card__meta">
          Источник:{' '}
          {isUrl(currentNews.source_name) ? (
            <a
              href={currentNews.source_name!}
              target="_blank"
              rel="noopener noreferrer"
              className="question-card__source-link"
            >
              {formatSourceUrl(currentNews.source_name)}
            </a>
          ) : (
            formatSourceUrl(currentNews.source_name) || 'Неизвестно'
          )}
          {currentNews.published_date && (
            <> | Дата: {new Date(currentNews.published_date).toLocaleDateString('ru-RU')}</>
          )}
        </div>
      )}

      {answered && currentNews.author_comment && (
        <div className="question-card__author-comment">
          <strong>Комментарий модератора:</strong> {currentNews.author_comment}
        </div>
      )}

      {!answered ? (
        <div className="question-card__buttons">
          <button className="question-card__button" onClick={() => answer(true)}>
            REAL
          </button>
          <button className="question-card__button question-card__button--danger" onClick={() => answer(false)}>
            FAKE
          </button>
        </div>
      ) : (
        <button className="question-card__continue" onClick={continueToNext}>
          {currentIndex < dailyData.length - 1 ? 'Продолжить' : 'Завершить'}
        </button>
      )}

      {answered && (
        <>
          <div className="question-card__truth-badge">
            {currentNews.is_real ? 'REAL' : 'FAKE'}
          </div>
          <div className={`question-card__result-badge ${isCorrect ? 'question-card__result-badge--correct' : 'question-card__result-badge--incorrect'}`}>
            {isCorrect ? '✓' : '✗'}
          </div>
        </>
      )}
    </div>
  );
};