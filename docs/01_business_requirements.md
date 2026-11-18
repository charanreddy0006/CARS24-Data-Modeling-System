# Business Requirements

**Project:** Independent used-car marketplace data model (educational)  
**Phase:** Day 1 — business analysis and logical design  
**Version:** 1.0

## Executive summary

This project defines a normalized SQL Server-targeted OLTP data model for an illustrative Indian used-car marketplace. It records customer participation as seller and buyer, vehicle submission and assessment, acquisition, inventory custody, listings, enquiries, reservations, orders, financial transactions, title transfer, and delivery. This is an independent educational design; it does not describe or claim access to CARS24 internal systems.

## Background and problem

The scenario spans multiple cities and branches, with vehicles moving through different operational teams and statuses. Without shared identifiers and traceable events, teams cannot reliably establish who submitted or owns a vehicle, whether it passed inspection, where it is held, whether it is available to reserve, or whether payment, transfer, and delivery are complete. The model provides a consistent source of transactional facts and history.

## Objectives

- Represent a vehicle's business lifecycle and customer transaction history.
- Preserve inspection, valuation, offer, ownership, inventory, listing, payment, and delivery history.
- Prevent conflicting active reservations and double sale through transactional controls.
- Separate reference, master, transaction, and historical data and target 3NF.
- Provide a reviewable conceptual and logical model before physical SQL implementation.

## Scope

Customer registration and contact/address records; organization city/branch/employee data; vehicle catalog and identity; submission, inspection, valuation, offers, acquisition and agreement; inventory location and movements; listing, enquiry, reservation, order; payments/refunds; ownership transfer; delivery; auditable status and transaction history.

## Out of scope

SQL scripts, production/sample data, APIs, UI, payment gateway integration, lender underwriting, insurance, servicing, taxation/accounting ledger, document/image binary storage, external RTO integration, analytics warehouse, and CARS24-specific operating procedures. LoanApplication remains a candidate extension and is excluded from the finalized core model.

## Stakeholders and data use

| Stakeholder | Work and data interacted with |
|---|---|
| Seller | Registers/maintains customer details; submits vehicle and evidence; reviews offer and acquisition agreement. |
| Buyer | Maintains customer details; enquires, reserves, orders, pays, receives transfer and delivery. |
| Customer Support | Maintains customer contact/address, submission and enquiry follow-up, and customer-visible status. |
| Vehicle Inspector | Schedules/records inspection, checklist observations, and report outcome. |
| Valuation Team | Records dated vehicle valuation and offer decisions. |
| Inventory Manager | Assigns inventory location and records auditable movements and availability. |
| Sales Executive | Publishes listing, handles enquiries/reservations and creates sales orders. |
| Finance Team | Reconciles order payments and refunds. |
| Branch Manager | Oversees branch staff, inventory and local workflow exceptions. |
| Delivery Team | Plans delivery and records handover outcome. |
| System Administrator | Manages access/configuration and reference data; privileged changes are auditable. |

## User roles

Business roles above are permissions/personas, not duplicate customer records. Employee access is assigned through EmployeeRole; a customer can participate as buyer and seller without separate person identities. System authorization details are a later implementation concern.

## Business lifecycle

Customer registers → seller submits vehicle → inspection and valuation can repeat → purchase offer is issued/accepted/declined/expired → acquisition and purchase agreement record transfer into company ownership → inventory custody and movements are recorded → inspection-cleared vehicle may be listed → buyer enquiry → time-bounded reservation → sales order and payment/refund activity → ownership transfer → delivery and closure. A vehicle can be withdrawn, rejected, or reacquired only through explicit events; a sold vehicle cannot return to available inventory through a direct status edit.

## Functional requirements

