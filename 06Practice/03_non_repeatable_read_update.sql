-- Session B
BEGIN;

UPDATE tickets
SET available_count = 90
WHERE event_id = 1;

COMMIT;