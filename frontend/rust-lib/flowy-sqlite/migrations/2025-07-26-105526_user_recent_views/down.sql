-- This file should undo anything in `up.sql`
DROP INDEX IF EXISTS idx_user_recent_view_uid_view_at;
DROP TABLE IF EXISTS user_recent_view;

ALTER TABLE user_workspace_table DROP COLUMN updated_at; 