# Day 3 offline remediation completion report

> **Later runtime update (2026-11-26):** This offline-remediation report records its historical source-only status. The operator now reports preflight and Phases 01-06 PASS, independent Phase 04/05/06 verifiers 12/12, 28/28, and 36/36 PASS, and the final validator PASS with zero failures. Day 3 is complete according to the supplied runtime evidence. Current phase and final results are tracked in `docs/24_day3_synthetic_generation_execution_report.md` through `docs/26_day3_completion_report.md`.

**Date:** 2026-11-21
**Status at time of offline remediation:** **CODE REMEDIATION IMPLEMENTED; DAY 3 REMAINED INCOMPLETE AND BLOCKED**

## Executive summary

The offline source work adds a mandatory Day 2 fixture integrity gate to preflight and independently reconstructs Day 3 expected payloads across all six generation phases in the final validator. The validator aggregates mandatory failures into a final `PASS` or `FAIL`; it has no optional warning-only checks at present. Preflight and validator source were reviewed for persistent DML and none was found. Their dynamic `EXEC` statements are limited to metadata-built row-count reads and `DBCC CHECKCONSTRAINTS` output capture.

No SQL was executed. No SQL Server connection was made, and no database was accessed. The code has not been compiled by SQL Server or exercised against live data. Day 3 is not certified or ready for execution.

## Implemented source changes

### Day 2 fixture gate

`00_pre_generation_checks.sql` now creates per-group fixture findings and includes a fixture mismatch bit in its aggregate readiness decision. It checks fixture values from `database/10_seed_reference_data.sql` by natural/business keys rather than relying on identity values. Coverage includes cities, branches, staff and roles, customers/contacts/addresses, catalog records, vehicle registration/ownership/submission, inspection/report/items/defect/valuations, acquisition/inventory/receipt, marketplace/listing/enquiry/reservation, and sales/finance/delivery fixtures. It checks expected fixture cardinalities and the selected lifecycle relationships and values. A nonzero group failure count blocks readiness. Checks are read-only.

The fixture source rows were inspected in the repository. Live fixture integrity remains unknown until preflight is run against the identity-verified target. The gate is source-reviewed, not runtime-proven.

### Independent payload validator

`10_validate_generated_data.sql` now constructs expected rows from deterministic ordinal formulas and compares expected and observed projections in both directions (`EXCEPT`) for the generated cohorts. Its payload families cover:

| Phase | Independently reconstructed families |
|---|---|
| 01 | Employee, employee role, customer, contact, address |
| 02 | Vehicle identity/catalog, registration, initial ownership, submission, final owner and lifecycle projection |
| 03 | Inspection, report, checklist items, defects, valuations |
| 04 | Purchase offers, agreements, acquisitions |
| 05 | Listings, images, enquiries, reservations |
| 06 | Orders and items, payments, refunds, transfers, delivery, inventory movements and final inventory/ownership state |

Additional mandatory checks cover cumulative table totals, cohort totals, FK/check/index health, relationship mismatches, state and lifecycle consistency, movement sequence and inventory position, overlapping temporal records, payment/refund conditions, and captured `DBCC CHECKCONSTRAINTS` findings. The final status is `PASS` only when every recorded mandatory failure count is zero; any nonzero mandatory count yields `FAIL`.

The validator uses SQL Server table variables to hold expected payloads and performs read-only comparisons. Some correlations use deterministic descriptive/reference strings to derive ordinals because the schema does not provide a universal batch identifier. This is a documented design limitation: an altered descriptive key can cause a mismatch or make a row fall outside a cohort filter; the independent whole-table counts and other checks reduce but do not eliminate that risk. Exact cumulative table targets also assume the documented clean Day 2 baseline and require reconciliation if legitimate additional rows exist.

## Static review and verification

- Reviewed the fixture definitions in `database/10_seed_reference_data.sql`, the Day 2 DDL under `database/03_reference_tables.sql` through `database/09_indexes.sql`, the six generation scripts, the Day 3 plan, architecture and audit reports, and the preflight/validator source.
- Confirmed each phase 01–06 contains one transaction start, one `sp_getapplock` call, one commit, and one catch block by source-count inspection. The six phases use the common transaction/application-lock design documented in `docs/22_day3_transaction_lock_remediation_report.md`; no source changes to those phase files were made for this offline remediation task.
- Reviewed preflight and validator source for persistent `INSERT`, `UPDATE`, `DELETE`, or `MERGE` statements. None were found. Table-variable inserts are used for expected data and findings.
- `git diff --check` reported no issues for tracked changes. Repository files are untracked in this checkout, so that command does not validate the untracked source additions; a separate whitespace/parser pass is still needed for those files.
- No suitable T-SQL parser was found in the local command set or the searched SQL Server installation paths. SQLCMD and SQL PowerShell clients are installed, but they were not used to parse or execute scripts because that would require a server/database interaction. SQL syntax is therefore **unverified**.
- Static review does not establish dynamic SQL correctness, compatibility with the actual server build, permissions, or actual fixture/payload agreement.

## Local connectivity diagnostics

