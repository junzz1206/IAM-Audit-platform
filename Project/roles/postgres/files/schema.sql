/* =========================================================
   schema.sql
   목적:
   - DB 스키마 및 핵심 테이블 정의
   - "존재 보장" 책임만 가짐
   - 구조 변경 / 권한 / 데이터는 다루지 않음
   ========================================================= */

-- =========================================================
-- 0. SCHEMA DEFINITIONS
-- =========================================================

CREATE SCHEMA IF NOT EXISTS iam;
CREATE SCHEMA IF NOT EXISTS finance;
CREATE SCHEMA IF NOT EXISTS audit;

-- =========================================================
-- 1. IAM DOMAIN TABLES
-- =========================================================

CREATE TABLE IF NOT EXISTS iam.users (
  user_id        BIGSERIAL PRIMARY KEY,
  username       TEXT NOT NULL UNIQUE,
  status         TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- 2. FINANCE DOMAIN TABLES
-- =========================================================

-- 카드 원천 거래 데이터 (불변 성격)
CREATE TABLE IF NOT EXISTS finance.card_transactions_raw (
  tx_id          BIGSERIAL PRIMARY KEY,
  card_no        TEXT NOT NULL,
  amount         NUMERIC(15,2) NOT NULL,
  currency       CHAR(3) NOT NULL DEFAULT 'KRW',
  occurred_at    TIMESTAMPTZ NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 사용/검증 규칙 정의
CREATE TABLE IF NOT EXISTS finance.usage_rules (
  rule_id        BIGSERIAL PRIMARY KEY,
  rule_name      TEXT NOT NULL,
  rule_expr      TEXT NOT NULL,
  enabled        BOOLEAN NOT NULL DEFAULT true,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 규칙 위반 결과 (엔진 출력)
CREATE TABLE IF NOT EXISTS finance.violation_results (
  violation_id   BIGSERIAL PRIMARY KEY,
  tx_id          BIGINT NOT NULL,
  rule_id        BIGINT NOT NULL,
  evaluated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- 3. AUDIT DOMAIN TABLES
-- =========================================================

-- 모든 서비스 공통 감사 로그
CREATE TABLE IF NOT EXISTS audit.audit_events (
  audit_id       BIGSERIAL PRIMARY KEY,
  source         TEXT NOT NULL,
  event_type     TEXT NOT NULL,
  event_payload  JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

