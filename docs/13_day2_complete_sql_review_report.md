# Day 2 Complete SQL Review and Execution Readiness

## Review scope

Reviewed the full Day 1 documentation set and ERDs together with every Day 2 SQL source file, both generated setup scripts, pre/post checks, and both PowerShell generators. The Day 1 model and documentation content were not changed; a trailing-whitespace-only cleanup was applied to `docs/01_business_requirements.md`.

This is an independent educational marketplace data model. It does not claim to represent CARS24's internal production design.

## Day 1 consistency and implemented architecture

All **34** finalized Day 1 entities are implemented, with the exact dictionary attributes and nullability reflected in DDL. Controlled domains remain code columns; no FuelType, TransmissionType, role catalog, or other new entity was added.

| Schema | Relations |
|---|---|
| `ref` | City |
| `core` | Branch, Employee, EmployeeRole, Customer, CustomerContact, CustomerAddress |
| `vehicle` | VehicleBrand, VehicleModel, VehicleVariant, Vehicle, VehicleRegistration, VehicleOwnershipHistory, VehicleSubmission |
| `inspection` | Inspection, InspectionReport, InspectionItem, Defect, VehicleValuation |
| `acquisition` | PurchaseOffer, PurchaseAgreement, VehicleAcquisition |
| `inventory` | Inventory, InventoryMovement |
| `marketplace` | VehicleListing, ListingImage, CustomerEnquiry, VehicleReservation |
| `sales` | SalesOrder, SalesOrderItem |
| `finance` | Payment, Refund |
| `delivery` | OwnershipTransfer, VehicleDelivery |

Physical inventory from the source DDL: **34 PKs, 62 FKs, 19 unique constraints, 79 check constraints, 8 defaults, and 60 explicit indexes**. The explicit indexes include 7 unique/filtered indexes. Including the indexes backing PKs and unique constraints, the expected SQL Server index count is **113**.

### Day 1 model discrepancies retained for review

1. The Day 1 validation report and logical ERD say 59 FK relationships. Counting the finalized relation attributes yields 62. Three modeled FKs are missing from the logical ERD: `InventoryMovement.from_branch_id`, `InventoryMovement.to_branch_id`, and `PurchaseAgreement.seller_customer_id`. DDL follows the explicit logical-model attributes; no Day 1 diagram was silently changed.
2. Acquisition is described as transfer into company ownership, but `Vehicle.current_owner_customer_id` and `VehicleOwnershipHistory.customer_id` only support `Customer`. The current model cannot represent the company as an owner. This requires an approved Day 1 model decision (for example, an owner-party abstraction) before claiming full legal-owner traceability. The SQL preserves the finalized attributes and records the limitation.

## Files reviewed

### SQL setup and validation

- `database/00_pre_execution_checks.sql`
- `database/00_run_complete_database_setup.sql` (generated)
- `database/00_continue_database_setup.sql` (generated existing-database continuation)
- `database/01_create_database.sql`
- `database/02_create_schemas.sql`
- `database/03_reference_tables.sql`
- `database/04_core_tables.sql`
- `database/05_vehicle_catalog.sql`
- `database/06_vehicle_identity.sql`
- `database/07_lifecycle_tables.sql`
- `database/08_constraints.sql`
- `database/09_indexes.sql`
- `database/10_seed_reference_data.sql`
- `database/11_post_execution_validation.sql`
- `database/generate_master_setup.ps1`
- `database/generate_continuation_setup.ps1`

The master script is generated from the canonical SQL files by `generate_master_setup.ps1`; it does not use SQLCMD mode or invalid file-include syntax. It contains SQL Server `GO` separators and embeds setup plus final validation. A session-context gate ensures an error in the initial version/database check causes later DDL, seed, and validation batches to be skipped even though SSMS can continue sending batches after a `THROW`.

The continuation script embeds canonical source scripts 02-11 in dependency order. Its fail-closed preflight resets a session gate, checks server/database state and full catalog visibility, reports existing schemas and expected-table count, and blocks on expected existing table/object names or any unexpected object in a managed schema. It distinguishes ready, partial-model, complete-model-present, and unexpected-object states. All later DDL, seed, and validation batches are gated. Each guarded batch uses TRY/CATCH to close the gate and rethrow on runtime failure, preventing later GO batches from continuing. It never includes the database creation script and contains no drop, truncate, or SQLCMD directives.

### Day 1 sources

