-- =============================================================================
-- AutoPartsPro: 04_reports.sql
-- Eight business reports. Each answers a question a store manager would ask.
-- Revenue figures exclude cancelled orders unless stated otherwise.
-- =============================================================================

USE AutoPartsPro;

-- -----------------------------------------------------------------------------
-- R1. Order summary
-- "Show me every order with its customer, staff member and total value."
-- customer_id is included because two customers can share a name.
-- -----------------------------------------------------------------------------
SELECT
    order_id,
    order_date,
    status,
    customer_id,
    customer_name,
    staff_name,
    items,
    order_value
FROM OrderSummary
ORDER BY order_date DESC;

-- -----------------------------------------------------------------------------
-- R2. Customer spend ranking
-- "Who are our most valuable customers?"
-- RANK() keeps ties on the same position.
-- -----------------------------------------------------------------------------
SELECT
    RANK() OVER (ORDER BY SUM(order_value) DESC)  AS spend_rank,
    customer_id,
    customer_name,
    COUNT(*)                                       AS orders,
    SUM(order_value)                               AS total_spend,
    ROUND(AVG(order_value), 2)                     AS avg_order_value
FROM OrderSummary
WHERE status <> 'cancelled'
GROUP BY customer_id, customer_name
ORDER BY spend_rank;

-- -----------------------------------------------------------------------------
-- R3. Best-selling parts
-- "Which parts sell the most?" (more than 5 units, using HAVING)
-- -----------------------------------------------------------------------------
SELECT
    p.part_id,
    p.part_name,
    p.category,
    SUM(sl.quantity)                       AS units_sold,
    SUM(sl.quantity * sl.sell_price_each)  AS revenue
FROM Parts p
INNER JOIN SalesOrderLines sl ON sl.part_id  = p.part_id
INNER JOIN SalesOrders     o  ON o.order_id  = sl.order_id
WHERE o.status <> 'cancelled'
GROUP BY p.part_id, p.part_name, p.category
HAVING units_sold > 5
ORDER BY units_sold DESC;

-- -----------------------------------------------------------------------------
-- R4. Reorder report with recommended supplier
-- "What is running low, how many should we order, from whom, and when will it arrive?"
-- The CTE ranks each part's suppliers by cost (then lead time); ROW_NUMBER() = 1
-- picks the best one. Order quantity tops stock back up to twice the reorder level.
-- -----------------------------------------------------------------------------
WITH ranked_suppliers AS (
    SELECT
        ps.part_id,
        s.supplier_name,
        ps.cost_price,
        ps.lead_time_days,
        ROW_NUMBER() OVER (PARTITION BY ps.part_id
                           ORDER BY ps.cost_price, ps.lead_time_days) AS supplier_rank
    FROM PartSupplier ps
    INNER JOIN Suppliers s ON s.supplier_id = ps.supplier_id
)
SELECT
    p.part_id,
    p.part_name,
    i.location_code,
    i.qty_on_hand,
    i.reorder_level,
    (2 * i.reorder_level - i.qty_on_hand)                      AS suggested_order_qty,
    rs.supplier_name                                           AS best_supplier,
    rs.cost_price,
    (2 * i.reorder_level - i.qty_on_hand) * rs.cost_price      AS estimated_cost,
    DATE_ADD(CURRENT_DATE, INTERVAL rs.lead_time_days DAY)     AS expected_arrival
FROM Parts p
INNER JOIN Inventory        i  ON i.part_id  = p.part_id
INNER JOIN ranked_suppliers rs ON rs.part_id = p.part_id AND rs.supplier_rank = 1
WHERE i.qty_on_hand < i.reorder_level
ORDER BY (i.qty_on_hand / i.reorder_level), p.part_name;    -- most urgent first

-- -----------------------------------------------------------------------------
-- R5. Compatibility search by registration number
-- "A customer is at the counter with rego 784QRB and needs brake parts.
--  What fits their car, what does it cost, and is it in stock?"
-- Change the two variables to search for another car or category.
-- -----------------------------------------------------------------------------
SET @rego     = '784QRB';
SET @category = 'Braking';

