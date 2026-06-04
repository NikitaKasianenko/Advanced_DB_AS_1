INSERT INTO customers (first_name, last_name, email, birth_date, country_code, is_active)
VALUES
    ('Ivan', 'Petrenko', 'ivan.petrenko@example.com', '1985-05-15', 'UA', TRUE),
    ('Olena', 'Koval', 'olena.k@example.com', '1990-10-20', 'UA', TRUE),
    ('John', 'Doe', 'john.doe@example.com', '1978-02-11', 'US', TRUE),
    ('Maria', 'Garcia', 'maria.garcia@example.es', '1992-07-08', 'ES', TRUE),
    ('Taras', 'Shevchenko', 'taras.sh@example.ua', '1980-03-09', 'UA', TRUE),
    ('Anna', 'Smith', 'anna.smith@example.gb', '1995-11-25', 'GB', TRUE),
    ('Pedro', 'Pascal', 'pedro.p@example.cl', '1975-04-02', 'CL', FALSE),
    ('Yoko', 'Ono', 'yoko.o@example.jp', '1988-12-12', 'JP', TRUE),
    ('Liam', 'Neeson', 'liam.n@example.ie', '1965-06-07', 'IE', TRUE),
    ('Sofia', 'Muller', 'sofia.m@example.de', '1999-01-30', 'DE', TRUE);

INSERT INTO accounts (customer_id, account_number, currency, balance, status)
VALUES
    (1, 'UA123456789012345678901234501', 'UAH', 15000.50, 'ACTIVE'),
    (2, 'UA123456789012345678901234502', 'USD', 2500.00, 'ACTIVE'),
    (3, 'US111222333444555666777888903', 'USD', 100.00, 'FROZEN'),
    (4, 'ES987654321098765432109876504', 'EUR', 4500.75, 'ACTIVE'),
    (5, 'UA555555555555555555555555505', 'UAH', 0.00, 'CLOSED'),
    (6, 'GB444444444444444444444444406', 'EUR', 12340.00, 'ACTIVE'),
    (7, 'CL333333333333333333333333307', 'USD', 5000.00, 'FROZEN'),
    (8, 'JP222222222222222222222222208', 'USD', 8900.00, 'ACTIVE'),
    (9, 'IE111111111111111111111111109', 'EUR', 670.20, 'ACTIVE'),
    (10, 'DE000000000000000000000000010', 'EUR', 34000.00, 'ACTIVE');

