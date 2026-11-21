# Day 3 Final Independent Code Review

> **Runtime status update (2026-11-21):** The decision and evidence below describe the static review snapshot. The operator subsequently ran pre-generation checks successfully and committed Phases 01 and 02 with PASS results. Phases 03-06 and the independent final validator remain unexecuted; this review does not certify those runtime results. See `docs/24_day3_synthetic_generation_execution_report.md` and `docs/26_day3_completion_report.md`.

**Review date:** 2026-11-21
**Decision at review time:** **BLOCKED**
**Scope:** Static review of the current Day 3 SQL package and relevant Day 2 DDL/seed. No database connection or SQL execution.

## Executive finding

The fixture gate is status-driving and appears read-only. The six generation phases follow one transaction-owned exclusive application-lock pattern and scope their writes to deterministic Day 3 rows/cohorts. I found no `DELETE`, `MERGE`, or broad unqualified update in the phase scripts.

The final validator is not yet a complete independent payload validator. Several projections omit mutable columns that exist in the Day 2 DDL, and the offer comparison does not establish that an offer references the expected valuation for the same vehicle. Those values can be altered while the current mandatory aggregate still reports no corresponding failure. The package is therefore **BLOCKED for generation** until these validator gaps are corrected and the SQL is parsed/reviewed. A later controlled, read-only preflight may be useful as a diagnostic, but this review does not approve generation or certify the preflight's runtime behavior.

## Review coverage and evidence

Reviewed actual source files:

- `database/data_generation/00_pre_generation_checks.sql`
- `database/data_generation/01_generate_customers_and_staff.sql` through `06_generate_sales_finance_delivery.sql`
- `database/data_generation/10_validate_generated_data.sql`
- `database/data_generation/README.md`
- `database/03_reference_tables.sql` through `09_indexes.sql`, including `database/07_lifecycle_tables.sql`
- `database/10_seed_reference_data.sql`
- Existing Day 3 documentation files `docs/14` through `docs/27` where present. There is no `docs/17...` file in the repository. Reports 23–25 describe the historical blocked attempt; docs/27 and the current README describe the latest offline source state.

Line numbers below refer to the reviewed source versions at this review. The reports and source were checked for consistency; historical reports were not rewritten.

The findings and matrix below are the initial review snapshot. The appended targeted remediation section records the current disposition of the two corrected validator defects and updates the coverage ratings for those specific payload fields.

## Findings

### CRITICAL — Expected offer valuation relationship is not validated

In `10_validate_generated_data.sql:264–265`, the offer comparison checks the D3 vehicle through its submission and compares dates, amount, status, seller, but it neither compares `PurchaseOffer.valuation_id` nor joins that valuation to the expected vehicle/inspection. The DDL defines `valuation_id` as a required FK (`database/07_lifecycle_tables.sql:120–141`), but the FK only proves that some valuation exists. The validator's broader relationship checks at lines 415–419 check defect/report and acquisition/seller lineage, not offer/valuation lineage.

A D3 offer can therefore point to a different vehicle's valuation (including one with matching amounts) and escape this payload check. Add expected valuation identity by deterministic vehicle/inspection lineage and compare the actual valuation's vehicle, report, amount, and approved/expected state; include `valuation_id` lineage in the offer payload finding.

### HIGH — Payload projections omit actual mutable columns

The independent comparisons use set differences over selected projections. They do not compare the following DDL columns, and no other mandatory D3 finding was found that fully checks them:

