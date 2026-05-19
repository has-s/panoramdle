-- Migration: Add daily_submissions table for IP-based rate limiting
-- Date: 2026-05-19
-- Description: Track one submission per IP per day to prevent stat manipulation

BEGIN;

CREATE TABLE IF NOT EXISTS daily_submissions (
    id SERIAL PRIMARY KEY,
    challenge_date DATE NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    correct_count INTEGER NOT NULL,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT daily_submissions_ip_date_unique UNIQUE (challenge_date, ip_address)
);

CREATE INDEX IF NOT EXISTS idx_daily_submissions_date ON daily_submissions(challenge_date);
CREATE INDEX IF NOT EXISTS idx_daily_submissions_ip ON daily_submissions(ip_address);

COMMENT ON TABLE daily_submissions IS 'One record per IP per day — prevents duplicate stat submissions';

COMMIT;