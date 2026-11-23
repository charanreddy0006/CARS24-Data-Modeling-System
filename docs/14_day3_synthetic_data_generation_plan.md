# Day 3 Synthetic Operational Data Generation Plan

> **Runtime status update (2026-11-22):** Pre-generation checks passed. Phases 01-04 have since been executed and committed with PASS results. Phase 04 inserted 49 offers, 34 agreements, 31 acquisitions, 31 inventory positions, and 54 movement rows (199 total); its independent SELECT-only verifier returned 12 checks with failure_count 0. Phases 05-06 and the independent final validator have not been executed. The five Phase 03 family counts sum to 681; the earlier 721 figure was an erroneous aggregate in the supplied execution summary. Historical plan and review notes below describe their respective snapshots. See `docs/24_day3_synthetic_generation_execution_report.md` and `docs/26_day3_completion_report.md` for current progress.

## Objective

Plan a deterministic, reviewable synthetic workload for the independent educational used-car marketplace model. Day 3 data should support OLTP workflow practice, joins, aggregates, operational reporting, and later analytical modeling. This plan does not claim to represent CARS24 internal systems.

This is a schema and implementation plan. At the time this plan was first prepared, no Day 3 generator had been executed and no SQL had been run against SQL Server. The later runtime progress is summarized in the status update above; the database's complete row-level state has not been independently validated because the final validator remains unexecuted.

## Scope and guardrails

- Preserve the existing Day 2 database, its objects, its three-vehicle synthetic fixture, and any user data.
- Do not drop, truncate, delete, reset identities, disable constraints, or recreate objects.
- Treat the counts in `10_seed_reference_data.sql` as the expected Day 2 fixture baseline, not proof of the current database contents.
- Before any future data execution, run the read-only `database/12_diagnose_existing_database_state.sql` in SSMS and review its complete output. The checked-in diagnostic reports object state, approximate row counts, seed markers, constraints, indexes, and integrity checks; this review did not execute it.
- Do not continue a generation phase if actual rows conflict with its deterministic synthetic keys or the expected baseline. Report the conflict and require a reviewed recovery decision.

## Schema review findings

The physical source defines 10 schemas and 34 tables. The dependency and status domains below are taken from the SQL DDL, especially files `03` through `09`; the Day 1 business rules document supplies workflow rules not enforced by row constraints.

