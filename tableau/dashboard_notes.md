# Tableau Dashboard Guide
## E-Commerce Funnel Revenue Analysis

---

## Data Sources to Connect

All files are in `data/processed/`. Connect these CSVs in Tableau:

| File | Use for |
|------|---------|
| `orders_enriched.csv` | Primary — orders joined with session & user info |
| `events.csv` | Funnel stage counts |
| `products.csv` | Product/subcategory dimensions |
| `order_items.csv` | Product-level revenue (join to orders_enriched on order_id) |
| `users.csv` | User demographics |
| `sessions.csv` | Session-level traffic |

---

## Recommended Dashboard Sheets (7 sheets, 1 dashboard)

---

### Sheet 1 — Funnel Overview (Bar Chart)
**Data source:** `events.csv`

| Field | Role |
|-------|------|
| event_type | Dimension → Rows (order manually: page_view, product_view, add_to_cart, checkout_start, purchase) |
| user_id (COUNTD) | Measure → Columns |

- Chart type: Horizontal Bar
- Add a calculated field: `Conversion % = COUNTD([user_id]) / WINDOW_MAX(COUNTD([user_id]))`
- Color: encode by stage
- Add label showing both count and %

---

### Sheet 2 — Monthly Revenue Trend (Line + Bar combo)
**Data source:** `orders_enriched.csv`  
Filter: `status = completed`

| Field | Role |
|-------|------|
| order_date (MONTH) | Columns |
| SUM(total_amount) | Rows (Bar) |
| AVG(total_amount) | Rows (Line, dual axis) |

- Dual axis chart: revenue bars + AOV line
- Format revenue axis as `$#,##0`

---

### Sheet 3 — Revenue by Channel (Horizontal Bar)
**Data source:** `orders_enriched.csv`  
Filter: `status = completed`

| Field | Role |
|-------|------|
| acquisition_channel | Rows |
| SUM(total_amount) | Columns |
| AVG(total_amount) | Color / tooltip |

- Sort descending by SUM(total_amount)
- Add reference line at average

---

### Sheet 4 — Funnel by Device (Grouped Bar)
**Data source:** `events.csv` joined with `sessions.csv` on session_id

| Field | Role |
|-------|------|
| event_type | Columns |
| COUNTD(user_id) | Rows |
| device_type | Color |

- Chart type: Grouped Bar
- Order event_type manually as funnel stages

---

### Sheet 5 — Top 10 Products by Revenue (Bar Chart)
**Data source:** `order_items.csv` joined with `products.csv` on product_id, joined with `orders_enriched.csv` on order_id  
Filter: `status = completed`

| Field | Role |
|-------|------|
| product_name | Rows |
| SUM(unit_price * quantity) | Columns — calculated field: `[unit_price] * [quantity]` |
| subcategory | Color |

- Top N filter: Top 10 by SUM revenue
- Sort descending

---

### Sheet 6 — Cohort Retention Heatmap
**Data source:** `orders_enriched.csv`  
Filter: `status = completed`

**Calculated fields needed:**

```
Cohort Month = DATETRUNC('month', {FIXED [user_id]: MIN([order_date])})

Month Number = DATEDIFF('month', [Cohort Month], DATETRUNC('month', [order_date]))

Cohort Size = {FIXED [Cohort Month]: COUNTD([user_id])}

Retention % = COUNTD([user_id]) / [Cohort Size] * 100
```

| Field | Role |
|-------|------|
| Cohort Month | Rows |
| Month Number | Columns |
| Retention % | Color (Red-Green diverging, 0-100) |
| Retention % | Label (format as 0.0%) |

- Chart type: Text/Heatmap
- Color: Sequential green (high retention) to red (low)

---

### Sheet 7 — Revenue by Subcategory (Treemap)
**Data source:** `order_items.csv` joined with `products.csv`  
Filter on orders: `status = completed`

| Field | Role |
|-------|------|
| subcategory | Label / Detail |
| SUM(unit_price * quantity) | Size |
| SUM(unit_price * quantity) | Color |

- Chart type: Treemap
- Color: Blue sequential

---

## Dashboard Layout

```
+---------------------------+---------------------------+
|   Sheet 1: Funnel         |   Sheet 2: Monthly Rev    |
|   Overview (Bar)          |   Trend (Line+Bar)        |
+---------------------------+---------------------------+
|   Sheet 3: Revenue by     |   Sheet 4: Funnel by      |
|   Channel                 |   Device                  |
+---------------------------+---------------------------+
|   Sheet 5: Top 10         |   Sheet 6: Cohort         |
|   Products                |   Retention Heatmap       |
+---------------------------+---------------------------+
|         Sheet 7: Revenue by Subcategory (Treemap)     |
+-------------------------------------------------------+
```

- Dashboard size: 1400 x 1200 px (fixed)
- Add a filter action: clicking a channel in Sheet 3 filters Sheet 2 and Sheet 5
- Add title: "E-Commerce Electronics — Funnel & Revenue Dashboard"

---

## Key Metrics to Show as KPI Cards (text boxes at top)

Add 4 KPI tiles above the charts using `Orders_enriched.csv`:

| KPI | Formula |
|-----|---------|
| Total Revenue | SUM(total_amount) where status=completed |
| Avg Order Value | AVG(total_amount) where status=completed |
| Conversion Rate | Purchases / Page Views (from events.csv) |
| Repeat Buyer Rate | Users with 2+ orders / total buyers |

---

## Publishing
1. Save as `.twbx` (packaged workbook) to include the CSV data
2. Publish to Tableau Public: **Server → Tableau Public → Save to Tableau Public**
