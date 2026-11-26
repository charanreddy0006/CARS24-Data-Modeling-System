# CARS24 Data Modeling System

An educational used-car marketplace data model. This project does not describe CARS24 internal architecture.

## Project status

| Day | Status | Evidence |
|---|---|---|
| Day 1 | Complete | Requirements and logical model review: [Day 1 validation report](docs/10_day1_validation_report.md). |
| Day 2 | Complete and checkpointed | SQL Server schema, constraints, indexes, and fixtures: [Day 2 implementation report](docs/12_day2_implementation_report.md). |
| Day 3 | **COMPLETE** | Operator-reported runtime PASS for preflight, all six generation phases, independent verification where packaged, and final validator. See [completion report](docs/26_day3_completion_report.md). |

## Day 3 generated cohorts

| Phase | Generated records | Runtime result |
|---|---|---|
| 01 — Customers and staff | 21 employees, 21 roles, 97 customers, 172 contacts, 122 addresses | COMMITTED / PASS |
| 02 — Catalog and intake | 67 vehicles, 67 registrations, 67 ownership-history rows, 67 submissions | COMMITTED / PASS; zero exact-match skips |
| 03 — Inspection and valuation | 62 inspections, 57 reports, 411 checklist items, 99 defects, 52 valuations | COMMITTED / PASS; independent counts and three relationship checks passed |
| 04 — Acquisition and inventory | 49 offers, 34 agreements, 31 acquisitions, 31 inventory positions, 54 movements | COMMITTED / PASS; 12/12 independent checks passed |
| 05 — Marketplace activity | 34 listings, 119 images, 99 enquiries, 24 reservations | COMMITTED / PASS; 28/28 independent checks passed |
| 06 — Sales, finance, and delivery | 18 orders, 18 items, 26 payments, 5 refunds, 12 transfers, 12 deliveries, 8 sale-history rows, 8 dispatch movements | COMMITTED / PASS; 36/36 independent checks passed |

Phase 03's five reported family counts sum to **681**; the earlier 721 aggregate was an arithmetic/reporting error. Cohort figures above are Day 3 additions. They are distinct from cumulative database counts, which include Day 2 fixtures.

## Final database validation

The operator reports that `database/data_generation/10_validate_generated_data.sql` returned **PASS**, with **0 failed checks** and **0 detected failures**. The database was reported **ONLINE** at compatibility level **170**; `DBCC CHECKCONSTRAINTS` completed without reported violation rows. Reported cumulative counts matched the validator targets, including 70 vehicles, 100 customers, 25 employees, 50 offers, 35 agreements, 32 acquisitions, 32 inventory positions, 63 movements, 35 listings, 120 images, 100 enquiries, 25 reservations, 19 orders, 19 order items, 27 payments, 6 refunds, 13 ownership transfers, and 13 deliveries.

These are operator-provided SQL Server runtime results. Codex did not connect to SQL Server or execute SQL. The validator covers its implemented checks; it is not a proof of every conceivable application rule.

## Day 3 package and execution

The package, phase order, prerequisites, reference CMD commands, and verification sequence are in [the Day 3 generation README](database/data_generation/README.md). The generation scripts are separate files: run preflight, phases 01–06 in order, each independent verifier after its phase, then the final validator. Stop on any command error or failed result. The existing database has already completed this sequence; these commands document reproducibility and are not a request to rerun generators.

The operator previously verified local SQLCMD access from normal Windows CMD under `chakri\chara` using Shared Memory: `sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`. The exact command used for the final validator run was not included with its result. Historical TCP/SSPI troubleshooting is in [the connectivity report](docs/29_sql_server_local_connectivity_resolution.md).

## Limitations and next milestone

The data is synthetic and depends on the documented Day 2 baseline. `DBCC CHECKCONSTRAINTS` and application validations cover declared and implemented rules only. The model has no odometer/mileage field or company-owner entity, so those concepts are not represented as normalized data. Day 3 is complete; the next planned milestone is Day 4 planning. Day 4 work was not started in this update.
