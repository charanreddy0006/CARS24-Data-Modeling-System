# Day 3 Transaction and Lock Remediation Report

**Date:** 2026-11-20  
**Scope:** Step 1 only — unified transaction and application-lock redesign.  
**Readiness:** **DAY 3 REMAINS BLOCKED** pending subsequent independent review.

## Executive summary

All six Day 3 generation scripts now enter a single `TRY`, begin a transaction, and acquire the same exclusive transaction-owned application lock before their mutable prechecks. The resource is `CARS24-Day3-Generation`, with `@DbPrincipal=N'public'`, `@LockTimeout=0`, and a negative return-code guard. The prior phase-specific resources were removed. All existing inserts, updates, phase postconditions, commits, and catch/rollback/rethrow paths remain within that transaction.

The Day 2 database-name guard remains before transaction start because it validates execution context and performs no mutable application-data check or write. Expected cohort table variables and all data-dependent prerequisite/payload/state reads are now built after lock acquisition. No targets, deterministic keys, payload formulas, lifecycle rules, preflight, or validator logic were changed.

## Files modified

- `database/data_generation/01_generate_customers_and_staff.sql`
- `database/data_generation/02_generate_catalog_and_vehicle_intake.sql`
- `database/data_generation/03_generate_inspection_and_valuation.sql`
- `database/data_generation/04_generate_acquisition_and_inventory.sql`
- `database/data_generation/05_generate_marketplace_activity.sql`
- `database/data_generation/06_generate_sales_finance_delivery.sql`

Created the required report: `docs/22_day3_transaction_lock_remediation_report.md`. No other SQL or documentation file was modified in this step.

## Previous ordering

The prior ordering performed substantial schema/data prechecks before `BEGIN TRY`, `BEGIN TRANSACTION`, and application-lock acquisition. The audited locations were:

| Phase | Previous mutable prechecks | Previous transaction and phase lock |
|---|---|---|
| 01 | Lines 8–135 | TRY 137, transaction 138, phase lock 140–141 |
| 02 | Lines 8–106 | TRY 108, transaction 109, phase lock 111–112 |
| 03 | Lines 6–98 | TRY 100, transaction 101, phase lock 103–104 |
| 04 | Lines 6–122 | TRY 124, transaction 125, phase lock 127–128 |
| 05 | Lines 6–110 | TRY 112, transaction 113, phase lock 115–116 |
| 06 | Lines 6–167 | TRY 169, transaction 170, phase lock 172–173 |

The phase-specific resources differed, so calls to different phases did not coordinate through the application lock.

## Implemented architecture

Each script now follows the same order:

1. `SET NOCOUNT ON`, `SET XACT_ABORT ON`, and the database-name guard.
2. `BEGIN TRY`.
3. `BEGIN TRANSACTION`.
4. Declare the lock-result variable and call `sys.sp_getapplock` with exclusive mode, transaction ownership, zero timeout, resource `CARS24-Day3-Generation`, and database principal `public`.
5. Throw immediately if the return code is negative. No permanent insert or update occurs before this guard.
6. Build expected-row table variables and perform mutable prerequisite, deterministic-key, payload, relationship, and lifecycle prechecks while the transaction and application lock are active.
7. Perform existing writes and postconditions inside the same transaction.
8. Commit after the postconditions pass. In `CATCH`, roll back if `XACT_STATE()<>0`, emit the existing error details where applicable, and execute bare `THROW` to preserve the original error context.

The transaction-owned application lock is released automatically at commit or rollback. Timeout `0` is fail-fast: a competing participant that cannot acquire the lock receives a negative return and throws before writes. An error raised by `sp_getapplock` itself enters the same catch path.

## Phase-by-phase review

| Phase | Transaction / lock locations | Protected prechecks | Protected writes and postconditions | Commit / rollback |
|---|---|---|---|---|
| 01 — customers/staff | TRY 9; transaction 10; shared lock call 12 and failure guard 13. | Mutable checks and expected employee/customer/contact/address relations follow lock acquisition, lines 14–143. | Employee, role, customer, contact, address writes at 144–168; payload/cardinality postconditions at 170–188. | Commit 190; catch 199; rollback 200; rethrow 203. |
| 02 — catalog/vehicle intake | TRY 9; transaction 10; lock 12 and guard 13. | Catalog resolution, vehicle/registration/ownership/submission conflicts and source-state checks after the guard, lines 14–115. | Inserts 116–138; ownership, registration, submission, payload and count postconditions through 210. | Commit 212; catch 220; rollback 221; rethrow 223. |
| 03 — inspection/valuation | TRY 7; transaction 8; lock 10 and guard 11. | Cohort, inspection/report/item/defect/valuation expected rows and conflict checks after the guard, lines 12–107. | Inserts 108–151; full phase postconditions through 210. | Commit 212; catch 221; rollback 222; rethrow 224. |
| 04 — acquisition/inventory | TRY 7; transaction 8; lock 10 and guard 11. | Cohort and source-state checks, plus offer/agreement/acquisition/inventory/movement payload checks, lines 12–131. | Inserts 132–178; inventory, vehicle and submission updates 179–194; postconditions through 211. | Commit 213; catch 222; rollback 223; rethrow 225. |
| 05 — marketplace | TRY 7; transaction 8; lock 10 and guard 11. | Listing/image/enquiry/reservation keys, active-hold relationships, and per-vehicle prior-state checks, lines 12–119. | Inserts 120–149; lifecycle updates 150–157; payload, cardinality and per-vehicle postconditions through 221. | Commit 222; catch 230; rollback 231; rethrow 233. |
| 06 — sales/finance/delivery | TRY 7; transaction 8; lock 10 and guard 11. | Order/payment/refund/transfer/delivery payload checks, ownership/inventory/listing state checks, lines 12–176. | Inserts 177–238; history/vehicle/inventory/listing updates 239–283; dispatch insert 284–291; postconditions through 311. | Commit 312; catch 324; rollback 325; rethrow 327. |

