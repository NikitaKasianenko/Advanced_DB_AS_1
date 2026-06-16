# Assignment 02 — PostgreSQL Performance Analysis Report

**Database:** `student_perf_lab`  
**Tables:** `customers` (20k rows), `products` (2k), `orders` (120k), `order_items` (~360k), `customer_events_wide` (200k, 25 columns)

## 1. Identified Performance Issues & Diagnostic Tools

During the load simulation, several critical bottlenecks were detected using PostgreSQL diagnostic tools:

* **Seq Scans on String Matching:** `LIKE '%gmail%'` queries caused full table scans (20,000 rows) because standard B-tree indexes cannot process leading wildcards. *(Detected via EXPLAIN ANALYZE)*
* **Missing Indexes:** Queries filtering by `delivery_city`, `status`, and `event_time` resulted in sequential scans over 120k+ rows. *(Detected via EXPLAIN ANALYZE)*
* **Cartesian Row Explosion:** A three-way `JOIN` (`customers` × `orders` × `customer_events_wide`) produced massive intermediate result sets before aggregation. *(Detected via EXPLAIN ANALYZE)*
* **MVCC Bloat on Wide Tables:** Updating a few columns in the 25-column `customer_events_wide` table forced PostgreSQL to rewrite the entire wide row, causing high I/O and rapid accumulation of dead tuples. *(Detected via pg_stat_user_tables)*
* **Lock Contention & Deadlocks:** Transactions were updating the same customer rows in different orders, causing circular lock dependencies (`wait_event_type = 'Lock'`). *(Detected via pg_locks and pg_stat_activity)*

---

## 2. Implemented Solutions

To resolve the identified issues, the following optimizations were applied:

### 2.1. Indexing Strategy
* **GIN Trigram Index:** Enabled `pg_trgm` and created a GIN index on `customers.email` to handle `LIKE '%...%'` queries efficiently.
* **Composite Indexes:** Created an index on `orders (delivery_city, status)` so the planner can resolve both conditions in a single scan.
* **Covering Indexes (`INCLUDE`):** Created covering indexes (e.g., `ON orders (customer_id) INCLUDE (order_id, total_amount)`). This allows the database to perform an **Index Only Scan**, fetching data directly from the index and reducing `Heap Fetches` to 0.

### 2.2. Query Rewriting & Normalization
* **Eliminating Cartesian Pressure:** Rewrote the problematic three-way `JOIN` using `EXISTS`. This short-circuits the search as soon as a match is found, preventing row duplication.
* **Table Normalization:** Split the 25-column `customer_events_wide` table into three narrower tables (`customer_events`, `event_utm`, `event_attributes`). This drastically reduced the I/O cost of `UPDATE` operations and slowed down MVCC bloat.

> **Note on Maintenance:** A stored procedure for scheduled maintenance (`run_maintenance()`) using `VACUUM ANALYZE` was created in the script (Section 9) to demonstrate understanding of transaction logic, but it was **not executed** during the final performance benchmarking to isolate the impact of indexes and schema changes.

---

## 3. Results After Optimization (Before vs. After)

Performance was benchmarked using `EXPLAIN ANALYZE` before and after applying the structural changes. The results show massive improvements across all queries:

| Query Description | Execution Time (Before) | Execution Time (After) | Execution Plan Changes |
| :--- | :--- | :--- | :--- |
| **1. Email Search (`LIKE`)** | 2.82 ms | **0.38 ms** | `Seq Scan` → `Bitmap Index Scan`. The GIN trgm index eliminated the full table scan. |
| **2. Orders Filter** | 20.45 ms | **10.30 ms** | `Seq Scan` → `Bitmap Heap Scan`. Composite index effectively narrowed the dataset. |
| **3. Heavy JOIN** | 35.85 ms | **29.99 ms** | `Hash Join` → **`Index Only Scan`**. The `INCLUDE` clause reduced Heap Fetches to 0. |
| **4. Events Aggregation** | 138.70 ms | **85.96 ms** | Read buffers dropped from 9198 to 489. Switched to `Index Only Scan` on the newly normalized table. |
| **5. Products Aggregation** | 62.48 ms | **55.16 ms** | Partial improvement due to B-tree indexes on join keys. |
| **6. Cartesian Pressure** | 70.64 ms | **42.28 ms** | `Hash Join` → `Hash Semi Join`. Using `EXISTS` eliminated the N×M row explosion. |

## This report were generated with help of Gemini by just summarizing the results of the performance analysis and optimization process and give it a good look . The original code and queries were executed in DataGrip 
