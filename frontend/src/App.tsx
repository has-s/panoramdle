import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from '@/context/AuthContext';
import { PrivateRoute } from '@/components/PrivateRoute';

// Pages
import { DailyChallenge } from '@/pages/DailyChallenge/DailyChallenge';
import { ModerationLogin } from '@/pages/Moderation/ModerationLogin';
import { ModerationDashboard } from '@/pages/Moderation/ModerationDashboard';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public Routes */}
          <Route path="/" element={<DailyChallenge />} />

          {/* Moderation Routes */}
          <Route path="/moderation/login" element={<ModerationLogin />} />
          <Route
            path="/moderation"
            element={
              <PrivateRoute>
                <ModerationDashboard />
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