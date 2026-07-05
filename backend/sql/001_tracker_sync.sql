CREATE TABLE IF NOT EXISTS tracker_folders (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(120) NOT NULL,
  emoji VARCHAR(16) NOT NULL DEFAULT '🗂',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE applications
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS resume_used VARCHAR(255),
  ADD COLUMN IF NOT EXISTS job_link TEXT,
  ADD COLUMN IF NOT EXISTS folder_id UUID REFERENCES tracker_folders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ats_score INTEGER,
  ADD COLUMN IF NOT EXISTS interview_reflection_rating INTEGER,
  ADD COLUMN IF NOT EXISTS interview_reflection_outcome VARCHAR(64),
  ADD COLUMN IF NOT EXISTS interview_reflection_notes TEXT,
  ADD COLUMN IF NOT EXISTS interview_reflection_submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_tracker_folders_user_id ON tracker_folders(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_folder_id ON applications(folder_id);