- `Employee.active_to` and `EmployeeRole.valid_to`: phase 01 comparisons at lines 172–176 compare code/branch/name/date and role/start only. DDL: `database/04_core_tables.sql:25–59`. Expected generated values are open-ended (`NULL`), so non-NULL alterations can pass.
- `CustomerAddress.address_line2`: phase 01 address comparison at lines 184–185 omits it. DDL: `database/04_core_tables.sql:100–119`. Generation inserts `NULL` at `01_generate_customers_and_staff.sql:168`; another value can pass.
- `VehicleRegistration.valid_to`: registration comparison at lines 204–205 omits it. DDL: `database/06_vehicle_identity.sql:36–53`. Generation creates the active registration with `valid_to` omitted (`02_generate_catalog_and_vehicle_intake.sql:123`); a later closure can pass when it does not overlap another registration.
- `Inspection.submission_id`: inspection payload comparison at lines 239–240 keys by VIN/time and compares inspector/status/times, but not the expected submission relation. DDL: `database/07_lifecycle_tables.sql:16–34`. The FK permits a different valid submission for that vehicle.
- `Defect.currency_code`: defect comparison at lines 248–250 omits it. DDL: `database/07_lifecycle_tables.sql:71–92`; generator writes `INR` at phase 03 line 136. The code/domain checks do not require INR.
- `PurchaseOffer.currency_code` and `valuation_id`: offer comparison at lines 264–265 omits both; DDL: `database/07_lifecycle_tables.sql:120–141`.
- `VehicleAcquisition.currency_code`: acquisition comparison at lines 271–273 omits it. DDL: `database/07_lifecycle_tables.sql:167–186`.
- `VehicleListing.currency_code`: listing comparison at lines 284–286 omits it. DDL: `database/07_lifecycle_tables.sql:235–257`.
- `Refund.currency_code`: refund comparison at lines 339–341 omits it. DDL: `database/07_lifecycle_tables.sql:387–406`.

These are not merely surrogate identity columns: they are declared business/state columns in the modeled tables. Extend the independent expected rows and actual projections to include them. In particular, test nullable columns explicitly so expected `NULL` is distinguished from an altered value.

### MEDIUM — Several entity-family comparisons are only partial despite complete-payload intent

The matrix below describes what the validator actually compares, not what the report or table counts imply. The major identified gaps are expanded in the HIGH finding.

| Generated family | Coverage | Review note |
|---|---|---|
| Phase 01 Employee | COMPLETE | `active_to` now included and compared as expected `NULL`. |
| Phase 01 EmployeeRole | COMPLETE | `valid_to` now included and compared as expected `NULL`. |
| Phase 01 Customer | COMPLETE | Display/legal names, status, creation time compared bidirectionally. |
| Phase 01 CustomerContact | COMPLETE | Type/value/verified flag/validity compared bidirectionally with parent customer. |
| Phase 01 CustomerAddress | COMPLETE | `address_line2` now included and compared as expected `NULL`. |
| Phase 02 Vehicle | COMPLETE | VIN/engine/catalog/year/fuel/transmission/created time compared; final owner and lifecycle separately checked. |
| Phase 02 Registration | COMPLETE | `valid_to` now included and compared as expected `NULL`. |
| Phase 02 Ownership history | PARTIAL | Initial-owner expected-to-actual comparison is one-way at line 207; final history checks at 366–370 cover initial and sale records but do not fully establish every expected initial row in both directions. |
| Phase 02 Submission | COMPLETE | Seller, branch, submitted time, status, close time and outcome reason checked across payload/lifecycle findings. |
| Phase 03 Inspection | COMPLETE | Submission vehicle VIN and submitted time now join the independent expected submission mapping. |
| Phase 03 InspectionReport | COMPLETE | Report outcome, summary, finalization time and inspection cohort compared. |
| Phase 03 InspectionItem | COMPLETE | Item code/outcome/note and report-to-inspection lineage compared. |
| Phase 03 Defect | COMPLETE | Currency is now compared as expected `INR`. |
| Phase 03 VehicleValuation | COMPLETE | Expected inspection VIN/schedule is now compared through the attached report. |
| Phase 04 PurchaseOffer | COMPLETE | Currency is compared and the valuation/report relationship is independently checked against the deterministic vehicle and inspection keys. |
| Phase 04 PurchaseAgreement | PARTIAL | Reference/status/time and some seller/offer consistency checked; the full offer ID lineage is not compared as an expected payload key. |
| Phase 04 VehicleAcquisition | COMPLETE | Currency is now compared as expected `INR`; remaining acquisition payload and lineage fields are compared. |
| Phase 04 Inventory | COMPLETE | Vehicle, branch, location, status and since time are compared. |
| Phase 04/06 InventoryMovement | COMPLETE | Event type, from/to branch/location, employee, time and reason compared bidirectionally for D3 cohort. |
| Phase 05 VehicleListing | COMPLETE | Currency is now compared as expected `INR`. |
| Phase 05 ListingImage | COMPLETE | Display order/reference/caption and listing-to-vehicle cohort compared. |
| Phase 05 CustomerEnquiry | PARTIAL | Payload and customer/listing relations checked; assigned employee is checked as a separate fixed-code condition, not part of the expected-row projection. |
| Phase 05 VehicleReservation | COMPLETE | Customer/listing/time/status/release payload compared bidirectionally. |
| Phase 06 SalesOrder | COMPLETE | Buyer, timestamps, state and currency compared bidirectionally. |
| Phase 06 SalesOrderItem | PARTIAL | Vehicle/buyer/price/reservation mapping and currency are checked, but order identity is inferred via parent joins rather than included in the expected projection. |
| Phase 06 Payment | COMPLETE | Provider/ref/method/amount/status/times compared; order mapping and currency consistency checked separately. |
| Phase 06 Refund | COMPLETE | Currency is now compared as expected `INR`. |
| Phase 06 OwnershipTransfer | COMPLETE | Reference/state/times/vehicle/buyer compared; source and destination parties checked separately. |
| Phase 06 VehicleDelivery | COMPLETE | Reference/state/times/vehicle/buyer/branch/address compared; recipient-to-buyer condition checked separately. |

