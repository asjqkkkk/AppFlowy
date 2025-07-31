-- Your SQL goes here
CREATE TABLE user_recent_view
(
    view_id      TEXT      NOT NULL,
    view_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    uid          BigInt    NOT NULL,
    workspace_id TEXT      NOT NULL,
    PRIMARY KEY (uid, workspace_id, view_id)
);

-- Create an index on uid, workspace_id and view_at for efficient queries
CREATE INDEX idx_user_recent_view_uid_workspace_view_at ON user_recent_view (uid, workspace_id, view_at DESC);


ALTER TABLE user_workspace_table ADD COLUMN updated_at BIGINT NOT NULL DEFAULT 0;
UPDATE user_workspace_table SET updated_at = created_at WHERE updated_at = 0; 