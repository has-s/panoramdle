-- migrations/003_daily_challenge.sql

CREATE TABLE IF NOT EXISTS daily_challenge (
    id SERIAL PRIMARY KEY,
    challenge_date DATE NOT NULL UNIQUE,
    news_snapshot JSONB NOT NULL,
    total_attempts INTEGER DEFAULT 0,
    total_correct INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES moderators(id),
    is_custom BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_daily_challenge_date ON daily_challenge(challenge_date);
CREATE INDEX IF NOT EXISTS idx_daily_challenge_created_at ON daily_challenge(created_at);

COMMENT ON TABLE daily_challenge IS 'Daily challenge snapshots - 10 news per day with completion statistics';
COMMENT ON COLUMN daily_challenge.news_snapshot IS 'JSON array of 10 news objects';
COMMENT ON COLUMN daily_challenge.total_attempts IS 'Total number of completions (no user data stored)';
COMMENT ON COLUMN daily_challenge.total_correct IS 'Sum of all correct answers across all attempts';
COMMENT ON COLUMN daily_challenge.is_custom IS 'True for manually created special day challenges';