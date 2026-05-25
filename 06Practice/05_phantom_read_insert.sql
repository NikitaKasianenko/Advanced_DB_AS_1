-- Session B
BEGIN;

INSERT INTO reservations(event_id, customer_name)
VALUES (1, 'Alice');

COMMIT;