# PostgreSQL Index Optimization Task: Elite Retail Transactions UK

## Goal

You are given a large retail transaction table loaded from the Kaggle dataset:

`noahtaylson/elite-retail-transaction-dataset-uk`

Your task is to optimize one complex analytical query using PostgreSQL indexes.

The main learning goal is to decide when to use:

1. A normal B-tree index
2. A covering index with `INCLUDE`
3. An expression / functional index
4. A partial index
5. A composite index

---

## Complex Query To Optimize

```sql
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.date_of_birth,
    c.gender,
    c.city,
    c.postcode,
    c.country,
    c.loyalty_tier,
    c.registration_date,

    LOWER(c.email) AS email_normalized,
    INITCAP(c.first_name || ' ' || c.last_name) AS full_name,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth)) AS age,

    COUNT(t.txn_id) AS total_transactions,
    SUM(t.quantity) AS total_quantity,
    COUNT(DISTINCT t.product_id) AS unique_products,
    COUNT(DISTINCT t.store_id) AS unique_stores,
    COUNT(DISTINCT t.staff_id) AS unique_staff,
    MIN(t.event_time) AS first_transaction_time,
    MAX(t.event_time) AS last_transaction_time,

    SUM(CASE WHEN t.payment_method = 'Card' THEN 1 ELSE 0 END) AS card_transactions,
    SUM(CASE WHEN t.payment_method = 'Cash' THEN 1 ELSE 0 END) AS cash_transactions,
    SUM(CASE WHEN t.payment_method NOT IN ('Card', 'Cash') THEN 1 ELSE 0 END) AS other_payment_transactions

FROM customers c
         JOIN transactions t
              ON t.customer_id = c.customer_id

WHERE 1 = 1
  AND c.loyalty_tier IN ('Silver', 'Gold', 'Platinum')
  AND c.registration_date >= CURRENT_DATE - INTERVAL '15 years'
  AND EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth)) in (25, 30, 35)

  AND (LOWER(c.email) LIKE '%.org' or LOWER(c.email) LIKE '%.com')
  AND LENGTH(c.email) BETWEEN 12 AND 80
  AND POSITION('@' IN c.email) > 1
  AND c.email ~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'
  AND COALESCE(c.phone, '') ~ '[0-9]{7,}'

  AND LENGTH(TRIM(c.first_name)) >= 2
  AND LENGTH(TRIM(c.last_name)) >= 2
  AND LOWER(c.first_name) NOT LIKE 'test%'
  AND LOWER(c.last_name) NOT LIKE 'demo%'

  AND COALESCE(c.city, '') <> ''
  AND COALESCE(c.country, '') <> ''
  AND LENGTH(COALESCE(c.postcode, '')) BETWEEN 3 AND 12

-- transaction filters
  AND t.event_time >= CURRENT_DATE - INTERVAL '12 years'
  AND t.quantity > 0
  AND t.payment_method IN ('Card', 'Cash', 'Apple Pay', 'Google Pay')
  AND EXTRACT(HOUR FROM t.event_time) BETWEEN 8 AND 22
  AND EXTRACT(DOW FROM t.event_time) IN (1, 2, 3, 4, 5, 6)
  AND MOD(t.product_id, 2) = 0
  AND MOD(t.store_id, 3) <> 0

-- intentionally expensive expressions
  AND MD5(LOWER(c.email || COALESCE(c.phone, '') || c.customer_id::TEXT)) IS NOT NULL
  AND MD5(t.txn_id::TEXT || t.customer_id::TEXT || t.product_id::TEXT) IS NOT NULL

GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.date_of_birth,
    c.gender,
    c.city,
    c.postcode,
    c.country,
    c.loyalty_tier,
    c.registration_date

HAVING
    COUNT(t.txn_id) >= 3
   AND SUM(t.quantity) >= 10
   AND COUNT(DISTINCT t.product_id) >= 2

ORDER BY
    total_quantity DESC,
    total_transactions DESC,
    MAX(t.event_time) DESC,
    LOWER(c.last_name),
    LOWER(c.first_name)

```