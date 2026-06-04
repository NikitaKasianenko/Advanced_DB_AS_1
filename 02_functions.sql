-- mask_card_number: masks card number, showing only last 4 digits
CREATE OR REPLACE FUNCTION mask_card_number(p_card_number VARCHAR)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_card_number IS NULL OR length(p_card_number) < 4 THEN
        RETURN '****';
    END IF;

    RETURN '****-****-****-' || right(p_card_number, 4);
END;
$$;

-- SELECT mask_card_number('4111111111111234');


-- is_high_risk_country: returns TRUE if country is flagged as high risk
CREATE OR REPLACE FUNCTION is_high_risk_country(p_country_code CHAR(2))
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN p_country_code = ANY(ARRAY['KP', 'IR', 'SY', 'CU', 'VE', 'MM', 'AF']);
END;
$$;

-- SELECT is_high_risk_country('KP');
-- SELECT is_high_risk_country('UA');


-- get_customer_age: returns customer age in full years
CREATE OR REPLACE FUNCTION get_customer_age(p_customer_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_birth_date DATE;
BEGIN
    SELECT birth_date INTO v_birth_date
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer with ID % not found', p_customer_id;
    END IF;

    RETURN DATE_PART('year', AGE(v_birth_date));
END;
$$;

-- SELECT get_customer_age(1);


-- calculate_customer_daily_volume: returns total transaction amount for a customer on a given date
CREATE OR REPLACE FUNCTION calculate_customer_daily_volume(
    p_customer_id BIGINT,
    p_target_date DATE
)
RETURNS DECIMAL(15, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total DECIMAL(15, 2);
BEGIN
    SELECT COALESCE(SUM(t.amount), 0) INTO v_total
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id
      AND t.transaction_at::DATE = p_target_date
      AND t.status != 'DECLINED';

    RETURN v_total;
END;
$$;

-- SELECT calculate_customer_daily_volume(1, CURRENT_DATE);


-- calculate_transaction_risk_score: returns risk score 0-100 based on multiple fraud factors
CREATE OR REPLACE FUNCTION calculate_transaction_risk_score(p_transaction_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction  transactions%ROWTYPE;
    v_account      accounts%ROWTYPE;
    v_daily_volume DECIMAL(15, 2);
    v_tx_count_1h  INTEGER;
    v_score        INTEGER := 0;
BEGIN
    SELECT * INTO v_transaction
    FROM transactions
    WHERE transaction_id = p_transaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction % not found', p_transaction_id;
    END IF;

    SELECT * INTO v_account
    FROM accounts
    WHERE account_id = v_transaction.account_id;

    IF v_transaction.amount > 10000 THEN
        v_score := v_score + 25;
    ELSIF v_transaction.amount > 5000 THEN
        v_score := v_score + 15;
    ELSIF v_transaction.amount > 1000 THEN
        v_score := v_score + 5;
    END IF;

    IF v_transaction.merchant_country IS NOT NULL
       AND is_high_risk_country(v_transaction.merchant_country) THEN
        v_score := v_score + 25;
    END IF;

    IF v_transaction.merchant_category IN ('GAMBLING', 'CRYPTO', 'ADULT_CONTENT', 'WEAPONS') THEN
        v_score := v_score + 20;
    END IF;

    IF EXTRACT(HOUR FROM v_transaction.transaction_at) BETWEEN 0 AND 4 THEN
        v_score := v_score + 10;
    END IF;

    v_daily_volume := calculate_customer_daily_volume(
        v_account.customer_id,
        v_transaction.transaction_at::DATE
    );

    IF v_daily_volume > 50000 THEN
        v_score := v_score + 20;
    ELSIF v_daily_volume > 20000 THEN
        v_score := v_score + 10;
    END IF;

    SELECT COUNT(*) INTO v_tx_count_1h
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = v_account.customer_id
      AND t.transaction_id != p_transaction_id
      AND t.transaction_at >= v_transaction.transaction_at - INTERVAL '1 hour'
      AND t.transaction_at <= v_transaction.transaction_at
      AND t.status != 'DECLINED';

    IF v_tx_count_1h >= 5 THEN
        v_score := v_score + 20;
    ELSIF v_tx_count_1h >= 3 THEN
        v_score := v_score + 10;
    END IF;

    RETURN LEAST(v_score, 100);
END;
$$;

-- SELECT calculate_transaction_risk_score(1);
