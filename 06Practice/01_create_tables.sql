
DROP DATABASE PRACTICE06;

CREATE DATABASE PRACTICE06;


CREATE TABLE tickets (
    event_id INT PRIMARY KEY,
    available_count INT NOT NULL
);

INSERT INTO tickets VALUES (1, 100);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    event_id INT NOT NULL,
    customer_name TEXT NOT NULL
);

INSERT INTO reservations(event_id, customer_name)
SELECT 1, 'Customer_' || g
FROM generate_series(1,10) g;
