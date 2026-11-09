-- =============================================================================
-- AutoPartsPro: tests/constraint_tests.sql
-- Each statement below breaks a business rule and is EXPECTED TO FAIL.
-- If any of them succeeds, a constraint is missing.
--
-- Run from the command line so it continues after each error:
--   mysql -u root -p --force AutoPartsPro < tests/constraint_tests.sql
-- (In MySQL Workbench, run the statements one at a time.)
-- =============================================================================

USE AutoPartsPro;

-- T1. A part cannot have a zero or negative price            -> chk_parts_price
INSERT INTO Parts (part_name, category, unit_price, brand, warranty_months)
VALUES ('Test part', 'Braking', -5.00, 'TestBrand', 12);

-- T2. Categories are limited to the store's departments      -> chk_parts_category
INSERT INTO Parts (part_name, category, unit_price, brand, warranty_months)
VALUES ('Test part', 'Groceries', 10.00, 'TestBrand', 12);

-- T3. Stock on hand cannot go below zero                      -> chk_inventory_qty
UPDATE Inventory SET qty_on_hand = -1 WHERE part_id = 1;

-- T4. Order status must be one of the four allowed values      -> chk_order_status
INSERT INTO SalesOrders (order_date, customer_id, staff_id, status)
VALUES ('2026-11-01', 1, 1, 'shipped');

-- T5. An order cannot reference a customer who does not exist  -> fk_order_customer
INSERT INTO SalesOrders (order_date, customer_id, staff_id, status)
VALUES ('2026-11-01', 999, 1, 'pending');

-- T6. The same part cannot appear twice on one order           -> PRIMARY KEY (order_id, part_id)
INSERT INTO SalesOrderLines (order_id, part_id, quantity, sell_price_each)
VALUES (1, (SELECT part_id FROM (SELECT part_id FROM SalesOrderLines WHERE order_id = 1 LIMIT 1) x), 1, 10.00);

-- T7. Quantity on an order line must be positive              -> chk_line_qty
INSERT INTO SalesOrderLines (order_id, part_id, quantity, sell_price_each)
VALUES (1, 17, 0, 10.00);

-- T8. Two customers cannot share an email address              -> UNIQUE (email)
INSERT INTO Customers (first_name, last_name, email)
VALUES ('Copy', 'Cat', 'olivia.nguyen@mail.example');

-- T9. A model cannot end production before it starts           -> chk_model_years
INSERT INTO VehicleModels (make, model, year_from, year_to, engine_code)
VALUES ('Test', 'Model', 2020, 2010, 'X1');

-- T10. A part with stock or sales history cannot be deleted     -> fk_inventory_part / fk_line_part
DELETE FROM Parts WHERE part_id = 1;
