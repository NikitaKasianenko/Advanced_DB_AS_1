
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT pg_stat_statements_reset();



--  top queries by total execution time
SELECT
    LEFT(query, 120)                         AS query_preview,
    calls,
    ROUND(total_exec_time::NUMERIC, 2)       AS total_ms,
    ROUND(mean_exec_time::NUMERIC, 2)        AS mean_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;


-- currently running queries (real-time snapshot)
SELECT
    pid,
    usename,
    state,
    wait_event_type,
    wait_event,
    ROUND(EXTRACT(EPOCH FROM (NOW() - query_start))::NUMERIC, 2) AS running_sec,
    LEFT(query, 200) AS query
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY query_start;



-- blocked sessions and their blockers

SELECT
    blocked.pid          AS blocked_pid,
    blocked.usename      AS blocked_user,
    ROUND(EXTRACT(EPOCH FROM (NOW() - blocked.query_start))::NUMERIC, 2) AS blocked_for_sec,
    LEFT(blocked.query, 150)  AS blocked_query,
    blocking.pid         AS blocking_pid,
    blocking.usename     AS blocking_user,
    LEFT(blocking.query, 150) AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
ORDER BY blocked.query_start;



-- sessions waiting for locks
SELECT
    pid,
    usename,
    state,
    wait_event_type,
    wait_event,
    ROUND(EXTRACT(EPOCH FROM (NOW() - query_start))::NUMERIC, 2) AS waiting_sec,
    LEFT(query, 200) AS query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY query_start;


-- active locks details
SELECT
    l.pid,
    l.locktype,
    l.relation::REGCLASS AS table_name,
    l.mode,
    l.granted,
    LEFT(a.query, 120) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL
ORDER BY l.granted, l.pid;



-- long-running transactions

SELECT
    pid,
    usename,
    state,
    xact_start,
    ROUND(EXTRACT(EPOCH FROM (NOW() - xact_start))::NUMERIC, 2) AS xact_duration_sec,
    LEFT(query, 200) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start;



-- existing indexes on the database

SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;



-- table row counts and dead tuples

SELECT
    relname            AS table_name,
    n_live_tup         AS live_rows,
    n_dead_tup         AS dead_rows,
    last_autovacuum,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;


-- ============================================================

-- email search with leading wildcard
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM customers
WHERE email LIKE '%gmail%';


-- orders filter on delivery_city and status
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM orders
WHERE delivery_city LIKE '%a%'
  AND status = 'paid';


-- heavy JOIN: customers + orders with GROUP BY and ORDER BY
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


-- events aggregation with date range
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    customer_id,
    event_type,
    COUNT(*)        AS events_count,
    MAX(event_time) AS last_event_time
FROM customer_events_wide
WHERE event_time >= NOW() - INTERVAL '180 days'
GROUP BY customer_id, event_type
ORDER BY events_count DESC
LIMIT 200;


-- order_items + products aggregation by category
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    p.category,
    COUNT(*)                         AS items_sold,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;


-- three-way join producing cartesian pressure
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT COUNT(*)
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN customer_events_wide e ON e.customer_id = c.customer_id
WHERE c.status IN ('active', 'inactive')
  AND e.event_time >= NOW() - INTERVAL '90 days';

-- ======

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT customer_id, event_type, COUNT(*) AS events_count, MAX(event_time) AS last_event_time
FROM customer_events
WHERE event_time >= NOW() - INTERVAL '180 days'
GROUP BY customer_id, event_type ORDER BY events_count DESC LIMIT 200;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT COUNT(*) FROM customers c
                         JOIN orders o ON o.customer_id = c.customer_id
WHERE c.status IN ('active', 'inactive')
  AND EXISTS (
    SELECT 1 FROM customer_events e
    WHERE e.customer_id = c.customer_id AND e.event_time >= NOW() - INTERVAL '90 days'
);