# 🌟 Power BI Star-Schema Data Model Specification

## 1. Architecture Overview
The data model follows an industry-standard **Star Schema** optimized for high-performance in-memory VertiPaq analytics.

```
       +--------------------+          +--------------------+
       |   dim_customers    |          |    dim_products    |
       |--------------------|          |--------------------|
       | customer_id (PK)   |<---+     | product_id (PK)    |<----+
       | customer_name      |    |     | product_name       |     |
       | customer_segment   |    |     | category           |     |
       | customer_region    |    |     | sub_category       |     |
       | customer_state     |    |     | unit_price         |     |
       | customer_city      |    |     | unit_cost          |     |
       +--------------------+    |     +--------------------+     |
                                 |                                |
                                 | 1:N                            | 1:N
                                 |                                |
       +--------------------+    |     +--------------------+     |
       |      dim_date      |    |     |  fact_order_items  |     |
       |--------------------|    |     |--------------------|     |
       | Date (PK)          |<---|--+  | item_id (PK)       |     |
       | Year               |    |  |  | order_id (FK)      |     |
       | Quarter            |    |  |  | product_id (FK)    |-----+
       | Month / MonthName  |    |  |  | quantity           |
       | WeekOfYear         |    |  |  | revenue            |
       | DayOfWeekName      |    |  |  | cost               |
       +--------------------+    |  |  | profit             |
                 |               |  |  +--------------------+
                 | 1:N           |  |            |
                 v               |  |            | N:1 (Bidirectional/Inactive)
       +--------------------+    |  |            v
       |    fact_orders     |    |  |  +--------------------+
       |--------------------|    |  |  |  dim_payment       |
       | order_id (PK)      |    |  |  |--------------------|
       | customer_id (FK)   |----+  |  | payment_method (PK)|
       | order_date (FK)    |-------+  +--------------------+
       | delivery_date      |
       | order_status       |
       | order_revenue      |
       | order_cost         |
       | order_profit       |
       +--------------------+
```

## 2. Table Classifications & Cardinalities
1. **Fact Tables**:
   - `fact_order_items`: Granular transaction line-item grain.
   - `fact_orders`: Header-level order grain.
2. **Dimension Tables**:
   - `dim_customers`: 1-to-Many (`1:*`) Single Direction filter to `fact_orders`.
   - `dim_products`: 1-to-Many (`1:*`) Single Direction filter to `fact_order_items`.
   - `dim_date`: 1-to-Many (`1:*`) Single Direction filter to `fact_orders[order_date]`.

## 3. Why a Dedicated Date Dimension (`dim_date`) is Required?
- Enables continuous calendar sequences without gaps for standard Time Intelligence functions (`TOTALYTD`, `SAMEPERIODLASTYEAR`, `DATEADD`).
- Avoids relying on transaction date columns which may skip holidays/weekends.
