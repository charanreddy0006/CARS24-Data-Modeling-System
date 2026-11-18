# Day 1 Validation Report

**Review status:** completed by cross-reading the authored requirements, workflows, rules, entity catalog, logical model, diagrams, and dictionary. This is a document-level consistency review, not execution against a SQL Server instance or automated Mermaid parser. Physical database behavior remains unverified because implementation is out of scope.

## Validation checks

| Check | Result | Evidence / resolution |
|---|---|---|
| Requirements have data support | Pass with stated boundary | FR-001–022 map to customer/contact/address, vehicle/submission/assessment, acquisition/inventory, listing/sale/finance, transfer/delivery and audit event relations. Identity verification and external integrations are explicitly out of scope. |
| Entity purpose and candidate decisions | Pass | Candidate evaluations and merge/exclusion rationale are in entity catalog. LoanApplication is explicitly excluded; FuelType/TransmissionType are controlled codes rather than tables. |
| PK coverage | Pass | Each of 34 finalized relations has one surrogate logical PK in model and dictionary. |
| FK validity | Pass after review | Every declared FK points to a finalized relation and attribute; the reservation/order references intentionally support conversion traceability and must be set atomically. |
| Cardinality / optionality | Pass with transaction policies | Conceptual and logical diagrams reflect nullable submission/employee/report/variant relationships and one-to-many histories. Active-only and temporal uniqueness are documented as rules, not diagram cardinalities. |
| Many-to-many handling | Pass | Employee-to-role uses EmployeeRole; orders-to-vehicles use SalesOrderItem; report-to-checklist uses InspectionItem. |
| Duplicate entities | Pass | Customer roles consolidated; report detail represented by InspectionItem; candidates merged/excluded with reasons. |
| Historical data | Pass | Effective-dated registration/ownership plus append-only assessment, movement, listing, reservation, payment, refund, transfer and delivery records. |
| Rule consistency | Pass | BR-001–038 align with status transitions and workflow validations. SOLD cannot transition directly to AVAILABLE. |
| Normalization | Pass for logical design | 1NF atomic values, 2NF examples and 3NF dependencies are explained; no intentional denormalization claimed beyond current-state projection. |
| Mermaid syntax and entity references | Reviewed | All diagram files use `erDiagram` and supported cardinality tokens; logical diagram lists all finalized entities and modeled FK relationships. No Mermaid renderer/parser is configured in this repository, so parser execution is not claimed. |
| Logical ERD vs catalog | Pass | Logical diagram contains each Core row in catalog and no excluded LoanApplication/FuelType/TransmissionType entity. |
| Dictionary vs logical model | Pass by attribute-level cross-check | Dictionary includes every declared attribute for all 34 relations, with logical type, key role, nullable flag and description. |

## Count and domains

- **Finalized entities:** 34.
- **Relationship count:** 59 distinct FK relationships in the logical ERD. Multiple FKs from one entity to the same target (for example transferor/transferee) count separately; conceptual-only business constraints are not counted.
- **Business domains:** customer/organization, vehicle catalog and identity, inspection/valuation, seller acquisition, inventory, marketplace, sales, finance, ownership transfer and delivery.
- **Normalization result:** design targets 3NF; candidate FDs and examples are stated in `07_normalization_analysis.md`.

## Gaps resolved during review

Vehicle submission was added as a transaction separate from the enduring vehicle. A lifecycle ownership-history entity, controlled current position plus movement ledger, listing-image metadata, enquiry, reservation, order item, payment/refund, transfer and delivery trace were retained to cover the requested lifecycle. The order model has a single-vehicle initial business constraint while retaining order details. Customer can be both buyer and seller. Registration identifiers are history records instead of immutable vehicle attributes. These changes close the principal traceability gaps.

## Remaining assumptions and decisions

Confirm one-item orders, one-active-hold/listing policy, hold expiry/deposit, inspection pass and validity standards, offer acceptance rules, acquisition settlement timing, direct consignment support, registration/VIN jurisdiction validation, title evidence, refund policy, personal-data retention, and technical actor/audit coverage. These are business decisions, not unresolved structural contradictions.

## Recommended Day 2 sequence

1. Confirm open policy assumptions with stakeholders and freeze controlled status/code lists.
2. Define SQL Server naming, key-generation, UTC, precision, collation and soft-delete/audit conventions.
3. Implement reference/catalog and customer/organization tables first, then vehicle identity/history.
4. Add inspection/valuation and acquisition/agreement relations and keys.
5. Add inventory, listing, reservation, order and finance relations with concurrency-safe active-row and completed-sale controls.
6. Add ownership transfer/delivery, indexes and permissions.
7. Create schema-level constraints and transactional procedures for cross-row rules; then test with synthetic educational fixtures in the later implementation phase.

No SQL scripts, fake production data, application code, or APIs were created for Day 1.
