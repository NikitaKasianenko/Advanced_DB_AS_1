# Databricks notebook source
FILE_PATH = "/Volumes/workspace/default/superstore/Sample - Superstore.csv"

spark.sql("CREATE DATABASE IF NOT EXISTS lakehouse_db")
spark.sql("USE lakehouse_db")

print("ready")

# COMMAND ----------

# =============================================================================
# TASK 1 — BRONZE LAYER
# load CSV and add ingestion metadata, save as Delta
# =============================================================================

from pyspark.sql import functions as F
from pyspark.sql.window import Window

raw_df = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(FILE_PATH)
)

print(f"rows loaded: {raw_df.count()}")

# COMMAND ----------

# rename columns — remove spaces ("Row ID" → "row_id")
bronze_df = (
    raw_df
    .withColumnRenamed("Row ID",       "row_id")
    .withColumnRenamed("Order ID",     "order_id")
    .withColumnRenamed("Order Date",   "order_date")
    .withColumnRenamed("Ship Date",    "ship_date")
    .withColumnRenamed("Ship Mode",    "ship_mode")
    .withColumnRenamed("Customer ID",  "customer_id")
    .withColumnRenamed("Customer Name","customer_name")
    .withColumnRenamed("Segment",      "segment")
    .withColumnRenamed("Country",      "country")
    .withColumnRenamed("City",         "city")
    .withColumnRenamed("State",        "state")
    .withColumnRenamed("Postal Code",  "postal_code")
    .withColumnRenamed("Region",       "region")
    .withColumnRenamed("Product ID",   "product_id")
    .withColumnRenamed("Category",     "category")
    .withColumnRenamed("Sub-Category", "sub_category")
    .withColumnRenamed("Product Name", "product_name")
    .withColumnRenamed("Sales",        "sales")
    .withColumnRenamed("Quantity",     "quantity")
    .withColumnRenamed("Discount",     "discount")
    .withColumnRenamed("Profit",       "profit")
    .withColumn("ingestion_timestamp", F.current_timestamp())
    .withColumn("source_file_name",    F.lit(FILE_PATH))
)

(
    bronze_df
    .write
    .format("delta")
    .mode("overwrite")
    .saveAsTable("lakehouse_db.bronze_orders")
)

print(f"bronze_orders created: {bronze_df.count()} rows")
bronze_df.select("row_id", "order_id", "sales", "ingestion_timestamp").show(5)

# COMMAND ----------

# =============================================================================
# TASK 2 — SILVER LAYER
# deduplicate, standardize text, validate data
# =============================================================================

bronze = spark.table("lakehouse_db.bronze_orders")

# deduplication via ROW_NUMBER — if row_id appears twice, keep the latest one
window_spec = Window.partitionBy("row_id").orderBy(F.col("ingestion_timestamp").desc())

deduplicated_df = (
    bronze
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn")
)

print(f"after dedup: {deduplicated_df.count()} (was {bronze.count()})")

# COMMAND ----------

# text standardization + cast numeric columns to correct types
standardized_df = (
    deduplicated_df
    .withColumn("customer_name", F.initcap(F.trim(F.col("customer_name"))))
    .withColumn("city",          F.initcap(F.trim(F.col("city"))))
    .withColumn("state",         F.initcap(F.trim(F.col("state"))))
    .withColumn("region",        F.upper(F.trim(F.col("region"))))
    .withColumn("category",      F.upper(F.trim(F.col("category"))))
    .withColumn("segment",       F.initcap(F.trim(F.col("segment"))))
    .withColumn("ship_mode",     F.initcap(F.trim(F.col("ship_mode"))))
    .withColumn("sales",         F.expr("try_cast(sales as double)"))
    .withColumn("quantity",      F.expr("try_cast(quantity as double)").cast("integer"))
    .withColumn("profit",        F.expr("try_cast(profit as double)"))
    .withColumn("discount",      F.expr("try_cast(discount as double)"))
    .withColumn("order_date_parsed", F.to_date(F.col("order_date"), "M/d/yyyy"))
    .withColumn("ship_date_parsed",  F.to_date(F.col("ship_date"),  "M/d/yyyy"))
)

# COMMAND ----------

# validation rules: sales >= 0, quantity > 0, ship_date not before order_date
valid_df = standardized_df.filter(
    (F.col("sales") >= 0) &
    (F.col("quantity") > 0) &
    (F.col("ship_date_parsed") >= F.col("order_date_parsed"))
)

rejected_df = standardized_df.filter(
    (F.col("sales") < 0) |
    (F.col("quantity") <= 0) |
    (F.col("ship_date_parsed") < F.col("order_date_parsed")) |
    F.col("sales").isNull()
)

