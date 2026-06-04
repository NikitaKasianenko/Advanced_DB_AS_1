# Assignment: NoSQL Databases with MongoDB and Redis

## Overview

In this assignment, you will work with two widely used NoSQL technologies:

* **MongoDB** – a document-oriented database
* **Redis** – an in-memory key-value data store

The objective is to learn how NoSQL databases store data, perform CRUD operations, optimize query performance, and use Redis data structures for caching and fast data access.

---

# Learning Objectives

By completing this assignment, students will be able to:

* Design and populate MongoDB collections.
* Perform CRUD operations in MongoDB.
* Build aggregation pipelines.
* Analyze query performance using MongoDB tools.
* Create and use indexes to optimize queries.
* Work with Redis Strings, Hashes, Lists, Sets, and Sorted Sets.
* Implement caching using Redis TTL.
* Compare document databases and key-value stores.

---

# Part 1. MongoDB (7.5 points)

## Scenario

You are developing a backend database for an online bookstore.

Create a MongoDB database called:

```text
bookstore
```

Create a collection:

```text
books
```

Each document should contain the following fields:

```json
{
  "_id": ObjectId(),
  "title": "Clean Code",
  "author": "Robert C. Martin",
  "category": "Programming",
  "price": 35,
  "in_stock": true,
  "published_year": 2008,
  "rating": 4.8
}
```

---

## Task 1. Data Generation

Insert at least **30 books** into the collection.

Requirements:

* At least 4 different categories.
* At least 5 different authors.
* Various publication years.
* Various prices.

---

## Task 2. CRUD Operations

### Create

Insert at least 5 additional books.

### Read

Write queries to:

* Find all books in the "Programming" category.
* Find books published after 2015.
* Find books priced above $40.
* Find books currently in stock.
* Find books written by a specific author.
* Find books with a rating greater than 4.5.

### Update

Perform at least 3 updates:

* Change the price of a book.
* Update stock availability.
* Increase the rating of a selected book.

### Delete

Delete at least 2 books from the collection.

---

## Task 3. Aggregation Framework

Create aggregation pipelines to answer the following questions:

### Aggregation 1

Calculate:

* Average book price per category.

### Aggregation 2

Find:

* Number of books per category.

### Aggregation 3

Calculate:

* Average rating per category.

### Aggregation 4

Return:

* Top 5 most expensive books.

---

## Task 4. MongoDB Query Optimization

### Step 1. Analyze Query Performance

Run the following query:

```javascript
db.books.find({
    category: "Programming",
    published_year: { $gte: 2020 }
}).explain("executionStats")
```

Save the execution statistics.

Answer the following questions:

1. How many documents were scanned?
2. Was a collection scan performed?
3. What was the execution time?

---

### Step 2. Create an Index

Create a compound index:

```javascript
db.books.createIndex({
    category: 1,
    published_year: 1
})
```

---

### Step 3. Re-run Performance Analysis

Execute the same query again:

```javascript
db.books.find({
    category: "Programming",
    published_year: { $gte: 2020 }
}).explain("executionStats")
```

Compare the results before and after indexing.

---

### Step 4. Performance Report

Create a short report (1-2 pages) explaining:

* Why indexes improve performance.
* Differences between COLLSCAN and IXSCAN.
* How many documents were examined before and after indexing.
* Whether execution time improved.

Include screenshots of both execution plans.

---

## Deliverables

Submit:

* `mongodb_assignment.js`
* Screenshots of CRUD operations
* Screenshots of aggregation results
* Screenshots of execution plans
* Optimization report (`mongodb_optimization_report.pdf`)

---

# Part 2. Redis (7.5 points)

## Scenario

You are building a cache layer for an e-commerce platform.

---

## Task 1. String Operations

Store the following information using Strings:

```text
product:1:name
product:1:price
product:1:category
```

Retrieve all values.

---

## Task 2. Hash Operations

Create a product hash:

```text
product:2
```

Fields:

* name
* price
* category
* stock

Retrieve all fields.

---

## Task 3. List Operations

Create:

```text
recent_orders
```

Add at least 10 order IDs.

Display:

* All orders.
* The latest 3 orders.

---

## Task 4. Set Operations

Create:

```text
product_tags
```

Add at least 8 tags.

Demonstrate:

* Duplicate prevention.
* Membership check using SISMEMBER.

---

## Task 5. Expiration (TTL)

Create:

```text
featured_product
```

Set:

```text
TTL = 60 seconds
```

Show:

* Remaining TTL.
* Automatic expiration.

---

## Task 6. Cache Simulation

Simulate a cached product page:

```text
cache:product:1001
```

Store product information.

Requirements:

* Set expiration to 120 seconds.
* Retrieve cached value.
* Verify expiration time.

Explain why caching improves application performance.

---

## Deliverables

Submit:

* `redis_assignment.txt`
* Screenshots of all commands
* Short explanation of Redis use cases (`redis_notes.md`)

---

# Bonus (+2.5 points)

## Redis

Create a leaderboard using a Sorted Set:

```text
sales_leaderboard
```

Requirements:

* Store at least 5 products.
* Use sales count as score.
* Display ranking from highest to lowest.
* Display the top-selling product.

**Bonus Points: +2.5**

---

# Submission Structure

```text
assignment/
│
├── mongodb_assignment.js
├── mongodb_optimization_report.pdf
├── redis_assignment.txt
├── redis_notes.md
├── screenshots/
│   ├── mongodb/
│   └── redis/
└── README.md
```

---

# Grading Rubric

| Category                                |   Points |
| --------------------------------------- |---------:|
| MongoDB CRUD Operations                 |      2.5 |
| MongoDB Aggregations                    |      2.5 |
| MongoDB Query Optimization and Indexing |      2.5 |
| Redis Data Structures                   |      5.0 |
| Redis TTL and Cache Simulation          |      2.5 |
| **Core Assignment Total**               | **15.0** |
| Bonus: Redis Leaderboard (Sorted Set)   |      2.5 |
| **Maximum Total Score**                 | **17.5** |

---

# Evaluation Criteria

The following aspects will be evaluated:

* Correctness of commands and queries.
* Proper use of MongoDB aggregation framework.
* Understanding of indexing and query optimization.
* Correct use of Redis data structures.
* Quality of documentation and explanations.
* Completeness of submitted deliverables.

---

# Academic Integrity

Students must complete the assignment individually. All submitted code, screenshots, and reports should be the student's own work. Plagiarism or copying solutions from other students may result in a score of zero for the assignment.
