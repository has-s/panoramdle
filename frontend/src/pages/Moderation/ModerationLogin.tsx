import { useEffect } from 'react';

export const ModerationLogin = () => {
  useEffect(() => {
    document.title = 'Вход - Модерация';
  }, []);

  return (
    <div style={{ padding: '40px', textAlign: 'center' }}>
      <h1>Moderation Login</h1>
      <p>Coming soon...</p>
    </div>
  );
};