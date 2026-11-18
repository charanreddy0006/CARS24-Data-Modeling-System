# Design Decisions

## Independent educational scope

The scenario is an illustrative used-car marketplace. No statement here asserts access to or knowledge of CARS24 internal systems. The model favors lifecycle traceability over claims about any company's actual policy.

## Person and business roles

**Decision:** one Customer entity represents a person who may be seller, buyer, or both. **Alternative:** separate Buyer and Seller tables. **Reason:** separate tables duplicate identity/contact information and complicate transaction history. Role-specific facts stay on their relevant transaction.

## Vehicle identity and catalog

**Decision:** Vehicle is distinct from Brand, Model and optional Variant. Registration number and ownership are effective-dated children. **Alternative:** put all catalog and current registration fields on Vehicle. **Reason:** catalog reuse and changing registration/ownership would cause update anomalies. VIN may be absent at intake, so it is a candidate alternate key rather than mandatory PK.

## Separate submission and enduring vehicle

**Decision:** VehicleSubmission represents an intake attempt. **Alternative:** put submitted/decision state on Vehicle. **Reason:** a vehicle may be submitted more than once, while its stable identity persists across attempts.

## Assessment history

**Decision:** inspections, finalized reports, checklist results, defects and valuation snapshots are separate. **Alternative:** overwrite a single inspection/value on Vehicle. **Reason:** repeat assessments and prior offer rationale must remain auditable. A report is optional until inspection finalization; one final report per inspection is the initial policy.

## Offer, agreement and acquisition

**Decision:** offer, signed agreement, and completed acquisition are distinct records. **Alternative:** one purchase row with a mutable status. **Reason:** issued terms, accepted legal agreement and actual transfer are different milestones with different evidence. Acquisition references its agreement, seller and vehicle.

## Inventory current position plus movement ledger

**Decision:** Inventory represents current location/status, while InventoryMovement is append-only history. **Alternative:** infer current position by scanning movements only. **Reason:** an explicit current position supports operational queries; the movement ledger retains auditability. Changes to both must be atomic and periodically reconcilable.

## Listing and reservation history

**Decision:** each publication/reservation cycle is a row; closed rows remain. **Alternative:** one mutable listing/reservation per vehicle. **Reason:** preserve price/publication and customer hold history. Initial policy permits only one active listing and one active reservation per vehicle; exact active-state indexing/locking is a physical/transaction concern.

## One vehicle per initial sales order

**Decision:** SalesOrderItem exists even though initial policy requires one item per order. **Alternative:** put vehicle/price directly on SalesOrder. **Reason:** explicit order detail cleanly links sale, transfer and delivery and supports later multi-vehicle expansion without redesign. Do not store derived order total while only one item exists.

## Payment and refund structure

**Decision:** Payment records attempts/settlement and Refund records each refund attempt against its payment. **Alternative:** store paid/refunded totals only on order. **Reason:** provider reconciliation and partial/multiple refunds require transaction history. Cumulative refund limit requires transactional aggregate validation, not a row-level check.

## Ownership and delivery

**Decision:** ownership history stores effective intervals, transfer cases record administrative progress, and delivery attempts record physical handover. **Alternative:** a single sold flag/date. **Reason:** title transfer and physical fulfillment can progress independently and may have retries. Current owner on Vehicle is a convenience projection synchronized with effective history.

## Status management and history

**Decision:** current status is stored on active operational records, while significant process history is retained in event/transaction rows. Status transitions are a controlled state machine. SOLD is terminal for ordinary availability; corrections require explicit reversal/return/reacquisition evidence, never SOLD → AVAILABLE. **Alternative:** arbitrary status updates. **Reason:** prevents impossible lifecycle states and supports audit. Database checks alone cannot encode multi-table, concurrency-sensitive rules.

## Reference codes

**Decision:** common catalog references use entities, while small controlled domains (fuel, transmission, statuses, channels, outcomes) use codes in the logical core. **Alternative:** a lookup table for every code. **Reason:** avoid excessive one-column entities at Day 1; promote governed/translated/extensible domains to reference tables in physical design.

## Deferred candidate entities

Customer role tables, separate InspectionReportDetail, and separate fuel/transmission tables are omitted or consolidated as described in the entity catalog. LoanApplication is excluded because lender eligibility/decisioning is out of core scope. Image binaries and identity document contents are external secure assets; only references/metadata are modeled.

## Open policy decisions

Confirm reservation duration, deposit and extension; inspection validity window and pass criteria; offer expiry and acceptance authority; acquisition payment completion; multi-item orders; whether direct consignment is required; registration/VIN validation; ownership transfer evidence; refund accounting policy; personal-data retention and deletion; and technical audit actor coverage. These decisions may alter constraints and code sets but do not invalidate the current lifecycle structure.
