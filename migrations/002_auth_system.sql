-- migrations/002_auth_system.sql

CREATE TABLE IF NOT EXISTS moderators (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email VARCHAR(100),
    role VARCHAR(20) DEFAULT 'moderator' CHECK (role IN ('admin', 'moderator')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    created_by INTEGER REFERENCES moderators(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_moderators_username ON moderators(username);
CREATE INDEX IF NOT EXISTS idx_moderators_is_active ON moderators(is_active);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    moderator_id INTEGER NOT NULL REFERENCES moderators(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_sessions_moderator_id ON sessions(moderator_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    moderator_id INTEGER REFERENCES moderators(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    target_type VARCHAR(50),
    target_id TEXT,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_log_moderator_id ON audit_log(moderator_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);

CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM sessions WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;