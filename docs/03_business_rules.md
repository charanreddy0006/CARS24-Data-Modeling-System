# Business Rules

“DB” means declarative key/check/foreign-key enforcement; “TX” means a transaction/locking requirement; “APP” means workflow or policy validation (often supported by database constraints). SQL implementation is deferred.

| ID | Description | Reason | Related entities | Validation / enforcement |
|---|---|---|---|---|
| BR-001 | A customer may register multiple vehicles over time. | Preserve customer history. | Customer, VehicleSubmission | FK and workflow (DB + APP). |
| BR-002 | A customer can act as both buyer and seller. | One identity across roles. | Customer, VehicleSubmission, SalesOrder | No separate person role rows required (model). |
| BR-003 | A submission must identify submitter and vehicle. | Traceability. | VehicleSubmission, Customer, Vehicle | Required FKs (DB). |
| BR-004 | Vehicle current registered owner must be represented in ownership history. | Ownership evidence. | Vehicle, VehicleOwnershipHistory | Effective-date and current-owner consistency (TX/APP). |
| BR-005 | Vehicle registration number is unique among active registration assignments. | Avoid vehicle identity collision. | VehicleRegistration | Filtered uniqueness/effective-date transaction (DB/TX). |
| BR-006 | Vehicle catalog model belongs to one brand; variant, if used, belongs to one model. | Catalog integrity. | VehicleBrand, VehicleModel, VehicleVariant | FK (DB). |
| BR-007 | A vehicle may have multiple inspection records over time. | Preserve reassessment history. | Vehicle, Inspection | One-to-many FK (DB). |
| BR-008 | Each finalized inspection has one final report. | Clear outcome. | Inspection, InspectionReport | Unique inspection FK and completion validation (DB/APP). |
| BR-009 | Inspection checklist item definitions are unique within the chosen reference scheme. | Repeatable assessment. | InspectionItem, InspectionReport | Unique key and required outcome (DB/APP). |
| BR-010 | Listing requires an approved current inspection and acquired stock. | Do not advertise ineligible vehicle. | InspectionReport, Acquisition, Inventory, Listing | Transactional eligibility check (TX/APP). |
| BR-011 | A vehicle may have multiple valuations; prior values are retained. | Explain offer decisions. | VehicleValuation, Vehicle | Insert a new valuation, never overwrite history (APP). |
| BR-012 | Valuation amount is nonnegative and has currency/date/assessor. | Meaningful financial snapshot. | VehicleValuation, Employee | CK and required attributes (DB). |
| BR-013 | Offers reference a vehicle, seller and valuation basis. | Trace offer rationale. | PurchaseOffer, Customer, Vehicle, VehicleValuation | FKs (DB), eligibility (APP). |
| BR-014 | An offer is actionable only before expiry and while not withdrawn/accepted. | Avoid stale acceptance. | PurchaseOffer | Status/expiry check in transaction (TX/APP). |
| BR-015 | Completed acquisition references seller, vehicle and executed purchase agreement. | Legal/business trace. | VehicleAcquisition, PurchaseAgreement | Required unique relationship and completion check (DB/APP). |
| BR-016 | The seller at acquisition must match the current recorded owner or approved authority evidence. | Valid transfer chain. | VehicleAcquisition, Customer, VehicleOwnershipHistory | Workflow validation (APP). |
| BR-017 | A vehicle cannot have two completed acquisitions representing the same transfer event. | Prevent duplicate intake. | VehicleAcquisition | Unique event key; transactional check (DB/TX). |
| BR-018 | Inventory movements are append-only and preserve from/to, time, actor and reason. | Audit custody. | Inventory, InventoryMovement, Employee | Required fields; corrections by compensating movement (DB/APP). |
| BR-019 | A movement source must equal the vehicle's current inventory location. | Prevent impossible movement. | InventoryMovement | Serialized transaction (TX). |
| BR-020 | A sold vehicle cannot be available or actively listed. | Prevent double sale. | Vehicle, Listing, SalesOrder | Atomic sale transition and uniqueness (TX/DB). |
| BR-021 | Only one active listing per vehicle is permitted in the initial policy. | Prevent duplicate offers. | Listing | Filtered uniqueness/transaction (DB/TX). |
| BR-022 | Enquiry is retained against the listing version and customer even if listing closes. | Preserve interaction history. | CustomerEnquiry, Listing, Customer | FKs; no cascade deletion (DB). |
| BR-023 | At most one active reservation exists per vehicle. | Exclusive hold. | VehicleReservation, Vehicle | Filtered unique constraint or serializable/locked transaction (TX/DB). |
| BR-024 | Reservation expiry must be later than creation; expired/released reservations cannot convert without renewal. | Predictable hold period. | VehicleReservation | CK and transaction status check (DB/TX). |
| BR-025 | A sales order identifies one buyer and at least one vehicle detail; initial scope permits exactly one item. | Explicit commercial commitment. | SalesOrder, SalesOrderItem | Required FK and unique order-item vehicle policy (DB/APP). |
| BR-026 | Completed sale cannot exist for the same vehicle more than once. | No double sale. | SalesOrderItem, SalesOrder | Unique completed-sale transaction control (TX/DB). |
| BR-027 | Order item vehicle must equal the vehicle in its converted reservation, when reservation is used. | Prevent mismatched sale. | Reservation, OrderItem | Transaction validation (TX). |
| BR-028 | Payment references an order and is denominated in the order currency. | Reconciliation. | Payment, SalesOrder | FK and currency validation (DB/APP). |
| BR-029 | Provider transaction identifiers are idempotent within provider scope. | Avoid duplicate capture. | Payment, Refund | Unique key (DB). |
| BR-030 | Successful refunds reference a successful payment and cannot exceed its captured amount cumulatively. | Prevent over-refund. | Refund, Payment | Aggregate transaction control (TX); simple row check insufficient. |
| BR-031 | Ownership transfer references the sold order and exact vehicle. | Link title work to sale. | OwnershipTransfer, SalesOrder, Vehicle | FKs and consistency (DB/APP). |
| BR-032 | Transfer completion requires buyer, effective date and evidence/reference. | Auditable title outcome. | OwnershipTransfer, VehicleOwnershipHistory | Workflow gate (APP). |
| BR-033 | Completed delivery references an order vehicle and records recipient, time and handover result. | Proof of fulfillment. | VehicleDelivery, SalesOrder, Customer | Required fields and consistency (DB/APP). |
| BR-034 | Lifecycle changes must follow the permitted transition graph; SOLD → AVAILABLE is prohibited. | Protect status integrity. | Vehicle, Listing, Reservation, Order | State machine in transaction/application; audit each change (TX/APP). |
| BR-035 | Historical transaction, movement and assessment records are not physically deleted during normal operations. | Explain past state. | All history entities | Retention/access policy and no cascading deletes (DB/APP). |
| BR-036 | Monetary values are nonnegative, use explicit currency, and default business currency is INR. | Consistent financial interpretation. | Valuation, Offer, Acquisition, Order, Payment, Refund | CK/default/reference plus currency match (DB/APP). |
| BR-037 | Employee actions are attributed to an employee where operationally performed. | Accountability. | Employee and transaction entities | FK where actor is known; system actor policy (DB/APP). |
| BR-038 | Effective-dated ownership intervals for one vehicle must not overlap. | Unambiguous owner at any instant. | VehicleOwnershipHistory | Serialized interval validation (TX). |
