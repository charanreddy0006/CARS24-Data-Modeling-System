/*
  Independent, read-only Phase 04 verification.
  Run with CARS24DataModelingSystem as the current database.
  Intended for the immediate post-Phase 04 state, before later lifecycle phases.
*/
;WITH
N(n) AS
(
    SELECT CONVERT(int, 1)
    UNION ALL
    SELECT n + 1
    FROM N
    WHERE n < 67
),
BranchMap(slot_no, branch_code) AS
(
    SELECT x.slot_no, x.branch_code
    FROM
    (
        VALUES
            (0, CONVERT(varchar(30), 'HYD-CEN')),
            (1, CONVERT(varchar(30), 'MUM-WST')),
            (2, CONVERT(varchar(30), 'BLR-SOU')),
            (3, CONVERT(varchar(30), 'PUN-CEN')),
            (4, CONVERT(varchar(30), 'DEL-SOU')),
            (5, CONVERT(varchar(30), 'CHE-CEN')),
            (6, CONVERT(varchar(30), 'AMD-CEN')),
            (7, CONVERT(varchar(30), 'RJK-CEN'))
    ) AS x(slot_no, branch_code)
),
SourceRows AS
(
    SELECT
        n.n,
        CONCAT('D3SYN', RIGHT(CONCAT('000000000000', n.n), 12)) AS vin,
        DATEADD(day, n.n, CONVERT(datetime2(0), '2026-02-01T09:00:00')) AS expected_created_at,
        DATEADD(hour, 1, DATEADD(day, n.n, CONVERT(datetime2(0), '2026-02-01T09:00:00'))) AS expected_submitted_at,
        DATEADD(hour, 9, DATEADD(day, 4 + n.n, CONVERT(datetime2(0), '2026-02-01T00:00:00'))) AS expected_valued_at,
        DATEADD(hour, 14, DATEADD(day, 6 + n.n, CONVERT(datetime2(0), '2026-02-01T00:00:00'))) AS expected_acquired_at,
        v.vehicle_id,
        v.created_at AS actual_vehicle_created_at,
        v.lifecycle_status AS actual_vehicle_lifecycle_status,
        s.submission_id,
        s.seller_customer_id,
        s.status AS actual_submission_status,
        s.closed_at AS actual_submission_closed_at,
        val.valuation_id,
        initial_branch.branch_id AS initial_branch_id,
        final_branch.branch_id AS final_branch_id
    FROM N AS n
    LEFT JOIN vehicle.Vehicle AS v
        ON v.vin = CONCAT('D3SYN', RIGHT(CONCAT('000000000000', n.n), 12))
    LEFT JOIN vehicle.VehicleSubmission AS s
        ON s.vehicle_id = v.vehicle_id
       AND s.submitted_at =
           DATEADD(hour, 1, DATEADD(day, n.n, CONVERT(datetime2(0), '2026-02-01T09:00:00')))
    LEFT JOIN inspection.VehicleValuation AS val
        ON val.vehicle_id = v.vehicle_id
       AND val.valued_at =
           DATEADD(hour, 9, DATEADD(day, 4 + n.n, CONVERT(datetime2(0), '2026-02-01T00:00:00')))
    LEFT JOIN BranchMap AS initial_map
        ON initial_map.slot_no = (n.n - 1) % 8
    LEFT JOIN core.Branch AS initial_branch
        ON initial_branch.branch_code = initial_map.branch_code
    LEFT JOIN BranchMap AS final_map
        ON final_map.slot_no = (n.n + 1) % 8
    LEFT JOIN core.Branch AS final_branch
        ON final_branch.branch_code = final_map.branch_code
),
SourceCheck AS
(
    SELECT
        s.n,
        COUNT(DISTINCT s.vehicle_id) AS vehicle_keys,
        COUNT(DISTINCT s.submission_id) AS submission_keys,
        COUNT(DISTINCT s.valuation_id) AS valuation_keys,
        MAX(CASE
                WHEN s.vehicle_id IS NOT NULL
                 AND s.actual_vehicle_created_at = s.expected_created_at
                THEN 1 ELSE 0
            END) AS vehicle_created_at_matches
    FROM SourceRows AS s
    WHERE s.n <= 49
    GROUP BY s.n
),
OfferBase AS
(
    SELECT
        s.*,
        DATEADD(hour, 12,
            DATEADD(day, 1,
                DATEADD(day, 3 + s.n, CONVERT(datetime2(0), '2026-02-01T00:00:00'))
            )
        ) AS expected_offered_at,
        DATEADD(day, 7,
            DATEADD(hour, 12,
                DATEADD(day, 1,
                    DATEADD(day, 3 + s.n, CONVERT(datetime2(0), '2026-02-01T00:00:00'))
                )
            )
        ) AS expected_expires_at,
        CONVERT(decimal(19,4), (500000 + (s.n % 20) * 25000) * 0.88) AS expected_offer_amount,
        CASE
            WHEN s.n <= 34 THEN 'ACCEPTED'
            WHEN s.n <= 40 THEN 'DECLINED'
            WHEN s.n <= 45 THEN 'EXPIRED'
            ELSE 'ISSUED'
        END AS expected_offer_status
    FROM SourceRows AS s
    WHERE s.n <= 49
),
OfferExpected AS
(
    SELECT
        o.*,
        CASE
            WHEN o.n <= 34 THEN DATEADD(hour, 3, o.expected_offered_at)
            WHEN o.n <= 40 THEN DATEADD(hour, 2, o.expected_offered_at)
            WHEN o.n <= 45 THEN DATEADD(hour, 1, o.expected_expires_at)
            ELSE NULL
        END AS expected_decision_at
    FROM OfferBase AS o
),
OfferCheck AS
(
    SELECT
        e.n,
        COUNT_BIG(o.offer_id) AS matching_rows,
        SUM(CONVERT(bigint, CASE
            WHEN o.offer_id IS NULL
              OR e.vehicle_id IS NULL
              OR e.submission_id IS NULL
              OR e.valuation_id IS NULL
              OR e.seller_customer_id IS NULL
              OR o.submission_id IS NULL
              OR o.submission_id <> e.submission_id
              OR o.valuation_id IS NULL
              OR o.valuation_id <> e.valuation_id
              OR o.seller_customer_id IS NULL
              OR o.seller_customer_id <> e.seller_customer_id
              OR o.amount <> e.expected_offer_amount
              OR o.currency_code <> 'INR'
              OR o.expires_at <> e.expected_expires_at
              OR o.status <> e.expected_offer_status
              OR (o.decision_at IS NULL AND e.expected_decision_at IS NOT NULL)
              OR (o.decision_at IS NOT NULL AND e.expected_decision_at IS NULL)
              OR (o.decision_at IS NOT NULL AND e.expected_decision_at IS NOT NULL
                  AND o.decision_at <> e.expected_decision_at)
            THEN 1 ELSE 0
        END)) AS bad_payload_rows
    FROM OfferExpected AS e
    LEFT JOIN acquisition.PurchaseOffer AS o
        ON o.submission_id = e.submission_id
       AND o.offered_at = e.expected_offered_at
    GROUP BY e.n
),
AgreementExpected AS
(
    SELECT
        o.*,
        CONCAT('D3-AGR-', RIGHT(CONCAT('0000', o.n), 4)) AS expected_agreement_reference,
        DATEADD(day, 2, o.expected_offered_at) AS expected_signed_at,
        CASE
            WHEN o.n <= 31 THEN 'SIGNED'
            WHEN o.n = 32 THEN 'VOID'
            ELSE 'CANCELLED'
        END AS expected_agreement_status
    FROM OfferExpected AS o
    WHERE o.n <= 34
),
AgreementCheck AS
(
    SELECT
        e.n,
        COUNT_BIG(a.agreement_id) AS matching_rows,
        SUM(CONVERT(bigint, CASE
            WHEN a.agreement_id IS NULL
              OR o.offer_id IS NULL
              OR a.offer_id IS NULL
              OR a.offer_id <> o.offer_id
              OR a.seller_customer_id IS NULL
              OR a.seller_customer_id <> e.seller_customer_id
              OR a.agreement_reference <> e.expected_agreement_reference
              OR a.signed_at <> e.expected_signed_at
              OR a.status <> e.expected_agreement_status
            THEN 1 ELSE 0
        END)) AS bad_payload_rows
    FROM AgreementExpected AS e
    LEFT JOIN acquisition.PurchaseOffer AS o
        ON o.submission_id = e.submission_id
       AND o.offered_at = e.expected_offered_at
    LEFT JOIN acquisition.PurchaseAgreement AS a
        ON a.agreement_reference = e.expected_agreement_reference
    GROUP BY e.n
),
AcquisitionExpected AS
(
    SELECT
        e.*,
        CONCAT('D3-AGR-', RIGHT(CONCAT('0000', e.n), 4)) AS expected_agreement_reference
    FROM OfferExpected AS e
    WHERE e.n <= 31
),
AcquisitionCheck AS
(
    SELECT
        e.n,
        COUNT_BIG(ac.acquisition_id) AS matching_rows,
        SUM(CONVERT(bigint, CASE
            WHEN ac.acquisition_id IS NULL
              OR ag.agreement_id IS NULL
              OR e.vehicle_id IS NULL
              OR e.seller_customer_id IS NULL
              OR ac.agreement_id IS NULL
              OR ac.agreement_id <> ag.agreement_id
              OR ac.vehicle_id IS NULL
              OR ac.vehicle_id <> e.vehicle_id
              OR ac.seller_customer_id IS NULL
              OR ac.seller_customer_id <> e.seller_customer_id
              OR ac.acquired_at <> e.expected_acquired_at
              OR ac.amount <> e.expected_offer_amount
              OR ac.currency_code <> 'INR'
            THEN 1 ELSE 0
        END)) AS bad_payload_rows
    FROM AcquisitionExpected AS e
    LEFT JOIN acquisition.PurchaseAgreement AS ag
        ON ag.agreement_reference = e.expected_agreement_reference
    LEFT JOIN acquisition.VehicleAcquisition AS ac
        ON ac.agreement_id = ag.agreement_id
    GROUP BY e.n
),
InventoryExpected AS
(
    SELECT
        e.*,
        DATEADD(minute, 10, e.expected_acquired_at) AS expected_inventory_since_at,
        CASE WHEN e.n <= 23 THEN e.final_branch_id ELSE e.initial_branch_id END AS expected_inventory_branch_id,
        CASE WHEN e.n <= 23 THEN 'D3-YARD-B' ELSE 'D3-YARD-A' END AS expected_inventory_location
    FROM AcquisitionExpected AS e
),
InventoryCheck AS
(
    SELECT
        e.n,
        COUNT_BIG(i.inventory_id) AS matching_rows,
        SUM(CONVERT(bigint, CASE
            WHEN i.inventory_id IS NULL
              OR ag.agreement_id IS NULL
              OR ac.acquisition_id IS NULL
              OR e.vehicle_id IS NULL
              OR i.vehicle_id IS NULL
              OR i.vehicle_id <> e.vehicle_id
              OR e.expected_inventory_branch_id IS NULL
              OR i.branch_id IS NULL
              OR i.branch_id <> e.expected_inventory_branch_id
              OR i.location_code <> e.expected_inventory_location
              OR i.status <> 'AVAILABLE'
              OR i.since_at <> e.expected_inventory_since_at
            THEN 1 ELSE 0
        END)) AS bad_payload_rows
    FROM InventoryExpected AS e
    LEFT JOIN acquisition.PurchaseAgreement AS ag
        ON ag.agreement_reference = e.expected_agreement_reference
    LEFT JOIN acquisition.VehicleAcquisition AS ac
        ON ac.agreement_id = ag.agreement_id
    LEFT JOIN inventory.Inventory AS i
        ON i.vehicle_id = e.vehicle_id
    GROUP BY e.n
),
MovementExpected AS
(
    SELECT
        e.n,
        e.vehicle_id,
        i.inventory_id,
        'RECEIPT' AS expected_movement_type,
        CAST(NULL AS int) AS expected_from_branch_id,
        CAST(NULL AS varchar(30)) AS expected_from_location_code,
        e.initial_branch_id AS expected_to_branch_id,
        CAST('D3-YARD-A' AS varchar(30)) AS expected_to_location_code,
        emp.employee_id AS expected_employee_id,
        e.expected_inventory_since_at AS expected_occurred_at,
        CAST(N'Day 3 synthetic acquisition receipt' AS nvarchar(500)) AS expected_reason
    FROM InventoryExpected AS e
    LEFT JOIN inventory.Inventory AS i
        ON i.vehicle_id = e.vehicle_id
    LEFT JOIN core.Employee AS emp
        ON emp.employee_code = 'D3-EMP-0011'

    UNION ALL

    SELECT
        e.n,
        e.vehicle_id,
        i.inventory_id,
        'TRANSFER',
        e.initial_branch_id,
        CAST('D3-YARD-A' AS varchar(30)),
        e.final_branch_id,
        CAST('D3-YARD-B' AS varchar(30)),
        emp.employee_id,
        DATEADD(day, 2, e.expected_inventory_since_at),
        CAST(N'Day 3 synthetic inter-branch transfer' AS nvarchar(500))
    FROM InventoryExpected AS e
    LEFT JOIN inventory.Inventory AS i
        ON i.vehicle_id = e.vehicle_id
    LEFT JOIN core.Employee AS emp
        ON emp.employee_code = 'D3-EMP-0011'
    WHERE e.n <= 23
),
MovementCheck AS
(
    SELECT
        e.n,
        e.expected_movement_type,
        COUNT_BIG(m.movement_id) AS matching_rows,
        SUM(CONVERT(bigint, CASE
            WHEN m.movement_id IS NULL
              OR e.inventory_id IS NULL
              OR e.expected_employee_id IS NULL
              OR m.employee_id IS NULL
              OR m.employee_id <> e.expected_employee_id
              OR m.movement_type <> e.expected_movement_type
              OR m.occurred_at <> e.expected_occurred_at
              OR m.reason <> e.expected_reason
              OR e.expected_to_branch_id IS NULL
              OR m.to_branch_id IS NULL
              OR m.to_branch_id <> e.expected_to_branch_id
              OR m.to_location_code IS NULL
              OR m.to_location_code <> e.expected_to_location_code
              OR (e.expected_movement_type = 'RECEIPT'
                  AND (m.from_branch_id IS NOT NULL OR m.from_location_code IS NOT NULL))
              OR (e.expected_movement_type = 'TRANSFER'
                  AND (e.expected_from_branch_id IS NULL
                       OR m.from_branch_id IS NULL
                       OR m.from_branch_id <> e.expected_from_branch_id
                       OR m.from_location_code IS NULL
                       OR m.from_location_code <> e.expected_from_location_code))
            THEN 1 ELSE 0
        END)) AS bad_payload_rows
    FROM MovementExpected AS e
    LEFT JOIN inventory.InventoryMovement AS m
        ON m.inventory_id = e.inventory_id
       AND m.occurred_at =
           CASE WHEN e.expected_movement_type = 'RECEIPT'
                THEN e.expected_occurred_at
                ELSE e.expected_occurred_at
           END
    GROUP BY e.n, e.expected_movement_type
),
LifecycleCheck AS
(
    SELECT
        s.n,
        COUNT_BIG(s.vehicle_id) AS vehicle_rows,
        COUNT_BIG(s.submission_id) AS submission_rows,
        SUM(CONVERT(bigint, CASE
            WHEN s.vehicle_id IS NULL
              OR s.submission_id IS NULL
              OR (s.n <= 31 AND
                  (s.actual_vehicle_lifecycle_status <> 'IN_STOCK'
                   OR s.actual_submission_status <> 'ACCEPTED'
                   OR s.actual_submission_closed_at IS NULL
                   OR s.actual_submission_closed_at <> s.expected_acquired_at))
              OR (s.n > 31 AND
                  (s.actual_vehicle_lifecycle_status <> 'SUBMITTED'
                   OR s.actual_submission_status <> 'SUBMITTED'
                   OR s.actual_submission_closed_at IS NOT NULL))
            THEN 1 ELSE 0
        END)) AS bad_lifecycle_rows
    FROM SourceRows AS s
    GROUP BY s.n
),
Checks AS
(
    SELECT
        N'source_vehicle_submission_valuation_keys' AS check_name,
        COUNT_BIG(*) AS failure_count
    FROM SourceCheck
    WHERE vehicle_keys <> 1
       OR submission_keys <> 1
       OR valuation_keys <> 1
       OR vehicle_created_at_matches <> 1

    UNION ALL
    SELECT N'offers_count', ABS((SELECT COUNT_BIG(*)
        FROM acquisition.PurchaseOffer AS o
        JOIN vehicle.VehicleSubmission AS s ON s.submission_id = o.submission_id
        JOIN vehicle.Vehicle AS v ON v.vehicle_id = s.vehicle_id
        WHERE v.vin LIKE 'D3SYN%') - CONVERT(bigint, 49))

    UNION ALL
    SELECT N'offers_payload_and_relationships',
        COUNT_BIG(*) FROM OfferCheck
    WHERE matching_rows <> 1 OR bad_payload_rows <> 0

    UNION ALL
    SELECT N'agreements_count', ABS((SELECT COUNT_BIG(*)
        FROM acquisition.PurchaseAgreement AS a
        JOIN acquisition.PurchaseOffer AS o ON o.offer_id = a.offer_id
        JOIN vehicle.VehicleSubmission AS s ON s.submission_id = o.submission_id
        JOIN vehicle.Vehicle AS v ON v.vehicle_id = s.vehicle_id
        WHERE v.vin LIKE 'D3SYN%') - CONVERT(bigint, 34))

    UNION ALL
    SELECT N'agreements_payload_and_offer_seller_relationships',
        COUNT_BIG(*) FROM AgreementCheck
    WHERE matching_rows <> 1 OR bad_payload_rows <> 0

    UNION ALL
    SELECT N'acquisitions_count', ABS((SELECT COUNT_BIG(*)
        FROM acquisition.VehicleAcquisition AS ac
        JOIN vehicle.Vehicle AS v ON v.vehicle_id = ac.vehicle_id
        WHERE v.vin LIKE 'D3SYN%') - CONVERT(bigint, 31))

    UNION ALL
    SELECT N'acquisitions_payload_and_relationships',
        COUNT_BIG(*) FROM AcquisitionCheck
    WHERE matching_rows <> 1 OR bad_payload_rows <> 0

    UNION ALL
    SELECT N'inventory_positions_count', ABS((SELECT COUNT_BIG(*)
        FROM inventory.Inventory AS i
        JOIN vehicle.Vehicle AS v ON v.vehicle_id = i.vehicle_id
        WHERE v.vin LIKE 'D3SYN%') - CONVERT(bigint, 31))

    UNION ALL
    SELECT N'inventory_payload_and_acquisition_relationships',
        COUNT_BIG(*) FROM InventoryCheck
    WHERE matching_rows <> 1 OR bad_payload_rows <> 0

    UNION ALL
    SELECT N'phase04_receipt_transfer_movement_count', ABS((SELECT COUNT_BIG(*)
        FROM inventory.InventoryMovement AS m
        JOIN inventory.Inventory AS i ON i.inventory_id = m.inventory_id
        JOIN vehicle.Vehicle AS v ON v.vehicle_id = i.vehicle_id
        WHERE v.vin LIKE 'D3SYN%'
          AND m.movement_type IN ('RECEIPT', 'TRANSFER')) - CONVERT(bigint, 54))

    UNION ALL
    SELECT N'receipt_transfer_payload_inventory_employee_relationships',
        COUNT_BIG(*) FROM MovementCheck
    WHERE matching_rows <> 1 OR bad_payload_rows <> 0

    UNION ALL
    SELECT N'phase04_vehicle_submission_lifecycle',
        COUNT_BIG(*) FROM LifecycleCheck
    WHERE vehicle_rows <> 1 OR submission_rows <> 1 OR bad_lifecycle_rows <> 0
)
SELECT
    check_name,
    failure_count,
    CASE WHEN failure_count = 0 THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM Checks
ORDER BY check_name
OPTION (MAXRECURSION 100);
