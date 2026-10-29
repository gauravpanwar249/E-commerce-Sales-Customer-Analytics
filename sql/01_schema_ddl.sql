-- ============================================================================
-- E-COMMERCE SALES & CUSTOMER ANALYTICS — POSTGRESQL RELATIONAL SCHEMA
-- Author: Gaurav | Senior Data Analyst & Analytics Engineer
-- Database: PostgreSQL 14+ / Standard SQL
-- ============================================================================

-- 1. DROP EXISTING TABLES IF ANY (IN REVERSE DEPENDENCY ORDER)
DROP TABLE IF EXISTS fact_order_items CASCADE;
DROP TABLE IF EXISTS fact_orders CASCADE;
DROP TABLE IF EXISTS dim_products CASCADE;
DROP TABLE IF EXISTS dim_customers CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- 2. DIMENSION: CUSTOMERS
CREATE TABLE dim_customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_segment VARCHAR(30) CHECK (customer_segment IN ('VIP', 'Regular', 'Occasional')),
    customer_region VARCHAR(50) NOT NULL,
    customer_state VARCHAR(50) NOT NULL,
    customer_city VARCHAR(50) NOT NULL,
    customer_signup_date DATE NOT NULL
);

-- 3. DIMENSION: PRODUCTS & CATEGORIES
CREATE TABLE dim_products (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sub_category VARCHAR(50) NOT NULL,
    unit_price NUMERIC(10, 2) CHECK (unit_price > 0),
    unit_cost NUMERIC(10, 2) CHECK (unit_cost > 0)
);

-- 4. FACT: ORDERS (ORDER HEADER LEVEL)
CREATE TABLE fact_orders (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL REFERENCES dim_customers(customer_id),
    order_date DATE NOT NULL,
    delivery_date DATE,
    order_status VARCHAR(30) CHECK (order_status IN ('Delivered', 'Shipped', 'Cancelled', 'Returned')),
    payment_method VARCHAR(50) NOT NULL,
    total_items INT CHECK (total_items > 0),
    order_revenue NUMERIC(12, 2) NOT NULL,
    order_cost NUMERIC(12, 2) NOT NULL,
    order_profit NUMERIC(12, 2) NOT NULL,
    customer_region VARCHAR(50) NOT NULL,
    customer_state VARCHAR(50) NOT NULL,
    customer_city VARCHAR(50) NOT NULL
);

-- 5. FACT: ORDER ITEMS (TRANSACTION LINE ITEM LEVEL)
CREATE TABLE fact_order_items (
    item_id VARCHAR(20) PRIMARY KEY,
    order_id VARCHAR(20) NOT NULL REFERENCES fact_orders(order_id) ON DELETE CASCADE,
    product_id VARCHAR(20) NOT NULL REFERENCES dim_products(product_id),
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sub_category VARCHAR(50) NOT NULL,
    quantity INT CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,
    unit_cost NUMERIC(10, 2) NOT NULL,
    discount_pct NUMERIC(5, 4) DEFAULT 0.00,
    discount_amount NUMERIC(10, 2) DEFAULT 0.00,
    revenue NUMERIC(12, 2) NOT NULL,
    cost NUMERIC(12, 2) NOT NULL,
    profit NUMERIC(12, 2) NOT NULL
);

-- 6. INDEXES FOR HIGH-PERFORMANCE ANALYTICAL QUERIES
CREATE INDEX idx_orders_customer ON fact_orders(customer_id);
CREATE INDEX idx_orders_date ON fact_orders(order_date);
CREATE INDEX idx_order_items_product ON fact_order_items(product_id);
CREATE INDEX idx_order_items_category ON fact_order_items(category, sub_category);
CREATE INDEX idx_orders_status_region ON fact_orders(order_status, customer_region);

-- ============================================================================
-- BULK COPY COMMANDS (Run in psql terminal or PgAdmin)
-- ============================================================================
-- \copy dim_customers FROM '../data/dim_customers.csv' WITH (FORMAT csv, HEADER true);
-- \copy dim_products FROM '../data/dim_products.csv' WITH (FORMAT csv, HEADER true);
-- \copy fact_orders FROM '../data/fact_orders.csv' WITH (FORMAT csv, HEADER true);
-- \copy fact_order_items FROM '../data/fact_order_items.csv' WITH (FORMAT csv, HEADER true);
