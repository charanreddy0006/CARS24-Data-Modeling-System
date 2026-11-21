# Day 3 SQL Safety and Correctness Audit

**Audit date:** 2026-11-20  
**Overall readiness:** **BLOCKED — HIGH ISSUES**  
**Recommendation:** Do not execute any generation phase. Resolve the high-risk lifecycle and preflight findings, revise the validator, then repeat the static audit. This review did not run SQL or connect to SQL Server.

## Executive summary

The package contains modular inserts, deterministic cohort keys, transaction-scoped application locks, `XACT_ABORT`, conflict checks and rollback handlers. Static inspection found no `DELETE`, `DROP`, `TRUNCATE`, identity reseed, constraint/trigger disable, schema DDL, or SQLCMD include in the generation package. Each generation phase wraps its writes in a transaction and its `CATCH` block rolls back an active transaction.

However, the safeguards do not consistently meet the package's own exact-payload and fail-closed requirements. The preflight omits registration collisions from the scalar collision status; several phases perform incomplete payload comparisons or make post-insert checks broader/narrower than the generated cohort; Phase 06 overwrites the status and close time of every listing for sold vehicles; and the final validator produces descriptive result sets but no aggregate pass/fail result. These issues mean the current preflight can miss a key conflict and the current validator can leave operators to infer success from a set of outputs.

## Scope and method

Review-only static inspection of all files in `database/data_generation/`, the Day 3 plan and implementation report, and the relevant Day 2 SQL DDL, constraints, indexes and seed scripts. Reviewed SQL statements, transaction and error handling, key/payload checks, cohort dependencies, target arithmetic, lifecycle updates, validator queries and README run guidance. No SQL Server connection, SQL execution, parser invocation, database change, Git staging, commit or push was performed. No files other than this report were modified.

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
- Day 2 DDL/seed sources under `database/`, including schema creation, tables, lifecycle tables, vehicle identity/catalog, constraints, indexes, and reference seed data.

## Findings

### HIGH — Registration collision is not included in preflight's blocking/warning key total

**Location:** `database/data_generation/00_pre_generation_checks.sql:126-145` (especially 131 and 145).

The script returns a `D3_REGISTRATION` count at line 131, but `@D3KeyCount` at line 145 sums only employee, customer, VIN, payment and refund keys. As a result, a pre-existing row matching the generation registration namespace can coexist with `readiness_status = PASS` when there are no other D3 keys. Phase 02 may later stop on some registration conflicts, but the advertised preflight status does not require reconciliation and does not establish that the generated registration set is collision-free.

**Why it matters:** Operators are explicitly told to use preflight as the gate before mutation. A key family can be reported as present while the top-level status gives a pass.

**Recommended correction:** Include the registration collision count (and any other generation natural-key families, including ownership/submission events if practical) in the status-driving collision total. Report per-family counts and make any nonzero value require reconciliation before generation.

### HIGH — Phase 06 rewrites all listing history for a sold vehicle

**Location:** `database/data_generation/06_generate_sales_finance_delivery.sql:242-244`.

The update joins every listing for each of the eight completed-sale vehicles and assigns `status='SOLD'` and the order's `completed_at` to `closed_at`. It does not restrict the update to the active listing associated with the order. For each vehicle, earlier `CLOSED`, `PAUSED`, or `WITHDRAWN` listing history is rewritten as sold at a later date. This changes historical lifecycle facts, is inconsistent with Phase 05's expected payload, and can reduce fidelity of lifecycle reports. The update is also not guarded by a prior exact-payload comparison for all listing rows it changes.

**Why it matters:** Generation must preserve existing fixture data and maintain accurate marketplace history. The same-script Day 3 listings are still pre-existing data when Phase 06 runs.

**Recommended correction:** Identify the exact listing/reservation tied to each sold order item and update only the one currently active listing to `SOLD`; leave prior listing rows/status/close times untouched. Add exact precondition and postcondition checks for that listing.

