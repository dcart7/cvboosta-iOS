-- 06. CVBoosta PostgreSQL Schema (MVP)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  apple_sub VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255),
  display_name VARCHAR(120),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resumes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  file_name VARCHAR(255) NOT NULL,
  text_content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resume_scans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  resume_id UUID NOT NULL REFERENCES resumes(id),
  target_role VARCHAR(100) NOT NULL,
  ats_score INTEGER NOT NULL,
  keyword_coverage DOUBLE PRECISION NOT NULL,
  measurable_impact_ratio DOUBLE PRECISION NOT NULL,
  readability_score DOUBLE PRECISION NOT NULL,
  recruiter_signal_score DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scan_findings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_id UUID NOT NULL REFERENCES resume_scans(id),
  category VARCHAR(64) NOT NULL,
  severity INTEGER NOT NULL,
  message TEXT NOT NULL,
  suggestion TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS applications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  company VARCHAR(120) NOT NULL,
  role VARCHAR(120) NOT NULL,
  status VARCHAR(32) NOT NULL,
  source VARCHAR(64),
  salary_band VARCHAR(64),
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  interview_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  entitlement VARCHAR(64) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ,
  source VARCHAR(32) NOT NULL DEFAULT 'app_store'
);

CREATE TABLE IF NOT EXISTS role_keyword_sets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role VARCHAR(120) UNIQUE NOT NULL,
  keywords JSONB NOT NULL,
  expectations JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_resumes_user_id ON resumes(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_resume_id ON resume_scans(resume_id);
CREATE INDEX IF NOT EXISTS idx_applications_user_id ON applications(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_role_keyword_sets_role ON role_keyword_sets(role);
