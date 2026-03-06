-- Migration: Add created_by and edit_history to news table
-- Date: 2025-03-06
-- Description: Track news creator and edit history with SYSTEM user

BEGIN;

-- Shift existing IDs if there's a user with id=0
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM moderators WHERE id = 0) THEN
        ALTER SEQUENCE moderators_id_seq RESTART WITH 1;
        UPDATE moderators SET id = id + 1;
        UPDATE audit_log SET moderator_id = moderator_id + 1 WHERE moderator_id IS NOT NULL;
        UPDATE sessions SET moderator_id = moderator_id + 1;
    END IF;
END $$;

-- Create SYSTEM user with id=0
INSERT INTO moderators (id, username, password_hash, email, role, status, created_at)
VALUES (0, 'SYSTEM', 'N/A', NULL, 'system', 'active', CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

-- Add columns to news table
ALTER TABLE news ADD COLUMN IF NOT EXISTS created_by INTEGER REFERENCES moderators(id);
ALTER TABLE news ADD COLUMN IF NOT EXISTS edit_history JSONB DEFAULT '[]'::jsonb;

-- Populate created_by for existing news
UPDATE news SET created_by = 0 WHERE created_by IS NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_news_created_by ON news(created_by);

COMMIT;

SELECT
    COUNT(*) as total_news,
    COUNT(*) FILTER (WHERE created_by = 0) as system_created,
    COUNT(*) FILTER (WHERE created_by > 0) as user_created
FROM news;