### HIGH — Final validator does not compute a readiness result or fail on incomplete target counts

**Location:** `database/data_generation/10_validate_generated_data.sql:15-29, 31-40, 61-129`.

The dynamic count query reports `actual_count` beside `proposed_target`, but no comparison creates a mismatch result, severity, or final status. Subsequent issue checks are independent result sets; the script ends after `DBCC CHECKCONSTRAINTS` without an aggregate status or assertion. Thus zero generated rows, incomplete phases, or nonempty issue result sets do not produce a definitive `BLOCKED`/`FAIL` output. The header says “final validation,” but it is an inspection report requiring operator interpretation.

**Why it matters:** This fails the requirement that the validator must not falsely claim success when data is incomplete or inconsistent. It also makes an automated or casual review prone to treating successful script completion as validation success.

**Recommended correction:** Keep it read-only but accumulate target mismatches, missing generated cohorts, workflow violations and DBCC findings into a final explicit status row (for example `PASS` only if all required checks pass; otherwise `FAIL`/`REVIEW`). Clearly distinguish targets that are minima/exact cumulative expected totals from informational counts. Do not call these variables targets without stating the comparison policy.

### MEDIUM — Phase 02 post-checks do not validate the complete vehicle, registration, ownership and submission payload

**Location:** `database/data_generation/02_generate_catalog_and_vehicle_intake.sql:149-187, 219-247`.

Pre-insert checks compare several payload fields, but the post-insert assertions only verify owner linkage, existence of some active ownership row and exactly one active registration. They do not establish exactly one registration for each expected registration key with matching state/date/vehicle; nor exactly one expected submission per cohort key with matching seller, branch, status and timestamps; nor complete ownership-history payload for every cohort row. The insert anti-joins use event keys, so a pre-existing row with a conflicting payload can be skipped if it is not caught by the earlier conflict join. The postconditions are not a substitute for exact-key, exact-payload reconciliation.

**Why it matters:** A phase may commit while a deterministic record was skipped or a related record already exists with a different payload. Counts alone do not prove correctness.

**Recommended correction:** For each expected vehicle, registration, ownership and submission row, assert exactly one matching key and compare every inserted column after the insert. Detect collisions on alternate unique keys, including VIN/engine number and registration uniqueness, before mutation.

### MEDIUM — Phase 03 report/checklist/defect conflicts are not uniformly checked for unmatched keys

**Location:** `database/data_generation/03_generate_inspection_and_valuation.sql:53-140, 190-260`.

The exact conflict joins detect changed payloads only when the expected natural key already matches. Existing report rows on the expected inspection are not comprehensively asserted to be exactly one and match every field; similarly the checklist and defect paths rely on the later cohort-wide counts and limited postconditions. A pre-existing row using a stable generated description/key but associated with an unexpected report can escape the direct conflict predicate. The committed assertions verify aggregate counts (and only one cross-report condition), rather than all expected event keys and full payloads.

**Why it matters:** A partial or inconsistent earlier execution can be mistaken for safe-to-fill gaps; aggregate totals can be reached with the wrong rows.

**Recommended correction:** Create expected-row tables for each event family, check duplicates and conflicting alternate-key matches before writes, then assert exactly one full-payload match per expected key after insertion.

### MEDIUM — Phase 04 state updates accept pre-existing lifecycle states without validating their full expected meaning

**Location:** `database/data_generation/04_generate_acquisition_and_inventory.sql:22-25, 129-181, 247-293`.

The phase allows vehicle statuses `SUBMITTED` or `IN_STOCK`; updates only `SUBMITTED` rows. Likewise it updates inventory location only while it is `D3-YARD-A`, and updates submissions only while status is `SUBMITTED`. Existing expected-key rows can therefore be skipped by anti-joins, then accepted because they happen to be in a permitted later state. Some payload comparisons cover inventory and movement but do not establish every expected offer/agreement/acquisition/movement row one-to-one. This is particularly fragile after partial execution or external edits.

