# Day 3 Independent Re-Audit After Remediation

**Audit date:** 2026-11-20  
**Overall readiness:** **BLOCKED — HIGH ISSUES**  
**Decision:** Do not proceed to generation. The preflight and validator need corrections before their readiness outputs can be relied on. This report is static only; no SQL was connected to or executed.

## Executive summary

The remediation materially improved generation-phase checks. Phase 06 now selects the expected listing by vehicle and deterministic `listed_at`, verifies order/item/reservation context, and updates only that active listing; its update count is asserted. Phase 02–05 also gained useful cohort and payload assertions. The DBCC capture is consistent with SQL Server's documented result-set shape and the documented `INSERT ... EXEC` compatibility rules, although compilation/runtime was not tested.

Three high-risk issues remain:

1. Preflight still omits most deterministic event-key families from its collision report and status-driving total. A pre-existing agreement, acquisition, listing, enquiry, reservation, order, transfer, or delivery key can therefore coexist with `readiness_status = PASS`.
2. The movement-chain failure aggregate selects the earliest prior movement instead of the immediately preceding movement. The expected Phase 04 transfer followed by Phase 06 dispatch for sold vehicles is consequently counted as a failure, making the final validator report `FAIL` for the planned valid workflow.
3. The aggregate status excludes the database/object-health result set and several whole-database cross-row diagnostics. It can report `PASS` while an earlier mandatory result set contains issues, including disabled/untrusted constraints or a Day 2 cross-row inconsistency.

The revised package is **not ready for generation**. Do not treat the current preflight `PASS` or final validator `PASS` as a reliable gate.

## Scope and method

Re-read every file under `database/data_generation/`, the Day 3 plan, implementation report and prior audit, and relevant Day 2 table, constraint, index and seed DDL. Inspected modified conditions, joins, target counts, event keys, SQL batches, transaction/lock placement, all `UPDATE` statements, validator diagnostics and status aggregation. Used Microsoft SQL Server documentation to assess the DBCC rowset and `INSERT ... EXEC` mechanics. Checked common local ScriptDom/SQLFluff locations; no parser was available at those paths. No SQL Server connection, SQL execution, preflight, validator execution, database change, script edit, Git staging, commit or push occurred.

## Files reviewed

- `database/data_generation/00_pre_generation_checks.sql`
- `database/data_generation/01_generate_customers_and_staff.sql`
- `database/data_generation/02_generate_catalog_and_vehicle_intake.sql`
- `database/data_generation/03_generate_inspection_and_valuation.sql`
- `database/data_generation/04_generate_acquisition_and_inventory.sql`
- `database/data_generation/05_generate_marketplace_activity.sql`
- `database/data_generation/06_generate_sales_finance_delivery.sql`
- `database/data_generation/10_validate_generated_data.sql`
- `database/data_generation/README.md`
- `docs/14_day3_synthetic_data_generation_plan.md`
- `docs/15_day3_synthetic_data_generation_implementation_report.md`
- `docs/16_day3_sql_safety_and_correctness_audit.md`
- Relevant Day 2 DDL under `database/`, including core, vehicle, lifecycle tables, constraints, indexes and seed scripts.

## Findings

### HIGH — Preflight still omits deterministic event-key families

**Location:** `database/data_generation/00_pre_generation_checks.sql:126-150`.

The preflight's per-family output covers employee code, customer name, VIN, engine number, registration number, payment/refund reference, ownership event and submission event (`128-138`). The status-driving `@D3KeyCount` (`150`) likewise counts those families only. It omits deterministic keys created later by the package, including:

- purchase offer/agreement references (`04_generate_acquisition_and_inventory.sql:49-56`);
- acquisition and inventory event keys/movement timestamps (`04_generate_acquisition_and_inventory.sql:124-176`);
- listing descriptions/timestamps and image references/display-order keys (`05_generate_marketplace_activity.sql:26-40, 108-143`);
- enquiry references and reservation event keys (`05_generate_marketplace_activity.sql:41-62`);
- sales order keys, payment references, refund references, transfer references and handover references (`06_generate_sales_finance_delivery.sql:23-73, 169-226`).

A matching deterministic row in one of these families can exist before a run while all counted families are empty; preflight then returns `PASS` at line 156. The later phase may catch a subset of collisions, but this defeats preflight's role as the complete namespace reconciliation gate.

**Recommended correction:** Enumerate all deterministic keys and alternate unique keys produced by each phase in preflight output and include each in one status-driving collision calculation. Include exact event tuples (not only broad text prefixes) where a natural key is composite. Any unresolved match must yield a blocked result.

### HIGH — Movement-chain aggregate compares against the earliest prior event

**Location:** `database/data_generation/10_validate_generated_data.sql:211-213`.

