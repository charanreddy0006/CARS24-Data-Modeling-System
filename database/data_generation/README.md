# Day 3 synthetic data generation

These are separate SQL scripts for `CARS24DataModelingSystem`. No SQLCMD file inclusion is used.

## Current status (2026-11-22)

Day 3 is **IN PROGRESS, NOT COMPLETE**. Runtime progress verified by the operator is:

| Step | Result | Runtime details |
|---|---|---|
| Pre-generation checks | **PASS** | Readiness checks passed for the target database. |
| Phase 01 - Customers and staff | **COMMITTED / PASS** | 21 employees, 21 roles, 97 customers, 172 contacts, 122 addresses. |
| Phase 02 - Catalog and vehicle intake | **COMMITTED / PASS** | 67 vehicles, 67 registrations, 67 ownership-history rows, 67 submissions; zero exact-match skips in all four categories. |
| Phase 03 - Inspection and valuation | **COMMITTED / PASS** | 62 inspections, 57 reports, 411 checklist items, 99 defects, 52 valuations; zero exact-match skips. Independent count query matched; all three relationship checks had failure_count 0. |
| Phase 04 - Acquisition and inventory | **COMMITTED / PASS** | 49 offers, 34 agreements, 31 acquisitions, 31 inventory positions, 54 movement rows; zero skips in all five families; 199 inserted total. |
| Phase 04 read-only verification | **PASS** | `11_verify_phase04_readonly.sql` returned 12 checks with `failure_count = 0`; the script is SELECT-only. |
| Failed Phase 02 attempt | **ROLLED BACK** | Full rollback was verified before the successful Phase 02 rerun. |
| Initial Phase 03 attempt | **FAILED BEFORE INSERTS** | A missing closing parenthesis in the completed-inspection report predicate caused a syntax error; read-only counts showed zero rows in all five target families. The syntax was corrected before the successful run. |
| Phases 05-06 | **NOT EXECUTED** | No runtime results are claimed. |
| Independent final validator | **NOT EXECUTED** | No final aggregate validation result is claimed. |

Phase 01-04 results are operator-reported runtime evidence. Phase 03's five family counts sum to 681; the earlier 721 figure was an erroneous aggregate in the supplied execution summary. Phase 04 inserted 199 records across its five families, and its independent read-only verifier returned 12 zero-failure checks. Static source review and runtime evidence are documented separately. Earlier connection failures from the Codex shell are historical and do not describe the successful normal Windows CMD execution. The Shared Memory method was verified for the reported Phase 01/02 runs. See `docs/23_day3_preflight_execution_report.md`, `docs/24_day3_synthetic_generation_execution_report.md`, and `docs/26_day3_completion_report.md` for execution reporting.

## Before continuing

1. Review the committed Phase 04 output and this execution status. Do not blindly rerun Phases 01-04.
2. Continue with Phase 05, then execute Phase 06. Review each phase's result sets and stop after any error, conflict, or failed validation.
3. Run `10_validate_generated_data.sql` only after all six phases complete successfully. Day 3 remains incomplete until its independent final validator passes.
4. Do not proceed if readiness is blocked, a fixture group fails, structural counts differ, a deterministic key conflicts, or actual rows exceed the plan unexpectedly. Scripts do not delete excess rows to force targets.
5. A rerun must reconcile exact payload and lifecycle state. Later phases update earlier cohort state; this package is not a blind rerunnable import.

## Files and cumulative targets

| File | Purpose | Selected cumulative targets |
|---|---|---|
| `00_pre_generation_checks.sql` | Read-only readiness, fixture integrity and collision report | 10 schemas, 34 tables; 34 PK, 62 FK, 19 UQ, 79 CHECK, 8 DEFAULT, 113 total indexes, 60 named explicit indexes |
| `01_generate_customers_and_staff.sql` | Employees, roles, customers, contacts, addresses | 25 employees/roles; 100 customers; 175 contacts; 125 addresses |
| `02_generate_catalog_and_vehicle_intake.sql` | Reuses catalog; adds intake cohort | 70 vehicles, registrations and submissions; 78 ownership rows after completed sales |
| `03_generate_inspection_and_valuation.sql` | Inspections, reports, checklist, defects, valuations | 65 / 60 / 420 / 100 / 55 |
| `04_generate_acquisition_and_inventory.sql` | Offers, agreements, acquisitions, inventory and ledger | 50 / 35 / 32 / 32 inventory rows / 63 movements |
| `11_verify_phase04_readonly.sql` | Independent read-only Phase 04 counts, payload, relationship, movement and lifecycle checks | 12 checks; expected `failure_count = 0` for each |
| `05_generate_marketplace_activity.sql` | Listings, images, enquiries, reservations | 35 / 120 / 100 / 25 |
| `06_generate_sales_finance_delivery.sql` | Orders, payments, refunds and fulfillment | 18 orders/items; 26 payments; 5 refunds; 12 transfers/deliveries |
| `10_validate_generated_data.sql` | Read-only final expected-payload and count/state/workflow checks | Independently reconstructs deterministic cohort payloads and aggregates mandatory failures |

Targets include the documented Day 2 baseline. The final validator treats these as exact cumulative totals for the documented clean baseline; any deviation requires reconciliation and is not corrected automatically. Phase 05 creates 18 active listings before sales (including the eight exact listings transitioned by Phase 06). Generation scripts use deterministic identifiers, transactions, transaction-owned application locks, payload checks and stop-on-conflict behavior. Some tables lack a universal batch key, and later phases update earlier cohort state.

## Model limitations

The schema has no odometer/mileage field, normalized condition grade, or company-owner entity. Ownership history is customer-only, so it cannot represent company ownership after acquisition. Generated names, contacts, and registration strings are synthetic; emails/image references use `.invalid`. Registration formats use a reserved synthetic `ZZ` series. No real personal data is used.

The independent validator uses read-only `DBCC CHECKCONSTRAINTS`. It has **not** been executed against the database; its aggregate result and live integrity checks remain pending. Exact total checks assume the documented Day 2 baseline. The fixture gate and validator source remediation are documented in `docs/27_day3_offline_remediation_completion_report.md` and `docs/28_day3_final_independent_code_review.md`.
