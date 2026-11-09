-- =============================================================================
-- AutoPartsPro: Sales & Inventory Database
-- 01_schema.sql: creates the database and all 11 tables (3NF)
--
-- Run order: 01_schema.sql -> 02_seed_data.sql -> 03_views_indexes.sql -> 04_reports.sql
-- Written for MySQL 8.0 (also runs on MariaDB 10.11).
-- =============================================================================

DROP DATABASE IF EXISTS AutoPartsPro;
CREATE DATABASE AutoPartsPro;
USE AutoPartsPro;

-- -----------------------------------------------------------------------------
-- People
-- -----------------------------------------------------------------------------

CREATE TABLE Customers (
    customer_id  INT AUTO_INCREMENT PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(320) NOT NULL UNIQUE,   -- 320 = maximum length of an email address
    phone        VARCHAR(20)                      -- optional: email is the required contact
);

CREATE TABLE Staff (
    staff_id     INT AUTO_INCREMENT PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(320) NOT NULL UNIQUE,
    role         VARCHAR(30)  NOT NULL,
    CONSTRAINT chk_staff_role
        CHECK (role IN ('Store Manager', 'Parts Interpreter', 'Sales Assistant', 'Warehouse Officer'))
);

CREATE TABLE Suppliers (
    supplier_id   INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL UNIQUE,
    email         VARCHAR(320) NOT NULL UNIQUE,
    phone         VARCHAR(20)
);

-- -----------------------------------------------------------------------------
-- Products and stock
-- -----------------------------------------------------------------------------

CREATE TABLE Parts (
    part_id          INT AUTO_INCREMENT PRIMARY KEY,
    part_name        VARCHAR(100)  NOT NULL,
    category         VARCHAR(30)   NOT NULL,
    unit_price       DECIMAL(10,2) NOT NULL,   -- current retail price (AUD, incl. GST)
    brand            VARCHAR(50)   NOT NULL,
    warranty_months  INT           NOT NULL DEFAULT 0,
    CONSTRAINT chk_parts_category
        CHECK (category IN ('Braking', 'Filters', 'Cooling', 'Engine', 'Electrical', 'Suspension')),
    CONSTRAINT chk_parts_price    CHECK (unit_price > 0),
    CONSTRAINT chk_parts_warranty CHECK (warranty_months >= 0)
);

-- One row per part (1:1 with Parts), so part_id is both the primary and the foreign key.
CREATE TABLE Inventory (
    part_id        INT         PRIMARY KEY,
    qty_on_hand    INT         NOT NULL,
    reorder_level  INT         NOT NULL,
    location_code  VARCHAR(20) NOT NULL,       -- aisle-bay-shelf, e.g. 'A1-03-2'
    CONSTRAINT fk_inventory_part FOREIGN KEY (part_id) REFERENCES Parts(part_id),
    CONSTRAINT chk_inventory_qty     CHECK (qty_on_hand >= 0),
    CONSTRAINT chk_inventory_reorder CHECK (reorder_level >= 0)
);

-- Many-to-many: a part can be bought from several suppliers at different costs and lead times.
CREATE TABLE PartSupplier (
    part_id           INT           NOT NULL,
    supplier_id       INT           NOT NULL,
    supplier_part_no  VARCHAR(30)   NOT NULL,
    cost_price        DECIMAL(10,2) NOT NULL,
    lead_time_days    INT           NOT NULL,
    PRIMARY KEY (part_id, supplier_id),
    CONSTRAINT fk_ps_part     FOREIGN KEY (part_id)     REFERENCES Parts(part_id),
    CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id),
    CONSTRAINT chk_ps_cost CHECK (cost_price > 0),
    CONSTRAINT chk_ps_lead CHECK (lead_time_days >= 0)
);

-- -----------------------------------------------------------------------------
-- Vehicles and compatibility
-- -----------------------------------------------------------------------------

CREATE TABLE VehicleModels (
    model_id     INT AUTO_INCREMENT PRIMARY KEY,
    make         VARCHAR(50) NOT NULL,
    model        VARCHAR(50) NOT NULL,
    year_from    INT         NOT NULL,
    year_to      INT,                           -- NULL = still in production
    engine_code  VARCHAR(20) NOT NULL,
    CONSTRAINT uq_model UNIQUE (make, model, year_from, engine_code),
    CONSTRAINT chk_model_years CHECK (year_to IS NULL OR year_from <= year_to)
);

CREATE TABLE Vehicles (
    vehicle_id           INT AUTO_INCREMENT PRIMARY KEY,
    model_id             INT         NOT NULL,
    customer_id          INT         NOT NULL,
    registration_number  VARCHAR(10) NOT NULL UNIQUE,
    colour               VARCHAR(30),
    CONSTRAINT fk_vehicle_model    FOREIGN KEY (model_id)    REFERENCES VehicleModels(model_id),
    CONSTRAINT fk_vehicle_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- Many-to-many: which parts fit which vehicle models.
CREATE TABLE PartCompatibility (
    part_id   INT NOT NULL,
    model_id  INT NOT NULL,
    PRIMARY KEY (part_id, model_id),
    CONSTRAINT fk_pc_part  FOREIGN KEY (part_id)  REFERENCES Parts(part_id),
    CONSTRAINT fk_pc_model FOREIGN KEY (model_id) REFERENCES VehicleModels(model_id)
);

-- -----------------------------------------------------------------------------
-- Sales
-- -----------------------------------------------------------------------------

CREATE TABLE SalesOrders (
    order_id     INT AUTO_INCREMENT PRIMARY KEY,
    order_date   DATE        NOT NULL DEFAULT (CURRENT_DATE),  -- fixed dates are used in the sample data
    customer_id  INT         NOT NULL,
    staff_id     INT         NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    CONSTRAINT fk_order_staff    FOREIGN KEY (staff_id)    REFERENCES Staff(staff_id),
    CONSTRAINT chk_order_status
        CHECK (status IN ('pending', 'in progress', 'completed', 'cancelled'))
);

-- Associative entity between SalesOrders and Parts.
-- sell_price_each stores the price actually charged, so past orders keep their value
-- when Parts.unit_price changes later (and trade discounts can be recorded).
CREATE TABLE SalesOrderLines (
    order_id         INT           NOT NULL,
    part_id          INT           NOT NULL,
    quantity         INT           NOT NULL,
    sell_price_each  DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, part_id),
    CONSTRAINT fk_line_order FOREIGN KEY (order_id) REFERENCES SalesOrders(order_id),
    CONSTRAINT fk_line_part  FOREIGN KEY (part_id)  REFERENCES Parts(part_id),
    CONSTRAINT chk_line_qty   CHECK (quantity > 0),
    CONSTRAINT chk_line_price CHECK (sell_price_each > 0)
);