The anti-join condition at line 212 excludes a `prior` row when a row named `later` has an earlier timestamp/ID than `prior`. That selects the earliest earlier movement, not the latest movement immediately preceding the current movement. The displayed diagnostic at lines 92-99 uses `LAG`, which does select the immediate predecessor; the aggregate therefore does not implement the same test.

For the planned data, Phase 04 transfers the first 23 acquisitions (`04_generate_acquisition_and_inventory.sql:168-176`), and Phase 06 dispatches completed-sale vehicles from their final inventory branch (`06_generate_sales_finance_delivery.sql:284-290`). Completed-sale vehicles are in the transferred set. For each dispatch, the aggregate can compare its source to the receipt's original destination instead of the transfer's destination and count a false failure. This is an expected-path defect, not merely a hypothetical dirty-data case.

**Recommended correction:** Build the aggregate from the same `LAG(to_branch_id)` / `LAG(to_location_code)` ordered CTE used by the displayed diagnostic, then count the rows it returns. Keep the ordering tuple identical in both queries.

### HIGH — Final `PASS` excludes mandatory diagnostic result sets and database state

**Location:** `database/data_generation/10_validate_generated_data.sql:11-13, 64-70, 72-127, 145-220`.

The database state query emits `BLOCKED` for a non-ONLINE or read-only database at lines 11-13, but that result is not added to `@ValidationFailures`. Object-health diagnostics at lines 64-70 are also output-only. Thus a disabled/untrusted FK or CHECK constraint, or a disabled index, can be shown in an issue result set while the aggregate still returns `PASS` if counts and its selected checks are zero.

Other displayed diagnostics are only partly aggregated or are restricted to D3 while the displayed query is whole-database. Examples include defect/report item mismatch (81-82; aggregate only D3 defects at 177-178), valuation vehicle/report mismatch (83-85; aggregate only D3 at 179-180), acquisition mismatch and inventory without acquisition (86-91; aggregate only D3 at 181-184), and whole-database untrusted object health (64-70). The final calculation at 218-220 has no assertion that all prior issue result sets were empty.

**Why it matters:** A user can see an earlier mandatory diagnostic report a problem and still see the final row say `PASS`. The README calls for review of every result set, but the brief requires the aggregate status itself never to pass if a mandatory check fails.

**Recommended correction:** Populate the failure table from every mandatory diagnostic query (including database state and object health), or refactor diagnostics to write to a shared findings table and render both detail and final status from that table. Apply consistent scope: all tables for global integrity checks and D3 cohort filters for cohort-only rules. Compute the final row only from the complete findings set.

### MEDIUM — Phase 05 accepts and normalizes unexplained vehicle lifecycle states

**Location:** `database/data_generation/05_generate_marketplace_activity.sql:106, 145-152`.

The source-state gate allows any generated vehicle status in `IN_STOCK`, `LISTED` or `RESERVED` at line 106, without determining whether that row should have an active reservation. The update at lines 145-146 then derives `RESERVED` versus `LISTED` from the generated reservation set and overwrites the existing value. This can silently repair an inconsistent earlier state (for example, `RESERVED` with no corresponding expected active hold, or `LISTED` where the expected active hold exists). The aggregate row-count check accepts either zero or all 18 affected rows at line 147; it does not prove each source status was the correct one for that vehicle.

**Recommended correction:** Before the update, assert the expected prior lifecycle state per vehicle and per reservation condition. Reject mismatches; only apply the transition from the expected prior state. Assert resulting status per vehicle, not only total affected rows.

### MEDIUM — Phase 06 permits an unexplained held inventory state for completed-sale vehicles

**Location:** `database/data_generation/06_generate_sales_finance_delivery.sql:144-156, 256-259`.

For the eight planned completed sales, the intended vehicles are the cohort's vehicles 11–18. Phase 05's active reservations are on vehicles 4–10; the converted reservations attached to the sales do not change inventory to `HELD`. Nevertheless the Phase 06 precondition accepts either `AVAILABLE` or `HELD` for completed-sale vehicles (the earlier source check around line 143 and explicit state check at 156), then sets all eight inventory rows to `SOLD`. A held state without an expected active reservation is not reconciled before being overwritten.

**Recommended correction:** Require the expected pre-sale inventory state for each sale and reconcile any hold against its exact active reservation before changing inventory. Reject unexplained `HELD` state rather than normalizing it into `SOLD`.

### MEDIUM — Critical prechecks occur before the phase transaction and application lock

**Location:** Generation phases `01-06`; examples: Phase 01 checks at `01_generate_customers_and_staff.sql:8-135`, transaction/lock at `137-141`; Phase 06 checks at `06_generate_sales_finance_delivery.sql:6-167`, transaction/lock at `169-173`.

