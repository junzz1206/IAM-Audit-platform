/* =========================================================
   DML - APPLICATION DATA OPERATIONS
   =========================================================
   목적:
   - 애플리케이션에서 사용하는 실제 데이터 변경 쿼리
   - allowed_roles 기반 접근 제어 전제
   - 모든 중요 행위는 audit 로그를 반드시 남김
   - 판단 결과(is_violation, severity)는 "사실"로 저장
   ========================================================= */


-- =========================================================
-- IAM - USER CREATE
-- =========================================================

BEGIN;

INSERT INTO iam.users (
    user_id,
    username,
    email,
    status
) VALUES (
    :user_id,
    :username,
    :email,
    'ACTIVE'
);

INSERT INTO iam.credentials (
    credential_id,
    user_id,
    password_hash,
    algorithm
) VALUES (
    :cred_id,
    :user_id,
    :password_hash,
    'bcrypt'
);

INSERT INTO iam.user_role (
    user_id,
    role_id
) VALUES (
    :user_id,
    :role_id
);

INSERT INTO audit.audit_events (
    audit_id,
    event_type,
    actor_id,
    actor_type,
    target_type,
    target_id,
    action,
    result,
    is_violation,
    severity,
    allowed_roles
) VALUES (
    :audit_id,
    'USER_CREATE',
    :actor_id,
    'USER',
    'USER',
    :user_id,
    'CREATE',
    'SUCCESS',
    false,              -- 정상 행위
    0,                  -- INFO
    ARRAY['admin']
);

COMMIT;


-- =========================================================
-- IAM - USER STATUS CHANGE
-- =========================================================

BEGIN;

WITH updated_user AS (
    UPDATE iam.users
    SET status = :new_status
    WHERE user_id = :user_id
    RETURNING user_id
)
INSERT INTO audit.audit_events (
    audit_id,
    event_type,
    actor_id,
    actor_type,
    target_type,
    target_id,
    action,
    result,
    is_violation,
    severity,
    allowed_roles
)
SELECT
    :audit_id,
    'USER_STATUS_CHANGE',
    :actor_id,
    'USER',
    'USER',
    user_id,
    'UPDATE',
    'SUCCESS',
    false,              -- 정상 관리 행위
    0,                  -- INFO
    ARRAY['admin']
FROM updated_user;

COMMIT;


-- =========================================================
-- FINANCE - RAW TRANSACTION INGEST
-- =========================================================

INSERT INTO finance.card_transactions_raw (
    tx_id,
    card_id,
    user_id,
    merchant,
    amount,
    currency,
    tx_date,
    raw_payload,
    allowed_roles
) VALUES (
    :tx_id,
    :card_id,
    :user_id,
    :merchant,
    :amount,
    :currency,
    :tx_date,
    :raw_payload,
    ARRAY[
        'finance_engine',
        'auditor'
    ]
);


-- =========================================================
-- FINANCE - RULE VALIDATION RESULT
-- =========================================================

BEGIN;

INSERT INTO finance.violation_results (
    violation_id,
    tx_id,
    rule_id,
    status,
    reason,
    is_violation,
    severity,
    allowed_roles
) VALUES (
    :violation_id,
    :tx_id,
    :rule_id,
    'FAIL',
    'Amount exceeds limit',
    true,               -- 규칙 위반
    :severity,          -- 애플리케이션이 판단한 등급 (예: 3)
    ARRAY[
        'finance_engine',
        'auditor'
    ]
);

INSERT INTO audit.audit_events (
    audit_id,
    event_type,
    actor_id,
    actor_type,
    target_type,
    target_id,
    action,
    result,
    is_violation,
    severity,
    allowed_roles
) VALUES (
    :audit_id,
    'TX_VALIDATE',
    NULL,
    'SYSTEM',
    'TRANSACTION',
    :tx_id,
    'CREATE',
    'FAIL',
    true,               -- 위반 이벤트
    :severity,          -- 동일한 severity 사용
    ARRAY[
        'auditor',
        'admin'
    ]
);

COMMIT;


-- =========================================================
-- AUDIT - LOGIN EVENT
-- =========================================================

INSERT INTO audit.audit_events (
    audit_id,
    event_type,
    actor_id,
    actor_type,
    action,
    result,
    source_ip,
    is_violation,
    severity,
    allowed_roles
) VALUES (
    :audit_id,
    'LOGIN',
    :user_id,
    'USER',
    'AUTH',
    'SUCCESS',
    :source_ip,
    false,              -- 정상 로그인
    0,                  -- INFO
    ARRAY[
        'auditor',
        'admin'
    ]
);