**Why it matters:** The package promises exact-payload matching and safe failure for inconsistent partial executions. Accepting a broad status without a full cohort-state proof can mask inconsistency.

**Recommended correction:** Define the only allowed pre-run states per cohort and verify their complete expected values, including offer/agreement linkages, movement chains, current inventory position, submission state and vehicle state, before any write. After insertion, assert exact cohort cardinalities and payloads, not only existence.

### MEDIUM — Phase 05 does not fully assert generated image/enquiry/listing payloads and mutable inventory references

**Location:** `database/data_generation/05_generate_marketplace_activity.sql:111-150, 208-271`.

Image conflict checks cover matching `(listing_id, display_order)` keys, while listing/enquiry checks use natural keys; post-insert validation focuses on active listing/reservation uniqueness and listing branch versus current inventory branch. It does not verify exact cardinality and all payload fields for each expected image, enquiry, reservation and listing before commit. Listing branch is derived from the inventory row as it exists at execution time, but the deterministic event payload is not independently specified by the expected listing rows. A prior partial run or external status/location change can therefore affect expected data.

**Why it matters:** A successful transaction can report expected insert/skip arithmetic without proving all exact rows were present and unchanged.

**Recommended correction:** Build expected listing/image/enquiry/reservation payloads including branch, status and timestamps; compare and assert one exact row for each key both before and after insert. Validate that only the expected inventory state/location is used.

### MEDIUM — Phase 06 order and fulfillment updates do not validate every event before commit

**Location:** `database/data_generation/06_generate_sales_finance_delivery.sql:75-154, 168-271`.

The phase performs useful checks for order items, payment references, refunds, transfers and deliveries, but not all are complete. In particular the sale ownership-history insertion checks a row with matching `(vehicle_id, valid_from)` only through a limited conflict path, and the subsequent updates to vehicle owner/status, inventory status, listing status and prior ownership interval are cohort-wide state mutations. Not all update targets are constrained by exact expected prior values, so a mismatch can be overwritten instead of rejected. Existing non-D3 rows related by a D3 vehicle/order can also be affected by broad joins.

**Why it matters:** Later-phase mutations are the highest risk for fixture preservation and rerun safety. The surrounding transaction makes errors atomic, but it cannot protect values that the script intentionally overwrites without first proving they are expected.

**Recommended correction:** Before each `UPDATE`, assert exact expected source row(s), original value(s), and target cardinality. Restrict all updates to the unique generated event keys, then verify the complete resulting chain and preserved unrelated rows before commit.

### LOW — Plan and implementation claims exceed what the validator currently establishes

**Location:** `docs/14_day3_synthetic_data_generation_plan.md` “Prepared implementation files” and “Data-quality validation strategy”; `docs/15_day3_synthetic_data_generation_implementation_report.md` “Static checks performed”; `database/data_generation/README.md:7-10, 26`.

The documentation describes exact payload checks, complete cross-row workflow validation and target checks. The scripts implement some of these, but the validator does not turn its output into an explicit pass/fail and several phase assertions are partial. The plan's movement target narrative includes dispatches added in Phase 06, while Phase 04 reports only 54 expected movements (31 receipt + 23 transfer), so operators should interpret the phase and cumulative counts distinctly.

**Why it matters:** Operational instructions can overstate what a green-looking phase result or completed validator proves.

**Recommended correction:** After code corrections, align documentation with the implemented checks and state explicitly which target counts are cumulative and which are phase deltas.

## Phase-by-phase assessment