- `docs/01_business_requirements.md`
- `docs/02_business_process_workflows.md`
- `docs/03_business_rules.md`
- `docs/04_entity_catalog.md`
- `docs/05_conceptual_data_model.md`
- `docs/06_logical_data_model.md`
- `docs/07_normalization_analysis.md`
- `docs/08_data_dictionary.md`
- `docs/09_design_decisions.md`
- `docs/10_day1_validation_report.md`
- `docs/11_sql_server_implementation_standards.md`
- `docs/12_day2_implementation_report.md`
- `docs/13_day2_complete_sql_review_report.md`
- `docs/er_diagrams/conceptual_erd.mmd`, `logical_erd.mmd`, `customer_vehicle_erd.mmd`, `inspection_valuation_erd.mmd`, `acquisition_inventory_erd.mmd`, and `marketplace_sales_erd.mmd`

## Static checks performed

- Parsed **34** source table declarations and **62** FK declarations.
- Compared the validation script's explicit expected-FK inventory with source DDL: **62 names matched, 0 missing, 0 unexpected**.
- Verified every FK child and parent table/column exists, FK column types match, and every target is a primary/unique key: **0 issues**.
- Checked parent tables occur before dependent FK creation: **0 ordering issues** and no unintended cycles.
- Compared DDL attributes with all 34 data-dictionary entities: **0 missing or undocumented columns**.
- Checked constraint names and explicit index names for duplicates: **none found**.
- Confirmed `SELECT *` does not occur in the SQL scripts.
- `git diff --check` passed.
- Reviewed seed order and code/check compatibility; all source inserts use parent-first ordering and deterministic synthetic identifiers. Runtime constraint enforcement remains unverified.

These checks are static. They do not prove SQL Server parser acceptance or runtime behavior.

## Issues found and corrected

- The first implementation covered only 14 entities. The requested full-model review now includes the remaining 20 relations and all 10 schema domains.
- Added the dependency-ordered lifecycle DDL before indexes/seeds, and extended the fixture chain across inspection, valuation, acquisition, stock, listing, reservation, order, payment/refund, transfer, and delivery.
- Added lifecycle FK indexes and filtered uniqueness structures for optional VIN/provider references, active listing/hold policies, and the one-item-per-order initial policy.
- Replaced a nullable `UNIQUE(reservation_id)` constraint with a filtered unique index. SQL Server's ordinary unique constraint would otherwise allow only one NULL reservation across unrelated order items.
- Expanded the validation script from the initial subset to all 34 tables, 10 schemas, key/constraint/index inventories, expected counts, seed counts, duplicate checks, temporal diagnostics, and `DBCC CHECKCONSTRAINTS`.
- Added exact-name runtime validation for all 62 foreign keys, including missing and unexpected FK result sets.
- Added a pre-execution guard and generated master script. Both stop rather than dropping or overwriting an existing target database.
- Added the existing-database continuation gate, including full metadata visibility, database-state and permission checks, unexpected managed-schema object detection, explicit partial/complete-model reporting, and per-batch error gates that stop later batches on runtime failures.
- Corrected the post-execution expected index total from 114 to 113 after reconciling all 60 explicit index statements with the 34 PK and 19 unique-constraint backing indexes; regenerated both master scripts.
- Tightened registration effective-date validation to match the documented half-open interval rule (`valid_to` must be after `valid_from`).
- Recorded, without modifying Day 1, the 59-versus-62 ERD relationship discrepancy and customer-only ownership limitation.

## SQL Server environment and execution status

SSMS showed a connection to `chakri\SQLEXPRESS`, Microsoft SQL Server 2025 Express Edition (64-bit), version `17.0.1000.7`, RTM, engine edition `4`, with `master` selected. `01_create_database.sql` ran successfully in that session. The target database now exists or was already present; whether it was newly created and its contents/state were not independently queried.

The remaining setup scripts and final validation were **not executed**. The computer-use bridge detected user input and stopped accepting further actions; command-line access from the agent execution context also failed. No successful runtime table, seed, or integrity results are claimed.

The new-database pre-check is expected to stop because the target database exists or was already present after the successful creation-script run. The generated continuation script now preflights the existing database and proceeds only if it is online, writable, compatible, and has no expected table/object names or unexpected tables in managed schemas. Expected existing tables, including partial implementation, are reported as conflicts; no automated repair or definition matching is attempted.

## Minimal SSMS workflow

1. Connect to `chakri\SQLEXPRESS` and select `master`.
2. Open `database/00_continue_database_setup.sql` and execute it once. Review the preflight Results and Messages. It either stops before DDL/seed batches with reported conflicts, or continues with schemas, tables, constraints, indexes, reference data, and final validation.
3. If it reports conflicts, inspect them in SSMS and determine a separate repair plan. Do not run the new-database master against this existing database.

Regenerate the continuation after source changes with `database/generate_continuation_setup.ps1`.

## Readiness status

**DAY 2 COMPLETED — READY FOR USER EXECUTION**. The implementation and continuation workflow are statically reviewed and fail closed when database preflight or object-conflict checks fail. SQL Server setup and post-execution validation have not been run; the actual target database contents/state remain unverified.
