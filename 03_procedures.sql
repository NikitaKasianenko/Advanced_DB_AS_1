-- create_fraud_alert: creates a fraud alert record for a suspicious transaction
CREATE OR REPLACE PROCEDURE create_fraud_alert(
    p_transaction_id BIGINT,
    p_reason         TEXT,
    p_risk_score     INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_matching_rule_id BIGINT;
BEGIN
    SELECT rule_id INTO v_matching_rule_id
    FROM fraud_rules
    WHERE is_active = TRUE
      AND (
          (rule_type = 'AMOUNT'   AND p_reason ILIKE '%amount%')   OR
          (rule_type = 'COUNTRY'  AND p_reason ILIKE '%country%')  OR
          (rule_type = 'VELOCITY' AND p_reason ILIKE '%velocit%')  OR
          (rule_type = 'BEHAVIOR' AND (p_reason ILIKE '%merchant%' OR p_reason ILIKE '%gambling%' OR p_reason ILIKE '%crypto%')) OR
          (rule_type = 'TIME'     AND p_reason ILIKE '%time%')
      )
    LIMIT 1;

    INSERT INTO fraud_alerts (transaction_id, rule_id, reason, risk_score, alert_status)
    VALUES (p_transaction_id, v_matching_rule_id, p_reason, p_risk_score, 'OPEN');

    COMMIT;
END;
$$;

-- CALL create_fraud_alert(1, 'High amount transaction detected', 75);
-- SELECT * FROM fraud_alerts;


-- process_transaction: evaluates and processes a PENDING transaction
CREATE OR REPLACE PROCEDURE process_transaction(p_transaction_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_risk_score INTEGER;
    v_old_status VARCHAR(20);
    v_new_status VARCHAR(20);
BEGIN
    SELECT status INTO v_old_status
    FROM transactions
    WHERE transaction_id = p_transaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction % not found', p_transaction_id;
    END IF;

    IF v_old_status != 'PENDING' THEN
        RAISE EXCEPTION 'Transaction % is already processed (status: %)', p_transaction_id, v_old_status;
    END IF;

    v_risk_score := calculate_transaction_risk_score(p_transaction_id);

    IF v_risk_score >= 60 THEN
        v_new_status := 'FLAGGED';
    ELSIF v_risk_score <= 30 THEN
        v_new_status := 'APPROVED';
    ELSE
        v_new_status := 'PENDING';
    END IF;

    UPDATE transactions
    SET risk_score = v_risk_score,
        status     = v_new_status
    WHERE transaction_id = p_transaction_id;

    IF v_new_status = 'FLAGGED' THEN
        CALL create_fraud_alert(
            p_transaction_id,
            'process_transaction: risk score = ' || v_risk_score,
            v_risk_score
        );
    END IF;

    COMMIT;
    RAISE NOTICE 'Transaction % processed. Status: %, Risk: %', p_transaction_id, v_new_status, v_risk_score;
END;
$$;

-- CALL process_transaction(1);


-- freeze_account: freezes an account and declines all its PENDING transactions
CREATE OR REPLACE PROCEDURE freeze_account(p_account_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_declined_count INTEGER;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM accounts
        WHERE account_id = p_account_id AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Account % not found or already not ACTIVE', p_account_id;
    END IF;

    UPDATE accounts
    SET status = 'FROZEN'
    WHERE account_id = p_account_id;

    UPDATE transactions
    SET status = 'DECLINED'
    WHERE account_id = p_account_id
      AND status = 'PENDING';

    GET DIAGNOSTICS v_declined_count = ROW_COUNT;

    COMMIT;
    RAISE NOTICE 'Account % frozen. % transactions declined.', p_account_id, v_declined_count;
END;
$$;

-- CALL freeze_account(1);
-- SELECT status FROM accounts WHERE account_id = 1;


-- approve_pending_transactions: batch-approves low-risk PENDING transactions
CREATE OR REPLACE PROCEDURE approve_pending_transactions()
LANGUAGE plpgsql
AS $$
DECLARE
    v_approved_count INTEGER;
BEGIN
    UPDATE transactions
    SET status = 'APPROVED'
    WHERE status     = 'PENDING'
      AND risk_score  > 0
      AND risk_score <= 30;

    GET DIAGNOSTICS v_approved_count = ROW_COUNT;

    COMMIT;
    RAISE NOTICE '% transactions approved.', v_approved_count;
END;
$$;

-- CALL approve_pending_transactions();


-- refresh_fraud_dashboard: refreshes all materialized views
CREATE OR REPLACE PROCEDURE refresh_fraud_dashboard()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;

    COMMIT;
    RAISE NOTICE 'Fraud dashboard refreshed at %', NOW();
END;
$$;

-- CALL refresh_fraud_dashboard();