| Phase | Assessment |
|---|---|
| 0 — Preflight | Read-only in intent. Confirms database existence/access/state, modeled schema/table and object totals, trust/disabled health, approximate counts and fixture markers. High finding: registration namespace is omitted from the status-driving collision count. The count-only structural checks do not compare actual constraint/index definitions to expected definitions. |
| 1 — Customers and staff | Insert order and FK dependencies are appropriate; generated employee/customer keys are deterministic; transaction and lock are present. Contact/address/role key checks do not uniformly compare all alternate-key cases; review exact payload and uniqueness behavior before generation. It requires branches/cities and rejects unclassified employee/customer rows. |
| 2 — Catalog and vehicle intake | Existing catalog is reused and parent keys are resolved by names. VIN, registration, owner and submission dependencies are ordered correctly. Medium finding: postconditions are not full one-to-one payload proofs. |
| 3 — Inspection and valuation | Inspection/report/item/defect/valuation insertion order follows FKs; generated counts correspond to 57 new reports + 3 fixture, 411 + 9 checklist items, 99 + 1 defects, and 52 + 3 valuations. Medium finding: exact-key coverage and complete payload validation are not consistent for partial/conflicting states. |
| 4 — Acquisition and inventory | Offers precede agreements, acquisitions, inventory, then movement ledger. Mutations are transactional. Movement/inventory state is updated for generated cohort. Medium finding: accepted later states can mask partial or externally changed payloads without full-state proof. |
| 5 — Marketplace | Listings precede images/enquiries/reservations; active listing and reservation policy checks exist across vehicle history. Medium finding: exact row coverage is not proven for every generated payload; listing branch relies on live inventory position. |
| 6 — Sales, finance and delivery | Order/item/payment/refund/transfer/delivery sequencing and several amount/party checks are present. High finding: all listing versions on sold vehicles are rewritten. Additional medium finding: broad state updates need stronger precondition and target scoping. |
| Final validator | Read-only queries cover counts, status mixes, temporal ownership/registration, cross-row relations and DBCC constraint checks. High finding: no aggregate readiness/failure status; counts are reported but not asserted. |

## SQL safety analysis

- No destructive DML or DDL was found in the Day 3 package. Generation uses `INSERT` and intentional cohort state `UPDATE`s only.
- No identity values are hard-coded or reset. Identity keys are resolved by natural keys and actual table joins.
- No constraints or triggers are disabled; no schema changes are present.
- All six mutation phases set `XACT_ABORT ON`, use a transaction-owned exclusive application lock, have `TRY/CATCH`, and roll back when `XACT_STATE() <> 0`. This is a sound atomicity pattern for errors occurring after `BEGIN TRANSACTION`.
- Important boundary: several preflight and conflict checks execute before `BEGIN TRANSACTION`/application lock. Concurrent writers or a second actor can change matching data between check and insert. The app lock serializes only cooperating Day 3 sessions, not arbitrary database writers. Unique constraints may reject some races and roll back, but do not prove full payload equivalence. Move critical precondition checks inside the locked transaction and use appropriate isolation/locking for checked key ranges.
- `00_pre_generation_checks.sql` uses read-only catalog queries and SELECTs. `10_validate_generated_data.sql` uses SELECTs and read-only `DBCC CHECKCONSTRAINTS`; no write operation was found there.

## Idempotency and rerun analysis

The scripts are not blind rerunnable imports. Exact repeated execution from the documented intended end state is partly supported through natural-key anti-joins and exact-match skips, but later phases mutate earlier states. Conflicts generally raise errors and phase transactions roll back, which is a useful safeguard. The package still has gaps: collision status omission in preflight, pre-transaction checks, incomplete exact payload assertions, and broad lifecycle updates can make a rerun either stop inconsistently or overwrite a related row. A failed phase after `BEGIN TRANSACTION` should roll back its own phase; previously committed phases remain committed and need exact reconciliation. A failure before the transaction performs no phase writes. Existing deterministic keys with changed payload are caught only where the specific conflict predicate covers the row/key. This is not sufficient to certify the package's stated fail-safe behavior.

## Schema compatibility and integrity

