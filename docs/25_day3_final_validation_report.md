# Day 3 Final Validation Report

**Updated:** 2026-11-26
**Outcome:** **PASS — operator-reported SQL Server runtime result**

## Runtime result

The operator reports manual execution of `database/data_generation/10_validate_generated_data.sql` against `CARS24DataModelingSystem` on `chakri\SQLEXPRESS`:

- `final_validation_status`: **PASS**
- `failed_check_count`: **0**
- `total_detected_failure_count`: **0**
- Database state: **ONLINE**
- Compatibility level: **170**
- `DBCC CHECKCONSTRAINTS`: completed without reported violation rows
- All reported cumulative table counts matched their targets.

The final validator source contains the corrected expected-listing reconstruction and cumulative targets that account for the Day 2 baseline. This report records operator-supplied runtime output; Codex did not connect to SQL Server or run the validator.

## Selected cumulative counts

These counts include Day 2 fixture rows and are not Day 3 additions.

| Table | Actual | Target |
|---|---:|---:|
| `vehicle.Vehicle` | 70 | 70 |
| `core.Customer` | 100 | 100 |
| `core.Employee` | 25 | 25 |
| `acquisition.PurchaseOffer` | 50 | 50 |
| `acquisition.PurchaseAgreement` | 35 | 35 |
| `acquisition.VehicleAcquisition` | 32 | 32 |
| `inventory.Inventory` | 32 | 32 |
| `inventory.InventoryMovement` | 63 | 63 |
| `marketplace.VehicleListing` | 35 | 35 |
| `marketplace.ListingImage` | 120 | 120 |
| `marketplace.CustomerEnquiry` | 100 | 100 |
| `marketplace.VehicleReservation` | 25 | 25 |
| `sales.SalesOrder` | 19 | 19 |
| `sales.SalesOrderItem` | 19 | 19 |
| `finance.Payment` | 27 | 27 |
| `finance.Refund` | 6 | 6 |
| `delivery.OwnershipTransfer` | 13 | 13 |
| `delivery.VehicleDelivery` | 13 | 13 |

The extra cumulative row in each of the last six families is the documented Day 2 seed fixture in addition to the Phase 06 cohort.

## Independent phase verification

The operator reports the independent read-only Phase 04, 05, and 06 verifiers returned **12/12**, **28/28**, and **36/36 PASS**, respectively. Phase 03's five counts were independently confirmed, and its three reported relationship checks each returned zero failures. See [the execution report](24_day3_synthetic_generation_execution_report.md) for phase counts and execution history.

## Evidence boundary and limitations

The runtime results above were supplied by the operator. This repository review did not access SQL Server, execute SQL, or modify database content. DBCC CHECKCONSTRAINTS and the validator cover declared constraints and implemented application checks; they do not certify every possible business rule, external integration, or execution-history property. Cumulative target comparisons assume the documented Day 2 baseline.

The SQLCMD command previously verified for normal Windows CMD Shared Memory access is `sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`. The exact command used for the final validator execution was not included in the supplied result.

## Completion

Based on the supplied runtime evidence, preflight, Phases 01–06, the independent phase verifiers, and final aggregate validation passed. Day 3 is **COMPLETE**. No SQL rerun is required for this documentation update. The next project milestone is Day 4 planning; it was not started here.
