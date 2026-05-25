# PostgreSQL Indexes Task Files

## Load CSV data into PostgreSQL

https://www.kaggle.com/datasets/noahtaylson/elite-retail-transaction-dataset-uk?resource=download

Rename files:
- customers_master.csv -> customers.csv
- sales_raw_oltp.csv -> transactions.csv

Install dependency:

```bash
pip install psycopg2-binary
```

Run:

```bash
python load_csv_to_postgres.py \
  --host localhost \
  --port 5432 \
  --database retail \
  --user postgres \
  --password postgres \
  --customers-csv ./customers.csv \
  --transactions-csv ./transactions.csv \
  --truncate
```

The script expects these exact CSV headers:

Transactions:

```text
txn_id,customer_id,product_id,store_id,staff_id,quantity,payment_method,event_time
```

Customers:

```text
customer_id,first_name,last_name,email,phone,date_of_birth,gender,street_address,city,postcode,country,loyalty_tier,registration_date
```
