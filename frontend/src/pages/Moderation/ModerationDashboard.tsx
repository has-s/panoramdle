import { useEffect } from 'react';

export const ModerationDashboard = () => {
  useEffect(() => {
    document.title = 'Панель модерации';
  }, []);

  return (
    <div style={{ padding: '40px', textAlign: 'center' }}>
      <h1>Moderation Dashboard</h1>
      <p>Coming soon...</p>
    </div>
  );
};