Natural-key payload conflict checks, lifecycle checks and prerequisite checks run before `BEGIN TRANSACTION` and before the transaction-owned application lock is acquired. A concurrent writer can change a row after the precheck and before the phase obtains its lock. In-transaction `UPDLOCK,HOLDLOCK` anti-joins and unique constraints protect several insert paths, and rollback protects caught errors, but they do not make all prechecked update targets or cross-row relationships atomic with validation. The application lock only coordinates sessions using the same resource; it does not serialize arbitrary database writers.

**Recommended correction:** Move the critical state/key reconciliation into the locked transaction (or recheck it inside the transaction immediately before mutation) with suitable isolation/locking. Keep any early checks as operator diagnostics only.

### MEDIUM — Exact aggregate counts do not establish full generated payload validity

**Location:** `database/data_generation/10_validate_generated_data.sql:15-43, 145-187`.

The validator compares every modeled table's count to an exact cumulative target and checks selected cohort cardinalities and business relationships. It does not compare all expected D3 payloads at final validation; for example, customer/contact/address and employee-role payloads are represented mostly by table totals/cohort counts, while listing images and sales events are not fully reconstructed from deterministic expected values. A wrong row can replace a missing row while keeping the exact count. Phase-level checks reduce this risk but do not make the final validator a complete independent payload audit.

**Recommended correction:** Add read-only exact expected-key/payload reconciliation for each generated cohort, or narrow the validator's claim to counts and selected lifecycle checks and require phase result evidence as a separate operator artifact.

## Previous findings — resolution status

| Earlier finding | Re-audit result |
|---|---|
| Registration collision omitted from status | **Resolved narrowly.** Registration, engine, ownership and submission namespaces now contribute to `@D3KeyCount`. Other deterministic phase key families remain omitted (HIGH finding above). |
| Phase 06 rewrote all listing history | **Resolved.** It selects the deterministic listing for each sold vehicle, verifies the order/item/reservation context, restricts update to `status='ACTIVE'`, checks exactly eight affected rows, and checks the sold listing postcondition (`06_generate_sales_finance_delivery.sql:261-281`). Historical listing rows do not match this update target. |
| Final validator lacked aggregate result | **Partly resolved.** It now returns `PASS`/`FAIL` and includes target mismatches and selected checks (`10_validate_generated_data.sql:138-223`), but excludes mandatory diagnostics and has a false-failure movement comparison (HIGH findings above). |
| Phase 02 incomplete payload verification | **Substantially improved.** Exact postchecks cover vehicle, registration, ownership and submission rows (`02_generate_catalog_and_vehicle_intake.sql:147-209`); no SQL Server compilation/runtime was performed. |
| Phase 03 incomplete payload verification | **Substantially improved.** Inspections, reports, items, defects and valuations have added exact/key postchecks (`03_generate_inspection_and_valuation.sql:154-209`). Offers are generated in Phase 04, not Phase 03. |
| Phase 04 incomplete lifecycle/cohort checks | **Partly resolved.** Complete-or-absent cohort counts and update cardinalities were added (`04_generate_acquisition_and_inventory.sql:22-40, 178-210`). Concurrency remains a concern because checks precede its transaction/lock. |
| Phase 05 incomplete payload checks | **Substantially improved.** Listing/image/enquiry/reservation payloads and counts are reconciled (`05_generate_marketplace_activity.sql:155-208`). Per-row expected source lifecycle state is still not enforced before normalization (MEDIUM finding). |
| Phase 06 broad lifecycle mutation checks | **Mostly resolved.** Vehicle, prior-owner, inventory and listing update counts are checked; listing scope is precise. Held-inventory precondition remains broader than the expected sale state (MEDIUM finding). |

## SQL Server compatibility and DBCC assessment

The capture at `10_validate_generated_data.sql:131-133` is **statically plausible for SQL Server**:

- Microsoft documents `DBCC CHECKCONSTRAINTS` as returning three columns: table name, constraint name and a `Where` expression, with `varchar` types. The receiving table has three positionally compatible `nvarchar` columns, and widening conversion is appropriate.
- Microsoft documents that `INSERT` with an `EXECUTE` statement accepts result sets compatible with the target columns, and that `EXECUTE` can run a command string. Taken together, those rules support the syntax used here. This is documentation-based assessment, not runtime proof.
- `ALL_ERRORMSGS` is appropriate when collecting all returned violation rows rather than relying on the default first 200.
- Microsoft also explicitly states that `DBCC CHECKCONSTRAINTS` is **not guaranteed to find all constraint violations**. Therefore a zero-row capture is not an exhaustive integrity certificate. The aggregate must still rely on other checks and should describe this limit.
- The DBCC operation requires elevated permissions (`sysadmin` or `db_owner` per the DBCC documentation). A permission/runtime error should stop the batch; the script does not currently catch it and print a final `PASS`, which is fail-closed but may prevent the user from receiving later result sets.

