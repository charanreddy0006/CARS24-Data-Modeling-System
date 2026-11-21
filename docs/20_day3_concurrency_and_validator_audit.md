# Day 3 Concurrency and Validator Audit

**Audit date:** 2026-11-20  
**Readiness:** **BLOCKED — HIGH ISSUES**  
**Scope:** Independent static audit of current repository source. No SQL was connected to or executed.

## 1. Executive summary

The revised sources address several issues raised in the prior audits: deterministic key-family reporting is broader, the movement aggregate uses `LAG`, database/object-health checks feed the final validator status, Phase 05 has per-vehicle state checks, and Phase 06 rejects HELD inventory for planned sales.

Two high findings remain:

1. **Concurrency boundary:** in every generation phase, material prerequisite, duplicate, payload, and lifecycle prechecks execute before `BEGIN TRANSACTION` and before that phase's exclusive application lock. The phase lock serializes only cooperating sessions using that exact resource. It cannot make those earlier checks atomic and does not coordinate unrelated writers. Several Phase 06 updates do not include the expected prior state in their `WHERE` clause, so a changed row can be overwritten after the precheck.
2. **Validator completeness:** `10_validate_generated_data.sql` checks exact table counts, selected D3 cohorts, relationships and lifecycle aggregates, but it does not reconstruct the complete expected payload for the generated entities. Equal counts can hide a missing expected row replaced by an unexpected or wrong-payload row. No entity family meets complete payload validation in the final validator.

**Recommendation:** do not proceed to read-only preflight based on this source review. Resolve the transaction boundary and validator payload gap, then commission another independent audit. This is not a runtime certification.

## 2. Files reviewed

- All SQL files under `database/data_generation/`: preflight, Phases 01–06 and final validator.
- `docs/18_day3_independent_reaudit_report.md` and `docs/19_day3_completion_remediation_report.md`.
- `docs/14_day3_synthetic_data_generation_plan.md`, `docs/15_day3_synthetic_data_generation_implementation_report.md`, and `database/data_generation/README.md`.
- Day 2 schema and seed sources, including `database/04_core_tables.sql`, `database/05_vehicle_catalog.sql`, `database/06_vehicle_identity.sql`, `database/07_lifecycle_tables.sql`, `database/08_constraints.sql`, `database/09_indexes.sql`, `database/10_seed_reference_data.sql`, and relevant table definitions in setup scripts.

## 3. Concurrency architecture

Every generation script uses `SET XACT_ABORT ON`, a `TRY/CATCH`, an explicit transaction, an exclusive `sp_getapplock` with `@LockOwner='Transaction'`, and rollback when `XACT_STATE()<>0`. Each resource is phase-specific (`CARS24-Day3-Phase01` through `Phase06`), each uses `@LockTimeout=0`, and each checks a negative lock return code. The lock is taken after `BEGIN TRANSACTION` and is released automatically at commit or rollback. Writes and postconditions are inside the transaction; the major prechecks are not.

### Exact phase ordering

| Phase | Prechecks before transaction | Transaction and lock | Writes and postconditions | Commit / rollback |
|---|---|---|---|---|
| 01 | Lines 8–135: target/schema prerequisites, natural-key payload checks, ambiguity and expected cohort checks. | `TRY` 137; transaction 138; lock 140 (`Phase01`). | Inserts 144–168; postconditions 170–188. | Commit 190; catch/rollback/rethrow 199–205. |
| 02 | Lines 8–106: catalog/prerequisites, deterministic source cohorts, VIN/engine/registration collisions, ownership and submission checks. | `TRY` 108; transaction 109; lock 111 (`Phase02`). | Inserts 115–137; postconditions 139–209. | Commit 211; catch/rollback/rethrow 219–224. |
| 03 | Lines 6–98: cohort, inspection/report/item/defect/valuation payload and ambiguity checks. | `TRY` 100; transaction 101; lock 103 (`Phase03`). | Inserts 107–150; postconditions 154–209. | Commit 211; catch/rollback/rethrow 220–225. |
| 04 | Lines 6–122: cohort completeness, expected state, offers/agreements/acquisition/inventory/movement payload checks. | `TRY` 124; transaction 125; lock 127 (`Phase04`). | Inserts 131–175; updates 178–193; postconditions 196–210. | Commit 212; catch/rollback/rethrow 221–226. |
| 05 | Lines 6–110: Phase 04 cohort, listing/image/enquiry/reservation conflicts, active holds and per-vehicle source states. | `TRY` 112; transaction 113; lock 115 (`Phase05`). | Inserts 119–146; lifecycle updates 149–156; postconditions 164–220. | Commit 221; catch/rollback/rethrow 229–234. |
| 06 | Lines 6–167: active listing/reservation cohorts, deterministic order/payment/transfer/delivery keys, ownership and source state checks. | `TRY` 169; transaction 170; lock 172 (`Phase06`). | Inserts 176–235; state/listing updates 238–281; dispatch insert 283–290; postconditions 292–309. | Commit 311; catch/rollback/rethrow 323–328. |

