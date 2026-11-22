# CARS24 Data Modeling System

An educational used-car marketplace data model. This project does not describe CARS24 internal architecture.

## Project status

| Day | Status | Evidence boundary |
|---|---|---|
| Day 1 | Complete | Logical model and requirements passed the documented cross-review in `docs/10_day1_validation_report.md`. |
| Day 2 | Complete / checkpointed per project history | SQL Server implementation and fixture scripts are documented in `docs/12_day2_implementation_report.md` and `docs/13_day2_complete_sql_review_report.md`. |
| Day 3 | **In progress** | Pre-generation checks and Phases 01-03 passed. Phases 04-06 and the independent final validator have not been executed; Day 3 is not complete. |

## Day 3 runtime progress (2026-11-22)

Verified against `CARS24DataModelingSystem`:

- Pre-generation checks: **PASS**.
- Phase 01 - Customers and staff: **COMMITTED / PASS**; 21 employees, 21 roles, 97 customers, 172 contacts, and 122 addresses.
- Phase 02 - Catalog and vehicle intake: **COMMITTED / PASS**; 67 vehicles, 67 registrations, 67 ownership-history rows, and 67 submissions. Exact-match skips were zero in all four categories.
- The earlier failed Phase 02 attempt was verified to have rolled back completely before the successful rerun.
- Phase 03 - Inspection and valuation: **COMMITTED / PASS**; 62 inspections, 57 reports, 411 checklist items, 99 defects, and 52 valuations. Exact-match skips were zero. Independent read-only counts matched these five figures, and all three relationship checks returned failure_count 0.
- The first Phase 03 attempt failed on a missing closing parenthesis in the completed-inspection report predicate. Read-only counts confirmed zero Phase 03 rows after that attempt; the predicate was corrected before the successful run.
- Phases 04-06: **not executed**.
- Independent final validator: **not executed**.

The Phase 03 script reports inserted rows separately for each of its five families and does not emit an aggregate inserted-total field. Those verified family counts sum to **681**. The earlier figure of 721 was an erroneous aggregate in the supplied execution summary. The pending final validator means Day 3 is not complete.

## Day 3 package

The package contains a read-only preflight, six sequential generation phases, and a read-only independent validator under [`database/data_generation`](database/data_generation/README.md). Continue with Phase 04 after reviewing Phase 03's committed output; run later phases sequentially and stop on any failure. Run the independent validator after all phases.

## SQL Server connection

The reported successful Phase 01/02 execution used normal Windows CMD under `chakri\chara`, connecting to `chakri\SQLEXPRESS` with Shared Memory: `sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`. Earlier Codex shell connection failures occurred under a different Windows account and did not prevent that normal-CMD execution. TCP Windows Authentication troubleshooting remains documented in `docs/29_sql_server_local_connectivity_resolution.md`.

## Limitations and next milestone

The Day 3 generated values are synthetic. The model has documented domain limitations, and the generated-data checks depend on the documented Day 2 baseline. The next milestone is controlled execution of Phases 04-06 followed by the independent final validator. Day 3 should be marked complete only after these items pass.
