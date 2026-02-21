import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from '@/context/AuthContext';
import { PrivateRoute } from '@/components/PrivateRoute';

// Pages
import { DailyChallenge } from '@/pages/DailyChallenge/DailyChallenge';
import { ModerationLogin } from '@/pages/Moderation/ModerationLogin';
import { ModerationDashboard } from '@/pages/Moderation/ModerationDashboard';
import { NewsCreate } from '@/pages/News/NewsCreate';
import { NewsList } from '@/pages/News/NewsList';
import { NewsEdit } from '@/pages/News/NewsEdit';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public Routes */}
          <Route path="/" element={<DailyChallenge />} />

          {/* Auth */}
          <Route path="/login" element={<ModerationLogin />} />

          {/* Moderation */}
          <Route
            path="/moderation"
            element={
              <PrivateRoute>
                <ModerationDashboard />
              </PrivateRoute>
            }
          />

          {/* News CRUD */}
          <Route
            path="/news/create"
            element={
              <PrivateRoute>
                <NewsCreate />
              </PrivateRoute>
            }
          />
          <Route
            path="/news/list"
            element={
              <PrivateRoute>
                <NewsList />
              </PrivateRoute>
            }
          />
          <Route
            path="/news/edit/:id"
            element={
              <PrivateRoute>
                <NewsEdit />
              </PrivateRoute>
            }
          />

          {/* Fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;