/* =========================================================
   DDL - FULL SCHEMA + TABLE + ROLE + PERMISSIONS
   ========================================================= */

/* =========================================================
   0. SCHEMA 생성
   ========================================================= */
CREATE SCHEMA IF NOT EXISTS iam;
CREATE SCHEMA IF NOT EXISTS finance;
CREATE SCHEMA IF NOT EXISTS audit;

/* =========================================================
   1. ROLE DEFINITIONS (NOLOGIN)
   ========================================================= */
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'iam_app_role') THEN
    CREATE ROLE iam_app_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_engine_role') THEN
    CREATE ROLE finance_engine_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'readonly_role') THEN
    CREATE ROLE readonly_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'db_admin_role') THEN
    CREATE ROLE db_admin_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ci_migrate_role') THEN
    CREATE ROLE ci_migrate_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'audit_relay_role') THEN
    CREATE ROLE audit_relay_role NOLOGIN;
  END IF;
END
$$;

/* =========================================================
   2. SCHEMA USAGE GRANT
   ========================================================= */
GRANT USAGE ON SCHEMA iam TO iam_app_role;
GRANT USAGE ON SCHEMA finance TO finance_engine_role;
GRANT USAGE ON SCHEMA iam, finance TO readonly_role;
GRANT USAGE ON SCHEMA iam, finance, audit TO db_admin_role;
GRANT USAGE ON SCHEMA iam, finance, audit TO ci_migrate_role;
GRANT USAGE ON SCHEMA audit TO audit_relay_role;

/* =========================================================
   3. TABLES 생성 (IF NOT EXISTS)
   ========================================================= */

-- IAM TABLES
CREATE TABLE IF NOT EXISTS iam.users (
    user_id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    status TEXT DEFAULT 'ACTIVE'
);

CREATE TABLE IF NOT EXISTS iam.credentials (
    credential_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES iam.users(user_id),
    password_hash TEXT NOT NULL,
    algorithm TEXT DEFAULT 'bcrypt'
);

CREATE TABLE IF NOT EXISTS iam.user_role (
    user_id INT REFERENCES iam.users(user_id),
    role_id INT NOT NULL,
    PRIMARY KEY (user_id, role_id)
);

-- FINANCE TABLES
CREATE TABLE IF NOT EXISTS finance.card_transactions_raw (
    tx_id SERIAL PRIMARY KEY,
    card_id INT NOT NULL,
    user_id INT,
    merchant TEXT,
    amount NUMERIC,
    currency TEXT,
    tx_date TIMESTAMP,
    raw_payload JSONB,
    allowed_roles TEXT[] DEFAULT ARRAY['finance_engine_role']
);

CREATE TABLE IF NOT EXISTS finance.violation_results (
    violation_id SERIAL PRIMARY KEY,
    tx_id INT REFERENCES finance.card_transactions_raw(tx_id),
    rule_id TEXT,
    status TEXT,
    reason TEXT,
    is_violation BOOLEAN DEFAULT TRUE,
    severity SMALLINT DEFAULT 0,
    allowed_roles TEXT[] DEFAULT ARRAY['finance_engine_role'],
    CONSTRAINT chk_finance_severity CHECK (severity BETWEEN 0 AND 4)
);

CREATE TABLE IF NOT EXISTS finance.usage_rules (
    rule_id SERIAL PRIMARY KEY,
    rule_name TEXT,
    description TEXT,
    allowed_roles TEXT[] DEFAULT ARRAY['finance_engine_role']
);

-- AUDIT TABLES
CREATE TABLE IF NOT EXISTS audit.audit_events (
    audit_id SERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    actor_id INT,
    actor_type TEXT,
    target_type TEXT,
    target_id INT,
    action TEXT,
    result TEXT,
    source_ip TEXT,
    is_violation BOOLEAN DEFAULT FALSE,
    severity SMALLINT DEFAULT 0,
    allowed_roles TEXT[] DEFAULT ARRAY['audit_relay_role'],
    CONSTRAINT chk_audit_severity CHECK (severity BETWEEN 0 AND 4)
);

/* =========================================================
   4. SAFE COLUMN MODIFICATIONS
   ========================================================= */