Precheck `THROW`s occur before the `TRY/CATCH` and before any phase writes, so they do not leave that phase's transaction open. A failure after transaction start is caught and rolled back before rethrow. A successful phase commits all its own writes atomically; this does not undo previously committed phases.

### Locking and race analysis

- **Same phase, cooperating sessions:** both sessions can perform prechecks concurrently. The first to acquire the phase resource proceeds. A second receives the immediate timeout/failure after it reaches the lock and should do no writes because the lock check precedes inserts; it then rolls its empty transaction back. This is useful serialization, with a fail-fast rather than wait behavior.
- **Different phases:** resource names differ. The locks do not serialize Phase 02 against 03, Phase 04 against 05, or Phase 05 against 06. The README's one-session ordered procedure is an operational control, not an enforced dependency lock. Concurrent downstream phases will often fail their cohort prechecks, but this is not a substitute for serialization and can yield confusing partial observations.
- **Unrelated writers:** ordinary sessions do not request these application locks. They can change a row after a precheck and before the generator enters its transaction. Declared unique indexes can reject some duplicate inserts; they do not protect all composite event keys or lifecycle assumptions.
- **Isolation:** no phase sets an explicit transaction isolation level. Several insert anti-joins use `UPDLOCK,HOLDLOCK` inside the write transaction (for example Phase 01 lines 147–172; Phase 04 lines 135–175; Phase 06 lines 179–289). These can protect the particular searched key ranges when supported by an appropriate access path. They do not protect prechecks run before the transaction, every cross-row invariant, or unrelated update targets. There are no universal unique constraints for all natural events; the movement index on inventory/time is non-unique, and transfer/delivery order-item indexes are non-unique.
- **Stale update risk:** Phase 06 validates source state before locking (lines 144–156), then updates vehicle owner/status at 248–254 and inventory status at 256–259 by cohort/order joins without requiring the exact old status in each update predicate. A writer that changes a target after precheck may have that new state overwritten. The active listing update is narrower (`status='ACTIVE'`, lines 262–279), and its count is checked, but that does not close the earlier race.
- **Phase 05 stale state:** source pairs are validated at 101–110, while later updates at 149–156 accept state sets in their predicates. A non-cooperating writer can modify a row between these points. The postcondition catches many inconsistencies before commit but does not provide an atomic prior-state guarantee against a writer that changes a row after the check or an update that does not conflict with it.
- **Unique indexes:** Day 2 defines useful protection including VIN, active listing per vehicle, active reservation per listing, payment provider/reference, refund reference, and sales order item uniqueness. They do not cover every generated natural key: customer contacts are indexed non-uniquely; registration number and event-time tuples are not universally unique; transfer/delivery per order item are indexed non-uniquely; movement inventory/time is non-unique. Therefore constraints are not an adequate substitute for serialized prechecks and postconditions.

### Recommended transaction design

The practical design is to start the transaction, acquire the phase lock, and perform critical prerequisite/key/payload/state checks inside the protected transaction immediately before writes. Use exact prior-state predicates in updates and assert affected-row counts. For races with non-cooperating writers, use suitable indexed key-range locks (such as `UPDLOCK,HOLDLOCK` on exact keys) or a carefully chosen serializable strategy for cross-row invariants; review deadlock and blocking consequences. Keep the phase locks distinct if phases remain independently callable, and add an orchestration lock/resource or explicit dependency guard if concurrent phases must be prohibited. Application locks coordinate only participants that request compatible resource names/modes. No SQL was modified during this audit.

## 4. Final validator payload completeness

The validator has cumulative target counts at lines 15–23, descriptive cohorts at 36–43, status distributions at 46–62, detail diagnostics at 64–127, DBCC capture at 131–134, and aggregate findings at 145–280. The following classification asks whether the *final validator itself* reconstructs expected row values, not whether a generation phase has its own post-insert assertions.

