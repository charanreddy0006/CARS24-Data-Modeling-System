# CARS24 Data Modeling System

An educational used-car marketplace data model. This project does not describe CARS24 internal architecture.

## Project status

| Day | Status | Evidence boundary |
|---|---|---|
| Day 1 | Complete | Logical model and requirements passed the documented cross-review in `docs/10_day1_validation_report.md`. |
| Day 2 | Complete / checkpointed per project history | SQL Server implementation and fixture scripts are documented in `docs/12_day2_implementation_report.md` and `docs/13_day2_complete_sql_review_report.md`. |
| Day 3 | **In progress** | Pre-generation checks passed. Phases 01 and 02 committed successfully with PASS results. Phases 03-06 and the independent final validator have not been executed; Day 3 is not complete. |

## Day 3 runtime progress (2026-11-21)

Verified against `CARS24DataModelingSystem`:

- Pre-generation checks: **PASS**.
- Phase 01 - Customers and staff: **COMMITTED / PASS**; 21 employees, 21 roles, 97 customers, 172 contacts, and 122 addresses.
- Phase 02 - Catalog and vehicle intake: **COMMITTED / PASS**; 67 vehicles, 67 registrations, 67 ownership-history rows, and 67 submissions. Exact-match skips were zero in all four categories.
- The earlier failed Phase 02 attempt was verified to have rolled back completely before the successful rerun.
- Phases 03-06: **not executed**.
- Independent final validator: **not executed**.

These results record the verified preflight and phase outputs. They do not establish final Day 3 validation or completion.

## Day 3 package

The package contains a read-only preflight, six sequential generation phases, and a read-only independent validator under [`database/data_generation`](database/data_generation/README.md). Continue with Phase 03 only after reviewing Phase 02's committed output; run later phases sequentially and stop on any failure. Run the independent validator after all phases.

## SQL Server connection

The verified execution used normal Windows CMD under `chakri\chara`, connecting to `chakri\SQLEXPRESS` with Shared Memory: `sqlcmd -S "lpc:.\SQLEXPRESS" -E -C`. Earlier Codex shell connection failures occurred under a different Windows account and did not prevent this normal-CMD execution. TCP Windows Authentication troubleshooting remains documented in `docs/29_sql_server_local_connectivity_resolution.md`; Shared Memory was the successful method for the reported Phase 01/02 runs.

## Limitations and next milestone

The Day 3 generated values are synthetic. The model has documented domain limitations, and the generated-data checks depend on the documented Day 2 baseline. The next milestone is controlled execution of Phases 03-06 followed by the independent final validator. Day 3 should be marked complete only after the remaining phases and validator pass.
