import { useState, useEffect } from 'react';
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
import type { News, DailyChallengeStats } from '@/types';

export const DailyChallenge = () => {
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

    // Load saved results if completed today
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

  const checkAuth = async () => {
    try {
      await authApi.me();
      setIsModerator(true);
    } catch {
      // Regular users are not moderators - this is expected
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
        console.log('Восстановлен прогресс:', savedProgress.index, 'вопрос');
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

    // Don't increment index yet - will do it in continueToNext
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

    // Save detailed results for later viewing
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

  const copyNewsId = (newsId: string) => {
    navigator.clipboard.writeText(newsId).catch(err => {
      alert('Ошибка копирования: ' + err);
    });
  };

  // Welcome screen (already completed)
  if (hasCompletedToday() && showWelcome) {
    return (
      <div>
        <h1>Panoramdle</h1>
        <p>Вы уже прошли сегодняшний челлендж!</p>
        {stats && stats.total_attempts > 0 && (
          <p>Средний результат сегодня: {stats.average_percentage}%</p>
        )}

        {savedResults && (
          <div style={{ marginTop: '20px' }}>
            <button onClick={() => setShowDetailedResults(!showDetailedResults)}>
              {showDetailedResults ? 'Скрыть подробности' : 'Посмотреть подробнее'}
            </button>

            {showDetailedResults && (
              <div style={{ marginTop: '20px' }}>
                <h3>Ваши результаты:</h3>
                <div>
                  Правильных ответов: {savedResults.results.filter(Boolean).length} / {savedResults.results.length}
                </div>
                {savedResults.newsData.map((news, index) => (
                  <div key={news.id} style={{
                    marginTop: '15px',
                    padding: '10px',
                    border: '1px solid #ccc',
                    backgroundColor: savedResults.results[index] ? '#e8f5e9' : '#ffebee'
                  }}>
                    <div>
                      <strong>Вопрос {index + 1}:</strong> {news.headline}
                    </div>
                    <div>
                      Источник: {news.source_name || 'Неизвестно'}
                    </div>
                    <div>
                      {savedResults.results[index] ? '✓ Правильно' : '✗ Неправильно'}
                    </div>
                    <div>
                      Это была: {news.is_real ? 'Правда' : 'Фейк'}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        <p style={{ marginTop: '20px' }}>Возвращайтесь завтра за новыми новостями.</p>
      </div>
    );
  }

  // Welcome screen (before start)
  if (showWelcome) {
    return (
      <div className="welcome-card">
        <div className="welcome-card__banner">
          <span className="welcome-card__banner-text welcome-card__banner-text--main">BETA</span>
          <span className="welcome-card__banner-text welcome-card__banner-text--alt">NEW</span>
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

  // Loading
  if (loading) {
    return <div>Загрузка квиза...</div>;
  }

  // Error
  if (error) {
    return (
      <div>
        <h2>Ошибка загрузки</h2>
        <p>{error}</p>
      </div>
    );
  }

  // Results screen
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
      <div>
        <h2>Челлендж завершён!</h2>
        <div>{score} / {total}</div>
        <p>{message}</p>

        {isModerator && (
          <p>(Результаты модераторов не учитываются в статистике)</p>
        )}

        {!isModerator && finalStats && finalStats.total_attempts > 1 && (
          <p>Средний результат сегодня: {finalStats.average_percentage}%</p>
        )}

        <div style={{ marginTop: '30px' }}>
          <button onClick={() => setShowDetailedResults(!showDetailedResults)}>
            {showDetailedResults ? 'Скрыть подробности' : 'Посмотреть подробнее'}
          </button>

          {showDetailedResults && (
            <div style={{ marginTop: '20px' }}>
              <h3>Подробные результаты:</h3>
              {dailyData.map((news, index) => (
                <div key={news.id} style={{
                  marginBottom: '15px',
                  padding: '10px',
                  border: '1px solid #ccc',
                  backgroundColor: results[index] ? '#e8f5e9' : '#ffebee'
                }}>
                  <div>
                    <strong>Вопрос {index + 1}:</strong> {news.headline}
                  </div>
                  <div>
                    Источник: {news.source_name || 'Неизвестно'}
                  </div>
                  <div>
                    {results[index] ? '✓ Правильно' : '✗ Неправильно'}
                  </div>
                  <div>
                    Это была: {news.is_real ? 'Правда' : 'Фейк'}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <p style={{ marginTop: '30px' }}>Возвращайтесь завтра за новым челленджем!</p>
      </div>
    );
  }

  // Question screen
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
        />
      )}

      {currentNews.text && (
        <p className="question-card__content">
          {currentNews.text.split(' ').map((word, i) => {
            // Check if word is a URL
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
          Источник: {currentNews.source_name || 'Неизвестно'}
          {currentNews.published_date && (
            <> | Дата: {new Date(currentNews.published_date).toLocaleDateString('ru-RU')}</>
          )}
        </div>
      )}

      {!answered ? (
        <div className="question-card__buttons">
          <button
            className="question-card__button"
            onClick={() => answer(true)}
          >
            REAL
          </button>
          <button
            className="question-card__button question-card__button--danger"
            onClick={() => answer(false)}
          >
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