| Schema | Tables | Generation considerations |
|---|---|---|
| `ref` | City | Only modeled reference relation. City/state/country is unique; state and country codes must be uppercase. |
| `core` | Branch, Employee, EmployeeRole, Customer, CustomerContact, CustomerAddress | Branch states: `ACTIVE`, `INACTIVE`, `CLOSED`; customer: `ACTIVE`, `INACTIVE`, `SUSPENDED`; contact type: `EMAIL`, `PHONE`, `OTHER`; address type: `HOME`, `MAILING`, `DELIVERY`, `OTHER`. PIN must be six numeric digits. Effective intervals must have end after start. |
| `vehicle` | VehicleBrand, VehicleModel, VehicleVariant, Vehicle, VehicleRegistration, VehicleOwnershipHistory, VehicleSubmission | Catalog keys are unique by brand/model/variant. Vehicle fuel: `PETROL`, `DIESEL`, `CNG`, `ELECTRIC`, `HYBRID`; transmission: `MANUAL`, `AUTOMATIC`, `AMT`, `CVT`, `DCT`; lifecycle: `SUBMITTED`, `UNDER_REVIEW`, `ACQUIRED`, `IN_STOCK`, `LISTED`, `RESERVED`, `SOLD`, `WITHDRAWN`, `REJECTED`. Registration number/date is unique; year is 1886–2100. |
| `inspection` | Inspection, InspectionReport, InspectionItem, Defect, VehicleValuation | Inspection: `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`, `NO_SHOW`; report outcome: `PASS`, `FAIL`, `CONDITIONAL`; checklist outcome: `PASS`, `FAIL`, `NOT_APPLICABLE`, `NOT_CHECKED`; valuation: `DRAFT`, `APPROVED`, `REJECTED`, `SUPERSEDED`. A report is unique per inspection and checklist item code is unique per report. Defect category/severity are checked code sets. |
| `acquisition` | PurchaseOffer, PurchaseAgreement, VehicleAcquisition | Offer: `DRAFT`, `ISSUED`, `ACCEPTED`, `DECLINED`, `EXPIRED`, `WITHDRAWN`; agreement: `SIGNED`, `VOID`, `CANCELLED`. One acquisition per agreement. Amounts are nonnegative and currency codes uppercase. |
| `inventory` | Inventory, InventoryMovement | Inventory: `AVAILABLE`, `HELD`, `IN_TRANSIT`, `PREPARATION`, `SOLD`, `NOT_AVAILABLE`; one inventory row per vehicle. Movement: `RECEIPT`, `TRANSFER`, `DISPATCH`, `ADJUSTMENT`; source/destination branch and location pairs must be both null or both populated, and at least one endpoint is required. |
| `marketplace` | VehicleListing, ListingImage, CustomerEnquiry, VehicleReservation | Listing: `DRAFT`, `ACTIVE`, `PAUSED`, `CLOSED`, `WITHDRAWN`, `SOLD`; filtered unique index allows only one active listing per vehicle. Enquiry channel: `WEB`, `PHONE`, `BRANCH`, `PARTNER`, `OTHER`; status: `OPEN`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`. Reservation: `ACTIVE`, `CONVERTED`, `RELEASED`, `EXPIRED`; filtered unique index permits one active reservation per listing. |
| `sales` | SalesOrder, SalesOrderItem | Order: `DRAFT`, `CONFIRMED`, `COMPLETED`, `CANCELLED`. The explicit unique index imposes one item per order; reservation ID is unique when supplied. Order item must be checked against its reservation's listing/vehicle and buyer by workflow validation. |
| `finance` | Payment, Refund | Payment: `PENDING`, `SUCCEEDED`, `FAILED`, `REVERSED`; refund: `PENDING`, `SUCCEEDED`, `FAILED`, `CANCELLED`. Both amounts must be positive. Provider references are filtered unique indexes. Currency and aggregate refund limits require workflow validation. |
| `delivery` | OwnershipTransfer, VehicleDelivery | Transfer: `NOT_STARTED`, `SUBMITTED`, `IN_PROGRESS`, `COMPLETED`, `REJECTED`; delivery: `SCHEDULED`, `IN_TRANSIT`, `COMPLETED`, `FAILED`, `CANCELLED`. Transfer parties must differ. FK existence alone does not prove that they match the order parties. |

The schema has **no mileage/odometer column**, no structured condition grade, no standalone payment schedule/ledger balance, and no company owner entity. Mileage and condition can be described in inspection notes/defects and valuation basis, but cannot be queried as normalized numeric attributes without an approved schema change. Ownership history and `Vehicle.current_owner_customer_id` accept only customers; this cannot faithfully record a company as the legal owner after acquisition. Do not invent columns or encode company ownership as a fake customer.

The row constraints do not enforce several important relationships. Future generation validation must explicitly check that seller/customer/vehicle agree across submission, valuation, offer, agreement and acquisition; the inspector/assessor and branch are coherent; listing is backed by acquired inventory and an approved report; reservations/orders match customer, listing and vehicle; successful payments match the order currency and amount; cumulative successful refunds do not exceed captured payment; and transfer/delivery match the sold item and buyer. Inventory movements are append-only and must agree with the recorded position.

The 60 explicit indexes in `09_indexes.sql` were reviewed by key definition. They cover branch/customer/vehicle FK lookups, submission and valuation timelines, inventory movement history, marketplace enquiry/reservation histories, buyer order history, payment/refund history, and transfer/delivery joins. The descending time keys are on valuation, inventory movement, enquiry, reservation, sales order, payment, and refund access paths. Filtered indexes cover optional keys and unique policies for VIN, active listings/reservations, order reservation, and non-null provider references as declared. The source defines no `INCLUDE` columns. Generation does not need index changes; it must respect the filtered unique active-listing/reservation rules and the unique provider-reference rules.

Day 1's logical diagram says 59 relationships while the finalized DDL declares 62 FKs. The three additional DDL relations are InventoryMovement source branch, InventoryMovement destination branch, and PurchaseAgreement seller. The model's customer-only owner limitation also remains unresolved. Day 3 should not alter either Day 1 or Day 2 design silently.

## Existing seed/reference fixture

`database/10_seed_reference_data.sql` contains duplicate-guarded synthetic fixture statements. Its documented clean-install fixture is:

- 8 Indian cities and 8 branches: Hyderabad, Mumbai, Bengaluru, Pune, Delhi, Chennai, Ahmedabad, Rajkot.
- 4 synthetic employees and role rows; 3 synthetic customers, 3 contacts, and 3 addresses.
- 8 brands, 7 models, 4 variants, 3 vehicles, 3 registrations, 3 ownership-history rows, 3 submissions, 3 inspections, 3 reports, 9 checklist items, 1 defect, and 3 valuations.
- One offer, agreement, acquisition, inventory position, movement, listing, image, enquiry, reservation, order, order item, payment, refund, ownership transfer, and delivery.

This is the source's expected fixture, not a claim that the target database currently contains exactly those records. The Day 2 report says SQL Server structural diagnostics showed expected object counts and fixture markers but does not provide the complete row-level output in the repository. Preserve and identify these fixture records by their explicit synthetic codes/references; never replace them.

## Proposed volume plan

The table gives the **adjusted cumulative targets implemented by the Day 3 phases**, including the Day 2 fixture where applicable. The initial proposal was reduced for the catalog/vehicle cohort: reuse the existing 7 models and 4 variants, and generate 67 vehicles with one submission each, giving 70 cumulative vehicles/submissions including the 3 Day 2 rows. Eight completed buyer transfers add ownership history, resulting in 78 rows. These targets remain subject to actual preflight counts. “Added” is target minus the documented Day 2 baseline; where actual counts exceed a target, do not delete data—stop and reconcile.

| Table | Cumulative target | Notes |
|---|---:|---|
| `ref.City` | 8 | Reuse existing city keys; add none unless reviewed and absent. |
| `core.Branch` | 8 | Reuse existing branches. |
| `core.Employee` | 25 | 21 additional synthetic employees. |
| `core.EmployeeRole` | 25 | At least one valid role per planned employee; dates within employment interval. |
| `core.Customer` | 100 | 97 additional synthetic buyer/seller identities. |
| `core.CustomerContact` | 175 | Unique customer/type/value/valid-from combinations. |
| `core.CustomerAddress` | 125 | Six-digit synthetic PINs and valid intervals. |
| `vehicle.VehicleBrand` | 8 | Reuse existing brands. |
| `vehicle.VehicleModel` | 7 | Reuse existing curated catalog; no catalog expansion in this cohort. |
| `vehicle.VehicleVariant` | 4 | Reuse existing variants; nullable variant remains supported. |
| `vehicle.Vehicle` | 70 | 67 additional records; unique synthetic VINs. |
| `vehicle.VehicleRegistration` | 70 | One synthetic registration for each cohort vehicle. |
| `vehicle.VehicleOwnershipHistory` | 78 | 70 initial owner rows plus 8 completed buyer ownership rows. |
| `vehicle.VehicleSubmission` | 70 | Multiple submissions on some vehicles are allowed; deterministic timestamps distinguish them. |
| `inspection.Inspection` | 65 | Includes scheduled, in-progress, completed, cancelled, and no-show cases. |
| `inspection.InspectionReport` | 60 | Only finalized/completed inspections; one report maximum per inspection. |
| `inspection.InspectionItem` | 420 | About seven distinct uppercase checklist codes per report. |
| `inspection.Defect` | 100 | Varied categories/severity; nonnegative INR estimate/currency pairs. |
| `inspection.VehicleValuation` | 55 | Multiple dated snapshots allowed; retain superseded/rejected values. |
| `acquisition.PurchaseOffer` | 50 | Issued, accepted, declined, expired, withdrawn, and draft cases. |
| `acquisition.PurchaseAgreement` | 35 | Unique synthetic reference; signed, void, or cancelled. |
| `acquisition.VehicleAcquisition` | 32 | Only a matched executed agreement/vehicle/seller chain. |
| `inventory.Inventory` | 32 | One per acquired vehicle (unique vehicle key); sold positions retained with status. |
| `inventory.InventoryMovement` | 63 | 31 receipts, 23 transfers, 8 dispatches, and 1 Day 2 movement. |
| `marketplace.VehicleListing` | 35 | Listing history for acquired stock; at most one active per vehicle. |
| `marketplace.ListingImage` | 120 | Three to four synthetic `.invalid` image references per listing on average. |
| `marketplace.CustomerEnquiry` | 100 | Multiple channels and realistic open-to-closed outcomes. |
| `marketplace.VehicleReservation` | 25 | Active, converted, released, and expired; no competing active hold for same vehicle. |
| `sales.SalesOrder` | 18 | Completed, confirmed, draft, and cancelled; avoid orphan/incomplete commercial chains. |
| `sales.SalesOrderItem` | 18 | Exactly one item per order by current policy; match reservation when present. |
| `finance.Payment` | 26 | Attempts include successful, pending, failed, and reversed outcomes; fixed unique provider references. |
| `finance.Refund` | 5 | Mix of pending/failed/successful; successful cumulative total below successful capture. |
| `delivery.OwnershipTransfer` | 12 | Only against valid order items; mix of submitted, in progress, rejected, completed. |
| `delivery.VehicleDelivery` | 12 | Only against non-cancelled order items; mix of scheduled, in transit, completed, failed. |

Keep transaction history in a fixed synthetic window (for example, 2026-02-01 through 2026-10-31 UTC), after the Day 2 fixture's January 2026 events. Do not use runtime-dependent `GETDATE()` or `NEWID()` for reproducible business data. INR amounts should be plausible ranges by model/year/condition; pricing must use `DECIMAL(19,4)` and retain currency `INR` explicitly. No real customer PII should be used. Use reserved `.invalid` email domains and synthetic `+91` phone strings. Registration patterns should resemble Indian RTO formats but use clearly synthetic combinations and be checked for collisions; the schema itself only enforces uppercase and number/date uniqueness.

## Dependency and insertion order

Resolve parent IDs using verified natural/synthetic keys; never embed arbitrary identity values. Insert in this order:

1. Reuse/verify `ref.City`; then `core.Branch`.
2. `core.Employee`, `core.EmployeeRole`, and `core.Customer`; then `core.CustomerContact` and `core.CustomerAddress`.
3. Reuse/verify `vehicle.VehicleBrand`; then `VehicleModel`, `VehicleVariant`, `Vehicle`, `VehicleRegistration`, `VehicleOwnershipHistory`, and `VehicleSubmission`.
4. `inspection.Inspection` → `InspectionReport` → `InspectionItem` → `Defect`; then `VehicleValuation`.
5. `acquisition.PurchaseOffer` → `PurchaseAgreement` → `VehicleAcquisition`.
6. `inventory.Inventory` → append `InventoryMovement` rows.
7. `marketplace.VehicleListing` → `ListingImage` and `CustomerEnquiry`; then `VehicleReservation`.
8. `sales.SalesOrder` → `SalesOrderItem`.
9. `finance.Payment` → `Refund`.
10. `delivery.OwnershipTransfer` and `VehicleDelivery` after valid order items exist.

Keep each dependency phase in a transaction, with `XACT_ABORT ON`, an explicit precondition, inserted/skipped counts, post-phase assertions, and rollback on any conflict. Do not use a single transaction spanning every batch if it would make failure diagnosis or recovery unclear. A phase must stop the remaining workflow when its assertions fail.

## Lifecycle and business scenarios

Construct deterministic cohorts with their own stable synthetic IDs, and vary outcomes rather than pushing every row through a completed sale:

- **Acquired and listed:** seller/customer owns the vehicle; submission and inspection align to the same vehicle; approved report/valuation supports an accepted unexpired offer; signed agreement and acquisition agree on seller, vehicle, currency, and amount; inventory receipt and listing follow acquisition. Use multiple listing history records only after closing earlier ones; never create two `ACTIVE` listings for a vehicle.
- **Rejected intake:** use submission `REJECTED`/`WITHDRAWN` or offer `DECLINED`/`EXPIRED`, and vehicle `REJECTED` only where that flow is appropriate. Retain inspection defects and reasons. Do not create agreement/acquisition/inventory/listing for rejected candidates.
- **Inspection exceptions:** keep some inspections `SCHEDULED`, `IN_PROGRESS`, `CANCELLED`, or `NO_SHOW` without a finalized report; completed inspections receive at most one report. Use `FAIL`/`CONDITIONAL` outcomes and defects for vehicles that do not proceed.
- **Negotiation:** retain multiple valuations and offers over time; use status and decision dates consistent with expiry. No unsupported “counter-offer” status exists, so represent separate offer rows only when the schema and business keys distinguish them.
- **Inventory transfer:** append receipt/transfer/dispatch movements with actual branch endpoints and time-ordered source/destination locations. Movement does not automatically mutate the current inventory row; generation must update only its newly generated row after validating the movement chain, or avoid asserting a derived current position that the schema cannot enforce.
- **Enquiries and holds:** retain enquiries against listing versions, including closed listings; reserve only eligible listing stock. Ensure no two active reservations for one listing and no active holds for the same vehicle across historical listings.
- **Sales and payment:** one order item per order. Include converted reservation cases and allowed no-reservation cases. Keep cancelled/draft/confirmed orders from falsely completing transfer/delivery. Include multiple payment attempts and partial payments, but no payment schedule exists; label them as attempts/installments only in synthetic references and validate the successful aggregate against order price.
- **Refund and fulfillment:** only successful payment amounts can fund successful refunds; sum successful refunds per payment must not exceed captured amount. Completed transfer/delivery require matching order parties/vehicle, non-null evidence/reference, and appropriate event timestamps; schema FK presence alone does not guarantee this.
- **Pending operational stock:** retain vehicles at submitted, under-review, acquired, in-stock, listed, or reserved states as appropriate. Every lifecycle status must be supported by the DDL. Do not invent `UNDER_INSPECTION`, `VALUED`, `OFFERED`, or `DELIVERED` in `Vehicle.lifecycle_status`.

The current DDL does not define an application-level transition trigger or permitted transition graph. Therefore generation scripts must use controlled statements and validate the new rows as a complete cohort before committing.

## Generation strategy

Prefer modular T-SQL data-generation scripts under `database/data_generation/`. This repository's implementation, constraints, seed fixture, and diagnostics are already SQL Server-native; T-SQL can resolve identity keys from the actual database and validate FK/business relationships in the same transaction without external credentials, drivers, or dependencies. A Python PRNG would still need a SQL key-resolution/idempotency layer and would add another runtime dependency. If deterministic variation is needed, use a fixed arithmetic mapping from cohort ordinal (or a fixed-seed generator that emits reviewed T-SQL), never unseeded randomness.

The schema does not provide a universal synthetic batch ID or unique key for every event table. Therefore do not promise blind rerun safety from `NOT EXISTS` alone. Each generated row must have a documented stable natural key/event tuple. Before insert, compare any existing row with that key against the full expected payload: exact match is a “skipped/already present” result; mismatch or ambiguous multiple match is a hard stop. Use serializable transaction/application locks around check-and-insert to prevent concurrent duplicate runs. Tables without an appropriate deterministic business key must be stopped until a safe key strategy is approved; do not add a key column or helper table without a separate schema review. Generation manifest tables would expand the Day 2 model and are not part of this plan.

## Prepared implementation files

The following scripts have now been prepared and statically reviewed against the Day 2 DDL. This does not mean they were executed or that the live database is ready:

1. `database/data_generation/00_pre_generation_checks.sql` — read-only readiness and collision report.
2. `01_generate_customers_and_staff.sql` — staff, roles, customers, contacts, addresses.
3. `02_generate_catalog_and_vehicle_intake.sql` — vehicles, registrations, ownership history, submissions; reuses existing catalog.
4. `03_generate_inspection_and_valuation.sql` — inspections, reports, checklist rows, defects, valuations.
5. `04_generate_acquisition_and_inventory.sql` — offers, agreements, acquisitions, inventory and movement ledger.
6. `05_generate_marketplace_activity.sql` — listings, image references, enquiries, reservations.
7. `06_generate_sales_finance_delivery.sql` — orders/items, payment/refund attempts, transfers, deliveries.
8. `10_validate_generated_data.sql` — read-only final count, state, cross-row and constraint checks.
9. `database/data_generation/README.md` — operator sequence and recovery guidance.

Do not SQLCMD-include files. Review the preflight results, then run one phase at a time in order in SSMS. If a phase fails or a rerun hits a later lifecycle state, stop and review; do not replay upstream phases automatically.
## Data-quality validation strategy

Before generation, capture the diagnostic output and count baseline. After each phase, verify:

- **Reference and uniqueness:** expected synthetic natural keys resolve to exactly one row; no duplicate synthetic keys, VINs, catalog keys, registrations at the same effective start, active listings, or active reservations.
- **FK/integrity:** run orphan anti-joins for every generated relationship plus `DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS`; confirm expected FKs/checks remain enabled and trusted.
- **Ownership/time:** no overlapping ownership intervals; active ownership matches `Vehicle.current_owner_customer_id`; current rows have valid start/end chronology. Since acquisition cannot be represented as company ownership, document this limitation rather than fake an owner row.
- **Inspection/acquisition chain:** report only for completed inspections; unique report per inspection; item and defect belong to the same report; seller and vehicle match through submission, valuation, offer, agreement, and acquisition; agreement status supports acquisition.
- **Inventory/listing:** each inventory row maps to one acquisition; movement endpoints chain from prior location; listing vehicle/branch agree with eligible acquired stock; active listing and reservation uniqueness is checked across all listing versions.
- **Sales/finance:** order has exactly one item; buyer, item vehicle, reservation customer/listing/vehicle all agree when a reservation exists; completed sale is unique per vehicle; currencies agree; successful payment totals reconcile; successful refund totals do not exceed successful captures.
- **Fulfillment:** transfer parties align to seller/buyer and exact order vehicle; completed transfer includes evidence and valid dates; delivery recipient, branch/address, event times, and status agree with the order. The schema lacks a unique constraint for one transfer/delivery per item, so report duplicates explicitly.
- **Volumes and outcomes:** report counts by table, cohort, and status; compare with the proposed target and the pre-generation baseline. Report inserted, exact-match skipped, and conflict counts separately.
- **Database integrity:** use `DBCC CHECKDB` only in a reviewed, appropriate maintenance window because it may be expensive; the Day 2 diagnostic already includes it. No runtime result is claimed here.

Each phase's output should include phase name, status, inserted rows, exact-match skipped rows, conflict count, and validation status. Any conflict is a stop condition, not a row silently ignored by the generator.

## Risks and safeguards

| Risk | Safeguard |
|---|---|
| Actual DB rows differ from seed documentation | Run and review the existing read-only diagnostic first; treat live counts/keys as authoritative. |
| Prior partial generation or accidental rerun | Stable cohort keys, payload conflict checks, phase transactions/application locks, and stop on mismatch/ambiguity. Never blindly replay a phase. |
| Identity values differ across databases | Resolve IDs by verified synthetic natural keys; do not hard-code identity values or reseed. |
| Cross-row business mismatches pass FKs | Add explicit phase assertions for cohort chain consistency and financial aggregates. |
| Model does not store mileage, condition grade, or company ownership | Document limitations; do not pretend descriptive notes are normalized columns or fabricate company customer identity. |
| Fake Indian identity detail looks real | Use wholly synthetic names, `.invalid` emails, reserved synthetic phone patterns and collision-checked registration strings; do not source personal data. |
| Simulated event chronology is inconsistent | Use a fixed UTC clock window; validate all event intervals and status/date combinations before commit. |
| Concurrent/overlapping execution | Serialize each phase with transaction locks/application locks; run one phase at a time from one SSMS session. |
| Day 2 expected object counts change | Add data rows only; no changes to schemas, tables, constraints, or indexes are included in this plan. |

## Day 3 execution checklist

- [ ] Review this plan and confirm the target volumes/cohort key convention.
- [ ] Execute the existing read-only diagnostic in SSMS; retain complete results and errors/messages.
- [ ] Confirm the actual target database, all 10 schemas/34 tables, constraints/indexes, seed markers, trust/disabled states, and data integrity before generating anything.
- [ ] Reconcile the actual baseline to this plan; resolve any partial/unknown prior data generation without deleting data.
- [x] Prepare modular SQL phases with deterministic cohort keys, payload checks, phase transactions, and fail-closed behavior.
- [x] Static-review the generated statements against the DDL and status domains; SQL Server execution remains outstanding.
- [ ] User runs the read-only preflight and reviews its output before deciding whether to authorize generation.
- [ ] After user-controlled generation, run the read-only final validator and review actual output; document results accurately.
- [ ] Update documentation with scripts and measured results only after evidence exists.
- [ ] Do not commit or push unless separately instructed.

## Review status

The source SQL files listed in the Day 3 request and relevant Day 1 business rules/workflows were reviewed statically. Repository HEAD is the Day 2 checkpoint `0a535633eee312f222b93dcdeb1291bf7ecad048`, branch `main`, and the working tree was clean at the start of this task. SQL Server was not accessed. This plan and the prepared scripts have been statically checked against the DDL table names, FKs, supported status/code domains, uniqueness/index rules, and documented fixture. Proposed counts are targets only. No live database state or runtime result has been verified.

## Post-audit remediation status

At the time of this 2026-11-20 update, the revised SQL source had not been executed; this historical status is superseded for preflight and Phases 01-02 by the runtime update at the top of this plan. The source changes described here fail closed on deterministic key collisions, add exact payload/cardinality checks, preserve listing history by transitioning only the eight active sale listings, and add aggregate validator findings against exact cumulative targets. The target matrix remains unchanged; the revised marketplace cohort has 18 active listings before Phase 06 so every completed sale has one eligible active listing.

### Completion remediation update (2026-11-20)

Preflight now enumerates deterministic key namespaces from Phases 01–06 and blocks on any match. The final validator's aggregate includes the mandatory diagnostic categories and exact cumulative targets. Movement arithmetic is one Day 2 receipt + 31 Day 3 receipts + 23 transfers + eight dispatches = 63 cumulative rows. Phase 05 checks coherent per-vehicle prior and resulting states; Phase 06 requires AVAILABLE inventory before each planned sale. Movement validation uses the immediately preceding event ordered by `(occurred_at, movement_id)`, checks expected D3 type counts, duplicate events, unexpected D3 types, and inventory's last known destination. These are source-level checks only. Material prechecks still occur before transaction-owned locks, so concurrency remains an unresolved review item; no controlled preflight or generation is authorized by this document.


