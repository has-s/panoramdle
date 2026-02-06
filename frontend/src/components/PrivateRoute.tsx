  import { Navigate } from 'react-router-dom';
import type { ReactNode } from 'react';
import { useAuth } from '@/context/AuthContext.tsx';

interface PrivateRouteProps {
  children: ReactNode;
}

export const PrivateRoute = ({ children }: PrivateRouteProps) => {
  const { moderator, loading } = useAuth();

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        minHeight: '100vh',
        fontSize: '20px',
        color: 'var(--color-text-sub)'
      }}>
        Загрузка...
      </div>
    );
  }

  if (!moderator) {
    return <Navigate to="/moderation/login" replace />;
  }

  return <>{children}</>;
};