-- ============================================================
-- E-Commerce Funnel Analysis - Database Schema
-- Electronics Category | 6-Month Synthetic Data
-- ============================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    user_id          INTEGER PRIMARY KEY,
    signup_date      DATE NOT NULL,
    country          TEXT NOT NULL,
    device_type      TEXT NOT NULL,
    acquisition_channel TEXT NOT NULL,
    age_group        TEXT,
    email            TEXT
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    product_id       INTEGER PRIMARY KEY,
    product_name     TEXT NOT NULL,
    category         TEXT NOT NULL DEFAULT 'Electronics',
    subcategory      TEXT NOT NULL,
    brand            TEXT,
    price            REAL NOT NULL,
    cost             REAL NOT NULL,
    stock_quantity   INTEGER
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    session_id       INTEGER PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(user_id),
    session_date     DATE NOT NULL,
    session_hour     INTEGER,
    device_type      TEXT NOT NULL,
    channel          TEXT NOT NULL,
    landing_page     TEXT
);

-- Events table (funnel steps)
-- event_type values: 'page_view', 'product_view', 'add_to_cart', 'checkout_start', 'purchase'
CREATE TABLE IF NOT EXISTS events (
    event_id         INTEGER PRIMARY KEY,
    session_id       INTEGER NOT NULL REFERENCES sessions(session_id),
    user_id          INTEGER NOT NULL REFERENCES users(user_id),
    event_type       TEXT NOT NULL CHECK(event_type IN ('page_view','product_view','add_to_cart','checkout_start','purchase')),
    product_id       INTEGER REFERENCES products(product_id),
    timestamp        DATETIME NOT NULL,
    page             TEXT
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    order_id         INTEGER PRIMARY KEY,
    session_id       INTEGER NOT NULL REFERENCES sessions(session_id),
    user_id          INTEGER NOT NULL REFERENCES users(user_id),
    order_date       DATE NOT NULL,
    total_amount     REAL NOT NULL,
    discount_amount  REAL NOT NULL DEFAULT 0,
    payment_method   TEXT NOT NULL,
    status           TEXT NOT NULL CHECK(status IN ('completed','returned','cancelled'))
);

-- Order Items table
CREATE TABLE IF NOT EXISTS order_items (
    item_id          INTEGER PRIMARY KEY,
    order_id         INTEGER NOT NULL REFERENCES orders(order_id),
    product_id       INTEGER NOT NULL REFERENCES products(product_id),
    quantity         INTEGER NOT NULL DEFAULT 1,
    unit_price       REAL NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_user    ON events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_type    ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_orders_user    ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_date    ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_sessions_user  ON sessions(user_id);