SELECT
    v.registration_number,
    CONCAT(vm.make, ' ', vm.model, ' (', vm.year_from, '-', COALESCE(vm.year_to, 'now'), ')') AS vehicle,
    p.part_id,
    p.part_name,
    p.brand,
    p.unit_price,
    i.qty_on_hand,
    CASE WHEN i.qty_on_hand > 0 THEN 'In stock' ELSE 'Order in' END AS availability
FROM Vehicles v
INNER JOIN VehicleModels     vm ON vm.model_id = v.model_id
INNER JOIN PartCompatibility pc ON pc.model_id = vm.model_id
INNER JOIN Parts             p  ON p.part_id   = pc.part_id
INNER JOIN Inventory         i  ON i.part_id   = p.part_id
WHERE v.registration_number = @rego
  AND p.category = @category
ORDER BY p.unit_price DESC;

-- -----------------------------------------------------------------------------
-- R6. Gross profit and margin by category
-- "Which product categories actually make us money?"
-- -----------------------------------------------------------------------------
WITH line_profit AS (
    SELECT
        p.category,
        sl.quantity * sl.sell_price_each                  AS revenue,
        sl.quantity * (sl.sell_price_each - pc.unit_cost) AS gross_profit
    FROM SalesOrderLines sl
    INNER JOIN SalesOrders o  ON o.order_id  = sl.order_id
    INNER JOIN Parts       p  ON p.part_id   = sl.part_id
    INNER JOIN PartCost    pc ON pc.part_id  = sl.part_id
    WHERE o.status <> 'cancelled'
)
SELECT
    category,
    SUM(revenue)                                     AS revenue,
    SUM(gross_profit)                                AS gross_profit,
    ROUND(100 * SUM(gross_profit) / SUM(revenue), 1) AS margin_pct,
    ROUND(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS share_of_revenue_pct
FROM line_profit
GROUP BY category
ORDER BY gross_profit DESC;

-- -----------------------------------------------------------------------------
-- R7. Monthly sales trend with running total
-- "How are sales tracking month by month, and year to date?"
-- Uses the DailySalesSummary view; the running total restarts each calendar year.
-- -----------------------------------------------------------------------------
WITH monthly AS (
    SELECT
        YEAR(order_date)                  AS sales_year,
        DATE_FORMAT(order_date, '%Y-%m')  AS sales_month,
        SUM(orders)                       AS orders,
        SUM(revenue)                      AS revenue,
        SUM(gross_profit)                 AS gross_profit
    FROM DailySalesSummary
    GROUP BY YEAR(order_date), DATE_FORMAT(order_date, '%Y-%m')
)
SELECT
    sales_month,
    orders,
    revenue,
    gross_profit,
    SUM(revenue) OVER (PARTITION BY sales_year ORDER BY sales_month) AS revenue_ytd
FROM monthly
ORDER BY sales_month;

-- -----------------------------------------------------------------------------
-- R8. Dead stock
-- "Which parts have never sold, and how much money is tied up in them?"
-- LEFT JOIN + IS NULL finds parts with no (non-cancelled) sales lines.
-- -----------------------------------------------------------------------------
SELECT
    p.part_id,
    p.part_name,
    p.category,
    i.qty_on_hand,
    pc.unit_cost,
    i.qty_on_hand * pc.unit_cost AS stock_value_at_cost
FROM Parts p
INNER JOIN Inventory i  ON i.part_id  = p.part_id
INNER JOIN PartCost  pc ON pc.part_id = p.part_id
LEFT JOIN (
    SELECT DISTINCT sl.part_id
    FROM SalesOrderLines sl
    INNER JOIN SalesOrders o ON o.order_id = sl.order_id
    WHERE o.status <> 'cancelled'
) sold ON sold.part_id = p.part_id
WHERE sold.part_id IS NULL
ORDER BY stock_value_at_cost DESC;
