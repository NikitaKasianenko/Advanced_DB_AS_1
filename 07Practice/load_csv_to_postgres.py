"""
Load Elite Retail CSV files into PostgreSQL.

This script creates two tables and inserts all rows from CSV files:
- customers.csv
- transactions.csv

Expected transaction CSV columns:
txn_id,customer_id,product_id,store_id,staff_id,quantity,payment_method,event_time

Expected customer CSV columns:
customer_id,first_name,last_name,email,phone,date_of_birth,gender,street_address,city,postcode,country,loyalty_tier,registration_date

Install:
    pip install psycopg2-binary

Run example:
    python load_csv_to_postgres.py \
        --host localhost \
        --port 5432 \
        --database retail \
        --user postgres \
        --password postgres \
        --customers-csv ./customers.csv \
        --transactions-csv ./transactions.csv
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Iterable

import psycopg2
from psycopg2.extensions import connection as PgConnection
from psycopg2.extras import execute_values


CUSTOMER_COLUMNS = [
    "customer_id",
    "first_name",
    "last_name",
    "email",
    "phone",
    "date_of_birth",
    "gender",
    "street_address",
    "city",
    "postcode",
    "country",
    "loyalty_tier",
    "registration_date",
]

TRANSACTION_COLUMNS = [
    "txn_id",
    "customer_id",
    "product_id",
    "store_id",
    "staff_id",
    "quantity",
    "payment_method",
    "event_time",
]


CREATE_CUSTOMERS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS customers (
    customer_id        BIGINT PRIMARY KEY,
    first_name         TEXT,
    last_name          TEXT,
    email              TEXT,
    phone              TEXT,
    date_of_birth      DATE,
    gender             TEXT,
    street_address     TEXT,
    city               TEXT,
    postcode           TEXT,
    country            TEXT,
    loyalty_tier       TEXT,
    registration_date  DATE
);
"""


CREATE_TRANSACTIONS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS transactions (
    txn_id          BIGINT PRIMARY KEY,
    customer_id     BIGINT REFERENCES customers(customer_id),
    product_id      BIGINT,
    store_id        BIGINT,
    staff_id        BIGINT,
    quantity        INTEGER,
    payment_method  TEXT,
    event_time      TIMESTAMP
);
"""

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load customers and transactions CSV files into PostgreSQL.")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--database", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--customers-csv", type=Path, required=True)
    parser.add_argument("--transactions-csv", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=10_000)
    parser.add_argument("--truncate", action="store_true", help="Delete existing table data before loading CSV files.")
    return parser.parse_args()


def connect(args: argparse.Namespace) -> PgConnection:
    return psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.database,
        user=args.user,
        password=args.password,
    )


def validate_csv_header(csv_path: Path, expected_columns: list[str]) -> None:
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    with csv_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        header = next(reader, None)

    if header != expected_columns:
        raise ValueError(
            f"Invalid header in {csv_path}.\n"
            f"Expected: {expected_columns}\n"
            f"Actual:   {header}"
        )


def batched_rows(csv_path: Path, columns: list[str], batch_size: int) -> Iterable[list[tuple[str, ...]]]:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        batch: list[tuple[str, ...]] = []

        for row in reader:
            batch.append(tuple(row[column] or None for column in columns))

            if len(batch) >= batch_size:
                yield batch
                batch = []

        if batch:
            yield batch


def create_tables(conn: PgConnection) -> None:
    with conn.cursor() as cur:
        cur.execute(CREATE_CUSTOMERS_TABLE_SQL)
        cur.execute(CREATE_TRANSACTIONS_TABLE_SQL)
    conn.commit()


def truncate_tables(conn: PgConnection) -> None:
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE transactions, customers RESTART IDENTITY CASCADE;")
    conn.commit()


def insert_csv(conn: PgConnection, table_name: str, columns: list[str], csv_path: Path, batch_size: int) -> int:
    column_sql = ", ".join(columns)
    insert_sql = f"""
        INSERT INTO {table_name} ({column_sql})
        VALUES %s
        ON CONFLICT DO NOTHING;
    """

    inserted_rows = 0
    with conn.cursor() as cur:
        for batch in batched_rows(csv_path, columns, batch_size):
            execute_values(cur, insert_sql, batch, page_size=batch_size)
            inserted_rows += len(batch)
            print(f"Loaded {inserted_rows:,} rows into {table_name}...")
    conn.commit()
    return inserted_rows


def main() -> None:
    args = parse_args()

    validate_csv_header(args.customers_csv, CUSTOMER_COLUMNS)
    validate_csv_header(args.transactions_csv, TRANSACTION_COLUMNS)

    with connect(args) as conn:
        create_tables(conn)

        if args.truncate:
            truncate_tables(conn)

        customers_count = insert_csv(
            conn=conn,
            table_name="customers",
            columns=CUSTOMER_COLUMNS,
            csv_path=args.customers_csv,
            batch_size=args.batch_size,
        )

        transactions_count = insert_csv(
            conn=conn,
            table_name="transactions",
            columns=TRANSACTION_COLUMNS,
            csv_path=args.transactions_csv,
            batch_size=args.batch_size,
        )


    print("Done.")
    print(f"Customers loaded:    {customers_count:,}")
    print(f"Transactions loaded: {transactions_count:,}")


if __name__ == "__main__":
    main()
