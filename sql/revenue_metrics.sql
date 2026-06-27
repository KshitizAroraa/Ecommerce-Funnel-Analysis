-- ============================================================
-- Revenue Metrics Queries
-- ============================================================

-- --------------------------------------------------------
-- 1. Total Revenue, Total Orders, AOV by Month
-- --------------------------------------------------------
SELECT
    strftime('%Y-%m', order_date)             AS month,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) AS total_orders,
    ROUND(SUM(CASE WHEN status = 'completed' THEN total_amount ELSE 0 END), 2) AS total_revenue,
    ROUND(AVG(CASE WHEN status = 'completed' THEN total_amount END), 2) AS avg_order_value,
    ROUND(SUM(CASE WHEN status = 'completed' THEN discount_amount ELSE 0 END), 2) AS total_discounts
FROM orders
GROUP BY month
ORDER BY month;

-- --------------------------------------------------------
-- 2. Revenue by Acquisition Channel
-- --------------------------------------------------------
SELECT
    s.channel,
    COUNT(CASE WHEN o.status = 'completed' THEN 1 END)                                     AS total_orders,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END), 2)         AS total_revenue,
    ROUND(AVG(CASE WHEN o.status = 'completed' THEN o.total_amount END), 2)                AS avg_order_value,
    ROUND(100.0 * SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END)
          / SUM(SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END)) OVER(), 2) AS revenue_share_pct
FROM orders o
JOIN sessions s ON o.session_id = s.session_id
GROUP BY s.channel
ORDER BY total_revenue DESC;

-- --------------------------------------------------------
-- 3. Revenue by Device Type
-- --------------------------------------------------------
SELECT
    s.device_type,
    COUNT(CASE WHEN o.status = 'completed' THEN 1 END)                    AS total_orders,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END), 2) AS total_revenue,
    ROUND(AVG(CASE WHEN o.status = 'completed' THEN o.total_amount END), 2)        AS avg_order_value
FROM orders o
JOIN sessions s ON o.session_id = s.session_id
GROUP BY s.device_type
ORDER BY total_revenue DESC;

-- --------------------------------------------------------
-- 4. Revenue by Product Subcategory
-- --------------------------------------------------------
SELECT
    p.subcategory,
    COUNT(DISTINCT oi.order_id)                       AS total_orders,
    SUM(oi.quantity)                                  AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2)        AS gross_revenue,
    ROUND(AVG(oi.unit_price), 2)                      AS avg_unit_price,
    ROUND(SUM(oi.quantity * (oi.unit_price - p.cost)), 2) AS gross_profit
FROM order_items oi
JOIN products p  ON oi.product_id = p.product_id
JOIN orders   o  ON oi.order_id   = o.order_id
WHERE o.status = 'completed'
GROUP BY p.subcategory
ORDER BY gross_revenue DESC;

-- --------------------------------------------------------
-- 5. Top 10 Products by Revenue
-- --------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.subcategory,
    p.brand,
    p.price,
    COUNT(DISTINCT oi.order_id)                AS total_orders,
    SUM(oi.quantity)                           AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2)               AS avg_selling_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders   o ON oi.order_id   = o.order_id
WHERE o.status = 'completed'
GROUP BY p.product_id, p.product_name, p.subcategory, p.brand, p.price
ORDER BY total_revenue DESC
LIMIT 10;

-- --------------------------------------------------------
-- 6. Discount Impact Analysis
-- --------------------------------------------------------
SELECT
    CASE WHEN discount_amount > 0 THEN 'With Discount' ELSE 'No Discount' END AS discount_group,
    COUNT(*)                                AS total_orders,
    ROUND(AVG(total_amount), 2)             AS avg_order_value,
    ROUND(SUM(total_amount), 2)             AS total_revenue,
    ROUND(AVG(discount_amount), 2)          AS avg_discount,
    ROUND(100.0 * AVG(discount_amount)
          / NULLIF(AVG(total_amount + discount_amount), 0), 2) AS avg_discount_pct
FROM orders
WHERE status = 'completed'
GROUP BY discount_group;

-- Monthly discount trend
SELECT
    strftime('%Y-%m', order_date)           AS month,
    COUNT(*)                                AS total_orders,
    COUNT(CASE WHEN discount_amount > 0 THEN 1 END) AS discounted_orders,
    ROUND(100.0 * COUNT(CASE WHEN discount_amount > 0 THEN 1 END) / COUNT(*), 2) AS discount_rate_pct,
    ROUND(SUM(discount_amount), 2)          AS total_discounts_given,
    ROUND(SUM(total_amount), 2)             AS revenue_after_discounts
FROM orders
WHERE status = 'completed'
GROUP BY month
ORDER BY month;

-- --------------------------------------------------------
-- 7. Repeat Purchase Rate
-- --------------------------------------------------------
WITH user_order_counts AS (
    SELECT
        user_id,
        COUNT(*) AS order_count
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)
SELECT
    COUNT(*) AS total_buyers,
    COUNT(CASE WHEN order_count = 1  THEN 1 END) AS one_time_buyers,
    COUNT(CASE WHEN order_count >= 2 THEN 1 END) AS repeat_buyers,
    ROUND(100.0 * COUNT(CASE WHEN order_count >= 2 THEN 1 END) / COUNT(*), 2) AS repeat_purchase_rate_pct,
    ROUND(AVG(order_count), 2) AS avg_orders_per_buyer
FROM user_order_counts;

-- Repeat buyers breakdown
SELECT
    order_count AS orders_placed,
    COUNT(*) AS num_users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_of_buyers
FROM (
    SELECT user_id, COUNT(*) AS order_count
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)
GROUP BY order_count
ORDER BY order_count;
