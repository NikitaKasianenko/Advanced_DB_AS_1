# Banking Fraud Monitoring System

## Project Overview

This project is an extended PostgreSQL database that simulates an internal fraud monitoring system for a bank. The system stores information about customers, their accounts and cards, processes transactions, and automatically detects suspicious transactions, tracks their status history, and maintains database audit logs.
## Setup Instructions

Run scripts in this exact order in DataGrip:

```
01_ddl.sql              → Tables, constraints
02_functions.sql        → Helper functions
03_procedures.sql       → Business logic procedures
04_triggers.sql         → Automated event handlers
05_views.sql            → Analytical views
06_materialized_views.sql → Cached fraud dashboard
07_sample_data.sql      → Test data
08_demo_queries.sql     → Demonstration queries
```

## Assumptions

- Currencies supported: UAH, USD, EUR
- A transaction can exist without a card (e.g. wire transfers)
- Account balance cannot go negative (enforced by CHECK constraint)
- Risk score range: 0–100

## Fraud Detection Logic

Risk score is calculated by `calculate_transaction_risk_score()`:

| Factor | Points |
|---|---|
| Amount > 10,000 | +25 |
| Amount > 5,000 | +15 |
| Amount > 1,000 | +5 |
| High-risk merchant country (KP, IR, SY...) | +25 |
| High-risk category (GAMBLING, CRYPTO...) | +20 |
| Night transaction (00:00–04:59) | +10 |
| Daily volume > 50,000 | +20 |
| Daily volume > 20,000 | +10 |
| 5+ transactions in last hour | +20 |
| 3+ transactions in last hour | +10 |

**Score → Status mapping:**
- 0–30: `APPROVED` (auto-approved)
- 31–59: `PENDING` (manual review)
- 60–100: `FLAGGED` (fraud alert created)

## Materialized View Refresh Strategy

`mv_daily_fraud_summary` is refreshed manually:
```sql
CALL refresh_fraud_dashboard();
```

## Project Summary

All requested technical PostgreSQL requirements have been successfully implemented:

**Constraints & Data Integrity:** Ensured full data integrity across all entities using primary keys, foreign keys, unique and check constraints.

**Functions & Procedures:** Written custom PL/pgSQL functions and stored procedures to encapsulate business logic including risk scoring, account management, and fraud alert creation.

**Triggers:** Implemented automated transaction risk evaluation on INSERT, balance deduction on approval, status history tracking on every status change, and customer deletion protection.

**Views & Materialized Views:** Created analytical views and a daily fraud summary materialized view utilizing CTEs and window functions for fast reporting.
