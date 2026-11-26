# Day 3 Synthetic Generation Execution Report

**Original report date:** 2026-11-22
**Current outcome (operator-reported 2026-11-26):** **ALL SIX PHASES COMMITTED / PASS**

## Verified runtime results

The operator reports successful execution against `CARS24DataModelingSystem`. Pre-generation checks passed before generation. The following phase outcomes and component row counts are operator-verified runtime results:

| Phase | Status | Records inserted | Exact-match skips | Validation |
|---|---|---:|---:|---|
| 01 - Customers and staff | **COMMITTED** | 21 employees; 21 roles; 97 customers; 172 contacts; 122 addresses | 0 reported | **PASS** |
| 02 - Catalog and vehicle intake | **COMMITTED** | 67 vehicles; 67 registrations; 67 ownership-history rows; 67 submissions | 0 in each of the four categories | **PASS** |
| 03 - Inspection and valuation | **COMMITTED** | 62 inspections; 57 reports; 411 checklist items; 99 defects; 52 valuations | 0 in all five categories | **PASS** |
| 04 - Acquisition and inventory | **COMMITTED** | 49 offers; 34 agreements; 31 acquisitions; 31 inventory positions; 54 movement rows; total 199 | 0 in all five families | **PASS** |
| 05 - Marketplace activity | **COMMITTED** | 34 listings; 119 images; 99 enquiries; 24 reservations (276 total) | 0 reported | **PASS** |
| 06 - Sales, finance, and delivery | **COMMITTED** | 18 orders; 18 items; 26 payments; 5 refunds; 12 transfers; 12 deliveries; 8 sale-history rows; 8 dispatch movements (107 total) | 0 reported | **PASS** |

The earlier failed Phase 02 attempt was verified to have rolled back completely before its successful rerun.

## Phase 03 independent verification and execution history

The operator's read-only count query independently returned 62 inspections, 57 reports, 411 checklist items, 99 defects, and 52 valuations. The independent relationship checks each returned `failure_count = 0` for inspection/submission/vehicle, defect/report/item, and valuation/report/vehicle relationships.

The initial Phase 03 execution failed with a T-SQL syntax error near `THROW` in the completed-inspection report predicate. The cause was a missing closing parenthesis. It was corrected, and read-only counts after the failed attempt showed zero rows in all five Phase 03 target families. The subsequent execution committed with `PASS` and zero exact-match skips.

The five Phase 03 component counts sum to **681** (62 + 57 + 411 + 99 + 52). The script's result set exposes separate `*_inserted` and `*_exact_match_skipped` columns for these five families; it does not emit an aggregate inserted-total column. The earlier "all inserted" figure of 721 was an erroneous aggregate in the supplied execution summary and is superseded by the verified family counts and their 681 sum.

## Phase 04 independent verification

The operator reports that `database/data_generation/11_verify_phase04_readonly.sql` executed successfully. All 12 checks returned `PASS` with `failure_count = 0`:

- `acquisitions_count`
- `acquisitions_payload_and_relationships`
- `agreements_count`
- `agreements_payload_and_offer_seller_relationships`
- `inventory_payload_and_acquisition_relationships`
- `inventory_positions_count`
- `offers_count`
- `offers_payload_and_relationships`
- `phase04_receipt_transfer_movement_count`
- `phase04_vehicle_submission_lifecycle`
- `receipt_transfer_payload_inventory_employee_relationships`
- `source_vehicle_submission_valuation_keys`

The verification script is SELECT-only.

Phase 04 inserted counts sum to **199** (49 + 34 + 31 + 31 + 54), with zero exact-match skips in all five families.

## Phase 05 and Phase 06 independent verification

The operator reports that the read-only Phase 05 verifier `database/data_generation/12_verify_phase05_readonly.sql` returned **28/28 PASS**. The Phase 06 verifier `database/data_generation/13_verify_phase06_readonly.sql` returned **36/36 PASS**. These independent checks are separate from the generators' own `COMMITTED / PASS` outputs.

Phase 05 family counts sum to **276**. Phase 06's eight listed record-family counts sum to **107**. The Phase 06 transfer-completion time is order creation plus three days; completed listing/order time is order creation plus five days. Ownership-history transition and dispatch use the transfer-completion timestamp.

## Final cumulative validation update (2026-11-26)

The operator subsequently reports a successful manual execution of `10_validate_generated_data.sql`: `final_validation_status = PASS`, `failed_check_count = 0`, and `total_detected_failure_count = 0`. The target database was ONLINE at compatibility level 170, and DBCC CHECKCONSTRAINTS completed without reported violation rows. All reported cumulative counts matched the final targets, including the Day 2 seed rows in orders, order items, payments, refunds, transfers, and deliveries. Details are recorded in `docs/25_day3_final_validation_report.md` and `docs/26_day3_completion_report.md`.

## Evidence boundary and next steps

All runtime outcomes in this report are operator-reported SQL Server evidence. This documentation update did not connect to SQL Server or execute SQL. The historical Phase 01-04-only snapshot above is superseded by the later Phase 05/06 and final-validator results now recorded. Day 3 completion is based on those supplied runtime results; the report does not claim that Codex executed SQL or independently observed the database.
