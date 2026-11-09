-- =============================================================================
-- AutoPartsPro: 03_views_indexes.sql
-- Reusable views (so every report calculates revenue and cost the same way)
-- and indexes for the most common lookups.
-- =============================================================================

USE AutoPartsPro;

-- -----------------------------------------------------------------------------
-- PartCost: the cheapest current supplier cost for each part.
-- Assumption: the store restocks from its cheapest supplier, so this is used
-- as the cost of goods sold when calculating profit.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW PartCost AS
SELECT
    part_id,
    MIN(cost_price) AS unit_cost
FROM PartSupplier
GROUP BY part_id;

-- -----------------------------------------------------------------------------
-- OrderSummary: one row per order with customer, staff, item count and value.
-- Includes every status, so it can be used for operational lists too.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW OrderSummary AS
SELECT
    o.order_id,
    o.order_date,
    o.status,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    CONCAT(s.first_name, ' ', s.last_name)  AS staff_name,
    SUM(sl.quantity)                        AS items,
    SUM(sl.quantity * sl.sell_price_each)   AS order_value
FROM SalesOrders o
INNER JOIN Customers       c  ON c.customer_id = o.customer_id
INNER JOIN Staff           s  ON s.staff_id    = o.staff_id
INNER JOIN SalesOrderLines sl ON sl.order_id   = o.order_id
GROUP BY o.order_id, o.order_date, o.status, c.customer_id,
         c.first_name, c.last_name, s.first_name, s.last_name;

-- -----------------------------------------------------------------------------
-- DailySalesSummary: revenue, cost and gross profit per day.
-- Cancelled orders are excluded because they are not real sales.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW DailySalesSummary AS
SELECT
    o.order_date,
    COUNT(DISTINCT o.order_id)                               AS orders,
    SUM(sl.quantity)                                         AS parts_sold,
    SUM(sl.quantity * sl.sell_price_each)                    AS revenue,
    SUM(sl.quantity * pc.unit_cost)                          AS cost_of_goods,
    SUM(sl.quantity * (sl.sell_price_each - pc.unit_cost))   AS gross_profit
FROM SalesOrders o
INNER JOIN SalesOrderLines sl ON sl.order_id = o.order_id
INNER JOIN PartCost        pc ON pc.part_id  = sl.part_id
WHERE o.status <> 'cancelled'
GROUP BY o.order_date;

-- -----------------------------------------------------------------------------
-- Indexes
-- Primary keys, UNIQUE columns and foreign keys are indexed automatically (InnoDB).
-- These cover the extra searches the reports run most often.
-- -----------------------------------------------------------------------------

-- Date-range reports (daily/monthly sales) filter and group by order_date.
CREATE INDEX idx_orders_date ON SalesOrders (order_date);

-- Counter staff search for a part by category, then sort by price.
CREATE INDEX idx_parts_category_price ON Parts (category, unit_price);

-- Customers are often looked up by name at the counter.
CREATE INDEX idx_customers_name ON Customers (last_name, first_name);
