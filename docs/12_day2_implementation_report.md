# Day 2 SQL Server Implementation Report

## Summary

The Day 2 source scripts now implement all 34 finalized Day 1 entities across 10 schemas. The implementation includes named PK/FK/unique/check/default constraints, dependency-ordered table creation, selective indexes, small synthetic relational fixtures, a pre-execution guard, a generated one-file setup script, and comprehensive post-execution diagnostics.

This is an independent educational used-car marketplace model and does not describe CARS24 internal architecture.

## Implementation inventory

- Schemas: `ref`, `core`, `vehicle`, `inspection`, `acquisition`, `inventory`, `marketplace`, `sales`, `finance`, `delivery`.
- Tables: all 34 finalized Day 1 relations; full list and schema mapping are in `13_day2_complete_sql_review_report.md`.
- Expected FK declarations: 62 based on the logical relation attributes. Day 1's ERD/validation report states 59; three relationships are absent from that diagram count (the two InventoryMovement branch endpoints and PurchaseAgreement seller). The implementation follows the explicit logical-model attributes and records this discrepancy for Day 1 diagram correction.
- Indexes: FK/join/history patterns, exact identifier lookup, provider idempotency, and filtered active uniqueness. The initial one-item-per-order policy also has a unique index.
- Seed data: 8 Indian cities/branches, 4 employees/roles, 3 synthetic customer identities/contact/address rows, 8 brands, 7 models, 4 variants, 3 vehicles with registrations, ownership/submission, assessment and a linked sample acquisition/listing/order/payment/refund/transfer/delivery chain.

## Script usage

Run `database/00_pre_execution_checks.sql` in SSMS connected to `chakri\SQLEXPRESS` with `master` selected. If it reports `READY`, execute the generated `database/00_run_complete_database_setup.sql` once. That master is assembled from the canonical numbered source scripts by `database/generate_master_setup.ps1`, includes database creation through final validation, and uses `GO` batches without SQLCMD includes. Run `database/11_post_execution_validation.sql` separately for a repeatable validation pass.

## SQL Server execution status

SSMS showed an authenticated connection to `chakri\SQLEXPRESS`, SQL Server 2025 Express 64-bit, version `17.0.1000.7`, RTM, engine edition `4`, with `master` selected. `01_create_database.sql` was executed successfully in that SSMS session. The target database therefore exists or was already present; its contents and whether it was newly created were not queried afterward.

The remainder of the setup was not executed. The UI automation bridge subsequently detected user input and stopped accepting further app actions. Command-line connection attempts also failed in the agent execution context. Therefore table creation, seed insertion, and runtime validation results are not claimed. Since the database-creation script has run, the target database may now exist; the pre-execution check will stop if it does. Inspect its state and back it up before choosing a recovery path.

## Known limits

- Some initial code lists and policy choices require stakeholder confirmation before production use.
- Temporal overlap, company ownership, lifecycle transitions, active holds across old listing versions, completed-sale uniqueness, cross-entity consistency, and refund aggregate limits require transaction/application logic.
- The Day 1 model's current-owner references and ownership-history rows point only to `Customer`, while the acquisition workflow describes company ownership. This mismatch is documented in the complete review report; changing it requires an approved Day 1 model correction.
- Static review does not replace running the full setup and post-validation in SSMS.