The `COMPLETE` labels mean the modeled business payload and relationships described by this package are compared through the listed combined findings. Surrogate identity values are not deterministic and are not expected to match numeric IDs.

### MEDIUM — No SQL Server parser or live binding check was available

No suitable local T-SQL parser was found among available commands or the searched SQL Server installation paths. SQLCMD and SQL PowerShell clients exist, but neither was used because they require a server interaction for parsing. Dynamic SQL, object/column binding, SQL Server version support, and runtime error behavior remain unverified. This is a verification limitation, not a claim that the scripts have a syntax defect.

### VERIFIED — Fixture findings drive preflight readiness

`00_pre_generation_checks.sql:176–243` inserts named fixture groups, emits one explicit status row per group, and derives `@FixtureMismatch` from every group with a positive failure count. At lines 245–246, `@FixtureMismatch=1` forces `BLOCKED`; the fixture checks are not diagnostic-only. The compared seed values are grounded in `database/10_seed_reference_data.sql`; the group checks cover cities, branches, employees/roles, customers/contacts/addresses, catalog, vehicle registration/ownership/submission, inspection/report/items/defect/valuation, acquisition/inventory/receipt, marketplace/enquiry/reservation, sales/finance/delivery, and Day 2 table cardinalities. No fixture mutation statement was found.

The gate runs inside `sys.sp_executesql` after preflight's target database guard. A query error prevents the final readiness result rather than yielding a fabricated fixture PASS. The dynamic row-count query is read-only. No persistent DML is present in preflight; only table-variable inserts and catalog/data reads were found. This is source review only; no preflight execution occurred.

### VERIFIED — Six-phase transaction and application-lock structure

All six phase files contain one transaction start, one call to `sys.sp_getapplock`, one commit, and one `TRY/CATCH` rollback/rethrow path. Each uses resource `CARS24-Day3-Generation`, `Exclusive` mode, `Transaction` ownership, zero-millisecond timeout, and `public` database principal. The negative return-code check occurs immediately after lock acquisition, before data-dependent checks and permanent writes. Lock release is by transaction completion.

Permanent writes in phases 01–06 are inserts into intended Day 3 cohorts, plus scoped updates to the matching Day 3 lifecycle rows in phases 04–06. No `DELETE` or `MERGE` was found. Each phase has postcondition checks before `COMMIT`. The initial `USE` and database-name guard precede the transaction but do not inspect mutable application rows. The application lock only serializes participating scripts; unrelated writers that do not take it remain outside that coordination strategy. Ordinary constraints and phase-specific predicates remain necessary.

The shared lock does not enforce phase order across commit boundaries. The README's one-session ordered execution and each phase's prerequisite/state guards remain necessary. This review did not test concurrent execution or rollback behavior on SQL Server.

## Static verification performed

- Inspected actual source and DDL; verified fixture values against seed definitions.
- Counted transaction/app-lock/commit/catch structures across all six phases and confirmed shared lock resource/mode/owner/timeout in the source.
- Searched preflight/validator for persistent `INSERT`, `UPDATE`, `DELETE`, or `MERGE`; none found. Validator uses table-variable inserts and `DBCC CHECKCONSTRAINTS` result capture.
- Ran `git diff --check`; it produced no output. The checkout reports the repository files as untracked, so Git's tracked-diff check does not cover those files. A separate trailing-whitespace scan of the current preflight, validator, README and docs/26–27 found no whitespace errors.
- Parser unavailable; no SQL was parsed or executed.
- No DB connection, database access, preflight, generation, or validator execution occurred.

