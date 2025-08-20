ALTER TABLE workspace_members_table
ADD COLUMN is_pending_invitation BOOLEAN NOT NULL DEFAULT FALSE;