Read-only local inspection found the `MSSQL$SQLEXPRESS` service running with automatic startup, while SQL Browser was stopped/disabled. Registry instance mapping identified `SQLEXPRESS` as `MSSQL17.SQLEXPRESS`. The instance network-protocol registry values showed TCP disabled and named pipes disabled; no port was configured. This is consistent with client connectivity difficulties, but it is an inference and does not establish the only cause. Shared-memory connectivity was not tested. Historical reports record `sqlcmd` encryption/credential/connection errors and an integrated-authentication SSPI principal-name error from SQL PowerShell; those attempts were not repeated in this offline task.

Recommended user-controlled resolution: have the SQL Server administrator confirm the intended local instance and approved client protocol/authentication path, configure or enable the needed protocol through the normal change process if appropriate, and then have an authorized operator verify server and database identity read-only. This work changed no service, registry, network, firewall, authentication, or credential settings.

## Exact files modified for this remediation

- `database/data_generation/00_pre_generation_checks.sql`
- `database/data_generation/10_validate_generated_data.sql`
- `database/data_generation/README.md`
- `docs/26_day3_completion_report.md`
- `docs/27_day3_offline_remediation_completion_report.md` (this report)

The six phase scripts, Day 2 schema, and fixture data were not modified in this remediation.

## Remaining unverified conditions and risks

1. SQL Server has not parsed or executed the revised scripts; syntax, binding, runtime behavior and permissions remain unverified.
2. No database connection or access occurred. Server/database identity, actual Day 2 fixture state, existing Day 3 keys, and any live generated payloads are unknown.
3. The previous local connectivity failures and disabled TCP/named-pipe registry settings need administrator/operator review; no configuration change is authorized or performed here.
4. The validator's exact cumulative totals require the documented Day 2 baseline. Additional legitimate rows will fail totals and need explicit reconciliation.
5. Dynamic SQL, `DBCC CHECKCONSTRAINTS` permissions, SQL Server version compatibility, concurrency with non-cooperating writers, and transaction-lock runtime behavior need later controlled verification.
6. Day 3 remains incomplete until an identity-verified preflight passes, phases run under controlled authorization, and the independent validator passes against actual data with retained evidence.
# Targeted follow-up — Day 2 fixture predicate correction

The preflight fixture predicate for `VehicleRegistrationOwnershipSubmission` was inconsistent with the Day 2 seed lifecycle. It required all three `SYNVIN` vehicles to be `RESERVED` and all three submissions to be `SUBMITTED` with no close time. In the seed workflow, only VIN `SYNVIN00000000001` advances to `RESERVED`; its submission is `ACCEPTED` and closed at `2026-01-07 09:00:00`. VINs `...00002` and `...00003` remain `SUBMITTED` with open submissions. The preflight now checks those vehicle and submission states per VIN while retaining all other payload and relationship checks.

The `Day2ReportsDefectsValuations` predicate was compared against `database/10_seed_reference_data.sql`. Its four components remain: exact three report payloads; exact one defect payload; zero defect/item report-reference mismatches; and exact three valuation payloads and relationships. At the time of this initial review, no component-level live values were available to this process, so the discrepancy remained unclassified and the predicate was left unchanged. Subsequent read-only diagnostics and the confirmed valuation aggregate root cause are recorded in the targeted follow-up below; no data or fixture payload was changed to force a pass.

No SQL Server query or database modification was performed in this targeted follow-up. Generation phases 01–06 were not executed. Day 3 remains blocked until the corrected preflight returns `PASS` and the remaining report-group discrepancy is resolved from complete live values.

## Targeted follow-up — valuation fixture aggregate correction

The live read-only component diagnostics confirmed the report and defect checks were zero, while the valuation component returned three despite all three valuation records matching their expected payloads and relationships. The valuation predicate built three expected VIN/amount rows and filtered them with `WHERE NOT EXISTS` to retain only missing matches, but then calculated `ABS(COUNT_BIG(*) - 3)`. That inverted the result: zero unmatched rows became three failures, while three unmatched rows became zero. The failure count now directly counts the unmatched expected rows. The predicate also explicitly requires the report's inspection `vehicle_id` to equal the valuation vehicle, matching the seed join and the verified live relationship.

A focused review of the remaining fixture expressions found other `ABS(COUNT_BIG(*) - expected)` terms count matching actual rows and correctly measure cardinality differences. Mismatch-filtered expected-row checks already count unmatched rows directly. No other instance of the inversion was found. The earlier per-VIN lifecycle/submission correction remains unchanged.

No database query or modification was performed for this correction, and no generation phases were executed. Static parsing and whitespace checks are reported with this remediation. Day 3 remains blocked pending manual execution of the corrected preflight and a `PASS` result.

## Runtime syntax correction — valuation fixture tuple boundary

The first manual run after the valuation count correction reported cascading syntax errors at the following fixture rows. Static review of the entire `INSERT INTO @FixtureFindings VALUES` expression found that removing `ABS(COUNT_BIG(*)-3)` had also removed the final closing parenthesis that closed the valuation fixture's outer `(fixture_group, failure_count)` tuple. This left the subsequent row separator comma outside a completed tuple. The missing tuple close is restored; the unmatched-row count remains direct, and the explicit same-vehicle join remains in place. No fixture checks or expected values were removed or weakened.

This correction was validated statically only. SQL Server was not connected to and no SQL was executed; the manual preflight must be rerun before claiming runtime success.