| Entity/event family | Classification | Final validator evidence / gap |
|---|---|---|
| Employees | KEY/COUNT ONLY | D3 code cohort count (lines 159–160); no expected employee branch/name/active date payload. |
| Customers | KEY/COUNT ONLY | Name namespace count (161–162); no legal name/status/date payload comparison. |
| Contacts | KEY/COUNT ONLY | Included in total table counts; no D3 contact type/value/verification payload reconstruction. |
| Addresses | KEY/COUNT ONLY | Included in total counts; no D3 address/city/type/postal/date payload comparison. |
| Catalog | KEY/COUNT ONLY | Cumulative brand/model/variant counts only; D3 does not create catalog rows. |
| Vehicles | PARTIAL PAYLOAD VALIDATION | D3 count, ownership projection and linked checks; no full VIN-to-model/year/engine/fuel/transmission/created payload comparison. |
| Registrations | PARTIAL PAYLOAD VALIDATION | Cumulative count and overlapping-validity check (225–227, 263–264); no exact D3 registration-to-vehicle/state/date comparison. |
| Ownership history | PARTIAL PAYLOAD VALIDATION | Current-owner, overlap and transfer-prior checks (220–229, 259–262); no complete expected initial and sale history comparison. |
| Submissions | KEY/COUNT ONLY | Count indirectly represented through target table count; no exact seller/branch/time/status/closed-at comparison. |
| Inspections | KEY/COUNT ONLY | D3 count (163–168); no expected inspector/time/status payload. |
| Reports | PARTIAL PAYLOAD VALIDATION | Count and relationship checks; no full outcome/summary/finalized-at expected payload. |
| Inspection items | PARTIAL PAYLOAD VALIDATION | Count and defect/report linkage; not exact expected item-code/outcome/note set. |
| Defects | PARTIAL PAYLOAD VALIDATION | D3 count and item/report linkage (191–200); not complete category/severity/amount/currency payload. |
| Valuations | PARTIAL PAYLOAD VALIDATION | Count and vehicle/report match (193–202); no amount/assessor/time/basis/status payload comparison. |
| Offers | KEY/COUNT ONLY | D3 count through vehicle/submission joins (169–170); no exact offer value/status/expiry payload. |
| Agreements | KEY/COUNT ONLY | D3 count through offer chain (161–162); agreement reference/status are not reconstructed as complete expected rows. |
| Acquisitions | PARTIAL PAYLOAD VALIDATION | Seller/vehicle/agreement/status relationship checks (195–206); no amount/currency/acquired-at expected payload. |
| Inventory | PARTIAL PAYLOAD VALIDATION | Count, acquisition existence and D3 location projection (197–206, 251–254); no complete branch/status/since-at payload per expected VIN. |
| Movement ledger | PARTIAL PAYLOAD VALIDATION | D3 type counts, continuity, duplicate timestamp, allowed type and location checks (169–178, 240–254); not exact event-by-event employee/reason/time/source/destination reconstruction. |
| Listings | PARTIAL PAYLOAD VALIDATION | Count, active uniqueness and inventory availability (179–181, 207–209, 230–237); no exact listing branch/price/currency/description/status/closed-at payload. |
| Listing images | KEY/COUNT ONLY | D3 image count only (180–182); no expected image reference/caption/display-order payload. |
| Enquiries | KEY/COUNT ONLY | D3 reference count only (182); no expected listing/customer/employee/channel/time/status payload. |
| Reservations | PARTIAL PAYLOAD VALIDATION | Count, active uniqueness, order buyer/listing link and active-listing lifecycle (183, 207–211, 230–239); not every reservation's expected customer/time/expiry/released/status payload. |
| Orders | PARTIAL PAYLOAD VALIDATION | Count and completed-sale uniqueness/payment relationships; no full buyer/time/status/currency/confirmation/completion/cancellation payload comparison. |
| Order items | PARTIAL PAYLOAD VALIDATION | Count and buyer/reservation/listing/vehicle relationship checks; no complete expected reservation/sale-price/currency row comparison. |
| Payments | PARTIAL PAYLOAD VALIDATION | D3 count, currency and completed-sale aggregate amount checks (184–190, 212–216, 265–266); not all provider/method/reference/timing/status payloads. |
| Refunds | PARTIAL PAYLOAD VALIDATION | D3 count and successful-refund upper bound (188–190, 215–216, 273–274); not expected payment link/amount/currency/times/status per reference. |
| Ownership transfers | PARTIAL PAYLOAD VALIDATION | D3 count and buyer/prior/current-owner/evidence checks (189–190, 217–222, 267–272); no complete transfer party/time/reference payload reconstruction. |
| Deliveries | PARTIAL PAYLOAD VALIDATION | D3 count, recipient/order, status/date chronology and duplicate checks (189–190, 217–224, 267–272); no full branch/address/reference/schedule/completion payload. |

