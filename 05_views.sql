-- vw_customer_accounts: customers with their account details
CREATE OR REPLACE VIEW vw_customer_accounts AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name   AS full_name,
    c.email,
    c.country_code,
    is_high_risk_country(c.country_code) AS customer_in_risk_country,
    c.is_active                          AS customer_active,
    a.account_id,
    a.account_number,
    a.currency,
    a.balance,
    a.status                             AS account_status,
    a.opened_at
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id;

-- SELECT * FROM vw_customer_accounts;
-- SELECT * FROM vw_customer_accounts WHERE account_status = 'FROZEN';


-- vw_recent_transactions: transactions from the last 30 days with customer info
CREATE OR REPLACE VIEW vw_recent_transactions AS
SELECT
    t.transaction_id,
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    a.account_number,
    t.amount,
    t.currency,
    t.merchant_category,
    t.merchant_country,
    t.status,
    t.risk_score,
    CASE
        WHEN t.risk_score >= 60 THEN 'HIGH'
        WHEN t.risk_score >= 30 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                AS risk_level,
    t.transaction_at
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.transaction_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY t.transaction_at DESC;

-- SELECT * FROM vw_recent_transactions;
-- SELECT * FROM vw_recent_transactions WHERE risk_level = 'HIGH';


-- vw_flagged_transactions: flagged transactions with fraud alert and rule details
CREATE OR REPLACE VIEW vw_flagged_transactions AS
SELECT
    t.transaction_id,
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.country_code                     AS customer_country,
    a.account_number,
    t.amount,
    t.currency,
    t.merchant_category,
    t.merchant_country,
    t.risk_score,
    t.transaction_at,
    fa.alert_id,
    fa.reason                          AS alert_reason,
    fa.alert_status,
    fa.created_at                      AS alert_created_at,
    fr.rule_name,
    fr.rule_type
FROM transactions t
JOIN accounts     a  ON t.account_id    = a.account_id
JOIN customers    c  ON a.customer_id   = c.customer_id
JOIN fraud_alerts fa ON t.transaction_id = fa.transaction_id
LEFT JOIN fraud_rules fr ON fa.rule_id  = fr.rule_id
WHERE t.status = 'FLAGGED'
ORDER BY t.risk_score DESC, t.transaction_at DESC;

-- SELECT * FROM vw_flagged_transactions;
-- SELECT * FROM vw_flagged_transactions WHERE alert_status = 'OPEN';


-- vw_customer_risk_profile: risk profile per customer based on their transactions
CREATE OR REPLACE VIEW vw_customer_risk_profile AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name      AS full_name,
    c.email,
    c.country_code,
    is_high_risk_country(c.country_code)    AS in_high_risk_country,
    get_customer_age(c.customer_id)         AS age,
    COUNT(t.transaction_id)                                              AS total_transactions,
    COUNT(t.transaction_id) FILTER (WHERE t.status = 'FLAGGED')         AS flagged_count,
    COUNT(t.transaction_id) FILTER (WHERE t.status = 'APPROVED')        AS approved_count,
    COUNT(t.transaction_id) FILTER (WHERE t.status = 'DECLINED')        AS declined_count,
    COALESCE(AVG(t.risk_score), 0)::DECIMAL(5, 2)                       AS avg_risk_score,
    COALESCE(MAX(t.risk_score), 0)                                       AS max_risk_score,
    COALESCE(SUM(t.amount) FILTER (WHERE t.status = 'APPROVED'), 0)     AS total_approved_amount,
    CASE
        WHEN COALESCE(AVG(t.risk_score), 0) >= 60 THEN 'HIGH'
        WHEN COALESCE(AVG(t.risk_score), 0) >= 30 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                                  AS overall_risk_level
FROM customers c
LEFT JOIN accounts     a ON c.customer_id = a.customer_id
LEFT JOIN transactions t ON a.account_id  = t.account_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.country_code;

-- SELECT * FROM vw_customer_risk_profile ORDER BY avg_risk_score DESC;
-- SELECT * FROM vw_customer_risk_profile WHERE overall_risk_level = 'HIGH';