In each phase, `USE`/batch setup and the database-name assertion precede the transaction. That assertion checks only execution context. All expected table-variable construction and application-data checks occur after successful lock acquisition. Table-variable population is not a persistent database write.

## Cross-phase consistency findings

- All six scripts use byte-for-byte matching lock resource, exclusive mode, transaction owner, zero timeout, and `public` principal.
- Each script has one transaction start, one app-lock acquisition, one guarded write section, one commit, and one catch path. The prior `CARS24-Day3-Phase01` through `Phase06` resources are absent.
- Every app-lock failure guard precedes the first permanent insert/update. A negative return throws; `CATCH` rolls back the active transaction and rethrows.
- The common resource serializes participating Day 3 phase transactions, avoiding concurrent phase execution. It is released at each phase commit, so it does not by itself hold a package-wide lock across all six separately committed phases. The operator sequence and phase dependency/state checks remain necessary; calls can interleave between phase commits.
- No lock-order inversion was introduced: transaction → common application lock → existing checks/parent-to-child writes → postconditions. No new row-level hints or broader isolation level were added in this step.

## Static verification results

- Reviewed current source ordering and exact locations for each of the six phases.
- Confirmed all six lock declarations match and each negative lock result is checked before permanent writes.
- Confirmed every phase has a matching transaction/commit and catch/rollback/rethrow structure, with postconditions before commit.
- `git diff --check` completed without reported whitespace errors. The repository presents the SQL directory as untracked, so this command alone does not inspect those untracked file contents; ordering was also reviewed directly in the six current files.
- No suitable SQL Server parser command was found in the available command checks. `sqlcmd` is a database client and was not invoked. No SQL Server compilation or runtime check is claimed.
- No SQL was executed; the database was not accessed.

## Remaining risks and limitations

- Application locks coordinate only sessions that request the same database-scoped resource/principal. Manual SQL, jobs, or unrelated applications do not cooperate with this lock.
- Existing exact anti-join insert paths retain their `UPDLOCK,HOLDLOCK` hints. This step did not add row/range hints to every precheck or set transaction isolation to SERIALIZABLE; under ordinary READ COMMITTED, non-cooperating writers may still change rows/ranges not held by a statement-level lock. A controlled quiet window and later review of exact key-range protection remain necessary before any execution decision.
- The common app lock is held for the whole phase transaction, not across the entire Day 3 multi-phase workflow. Do not run phases out of order or concurrently from independent sessions; the scripts still rely on state checks and the operator procedure for dependency order.
- Longer transactions now include prechecks and expected table-variable construction, increasing lock duration and possible blocking. Deadlock behavior with external writers is unverified. Errors are fail-closed for the current phase, but earlier committed phases are not rolled back.
- No parser/runtime testing was performed. Day 3 remains blocked pending independent review of these edits and the separate fixture/validator remediation steps.

## Safety confirmation

Only the six authorized generation scripts were modified. No preflight, validator, generation phase, or other SQL was executed. No SQL Server connection was made. The database was not accessed or changed. No files were staged, committed, or pushed. Day 3 remains blocked; this report does not claim execution readiness.

## End-to-end mandate follow-up (2026-11-21)

The subsequent authorized completion attempt could not verify or connect to the target SQL Server. `sqlcmd` using ODBC Driver 18 failed with `Encryption not supported on the client`, `No credentials are available in the security package`, and `Client unable to establish connection` for both `chakri\SQLEXPRESS` and `localhost\SQLEXPRESS`. The installed SQL PowerShell client, using integrated authentication and encryption disabled, returned `The target principal name is incorrect. Cannot generate SSPI context` for `chakri\SQLEXPRESS`, `.\SQLEXPRESS`, and a local named-pipe endpoint. The SQL Server service appeared as `MSSQL$SQLEXPRESS` Running, but that service observation does not establish connectivity or database identity.

No SQL statement reached the server; no preflight, generation, or validator was executed. The target database's current state and contents therefore remain unknown. The transaction/lock static review above remains historical evidence only and does not establish runtime safety or Day 3 readiness. See `docs/23_day3_preflight_execution_report.md` through `docs/26_day3_completion_report.md` for the outcome of this attempt.
