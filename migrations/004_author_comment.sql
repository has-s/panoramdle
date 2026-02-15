-- migrations/003_author_comment.sql
-- Date: 2026-02-15

ALTER TABLE news
ADD COLUMN author_comment TEXT;

COMMENT ON COLUMN news.author_comment IS 'Optional comment from moderator explaining news origin or context';