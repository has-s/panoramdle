-- Migration: Add system role to moderators
-- Date: 2025-03-06
-- Description: Allow 'system' role for SYSTEM user

BEGIN;

-- Drop existing constraint
ALTER TABLE moderators DROP CONSTRAINT moderators_role_check;

-- Add new constraint with 'system' role
ALTER TABLE moderators ADD CONSTRAINT moderators_role_check
    CHECK (role IN ('moderator', 'admin', 'system'));

COMMIT;