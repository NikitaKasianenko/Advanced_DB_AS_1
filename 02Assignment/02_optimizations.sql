-- ============================================================
-- Enable pg_trgm for LIKE '%...%' queries
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- ============================================================
-- Basic B-tree indexes on filter columns
-- ============================================================

-- customers.email: GIN trigram index — the only way to index LIKE '%...%'
CREATE INDEX IF NOT EXISTS idx_customers_email_trgm
    ON customers USING GIN (email gin_trgm_ops);

-- customers.status: used in WHERE status = 'active' (heavy_join query)
CREATE INDEX IF NOT EXISTS idx_customers_status
    ON customers (status);

-- orders.status: used in WHERE status = 'paid'
CREATE INDEX IF NOT EXISTS idx_orders_status
    ON orders (status);

CREATE INDEX IF NOT EXISTS idx_orders_delivery_city_status
    ON orders (delivery_city, status);

-- customer_events_wide.event_time: date range filter in events_aggregation
CREATE INDEX IF NOT EXISTS idx_events_event_time
    ON customer_events_wide (event_time);

-- products.category: GROUP BY category in items_products_join
CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category);


-- ============================================================ with include

CREATE INDEX IF NOT EXISTS idx_orders_customer_covering
    ON orders (customer_id)
    INCLUDE (order_id, total_amount);

-- customers: filter on status, select customer_id + full_name.
CREATE INDEX IF NOT EXISTS idx_customers_status_covering
    ON customers (status)
    INCLUDE (customer_id, full_name);

-- customer_events_wide: filter event_time, GROUP BY customer_id + event_type.
CREATE INDEX IF NOT EXISTS idx_events_time_covering
    ON customer_events_wide (event_time)
    INCLUDE (customer_id, event_type);

-- order_items: product_id is the join key; quantity and unit_price are aggregated.
CREATE INDEX IF NOT EXISTS idx_order_items_product_covering
    ON order_items (product_id)
    INCLUDE (quantity, unit_price);


-- ======== ==================================== partial index
CREATE INDEX IF NOT EXISTS idx_orders_paid_customer
    ON orders (customer_id, total_amount)
    WHERE status = 'paid';


-- ============================================================
-- Composite indexes for multi-column filters

CREATE INDEX IF NOT EXISTS idx_orders_status_date_desc
    ON orders (status, order_date DESC);

CREATE INDEX IF NOT EXISTS idx_events_customer_event_time
    ON customer_events_wide (customer_id, event_time);


-- ============================================================
-- Functional indexes for expressions in WHERE

CREATE INDEX IF NOT EXISTS idx_orders_year
    ON orders (EXTRACT(YEAR FROM order_date));

CREATE INDEX IF NOT EXISTS idx_events_hour
    ON customer_events_wide (EXTRACT(HOUR FROM event_time));


-- ============================================================
 -- Normalize customer_events_wide (wide table fix)
-- ============================================================


CREATE TABLE IF NOT EXISTS customer_events (
    event_id    SERIAL      PRIMARY KEY,
    customer_id INT         NOT NULL,
    event_type  TEXT        NOT NULL,
    event_time  TIMESTAMP   NOT NULL,
    source      TEXT,
    campaign    TEXT,
    device      TEXT,
    browser     TEXT,
    os          TEXT,
    ip_address  TEXT,
    page_url    TEXT,
    referrer    TEXT
);

CREATE TABLE IF NOT EXISTS event_utm (
    event_id     INT  PRIMARY KEY REFERENCES customer_events(event_id) ON DELETE CASCADE,
    utm_source   TEXT,
    utm_medium   TEXT,
    utm_campaign TEXT
);

CREATE TABLE IF NOT EXISTS event_attributes (
    event_id INT PRIMARY KEY REFERENCES customer_events(event_id) ON DELETE CASCADE,
    attr_01  TEXT, attr_02 TEXT, attr_03 TEXT, attr_04 TEXT, attr_05 TEXT,
    attr_06  TEXT, attr_07 TEXT, attr_08 TEXT, attr_09 TEXT, attr_10 TEXT
);

INSERT INTO customer_events
    (event_id, customer_id, event_type, event_time, source, campaign,
     device, browser, os, ip_address, page_url, referrer)
SELECT event_id, customer_id, event_type, event_time, source, campaign,
       device, browser, os, ip_address, page_url, referrer
FROM customer_events_wide
ON CONFLICT DO NOTHING;

INSERT INTO event_utm (event_id, utm_source, utm_medium, utm_campaign)
SELECT event_id, utm_source, utm_medium, utm_campaign
FROM customer_events_wide
ON CONFLICT DO NOTHING;

INSERT INTO event_attributes
    (event_id, attr_01, attr_02, attr_03, attr_04, attr_05,
     attr_06, attr_07, attr_08, attr_09, attr_10)
SELECT event_id, attr_01, attr_02, attr_03, attr_04, attr_05,
       attr_06, attr_07, attr_08, attr_09, attr_10
FROM customer_events_wide
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_ce_customer_id         ON customer_events (customer_id);
CREATE INDEX IF NOT EXISTS idx_ce_event_time          ON customer_events (event_time);
CREATE INDEX IF NOT EXISTS idx_ce_customer_event_time ON customer_events (customer_id, event_time);
CREATE INDEX IF NOT EXISTS idx_ce_time_covering       ON customer_events (event_time) INCLUDE (customer_id, event_type);


-- ============================================================
-- Rewritten queries after optimization
-- ============================================================

SELECT *
FROM customers
WHERE email LIKE '%gmail%';


-- 8.2 Orders by city and status — composite index (delivery_city, status)
SELECT *
FROM orders
WHERE delivery_city LIKE '%a%'
  AND status = 'paid';


-- Heavy JOIN
SELECT
    c.customer_id,
    c.full_name,
    COUNT(o.order_id)   AS orders_count,
    SUM(o.total_amount) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.full_name
ORDER BY revenue DESC
LIMIT 100;


--  Events aggregation
SELECT
    customer_id,
    event_type,
    COUNT(*)        AS events_count,
    MAX(event_time) AS last_event_time
FROM customer_events
WHERE event_time >= NOW() - INTERVAL '180 days'
GROUP BY customer_id, event_type
ORDER BY events_count DESC
LIMIT 200;


-- Cartesian pressure rewritten using EXISTS

SELECT COUNT(*)
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE c.status IN ('active', 'inactive')
  AND EXISTS (
      SELECT 1
      FROM customer_events e
      WHERE e.customer_id = c.customer_id
        AND e.event_time >= NOW() - INTERVAL '90 days'
  );




-- 10.1 Email search — expect Bitmap Index Scan (GIN trgm)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM customers
WHERE email LIKE '%gmail%';


-- Events aggregation on normalized table
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    customer_id,
    event_type,
    COUNT(*)        AS events_count,
    MAX(event_time) AS last_event_time
FROM customer_events
WHERE event_time >= NOW() - INTERVAL '180 days'
GROUP BY customer_id, event_type
ORDER BY events_count DESC
LIMIT 200;


-- 10.3 Heavy JOIN
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.customer_id,
    c.full_name,
    COUNT(o.order_id)   AS orders_count,
    SUM(o.total_amount) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.full_name
ORDER BY revenue DESC
LIMIT 100;


-- Post-optimization pg_stat_statements

SELECT pg_stat_statements_reset();

SELECT
    LEFT(query, 120)                         AS query_preview,
    calls,
    ROUND(total_exec_time::NUMERIC, 2)       AS total_ms,
    ROUND(mean_exec_time::NUMERIC, 2)        AS mean_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;



SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
