-- Your SQL goes here
ALTER TABLE workspace_shared_user ADD COLUMN pending_invitation BOOLEAN NOT NULL DEFAULT FALSE;