**No family is COMPLETE PAYLOAD VALIDATION in the final validator.** A table can meet its exact total while one expected row is missing and another unexpected row takes its place. Phase-level reconciliation is valuable, but does not make the final validator independent of generation-time checks.

## 5. Aggregate validator assessment

### Positive controls

- The wrong-database guard returns `BLOCKED` before checks (lines 5–9).
- Exact cumulative table counts are generated for all 34 modeled tables and compared to targets (15–32, 138–143).
- Database state, disabled/untrusted FK/CHECK constraints and disabled indexes are included in failure counts (148–155).
- DBCC output is captured before final aggregation and its row count contributes (131–134, 258). A DBCC/runtime error aborts before final status; it cannot silently become zero findings.
- Movement aggregate and displayed diagnostic both use `LAG` ordered by event time and movement ID (92–99, 240–250). D3 type counts are 31 receipts, 23 transfers, eight dispatches; cumulative movement target is 63 (one Day 2 receipt + 62 Day 3 events).
- Whole-database variants of several previously D3-only diagnostics are included, including ownership, registration, defect/report, valuation/report, acquisition, inventory, order/reservation, payment, transfer/delivery, and refund checks (199–206, 233–274).
- Final status is calculated after all aggregate inserts, and nonzero failure counts yield `FAIL` (275–280). A SQL error before that point aborts the batch.

### Remaining completeness limits

- Exact totals do not prove expected keys or payloads. D3 count expressions commonly use broad markers (`LIKE` and dates) and can miss a missing row replaced by an unexpected row with matching marker/count.
- Several duplicate conditions are only partly detected. Event natural keys without a declared unique constraint are not all counted explicitly at final validation; e.g. duplicate enquiry references, duplicate agreement/payment/refund references beyond what unique indexes enforce, and duplicate listing-image logical keys. Some are expected to be rejected by constraints or phase checks, but the final validator is required to stand independently.
- The movement check catches duplicate inventory/timestamp rows and invalid types, but doesn't compare every event against an expected per-VIN event ledger; wrong employee, reason, or a different timestamp can pass if counts and continuity still agree.
- D3 status/lifecycle validation is largely generic. It does not assert every expected reservation/listing/order status per generated key, nor the complete exact status transition matrix.
- Some aggregate predicates use `<>` against nullable columns. SQL three-valued logic can make a comparison UNKNOWN rather than true; missing nullable current-owner/party values need explicit `IS NULL` handling where the rule requires a value (for example transfer owner joins at 217–222 and 267–269).
- `DBCC CHECKCONSTRAINTS` contributes correctly when it returns violations, but it is not guaranteed to find all constraint violations (documented in the prior audit report); application-level checks remain necessary.

Therefore, the aggregate is materially improved and fail-closed for SQL errors in its own check sequence, but it is not a complete payload validation system. A final PASS only means the implemented checks returned zero, not that all planned payload fields were independently proven.

## 6. Preflight audit

`00_pre_generation_checks.sql` selects the target DB identity/access/state and returns before deeper reads if missing, inaccessible, offline or read-only (lines 10–37). The dynamic body checks expected schemas/tables, structural object totals, disabled/untrusted constraints/indexes, baseline markers, row counts and key families (40–191). The dynamic body contains reads/catalog queries and table variables; no persistent write or DDL was found.

The 52-family matrix includes customer email/phone/address namespaces and deterministic event families through delivery (128–163); `@D3KeyCount` is the sum of those rows and drives `BLOCKED_RECONCILE_EXISTING_D3_KEYS` (172, 178–180). VIN, engine and registration patterns are present. This is substantially broader and status-driving.

Limitations: several checks are broad namespace counts rather than generated-key equality comparisons, so false-positive reconciliation is possible; conversely, event rows are found through parent cohorts/references, and no complete generated expected-key table is reconstructed. Day 2 fixture mismatch currently checks selected counts (employees/customers/VINs/branches, lines 173–177) rather than the payload of all seed markers shown in diagnostics at 108–124. Structural totals can match despite a same-count object substitution or altered definition. Preflight is read-only and fail-closed for the conflicts it enumerates, but its PASS should mean only “these enumerated static prerequisites were observed,” not full baseline certification.

## 7. Phase-by-phase integrity assessment

