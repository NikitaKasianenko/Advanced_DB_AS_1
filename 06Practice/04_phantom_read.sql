-- Session A
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*)
FROM reservations
WHERE event_id = 1;

-- Keep transaction open

--COMMIT;