| ID | Requirement |
|---|---|
| FR-001 | The system shall assign each customer a stable identifier and permit multiple contact methods and addresses with effective dates. |
| FR-002 | A customer shall be able to act as seller, buyer, or both without duplicate customer identity. |
| FR-003 | The system shall maintain cities, branches, employees, employee roles, and branch assignment history as required by operations. |
| FR-004 | Each vehicle shall have a stable identifier and link to a catalog model/variant and its current registered-owner customer. |
| FR-005 | The system shall retain vehicle registration identifiers and dated ownership history; a registration identifier shall not identify two simultaneously current vehicles. |
| FR-006 | The system shall record seller vehicle submissions and their lifecycle outcome. |
| FR-007 | The system shall schedule and retain multiple inspections, reports, checklist items and defect observations per vehicle. |
| FR-008 | The system shall retain dated valuation records and their assessor, currency and basis. |
| FR-009 | The system shall retain purchase offer history, expiry, decision, and seller response. |
| FR-010 | Completed acquisition shall link one seller, vehicle and purchase agreement and define acquisition price and date. |
| FR-011 | The system shall record inventory placement and append-only movements between branches/locations with reason and timestamp. |
| FR-012 | A listing shall be publishable only for eligible company inventory and retain listing publication/withdrawal history. |
| FR-013 | The system shall retain enquiries against listing and interested customer, with channel and status. |
| FR-014 | The system shall permit at most one active reservation per vehicle; reservation expiry/release shall restore eligibility only after transactional validation. |
| FR-015 | Each sales order shall identify buyer and a single vehicle for the initial scope, with price, currency, and status. |
| FR-016 | The system shall retain payment attempts/transactions associated with an order and distinguish successful, failed, pending and reversed outcomes. |
| FR-017 | Refund records shall reference the payment being refunded and prevent cumulative successful refunds above the captured amount. |
| FR-018 | Ownership transfer shall record the order, parties, dates, status, and registration/title reference. |
| FR-019 | Delivery shall record order, schedule, recipient, location, and handover outcome. |
| FR-020 | The system shall preserve customer transaction history through relationships to submissions, acquisitions, enquiries, orders, payments, transfers and deliveries. |
| FR-021 | Status changes and inventory movements shall retain actor, time, prior/new state, and reason where operationally applicable. |
| FR-022 | Monetary amounts shall carry ISO currency code; INR shall be the business default. |

## Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-001 | The OLTP model shall use relational keys and target 3NF; every finalized table has a declared key. |
| NFR-002 | Transactional operations that reserve, sell, or refund a vehicle shall be safe under concurrent requests. |
| NFR-003 | Personal and identity data access shall follow least privilege and applicable privacy/security requirements at implementation time. |
| NFR-004 | Operational history needed to reconstruct vehicle and financial lifecycle shall be retained and auditable. |
| NFR-005 | Timestamps shall have a documented timezone convention; store instants in UTC and render in local time. |
| NFR-006 | The model shall support multiple Indian cities, branches, teams, and vehicle records without city-specific schema changes. |
| NFR-007 | The model and Mermaid files shall remain readable, version controlled, and traceable to requirements and rules. |
| NFR-008 | No actual customer personal information shall be used in examples or test fixtures. |

## Business capabilities

Customer and workforce management; catalog and vehicle identity; appraisal and seller acquisition; inventory custody; marketplace publication and engagement; reservation and order management; payment/refund reconciliation; ownership transfer; fulfillment and audit.

## Assumptions

1. This is an illustrative independent marketplace design, not confirmed CARS24 policy or architecture.
2. The company acquires a vehicle before listing it in this core scenario. Consignment/direct marketplace sales would require a separate ownership/acquisition policy.
3. An order covers exactly one vehicle in the initial scope; SalesOrderItem is retained as an explicit associative/detail entity to allow future expansion, with one item per order enforced initially.
4. Registration identifiers are normalized as issued and effective dates retained; reassignment/format validation depends on jurisdictional rules.
5. INR is the default currency, but amounts include a currency code for future flexibility.
6. Inspection and valuation can repeat; eligibility uses a defined current approved result, not simply the existence of any historical pass.
7. One active reservation per vehicle is the selected initial policy; duration, deposit and extension policy are configurable business decisions.
8. City/state reference values are maintained by the business; postal and state validation rules require operational confirmation.
9. Identity documents and listing images are references/metadata only; secure binary storage is outside scope.

## Constraints, risks and dependencies

The model is constrained to a 3NF relational OLTP design and excludes executable SQL. Privacy obligations, retention periods, role-based permissions, payment reconciliation rules, reservation deposits/expiry, title-transfer evidence, vehicle inspection standards, and jurisdictional registration validation require business/legal confirmation before production use. Concurrent reservation/sale correctness requires transaction isolation or equivalent application/database locking beyond declarative constraints. External payment, RTO and delivery providers are dependencies of a later implementation.

## Success criteria

- Each lifecycle stage has a defined entity and auditable linkage.
- Seller/customer, vehicle, acquisition, inventory, listing, reservation, order, payment, transfer and delivery can be traced end to end.
- No documented transition permits SOLD → AVAILABLE; conflicting active reservations and duplicate completed sales have explicit transactional controls.
- Every finalized entity has key, purpose, relationships and dictionary coverage.
- Rules, logical model and Mermaid diagrams agree; unresolved policy choices are recorded.
