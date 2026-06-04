-- trg_evaluate_transaction_risk: after INSERT on transactions
-- calculates risk score, sets status, creates fraud alert if FLAGGED
CREATE OR REPLACE FUNCTION trg_fn_evaluate_transaction_risk()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_risk_score INTEGER;
    v_new_status VARCHAR(20);
BEGIN
    v_risk_score := calculate_transaction_risk_score(NEW.transaction_id);

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
    WHERE transaction_id = NEW.transaction_id;

    INSERT INTO transaction_status_history (transaction_id, old_status, new_status, changed_by)
    VALUES (NEW.transaction_id, NULL, v_new_status, 'SYSTEM_AUTO');

    IF v_new_status = 'FLAGGED' THEN
        INSERT INTO fraud_alerts (transaction_id, reason, risk_score, alert_status)
        VALUES (
            NEW.transaction_id,
            'Auto-flagged: risk score ' || v_risk_score,
            v_risk_score,
            'OPEN'
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_evaluate_transaction_risk
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION trg_fn_evaluate_transaction_risk();


-- trg_update_balance_on_approval: after UPDATE on transactions when status becomes APPROVED
-- deducts transaction amount from account balance
CREATE OR REPLACE FUNCTION trg_fn_update_balance_on_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE accounts
    SET balance = balance - NEW.amount
    WHERE account_id = NEW.account_id;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_update_balance_on_approval
AFTER UPDATE ON transactions
FOR EACH ROW
WHEN (NEW.status = 'APPROVED' AND OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trg_fn_update_balance_on_approval();


-- logs every status change into transaction_status_history
CREATE OR REPLACE FUNCTION trg_fn_track_status_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO transaction_status_history (transaction_id, old_status, new_status, changed_by)
    VALUES (NEW.transaction_id, OLD.status, NEW.status, CURRENT_USER);

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_track_status_history
AFTER UPDATE ON transactions
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trg_fn_track_status_history();


-- trg_protect_customer_delete - before DELETE on customers
-- prevents deletion if customer has active accounts
CREATE OR REPLACE FUNCTION trg_fn_protect_customer_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_active_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_active_count
    FROM accounts
    WHERE customer_id = OLD.customer_id
      AND status = 'ACTIVE';

    IF v_active_count > 0 THEN
        RAISE EXCEPTION 'Cannot delete customer %. They have % active account(s).',
            OLD.customer_id, v_active_count;
    END IF;

    RETURN OLD;
END;
$$;

CREATE OR REPLACE TRIGGER trg_protect_customer_delete
BEFORE DELETE ON customers
FOR EACH ROW
EXECUTE FUNCTION trg_fn_protect_customer_delete();
