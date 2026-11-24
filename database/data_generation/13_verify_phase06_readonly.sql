/*
    Independent, read-only Phase 06 verification.
    Run against CARS24DataModelingSystem after Phase 06 commits.
    The expected order cohort is reconstructed from Phase 05 listing dates and
    deterministic order rules. Payment, refund and fulfillment payloads are
    derived from those expected orders; generator output is not used.
*/
;WITH
Ordinals(n) AS
(
    SELECT CONVERT(int, 1)
    UNION ALL SELECT n + 1 FROM Ordinals WHERE n < 26
),
BranchMap(slot_no, branch_code) AS
(
    SELECT branch_map.slot_no, branch_map.branch_code
    FROM (VALUES
        (0, CONVERT(varchar(30), 'HYD-CEN')),
        (1, CONVERT(varchar(30), 'MUM-WST')),
        (2, CONVERT(varchar(30), 'BLR-SOU')),
        (3, CONVERT(varchar(30), 'PUN-CEN')),
        (4, CONVERT(varchar(30), 'DEL-SOU')),
        (5, CONVERT(varchar(30), 'CHE-CEN')),
        (6, CONVERT(varchar(30), 'AMD-CEN')),
        (7, CONVERT(varchar(30), 'RJK-CEN'))
    ) AS branch_map(slot_no, branch_code)
),
OrderSource AS
(
    SELECT
        n.n AS order_n,
        n.n + 10 AS vehicle_n,
        CASE WHEN n.n <= 6 THEN 89 + n.n
             WHEN n.n <= 10 THEN 40 + n.n
             ELSE 43 + n.n END AS buyer_n,
        CASE WHEN n.n <= 6 THEN n.n + 7 END AS reservation_n,
        inv.since_at,
        DATEADD(day, 5, inv.since_at) AS expected_listing_at,
        v.vehicle_id AS source_vehicle_id,
        inv.inventory_id AS source_inventory_id,
        listing.listing_id AS source_listing_id,
        listing.status AS source_listing_status,
        listing.closed_at AS source_listing_closed_at
    FROM Ordinals AS n
    LEFT JOIN vehicle.Vehicle AS v
        ON v.vin = CONCAT('D3SYN', RIGHT(CONCAT('000000000000', n.n + 10), 12))
    LEFT JOIN inventory.Inventory AS inv
        ON inv.vehicle_id = v.vehicle_id
    LEFT JOIN marketplace.VehicleListing AS listing
        ON listing.vehicle_id = v.vehicle_id
       AND listing.listed_at = DATEADD(day, 5, inv.since_at)
    WHERE n.n <= 18
),
ExpectedOrders AS
(
    SELECT
        src.order_n,
        src.vehicle_n,
        src.buyer_n,
        src.reservation_n,
        CONCAT('D3SYN', RIGHT(CONCAT('000000000000', src.vehicle_n), 12)) AS expected_vin,
        src.since_at AS inventory_since_at,
        src.expected_listing_at,
        src.source_vehicle_id,
        src.source_inventory_id,
        src.source_listing_id,
        CASE WHEN src.order_n <= 6
             THEN DATEADD(minute, 15, DATEADD(day, 40, src.expected_listing_at))
             ELSE DATEADD(day, 45, src.expected_listing_at) END AS created_at,
        CASE WHEN src.order_n <= 8 THEN 'COMPLETED'
             WHEN src.order_n IN (9,10,11,12,16,17) THEN 'CONFIRMED'
             WHEN src.order_n = 13 THEN 'DRAFT'
             ELSE 'CANCELLED' END AS status,
        CASE WHEN src.order_n <= 8 OR src.order_n IN (9,10,11,12,16,17)
             THEN CASE WHEN src.order_n <= 6
                       THEN DATEADD(minute, 15, DATEADD(day, 40, src.expected_listing_at))
                       ELSE DATEADD(day, 45, src.expected_listing_at) END END AS confirmed_at,
        CASE WHEN src.order_n <= 8
             THEN DATEADD(day, 5, CASE WHEN src.order_n <= 6
                                       THEN DATEADD(minute, 15, DATEADD(day, 40, src.expected_listing_at))
                                       ELSE DATEADD(day, 45, src.expected_listing_at) END) END AS completed_at,
        CASE WHEN src.order_n IN (14,15,18)
             THEN DATEADD(day, 1, DATEADD(day, 45, src.expected_listing_at)) END AS cancelled_at,
        CONVERT(decimal(19,4), (500000 + ((src.vehicle_n % 20) * 25000)) * 1.03 * 0.985) AS sale_price
    FROM OrderSource AS src
),
ExpectedPaymentMap AS
(
    SELECT
        n.n AS payment_n,
        CASE WHEN n.n <= 10 THEN (n.n + 1) / 2
             WHEN n.n <= 13 THEN n.n - 5
             WHEN n.n IN (14,15) THEN 9
             WHEN n.n = 16 THEN 10
             WHEN n.n = 17 THEN 11
             WHEN n.n = 18 THEN 12
             WHEN n.n IN (19,20) THEN 13
             WHEN n.n = 21 THEN 14
             WHEN n.n = 22 THEN 15
             WHEN n.n = 23 THEN 16
             WHEN n.n IN (24,25) THEN 17
             ELSE 18 END AS order_n
    FROM Ordinals AS n
    WHERE n.n <= 26
),
ExpectedPayments AS
(
    SELECT
        m.payment_n,
        o.order_n,
        o.buyer_n,
        o.created_at AS order_created_at,
        CONCAT('D3-PAY-', RIGHT(CONCAT('0000',m.payment_n),4)) AS provider_reference,
        CASE WHEN m.payment_n <= 13 THEN 'SUCCEEDED'
             WHEN m.payment_n IN (14,16,17,19,23,25) THEN 'PENDING'
             WHEN m.payment_n = 22 THEN 'REVERSED'
             ELSE 'FAILED' END AS status,
        CASE WHEN m.payment_n <= 10 THEN o.sale_price / 2
             WHEN m.payment_n <= 13 THEN o.sale_price
             ELSE CONVERT(decimal(19,4), 10000 + m.payment_n * 500) END AS amount,
        CASE WHEN m.payment_n % 2 = 0 THEN 'CARD' ELSE 'UPI' END AS payment_method_code,
        DATEADD(minute, m.payment_n * 5, DATEADD(hour, 1, o.created_at)) AS initiated_at,
        CASE WHEN m.payment_n <= 13 OR m.payment_n = 22
             THEN DATEADD(minute, 5, DATEADD(minute, m.payment_n * 5, DATEADD(hour, 1, o.created_at))) END AS settled_at
    FROM ExpectedPaymentMap AS m
    JOIN ExpectedOrders AS o ON o.order_n = m.order_n
),
RefundSeed(refund_n, payment_n, amount, status, days_after_settlement) AS
(
    SELECT seed.refund_n, seed.payment_n, seed.amount, seed.status, seed.days_after_settlement
    FROM (VALUES
        (1,1,CONVERT(decimal(19,4),2500),'SUCCEEDED',1),
        (2,2,CONVERT(decimal(19,4),5000),'SUCCEEDED',2),
        (3,3,CONVERT(decimal(19,4),2000),'PENDING',3),
        (4,4,CONVERT(decimal(19,4),3000),'FAILED',4),
        (5,13,CONVERT(decimal(19,4),1500),'SUCCEEDED',5)
    ) AS seed(refund_n,payment_n,amount,status,days_after_settlement)
),
ExpectedRefunds AS
(
    SELECT
        seed.refund_n,
        seed.payment_n,
        payment.provider_reference AS expected_payment_reference,
        CONCAT('D3-REF-',RIGHT(CONCAT('0000',seed.refund_n),4)) AS provider_reference,
        seed.amount,
        seed.status,
        DATEADD(day,seed.days_after_settlement,payment.settled_at) AS requested_at,
        CASE WHEN seed.status='SUCCEEDED'
             THEN DATEADD(minute,5,DATEADD(day,seed.days_after_settlement,payment.settled_at)) END AS settled_at
    FROM RefundSeed AS seed
    JOIN ExpectedPayments AS payment ON payment.payment_n=seed.payment_n
),
ExpectedTransfers AS
(
    SELECT
        o.order_n,
        o.vehicle_n,
        o.buyer_n,
        o.created_at AS order_created_at,
        CONCAT('D3-TR-',RIGHT(CONCAT('0000',o.order_n),4)) AS authority_reference,
        CASE WHEN o.order_n <= 8 THEN 'COMPLETED'
             WHEN o.order_n <= 10 THEN 'IN_PROGRESS'
             WHEN o.order_n = 11 THEN 'SUBMITTED' ELSE 'REJECTED' END AS status,
        DATEADD(day,1,o.created_at) AS submitted_at,
        CASE WHEN o.order_n <= 8 THEN DATEADD(day,3,o.created_at) END AS completed_at,
        CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',o.vehicle_n),4)) AS from_customer_name,
        CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',o.buyer_n),4)) AS to_customer_name
    FROM ExpectedOrders AS o
    WHERE o.order_n <= 12
),
ExpectedDeliveries AS
(
    SELECT
        o.order_n,
        o.vehicle_n,
        o.buyer_n,
        o.created_at AS order_created_at,
        CONCAT('D3-HAND-',RIGHT(CONCAT('0000',o.order_n),4)) AS handover_reference,
        CASE WHEN o.order_n <= 8 THEN 'COMPLETED'
             WHEN o.order_n <= 10 THEN 'SCHEDULED'
             WHEN o.order_n = 11 THEN 'IN_TRANSIT' ELSE 'FAILED' END AS status,
        DATEADD(day,4,o.created_at) AS scheduled_at,
        CASE WHEN o.order_n <= 8 THEN DATEADD(hour,1,DATEADD(day,4,o.created_at)) END AS completed_at,
        CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',o.buyer_n),4)) AS recipient_name,
        branch.branch_code AS expected_branch_code,
        CONCAT(N'D3 Synthetic Address ',RIGHT(CONCAT(N'0000',o.buyer_n),4)) AS expected_address_line1
    FROM ExpectedOrders AS o
    JOIN BranchMap AS branch ON branch.slot_no = (o.vehicle_n + 1) % 8
    WHERE o.order_n <= 12
),
ExpectedSaleHistory AS
(
    SELECT
        o.order_n,
        o.vehicle_n,
        o.buyer_n,
        o.source_vehicle_id AS vehicle_id,
        seller.customer_id AS expected_seller_customer_id,
        CONCAT('D3-TR-',RIGHT(CONCAT('0000',o.order_n),4)) AS evidence_reference,
        transfer.completed_at AS valid_from
    FROM ExpectedOrders AS o
    JOIN ExpectedTransfers AS transfer ON transfer.order_n=o.order_n
    LEFT JOIN core.Customer AS seller
        ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',o.vehicle_n),4))
    WHERE o.order_n <= 8
),
ExpectedDispatches AS
(
    SELECT
        o.order_n,
        o.vehicle_n,
        transfer.completed_at AS occurred_at,
        branch.branch_code AS expected_from_branch_code,
        CONVERT(varchar(30),'D3-YARD-B') AS expected_from_location_code,
        CONVERT(varchar(30),NULL) AS expected_to_branch_code,
        CONVERT(varchar(30),NULL) AS expected_to_location_code,
        CONVERT(varchar(30),'D3-EMP-0011') AS expected_employee_code,
        CONVERT(nvarchar(500),N'Day 3 synthetic completed-sale dispatch') AS reason
    FROM ExpectedOrders AS o
    JOIN ExpectedTransfers AS transfer ON transfer.order_n=o.order_n
    JOIN BranchMap AS branch ON branch.slot_no = (o.vehicle_n + 1) % 8
    WHERE o.order_n <= 8
),
ActualOrders AS
(
    SELECT o.order_id, o.buyer_customer_id, o.created_at, o.status, o.currency_code,
           o.confirmed_at, o.completed_at, o.cancelled_at,
           c.display_name AS buyer_name, TRY_CONVERT(int,RIGHT(c.display_name,4)) AS buyer_n
    FROM sales.SalesOrder AS o
    LEFT JOIN core.Customer AS c ON c.customer_id=o.buyer_customer_id
    WHERE c.display_name LIKE N'D3 Synthetic Customer %'
),
ActualOrderItems AS
(
    SELECT i.order_item_id, i.order_id, i.vehicle_id, i.reservation_id, i.sale_price, i.currency_code,
           o.created_at AS order_created_at, o.buyer_n, v.vin,
           TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n
    FROM sales.SalesOrderItem AS i
    JOIN ActualOrders AS o ON o.order_id=i.order_id
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id=i.vehicle_id
),
ActualPayments AS
(
    SELECT p.payment_id,p.order_id,p.provider_code,p.provider_reference,p.payment_method_code,
           p.amount,p.currency_code,p.status,p.initiated_at,p.settled_at,
           o.created_at AS order_created_at,o.buyer_n,o.order_id AS resolved_order_id
    FROM finance.Payment AS p
    LEFT JOIN ActualOrders AS o ON o.order_id=p.order_id
    WHERE p.provider_reference LIKE 'D3-PAY-%' OR o.order_id IS NOT NULL
),
ActualRefunds AS
(
    SELECT r.refund_id,r.payment_id,r.provider_reference,r.amount,r.currency_code,r.status,
           r.requested_at,r.settled_at,p.provider_reference AS payment_reference,
           p.status AS payment_status,p.amount AS payment_amount,p.settled_at AS payment_settled_at
    FROM finance.Refund AS r
    LEFT JOIN ActualPayments AS p ON p.payment_id=r.payment_id
    WHERE r.provider_reference LIKE 'D3-REF-%' OR p.payment_id IS NOT NULL
),
ActualTransfers AS
(
    SELECT t.transfer_id,t.order_item_id,t.authority_reference,t.status,t.submitted_at,t.completed_at,
           seller.display_name AS from_customer_name,recipient.display_name AS to_customer_name,
           o.created_at AS order_created_at,o.buyer_n,TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n
    FROM delivery.OwnershipTransfer AS t
    LEFT JOIN ActualOrderItems AS i ON i.order_item_id=t.order_item_id
    LEFT JOIN ActualOrders AS o ON o.order_id=i.order_id
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id=i.vehicle_id
    LEFT JOIN core.Customer AS seller ON seller.customer_id=t.from_customer_id
    LEFT JOIN core.Customer AS recipient ON recipient.customer_id=t.to_customer_id
    WHERE t.authority_reference LIKE 'D3-TR-%' OR o.order_id IS NOT NULL
),
ActualDeliveries AS
(
    SELECT d.delivery_id,d.order_item_id,d.handover_reference,d.status,d.scheduled_at,d.completed_at,
           d.recipient_customer_id,d.branch_id,d.delivery_address_id,
           recipient.display_name AS recipient_name,branch.branch_code,address.address_line1,
           address.customer_id AS address_customer_id,o.buyer_customer_id,o.created_at AS order_created_at,o.buyer_n,
           TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n
    FROM delivery.VehicleDelivery AS d
    LEFT JOIN ActualOrderItems AS i ON i.order_item_id=d.order_item_id
    LEFT JOIN ActualOrders AS o ON o.order_id=i.order_id
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id=i.vehicle_id
    LEFT JOIN core.Customer AS recipient ON recipient.customer_id=d.recipient_customer_id
    LEFT JOIN core.Branch AS branch ON branch.branch_id=d.branch_id
    LEFT JOIN core.CustomerAddress AS address ON address.address_id=d.delivery_address_id
    WHERE d.handover_reference LIKE 'D3-HAND-%' OR o.order_id IS NOT NULL
),
ActualSaleHistory AS
(
    SELECT h.ownership_history_id,h.vehicle_id,h.customer_id,h.valid_from,h.valid_to,h.basis_code,h.evidence_reference,
           v.vin,TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,c.display_name AS owner_name
    FROM vehicle.VehicleOwnershipHistory AS h
    JOIN vehicle.Vehicle AS v ON v.vehicle_id=h.vehicle_id
    LEFT JOIN core.Customer AS c ON c.customer_id=h.customer_id
    WHERE TRY_CONVERT(int,RIGHT(v.vin,12)) BETWEEN 11 AND 28
      AND (h.basis_code='SALE' OR h.evidence_reference LIKE 'D3-TR-%' OR h.valid_from>v.created_at)
),
ActualDispatches AS
(
    SELECT m.movement_id,m.inventory_id,m.from_branch_id,m.from_location_code,m.to_branch_id,m.to_location_code,
           m.movement_type,m.employee_id,m.occurred_at,m.reason,
           TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,
           from_branch.branch_code AS from_branch_code,to_branch.branch_code AS to_branch_code,
           employee.employee_code
    FROM vehicle.Vehicle AS v
    JOIN inventory.Inventory AS inv ON inv.vehicle_id=v.vehicle_id
    JOIN inventory.InventoryMovement AS m ON m.inventory_id=inv.inventory_id
    LEFT JOIN ExpectedDispatches AS expected ON expected.vehicle_n=TRY_CONVERT(int,RIGHT(v.vin,12))
    LEFT JOIN core.Branch AS from_branch ON from_branch.branch_id=m.from_branch_id
    LEFT JOIN core.Branch AS to_branch ON to_branch.branch_id=m.to_branch_id
    LEFT JOIN core.Employee AS employee ON employee.employee_id=m.employee_id
    WHERE TRY_CONVERT(int,RIGHT(v.vin,12)) BETWEEN 11 AND 28
       AND (m.movement_type='DISPATCH'
       OR m.reason=N'Day 3 synthetic completed-sale dispatch'
       OR m.occurred_at=expected.occurred_at)
),
CheckResults(check_name,failure_count) AS
(
    SELECT N'target_database',CONVERT(bigint,CASE WHEN DB_NAME()=N'CARS24DataModelingSystem' THEN 0 ELSE 1 END)
    UNION ALL SELECT N'expected_order_source_count',ABS(COUNT_BIG(*)-18) FROM ExpectedOrders
    UNION ALL SELECT N'order_source_vehicle_inventory_listing_present',COUNT_BIG(*) FROM ExpectedOrders
        WHERE source_vehicle_id IS NULL OR source_inventory_id IS NULL OR source_listing_id IS NULL
    UNION ALL SELECT N'orders_count',ABS(COUNT_BIG(*)-18) FROM ActualOrders
    UNION ALL SELECT N'orders_complete_payload',
        (SELECT COUNT_BIG(*) FROM (SELECT buyer_n,created_at,status,confirmed_at,completed_at,cancelled_at,'INR' AS currency_code FROM ExpectedOrders
          EXCEPT SELECT buyer_n,created_at,status,confirmed_at,completed_at,cancelled_at,currency_code FROM ActualOrders) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT buyer_n,created_at,status,confirmed_at,completed_at,cancelled_at,currency_code FROM ActualOrders
          EXCEPT SELECT buyer_n,created_at,status,confirmed_at,completed_at,cancelled_at,'INR' AS currency_code FROM ExpectedOrders) AS unexpected_rows)
    UNION ALL SELECT N'order_key_uniqueness',COUNT_BIG(*) FROM
        (SELECT buyer_customer_id,created_at FROM ActualOrders GROUP BY buyer_customer_id,created_at HAVING COUNT_BIG(*)<>1) AS duplicates
    UNION ALL SELECT N'order_listing_and_completed_sale_lifecycle',COUNT_BIG(*)
    FROM ExpectedOrders AS e
    LEFT JOIN vehicle.Vehicle AS v ON v.vehicle_id=e.source_vehicle_id
    LEFT JOIN inventory.Inventory AS inv ON inv.inventory_id=e.source_inventory_id
    LEFT JOIN marketplace.VehicleListing AS l ON l.listing_id=e.source_listing_id
    LEFT JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',e.buyer_n),4))
    LEFT JOIN ExpectedTransfers AS transfer ON transfer.order_n=e.order_n
    WHERE l.listing_id IS NULL OR (e.order_n<=8 AND
        (l.status IS NULL OR l.status<>'SOLD' OR l.closed_at IS NULL OR l.closed_at<>e.completed_at
         OR v.lifecycle_status IS NULL OR v.lifecycle_status<>'SOLD'
         OR buyer.customer_id IS NULL OR v.current_owner_customer_id IS NULL OR v.current_owner_customer_id<>buyer.customer_id
         OR inv.status IS NULL OR inv.status<>'SOLD'
         OR NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory AS h
                       WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=buyer.customer_id
                          AND h.valid_from=transfer.completed_at AND h.valid_to IS NULL))
        OR (e.order_n>8 AND (v.lifecycle_status IS NULL OR v.lifecycle_status<>'IN_STOCK'
                             OR inv.status IS NULL OR inv.status<>'AVAILABLE')))
    UNION ALL SELECT N'order_items_count',ABS(COUNT_BIG(*)-18) FROM ActualOrderItems
    UNION ALL SELECT N'order_items_complete_payload_and_order_vehicle_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.buyer_n,e.created_at,e.vehicle_n,e.sale_price,CONVERT(char(3),'INR') AS currency_code,CASE WHEN e.reservation_n IS NULL THEN 0 ELSE 1 END AS reservation_expected FROM ExpectedOrders AS e
          EXCEPT SELECT i.buyer_n,i.order_created_at,i.vehicle_n,i.sale_price,i.currency_code,CASE WHEN i.reservation_id IS NULL THEN 0 ELSE 1 END AS reservation_expected FROM ActualOrderItems AS i) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT i.buyer_n,i.order_created_at,i.vehicle_n,i.sale_price,i.currency_code,CASE WHEN i.reservation_id IS NULL THEN 0 ELSE 1 END AS reservation_expected FROM ActualOrderItems AS i
          EXCEPT SELECT e.buyer_n,e.created_at,e.vehicle_n,e.sale_price,CONVERT(char(3),'INR') AS currency_code,CASE WHEN e.reservation_n IS NULL THEN 0 ELSE 1 END AS reservation_expected FROM ExpectedOrders AS e) AS unexpected_rows)
    UNION ALL SELECT N'order_item_cardinality_and_reservation_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT order_id FROM ActualOrderItems GROUP BY order_id HAVING COUNT_BIG(*)<>1) AS wrong_item_counts)
       +(SELECT COUNT_BIG(*) FROM ExpectedOrders AS e
          LEFT JOIN ActualOrders AS o ON o.buyer_n=e.buyer_n AND o.created_at=e.created_at
          LEFT JOIN ActualOrderItems AS i ON i.order_id=o.order_id
          LEFT JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',e.buyer_n),4))
          LEFT JOIN marketplace.VehicleListing AS l ON l.vehicle_id=e.source_vehicle_id AND l.listed_at=e.expected_listing_at
          LEFT JOIN marketplace.VehicleReservation AS r ON r.listing_id=l.listing_id AND r.customer_id=buyer.customer_id
             AND r.created_at=DATEADD(day,40,e.expected_listing_at)
          WHERE (e.reservation_n IS NULL AND i.reservation_id IS NOT NULL)
             OR (e.reservation_n IS NOT NULL AND (r.reservation_id IS NULL OR i.reservation_id IS NULL OR i.reservation_id<>r.reservation_id
                 OR r.status IS NULL OR r.status<>'CONVERTED' OR r.expires_at<>DATEADD(day,3,r.created_at)
                 OR r.released_at IS NULL OR r.released_at<>DATEADD(minute,10,r.created_at)
                 OR r.customer_id<>buyer.customer_id OR l.vehicle_id<>i.vehicle_id)))
    UNION ALL SELECT N'payments_count',ABS(COUNT_BIG(*)-26) FROM ActualPayments
    UNION ALL SELECT N'payments_complete_payload_and_order_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.provider_reference,e.buyer_n,e.order_created_at,e.status,e.amount,CONVERT(char(3),'INR') AS currency_code,e.payment_method_code,e.initiated_at,e.settled_at,'D3_SYNTHETIC' AS provider_code FROM ExpectedPayments AS e
          EXCEPT SELECT a.provider_reference,a.buyer_n,a.order_created_at,a.status,a.amount,a.currency_code,a.payment_method_code,a.initiated_at,a.settled_at,a.provider_code FROM ActualPayments AS a) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT a.provider_reference,a.buyer_n,a.order_created_at,a.status,a.amount,a.currency_code,a.payment_method_code,a.initiated_at,a.settled_at,a.provider_code FROM ActualPayments AS a
          EXCEPT SELECT e.provider_reference,e.buyer_n,e.order_created_at,e.status,e.amount,CONVERT(char(3),'INR') AS currency_code,e.payment_method_code,e.initiated_at,e.settled_at,'D3_SYNTHETIC' AS provider_code FROM ExpectedPayments AS e) AS unexpected_rows)
    UNION ALL SELECT N'payment_provider_reference_uniqueness',COUNT_BIG(*) FROM
        (SELECT provider_code,provider_reference FROM ActualPayments GROUP BY provider_code,provider_reference HAVING COUNT_BIG(*)>1) AS duplicates
    UNION ALL SELECT N'payment_temporal_and_currency_rules',COUNT_BIG(*) FROM ActualPayments AS p
        LEFT JOIN sales.SalesOrder AS o ON o.order_id=p.order_id
        WHERE p.provider_code<>'D3_SYNTHETIC' OR p.currency_code<>'INR'
           OR p.initiated_at IS NULL OR p.order_created_at IS NULL OR p.initiated_at<p.order_created_at
           OR (p.settled_at IS NOT NULL AND p.settled_at<p.initiated_at)
           OR (p.status IN ('SUCCEEDED','REVERSED') AND p.settled_at IS NULL)
           OR (p.status IN ('PENDING','FAILED') AND p.settled_at IS NOT NULL)
           OR o.currency_code IS NULL OR o.currency_code<>p.currency_code
    UNION ALL SELECT N'refunds_count',ABS(COUNT_BIG(*)-5) FROM ActualRefunds
    UNION ALL SELECT N'refunds_complete_payload_and_payment_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.provider_reference,e.expected_payment_reference,e.amount,e.status,e.requested_at,e.settled_at,CONVERT(char(3),'INR') AS currency_code FROM ExpectedRefunds AS e
          EXCEPT SELECT a.provider_reference,a.payment_reference,a.amount,a.status,a.requested_at,a.settled_at,a.currency_code FROM ActualRefunds AS a) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT a.provider_reference,a.payment_reference,a.amount,a.status,a.requested_at,a.settled_at,a.currency_code FROM ActualRefunds AS a
          EXCEPT SELECT e.provider_reference,e.expected_payment_reference,e.amount,e.status,e.requested_at,e.settled_at,CONVERT(char(3),'INR') AS currency_code FROM ExpectedRefunds AS e) AS unexpected_rows)
    UNION ALL SELECT N'refund_reference_uniqueness',COUNT_BIG(*) FROM
        (SELECT provider_reference FROM ActualRefunds GROUP BY provider_reference HAVING COUNT_BIG(*)>1) AS duplicates
    UNION ALL SELECT N'refund_payment_time_and_amount_rules',COUNT_BIG(*) FROM ActualRefunds AS r
        WHERE r.payment_id IS NULL OR r.payment_status IS NULL OR r.payment_status<>'SUCCEEDED'
           OR r.payment_settled_at IS NULL OR r.requested_at IS NULL OR r.requested_at<r.payment_settled_at
           OR (r.settled_at IS NOT NULL AND r.settled_at<r.requested_at)
           OR (r.status='SUCCEEDED' AND (r.settled_at IS NULL OR r.settled_at<r.requested_at))
           OR (r.status IN ('PENDING','FAILED','CANCELLED') AND r.settled_at IS NOT NULL)
           OR r.amount>r.payment_amount OR r.currency_code<>'INR'
    UNION ALL SELECT N'successful_refunds_within_successful_payment_capture',COUNT_BIG(*)
    FROM (SELECT p.payment_id,p.amount,SUM(r.amount) AS refunded
          FROM ActualPayments AS p JOIN finance.Refund AS r ON r.payment_id=p.payment_id
          WHERE p.status='SUCCEEDED' AND r.status='SUCCEEDED'
          GROUP BY p.payment_id,p.amount HAVING SUM(r.amount)>p.amount) AS over_refunds
    UNION ALL SELECT N'transfers_count',ABS(COUNT_BIG(*)-12) FROM ActualTransfers
    UNION ALL SELECT N'transfers_complete_payload_and_order_item_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.authority_reference,e.order_created_at,e.vehicle_n,e.buyer_n,e.from_customer_name,e.to_customer_name,e.status,e.submitted_at,e.completed_at FROM ExpectedTransfers AS e
          EXCEPT SELECT a.authority_reference,a.order_created_at,a.vehicle_n,a.buyer_n,a.from_customer_name,a.to_customer_name,a.status,a.submitted_at,a.completed_at FROM ActualTransfers AS a) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT a.authority_reference,a.order_created_at,a.vehicle_n,a.buyer_n,a.from_customer_name,a.to_customer_name,a.status,a.submitted_at,a.completed_at FROM ActualTransfers AS a
          EXCEPT SELECT e.authority_reference,e.order_created_at,e.vehicle_n,e.buyer_n,e.from_customer_name,e.to_customer_name,e.status,e.submitted_at,e.completed_at FROM ExpectedTransfers AS e) AS unexpected_rows)
    UNION ALL SELECT N'transfer_reference_and_order_item_uniqueness',
        (SELECT COUNT_BIG(*) FROM (SELECT authority_reference FROM ActualTransfers GROUP BY authority_reference HAVING COUNT_BIG(*)>1) AS duplicate_refs)
       +(SELECT COUNT_BIG(*) FROM (SELECT order_item_id FROM ActualTransfers GROUP BY order_item_id HAVING COUNT_BIG(*)>1) AS duplicate_items)
    UNION ALL SELECT N'transfer_party_and_lifecycle_rules',COUNT_BIG(*) FROM ActualTransfers AS t
        WHERE t.order_item_id IS NULL OR t.from_customer_name IS NULL OR t.to_customer_name IS NULL
           OR t.from_customer_name=t.to_customer_name OR t.submitted_at IS NULL OR t.order_created_at IS NULL
           OR t.submitted_at<t.order_created_at OR (t.status='COMPLETED' AND (t.completed_at IS NULL OR t.completed_at<t.submitted_at))
           OR (t.status<>'COMPLETED' AND t.completed_at IS NOT NULL)
    UNION ALL SELECT N'deliveries_count',ABS(COUNT_BIG(*)-12) FROM ActualDeliveries
    UNION ALL SELECT N'deliveries_complete_payload_and_order_item_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.handover_reference,e.order_created_at,e.vehicle_n,e.buyer_n,e.recipient_name,e.status,e.scheduled_at,e.completed_at,e.expected_branch_code,e.expected_address_line1 FROM ExpectedDeliveries AS e
          EXCEPT SELECT a.handover_reference,a.order_created_at,a.vehicle_n,a.buyer_n,a.recipient_name,a.status,a.scheduled_at,a.completed_at,a.branch_code,a.address_line1 FROM ActualDeliveries AS a) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT a.handover_reference,a.order_created_at,a.vehicle_n,a.buyer_n,a.recipient_name,a.status,a.scheduled_at,a.completed_at,a.branch_code,a.address_line1 FROM ActualDeliveries AS a
          EXCEPT SELECT e.handover_reference,e.order_created_at,e.vehicle_n,e.buyer_n,e.recipient_name,e.status,e.scheduled_at,e.completed_at,e.expected_branch_code,e.expected_address_line1 FROM ExpectedDeliveries AS e) AS unexpected_rows)
    UNION ALL SELECT N'delivery_reference_and_order_item_uniqueness',
        (SELECT COUNT_BIG(*) FROM (SELECT handover_reference FROM ActualDeliveries GROUP BY handover_reference HAVING COUNT_BIG(*)>1) AS duplicate_refs)
       +(SELECT COUNT_BIG(*) FROM (SELECT order_item_id FROM ActualDeliveries GROUP BY order_item_id HAVING COUNT_BIG(*)>1) AS duplicate_items)
    UNION ALL SELECT N'delivery_recipient_address_and_lifecycle_relationships',COUNT_BIG(*) FROM ActualDeliveries AS d
        WHERE d.order_item_id IS NULL OR d.recipient_customer_id IS NULL OR d.address_customer_id IS NULL
           OR d.recipient_name IS NULL OR d.recipient_name<>CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',d.buyer_n),4))
           OR d.buyer_customer_id IS NULL OR d.address_customer_id<>d.buyer_customer_id
           OR d.recipient_customer_id<>d.buyer_customer_id
           OR d.branch_id IS NULL OR d.delivery_address_id IS NULL OR d.scheduled_at IS NULL
           OR (d.status='COMPLETED' AND (d.completed_at IS NULL OR d.completed_at<d.scheduled_at))
           OR (d.status<>'COMPLETED' AND d.completed_at IS NOT NULL)
           OR d.order_created_at IS NULL OR d.scheduled_at<d.order_created_at
    UNION ALL SELECT N'sale_history_count',ABS(COUNT_BIG(*)-8) FROM ActualSaleHistory
    UNION ALL SELECT N'sale_history_payload_and_completed_sale_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.vehicle_n,e.buyer_n,e.valid_from,'SALE' AS basis_code,e.evidence_reference,CONVERT(datetime2(0),NULL) AS valid_to FROM ExpectedSaleHistory AS e
          EXCEPT SELECT a.vehicle_n,TRY_CONVERT(int,RIGHT(a.owner_name,4)) AS buyer_n,a.valid_from,a.basis_code,a.evidence_reference,a.valid_to FROM ActualSaleHistory AS a) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT a.vehicle_n,TRY_CONVERT(int,RIGHT(a.owner_name,4)) AS buyer_n,a.valid_from,a.basis_code,a.evidence_reference,a.valid_to FROM ActualSaleHistory AS a
          EXCEPT SELECT e.vehicle_n,e.buyer_n,e.valid_from,'SALE' AS basis_code,e.evidence_reference,CONVERT(datetime2(0),NULL) AS valid_to FROM ExpectedSaleHistory AS e) AS unexpected_rows)
    UNION ALL SELECT N'sale_history_vehicle_key_uniqueness',COUNT_BIG(*) FROM
        (SELECT vehicle_id,valid_from FROM ActualSaleHistory GROUP BY vehicle_id,valid_from HAVING COUNT_BIG(*)>1) AS duplicates
    UNION ALL SELECT N'completed_owner_and_prior_owner_history',COUNT_BIG(*)
    FROM ExpectedSaleHistory AS e
    JOIN vehicle.Vehicle AS v ON v.vehicle_id=e.vehicle_id
    LEFT JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',e.buyer_n),4))
    WHERE v.current_owner_customer_id IS NULL OR v.current_owner_customer_id<>buyer.customer_id
       OR NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory AS current_history
                     WHERE current_history.vehicle_id=v.vehicle_id AND current_history.customer_id=buyer.customer_id
                       AND current_history.valid_from=e.valid_from AND current_history.valid_to IS NULL)
       OR NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory AS prior_history
                     WHERE prior_history.vehicle_id=v.vehicle_id
                       AND prior_history.customer_id=e.expected_seller_customer_id
                       AND prior_history.valid_to=e.valid_from)
    UNION ALL SELECT N'dispatch_movements_count',ABS(COUNT_BIG(*)-8) FROM ActualDispatches
    UNION ALL SELECT N'dispatch_payload_and_inventory_sale_relationship',
        (SELECT COUNT_BIG(*) FROM (SELECT e.vehicle_n,e.occurred_at,e.expected_from_branch_code,e.expected_from_location_code,e.expected_to_branch_code,e.expected_to_location_code,e.expected_employee_code,e.reason FROM ExpectedDispatches AS e
          EXCEPT SELECT a.vehicle_n,a.occurred_at,a.from_branch_code,a.from_location_code,a.to_branch_code,a.to_location_code,a.employee_code,a.reason FROM ActualDispatches AS a) AS missing_rows)
       +(SELECT COUNT_BIG(*) FROM (SELECT a.vehicle_n,a.occurred_at,a.from_branch_code,a.from_location_code,a.to_branch_code,a.to_location_code,a.employee_code,a.reason FROM ActualDispatches AS a
          EXCEPT SELECT e.vehicle_n,e.occurred_at,e.expected_from_branch_code,e.expected_from_location_code,e.expected_to_branch_code,e.expected_to_location_code,e.expected_employee_code,e.reason FROM ExpectedDispatches AS e) AS unexpected_rows)
    UNION ALL SELECT N'dispatch_event_key_uniqueness',COUNT_BIG(*) FROM
        (SELECT inventory_id,occurred_at FROM ActualDispatches GROUP BY inventory_id,occurred_at HAVING COUNT_BIG(*)>1) AS duplicates
    UNION ALL SELECT N'completed_order_successful_payment_reconciliation',
        (SELECT COUNT_BIG(*)
         FROM
         (
             SELECT e.order_n
             FROM ExpectedOrders AS e
             LEFT JOIN ActualOrders AS o ON o.buyer_n=e.buyer_n AND o.created_at=e.created_at
             LEFT JOIN ActualOrderItems AS i ON i.order_id=o.order_id
             LEFT JOIN finance.Payment AS p ON p.order_id=o.order_id AND p.status='SUCCEEDED'
             WHERE e.order_n<=8
             GROUP BY e.order_n,e.sale_price
             HAVING COALESCE(SUM(p.amount),0)<>e.sale_price
         ) AS failing_orders)
    UNION ALL SELECT N'transfer_delivery_same_order_item',COUNT_BIG(*)
    FROM ExpectedOrders AS e
    JOIN ActualOrders AS o ON o.buyer_n=e.buyer_n AND o.created_at=e.created_at
    JOIN ActualOrderItems AS i ON i.order_id=o.order_id
    LEFT JOIN ActualTransfers AS t ON t.order_item_id=i.order_item_id AND t.authority_reference=CONCAT('D3-TR-',RIGHT(CONCAT('0000',e.order_n),4))
    LEFT JOIN ActualDeliveries AS d ON d.order_item_id=i.order_item_id AND d.handover_reference=CONCAT('D3-HAND-',RIGHT(CONCAT('0000',e.order_n),4))
    WHERE e.order_n<=12 AND (t.transfer_id IS NULL OR d.delivery_id IS NULL OR t.order_item_id<>d.order_item_id)
),
Summary AS
(
    SELECT COUNT_BIG(*) AS total_checks,
           SUM(CONVERT(bigint,CASE WHEN failure_count=0 THEN 1 ELSE 0 END)) AS passed_checks,
           SUM(CONVERT(bigint,CASE WHEN failure_count<>0 THEN 1 ELSE 0 END)) AS failed_checks
    FROM CheckResults
),
OutputRows AS
(
    SELECT CONVERT(int,0) AS sort_order,c.check_name,c.failure_count,
           CASE WHEN c.failure_count=0 THEN 'PASS' ELSE 'FAIL' END AS check_result,
           s.total_checks,s.passed_checks,s.failed_checks,
           CASE WHEN s.failed_checks=0 THEN 'PASS' ELSE 'FAIL' END AS overall_result
    FROM CheckResults AS c CROSS JOIN Summary AS s
    UNION ALL
    SELECT CONVERT(int,1),N'SUMMARY',s.failed_checks,
           CASE WHEN s.failed_checks=0 THEN 'PASS' ELSE 'FAIL' END,
           s.total_checks,s.passed_checks,s.failed_checks,
           CASE WHEN s.failed_checks=0 THEN 'PASS' ELSE 'FAIL' END
    FROM Summary AS s
)
SELECT check_name,failure_count,check_result,total_checks,passed_checks,failed_checks,overall_result
FROM OutputRows
ORDER BY sort_order,check_name
OPTION (MAXRECURSION 100);
