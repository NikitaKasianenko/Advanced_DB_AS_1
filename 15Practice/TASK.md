# Getting Started with BigQuery

## 1 Point

## Goal

Become familiar with the BigQuery interface, execute your first SQL queries, and explore one of Google's public datasets.

> **Important:**
>
> * Use your **KSE Google account** if possible.
> * **Do not add a credit card or enable billing.** All tasks can be completed using BigQuery's free public datasets.

## Tasks

### 1. Access BigQuery

* Open the Google Cloud Console.
* Sign in with your KSE account.
* Open **BigQuery Studio**.
* If prompted, create a project (free) using your KSE account. Do **not** enable billing.

### 2. Explore the Interface

Find and briefly identify:

* Explorer panel
* SQL Query Editor
* Query Results section
* Public datasets

Take a screenshot of the BigQuery interface.

### 3. Run Your First Query

Execute the following query:

```sql
SELECT 'Hello, BigQuery!' AS message;
```

Take a screenshot of the result.

### 4. Query a Public Dataset

Run the following query:

```sql
SELECT
  name,
  SUM(number) AS total_births
FROM `bigquery-public-data.usa_names.usa_1910_current`
GROUP BY name
ORDER BY total_births DESC
LIMIT 10;
```

Answer the following questions:

1. Which name appears most frequently?
2. How many rows were returned?
3. Approximately how much data was processed?

### 5. Modify the Query

Change the previous query so that it returns only names starting with the letter **A**.

Hint:

```sql
WHERE name LIKE 'A%'
```

Limit the output to the top 10 names.

### 6. Reflection

In 2–3 sentences, answer:

* What is BigQuery?
* What surprised you the most during this practice?
* What advantages does using public datasets provide?

## Submission

Submit a PDF containing:

* Screenshot of the BigQuery interface.
* Screenshot of the `"Hello, BigQuery!"` query result.
* Screenshot of the public dataset query result.
* Answers to the three questions from Task 4.
* The modified SQL query from Task 5.
* Your short reflection from Task 6.