Sources: [DBCC CHECKCONSTRAINTS (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkconstraints-transact-sql), [INSERT (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql), and [EXECUTE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/execute-transact-sql).

## Phase-by-phase assessment

| Phase | Assessment |
|---|---|
| 0 — Preflight | Read-only in source and now blocks its counted collision families. It still omits most Phase 03–06 deterministic keys from collision detection/status. Schema/object health is count-based and expected fixture checks are partial. |
| 1 — Customers and staff | Inserts follow customer/employee parent dependencies. Natural-key, address/contact and role checks are present; transaction, `XACT_ABORT`, `TRY/CATCH` and a transaction-owned lock are used. Critical prechecks occur before the transaction/lock. |
| 2 — Catalog and vehicle intake | Catalog parent keys are resolved; alternate engine/registration collisions and full vehicle/registration/ownership/submission postchecks are present. Identity columns are omitted. Static schema compatibility looks consistent with Day 2 DDL. |
| 3 — Inspection and valuation | Parent sequence and expected counts are coherent; report/item/defect/valuation payload checks are substantially improved. Offers are not in this file; they are correctly generated in Phase 04. |
| 4 — Acquisition and inventory | Offer → agreement → acquisition → inventory → movements ordering is correct. Complete-or-absent counts and state transitions are guarded. Phase checks run before the lock/transaction; runtime and race behavior are unverified. |
| 5 — Marketplace | Listings/images/enquiries/reservations are inserted in FK order and reconciled. Active listings increase to 18 so the eight completed-sale vehicles have a matching active listing. Vehicle lifecycle updates accept a broad allowed state set and can normalize an inconsistent state. |
| 6 — Sales, finance and delivery | Payment/refund party and amount checks are present. Listing mutation now preserves history. State preconditions and mutation counts are improved; a held inventory row can still be accepted and overwritten for a planned sale. |
| Final validator | Aggregate exists, but movement check selects the wrong prior event, object health/database status are omitted from aggregate, and some global diagnostic outputs are not folded into it. It cannot certify all D3 payloads. |

## Transaction, concurrency and idempotency

All six mutation phases use `SET XACT_ABORT ON`, `TRY/CATCH`, an explicit transaction, a transaction-owned exclusive application lock and rollback when `XACT_STATE()<>0`. Transaction-owned application locks are released on commit/rollback; no manual release is needed. A caught SQL error rolls back that phase, while earlier committed phases remain committed.

The main concurrency gap is placement: the phase checks run before the transaction and application lock. Inserts use `UPDLOCK,HOLDLOCK` on anti-joins and unique constraints protect declared unique keys, but there remains a race for non-unique cross-row state and update preconditions. `sp_getapplock` does not coordinate unrelated writers that do not request the same resource. The phases are not a blind rerunnable package: downstream phases change lifecycle state, and the scripts intentionally stop when the expected state no longer matches. Partial manually-created rows are only safe where the specific event key's entire payload is checked.

## Safety assessment

No unintended `DELETE`, `DROP`, `TRUNCATE`, identity reset, constraint disable, trigger disable, schema DDL or other destructive operation was found in the generation package. Preflight and validator contain read queries, table variables and DBCC validation only. Generation scripts insert deterministic cohorts and perform documented state updates. The exact Phase 06 listing update is restricted to the D3 expected vehicle/listing timestamp and active status. No SQL was executed, so preservation of actual Day 2 rows is statically assessed only; live state is unknown.

## Static validation and explicitly unverified items

- No local ScriptDom DLL or SQLFluff executable was found in the checked common locations; no SQL parser was run. `sqlcmd` availability was not used to connect or execute anything.
- No SQL Server compilation, parser validation, preflight, validator execution, generation, or runtime result is claimed.
- `STRING_AGG` is used at `10_validate_generated_data.sql:30,139`; the target SQL Server engine version is not established from repository files. SQL Server 2017 or later is required for this function. The preflight reports ProductVersion/compatibility but does not gate the version for validator syntax.
- Actual target database state, object definitions, trust state, trigger state, row counts, collisions, fixture integrity and permission for DBCC remain unknown.
- DBCC's documented completeness limitation remains even when `ALL_ERRORMSGS` is used.

## Final recommendation

**BLOCKED — HIGH ISSUES.** Do not run generation. The Phase 06 listing-history remediation is valid, and DBCC capture is statically compatible based on Microsoft documentation, but preflight key coverage and final validator correctness are not complete. Correct the collision inventory, make every mandatory diagnostic feed the final status, fix the movement predecessor query, and tighten Phase 05/06 source-state guards. Then repeat a static audit before deciding whether a read-only preflight is the next controlled step.
