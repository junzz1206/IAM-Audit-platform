/* =========================================================
   목적:
   - 권한 묶음은 NOLOGIN ROLE
   - LOGIN USER는 ROLE만 부여
   - 테이블 없어도 실패하지 않음
   ========================================================= */

-- =========================================================
-- 1. ROLE DEFINITIONS (NOLOGIN)
-- =========================================================

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
END
$$;

-- =========================================================
-- 2. LOGIN USER DEFINITIONS
-- =========================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'iam_app_user') THEN
    CREATE ROLE iam_app_user LOGIN PASSWORD 'CHANGE_ME';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ci_migrate_user') THEN
    CREATE ROLE ci_migrate_user LOGIN PASSWORD 'CHANGE_ME';
  END IF;
END
$$;

-- USER ↔ ROLE 매핑
GRANT iam_app_role TO iam_app_user;
GRANT ci_migrate_role TO ci_migrate_user;

-- =========================================================
-- 3. SCHEMA USAGE
-- =========================================================

GRANT USAGE ON SCHEMA iam TO iam_app_role;
GRANT USAGE ON SCHEMA finance TO finance_engine_role;
GRANT USAGE ON SCHEMA iam, finance TO readonly_role;
GRANT USAGE ON SCHEMA iam, finance, audit TO db_admin_role;
GRANT USAGE ON SCHEMA iam, finance, audit TO ci_migrate_role;

-- =========================================================
-- 4. DOMAIN PERMISSIONS (SAFE)
-- =========================================================

GRANT SELECT, INSERT, UPDATE
ON ALL TABLES IN SCHEMA iam
TO iam_app_role;

GRANT SELECT
ON ALL TABLES IN SCHEMA iam, finance
TO readonly_role;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA iam, finance
TO db_admin_role;

-- =========================================================
-- 5. TABLE-LEVEL PERMISSIONS (존재할 때만)
-- =========================================================

DO $$
BEGIN
  IF to_regclass('audit.audit_events') IS NOT NULL THEN
    GRANT INSERT ON audit.audit_events TO iam_app_role, finance_engine_role;
    GRANT INSERT ON audit.audit_events TO db_admin_role;
    REVOKE UPDATE, DELETE ON audit.audit_events FROM db_admin_role;
  END IF;

  IF to_regclass('finance.card_transactions_raw') IS NOT NULL THEN
    GRANT SELECT ON finance.card_transactions_raw TO finance_engine_role;
  END IF;

  IF to_regclass('finance.usage_rules') IS NOT NULL THEN
    GRANT SELECT ON finance.usage_rules TO finance_engine_role;
  END IF;

  IF to_regclass('finance.violation_results') IS NOT NULL THEN
    GRANT INSERT ON finance.violation_results TO finance_engine_role;
  END IF;
END
$$;

-- =========================================================
-- 6. CI MIGRATION ROLE
-- =========================================================

GRANT CREATE
ON SCHEMA iam, finance, audit
TO ci_migrate_role;

-- =========================================================
-- 7. DEFAULT PRIVILEGES (핵심)
-- =========================================================

ALTER DEFAULT PRIVILEGES
FOR ROLE ci_migrate_role IN SCHEMA iam
GRANT SELECT, INSERT, UPDATE ON TABLES TO iam_app_role;

ALTER DEFAULT PRIVILEGES
FOR ROLE ci_migrate_role IN SCHEMA finance
GRANT SELECT ON TABLES TO finance_engine_role;

ALTER DEFAULT PRIVILEGES
FOR ROLE ci_migrate_role IN SCHEMA audit
GRANT INSERT ON TABLES TO iam_app_role, finance_engine_role, db_admin_role;

