-- ============================================================================
-- PROJECT 1: E-COMMERCE SALES & CUSTOMER ANALYTICS
-- 20+ PRODUCTION-GRADE BUSINESS SQL QUERIES WITH DETAILED BUSINESS CONTEXT
-- Author: Gaurav | Senior Data Analyst
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: EXECUTIVE KPI SUMMARY
-- Business Purpose: Immediate health check of total revenue, profit, gross margin %, total orders, and average order value (AOV).
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_active_customers,
    SUM(revenue) AS total_net_revenue,
    SUM(profit) AS total_net_profit,
    ROUND((SUM(profit) / NULLIF(SUM(revenue), 0) * 100), 2) AS overall_profit_margin_pct,
    ROUND(SUM(revenue) / COUNT(DISTINCT order_id), 2) AS average_order_value_aov
FROM fact_order_items;

-- ----------------------------------------------------------------------------
-- QUERY 2: MONTHLY REVENUE, COST, PROFIT & MOM GROWTH RATE (WINDOW LAG)
-- Business Purpose: Track monthly top-line and bottom-line momentum and identify seasonal spikes/dips.
-- ----------------------------------------------------------------------------
WITH monthly_metrics AS (
    SELECT 
        TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(i.revenue) AS monthly_revenue,
        SUM(i.profit) AS monthly_profit,
        ROUND((SUM(i.profit) / NULLIF(SUM(i.revenue), 0) * 100), 2) AS profit_margin_pct
    FROM fact_orders o
    JOIN fact_order_items i ON o.order_id = i.order_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY TO_CHAR(o.order_date, 'YYYY-MM')
)
SELECT 
    year_month,
    total_orders,
    monthly_revenue,
    monthly_profit,
    profit_margin_pct,
    LAG(monthly_revenue) OVER (ORDER BY year_month) AS prev_month_revenue,
    ROUND(
        ((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year_month)) 
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY year_month), 0) * 100), 2
    ) AS mom_revenue_growth_pct
FROM monthly_metrics
ORDER BY year_month;

-- ----------------------------------------------------------------------------
-- QUERY 3: TOP 10 PROFIT-GENERATING PRODUCTS WITH CATEGORY BENCHMARKS
-- Business Purpose: Identify the core "cash cow" SKUs driving company profitability.
-- ----------------------------------------------------------------------------
SELECT 
    product_id,
    product_name,
    category,
    sub_category,
    SUM(quantity) AS total_units_sold,
    SUM(revenue) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND((SUM(profit) / NULLIF(SUM(revenue), 0) * 100), 2) AS profit_margin_pct
FROM fact_order_items
GROUP BY product_id, product_name, category, sub_category
ORDER BY total_profit DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- QUERY 4: DENSE RANKING OF TOP 3 PRODUCTS WITHIN EACH CATEGORY (WINDOW FUNCTION)
-- Business Purpose: Merchandising team needs to know category-wise bestsellers for promotional shelf space.
-- ----------------------------------------------------------------------------
WITH ranked_products AS (
    SELECT 
        category,
        sub_category,
        product_id,
        product_name,
        SUM(revenue) AS product_revenue,
        SUM(profit) AS product_profit,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY SUM(revenue) DESC) AS rank_in_category
    FROM fact_order_items
    GROUP BY category, sub_category, product_id, product_name
)
SELECT 
    category,
    rank_in_category,
    product_id,
    product_name,
    sub_category,
    product_revenue,
    product_profit
FROM ranked_products
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- ----------------------------------------------------------------------------
-- QUERY 5: RUNNING CUMULATIVE REVENUE OVER TIME (WINDOW RUNNING TOTAL)
-- Business Purpose: Track pace toward annual target milestones.
-- ----------------------------------------------------------------------------
SELECT 
    order_date,
    SUM(order_revenue) AS daily_revenue,
    SUM(SUM(order_revenue)) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_running_revenue
FROM fact_orders
WHERE order_status != 'Cancelled'
GROUP BY order_date
ORDER BY order_date;

-- ----------------------------------------------------------------------------
-- QUERY 6: CUSTOMER LIFETIME VALUE (LTV) & SEGMENTATION (RFM PROXY)
-- Business Purpose: Identify high-net-worth VIPs for exclusive loyalty retention programs.
-- ----------------------------------------------------------------------------
SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.customer_region,
    COUNT(DISTINCT o.order_id) AS total_orders_placed,
    SUM(o.order_revenue) AS lifetime_net_spend,
    SUM(o.order_profit) AS lifetime_profit_contribution,
    ROUND(AVG(o.order_revenue), 2) AS customer_avg_order_value,
    MAX(o.order_date) AS last_order_date
