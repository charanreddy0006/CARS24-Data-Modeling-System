# SQL Server Implementation Standards

**Scope:** SQL Server physical implementation of all 34 finalized Day 1 relations. This document records the physical choices made for this educational project; it does not describe CARS24 internal systems.

## Naming and object placement

- Database: `CARS24DataModelingSystem`.
- Schemas: `ref` for City; `core` for branches, employees, and customers; `vehicle` for catalog, identity, ownership, and submissions; `inspection` for inspections, defects, and valuations; `acquisition` for offers, agreements, and acquisitions; `inventory` for current position and movement; `marketplace` for listings, images, enquiries, and reservations; `sales` for orders and items; `finance` for payment/refund attempts; `delivery` for ownership transfer and delivery.
- Tables use singular PascalCase entity names as in the logical model. Columns use `snake_case`.
- Constraint names use `PK_<Table>`, `FK_<Child>_<Parent>_<column>`, `UQ_<Table>_<columns>`, `CK_<Table>_<rule>`, and `DF_<Table>_<column>`.
- Index names use `IX_<Table>_<columns>`; unique indexes use `UX_<Table>_<columns>`.
- No spaces or reserved words in object names. All objects are schema-qualified in scripts.

## Types and key generation

- Logical identifiers are `INT IDENTITY(1,1)` primary keys. `INT` is adequate for the educational OLTP scope; use `BIGINT` only if measured growth requires it.
- Human-facing text uses bounded `NVARCHAR`: names (150), display names (150), address lines (200), branch address (500), and evidence-free descriptive text where applicable. No `NVARCHAR(MAX)` is used.
- Codes use bounded `VARCHAR` because identifiers and controlled codes are ASCII: most codes (30), country/state codes (2), PIN codes (6), VIN/chassis identifier (30), engine number (40), and registration number (15). Values are stored in normalized uppercase form where a code/identifier is used.
- `BIT` represents Boolean values.
- Calendar values use `DATE`; event instants use `DATETIME2(0)` and are stored in UTC. Conversion to local time is a presentation concern.
- Monetary amounts use `DECIMAL(19,4)` to preserve fractional currency precision without floating-point error. Amounts remain paired with ISO 4217 `CHAR(3)` currency codes; currency defaults to INR only where specified by the logical model.
- No floating-point type is used for money.
- Manufacture year uses `SMALLINT` and a static accepted range of 1886–2100. The upper bound is a stable guardrail because a time-dependent expression in a row check would not revalidate old rows as the year changes; revise through a reviewed schema change if the business range changes.

## Nulls, constraints, and codes

- `NOT NULL` follows the Day 1 mandatory (`*`) attributes. Optional (`?`) attributes remain nullable.
- Primary keys, foreign keys, uniqueness, row-level checks, and defaults are explicitly named.
- Fuel, transmission, lifecycle status, customer status, and other small controlled domains remain code columns with `CHECK` constraints. No FuelType/TransmissionType or status entities are introduced because Day 1 explicitly models these as codes.
- Case-insensitive unique identifiers use normalized uppercase values and explicit uniqueness. VIN is optional and unique when supplied; SQL Server's unique filtered index handles multiple NULLs.
- Date intervals use half-open `[valid_from, valid_to)` semantics. Checks enforce end after start; overlap prevention needs transactional logic.
- No cascade delete is used for business/history relationships.
- Variant-to-model consistency is enforced with a composite FK to the existing model/variant pair. This adds no entity or attribute.

## Audit and transactions

- Implement only audit attributes present in Day 1. Do not add generic `created_by`/`updated_at` columns to tables whose logical model does not contain them.
- Event timestamps are UTC. A staff actor is represented by a modeled employee FK when the relation defines one; no inferred actor fields are added.
- Multi-row lifecycle policies (owner projection synchronization, non-overlapping ownership intervals, simultaneous active registrations, seller/vehicle consistency on submissions, and state transitions) require transactional/application validation. Do not imply row checks solve them.
- Setup scripts are run in numeric order from a SQL Server connection with permission to create the named database. Database creation does not change server settings or drop an existing database.

## Script order

1. `00_pre_execution_checks.sql` (must pass before setup)
2. `00_run_complete_database_setup.sql` (generated master for the complete one-time setup)
3. Optional separate diagnostics: `11_post_execution_validation.sql`

The generated master embeds, in order, `01_create_database.sql`, `02_create_schemas.sql`, `03_reference_tables.sql`, `04_core_tables.sql`, `05_vehicle_catalog.sql`, `06_vehicle_identity.sql`, `07_lifecycle_tables.sql`, `08_constraints.sql`, `09_indexes.sql`, `10_seed_reference_data.sql`, and `11_post_execution_validation.sql`. Regenerate it with `generate_master_setup.ps1` after editing a source file. The master stops if the database name is already occupied; it never drops or overwrites an existing database. The modular scripts are retained for review and controlled recovery workflows.

## Policy and transaction boundary

The implementation uses checked code domains where Day 1 chose controlled codes, with initial code lists recorded in table DDL. Confirm the values with stakeholders before production. State transitions, interval overlap, owner projection synchronization, cross-entity party/vehicle matching, active hold uniqueness across listing history, completed-sale uniqueness, payment/order currency matching, and refund caps require transaction/application enforcement. Row checks and unique filtered indexes are used only where their scope accurately matches the rule.