INSERT INTO cards (account_id, card_number_hash, card_type, status, expiration_date)
VALUES
    (1, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'DEBIT', 'ACTIVE', '2028-12-31'),
    (2, '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92', 'CREDIT', 'ACTIVE', '2027-06-30'),
    (3, '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a', 'PREPAID', 'BLOCKED', '2024-01-01'),
    (4, 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d', 'CREDIT', 'ACTIVE', '2026-11-30'),
    (5, 'c1dfd96eea8cc2b62785275bca38ac261256e2786a3b2b8006fb1d87f71d5b3c', 'DEBIT', 'EXPIRED', '2023-05-31'),
    (6, '902ba3cda1883801594b6e1b452790cc53948fda382894175940e791221b6d05', 'DEBIT', 'ACTIVE', '2029-08-31'),
    (7, '855e966e3fb0cb28819d9b4b09e13d941de517176cb6c905db422e16ce0366eb', 'CREDIT', 'BLOCKED', '2025-02-28'),
    (8, '45c48cce2e2d7fbdea1afc51c7c6ad261e4a11c1d0f507b94098eb04a3e7dc93', 'PREPAID', 'ACTIVE', '2026-04-30'),
    (9, 'd4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35', 'DEBIT', 'ACTIVE', '2027-10-31'),
    (10, '3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d', 'CREDIT', 'ACTIVE', '2028-01-31');


INSERT INTO fraud_rules (rule_name, rule_type, threshold_value, is_active)
VALUES
    ('High Amount Transaction', 'AMOUNT', 50000, TRUE),
    ('Suspicious Foreign Country', 'COUNTRY', 1, TRUE),
    ('High Velocity - 5 TX per min', 'VELOCITY', 5, TRUE),
    ('Nighttime Suspicious Behavior', 'TIME', 1, TRUE),
    ('Multiple Declined Attempts', 'BEHAVIOR', 3, TRUE);


INSERT INTO transactions (account_id, card_id, amount, currency, merchant_category, merchant_country, transaction_at)
VALUES
    (1, 1, 550.00, 'UAH', 'Groceries', 'UA', '2026-05-30 10:15:00'),
    (2, 2, 120.00, 'USD', 'Software', 'US', '2026-05-30 11:00:00'),
    (2, 2, 2000.00, 'USD', 'Electronics', 'CN', '2026-05-30 11:05:00'),
    (3, 3, 50.00, 'USD', 'Entertainment', 'US', '2026-05-31 09:30:00'),
    (4, 4, 15.50, 'EUR', 'Coffee Shop', 'ES', '2026-05-31 08:45:00'),
    (4, 4, 3000.00, 'EUR', 'Travel', 'FR', '2026-05-31 14:20:00'),
    (6, 6, 850.00, 'EUR', 'Clothing', 'GB', '2026-06-01 09:00:00'),
    (7, 7, 100.00, 'USD', 'Gambling', 'MT', '2026-06-01 01:15:00'),
    (8, 8, 45.00, 'USD', 'Restaurants', 'JP', '2026-06-01 12:30:00'),
    (9, 9, 65000.00, 'EUR', 'Luxury', 'AE', '2026-05-29 16:40:00'),
    (10, 10, 12.00, 'EUR', 'Transport', 'DE', '2026-06-01 08:10:00'),
    (10, 10, 15.00, 'EUR', 'Transport', 'DE', '2026-06-01 08:35:00');


INSERT INTO audit_log (customer_id, table_name, operation, old_value, new_value)
VALUES
    (1, 'customers', 'INSERT', NULL, '{"first_name": "Ivan", "country_code": "UA"}'),
    (2, 'customers', 'INSERT', NULL, '{"first_name": "Olena", "country_code": "UA"}'),
    (3, 'accounts', 'UPDATE', '{"status": "ACTIVE"}', '{"status": "FROZEN"}'),
    (5, 'accounts', 'UPDATE', '{"status": "ACTIVE"}', '{"status": "CLOSED"}'),
    (7, 'customers', 'UPDATE', '{"is_active": true}', '{"is_active": false}'),
    (7, 'accounts', 'UPDATE', '{"status": "ACTIVE"}', '{"status": "FROZEN"}'),
    (7, 'cards', 'UPDATE', '{"status": "ACTIVE"}', '{"status": "BLOCKED"}'),
    (9, 'customers', 'INSERT', NULL, '{"first_name": "Liam", "country_code": "IE"}'),
    (10, 'customers', 'INSERT', NULL, '{"first_name": "Sofia", "country_code": "DE"}'),
    (10, 'accounts', 'INSERT', NULL, '{"currency": "EUR", "status": "ACTIVE"}');


REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;

SELECT
    'customers'               AS entity, COUNT(*) AS count FROM customers
UNION ALL SELECT 'accounts',               COUNT(*) FROM accounts
UNION ALL SELECT 'cards',                  COUNT(*) FROM cards
UNION ALL SELECT 'transactions',           COUNT(*) FROM transactions
UNION ALL SELECT 'status_history',         COUNT(*) FROM transaction_status_history
UNION ALL SELECT 'fraud_alerts',           COUNT(*) FROM fraud_alerts
UNION ALL SELECT 'audit_log',              COUNT(*) FROM audit_log;

SELECT status, COUNT(*) AS count, AVG(risk_score)::DECIMAL(5,2) AS avg_risk
FROM transactions
GROUP BY status
ORDER BY count DESC;