rejected_df = rejected_df.withColumn(
    "rejection_reason",
    F.when(F.col("sales").isNull(),   "parse_error")
     .when(F.col("sales") < 0,        "negative_sales")
     .when(F.col("quantity") <= 0,    "invalid_quantity")
     .otherwise("ship_before_order")
)

print(f"valid:    {valid_df.count()}")
print(f"rejected: {rejected_df.count()}")

# COMMAND ----------

# save valid records to silver_orders, invalid to silver_rejected_orders
(
    valid_df
    .select(
        "row_id", "order_id", "order_date_parsed", "ship_date_parsed",
        "ship_mode", "customer_id", "customer_name", "segment",
        "country", "city", "state", "postal_code", "region",
        "product_id", "category", "sub_category", "product_name",
        "sales", "quantity", "discount", "profit",
        "ingestion_timestamp", "source_file_name"
    )
    .write.format("delta").mode("overwrite")
    .saveAsTable("lakehouse_db.silver_orders")
)

(
    rejected_df
    .write.format("delta").mode("overwrite")
    .saveAsTable("lakehouse_db.silver_rejected_orders")
)

print("silver layer done")
spark.table("lakehouse_db.silver_orders").show(5)

# COMMAND ----------

# =============================================================================
# TASK 3
# simulate 3 daily loads with partial overlap
# MERGE: if row_id exists → UPDATE, if new → INSERT
# =============================================================================

from delta.tables import DeltaTable

bronze_all = spark.table("lakehouse_db.bronze_orders")

def add_batch_metadata(df, batch_name):
    return (
        df
        .withColumn("ingestion_timestamp", F.current_timestamp())
        .withColumn("source_file_name", F.lit(f"batch/{batch_name}.csv"))
    )

# day_1: rows 1-3000
# day_2: rows 2500-6500 (overlap 2500-3000 with day_1)
# day_3: rows 6000-9994 (overlap 6000-6500 with day_2)
day_1 = add_batch_metadata(bronze_all.filter(F.col("row_id") <= 3000), "day_1")
day_2 = add_batch_metadata(bronze_all.filter((F.col("row_id") >= 2500) & (F.col("row_id") <= 6500)), "day_2")
day_3 = add_batch_metadata(bronze_all.filter(F.col("row_id") >= 6000), "day_3")

print(f"day_1: {day_1.count()} rows")
print(f"day_2: {day_2.count()} rows")
print(f"day_3: {day_3.count()} rows")

# COMMAND ----------

def clean_for_silver(raw_df):
    window_spec = Window.partitionBy("row_id").orderBy(F.col("ingestion_timestamp").desc())
    return (
        raw_df
        .withColumn("rn", F.row_number().over(window_spec))
        .filter(F.col("rn") == 1).drop("rn")
        .withColumn("sales",    F.expr("try_cast(sales as double)"))
        .withColumn("quantity", F.expr("try_cast(quantity as double)").cast("integer"))
        .withColumn("profit",   F.expr("try_cast(profit as double)"))
        .withColumn("discount", F.expr("try_cast(discount as double)"))
        .withColumn("customer_name", F.initcap(F.trim(F.col("customer_name"))))
        .withColumn("region",        F.upper(F.trim(F.col("region"))))
        .withColumn("category",      F.upper(F.trim(F.col("category"))))
        .withColumn("order_date_parsed", F.to_date(F.col("order_date"), "M/d/yyyy"))
        .withColumn("ship_date_parsed",  F.to_date(F.col("ship_date"),  "M/d/yyyy"))
        .filter((F.col("sales") >= 0) & (F.col("quantity") > 0))
        .select(
            "row_id", "order_id", "order_date_parsed", "ship_date_parsed",
            "ship_mode", "customer_id", "customer_name", "segment",
            "country", "city", "state", "postal_code", "region",
            "product_id", "category", "sub_category", "product_name",
            "sales", "quantity", "discount", "profit",
            "ingestion_timestamp", "source_file_name"
        )
    )

# COMMAND ----------

# initialize silver_incremental with day_1
silver_day1 = clean_for_silver(day_1)

(
    silver_day1
    .write.format("delta").mode("overwrite")
    .saveAsTable("lakehouse_db.silver_incremental")
)
print(f"initial load: {silver_day1.count()} rows")

# COMMAND ----------

# MERGE function — apply for day_2 and day_3
def merge_batch(new_batch_df, batch_name):
    target = DeltaTable.forName(spark, "lakehouse_db.silver_incremental")
    new_clean = clean_for_silver(new_batch_df)

    target.alias("target").merge(
        new_clean.alias("source"),
        "target.row_id = source.row_id"
    ).whenMatchedUpdateAll(
    ).whenNotMatchedInsertAll(
    ).execute()

    count = spark.table("lakehouse_db.silver_incremental").count()
    print(f"after MERGE {batch_name}: {count} rows")

