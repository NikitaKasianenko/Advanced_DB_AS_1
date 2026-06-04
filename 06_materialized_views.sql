DROP MATERIALIZED VIEW IF EXISTS mv_daily_fraud_summary;

-- mv_daily_fraud_summary: daily fraud dashboard — aggregated per day using CTEs and window functions
CREATE MATERIALIZED VIEW mv_daily_fraud_summary AS

WITH daily_stats AS (
    SELECT
        t.transaction_at::DATE                                           AS transaction_date,
        COUNT(t.transaction_id)                                          AS total_transactions,
        COALESCE(SUM(t.amount), 0)                                       AS total_amount,
        COUNT(t.transaction_id) FILTER (WHERE t.status = 'FLAGGED')     AS flagged_transactions,
        COALESCE(SUM(t.amount) FILTER (WHERE t.status = 'FLAGGED'), 0)  AS suspicious_amount,
        COALESCE(AVG(t.risk_score), 0)::DECIMAL(5, 2)                   AS avg_risk_score,
        COUNT(fa.alert_id)                                               AS total_fraud_alerts
    FROM transactions t
    LEFT JOIN fraud_alerts fa ON t.transaction_id = fa.transaction_id
    GROUP BY t.transaction_at::DATE
),

ranked_customers AS (
    SELECT
        t.transaction_at::DATE                 AS transaction_date,
        c.first_name || ' ' || c.last_name    AS customer_name,
        AVG(t.risk_score)                      AS avg_risk,
        ROW_NUMBER() OVER (
            PARTITION BY t.transaction_at::DATE
            ORDER BY AVG(t.risk_score) DESC
        )                                      AS rank
    FROM transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
    WHERE t.risk_score > 0
    GROUP BY t.transaction_at::DATE, c.customer_id, c.first_name, c.last_name
),

top_risky_customers AS (
    SELECT
        transaction_date,
        STRING_AGG(customer_name, ', ' ORDER BY avg_risk DESC) AS top_risky_customers
    FROM ranked_customers
    WHERE rank <= 3
    GROUP BY transaction_date
)

SELECT
    ds.transaction_date,
    ds.total_transactions,
    ds.total_amount,
    ds.flagged_transactions,
    ds.suspicious_amount,
    ds.avg_risk_score,
    COALESCE(trc.top_risky_customers, 'None') AS top_risky_customers,
    ds.total_fraud_alerts,
    NOW()                                      AS last_refreshed_at
FROM daily_stats ds
LEFT JOIN top_risky_customers trc ON ds.transaction_date = trc.transaction_date
ORDER BY ds.transaction_date DESC;

-- SELECT * FROM mv_daily_fraud_summary;
-- SELECT * FROM mv_daily_fraud_summary WHERE flagged_transactions > 0;
-- REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;
    