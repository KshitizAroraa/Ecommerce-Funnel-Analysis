-- ============================================================
-- Cohort Analysis Queries
-- ============================================================

-- --------------------------------------------------------
-- 1. Monthly Cohorts Based on First Purchase Date
-- --------------------------------------------------------
WITH first_purchase AS (
    SELECT
        user_id,
        MIN(order_date) AS first_order_date,
        strftime('%Y-%m', MIN(order_date)) AS cohort_month
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    fp.cohort_month,
    cs.cohort_size,
    COUNT(DISTINCT fp.user_id) AS users_in_cohort
FROM first_purchase fp
JOIN cohort_sizes cs ON fp.cohort_month = cs.cohort_month
GROUP BY fp.cohort_month, cs.cohort_size
ORDER BY fp.cohort_month;

-- --------------------------------------------------------
-- 2. Cohort Retention: % of Users Purchasing in Subsequent Months
-- --------------------------------------------------------
WITH first_purchase AS (
    SELECT
        user_id,
        strftime('%Y-%m', MIN(order_date)) AS cohort_month
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
all_purchases AS (
    SELECT
        o.user_id,
        strftime('%Y-%m', o.order_date) AS purchase_month
    FROM orders o
    WHERE o.status = 'completed'
),
cohort_data AS (
    SELECT
        fp.cohort_month,
        ap.purchase_month,
        COUNT(DISTINCT ap.user_id) AS retained_users
    FROM first_purchase fp
    JOIN all_purchases ap ON fp.user_id = ap.user_id
    GROUP BY fp.cohort_month, ap.purchase_month
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    cd.cohort_month,
    cd.purchase_month,
    cs.cohort_size,
    cd.retained_users,
    ROUND(100.0 * cd.retained_users / cs.cohort_size, 2) AS retention_pct,
    -- Month index (0 = acquisition month)
    (
        (CAST(strftime('%Y', cd.purchase_month) AS INTEGER) - CAST(strftime('%Y', cd.cohort_month) AS INTEGER)) * 12
        + CAST(strftime('%m', cd.purchase_month) AS INTEGER) - CAST(strftime('%m', cd.cohort_month) AS INTEGER)
    ) AS month_number
FROM cohort_data cd
JOIN cohort_sizes cs ON cd.cohort_month = cs.cohort_month
ORDER BY cd.cohort_month, month_number;

-- --------------------------------------------------------
-- 3. Revenue per Cohort Over Time
-- --------------------------------------------------------
WITH first_purchase AS (
    SELECT
        user_id,
        strftime('%Y-%m', MIN(order_date)) AS cohort_month
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)
SELECT
    fp.cohort_month,
    strftime('%Y-%m', o.order_date) AS purchase_month,
    (
        (CAST(strftime('%Y', o.order_date) AS INTEGER) - CAST(strftime('%Y', fp.cohort_month || '-01') AS INTEGER)) * 12
        + CAST(strftime('%m', o.order_date) AS INTEGER) - CAST(strftime('%m', fp.cohort_month || '-01') AS INTEGER)
    ) AS month_number,
    COUNT(DISTINCT o.order_id)       AS total_orders,
    ROUND(SUM(o.total_amount), 2)    AS cohort_revenue,
    ROUND(AVG(o.total_amount), 2)    AS avg_order_value
FROM orders o
JOIN first_purchase fp ON o.user_id = fp.user_id
WHERE o.status = 'completed'
GROUP BY fp.cohort_month, purchase_month
ORDER BY fp.cohort_month, month_number;

-- --------------------------------------------------------
-- 4. Average Orders per User per Cohort
-- --------------------------------------------------------
WITH first_purchase AS (
    SELECT
        user_id,
        strftime('%Y-%m', MIN(order_date)) AS cohort_month
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
user_totals AS (
    SELECT
        fp.cohort_month,
        fp.user_id,
        COUNT(o.order_id)         AS user_order_count,
        SUM(o.total_amount)       AS user_total_revenue
    FROM first_purchase fp
    JOIN orders o ON fp.user_id = o.user_id AND o.status = 'completed'
    GROUP BY fp.cohort_month, fp.user_id
)
SELECT
    cohort_month,
    COUNT(DISTINCT user_id)               AS cohort_size,
    SUM(user_order_count)                 AS total_orders,
    ROUND(AVG(user_order_count), 2)       AS avg_orders_per_user,
    ROUND(SUM(user_total_revenue), 2)     AS total_revenue,
    ROUND(AVG(user_total_revenue), 2)     AS avg_revenue_per_user,
    ROUND(SUM(user_total_revenue) / SUM(user_order_count), 2) AS avg_order_value
FROM user_totals
GROUP BY cohort_month
ORDER BY cohort_month;