merge_batch(day_2, "day_2")
merge_batch(day_3, "day_3")

# verify — result should match unique row_id count across all 3 days
all_unique = day_1.union(day_2).union(day_3).dropDuplicates(["row_id"]).count()
final_count = spark.table("lakehouse_db.silver_incremental").count()
print(f"expected: {all_unique}, actual: {final_count} — {'OK' if all_unique == final_count else 'MISMATCH'}")

# COMMAND ----------

# =============================================================================
# TASK 4 — GOLD LAYER
# aggregate data for business analytics
# =============================================================================

silver = spark.table("lakehouse_db.silver_orders")

# revenue by date
gold_sales_daily = (
    silver
    .groupBy("order_date_parsed")
    .agg(
        F.round(F.sum("sales"), 2).alias("revenue"),
        F.count("order_id").alias("order_count"),
        F.round(F.sum("profit"), 2).alias("total_profit")
    )
    .withColumnRenamed("order_date_parsed", "date")
    .orderBy("date")
)
gold_sales_daily.write.format("delta").mode("overwrite").saveAsTable("lakehouse_db.gold_sales_daily")
print(f"gold_sales_daily: {gold_sales_daily.count()} rows")
gold_sales_daily.show(5)

# COMMAND ----------

# revenue by region
gold_sales_region = (
    silver
    .groupBy("region")
    .agg(
        F.round(F.sum("sales"), 2).alias("revenue"),
        F.count("order_id").alias("order_count"),
        F.round(F.avg("discount"), 4).alias("avg_discount")
    )
    .orderBy(F.col("revenue").desc())
)
gold_sales_region.write.format("delta").mode("overwrite").saveAsTable("lakehouse_db.gold_sales_region")
print(f"gold_sales_region: {gold_sales_region.count()} rows")
gold_sales_region.show()

# COMMAND ----------

# revenue by category
gold_sales_category = (
    silver
    .groupBy("category", "sub_category")
    .agg(
        F.round(F.sum("sales"), 2).alias("revenue"),
        F.round(F.sum("profit"), 2).alias("total_profit"),
        F.count("order_id").alias("order_count")
    )
    .orderBy(F.col("revenue").desc())
)
gold_sales_category.write.format("delta").mode("overwrite").saveAsTable("lakehouse_db.gold_sales_category")
print(f"gold_sales_category: {gold_sales_category.count()} rows")
gold_sales_category.show()

# COMMAND ----------

# customer metrics
gold_customer_metrics = (
    silver
    .groupBy("customer_id", "customer_name", "segment")
    .agg(
        F.round(F.sum("sales"), 2).alias("revenue"),
        F.countDistinct("order_id").alias("orders"),
        F.round(F.sum("profit"), 2).alias("total_profit"),
        F.round(F.avg("sales"), 2).alias("avg_order_value")
    )
    .orderBy(F.col("revenue").desc())
)
gold_customer_metrics.write.format("delta").mode("overwrite").saveAsTable("lakehouse_db.gold_customer_metrics")
print(f"gold_customer_metrics: {gold_customer_metrics.count()} rows")
gold_customer_metrics.show(10)

# COMMAND ----------

# =============================================================================
# TASK 5
# analytical queries using window functions
# =============================================================================

spark.sql("USE lakehouse_db")

# COMMAND ----------

# top 5 products by revenue
spark.sql("""
    SELECT
        product_name,
        category,
        ROUND(SUM(sales), 2) AS revenue,
        ROUND(SUM(profit), 2) AS profit,
        COUNT(order_id) AS times_ordered
    FROM silver_orders
    GROUP BY product_name, category
    ORDER BY revenue DESC
    LIMIT 5
""").show(truncate=False)

# COMMAND ----------

# top region by revenue
spark.sql("""
    SELECT
        region,
        ROUND(SUM(sales), 2) AS revenue,
        ROUND(SUM(profit), 2) AS profit,
        COUNT(DISTINCT order_id) AS unique_orders
    FROM silver_orders
    GROUP BY region
    ORDER BY revenue DESC
    LIMIT 1
""").show()

# COMMAND ----------

# monthly revenue trend using LAG() — compare each month to the previous one
spark.sql("""
    WITH monthly AS (
        SELECT
            DATE_FORMAT(order_date_parsed, 'yyyy-MM') AS month,
            ROUND(SUM(sales), 2) AS revenue
        FROM silver_orders
        GROUP BY DATE_FORMAT(order_date_parsed, 'yyyy-MM')
    )
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
        ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS revenue_change,
        ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month) * 100, 1) AS change_pct
    FROM monthly
    ORDER BY month
""").show(20)

# COMMAND ----------

