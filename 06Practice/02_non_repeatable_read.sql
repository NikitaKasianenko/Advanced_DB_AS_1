-- Session A
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT available_count
FROM tickets
WHERE event_id = 1;

-- Keep transaction open

COMMIT;