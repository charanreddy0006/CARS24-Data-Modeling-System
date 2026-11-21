# Day 3 Synthetic Generation Execution Report

**Date:** 2026-11-21
**Current outcome:** **PHASES 01-02 COMMITTED / PASS; PHASES 03-06 NOT EXECUTED**

## Verified runtime results

The operator reports successful execution against `CARS24DataModelingSystem`. The pre-generation checks passed before generation. The following row counts and phase statuses are operator-verified runtime results:

| Phase | Status | Records inserted | Exact-match skips | Validation |
|---|---|---:|---:|---|
| 01 - Customers and staff | **COMMITTED** | 21 employees; 21 roles; 97 customers; 172 contacts; 122 addresses | 0 reported | **PASS** |
| 02 - Catalog and vehicle intake | **COMMITTED** | 67 vehicles; 67 registrations; 67 ownership-history rows; 67 submissions | 0 in each of the four categories | **PASS** |
| 03 - Inspection and valuation | **NOT EXECUTED** | - | - | Not available |
| 04 - Acquisition and inventory | **NOT EXECUTED** | - | - | Not available |
| 05 - Marketplace activity | **NOT EXECUTED** | - | - | Not available |
| 06 - Sales, finance, and delivery | **NOT EXECUTED** | - | - | Not available |

The earlier failed Phase 02 attempt was verified to have rolled back completely before the successful rerun. The counts above describe the successful committed Phase 02 execution.

## Evidence boundary

These results are recorded from the operator's reported SQL Server output. This documentation update did not connect to SQL Server or run SQL. No runtime results are claimed for Phases 03-06 or for the independent final validator. The current validator outcome is pending; see `docs/25_day3_final_validation_report.md`.

## Next steps

Continue with Phase 03, then Phases 04-06 in order, reviewing each phase's result sets and stopping on any error or mismatch. Run the independent final validator only after all phases pass. Day 3 remains incomplete until that validator passes.

## Historical attempt

An earlier attempt recorded in this report before the successful normal Windows CMD run was blocked by a connection failure and had no phase execution. That historical result is superseded for Phases 01 and 02 by the verified counts above; it remains applicable only as a record of the earlier attempt.