## Decision and exact next condition

**BLOCKED** for generation. The smallest required code correction is to complete the validator's expected projections and relationship checks for the omitted columns and offer-to-valuation lineage listed above, then independently review those changes. After that, use a suitable T-SQL parser/static review, restore an authorized connection, identity-verify the exact instance/database, run the status-driving preflight, and only proceed to sequential generation if it passes and an operator explicitly authorizes execution.

This decision does not claim that the preflight has run, that the database is reachable, or that any generated data exists. Day 3 remains incomplete.

## Targeted validator defect remediation — 2026-11-21

This section records the focused follow-up to the HIGH findings above and supersedes those findings only for the affected validator projections and offer/valuation relationship. It does not change the overall **BLOCKED** decision or claim runtime readiness.

### Defects and fixes

1. **Mutable DDL columns omitted from expected-row comparisons.** The validator now independently expects and compares `Employee.active_to` and `EmployeeRole.valid_to` as `NULL`; `CustomerAddress.address_line2` as `NULL`; `VehicleRegistration.valid_to` as `NULL`; `Defect.currency_code` as `INR`; and `PurchaseOffer.currency_code`, `VehicleAcquisition.currency_code`, `VehicleListing.currency_code`, and `Refund.currency_code` as `INR`. It also strengthens inspection lineage by independently deriving the expected submission time from the Day 3 vehicle ordinal, comparing the actual submission vehicle VIN and time, and strengthening valuation lineage by comparing the report's inspection vehicle VIN and scheduled time. These expected values match the generation inserts and deterministic formulas reviewed in phases 01–06 and the Day 2 DDL.
2. **Offer-to-valuation association was not independently validated.** The validator now resolves exactly one expected valuation by the expected D3 vehicle and the deterministic valuation time (`expected inspection scheduled_at + 1 day`). For each expected offer, it verifies the actual offer's `valuation_id` equals the ID resolved by that natural key, then verifies that the referenced valuation belongs to the same vehicle, has the expected valuation time, and points through its report to the expected vehicle and inspection schedule. Missing offers, missing/ambiguous expected valuations, a different valuation ID, or a mismatched valuation/report/inspection relationship increment a mandatory `@ValidationFailures` row.

The currency and nullable-column comparisons use the existing bidirectional `EXCEPT` payload findings. The offer lineage check is a separate mandatory finding, and `@FailureCount` is computed from all `@ValidationFailures` rows before the final `PASS`/`FAIL` output. No generation success flag is used as evidence.

### Files modified

- `database/data_generation/10_validate_generated_data.sql`
- `docs/28_day3_final_independent_code_review.md`

No generation script, Day 2 DDL/fixture, README, or other report was modified for this targeted fix.

### Targeted verification

- Rechecked the affected DDL columns in `database/04_core_tables.sql`, `database/06_vehicle_identity.sql`, and `database/07_lifecycle_tables.sql`.
- Rechecked phase 01 address/employee inserts, phase 02 registration/submission inserts, phase 03 inspection/valuation/defect formulas, and phase 04 offer/valuation joins and currency literals; phase 04 joins valuation by the same vehicle and deterministic valuation timestamp used in the new expected-key check.
- Confirmed each new comparison is inserted into `@ValidationFailures`, which feeds the final aggregate failure count. The new logic uses table variables and read-only joins/applies; it adds no persistent DML.
- Reviewed null handling: expected null validity/address values are explicitly typed and compared with set operations, where NULL values compare as equal; a non-NULL alteration yields a difference.
- Reviewed relationship false-pass paths: expected valuation lookup must have cardinality exactly one; actual `valuation_id` must equal that lookup; an `EXISTS`-style relationship requirement ensures the valuation report resolves to the expected inspection and vehicle. Missing joins cannot be counted as a pass.
- `git diff --check` produced no output, but this checkout reports the source tree as untracked, so Git does not include these untracked files in its tracked diff. A direct trailing-whitespace scan of the modified SQL and report found none.
- No suitable SQL Server parser was available. SQL syntax and object binding remain unverified; no SQL was executed and no database was accessed.

### Remaining limitations

This is static review only. SQL Server parsing, permissions, actual row values, and live validator behavior remain unverified. The package remains blocked pending an appropriate parser/static validation, identity-verified database connectivity, controlled preflight, and later authorized generation and validation. Day 3 remains incomplete.