FROM dim_customers c
JOIN fact_orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.customer_region
ORDER BY lifetime_net_spend DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- QUERY 7: NEW VS REPEAT CUSTOMER ORDER CONTRIBUTION (FIRST ORDER VS REPEAT)
-- Business Purpose: Understand company reliance on customer acquisition vs repeat retention.
-- ----------------------------------------------------------------------------
WITH customer_order_history AS (
    SELECT 
        order_id,
        customer_id,
        order_date,
        order_revenue,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS order_sequence_num
    FROM fact_orders
    WHERE order_status != 'Cancelled'
)
SELECT 
    CASE 
        WHEN order_sequence_num = 1 THEN 'First-Time Purchase'
        ELSE 'Repeat Purchase'
    END AS purchase_type,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_revenue) AS total_revenue,
    ROUND((SUM(order_revenue) / SUM(SUM(order_revenue)) OVER () * 100), 2) AS revenue_share_pct
FROM customer_order_history
GROUP BY 
    CASE 
        WHEN order_sequence_num = 1 THEN 'First-Time Purchase'
        ELSE 'Repeat Purchase'
    END;

-- ----------------------------------------------------------------------------
-- QUERY 8: DISCOUNT ELASTICITY & MARGIN EROSION ANALYSIS
-- Business Purpose: Evaluate if steep discounting (>15%) creates incremental profit or erodes margins.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN discount_pct = 0.00 THEN '0% (No Discount)'
        WHEN discount_pct <= 0.10 THEN '1% - 10% (Mild Discount)'
        WHEN discount_pct <= 0.20 THEN '11% - 20% (Moderate Discount)'
        ELSE '20%+ (Aggressive Discount)'
    END AS discount_tier,
    COUNT(item_id) AS line_items_count,
    SUM(quantity) AS total_units_sold,
    SUM(revenue) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND((SUM(profit) / NULLIF(SUM(revenue), 0) * 100), 2) AS realized_margin_pct
FROM fact_order_items
GROUP BY 1
ORDER BY realized_margin_pct DESC;

-- ----------------------------------------------------------------------------
-- QUERY 9: REGIONAL & STATE-WISE SALES EFFICIENCY
-- Business Purpose: Supply chain allocation and geographic marketing ROI.
-- ----------------------------------------------------------------------------
SELECT 
    customer_region,
    customer_state,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_buyers,
    SUM(order_revenue) AS total_sales,
    SUM(order_profit) AS total_profit,
    ROUND(SUM(order_revenue) / COUNT(DISTINCT order_id), 2) AS regional_aov,
    ROUND((SUM(order_profit) / NULLIF(SUM(order_revenue), 0) * 100), 2) AS regional_margin_pct
FROM fact_orders
WHERE order_status = 'Delivered'
GROUP BY customer_region, customer_state
ORDER BY total_sales DESC;

-- ----------------------------------------------------------------------------
-- QUERY 10: PAYMENT METHOD POPULARITY & CANCELLATION RATE
-- Business Purpose: Identify payment friction or default rates (e.g. Cash on Delivery return rates).
-- ----------------------------------------------------------------------------
SELECT 
    payment_method,
    COUNT(order_id) AS total_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(
        (SUM(CASE WHEN order_status IN ('Cancelled', 'Returned') THEN 1 ELSE 0 END)::NUMERIC 
        / COUNT(order_id) * 100), 2
    ) AS fallout_rate_pct,
    SUM(order_revenue) AS gross_booked_revenue
FROM fact_orders
GROUP BY payment_method
ORDER BY total_orders DESC;

-- ----------------------------------------------------------------------------
-- QUERY 11: AVERAGE DELIVERY TIME BY REGION & STATUS
-- Business Purpose: Logistics SLA evaluation to identify regional shipping bottlenecks.
-- ----------------------------------------------------------------------------
SELECT 
    customer_region,
    COUNT(order_id) AS delivered_orders,
    ROUND(AVG(delivery_date - order_date), 2) AS avg_delivery_days,
    MIN(delivery_date - order_date) AS min_delivery_days,
    MAX(delivery_date - order_date) AS max_delivery_days
