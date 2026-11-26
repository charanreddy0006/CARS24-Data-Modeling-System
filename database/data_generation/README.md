# Day 3 synthetic data generation

Day 3 adds deterministic operational cohorts to the existing Day 2 SQL Server model. The scripts target `CARS24DataModelingSystem`; they do not create or alter schema objects. This is an educational used-car marketplace model, not a representation of CARS24 internal systems.

## Completion status (operator-reported, 2026-11-26)

Preflight, all six generation phases, the Phase 04–06 independent read-only verifiers, and the final validator have reported PASS. Day 3 is **COMPLETE**. This README records operator-provided runtime evidence; no SQL Server connection or SQL execution was performed for this documentation update.

| Phase | Day 3 records | Result |
|---|---|---|
| 01 — Customers and staff | 21 employees, 21 roles, 97 customers, 172 contacts, 122 addresses | COMMITTED / PASS |
| 02 — Catalog and vehicle intake | 67 vehicles, 67 registrations, 67 ownership-history rows, 67 submissions | COMMITTED / PASS; zero exact-match skips in all four categories |
| 03 — Inspection and valuation | 62 inspections, 57 reports, 411 checklist items, 99 defects, 52 valuations | COMMITTED / PASS; independent counts matched and three relationship checks had 0 failures |
| 04 — Acquisition and inventory | 49 offers, 34 agreements, 31 acquisitions, 31 inventory positions, 54 movements | COMMITTED / PASS; zero skips; independent verifier 12/12 PASS |
| 05 — Marketplace activity | 34 listings, 119 images, 99 enquiries, 24 reservations | COMMITTED / PASS; independent verifier 28/28 PASS |
| 06 — Sales, finance, and delivery | 18 orders, 18 items, 26 payments, 5 refunds, 12 transfers, 12 deliveries, 8 sale-history rows, 8 dispatch movements | COMMITTED / PASS; zero skips for reported families; independent verifier 36/36 PASS |

The Phase 03 family counts sum to **681**. The earlier 721 aggregate was an arithmetic/reporting error. These are Day 3 additions, not cumulative totals.

## Final cumulative validation

The operator reports that `10_validate_generated_data.sql` returned **PASS**, `failed_check_count = 0`, and `total_detected_failure_count = 0`. The target database was reported ONLINE at compatibility level 170, and DBCC CHECKCONSTRAINTS completed without reported violation rows.

Selected cumulative actual/target counts reported by the operator:

| Table | Actual / target |
|---|---:|
| `vehicle.Vehicle` | 70 / 70 |
| `core.Customer` | 100 / 100 |
| `core.Employee` | 25 / 25 |
| `acquisition.PurchaseOffer` | 50 / 50 |
| `acquisition.PurchaseAgreement` | 35 / 35 |
| `acquisition.VehicleAcquisition` | 32 / 32 |
| `inventory.Inventory` | 32 / 32 |
| `inventory.InventoryMovement` | 63 / 63 |
| `marketplace.VehicleListing` | 35 / 35 |
| `marketplace.ListingImage` | 120 / 120 |
| `marketplace.CustomerEnquiry` | 100 / 100 |
| `marketplace.VehicleReservation` | 25 / 25 |
| `sales.SalesOrder` | 19 / 19 |
| `sales.SalesOrderItem` | 19 / 19 |
| `finance.Payment` | 27 / 27 |
| `finance.Refund` | 6 / 6 |
| `delivery.OwnershipTransfer` | 13 / 13 |
| `delivery.VehicleDelivery` | 13 / 13 |

Cumulative totals include the Day 2 baseline. For example, the Day 2 order, order item, payment, refund, transfer, and delivery each contribute one row to their respective totals. The final validator covers its implemented checks; it does not prove undocumented business rules or execution history.

## Requirements and safety

