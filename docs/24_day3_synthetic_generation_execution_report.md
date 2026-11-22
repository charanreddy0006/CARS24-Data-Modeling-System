# Day 3 Synthetic Generation Execution Report

**Date:** 2026-11-22
**Current outcome:** **PHASES 01-03 COMMITTED / PASS; PHASES 04-06 NOT EXECUTED**

## Verified runtime results

The operator reports successful execution against `CARS24DataModelingSystem`. Pre-generation checks passed before generation. The following phase outcomes and component row counts are operator-verified runtime results:

| Phase | Status | Records inserted | Exact-match skips | Validation |
|---|---|---:|---:|---|
| 01 - Customers and staff | **COMMITTED** | 21 employees; 21 roles; 97 customers; 172 contacts; 122 addresses | 0 reported | **PASS** |
| 02 - Catalog and vehicle intake | **COMMITTED** | 67 vehicles; 67 registrations; 67 ownership-history rows; 67 submissions | 0 in each of the four categories | **PASS** |
| 03 - Inspection and valuation | **COMMITTED** | 62 inspections; 57 reports; 411 checklist items; 99 defects; 52 valuations | 0 in all five categories | **PASS** |
| 04 - Acquisition and inventory | **NOT EXECUTED** | - | - | Not available |
| 05 - Marketplace activity | **NOT EXECUTED** | - | - | Not available |
| 06 - Sales, finance, and delivery | **NOT EXECUTED** | - | - | Not available |

The earlier failed Phase 02 attempt was verified to have rolled back completely before its successful rerun.

## Phase 03 independent verification and execution history

The operator's read-only count query independently returned 62 inspections, 57 reports, 411 checklist items, 99 defects, and 52 valuations. The independent relationship checks each returned `failure_count = 0` for inspection/submission/vehicle, defect/report/item, and valuation/report/vehicle relationships.

The initial Phase 03 execution failed with a T-SQL syntax error near `THROW` in the completed-inspection report predicate. The cause was a missing closing parenthesis. It was corrected, and read-only counts after the failed attempt showed zero rows in all five Phase 03 target families. The subsequent execution committed with `PASS` and zero exact-match skips.

The five Phase 03 component counts sum to **681** (62 + 57 + 411 + 99 + 52). The script's result set exposes separate `*_inserted` and `*_exact_match_skipped` columns for these five families; it does not emit an aggregate inserted-total column. The earlier “all inserted” figure of 721 was an erroneous aggregate in the supplied execution summary and is superseded by the verified family counts and their 681 sum.

## Evidence boundary and next steps

These results are recorded from operator-reported SQL Server output. This documentation update did not connect to SQL Server or execute SQL. Phase 01-03 runtime results do not establish final Day 3 validation. Phases 04-06 remain unexecuted, and the independent final validator remains unexecuted. Continue with Phase 04 through Phase 06 sequentially, then run the independent validator and require aggregate `PASS` before declaring Day 3 complete.
