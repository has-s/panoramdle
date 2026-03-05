import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi } from '@/services/api';
import './ModerationDashboard.css';

interface User {
  id: number;
  username: string;
  email: string;
  role: string;
  status: string;  // Изменено с is_active
  last_login: string | null;
  created_at: string;
}

interface CurrentUser {
  id: number;
  username: string;
  email: string;
  role: string;
}

export const ModerationDashboard = () => {
  const navigate = useNavigate();
  const [currentUser, setCurrentUser] = useState<CurrentUser | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);

  // Modals
  const [showChangePassword, setShowChangePassword] = useState(false);
  const [showChangeEmail, setShowChangeEmail] = useState(false);
  const [showCreateUser, setShowCreateUser] = useState(false);
  const [showResetPassword, setShowResetPassword] = useState(false);
  const [showConflictModal, setShowConflictModal] = useState(false);
  const [resetUserId, setResetUserId] = useState<number | null>(null);
  const [resetUsername, setResetUsername] = useState('');
  const [conflictData, setConflictData] = useState<any>(null);
  const [createUserData, setCreateUserData] = useState({
    username: '',
    password: '',
    email: '',
    role: 'moderator',
  });

  useEffect(() => {
    init();
  }, []);

  const init = async () => {
    try {
      const response = await fetch('/api/users/me');
      const user = await response.json();
      setCurrentUser(user);

      if (user.role === 'admin') {
        await loadUsers();
      }
    } catch (error) {
      navigate('/login');
    } finally {
      setLoading(false);
    }
  };

  const loadUsers = async () => {
    try {
      const response = await fetch('/api/users/list');
      const data = await response.json();
      setUsers(data);
    } catch (error) {
      showMessage('Ошибка загрузки пользователей', 'error');
    }
  };

  const showMessage = (text: string, type: 'success' | 'error' = 'success') => {
    setMessage({ text, type });
    setTimeout(() => setMessage(null), 5000);
  };

  const handleLogout = async () => {
    try {
      await authApi.logout();
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  const handleChangePassword = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    if (formData.get('new_password') !== formData.get('new_password_confirm')) {
      showMessage('Пароли не совпадают', 'error');
      return;
    }

    try {
      const response = await fetch('/api/users/change-password', {
        method: 'POST',
        body: formData,
      });
      const data = await response.json();

      if (data.ok) {
        showMessage('Пароль успешно изменён');
        setShowChangePassword(false);
      } else {
        showMessage(data.error || 'Ошибка', 'error');
      }
    } catch (error) {
      showMessage('Ошибка сервера', 'error');
    }
  };

  const handleChangeEmail = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    try {
      const response = await fetch('/api/users/update-email', {
        method: 'POST',
        body: formData,
      });
      const data = await response.json();

      if (data.ok) {
        showMessage('Email успешно изменён');
        setShowChangeEmail(false);
        if (currentUser) {
          setCurrentUser({ ...currentUser, email: formData.get('email') as string });
        }
      } else {
        showMessage(data.error || 'Ошибка', 'error');
      }
    } catch (error) {
      showMessage('Ошибка сервера', 'error');
    }
  };

  const handleCreateUser = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    // Сохраняем данные для возможного conflict resolution
    setCreateUserData({
      username: formData.get('username') as string,
      password: formData.get('password') as string,
      email: formData.get('email') as string,
      role: formData.get('role') as string,
    });

    formData.append('force_overwrite', 'false');

    try {
      const response = await fetch('/api/users/create', {
        method: 'POST',
        body: formData,
      });
      const data = await response.json();

      // Проверяем конфликт с удалённым пользователем
      if (data.conflict) {
        setConflictData(data.deleted_user);
        setShowConflictModal(true);
        return;
      }

      if (data.ok) {
        showMessage('Модератор создан');
        setShowCreateUser(false);
        await loadUsers();
      } else {
        showMessage(data.error || 'Ошибка', 'error');
      }
    } catch (error) {
      showMessage('Ошибка сервера', 'error');
    }
  };

  const handleResolveConflict = async (action: 'restore' | 'overwrite') => {
    if (action === 'restore') {
      // Восстанавливаем старого пользователя
      const formData = new FormData();
      formData.append('new_password', createUserData.password);

      try {
        const response = await fetch(`/api/users/${conflictData.id}/restore`, {
          method: 'POST',
          body: formData,
        });

        if (response.ok) {
          showMessage('Пользователь восстановлен');
          setConflictData(null);
          setShowConflictModal(false);
          setShowCreateUser(false);
          await loadUsers();
        } else {
          showMessage('Ошибка восстановления', 'error');
        }
      } catch (error) {
        showMessage('Ошибка сервера', 'error');
      }
    } else {
      // Перезаписываем (создаём нового, старого переименовываем)
      const formData = new FormData();
      formData.append('username', createUserData.username);
      formData.append('password', createUserData.password);
      formData.append('email', createUserData.email);
      formData.append('role', createUserData.role);
      formData.append('force_overwrite', 'true');

      try {
        const response = await fetch('/api/users/create', {
          method: 'POST',
          body: formData,
        });

        if (response.ok) {
          showMessage('Новый пользователь создан');
          setConflictData(null);
          setShowConflictModal(false);
          setShowCreateUser(false);
          await loadUsers();
        } else {
          showMessage('Ошибка создания', 'error');
        }
      } catch (error) {
        showMessage('Ошибка сервера', 'error');
      }
    }
  };

  const handleResetPassword = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    if (formData.get('new_password') !== formData.get('new_password_confirm')) {
      showMessage('Пароли не совпадают', 'error');
      return;
    }

    try {
      const response = await fetch(`/api/users/${resetUserId}/reset-password`, {
        method: 'POST',
        body: formData,
      });
      const data = await response.json();

      if (data.ok) {
        showMessage('Пароль успешно сброшен');
        setShowResetPassword(false);
      } else {
        showMessage(data.error || 'Ошибка', 'error');
      }
    } catch (error) {
      showMessage('Ошибка сервера', 'error');
    }
  };

  const handleToggleStatus = async (userId: number, currentStatus: string) => {
    const endpoint = currentStatus === 'active' ? 'deactivate' : 'activate';

    try {
      const response = await fetch(`/api/users/${userId}/${endpoint}`, { method: 'POST' });
      const data = await response.json();

      if (data.ok) {
        showMessage(`Пользователь ${currentStatus === 'active' ? 'деактивирован' : 'активирован'}`);
        await loadUsers();
      } else {
        showMessage(data.error || 'Ошибка', 'error');
      }
    } catch (error) {
      showMessage('Ошибка сервера', 'error');
    }
  };

  const handleDelete = async (userId: number, username: string) => {
    if (!confirm(`Удалить пользователя ${username}?`)) return;

    try {
      const response = await fetch(`/api/users/${userId}`, { method: 'DELETE' });
      const data = await response.json();

      if (data.ok) {
        showMessage('Пользователь удалён');
        await loadUsers();
      } else {
        showMessage(data.error || 'Ошибка', 'error');
      }
    } catch (error) {
      showMessage('Ошибка сервера', 'error');
    }
  };

  if (loading) {
    return <div>Загрузка...</div>;
  }

  if (!currentUser) {
    return null;
  }

  return (
    <div className="dashboard-page">
      <div className="dashboard-header">
        <h1>Панель модерации</h1>
        <div className="dashboard-header-actions">
          <span className="user-info">
            {currentUser.username} ({currentUser.role})
          </span>
          <button className="logout-btn" onClick={handleLogout}>
            Выйти
          </button>
        </div>
      </div>

      <div className="dashboard-nav">
        <button onClick={() => navigate('/news/list')}>Управление новостями</button>
        <button onClick={() => navigate('/')}>Квиз</button>
      </div>

      {message && (
        <div className={`message message-${message.type}`}>
          {message.text}
        </div>
      )}

      {/* My Profile */}
      <div className="dashboard-section">
        <h2>Мой профиль</h2>
        <p><strong>Username:</strong> {currentUser.username}</p>
        <p><strong>Email:</strong> {currentUser.email || 'Не указан'}</p>
        <p><strong>Роль:</strong> {currentUser.role}</p>

        <button className="btn-primary" onClick={() => setShowChangePassword(true)}>
          Изменить пароль
        </button>
        <button className="btn-secondary" onClick={() => setShowChangeEmail(true)}>
          Изменить email
        </button>
      </div>

      {/* Users List (Admin only) */}
      {currentUser.role === 'admin' && (
        <div className="dashboard-section">
          <h2>Все модераторы</h2>
          <button className="btn-success" onClick={() => setShowCreateUser(true)}>
            + Создать модератора
          </button>

          <table className="users-table">
            <thead>
              <tr>
                <th>Username</th>
                <th>Email</th>
                <th>Роль</th>
                <th>Статус</th>
                <th>Последний вход</th>
                <th>Действия</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.username}</td>
                  <td>{user.email || '—'}</td>
                  <td>
                    <span className={`badge badge-${user.role}`}>
                      {user.role}
                    </span>
                  </td>
                  <td>
                    <span className={`badge badge-${user.status}`}>
                      {user.status.toUpperCase()}
                    </span>
                  </td>
                  <td>
                    {user.last_login
                      ? new Date(user.last_login).toLocaleString('ru-RU')
                      : 'Никогда'}
                  </td>
                  <td>
                    {user.id !== currentUser.id ? (
                      <div className="actions-cell">
                        <button
                          className="btn-secondary"
                          onClick={() => {
                            setResetUserId(user.id);
                            setResetUsername(user.username);
                            setShowResetPassword(true);
                          }}
                        >
                          Сбросить пароль
                        </button>
                        <button
                          className="btn-secondary"
                          onClick={() => handleToggleStatus(user.id, user.status)}
                          disabled={user.status === 'deleted'}
                        >
                          {user.status === 'active' ? 'Деактивировать' : 'Активировать'}
                        </button>
                        <button
                          className="btn-danger"
                          onClick={() => handleDelete(user.id, user.username)}
                        >
                          Удалить
                        </button>
                      </div>
                    ) : (
                      <em>Это вы</em>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Change Password Modal */}
      {showChangePassword && (
        <div className="modal" onClick={() => setShowChangePassword(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>Изменить пароль</h3>
            <form onSubmit={handleChangePassword}>
              <div className="form-group">
                <label>Старый пароль:</label>
                <input type="password" name="old_password" required />
              </div>
              <div className="form-group">
                <label>Новый пароль:</label>
                <input type="password" name="new_password" required />
              </div>
              <div className="form-group">
                <label>Повторите новый пароль:</label>
                <input type="password" name="new_password_confirm" required />
              </div>
              <button type="submit" className="btn-primary">
                Сохранить
              </button>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setShowChangePassword(false)}
              >
                Отмена
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Change Email Modal */}
      {showChangeEmail && (
        <div className="modal" onClick={() => setShowChangeEmail(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>Изменить email</h3>
            <form onSubmit={handleChangeEmail}>
              <div className="form-group">
                <label>Новый email:</label>
                <input type="email" name="email" defaultValue={currentUser.email} />
              </div>
              <button type="submit" className="btn-primary">
                Сохранить
              </button>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setShowChangeEmail(false)}
              >
                Отмена
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Create User Modal */}
      {showCreateUser && (
        <div className="modal" onClick={() => setShowCreateUser(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>Создать модератора</h3>
            <form onSubmit={handleCreateUser}>
              <div className="form-group">
                <label>Username:</label>
                <input type="text" name="username" required />
              </div>
              <div className="form-group">
                <label>Пароль:</label>
                <input type="password" name="password" required />
              </div>
              <div className="form-group">
                <label>Email:</label>
                <input type="email" name="email" />
              </div>
              <div className="form-group">
                <label>Роль:</label>
                <select name="role">
                  <option value="moderator">Moderator</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              <button type="submit" className="btn-success">
                Создать
              </button>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setShowCreateUser(false)}
              >
                Отмена
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Reset Password Modal */}
      {showResetPassword && (
        <div className="modal" onClick={() => setShowResetPassword(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>Сбросить пароль</h3>
            <p>
              Username: <strong>{resetUsername}</strong>
            </p>
            <form onSubmit={handleResetPassword}>
              <div className="form-group">
                <label>Новый пароль:</label>
                <input type="password" name="new_password" required />
              </div>
              <div className="form-group">
                <label>Повторите пароль:</label>
                <input type="password" name="new_password_confirm" required />
              </div>
              <button type="submit" className="btn-primary">
                Сбросить
              </button>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setShowResetPassword(false)}
              >
                Отмена
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Conflict Resolution Modal */}
      {showConflictModal && conflictData && (
        <div className="modal" onClick={() => setShowConflictModal(false)}>
          <div className="modal-content conflict-modal" onClick={(e) => e.stopPropagation()}>
            <h3>⚠️ Обнаружен конфликт</h3>
            <p>
              Найден удалённый пользователь с именем <strong>{createUserData.username}</strong>
            </p>
            <div className="conflict-details">
              <p><strong>Email:</strong> {conflictData.email || 'Не указан'}</p>
              <p><strong>Роль:</strong> {conflictData.role}</p>
              <p><strong>Создан:</strong> {new Date(conflictData.created_at).toLocaleDateString('ru-RU')}</p>
            </div>

            <p className="conflict-question">Выберите действие:</p>

            <div className="conflict-actions">
              <button
                className="btn-primary"
                onClick={() => handleResolveConflict('restore')}
              >
                Восстановить запись
              </button>
              <button
                className="btn-danger"
                onClick={() => handleResolveConflict('overwrite')}
              >
                Создать нового и перезаписать
              </button>
              <button
                className="btn-secondary"
                onClick={() => {
                  setShowConflictModal(false);
                  setConflictData(null);
                }}
              >
                Отмена
              </button>
            </div>

            <div className="conflict-warning">
              ⚠️ <strong>Перезапись</strong> переименует старого пользователя на "{createUserData.username}_[timestamp]"
            </div>
          </div>
        </div>
      )}
    </div>
  );
};