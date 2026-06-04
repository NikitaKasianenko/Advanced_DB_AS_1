DROP TABLE IF EXISTS audit_log                  CASCADE;
DROP TABLE IF EXISTS fraud_alerts               CASCADE;
DROP TABLE IF EXISTS transaction_status_history CASCADE;
DROP TABLE IF EXISTS transactions               CASCADE;
DROP TABLE IF EXISTS cards                      CASCADE;
DROP TABLE IF EXISTS accounts                   CASCADE;
DROP TABLE IF EXISTS fraud_rules                CASCADE;
DROP TABLE IF EXISTS customers                  CASCADE;


CREATE TABLE customers (
    customer_id  BIGSERIAL    PRIMARY KEY,
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(255) NOT NULL UNIQUE,
    birth_date   DATE         NOT NULL,
    country_code CHAR(2)      NOT NULL,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_customer_email
        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_customer_birth_date
        CHECK (birth_date < CURRENT_DATE)
);


CREATE TABLE accounts (
    account_id     BIGSERIAL      PRIMARY KEY,
    customer_id    BIGINT         NOT NULL REFERENCES customers(customer_id),
    account_number VARCHAR(29)    NOT NULL UNIQUE,
    currency       CHAR(3)        NOT NULL DEFAULT 'UAH',
    balance        DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    status         VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE',
    opened_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_account_balance   CHECK (balance >= 0),
    CONSTRAINT chk_account_currency  CHECK (currency IN ('UAH', 'USD', 'EUR')),
    CONSTRAINT chk_account_status    CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED'))
);


CREATE TABLE cards (
    card_id          BIGSERIAL   PRIMARY KEY,
    account_id       BIGINT      NOT NULL REFERENCES accounts(account_id),
    card_number_hash VARCHAR(64) NOT NULL UNIQUE,
    card_type        VARCHAR(20) NOT NULL DEFAULT 'DEBIT',
    status           VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    expiration_date  DATE        NOT NULL,

    CONSTRAINT chk_card_type   CHECK (card_type IN ('DEBIT', 'CREDIT', 'PREPAID')),
    CONSTRAINT chk_card_status CHECK (status IN ('ACTIVE', 'BLOCKED', 'EXPIRED'))
);


CREATE TABLE transactions (
    transaction_id    BIGSERIAL      PRIMARY KEY,
    account_id        BIGINT         NOT NULL REFERENCES accounts(account_id),
    card_id           BIGINT         REFERENCES cards(card_id) ON DELETE SET NULL,
    amount            DECIMAL(15, 2) NOT NULL,
    currency          CHAR(3)        NOT NULL DEFAULT 'UAH',
    merchant_category VARCHAR(50),
    merchant_country  CHAR(2),
    status            VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    risk_score        INTEGER        NOT NULL DEFAULT 0,
    transaction_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_transaction_amount     CHECK (amount > 0),
    CONSTRAINT chk_transaction_currency   CHECK (currency IN ('UAH', 'USD', 'EUR')),
    CONSTRAINT chk_transaction_status     CHECK (status IN ('PENDING', 'APPROVED', 'DECLINED', 'FLAGGED')),
    CONSTRAINT chk_transaction_risk_score CHECK (risk_score BETWEEN 0 AND 100)
);


CREATE TABLE transaction_status_history (
    history_id     BIGSERIAL    PRIMARY KEY,
    transaction_id BIGINT       NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    old_status     VARCHAR(20),
    new_status     VARCHAR(20)  NOT NULL,
    changed_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by     VARCHAR(100) NOT NULL DEFAULT CURRENT_USER
);


CREATE TABLE fraud_rules (
    rule_id         BIGSERIAL    PRIMARY KEY,
    rule_name       VARCHAR(100) NOT NULL UNIQUE,
    rule_type       VARCHAR(50)  NOT NULL,
    threshold_value INTEGER      NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_fraud_rule_type CHECK (rule_type IN ('AMOUNT', 'VELOCITY', 'COUNTRY', 'BEHAVIOR', 'TIME'))
);


CREATE TABLE fraud_alerts (
    alert_id       BIGSERIAL   PRIMARY KEY,
    transaction_id BIGINT      NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    rule_id        BIGINT      REFERENCES fraud_rules(rule_id) ON DELETE SET NULL,
    reason         TEXT        NOT NULL,
    risk_score     INTEGER     NOT NULL,
    alert_status   VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_alert_risk_score CHECK (risk_score BETWEEN 0 AND 100),
    CONSTRAINT chk_alert_status     CHECK (alert_status IN ('OPEN', 'REVIEWED', 'CLOSED', 'FALSE_POSITIVE'))
);


CREATE TABLE audit_log (
    audit_id    BIGSERIAL   PRIMARY KEY,
    customer_id BIGINT      REFERENCES customers(customer_id) ON DELETE SET NULL,
    table_name  VARCHAR(50) NOT NULL,
    operation   VARCHAR(10) NOT NULL,
    old_value   JSONB,
    new_value   JSONB,
    changed_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_audit_operation CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);
