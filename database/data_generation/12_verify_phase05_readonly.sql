/*
    Independent, read-only Phase 05 verification.
    Run with CARS24DataModelingSystem selected as the target database.
    Expected rows are reconstructed from the deterministic ordinal rules and
    Phase 04 inventory source rows; generator output is not used as evidence.
*/
;WITH Ordinals(n) AS
(
    SELECT 1
    UNION ALL
    SELECT n + 1
    FROM Ordinals
    WHERE n < 99
),
ExpectedListings AS
(
    SELECT
        o.n AS listing_n,
        CASE WHEN o.n <= 31 THEN o.n ELSE o.n - 31 END AS vehicle_n,
        v.vehicle_id AS expected_vehicle_id,
        v.vin AS expected_vin,
        inv.branch_id AS expected_branch_id,
        DATEADD(day, CASE WHEN o.n <= 31 THEN 5 ELSE 20 END, inv.since_at) AS expected_listed_at,
        CASE
            WHEN o.n BETWEEN 4 AND 21 OR o.n BETWEEN 32 AND 34 THEN CONVERT(datetime2(0), NULL)
            ELSE DATEADD(day, 60, DATEADD(day, CASE WHEN o.n <= 31 THEN 5 ELSE 20 END, inv.since_at))
        END AS expected_closed_at,
        CASE
            WHEN o.n BETWEEN 4 AND 18 OR o.n BETWEEN 32 AND 34 THEN 'ACTIVE'
            WHEN o.n BETWEEN 19 AND 21 THEN 'PAUSED'
            WHEN o.n BETWEEN 26 AND 31 THEN 'WITHDRAWN'
            ELSE 'CLOSED'
        END AS expected_status,
        CONVERT(decimal(19,4),
            (500000 + ((CASE WHEN o.n <= 31 THEN o.n ELSE o.n - 31 END) % 20) * 25000) * 1.03
        ) AS expected_asking_price,
        CONVERT(char(3), 'INR') AS expected_currency_code,
        CONVERT(nvarchar(1000), CONCAT(N'Day 3 synthetic listing ', RIGHT(CONCAT(N'0000', o.n), 4))) AS expected_description
    FROM Ordinals AS o
    JOIN vehicle.Vehicle AS v
        ON v.vin = CONCAT('D3SYN', RIGHT(CONCAT('000000000000', CASE WHEN o.n <= 31 THEN o.n ELSE o.n - 31 END), 12))
    JOIN inventory.Inventory AS inv
        ON inv.vehicle_id = v.vehicle_id
    WHERE o.n <= 34
),
ExpectedImages AS
(
    SELECT
        l.expected_vin,
        l.expected_listed_at,
        img.display_order AS expected_display_order,
        CONVERT(nvarchar(500), CONCAT(
            N'https://media.example.invalid/day3/vehicle-',
            RIGHT(CONCAT(N'0000', l.vehicle_n), 4),
            N'/photo-', img.display_order, N'.jpg'
        )) AS expected_image_reference,
        CONVERT(nvarchar(200), CONCAT(N'Synthetic exterior/interior view ', img.display_order)) AS expected_caption
    FROM ExpectedListings AS l
    CROSS JOIN (VALUES (1), (2), (3), (4)) AS img(display_order)
    WHERE img.display_order <= CASE WHEN l.listing_n <= 17 THEN 4 ELSE 3 END
),
ExpectedEnquiries AS
(
    SELECT
        o.n AS enquiry_n,
        l.expected_vin,
        l.expected_listed_at,
        CONCAT(N'D3 Synthetic Customer ', RIGHT(CONCAT(N'0000', ((o.n - 1) % 97) + 1), 4)) AS expected_customer_name,
        CONVERT(varchar(30), 'D3-EMP-0002') AS expected_employee_code,
        DATEADD(hour, 2, DATEADD(day, 1, l.expected_listed_at)) AS expected_received_at,
        CASE o.n % 5
            WHEN 0 THEN 'WEB' WHEN 1 THEN 'PHONE' WHEN 2 THEN 'BRANCH' WHEN 3 THEN 'PARTNER' ELSE 'OTHER'
        END AS expected_channel_code,
        CASE o.n % 4
            WHEN 0 THEN 'OPEN' WHEN 1 THEN 'IN_PROGRESS' WHEN 2 THEN 'RESOLVED' ELSE 'CLOSED'
        END AS expected_status,
        CONVERT(nvarchar(300), CONCAT(N'D3-ENQ-', RIGHT(CONCAT(N'0000', o.n), 4))) AS expected_message_reference
    FROM Ordinals AS o
    JOIN ExpectedListings AS l
        ON l.listing_n = ((o.n - 1) % 33) + 1
    WHERE o.n <= 99
),
ExpectedReservations AS
(
    SELECT
        o.n AS reservation_n,
        l.expected_vin,
        l.expected_listed_at,
        CONCAT(N'D3 Synthetic Customer ', RIGHT(CONCAT(N'0000',
            CASE WHEN o.n <= 7 THEN 80 + o.n WHEN o.n <= 13 THEN 82 + o.n ELSE 70 + o.n END), 4)) AS expected_customer_name,
        CASE
            WHEN o.n <= 7 THEN DATEADD(hour, o.n, CONVERT(datetime2(0), '2026-10-30T09:00:00'))
            WHEN o.n <= 13 THEN DATEADD(day, 40, l.expected_listed_at)
            ELSE DATEADD(day, 5, l.expected_listed_at)
        END AS expected_created_at,
        CASE
            WHEN o.n <= 7 THEN DATEADD(day, 3, DATEADD(hour, o.n, CONVERT(datetime2(0), '2026-10-30T09:00:00')))
            WHEN o.n <= 13 THEN DATEADD(day, 3, DATEADD(day, 40, l.expected_listed_at))
            ELSE DATEADD(day, 3, DATEADD(day, 5, l.expected_listed_at))
        END AS expected_expires_at,
        CASE
            WHEN o.n <= 7 THEN 'ACTIVE'
            WHEN o.n <= 13 THEN 'CONVERTED'
            WHEN o.n <= 18 THEN 'RELEASED'
            ELSE 'EXPIRED'
        END AS expected_status,
        CASE
            WHEN o.n <= 7 THEN CONVERT(datetime2(0), NULL)
            WHEN o.n <= 13 THEN DATEADD(minute, 10, DATEADD(day, 40, l.expected_listed_at))
            WHEN o.n <= 18 THEN DATEADD(day, 7, l.expected_listed_at)
            ELSE DATEADD(day, 8, l.expected_listed_at)
        END AS expected_released_at
    FROM Ordinals AS o
    JOIN ExpectedListings AS l
        ON l.listing_n = o.n + 3
    WHERE o.n <= 24
),
ExpectedVehicleLifecycle AS
(
    SELECT
        o.n AS vehicle_n,
        v.vin AS expected_vin,
        CASE
            WHEN o.n BETWEEN 4 AND 10 THEN 'RESERVED'
            WHEN o.n BETWEEN 1 AND 3 OR o.n BETWEEN 11 AND 18 THEN 'LISTED'
            ELSE 'IN_STOCK'
        END AS expected_lifecycle_status,
        CASE WHEN o.n BETWEEN 4 AND 10 THEN 'HELD' ELSE 'AVAILABLE' END AS expected_inventory_status
    FROM Ordinals AS o
    JOIN vehicle.Vehicle AS v
        ON v.vin = CONCAT('D3SYN', RIGHT(CONCAT('000000000000', o.n), 12))
    WHERE o.n <= 31
),
ActualListings AS
(
    SELECT
        v.vin,
        l.listed_at,
        l.branch_id,
        l.closed_at,
        l.status,
        l.asking_price,
        l.currency_code,
        l.description,
        l.listing_id,
        v.vehicle_id,
        b.branch_id AS resolved_branch_id
    FROM marketplace.VehicleListing AS l
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id = l.vehicle_id
    LEFT JOIN core.Branch AS b ON b.branch_id = l.branch_id
    WHERE v.vin LIKE 'D3SYN%'
       OR l.description LIKE N'Day 3 synthetic listing %'
),
ActualImages AS
(
    SELECT
        v.vin,
        l.listed_at,
        i.display_order,
        i.image_reference,
        i.caption,
        i.listing_image_id,
        i.listing_id
    FROM marketplace.ListingImage AS i
    LEFT JOIN marketplace.VehicleListing AS l ON l.listing_id = i.listing_id
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id = l.vehicle_id
    WHERE v.vin LIKE 'D3SYN%'
       OR l.description LIKE N'Day 3 synthetic listing %'
       OR i.image_reference LIKE N'https://media.example.invalid/day3/vehicle-%/photo-%.jpg'
),
ActualEnquiries AS
(
    SELECT
        v.vin,
        l.listed_at,
        c.display_name AS customer_name,
        e.employee_code,
        q.channel_code,
        q.received_at,
        q.status,
        q.message_reference,
        q.enquiry_id,
        q.listing_id,
        q.customer_id,
        q.assigned_employee_id,
        c.customer_id AS resolved_customer_id,
        e.employee_id AS resolved_employee_id
    FROM marketplace.CustomerEnquiry AS q
    LEFT JOIN marketplace.VehicleListing AS l ON l.listing_id = q.listing_id
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id = l.vehicle_id
    LEFT JOIN core.Customer AS c ON c.customer_id = q.customer_id
    LEFT JOIN core.Employee AS e ON e.employee_id = q.assigned_employee_id
    WHERE q.message_reference LIKE N'D3-ENQ-%'
       OR v.vin LIKE 'D3SYN%'
       OR l.description LIKE N'Day 3 synthetic listing %'
),
ActualReservations AS
(
    SELECT
        v.vin,
        l.listed_at,
        c.display_name AS customer_name,
        r.created_at,
        r.expires_at,
        r.status,
        r.released_at,
        r.reservation_id,
        r.listing_id,
        r.customer_id,
        c.customer_id AS resolved_customer_id
    FROM marketplace.VehicleReservation AS r
    LEFT JOIN marketplace.VehicleListing AS l ON l.listing_id = r.listing_id
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id = l.vehicle_id
    LEFT JOIN core.Customer AS c ON c.customer_id = r.customer_id
    WHERE v.vin LIKE 'D3SYN%'
       OR l.description LIKE N'Day 3 synthetic listing %'
       OR EXISTS
          (SELECT 1
           FROM ExpectedReservations AS er
           WHERE er.expected_created_at = r.created_at
             AND er.expected_customer_name = c.display_name)
),
ActualVehicleLifecycle AS
(
    SELECT
        v.vin,
        v.lifecycle_status,
        inv.status AS inventory_status
    FROM vehicle.Vehicle AS v
    LEFT JOIN inventory.Inventory AS inv ON inv.vehicle_id = v.vehicle_id
    WHERE v.vin LIKE 'D3SYN%'
      AND TRY_CONVERT(int, RIGHT(v.vin, 12)) BETWEEN 1 AND 31
),
CheckResults(check_name, failure_count) AS
(
    SELECT N'target_database', CONVERT(bigint, CASE WHEN DB_NAME() = N'CARS24DataModelingSystem' THEN 0 ELSE 1 END)
    UNION ALL
    SELECT N'expected_listing_source_count', ABS(COUNT_BIG(*) - 34) FROM ExpectedListings
    UNION ALL
    SELECT N'listings_count', ABS(COUNT_BIG(*) - 34) FROM ActualListings
    UNION ALL
    SELECT N'listings_complete_payload_and_vehicle_inventory_relationships',
        (SELECT COUNT_BIG(*) FROM
            (SELECT expected_vin, expected_listed_at, expected_branch_id, expected_closed_at, expected_status,
                    expected_asking_price, expected_currency_code, expected_description
             FROM ExpectedListings
             EXCEPT
             SELECT vin, listed_at, branch_id, closed_at, status, asking_price, currency_code, description
             FROM ActualListings) AS missing_or_changed)
        + (SELECT COUNT_BIG(*) FROM
            (SELECT vin, listed_at, branch_id, closed_at, status, asking_price, currency_code, description
             FROM ActualListings
             EXCEPT
             SELECT expected_vin, expected_listed_at, expected_branch_id, expected_closed_at, expected_status,
                    expected_asking_price, expected_currency_code, expected_description
             FROM ExpectedListings) AS unexpected_or_changed)
    UNION ALL
    SELECT N'listing_vehicle_and_branch_references', COUNT_BIG(*)
    FROM ActualListings AS a
    WHERE a.vehicle_id IS NULL OR a.resolved_branch_id IS NULL
    UNION ALL
    SELECT N'listing_event_key_uniqueness', COUNT_BIG(*)
    FROM (SELECT vehicle_id, listed_at FROM ActualListings GROUP BY vehicle_id, listed_at HAVING COUNT_BIG(*) > 1) AS duplicate_listing_keys
    UNION ALL
    SELECT N'expected_listing_image_source_count', ABS(COUNT_BIG(*) - 119) FROM ExpectedImages
    UNION ALL
    SELECT N'listing_images_count', ABS(COUNT_BIG(*) - 119) FROM ActualImages
    UNION ALL
    SELECT N'listing_images_complete_payload_and_parent_relationships',
        (SELECT COUNT_BIG(*) FROM
            (SELECT expected_vin, expected_listed_at, expected_display_order, expected_image_reference, expected_caption
             FROM ExpectedImages
             EXCEPT
             SELECT vin, listed_at, display_order, image_reference, caption FROM ActualImages) AS missing_or_changed)
        + (SELECT COUNT_BIG(*) FROM
            (SELECT vin, listed_at, display_order, image_reference, caption FROM ActualImages
             EXCEPT
             SELECT expected_vin, expected_listed_at, expected_display_order, expected_image_reference, expected_caption
             FROM ExpectedImages) AS unexpected_or_changed)
    UNION ALL
    SELECT N'listing_image_parent_and_order_uniqueness', COUNT_BIG(*)
    FROM (SELECT listing_id, display_order FROM ActualImages GROUP BY listing_id, display_order HAVING COUNT_BIG(*) > 1) AS duplicate_image_keys
    UNION ALL
    SELECT N'expected_enquiry_source_count', ABS(COUNT_BIG(*) - 99) FROM ExpectedEnquiries
    UNION ALL
    SELECT N'enquiries_count', ABS(COUNT_BIG(*) - 99) FROM ActualEnquiries
    UNION ALL
    SELECT N'enquiries_complete_payload_and_listing_customer_employee_relationships',
        (SELECT COUNT_BIG(*) FROM
            (SELECT expected_vin, expected_listed_at, expected_customer_name, expected_employee_code,
                    expected_channel_code, expected_received_at, expected_status, expected_message_reference
             FROM ExpectedEnquiries
             EXCEPT
             SELECT vin, listed_at, customer_name, employee_code, channel_code, received_at, status, message_reference
             FROM ActualEnquiries) AS missing_or_changed)
        + (SELECT COUNT_BIG(*) FROM
            (SELECT vin, listed_at, customer_name, employee_code, channel_code, received_at, status, message_reference
             FROM ActualEnquiries
             EXCEPT
             SELECT expected_vin, expected_listed_at, expected_customer_name, expected_employee_code,
                    expected_channel_code, expected_received_at, expected_status, expected_message_reference
             FROM ExpectedEnquiries) AS unexpected_or_changed)
    UNION ALL
    SELECT N'enquiry_listing_customer_and_assigned_employee_references', COUNT_BIG(*)
    FROM ActualEnquiries AS a
    WHERE a.enquiry_id IS NULL OR a.listing_id IS NULL OR a.customer_id IS NULL
       OR a.resolved_customer_id IS NULL OR a.assigned_employee_id IS NULL OR a.resolved_employee_id IS NULL
    UNION ALL
    SELECT N'enquiry_message_reference_uniqueness', COUNT_BIG(*)
    FROM (SELECT message_reference FROM ActualEnquiries GROUP BY message_reference HAVING COUNT_BIG(*) > 1) AS duplicate_enquiry_keys
    UNION ALL
    SELECT N'expected_reservation_source_count', ABS(COUNT_BIG(*) - 24) FROM ExpectedReservations
    UNION ALL
    SELECT N'reservations_count', ABS(COUNT_BIG(*) - 24) FROM ActualReservations
    UNION ALL
    SELECT N'reservations_complete_payload_and_listing_customer_relationships',
        (SELECT COUNT_BIG(*) FROM
            (SELECT expected_vin, expected_listed_at, expected_customer_name, expected_created_at,
                    expected_expires_at, expected_status, expected_released_at
             FROM ExpectedReservations
             EXCEPT
             SELECT vin, listed_at, customer_name, created_at, expires_at, status, released_at
             FROM ActualReservations) AS missing_or_changed)
        + (SELECT COUNT_BIG(*) FROM
            (SELECT vin, listed_at, customer_name, created_at, expires_at, status, released_at
             FROM ActualReservations
             EXCEPT
             SELECT expected_vin, expected_listed_at, expected_customer_name, expected_created_at,
                    expected_expires_at, expected_status, expected_released_at
             FROM ExpectedReservations) AS unexpected_or_changed)
    UNION ALL
    SELECT N'reservation_listing_and_customer_references', COUNT_BIG(*)
    FROM ActualReservations AS a
    WHERE a.reservation_id IS NULL OR a.listing_id IS NULL OR a.customer_id IS NULL OR a.resolved_customer_id IS NULL
    UNION ALL
    SELECT N'reservation_event_key_uniqueness', COUNT_BIG(*)
    FROM (SELECT listing_id, created_at FROM ActualReservations GROUP BY listing_id, created_at HAVING COUNT_BIG(*) > 1) AS duplicate_reservation_keys
    UNION ALL
    SELECT N'reservation_status_distribution', CONVERT(bigint, CASE
        WHEN (SELECT COUNT_BIG(*) FROM ActualReservations WHERE status = 'ACTIVE') = 7
         AND (SELECT COUNT_BIG(*) FROM ActualReservations WHERE status = 'CONVERTED') = 6
         AND (SELECT COUNT_BIG(*) FROM ActualReservations WHERE status = 'RELEASED') = 5
         AND (SELECT COUNT_BIG(*) FROM ActualReservations WHERE status = 'EXPIRED') = 6 THEN 0 ELSE 1 END)
    UNION ALL
    SELECT N'reservation_temporal_business_rules', COUNT_BIG(*)
    FROM ActualReservations AS a
    WHERE a.expires_at <= a.created_at OR (a.released_at IS NOT NULL AND a.released_at < a.created_at)
    UNION ALL
    SELECT N'reservations_share_expected_listing_context_with_enquiries', COUNT_BIG(*)
    FROM ExpectedReservations AS r
    WHERE NOT EXISTS
    (
        SELECT 1 FROM ActualEnquiries AS e
        WHERE e.vin = r.expected_vin AND e.listed_at = r.expected_listed_at
    )
    UNION ALL
    SELECT N'active_listing_count', ABS(COUNT_BIG(*) - 18)
    FROM ActualListings WHERE status = 'ACTIVE'
    UNION ALL
    SELECT N'active_reservation_count', ABS(COUNT_BIG(*) - 7)
    FROM ActualReservations WHERE status = 'ACTIVE'
    UNION ALL
    SELECT N'active_listing_uniqueness_per_vehicle', COUNT_BIG(*)
    FROM
    (
        SELECT vehicle_id FROM ActualListings WHERE status = 'ACTIVE'
        GROUP BY vehicle_id HAVING COUNT_BIG(*) > 1
    ) AS duplicate_active_listings
    UNION ALL
    SELECT N'active_reservation_uniqueness_per_vehicle', COUNT_BIG(*)
    FROM
    (
        SELECT a.vehicle_id
        FROM ActualReservations AS r
        JOIN marketplace.VehicleListing AS l ON l.listing_id = r.listing_id
        JOIN vehicle.Vehicle AS a ON a.vehicle_id = l.vehicle_id
        WHERE r.status = 'ACTIVE' AND a.vin LIKE 'D3SYN%'
        GROUP BY a.vehicle_id HAVING COUNT_BIG(*) > 1
    ) AS duplicate_active_reservations
    UNION ALL
    SELECT N'vehicle_and_inventory_lifecycle_after_marketplace_holds',
        (SELECT COUNT_BIG(*) FROM
            (SELECT expected_vin, expected_lifecycle_status, expected_inventory_status FROM ExpectedVehicleLifecycle
             EXCEPT
             SELECT vin, lifecycle_status, inventory_status FROM ActualVehicleLifecycle) AS missing_or_changed)
        + (SELECT COUNT_BIG(*) FROM
            (SELECT vin, lifecycle_status, inventory_status FROM ActualVehicleLifecycle
             EXCEPT
             SELECT expected_vin, expected_lifecycle_status, expected_inventory_status FROM ExpectedVehicleLifecycle) AS unexpected_or_changed)
),
Summary AS
(
    SELECT
        COUNT_BIG(*) AS total_checks,
        SUM(CONVERT(bigint, CASE WHEN failure_count = 0 THEN 1 ELSE 0 END)) AS passed_checks,
        SUM(CONVERT(bigint, CASE WHEN failure_count <> 0 THEN 1 ELSE 0 END)) AS failed_checks
    FROM CheckResults
),
OutputRows AS
(
    SELECT
        CONVERT(int, 0) AS sort_order,
        results.check_name,
        results.failure_count,
        CASE WHEN results.failure_count = 0 THEN 'PASS' ELSE 'FAIL' END AS check_result,
        summary.total_checks,
        summary.passed_checks,
        summary.failed_checks,
        CASE WHEN summary.failed_checks = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_result
    FROM CheckResults AS results
    CROSS JOIN Summary AS summary
    UNION ALL
    SELECT
        CONVERT(int, 1),
        N'SUMMARY',
        summary.failed_checks,
        CASE WHEN summary.failed_checks = 0 THEN 'PASS' ELSE 'FAIL' END,
        summary.total_checks,
        summary.passed_checks,
        summary.failed_checks,
        CASE WHEN summary.failed_checks = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM Summary AS summary
)
SELECT
    resultRow.check_name,
    resultRow.failure_count,
    resultRow.check_result,
    resultRow.total_checks,
    resultRow.passed_checks,
    resultRow.failed_checks,
    resultRow.overall_result
FROM OutputRows AS resultRow
ORDER BY resultRow.sort_order, resultRow.check_name
OPTION (MAXRECURSION 100);
