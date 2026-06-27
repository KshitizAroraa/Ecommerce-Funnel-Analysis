-- ============================================================
-- Funnel Analysis Queries
-- ============================================================

-- --------------------------------------------------------
-- 1. Overall Funnel: Unique users at each stage
-- --------------------------------------------------------
WITH funnel AS (
    SELECT
        SUM(CASE WHEN event_type = 'page_view'      THEN 1 ELSE 0 END) AS page_view_users,
        SUM(CASE WHEN event_type = 'product_view'   THEN 1 ELSE 0 END) AS product_view_users,
        SUM(CASE WHEN event_type = 'add_to_cart'    THEN 1 ELSE 0 END) AS add_to_cart_users,
        SUM(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) AS checkout_start_users,
        SUM(CASE WHEN event_type = 'purchase'       THEN 1 ELSE 0 END) AS purchase_users
    FROM (
        SELECT user_id, event_type
        FROM events
        GROUP BY user_id, event_type
    )
)
SELECT
    'page_view'      AS stage, page_view_users      AS unique_users FROM funnel
UNION ALL
SELECT 'product_view',   product_view_users   FROM funnel
UNION ALL
SELECT 'add_to_cart',    add_to_cart_users    FROM funnel
UNION ALL
SELECT 'checkout_start', checkout_start_users FROM funnel
UNION ALL
SELECT 'purchase',       purchase_users       FROM funnel;

-- --------------------------------------------------------
-- 2. Conversion & Drop-off Rates Between Each Stage
-- --------------------------------------------------------
WITH stage_counts AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type = 'page_view'      THEN user_id END) AS pv,
        COUNT(DISTINCT CASE WHEN event_type = 'product_view'   THEN user_id END) AS prv,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart'    THEN user_id END) AS atc,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS cs,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase'       THEN user_id END) AS pur
    FROM events
)
SELECT
    'page_view → product_view'    AS transition,
    pv   AS from_users,
    prv  AS to_users,
    ROUND(100.0 * prv  / pv,  2) AS conversion_rate_pct,
    ROUND(100.0 * (pv  - prv)  / pv,  2) AS dropoff_rate_pct
FROM stage_counts
UNION ALL
SELECT 'product_view → add_to_cart',   prv, atc,
    ROUND(100.0 * atc / prv, 2), ROUND(100.0 * (prv - atc) / prv, 2)
FROM stage_counts
UNION ALL
SELECT 'add_to_cart → checkout_start', atc, cs,
    ROUND(100.0 * cs  / atc, 2), ROUND(100.0 * (atc - cs)  / atc, 2)
FROM stage_counts
UNION ALL
SELECT 'checkout_start → purchase',    cs,  pur,
    ROUND(100.0 * pur / cs,  2), ROUND(100.0 * (cs  - pur) / cs,  2)
FROM stage_counts;

-- --------------------------------------------------------
-- 3. Funnel Breakdown by Device Type
-- --------------------------------------------------------
WITH device_funnel AS (
    SELECT
        s.device_type,
        COUNT(DISTINCT CASE WHEN e.event_type = 'page_view'      THEN e.user_id END) AS page_view_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'product_view'   THEN e.user_id END) AS product_view_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'add_to_cart'    THEN e.user_id END) AS add_to_cart_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'checkout_start' THEN e.user_id END) AS checkout_start_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'purchase'       THEN e.user_id END) AS purchase_users
    FROM events e
    JOIN sessions s ON e.session_id = s.session_id
    GROUP BY s.device_type
)
SELECT
    device_type,
    page_view_users,
    product_view_users,
    add_to_cart_users,
    checkout_start_users,
    purchase_users,
    ROUND(100.0 * purchase_users / NULLIF(page_view_users, 0), 2) AS overall_conversion_pct
FROM device_funnel
ORDER BY page_view_users DESC;

-- --------------------------------------------------------
-- 4. Funnel Breakdown by Acquisition Channel
-- --------------------------------------------------------
WITH channel_funnel AS (
    SELECT
        s.channel,
        COUNT(DISTINCT CASE WHEN e.event_type = 'page_view'      THEN e.user_id END) AS page_view_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'product_view'   THEN e.user_id END) AS product_view_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'add_to_cart'    THEN e.user_id END) AS add_to_cart_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'checkout_start' THEN e.user_id END) AS checkout_start_users,
        COUNT(DISTINCT CASE WHEN e.event_type = 'purchase'       THEN e.user_id END) AS purchase_users
    FROM events e
    JOIN sessions s ON e.session_id = s.session_id
    GROUP BY s.channel
)
SELECT
    channel,
    page_view_users,
    product_view_users,
    add_to_cart_users,
    checkout_start_users,
    purchase_users,
    ROUND(100.0 * purchase_users / NULLIF(page_view_users, 0), 2) AS overall_conversion_pct
FROM channel_funnel
ORDER BY overall_conversion_pct DESC;

-- --------------------------------------------------------
-- 5. Weekly Funnel Trends Over 6 Months
-- --------------------------------------------------------
SELECT
    strftime('%Y-W%W', e.timestamp)                                               AS week,
    COUNT(DISTINCT CASE WHEN e.event_type = 'page_view'      THEN e.user_id END) AS page_view_users,
    COUNT(DISTINCT CASE WHEN e.event_type = 'product_view'   THEN e.user_id END) AS product_view_users,
    COUNT(DISTINCT CASE WHEN e.event_type = 'add_to_cart'    THEN e.user_id END) AS add_to_cart_users,
    COUNT(DISTINCT CASE WHEN e.event_type = 'checkout_start' THEN e.user_id END) AS checkout_start_users,
    COUNT(DISTINCT CASE WHEN e.event_type = 'purchase'       THEN e.user_id END) AS purchase_users
FROM events e
GROUP BY week
ORDER BY week;

-- --------------------------------------------------------
-- 6. Top Drop-off Products (Added to Cart but Not Purchased)
-- --------------------------------------------------------
WITH cart_events AS (
    SELECT DISTINCT user_id, product_id
    FROM events
    WHERE event_type = 'add_to_cart'
      AND product_id IS NOT NULL
),
purchase_events AS (
    SELECT DISTINCT oi.product_id, o.user_id
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
),
abandonment AS (
    SELECT
        c.product_id,
        COUNT(*) AS cart_adds,
        COUNT(p.user_id) AS purchases,
        COUNT(*) - COUNT(p.user_id) AS abandoned
    FROM cart_events c
    LEFT JOIN purchase_events p ON c.product_id = p.product_id AND c.user_id = p.user_id
    GROUP BY c.product_id
)
SELECT
    a.product_id,
    pr.product_name,
    pr.subcategory,
    pr.price,
    a.cart_adds,
    a.purchases,
    a.abandoned,
    ROUND(100.0 * a.abandoned / NULLIF(a.cart_adds, 0), 2) AS abandonment_rate_pct
FROM abandonment a
JOIN products pr ON a.product_id = pr.product_id
ORDER BY abandonment_rate_pct DESC
LIMIT 10;
