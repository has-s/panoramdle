-- Migration: Add status field to moderators table
-- Date: 2025-03-02
-- Description: Replace is_active boolean with status enum (active/inactive/deleted)

BEGIN;

ALTER TABLE moderators ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

UPDATE moderators
SET status = CASE
    WHEN is_active = true THEN 'active'
    WHEN is_active = false THEN 'inactive'
    ELSE 'active'
END
WHERE status IS NULL OR status = '';

CREATE INDEX IF NOT EXISTS idx_moderators_status ON moderators(status);

-- (Optional) Drop old column after verification
-- ALTER TABLE moderators DROP COLUMN is_active;

COMMIT;

SELECT
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE status = 'active') as active,
    COUNT(*) FILTER (WHERE status = 'inactive') as inactive,
    COUNT(*) FILTER (WHERE status = 'deleted') as deleted
FROM moderators;