FROM fact_orders
WHERE order_status = 'Delivered' AND delivery_date IS NOT NULL
GROUP BY customer_region
ORDER BY avg_delivery_days ASC;

-- ----------------------------------------------------------------------------
-- QUERY 12: PRODUCTS WITH DECLINING REVENUE (MOM COMPARISON WITH LEAD/LAG)
-- Business Purpose: Detect stale inventory and early signs of product fatigue.
-- ----------------------------------------------------------------------------
WITH monthly_product_sales AS (
    SELECT 
        i.product_id,
        i.product_name,
        TO_CHAR(o.order_date, 'YYYY-MM') AS sales_month,
        SUM(i.revenue) AS monthly_rev
    FROM fact_order_items i
    JOIN fact_orders o ON i.order_id = o.order_id
    GROUP BY i.product_id, i.product_name, TO_CHAR(o.order_date, 'YYYY-MM')
),
lagged_sales AS (
    SELECT 
        product_id,
        product_name,
        sales_month,
        monthly_rev,
        LAG(monthly_rev) OVER (PARTITION BY product_id ORDER BY sales_month) AS prev_rev
    FROM monthly_product_sales
)
SELECT 
    product_id,
    product_name,
    sales_month,
    monthly_rev,
    prev_rev,
    ROUND(((monthly_rev - prev_rev) / NULLIF(prev_rev, 0) * 100), 2) AS decline_pct
FROM lagged_sales
WHERE prev_rev IS NOT NULL AND monthly_rev < prev_rev * 0.70 -- More than 30% drop
ORDER BY decline_pct ASC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- QUERY 13: CATEGORY CROSS-SELL MATRIX (BASKET ANALYSIS)
-- Business Purpose: Discover categories frequently purchased together in the same cart.
-- ----------------------------------------------------------------------------
SELECT 
    a.category AS category_a,
    b.category AS category_b,
    COUNT(DISTINCT a.order_id) AS co_purchase_frequency
FROM fact_order_items a
JOIN fact_order_items b ON a.order_id = b.order_id AND a.category < b.category
GROUP BY a.category, b.category
ORDER BY co_purchase_frequency DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- QUERY 14: PARETO 80/20 CUSTOMER CONCENTRATION
-- Business Purpose: Quantify what percentage of total revenue is driven by top 20% customers.
-- ----------------------------------------------------------------------------
WITH customer_totals AS (
    SELECT 
        customer_id,
        SUM(order_revenue) AS customer_revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(order_revenue) DESC) AS customer_rank,
        COUNT(*) OVER () AS total_customer_count
    FROM fact_orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
cumulative_pareto AS (
    SELECT 
        customer_id,
        customer_revenue,
        customer_rank,
        ROUND((customer_rank::NUMERIC / total_customer_count * 100), 2) AS customer_percentile,
        SUM(customer_revenue) OVER (ORDER BY customer_revenue DESC) AS running_rev_total,
        SUM(customer_revenue) OVER () AS overall_total_rev
    FROM customer_totals
)
SELECT 
    customer_percentile,
    ROUND((running_rev_total / overall_total_rev * 100), 2) AS cumulative_revenue_share_pct
FROM cumulative_pareto
WHERE customer_rank IN (
    ROUND(total_customer_count * 0.10),
    ROUND(total_customer_count * 0.20),
    ROUND(total_customer_count * 0.50),
    total_customer_count
)
ORDER BY customer_percentile;

-- ----------------------------------------------------------------------------
-- QUERY 15: HIGH VALUE ORDERS ANALYSIS (ABOVE 95TH PERCENTILE)
-- Business Purpose: Protect and optimize fulfillment for high-ticket basket sizes.
-- ----------------------------------------------------------------------------
WITH order_percentiles AS (
    SELECT 
        order_id,
        customer_id,
        order_revenue,
        NTILE(100) OVER (ORDER BY order_revenue) AS percentile_bucket
    FROM fact_orders
    WHERE order_status = 'Delivered'
)
SELECT 
    COUNT(order_id) AS high_value_orders_count,
    MIN(order_revenue) AS threshold_min_revenue,
    ROUND(AVG(order_revenue), 2) AS avg_high_value_order,
    SUM(order_revenue) AS total_high_value_revenue