- SQL Server 2025 (17.x) or compatible supported instance; the reported target was `chakri\SQLEXPRESS`, database `CARS24DataModelingSystem`, compatibility level 170.
- Before any future generation run, the preflight must report PASS for the online/writable target, the expected 10 schemas and 34 tables, 34 PKs, 62 FKs, 19 unique constraints, 79 check constraints, 8 defaults, 113 total indexes (including 60 named explicit indexes), trusted/enabled objects, Day 2 fixtures, and zero conflicting Day 3 deterministic keys.
- The Day 2 seed fixture is a prerequisite and remains in place. The generation package does not repair fixture drift or reconcile unexpected rows automatically.
- The operator previously verified SQLCMD Shared Memory access in normal Windows CMD under `chakri\chara` with `sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`. The final-validator output did not include its exact command.
- Execute each generation phase individually and in order. Do not skip a phase or continue after a nonzero command exit, SQL error, conflict, or failed postcondition.
- Generation phases use deterministic cohorts, transactions, transaction-owned application locks, payload/conflict checks, and phase-specific postconditions. Later phases update earlier lifecycle state. Do not blindly rerun against the already-completed database.
- The scripts do not delete excess rows to force targets. A mismatch requires reconciliation, not cleanup by rerun.
- The independent verifiers and final validator are read-only with respect to persistent data. The final validator captures DBCC output and uses table variables; it does not repair data.

## CMD execution sequence

Run from the repository root in normal Windows CMD. Each command is separate. Review its output and `%ERRORLEVEL%`; proceed only when the command exits successfully and its SQL result is PASS/COMMITTED as applicable. If a step fails, stop and retain the output for diagnosis. These commands document the controlled sequence; **the existing validated database has already completed them and should not be regenerated**.

```cmd
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\00_pre_generation_checks.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\01_generate_customers_and_staff.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\02_generate_catalog_and_vehicle_intake.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\03_generate_inspection_and_valuation.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\04_generate_acquisition_and_inventory.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\11_verify_phase04_readonly.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\05_generate_marketplace_activity.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\12_verify_phase05_readonly.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\06_generate_sales_finance_delivery.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\13_verify_phase06_readonly.sql"
sqlcmd -S "lpc:.\SQLEXPRESS" -E -C -d "CARS24DataModelingSystem" -b -i "database\data_generation\10_validate_generated_data.sql"
```

Expected successful indications: preflight `readiness_status = PASS`; each generator `COMMITTED` and validation `PASS`; the three independent verifiers show 12/12, 28/28, and 36/36 checks passed; final validation shows `PASS`, zero failed checks, and zero detected failures. The verifier totals and SQL Server results above are operator-reported runtime evidence.

## File map and cumulative targets

| File | Purpose |
|---|---|
| `00_pre_generation_checks.sql` | Read-only database, structure, fixture, and deterministic-key readiness gate |
| `01_generate_customers_and_staff.sql` | Phase 01 |
| `02_generate_catalog_and_vehicle_intake.sql` | Phase 02 |
| `03_generate_inspection_and_valuation.sql` | Phase 03 |
| `04_generate_acquisition_and_inventory.sql` | Phase 04 |
| `11_verify_phase04_readonly.sql` | Independent Phase 04 verification |
| `05_generate_marketplace_activity.sql` | Phase 05 |
| `12_verify_phase05_readonly.sql` | Independent Phase 05 verification |
| `06_generate_sales_finance_delivery.sql` | Phase 06 |
| `13_verify_phase06_readonly.sql` | Independent Phase 06 verification |
| `10_validate_generated_data.sql` | Final cumulative and workflow validation |

Selected cumulative targets are 70 vehicles/registrations/submissions; 78 ownership-history rows; 32 inventory rows; 63 movements; 35 listings, 120 images, 100 enquiries, 25 reservations; 19 orders and order items; 27 payments; 6 refunds; 13 ownership transfers and deliveries. The complete target set is maintained in `10_validate_generated_data.sql`.

## Limitations and next milestone

The Day 2 model has no mileage/odometer column, normalized condition grade, or company-owner entity. Ownership history therefore cannot represent company ownership after acquisition. Customer details and `.invalid` email/image references are synthetic. DBCC CHECKCONSTRAINTS is not exhaustive proof of every application-level rule. Day 3 is complete; the next planned milestone is Day 4 planning, which is outside this package and was not started here.

## Reports

- `docs/24_day3_synthetic_generation_execution_report.md` — phase-by-phase runtime evidence.
- `docs/25_day3_final_validation_report.md` — final aggregate validation result.
- `docs/26_day3_completion_report.md` — Day 3 closure summary.
- `docs/28_day3_final_independent_code_review.md` — historical static-review findings and their targeted remediation.
- `docs/29_sql_server_local_connectivity_resolution.md` — historical connection troubleshooting and later successful Shared Memory use.