DO $$
BEGIN
  IF to_regclass('finance.card_transactions_raw') IS NOT NULL THEN
    ALTER TABLE finance.card_transactions_raw
      ADD COLUMN IF NOT EXISTS allowed_roles TEXT[] NOT NULL
      DEFAULT ARRAY['finance_engine_role'];
  END IF;

  IF to_regclass('finance.violation_results') IS NOT NULL THEN
    ALTER TABLE finance.violation_results
      ADD COLUMN IF NOT EXISTS allowed_roles TEXT[] NOT NULL
      DEFAULT ARRAY['finance_engine_role'],
      ADD COLUMN IF NOT EXISTS is_violation BOOLEAN NOT NULL DEFAULT TRUE,
      ADD COLUMN IF NOT EXISTS severity SMALLINT NOT NULL DEFAULT 0;
  END IF;

  IF to_regclass('audit.audit_events') IS NOT NULL THEN
    ALTER TABLE audit.audit_events
      ADD COLUMN IF NOT EXISTS allowed_roles TEXT[] NOT NULL
      DEFAULT ARRAY['audit_relay_role'],
      ADD COLUMN IF NOT EXISTS is_violation BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS severity SMALLINT NOT NULL DEFAULT 0;
  END IF;
END
$$;

/* =========================================================
   5. DOMAIN PERMISSIONS
   ========================================================= */
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA iam TO iam_app_role;
GRANT SELECT ON ALL TABLES IN SCHEMA iam, finance TO readonly_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA iam, finance TO db_admin_role;
GRANT CREATE ON SCHEMA iam, finance, audit TO ci_migrate_role;

DO $$
BEGIN
  IF to_regclass('audit.audit_events') IS NOT NULL THEN
    GRANT INSERT ON audit.audit_events TO iam_app_role, finance_engine_role;
    GRANT SELECT, UPDATE ON audit.audit_events TO db_admin_role, audit_relay_role;
    REVOKE INSERT, DELETE ON audit.audit_events FROM db_admin_role, audit_relay_role;
  END IF;

  IF to_regclass('finance.card_transactions_raw') IS NOT NULL THEN
    GRANT SELECT ON finance.card_transactions_raw TO finance_engine_role;
  END IF;

  IF to_regclass('finance.violation_results') IS NOT NULL THEN
    GRANT INSERT ON finance.violation_results TO finance_engine_role;
  END IF;
END
$$;

/* =========================================================
   6. DEFAULT PRIVILEGES
   ========================================================= */
ALTER DEFAULT PRIVILEGES FOR ROLE ci_migrate_role IN SCHEMA iam
  GRANT SELECT, INSERT, UPDATE ON TABLES TO iam_app_role;

ALTER DEFAULT PRIVILEGES FOR ROLE ci_migrate_role IN SCHEMA finance
  GRANT SELECT ON TABLES TO finance_engine_role;

ALTER DEFAULT PRIVILEGES FOR ROLE ci_migrate_role IN SCHEMA audit
  GRANT INSERT ON TABLES TO iam_app_role, finance_engine_role, db_admin_role;

/* =========================================================
   7. INDEX 생성
   ========================================================= */
DO $$
BEGIN
  IF to_regclass('finance.card_transactions_raw') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_finance_raw_allowed_roles
      ON finance.card_transactions_raw USING GIN (allowed_roles);
  END IF;

  IF to_regclass('finance.violation_results') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_finance_violation_allowed_roles
      ON finance.violation_results USING GIN (allowed_roles);
  END IF;

  IF to_regclass('audit.audit_events') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_audit_allowed_roles
      ON audit.audit_events USING GIN (allowed_roles);
  END IF;
END
$$;

/* =========================================================
   8. COMMENT 추가
   ========================================================= */
DO $$
BEGIN
  IF to_regclass('audit.audit_events') IS NOT NULL THEN
    COMMENT ON COLUMN audit.audit_events.is_violation
      IS '정책 판단 결과: true=위반, false=정상 (판단은 애플리케이션 책임)';
    COMMENT ON COLUMN audit.audit_events.severity
      IS '위반 심각도: 0=INFO, 1=LOW, 2=MEDIUM, 3=HIGH, 4=CRITICAL';
  END IF;
END
$$;