FROM order_percentiles
WHERE percentile_bucket >= 95;

-- ----------------------------------------------------------------------------
-- QUERY 16: WEEKDAY VS WEEKEND REVENUE DYNAMICS
-- Business Purpose: Optimize ad spend and staffing between weekends and weekdays.
-- ----------------------------------------------------------------------------
SELECT 
    TO_CHAR(order_date, 'Day') AS day_of_week,
    EXTRACT(ISODOW FROM order_date) AS day_index,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_revenue) AS total_revenue,
    ROUND(AVG(order_revenue), 2) AS average_order_value
FROM fact_orders
WHERE order_status != 'Cancelled'
GROUP BY TO_CHAR(order_date, 'Day'), EXTRACT(ISODOW FROM order_date)
ORDER BY day_index;

-- ----------------------------------------------------------------------------
-- QUERY 17: PROFIT LEAKAGE FROM RETURNED ORDERS
-- Business Purpose: Quantify reverse logistics loss and identify problematic categories.
-- ----------------------------------------------------------------------------
SELECT 
    i.category,
    COUNT(DISTINCT o.order_id) AS returned_orders_count,
    SUM(i.revenue) AS gross_returned_value,
    SUM(i.cost) AS inventory_cost_locked,
    ROUND(
        (COUNT(DISTINCT o.order_id)::NUMERIC 
        / (SELECT COUNT(DISTINCT order_id) FROM fact_orders WHERE order_status = 'Delivered') * 100), 2
    ) AS category_return_intensity_pct
FROM fact_orders o
JOIN fact_order_items i ON o.order_id = i.order_id
WHERE o.order_status = 'Returned'
GROUP BY i.category
ORDER BY gross_returned_value DESC;

-- ----------------------------------------------------------------------------
-- QUERY 18: CUSTOMER COHORT RETENTION & SPEND OVER TIME
-- Business Purpose: Measure how customer cohorts acquired in Q1 perform across subsequent quarters.
-- ----------------------------------------------------------------------------
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        TO_CHAR(MIN(order_date), 'YYYY-"Q"Q') AS cohort_quarter
    FROM fact_orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
order_activity AS (
    SELECT 
        o.customer_id,
        c.cohort_quarter,
        TO_CHAR(o.order_date, 'YYYY-"Q"Q') AS order_quarter,
        o.order_revenue
    FROM fact_orders o
    JOIN customer_cohorts c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'Delivered'
)
SELECT 
    cohort_quarter,
    order_quarter,
    COUNT(DISTINCT customer_id) AS active_cohort_buyers,
    SUM(order_revenue) AS total_quarterly_spend
FROM order_activity
GROUP BY cohort_quarter, order_quarter
ORDER BY cohort_quarter, order_quarter;

-- ----------------------------------------------------------------------------
-- QUERY 19: UNPROFITABLE PRODUCT LINE DETECTOR
-- Business Purpose: Identify loss-making SKUs that need price adjustments or discontinuation.
-- ----------------------------------------------------------------------------
SELECT 
    product_id,
    product_name,
    category,
    sub_category,
    SUM(quantity) AS units_sold,
    SUM(revenue) AS net_revenue,
    SUM(cost) AS total_cost,
    SUM(profit) AS net_loss
FROM fact_order_items
GROUP BY product_id, product_name, category, sub_category
HAVING SUM(profit) < 0
ORDER BY net_loss ASC;

-- ----------------------------------------------------------------------------
-- QUERY 20: VIP CUSTOMER VELOCITY (DAYS BETWEEN CONSECUTIVE ORDERS)
-- Business Purpose: Benchmark re-order frequency to trigger re-engagement automations.
-- ----------------------------------------------------------------------------
WITH customer_order_dates AS (
    SELECT 
        customer_id,
        order_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date
    FROM fact_orders
    WHERE order_status = 'Delivered'
)
SELECT 
    customer_id,
    COUNT(order_id) AS repeat_orders_placed,
    ROUND(AVG(order_date - prev_order_date), 1) AS avg_days_between_orders,
    MIN(order_date - prev_order_date) AS min_days_between_orders,
    MAX(order_date - prev_order_date) AS max_days_between_orders
FROM customer_order_dates
WHERE prev_order_date IS NOT NULL
GROUP BY customer_id
HAVING COUNT(order_id) >= 4
ORDER BY avg_days_between_orders ASC
LIMIT 15;
