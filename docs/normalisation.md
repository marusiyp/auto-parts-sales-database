# Normalisation: from one wide table to 3NF

This page shows how the sales data was normalised step by step, and which anomaly each step removes.

## Starting point: an unnormalised "wide" table

| order_id | order_date | customer_name | customer_email | staff_name | part_1 | qty_1 | part_2 | qty_2 |
|---|---|---|---|---|---|---|---|---|
| 1 | 2025-07-07 | Andrew Cole | a.cole@mail.example | Emily Ross | Air filter | 1 | Brake pads | 1 |
| 2 | 2025-07-21 | Bob Hale | b.hale@mail.example | Tom Walker | Oil filter | 2 | Fuel pump | 1 |
| 3 | 2025-07-27 | Alice Rivers | a.rivers@mail.example | Emily Ross | Battery | 1 | | |

**Problems:**
- **Repeating groups.** `part_1 / part_2` limits an order to two parts and leaves empty cells.
- **Update anomaly.** If Andrew changes his email, every one of his orders must be updated, and missing one leaves the data inconsistent.
- **Insert anomaly.** A new part cannot be recorded until someone buys it.
- **Delete anomaly.** Deleting Alice's only order also deletes everything we know about her.

## First Normal Form (1NF)

**Rule:** every cell holds one atomic value, and there are no repeating groups.

- Each part on an order gets its own row.
- `customer_name` is split into `first_name` and `last_name`, which makes searching and sorting by surname possible.

| order_id | order_date | first_name | last_name | customer_email | staff_name | part_name | quantity |
|---|---|---|---|---|---|---|---|
| 1 | 2025-07-07 | Andrew | Cole | a.cole@mail.example | Emily Ross | Air filter | 1 |
| 1 | 2025-07-07 | Andrew | Cole | a.cole@mail.example | Emily Ross | Brake pads | 1 |
| 2 | 2025-07-21 | Bob | Hale | b.hale@mail.example | Tom Walker | Oil filter | 2 |
| 2 | 2025-07-21 | Bob | Hale | b.hale@mail.example | Tom Walker | Fuel pump | 1 |
| 3 | 2025-07-27 | Alice | Rivers | a.rivers@mail.example | Emily Ross | Battery | 1 |

The key is now **(order_id, part_name)**. Customer details still repeat on every line, though.

## Second Normal Form (2NF)

**Rule:** 1NF, and no non-key column depends on only *part* of a composite key.

With the key (order_id, part_id):
- `order_date`, the customer and the staff member depend on **order_id only**, which is a partial dependency.
- `part_name` and `unit_price` depend on **part_id only**, which is also a partial dependency.
- `quantity` and `sell_price_each` depend on the **whole key**, so they stay.

Splitting along those dependencies gives:

- **SalesOrders** (`order_id` PK, order_date, customer details, staff details)
- **Parts** (`part_id` PK, part_name, unit_price, ...)
- **SalesOrderLines** (`order_id`, `part_id` composite PK, quantity, sell_price_each)

## Third Normal Form (3NF)

**Rule:** 2NF, and no transitive dependencies (a non-key column depending on another non-key column).

In SalesOrders, customer details still depend on the order only *through* the customer:

```
order_id -> customer_id -> first_name, last_name, email
order_id -> staff_id    -> staff first_name, last_name, role
```

Moving them into their own tables leaves only foreign keys behind:

- **Customers** (`customer_id` PK, first_name, last_name, email, phone)
- **Staff** (`staff_id` PK, first_name, last_name, email, role)
- **SalesOrders** (`order_id` PK, order_date, `customer_id` FK, `staff_id` FK, status)

The same reasoning creates the rest of the schema:

| Table | Why it exists |
|---|---|
| `Inventory` | Stock level and shelf location describe the part's stock, not the part itself (1:1 with Parts) |
| `Suppliers` + `PartSupplier` | Cost price and lead time depend on the **part and supplier together**, so they belong in an associative table |
| `VehicleModels` + `Vehicles` | Make, model and engine code describe a model, not each customer's car |
| `PartCompatibility` | Which parts fit which models is a many-to-many fact of its own |

## Final schema (3NF)

```
Customers         (customer_id PK, first_name, last_name, email UK, phone)
Staff             (staff_id PK, first_name, last_name, email UK, role)
Suppliers         (supplier_id PK, supplier_name UK, email UK, phone)
Parts             (part_id PK, part_name, category, unit_price, brand, warranty_months)
Inventory         (part_id PK/FK, qty_on_hand, reorder_level, location_code)
PartSupplier      (part_id PK/FK, supplier_id PK/FK, supplier_part_no, cost_price, lead_time_days)
VehicleModels     (model_id PK, make, model, year_from, year_to, engine_code)
Vehicles          (vehicle_id PK, model_id FK, customer_id FK, registration_number UK, colour)
PartCompatibility (part_id PK/FK, model_id PK/FK)
SalesOrders       (order_id PK, order_date, customer_id FK, staff_id FK, status)
SalesOrderLines   (order_id PK/FK, part_id PK/FK, quantity, sell_price_each)
```

**One deliberate repetition:** `sell_price_each` looks like a copy of `Parts.unit_price`, but it isn't. It records the price *at the time of sale*, which can differ from today's price or include a discount, so it depends on the order line rather than the part.

All four anomalies from the starting table are now gone:
- Each fact is stored once.
- Parts and customers can exist without orders.
- Deleting an order removes only that order.
