# Assignment: NoSQL Databases with MongoDB and Redis

## Overview

In this assignment, you will work with two popular NoSQL databases:

* **MongoDB** – document-oriented database
* **Redis** – in-memory key-value data store

The goal is to understand the differences between document storage and key-value storage, practice CRUD operations, and learn how to model and retrieve data efficiently.

---

# Part 1. MongoDB (7.5 points)

## Scenario

You are building a simple online bookstore.

Create a MongoDB database called `bookstore` and a collection called `books`.

Each document should contain:

```json
{
  "_id": ObjectId(),
  "title": "Clean Code",
  "author": "Robert C. Martin",
  "category": "Programming",
  "price": 35,
  "in_stock": true,
  "published_year": 2008
}
```

## Tasks

### 1. Insert Data

Insert at least **10 books** into the collection.

### 2. Query Data

Write queries to:

* Find all books in the "Programming" category.
* Find books published after 2015.
* Find books with a price greater than $40.
* Find books that are currently in stock.

### 3. Update Data

Update at least one book:

* Change its price.
* Change its stock status.

### 4. Delete Data

Delete one book from the collection.

### 5. Aggregation

Create an aggregation pipeline that:

* Calculates the average price per category.
* Counts the number of books in each category.

## Deliverables

Submit:

* MongoDB script (`mongodb_assignment.js`) containing all commands.
* Screenshots showing successful execution of queries and aggregation results.

---

# Part 2. Redis (7.5 points)

## Scenario

You are implementing a caching system for an e-commerce application.

## Tasks

### 1. String Operations

Store and retrieve:

* Product name
* Product price
* Product category

Example keys:

```
product:1:name
product:1:price
product:1:category
```

### 2. Hash Operations

Create a Redis Hash for a product:

```
product:2
```

Fields:

* name
* price
* category
* stock

Retrieve all fields.

### 3. List Operations

Create a list called:

```
recent_orders
```

Add at least 5 order IDs and retrieve all values.

### 4. Set Operations

Create a set called:

```
product_tags
```

Add at least 5 tags and verify that duplicates are not stored.

### 5. Expiration (TTL)

Create a cache key:

```
featured_product
```

Set an expiration time of 60 seconds and verify the remaining TTL.

## Deliverables

Submit:

* Redis script (`redis_assignment.txt` or `redis_assignment.redis`)
* Screenshots showing successful execution of all commands.

---

# Bonus Task (+2.5 points)


## Redis

Create a leaderboard using a Sorted Set:

```
sales_leaderboard
```

Store at least 5 products with sales counts and display the ranking from highest to lowest score.

**Bonus Points:** +2.5

---

# Submission Requirements

Submit a ZIP archive containing:

```
assignment/
│
├── mongodb_assignment.js
├── redis_assignment.txt
├── screenshots/
│   ├── mongodb/
│   └── redis/
└── README.md
```

---

# Grading Rubric

| Task                                        |   Points |
| ------------------------------------------- |---------:|
| MongoDB: Data insertion and CRUD operations |      3.0 |
| MongoDB: Queries and Aggregations           |      4.5 |
| Redis: Strings, Hashes, Lists, Sets         |      5.0 |
| Redis: TTL / Expiration                     |      2.5 |
| **Core Assignment Total**                   | **15.0** |
| Bonus: Redis Sorted Set Leaderboard         |      2.5 |
| **Maximum Total Score**                     | **17.5** |

---

# Academic Integrity

Students must complete the assignment individually. Copying solutions from other students or external sources without proper attribution may result in a score of zero for the assignment.