Static cross-check against the Day 2 DDL found the named schemas and tables aligned with the modeled 10-schema/34-table design, and the generation order generally follows FK dependencies. Identity columns are omitted from inserts. Amounts use `decimal(19,4)` where generated. Status values and codes visibly follow the documented domains. The SQL uses SQL Server T-SQL constructs (`THROW`, table variables, `TRY/CATCH`, `sp_getapplock`, `STRING_AGG`, `DBCC CHECKCONSTRAINTS`). The validator's dynamic count SQL quotes schema/table identifiers with `QUOTENAME`; names are from a local table variable rather than user input.

Static review cannot confirm the live database has these exact definitions. Preflight and phase guards compare totals, not each constraint/index definition, and can be satisfied by a different object composition with the same counts. The scripts also rely on expected Day 2 fixture natural keys and exact data contents; these are documented prerequisites, not verified live facts.

## Transaction and rollback analysis

Each phase uses one transaction for its own inserts and state updates, with `XACT_ABORT ON` and rollback in `CATCH`. No transaction spans the whole six-phase workflow; earlier phases remain committed when a later phase fails, as intended for modular diagnosis. Application locks have a zero timeout, so concurrent attempts fail promptly. However, key validation before the transaction/lock leaves a race window. Also, rollback does not address correctness issues from updates that overwrite unexpected values; those need pre-update assertions and narrower predicates.

## Static validation results

- No SQL Server execution, connection, or live data inspection was performed.
- No SQL parser was run as part of this independent audit. The implementation report's claim that ScriptDom parsed the scripts is recorded as a prior report claim, not independently reproduced evidence.
- Manual static inspection found no destructive commands, unsafe user-controlled dynamic SQL, or SQLCMD file inclusion.
- Manual SQL Server compatibility review found the primary syntax idioms appropriate for T-SQL. Runtime compilation remains unverified.
- No tests or infrastructure changes were added.

## Explicitly unverified

- Whether `chakri\SQLEXPRESS` and `CARS24DataModelingSystem` exist, are accessible, online, writable, or contain the expected Day 2 fixture.
- Actual object definitions, nullable columns, identity properties, trust states, triggers, row counts, deterministic key collisions, current lifecycle statuses, or baseline data quality in the live database.
- Runtime SQL Server compilation, transaction behavior, application-lock behavior, dynamic SQL output, and all resulting rows.
- Whether registration strings conflict with any live row, especially because preflight status currently ignores that family.
- Whether target row totals are appropriate for the live baseline; targets are documented cumulative comparisons, not permission to remove rows.

## Final recommendation

**BLOCKED — HIGH ISSUES.** Do not run the generation phases. Correct the preflight collision status, scope Phase 06 listing updates to the exact active listing, and make the final validator produce a definitive failure/pass result. Then strengthen exact payload and precondition checks for partial/rerun states, re-audit the revised SQL, and only then consider the read-only preflight. No database action was taken during this audit.

## Remediation follow-up (2026-11-20)

The generation package was edited after this audit. The edits add registration/engine/ownership/submission key families to the preflight's blocking namespace count; make the preflight collision status fail closed; strengthen Phase 02 exact payload postconditions; add Phase 03 row reconciliation; require complete-or-absent Phase 04 cohorts and check lifecycle update cardinalities; add Phase 05 payload/cardinality checks; and change the listing cohort so Phase 06 can transition only the exact active listing for each completed sale. Phase 06 now checks the exact eight listing/order contexts, updates only those active rows, and asserts affected-row counts for key sale state updates. The final validator now compares exact cumulative target counts, attempts to capture `DBCC CHECKCONSTRAINTS` output, accumulates selected workflow failures and returns an aggregate status.

This follow-up is a source-change record, not a completed re-audit. The original **BLOCKED — HIGH ISSUES** conclusion remains in force until a fresh line-by-line review confirms the revised SQL, including SQL Server compilation of the new `INSERT ... EXEC DBCC CHECKCONSTRAINTS` capture, and resolves any remaining medium findings. No SQL parser or SQL Server execution was run; no database was contacted. In particular, not every diagnostic result set in the validator is currently folded into its aggregate failure table, and further review is required before its `PASS` can be treated as a complete application-level certification.
