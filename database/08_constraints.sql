USE [CARS24DataModelingSystem];
GO

/* Row checks and key constraints are declared alongside table definitions.
   Cross-row/temporal rules below intentionally remain transactional or
   application validations; a simple CHECK constraint cannot enforce them. */
/* Transactional/application rules (not reducible to row CHECK constraints):
   - Ownership intervals for a vehicle cannot overlap; current_owner_customer_id
     must match the active history row.
   - A registration number may have only one simultaneous active assignment.
   - Submission seller must match owner/authority; inspection submission must
     refer to the same vehicle; report/defect item must belong to that report.
   - Offer, valuation, submission, seller, agreement, acquisition, and vehicle
     must agree across their relationship chain.
   - Acquisition and current owner projection need an organization/ownership
     policy; Day 1 currently models current owners as Customer only.
   - Listing publication eligibility, one active hold per vehicle across all
     listing rows, matching order/buyer/reservation/item/vehicle, currency
     consistency, and completed-sale uniqueness require serialized workflow.
   - Cumulative successful refunds cannot exceed the captured successful
     payment; this needs transaction locking/aggregate validation.
   - Ownership transfer and delivery recipient/vehicle must match the order.
   Variant-to-model consistency is enforced by the composite FK in
   06_vehicle_identity.sql. One-item-per-order and one active listing/hold per
   listing have supporting unique indexes in 09_indexes.sql. */