| Phase | Static integrity assessment |
|---|---|
| 01 — Customers and staff | Deterministic employee/customer/contact/address source rows, pre-insert conflict checks and post-insert payload checks exist. Some unique natural keys are not enforced by unique constraints. All material checks precede lock/transaction. |
| 02 — Catalog and vehicle intake | Uses existing catalog; checks VIN, engine and registration alternatives, plus ownership/submission payloads and postconditions. Registration validity uniqueness is temporal logic, not a declared unique key. Checks precede lock/transaction. |
| 03 — Inspection and valuation | Expected inspection/report/item/defect/valuation payloads are checked within the phase transaction after inserts; parent relationships follow FK order. Inspection event uniqueness is partly application-defined. Initial conflict reads precede transaction/lock. |
| 04 — Acquisition and inventory | Offer → agreement → acquisition → inventory → receipt/transfer sequence is coherent, with updates and postconditions inside transaction. Movement event natural key has no unique DDL constraint; prechecks precede lock/transaction. |
| 05 — Marketplace | Listing/image/enquiry/reservation inserts are FK-ordered; exact phase payload checks and lifecycle postconditions are present. Active listing/reservation have filtered unique indexes, but many event keys do not. Prechecks precede lock/transaction. |
| 06 — Sales, finance, delivery | Exact listing update preserves unrelated listing history; order/finance/transfer/delivery events and owner/inventory/listing updates have row-count and postcondition checks. Vehicle/inventory updates are broader than a prior-state conditional update. Initial checks precede lock/transaction. |

The README directs sequential one-session operation. That lowers operator-created overlap but does not protect against other sessions, manual writers, or a caller that runs a downstream script independently.

## 8. SQL safety and Day 2 preservation

Static search of `database/data_generation/` found no unintended `DELETE`, `DROP`, `TRUNCATE`, identity reseed, constraint/trigger disabling, schema alteration or destructive DDL. The phase scripts insert deterministic cohort data and update selected lifecycle fields; they do not intentionally rewrite the documented Day 2 rows. Phase 06 listing scope is restricted to its matching active listing. No database or schema was modified during this audit.

## 9. Static validation and unverified items

- Reviewed batch boundaries and `BEGIN TRY/TRANSACTION/COMMIT/CATCH/ROLLBACK` ordering by source line inspection. Each phase has a single `GO` ending its script; preflight and validator have explicit batch boundaries.
- Reviewed application-lock resources/modes/owners/timeouts and transaction ownership. No static SQL Server parser was found among available command tools. `sqlcmd` is present as a client but was not invoked; it is not a parser-only validation path for this restricted task.
- Reviewed generator-to-validator target arithmetic and movement sequence against Phase 04/06 and Day 2 movement DDL/seed. No SQL compilation, SQL Server connection, preflight, validator, or generation was run.
- Live database state, actual constraints/indexes, SQL Server version/compatibility, permissions, concurrent workload and runtime lock behavior are unknown.
- No SQL was changed. No changes were staged, committed, or pushed.

## 10. Findings and recommendation

### HIGH — Phase prechecks are outside the lock/transaction

**Locations:** Phase 01 lines 8–135 vs 137–141; Phase 02 8–106 vs 108–112; Phase 03 6–98 vs 100–104; Phase 04 6–122 vs 124–128; Phase 05 6–110 vs 112–116; Phase 06 6–167 vs 169–173. Phase 06 vulnerable broad state updates are at 248–259.

**Impact:** The state checked is not guaranteed to be the state mutated. The phase-specific app lock only protects participating callers after they acquire it. Unique indexes do not cover all event keys or cross-row invariants.

**Recommendation:** Move critical checks under the transaction and after lock acquisition; apply exact prior-state predicates to updates; use suitable key-range/isolation controls for relevant keys; and enforce phase dependency serialization.

### HIGH — Final validator does not independently validate complete expected payloads

**Locations:** target/cohort setup 15–62; selected aggregate predicates 157–274.

**Impact:** A matching count can conceal wrong or substituted records. The validator is not an independent payload oracle for any listed family.

**Recommendation:** Add read-only expected-row relations per generated family and compare keys/payloads in both directions (including duplicates and unexpected rows), or explicitly limit the validator's claim and require complete phase evidence. Include nullable-field handling and event-level movement expected rows.

### MEDIUM — Preflight baseline certification is partial

**Locations:** `00_pre_generation_checks.sql:108–124, 173–177`.

**Impact:** Displayed seed markers are not all status-driving exact payload checks; structural object counts do not detect same-count definition substitution. A PASS can coexist with some unexamined baseline drift, although the key matrix and core structural checks now block many conflicts.

**Recommendation:** If preflight is intended to be a full readiness gate, make all expected Day 2 fixture and object-definition checks status-driving, or clearly label its limited scope.

### Final recommendation

**BLOCKED — HIGH ISSUES.** Remediate transaction/precheck ordering and validator payload reconstruction, then obtain a fresh independent audit. Do not infer readiness for preflight or generation from this static report.