# running total using SUM() OVER()
spark.sql("""
    WITH daily AS (
        SELECT
            order_date_parsed AS date,
            ROUND(SUM(sales), 2) AS daily_revenue
        FROM silver_orders
        GROUP BY order_date_parsed
    )
    SELECT
        date,
        daily_revenue,
        ROUND(SUM(daily_revenue) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS running_total
    FROM daily
    ORDER BY date
""").show(10)

# COMMAND ----------

# top product per region using ROW_NUMBER()
spark.sql("""
    WITH product_revenue AS (
        SELECT region, product_name, ROUND(SUM(sales), 2) AS revenue
        FROM silver_orders
        GROUP BY region, product_name
    ),
    ranked AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY region ORDER BY revenue DESC) AS rn
        FROM product_revenue
    )
    SELECT region, product_name, revenue
    FROM ranked WHERE rn = 1
    ORDER BY revenue DESC
""").show()

# COMMAND ----------

# =============================================================================
# TASK 6 — PERFORMANCE ANALYSIS
# compare regular JOIN vs broadcast JOIN
# =============================================================================

silver_df = spark.table("lakehouse_db.silver_orders")
region_df  = spark.table("lakehouse_db.gold_sales_region")

# regular JOIN — Spark shuffles data between nodes (expensive)
slow_join = silver_df.join(region_df, on="region", how="left")
print("without broadcast — look for Exchange + SortMergeJoin:")
slow_join.explain(True)

# COMMAND ----------

# broadcast() — small table is replicated to all nodes, no shuffle needed
fast_join = silver_df.join(F.broadcast(region_df), on="region", how="left")
print("with broadcast() — look for BroadcastExchange + BroadcastHashJoin:")
fast_join.explain(True)

# COMMAND ----------

import time

start = time.time()
slow_join.agg(F.sum("sales")).collect()
slow_time = time.time() - start

start = time.time()
fast_join.agg(F.sum("sales")).collect()
fast_time = time.time() - start

print(f"without broadcast: {slow_time:.3f}s")
print(f"with broadcast:    {fast_time:.3f}s")
print(f"difference:        {(slow_time - fast_time) / slow_time * 100:.1f}%")

# COMMAND ----------

# MAGIC %md
# MAGIC # Task 7 — Documentation
# MAGIC
# MAGIC ## Architecture
# MAGIC
# MAGIC ```
# MAGIC superstore.csv
# MAGIC      ↓
# MAGIC  Bronze Layer
# MAGIC  bronze_orders — raw data + ingestion_timestamp + source_file_name
# MAGIC      ↓
# MAGIC  Silver Layer
# MAGIC  silver_orders          — deduplicated, standardized, validated
# MAGIC  silver_rejected_orders — invalid records (kept for audit)
# MAGIC      ↓
# MAGIC  Gold Layer
# MAGIC  gold_sales_daily       — revenue by date
# MAGIC  gold_sales_region      — revenue by region
# MAGIC  gold_sales_category    — revenue by category
# MAGIC  gold_customer_metrics  — metrics per customer
# MAGIC      ↓
# MAGIC  Analytics
# MAGIC  ROW_NUMBER, LAG, SUM OVER window functions
# MAGIC ```
# MAGIC
# MAGIC ## Data Flow
# MAGIC
# MAGIC | Step | From | To | Operation |
# MAGIC |------|------|----|-----------|
# MAGIC | 1 | superstore.csv | bronze_orders | Load raw CSV, add metadata |
# MAGIC | 2 | bronze_orders | silver_orders | Dedup, standardize, validate |
# MAGIC | 3 | bronze_orders | silver_incremental | Incremental MERGE INTO |
# MAGIC | 4 | silver_orders | gold_* | Aggregate for BI |
# MAGIC | 5 | silver_orders | analytics | Window functions |
# MAGIC
# MAGIC ## Data Quality Rules
# MAGIC
# MAGIC | Rule | Description |
# MAGIC |------|-------------|
# MAGIC | `sales >= 0` | No negative revenue |
# MAGIC | `quantity > 0` | At least 1 item per order |
# MAGIC | `ship_date >= order_date` | Cannot ship before ordering |
# MAGIC | `row_id` is unique | ROW_NUMBER() deduplication |
# MAGIC | Numeric parsing | `try_cast` — malformed values → NULL → rejected |
# MAGIC
# MAGIC ## Assumptions
# MAGIC
# MAGIC - `row_id` is the primary key for deduplication
# MAGIC - Dates are in `M/d/yyyy` format
# MAGIC - All amounts are in USD
# MAGIC - Dataset covers orders from 2014 to 2017
# MAGIC
# MAGIC ## Limitations
# MAGIC
# MAGIC - Daily load simulation is artificial (one file split into 3 batches)
# MAGIC - `inferSchema` may misdetect column types — handled via `try_cast`