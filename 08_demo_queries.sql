-- mask_card_number
SELECT mask_card_number('4111111111111234') AS masked_card;

-- is_high_risk_country
SELECT
    unnest(ARRAY['UA', 'KP', 'DE', 'IR']) AS country_code,
    is_high_risk_country(unnest(ARRAY['UA', 'KP', 'DE', 'IR'])) AS is_risky;

-- get_customer_age
SELECT customer_id, first_name, last_name, birth_date,
       get_customer_age(customer_id) AS age
FROM customers
ORDER BY age DESC;

-- calculate_customer_daily_volume
SELECT calculate_customer_daily_volume(1, CURRENT_DATE) AS todays_volume;

-- calculate_transaction_risk_score
SELECT transaction_id, amount, merchant_category, merchant_country, status, risk_score
FROM transactions
ORDER BY risk_score DESC;


-- all transactions with risk level
SELECT
    t.transaction_id,
    c.first_name || ' ' || c.last_name AS customer,
    t.amount,
    t.currency,
    t.merchant_category,
    t.merchant_country,
    t.risk_score,
    t.status,
    CASE
        WHEN t.risk_score >= 60 THEN 'HIGH'
        WHEN t.risk_score >= 30 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_label,
    t.transaction_at
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
ORDER BY t.risk_score DESC;


-- customer risk ranking using window functions RANK and DENSE_RANK
SELECT
    customer_id,
    full_name,
    country_code,
    total_transactions,
    flagged_count,
    avg_risk_score,
    overall_risk_level,
    RANK()       OVER (ORDER BY avg_risk_score DESC) AS risk_rank,
    DENSE_RANK() OVER (ORDER BY flagged_count DESC)  AS flagged_rank
FROM vw_customer_risk_profile
ORDER BY risk_rank;


-- flagged transactions
SELECT * FROM vw_flagged_transactions;


-- daily fraud dashboard from materialized view
SELECT * FROM mv_daily_fraud_summary ORDER BY transaction_date DESC;


-- cumulative spend per customer using CTE and SUM OVER window function
WITH customer_transactions AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        t.transaction_id,
        t.amount,
        t.transaction_at,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id
            ORDER BY t.transaction_at
        ) AS tx_number
    FROM transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
    WHERE t.status = 'APPROVED'
)
SELECT
    customer_name,
    transaction_id,
    amount,
    tx_number,
    SUM(amount) OVER (
        PARTITION BY customer_id
        ORDER BY transaction_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_spent,
    transaction_at
FROM customer_transactions
ORDER BY customer_name, tx_number;


-- full status history for all transactions
SELECT
    tsh.transaction_id,
    t.amount,
    tsh.old_status,
    tsh.new_status,
    tsh.changed_at,
    tsh.changed_by
FROM transaction_status_history tsh
JOIN transactions t ON tsh.transaction_id = t.transaction_id
ORDER BY tsh.changed_at DESC;


-- freeze account and verify result
CALL freeze_account(7);
SELECT account_id, status FROM accounts WHERE account_id = 7;
SELECT transaction_id, status FROM transactions WHERE account_id = 7;


-- refresh fraud dashboard
CALL refresh_fraud_dashboard();
SELECT * FROM mv_daily_fraud_summary;
