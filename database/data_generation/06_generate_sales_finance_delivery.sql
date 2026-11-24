/* Day 3 Phase 06. Sales, payment/refund attempts, title and delivery events. */
USE [CARS24DataModelingSystem];
GO
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>N'CARS24DataModelingSystem' THROW 51500,'Wrong database. Phase 06 stopped.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @lockResult int;
 EXEC @lockResult=sys.sp_getapplock @Resource=N'CARS24-Day3-Generation',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=0,@DbPrincipal=N'public';
 IF @lockResult<0 THROW 51509,'Could not obtain exclusive Day 3 generation lock.',1;
IF (SELECT COUNT_BIG(*) FROM sys.schemas WHERE name IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>10
 OR (SELECT COUNT_BIG(*) FROM sys.tables WHERE schema_id IN (SELECT schema_id FROM sys.schemas WHERE name IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery')))<>34
 OR (SELECT COUNT_BIG(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id WHERE k.type='PK' AND SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>34
 OR (SELECT COUNT_BIG(*) FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id WHERE SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>62
 OR (SELECT COUNT_BIG(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id WHERE k.type='UQ' AND SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>19
 OR (SELECT COUNT_BIG(*) FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id WHERE SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>79
 OR (SELECT COUNT_BIG(*) FROM sys.default_constraints d JOIN sys.tables t ON t.object_id=d.parent_object_id WHERE SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>8
 OR EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)
 OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
 OR EXISTS (SELECT 1 FROM sys.indexes WHERE index_id>0 AND is_disabled=1)
    THROW 51990,'Day 2 schema or constraint prerequisites failed. No generation phase may continue.',1;
IF (SELECT COUNT_BIG(*) FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND r.status='CONVERTED')<>6
    THROW 51502,'Phase 05 converted reservation cohort is incomplete. Phase 06 stopped.',1;

DECLARE @Orders TABLE
(
 n int PRIMARY KEY,vehicle_n int,buyer_n int,reservation_n int NULL,created_at datetime2(0),status varchar(20),
 confirmed_at datetime2(0) NULL,completed_at datetime2(0) NULL,cancelled_at datetime2(0) NULL,sale_price decimal(19,4)
);
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<18),
base AS
(
 SELECT n, n+10 AS vehicle_n,
        CASE WHEN n<=6 THEN 89+n WHEN n<=10 THEN 40+n ELSE 43+n END AS buyer_n,
        CASE WHEN n<=6 THEN n+7 ELSE NULL END AS reservation_n,
        CASE WHEN n<=8 THEN 'COMPLETED' WHEN n IN (9,10,11,12,16,17) THEN 'CONFIRMED' WHEN n=13 THEN 'DRAFT' ELSE 'CANCELLED' END AS status
 FROM n
)
INSERT INTO @Orders
SELECT b.n,b.vehicle_n,b.buyer_n,b.reservation_n,
       CASE WHEN b.n<=6 THEN DATEADD(minute,15,r.created_at) ELSE DATEADD(day,45,l.listed_at) END,
       b.status,
       CASE WHEN b.status IN ('CONFIRMED','COMPLETED') THEN CASE WHEN b.n<=6 THEN DATEADD(minute,15,r.created_at) ELSE DATEADD(day,45,l.listed_at) END END,
       CASE WHEN b.status='COMPLETED' THEN DATEADD(day,5,CASE WHEN b.n<=6 THEN DATEADD(minute,15,r.created_at) ELSE DATEADD(day,45,l.listed_at) END) END,
       CASE WHEN b.status='CANCELLED' THEN DATEADD(day,1,CASE WHEN b.n<=6 THEN DATEADD(minute,15,r.created_at) ELSE DATEADD(day,45,l.listed_at) END) END,
       CONVERT(decimal(19,4),(500000+(b.vehicle_n%20)*25000)*1.03*0.985)
FROM base b JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',b.vehicle_n),12))
JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=DATEADD(day,5,inv.since_at)
LEFT JOIN marketplace.VehicleReservation r ON b.reservation_n IS NOT NULL AND r.listing_id=l.listing_id AND r.created_at=DATEADD(day,40,l.listed_at) AND r.status='CONVERTED'
WHERE b.n>6 OR r.reservation_id IS NOT NULL
OPTION(MAXRECURSION 100);
IF (SELECT COUNT_BIG(*) FROM @Orders)<>18 THROW 51503,'The deterministic order cohort could not be resolved uniquely.',1;
IF NOT
(
    ((SELECT COUNT_BIG(*) FROM marketplace.VehicleListing AS l JOIN vehicle.Vehicle AS v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.status='ACTIVE')=18
     AND (SELECT COUNT_BIG(*) FROM marketplace.VehicleListing AS l JOIN vehicle.Vehicle AS v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.status='SOLD')=0)
    OR
    ((SELECT COUNT_BIG(*) FROM marketplace.VehicleListing AS l JOIN vehicle.Vehicle AS v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.status='ACTIVE')=10
     AND (SELECT COUNT_BIG(*) FROM marketplace.VehicleListing AS l JOIN vehicle.Vehicle AS v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.status='SOLD')=8)
)
    THROW 51501,'Phase 05 listing cohort is neither at its pre-sale nor fully completed-sale state. Phase 06 stopped.',1;
IF (SELECT COUNT_BIG(*) FROM marketplace.VehicleListing AS l JOIN vehicle.Vehicle AS v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.status='ACTIVE') NOT IN (10,18)
    THROW 51537,'The Day 3 active listing count is not a valid Phase 06 precondition.',1;

DECLARE @Payments TABLE(n int PRIMARY KEY,order_n int,status varchar(20),amount decimal(19,4),initiated_at datetime2(0),settled_at datetime2(0) NULL,provider_reference varchar(100));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<26),
mapping AS
(
 SELECT n,CASE WHEN n<=10 THEN (n+1)/2 WHEN n<=13 THEN n-5 WHEN n=14 OR n=15 THEN 9 WHEN n=16 THEN 10 WHEN n=17 THEN 11 WHEN n=18 THEN 12 WHEN n IN (19,20) THEN 13 WHEN n=21 THEN 14 WHEN n=22 THEN 15 WHEN n=23 THEN 16 WHEN n IN (24,25) THEN 17 ELSE 18 END AS order_n
 FROM n
)
INSERT INTO @Payments
SELECT m.n,m.order_n,
       CASE WHEN m.n<=13 THEN 'SUCCEEDED' WHEN m.n IN (14,16,17,19,23,25) THEN 'PENDING' WHEN m.n=22 THEN 'REVERSED' ELSE 'FAILED' END,
       CASE WHEN m.n<=10 THEN o.sale_price/2 WHEN m.n<=13 THEN o.sale_price ELSE CONVERT(decimal(19,4),10000+m.n*500) END,
       DATEADD(minute,m.n*5,DATEADD(hour,1,o.created_at)),
       CASE WHEN m.n<=13 OR m.n=22 THEN DATEADD(minute,5,DATEADD(minute,m.n*5,DATEADD(hour,1,o.created_at))) END,
       CONCAT('D3-PAY-',RIGHT(CONCAT('0000',m.n),4))
FROM mapping m JOIN @Orders o ON o.n=m.order_n OPTION(MAXRECURSION 100);

DECLARE @Refunds TABLE(n int PRIMARY KEY,payment_n int,amount decimal(19,4),status varchar(20),requested_at datetime2(0),settled_at datetime2(0) NULL,provider_reference varchar(100));
;WITH RefundPlan(n,payment_n,amount,status,days_after_settlement) AS
(
    SELECT refund_plan.n,refund_plan.payment_n,refund_plan.amount,refund_plan.status,refund_plan.days_after_settlement
    FROM (VALUES
        (1,1,CONVERT(decimal(19,4),2500),'SUCCEEDED',1),
        (2,2,CONVERT(decimal(19,4),5000),'SUCCEEDED',2),
        (3,3,CONVERT(decimal(19,4),2000),'PENDING',3),
        (4,4,CONVERT(decimal(19,4),3000),'FAILED',4),
        (5,13,CONVERT(decimal(19,4),1500),'SUCCEEDED',5)
    ) AS refund_plan(n,payment_n,amount,status,days_after_settlement)
)
INSERT INTO @Refunds(n,payment_n,amount,status,requested_at,settled_at,provider_reference)
SELECT refund_plan.n,refund_plan.payment_n,refund_plan.amount,refund_plan.status,
       DATEADD(day,refund_plan.days_after_settlement,p.settled_at),
       CASE WHEN refund_plan.status='SUCCEEDED' THEN DATEADD(minute,5,DATEADD(day,refund_plan.days_after_settlement,p.settled_at)) END,
       CONCAT('D3-REF-',RIGHT(CONCAT('0000',refund_plan.n),4))
FROM RefundPlan AS refund_plan
JOIN @Payments AS p ON p.n=refund_plan.payment_n;

/* Verify every existing event key against the complete intended payload. */
IF EXISTS(SELECT 1 FROM @Orders x JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder o ON o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at WHERE o.status<>x.status OR o.currency_code<>'INR' OR ISNULL(o.confirmed_at,'9999-12-31')<>ISNULL(x.confirmed_at,'9999-12-31') OR ISNULL(o.completed_at,'9999-12-31')<>ISNULL(x.completed_at,'9999-12-31') OR ISNULL(o.cancelled_at,'9999-12-31')<>ISNULL(x.cancelled_at,'9999-12-31'))
    THROW 51504,'Sales order natural-key payload conflict. Phase 06 stopped.',1;
IF EXISTS(SELECT c.customer_id,o.created_at FROM sales.SalesOrder o JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE o.created_at>='2026-02-01' AND c.display_name LIKE N'D3 Synthetic Customer %' GROUP BY c.customer_id,o.created_at HAVING COUNT_BIG(*)>1)
    THROW 51505,'Ambiguous Day 3 sales order event key. Phase 06 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at
 JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 LEFT JOIN marketplace.VehicleListing expectedListing ON expectedListing.vehicle_id=v.vehicle_id AND expectedListing.listed_at=DATEADD(day,5,inv.since_at)
 LEFT JOIN marketplace.VehicleReservation expectedR ON x.reservation_n IS NOT NULL AND expectedR.listing_id=expectedListing.listing_id AND expectedR.customer_id=buyer.customer_id AND expectedR.created_at=DATEADD(day,40,expectedListing.listed_at)
 WHERE i.vehicle_id<>v.vehicle_id OR i.sale_price<>x.sale_price OR i.currency_code<>'INR'
    OR ISNULL(i.reservation_id,-1)<>ISNULL(expectedR.reservation_id,-1)
) THROW 51506,'Sales order item natural-key payload conflict. Phase 06 stopped.',1;
IF EXISTS(SELECT 1 FROM @Payments p JOIN @Orders o ON o.n=p.order_n JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',o.buyer_n),4)) JOIN sales.SalesOrder so ON so.buyer_customer_id=c.customer_id AND so.created_at=o.created_at JOIN finance.Payment x ON x.provider_code='D3_SYNTHETIC' AND x.provider_reference=p.provider_reference WHERE x.order_id<>so.order_id OR x.amount<>p.amount OR x.currency_code<>'INR' OR x.status<>p.status OR x.payment_method_code<>CASE WHEN p.n%2=0 THEN 'CARD' ELSE 'UPI' END OR x.initiated_at<>p.initiated_at OR ISNULL(x.settled_at,'9999-12-31')<>ISNULL(p.settled_at,'9999-12-31'))
    THROW 51507,'Payment provider-reference payload conflict. Phase 06 stopped.',1;
IF EXISTS(SELECT 1 FROM @Refunds r JOIN @Payments p ON p.n=r.payment_n JOIN finance.Payment pay ON pay.provider_code='D3_SYNTHETIC' AND pay.provider_reference=p.provider_reference JOIN finance.Refund x ON x.provider_reference=r.provider_reference WHERE x.payment_id<>pay.payment_id OR x.amount<>r.amount OR x.currency_code<>'INR' OR x.status<>r.status OR x.requested_at<>r.requested_at OR ISNULL(x.settled_at,'9999-12-31')<>ISNULL(r.settled_at,'9999-12-31'))
    THROW 51508,'Refund provider-reference payload conflict. Phase 06 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN core.Customer seller ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.vehicle_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN delivery.OwnershipTransfer t ON t.authority_reference=CONCAT('D3-TR-',RIGHT(CONCAT('0000',x.n),4))
 WHERE x.n<=12 AND (t.order_item_id<>i.order_item_id OR t.from_customer_id<>seller.customer_id OR t.to_customer_id<>buyer.customer_id
    OR t.status<>CASE WHEN x.n<=8 THEN 'COMPLETED' WHEN x.n<=10 THEN 'IN_PROGRESS' WHEN x.n=11 THEN 'SUBMITTED' ELSE 'REJECTED' END
    OR t.submitted_at IS NULL OR t.submitted_at<>DATEADD(day,1,x.created_at)
    OR ISNULL(t.completed_at,'9999-12-31')<>ISNULL(CASE WHEN x.n<=8 THEN DATEADD(day,3,x.created_at) END,'9999-12-31'))
) THROW 51518,'Ownership-transfer event payload conflict. Phase 06 stopped.',1;
IF EXISTS(SELECT authority_reference FROM delivery.OwnershipTransfer WHERE authority_reference LIKE 'D3-TR-%' GROUP BY authority_reference HAVING COUNT_BIG(*)>1)
    THROW 51519,'Ambiguous Day 3 transfer reference. Phase 06 stopped.',1;
IF EXISTS
(
    SELECT 1
    FROM @Orders AS x
    JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
    JOIN sales.SalesOrder AS o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at
    JOIN sales.SalesOrderItem AS i ON i.order_id=o.order_id
    JOIN delivery.OwnershipTransfer AS t ON t.order_item_id=i.order_item_id
    WHERE x.n<=12 AND (t.authority_reference IS NULL OR t.authority_reference<>CONCAT('D3-TR-',RIGHT(CONCAT('0000',x.n),4)))
)
    THROW 51535,'An order item already has a conflicting ownership-transfer event.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN delivery.VehicleDelivery d ON d.handover_reference=CONCAT('D3-HAND-',RIGHT(CONCAT('0000',x.n),4))
 JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.CustomerAddress a ON a.customer_id=buyer.customer_id AND a.address_line1=CONCAT(N'D3 Synthetic Address ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 WHERE x.n<=12 AND (d.order_item_id<>i.order_item_id OR d.recipient_customer_id<>buyer.customer_id
    OR d.branch_id IS NULL OR d.branch_id<>inv.branch_id
    OR d.delivery_address_id IS NULL OR d.delivery_address_id<>a.address_id
    OR d.scheduled_at IS NULL OR d.scheduled_at<>DATEADD(day,4,x.created_at)
    OR ISNULL(d.completed_at,'9999-12-31')<>ISNULL(CASE WHEN x.n<=8 THEN DATEADD(hour,1,DATEADD(day,4,x.created_at)) END,'9999-12-31')
    OR d.status<>CASE WHEN x.n<=8 THEN 'COMPLETED' WHEN x.n<=10 THEN 'SCHEDULED' WHEN x.n=11 THEN 'IN_TRANSIT' ELSE 'FAILED' END)
) THROW 51520,'Vehicle-delivery event payload conflict. Phase 06 stopped.',1;
IF EXISTS(SELECT handover_reference FROM delivery.VehicleDelivery WHERE handover_reference LIKE 'D3-HAND-%' GROUP BY handover_reference HAVING COUNT_BIG(*)>1)
    THROW 51521,'Ambiguous Day 3 delivery reference. Phase 06 stopped.',1;
IF EXISTS
(
    SELECT 1
    FROM @Orders AS x
    JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
    JOIN sales.SalesOrder AS o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at
    JOIN sales.SalesOrderItem AS i ON i.order_id=o.order_id
    JOIN delivery.VehicleDelivery AS d ON d.order_item_id=i.order_item_id
    WHERE x.n<=12 AND (d.handover_reference IS NULL OR d.handover_reference<>CONCAT('D3-HAND-',RIGHT(CONCAT('0000',x.n),4)))
)
    THROW 51536,'An order item already has a conflicting vehicle-delivery event.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN delivery.OwnershipTransfer t ON t.order_item_id=i.order_item_id AND t.status='COMPLETED' JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id
 JOIN core.Customer seller ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.vehicle_n),4))
 JOIN vehicle.VehicleOwnershipHistory old ON old.vehicle_id=v.vehicle_id AND old.customer_id=seller.customer_id
 WHERE x.n<=8 AND old.valid_to IS NOT NULL AND old.valid_to<>t.completed_at
) THROW 51522,'Prior ownership interval has a conflicting end time. Phase 06 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN delivery.OwnershipTransfer t ON t.order_item_id=i.order_item_id AND t.status='COMPLETED' JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=i.vehicle_id AND h.valid_from=t.completed_at
 WHERE x.n<=8 AND (h.customer_id<>buyer.customer_id OR h.valid_to IS NOT NULL OR h.basis_code<>'SALE' OR h.evidence_reference<>t.authority_reference)
) THROW 51523,'Ownership-history sale event payload conflict. Phase 06 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN core.Customer seller ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.vehicle_n),4))
 JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
  WHERE x.n<=8 AND (v.current_owner_customer_id NOT IN (seller.customer_id,buyer.customer_id) OR v.lifecycle_status NOT IN ('LISTED','SOLD') OR inv.status NOT IN ('AVAILABLE','SOLD'))
) THROW 51525,'Completed-sale source state conflicts with the planned Day 3 cohort. Phase 06 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN core.Customer seller ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.vehicle_n),4))
 JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 WHERE x.n<=8 AND NOT
  ((v.lifecycle_status='LISTED' AND v.current_owner_customer_id=seller.customer_id AND inv.status='AVAILABLE'
    AND EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=seller.customer_id AND h.valid_to IS NULL))
  OR (v.lifecycle_status='SOLD' AND v.current_owner_customer_id=buyer.customer_id AND inv.status='SOLD'
    AND EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=buyer.customer_id AND h.valid_to IS NULL)))
) THROW 51534,'Completed-sale vehicle/inventory/owner state is not an allowed exact state.',1;
IF EXISTS
(
 SELECT 1 FROM @Orders x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id JOIN delivery.OwnershipTransfer t ON t.completed_at=DATEADD(day,3,x.created_at) AND t.status='COMPLETED'
 JOIN core.Employee actor ON actor.employee_code='D3-EMP-0011'
 JOIN inventory.InventoryMovement m ON m.inventory_id=inv.inventory_id AND m.occurred_at=t.completed_at
 WHERE x.n<=8 AND (m.movement_type<>'DISPATCH' OR m.from_branch_id<>inv.branch_id OR m.from_location_code<>inv.location_code
    OR m.to_branch_id IS NOT NULL OR m.to_location_code IS NOT NULL OR m.employee_id<>actor.employee_id OR m.reason<>N'Day 3 synthetic completed-sale dispatch')
) THROW 51526,'Inventory dispatch event payload conflict. Phase 06 stopped.',1;
IF EXISTS(SELECT m.inventory_id,m.occurred_at FROM inventory.InventoryMovement m JOIN inventory.Inventory inv ON inv.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND m.movement_type='DISPATCH' GROUP BY m.inventory_id,m.occurred_at HAVING COUNT_BIG(*)>1)
    THROW 51527,'Ambiguous Day 3 dispatch event key. Phase 06 stopped.',1;

 /* The package lock and transaction were acquired before mutable prechecks. */
 DECLARE @ordersInserted int=0,@itemsInserted int=0,@paymentsInserted int=0,@refundsInserted int=0,@transfersInserted int=0,@deliveriesInserted int=0,@dispatchesInserted int=0,@saleHistoryInserted int=0,@listingRowsAffected int=0,@vehicleRowsAffected int=0,@inventoryRowsAffected int=0,@priorOwnerRowsAffected int=0;

 INSERT INTO sales.SalesOrder(buyer_customer_id,created_at,status,currency_code,confirmed_at,completed_at,cancelled_at)
 SELECT c.customer_id,x.created_at,x.status,'INR',x.confirmed_at,x.completed_at,x.cancelled_at
 FROM @Orders x JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 WHERE NOT EXISTS(SELECT 1 FROM sales.SalesOrder z WITH(UPDLOCK,HOLDLOCK) WHERE z.buyer_customer_id=c.customer_id AND z.created_at=x.created_at);
 SET @ordersInserted=@@ROWCOUNT;

 INSERT INTO sales.SalesOrderItem(order_id,vehicle_id,reservation_id,sale_price,currency_code)
 SELECT o.order_id,v.vehicle_id,r.reservation_id,x.sale_price,'INR'
 FROM @Orders x JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at
 JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 LEFT JOIN marketplace.VehicleListing listing ON listing.vehicle_id=v.vehicle_id AND listing.listed_at=DATEADD(day,5,inv.since_at)
 LEFT JOIN marketplace.VehicleReservation r ON x.reservation_n IS NOT NULL AND r.listing_id=listing.listing_id AND r.customer_id=c.customer_id AND r.created_at=DATEADD(day,40,listing.listed_at)
 WHERE NOT EXISTS(SELECT 1 FROM sales.SalesOrderItem z WITH(UPDLOCK,HOLDLOCK) WHERE z.order_id=o.order_id);
 SET @itemsInserted=@@ROWCOUNT;

 INSERT INTO finance.Payment(order_id,provider_code,provider_reference,payment_method_code,amount,currency_code,status,initiated_at,settled_at)
 SELECT o.order_id,'D3_SYNTHETIC',p.provider_reference,CASE WHEN p.n%2=0 THEN 'CARD' ELSE 'UPI' END,p.amount,'INR',p.status,p.initiated_at,p.settled_at
 FROM @Payments p JOIN @Orders x ON x.n=p.order_n JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at
 WHERE NOT EXISTS(SELECT 1 FROM finance.Payment z WITH(UPDLOCK,HOLDLOCK) WHERE z.provider_code='D3_SYNTHETIC' AND z.provider_reference=p.provider_reference);
 SET @paymentsInserted=@@ROWCOUNT;

 INSERT INTO finance.Refund(payment_id,provider_reference,amount,currency_code,status,requested_at,settled_at)
 SELECT p.payment_id,r.provider_reference,r.amount,'INR',r.status,r.requested_at,r.settled_at
 FROM @Refunds r JOIN @Payments ps ON ps.n=r.payment_n JOIN finance.Payment p ON p.provider_code='D3_SYNTHETIC' AND p.provider_reference=ps.provider_reference
 WHERE NOT EXISTS(SELECT 1 FROM finance.Refund z WITH(UPDLOCK,HOLDLOCK) WHERE z.provider_reference=r.provider_reference);
 SET @refundsInserted=@@ROWCOUNT;

 INSERT INTO delivery.OwnershipTransfer(order_item_id,from_customer_id,to_customer_id,status,submitted_at,completed_at,authority_reference)
 SELECT i.order_item_id,seller.customer_id,buyer.customer_id,
         CASE WHEN x.n<=8 THEN 'COMPLETED' WHEN x.n<=10 THEN 'IN_PROGRESS' WHEN x.n=11 THEN 'SUBMITTED' ELSE 'REJECTED' END,
        DATEADD(day,1,x.created_at),CASE WHEN x.n<=8 THEN DATEADD(day,3,x.created_at) END,CONCAT('D3-TR-',RIGHT(CONCAT('0000',x.n),4))
 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN core.Customer seller ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.vehicle_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at
 JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
  WHERE x.n<=12 AND NOT EXISTS(SELECT 1 FROM delivery.OwnershipTransfer z WITH(UPDLOCK,HOLDLOCK) WHERE z.authority_reference=CONCAT('D3-TR-',RIGHT(CONCAT('0000',x.n),4)));
 SET @transfersInserted=@@ROWCOUNT;

 INSERT INTO delivery.VehicleDelivery(order_item_id,recipient_customer_id,branch_id,delivery_address_id,scheduled_at,completed_at,status,handover_reference)
 SELECT i.order_item_id,buyer.customer_id,inv.branch_id,a.address_id,DATEADD(day,4,x.created_at),
         CASE WHEN x.n<=8 THEN DATEADD(hour,1,DATEADD(day,4,x.created_at)) END,
         CASE WHEN x.n<=8 THEN 'COMPLETED' WHEN x.n<=10 THEN 'SCHEDULED' WHEN x.n=11 THEN 'IN_TRANSIT' ELSE 'FAILED' END,
         CONCAT('D3-HAND-',RIGHT(CONCAT('0000',x.n),4))
 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.CustomerAddress a ON a.customer_id=buyer.customer_id AND a.address_line1=CONCAT(N'D3 Synthetic Address ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
  WHERE x.n<=12 AND NOT EXISTS(SELECT 1 FROM delivery.VehicleDelivery z WITH(UPDLOCK,HOLDLOCK) WHERE z.handover_reference=CONCAT('D3-HAND-',RIGHT(CONCAT('0000',x.n),4)));
 SET @deliveriesInserted=@@ROWCOUNT;

 /* A completed sale transfers customer ownership in the modeled history. The
    model has no company-owner entity, so company custody remains unrepresented. */
 INSERT INTO vehicle.VehicleOwnershipHistory(vehicle_id,customer_id,valid_from,basis_code,evidence_reference)
 SELECT v.vehicle_id,buyer.customer_id,t.completed_at,'SALE',t.authority_reference
 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN delivery.OwnershipTransfer t ON t.order_item_id=i.order_item_id AND t.status='COMPLETED'
 WHERE x.n<=8 AND NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WITH(UPDLOCK,HOLDLOCK) WHERE h.vehicle_id=v.vehicle_id AND h.valid_from=t.completed_at);
 SET @saleHistoryInserted=@@ROWCOUNT;

 UPDATE prior SET valid_to=t.completed_at
 FROM vehicle.VehicleOwnershipHistory prior JOIN vehicle.Vehicle v ON v.vehicle_id=prior.vehicle_id JOIN @Orders x ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN core.Customer seller ON seller.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.vehicle_n),4))
 JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 JOIN delivery.OwnershipTransfer t ON t.order_item_id=i.order_item_id AND t.status='COMPLETED'
 WHERE x.n<=8 AND prior.customer_id=seller.customer_id AND prior.valid_to IS NULL;
 SET @priorOwnerRowsAffected=@@ROWCOUNT;
  IF @priorOwnerRowsAffected NOT IN (0,8) THROW 51528,'Expected either eight prior owner rows to close or an exact completed rerun.',1;

 UPDATE v SET current_owner_customer_id=buyer.customer_id,lifecycle_status='SOLD'
 FROM vehicle.Vehicle v JOIN @Orders x ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
 JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
 WHERE x.n<=8;
 SET @vehicleRowsAffected=@@ROWCOUNT;
 IF @vehicleRowsAffected<>8 THROW 51529,'Expected exactly eight vehicle owner/status rows to update.',1;

 UPDATE inv SET status='SOLD'
 FROM inventory.Inventory inv JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id JOIN @Orders x ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) WHERE x.n<=8;
 SET @inventoryRowsAffected=@@ROWCOUNT;
 IF @inventoryRowsAffected<>8 THROW 51530,'Expected exactly eight inventory rows to update.',1;
 /* Only the exact active listing sold by each completed order may transition.
    This one-to-one precondition also rejects ambiguous listing/order context. */
  IF (SELECT COUNT_BIG(*) FROM @Orders x
     JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4))
     JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at
     JOIN sales.SalesOrderItem i ON i.order_id=o.order_id
     JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) AND i.vehicle_id=v.vehicle_id
     JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
      JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=DATEADD(day,5,inv.since_at)
     LEFT JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id
      WHERE x.n<=8 AND l.branch_id=inv.branch_id
        AND ((l.status='ACTIVE' AND l.closed_at IS NULL) OR (l.status='SOLD' AND l.closed_at=o.completed_at))
        AND ((x.reservation_n IS NULL AND i.reservation_id IS NULL)
             OR (i.reservation_id=r.reservation_id AND r.listing_id=l.listing_id AND r.customer_id=buyer.customer_id)))<>8
      THROW 51531,'Each completed order must resolve to exactly one eligible active or already-sold listing.',1;
 UPDATE l SET status='SOLD',closed_at=o.completed_at
 FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id JOIN @Orders x ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder o ON o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at
 JOIN sales.SalesOrderItem i ON i.order_id=o.order_id AND i.vehicle_id=v.vehicle_id
 WHERE x.n<=8 AND l.listed_at=DATEADD(day,5,inv.since_at) AND l.status='ACTIVE';
 SET @listingRowsAffected=@@ROWCOUNT;
  IF @listingRowsAffected NOT IN (0,8) THROW 51532,'Expected either eight active listing rows to transition or an exact completed rerun.',1;
  IF EXISTS(SELECT 1 FROM @Orders AS x JOIN vehicle.Vehicle AS v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) JOIN inventory.Inventory AS inv ON inv.vehicle_id=v.vehicle_id JOIN marketplace.VehicleListing AS l ON l.vehicle_id=v.vehicle_id AND l.listed_at=DATEADD(day,5,inv.since_at) JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder AS o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at WHERE x.n<=8 AND (l.status<>'SOLD' OR l.closed_at IS NULL OR l.closed_at<>o.completed_at))
     THROW 51533,'Sold listing postcondition failed.',1;

 INSERT INTO inventory.InventoryMovement(inventory_id,from_branch_id,from_location_code,movement_type,employee_id,occurred_at,reason)
 SELECT inv.inventory_id,inv.branch_id,inv.location_code,'DISPATCH',staff.employee_id,t.completed_at,N'Day 3 synthetic completed-sale dispatch'
 FROM @Orders x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Employee staff ON staff.employee_code='D3-EMP-0011' JOIN sales.SalesOrder o ON o.completed_at=DATEADD(day,5,x.created_at)
 JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) AND o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at
 JOIN sales.SalesOrderItem i ON i.order_id=o.order_id JOIN delivery.OwnershipTransfer t ON t.order_item_id=i.order_item_id AND t.status='COMPLETED'
 WHERE x.n<=8 AND NOT EXISTS(SELECT 1 FROM inventory.InventoryMovement z WITH(UPDLOCK,HOLDLOCK) WHERE z.inventory_id=inv.inventory_id AND z.occurred_at=t.completed_at);
 SET @dispatchesInserted=@@ROWCOUNT;

  IF (SELECT COUNT_BIG(*) FROM @Orders AS x JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder AS o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at)<>18
      THROW 51538,'Exact Phase 06 sales-order postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM @Orders AS x JOIN core.Customer AS buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder AS o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem AS i ON i.order_id=o.order_id)<>18
      THROW 51539,'Exact Phase 06 order-item postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM finance.Payment AS p WHERE p.provider_code='D3_SYNTHETIC' AND p.provider_reference LIKE 'D3-PAY-%')<>26
      THROW 51540,'Exact Phase 06 payment postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM finance.Refund AS r WHERE r.provider_reference LIKE 'D3-REF-%')<>5
      THROW 51541,'Exact Phase 06 refund postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer AS t WHERE t.authority_reference LIKE 'D3-TR-%')<>12
      THROW 51542,'Exact Phase 06 ownership-transfer postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM delivery.VehicleDelivery AS d WHERE d.handover_reference LIKE 'D3-HAND-%')<>12
      THROW 51543,'Exact Phase 06 vehicle-delivery postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM vehicle.VehicleOwnershipHistory AS h JOIN vehicle.Vehicle AS v ON v.vehicle_id=h.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND h.basis_code='SALE' AND h.evidence_reference LIKE 'D3-TR-%')<>8
      THROW 51544,'Exact Phase 06 sale-history postcondition failed.',1;
  IF (SELECT COUNT_BIG(*) FROM inventory.InventoryMovement AS m JOIN inventory.Inventory AS inv ON inv.inventory_id=m.inventory_id JOIN vehicle.Vehicle AS v ON v.vehicle_id=inv.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND m.movement_type='DISPATCH' AND m.reason=N'Day 3 synthetic completed-sale dispatch')<>8
      THROW 51545,'Exact Phase 06 dispatch-movement postcondition failed.',1;

 IF EXISTS(SELECT 1 FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id WHERE o.buyer_customer_id<>r.customer_id OR v.vehicle_id<>l.vehicle_id)
    THROW 51510,'Order buyer, item, reservation and listing do not match.',1;
 IF EXISTS(SELECT 1 FROM @Orders x JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder o ON o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at LEFT JOIN sales.SalesOrderItem i ON i.order_id=o.order_id GROUP BY x.n,o.order_id HAVING COUNT(i.order_item_id)<>1)
    THROW 51511,'One-item-per-order validation failed.',1;
 IF EXISTS(SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id LEFT JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=DATEADD(day,5,inv.since_at) LEFT JOIN marketplace.VehicleReservation r ON r.listing_id=l.listing_id AND r.customer_id=buyer.customer_id AND r.created_at=DATEADD(day,40,l.listed_at) WHERE x.n<=6 AND (r.reservation_id IS NULL OR i.reservation_id<>r.reservation_id))
    THROW 51517,'Converted reservation does not match order buyer, listing, and vehicle.',1;
 IF EXISTS(SELECT 1 FROM @Orders x JOIN sales.SalesOrder o ON o.created_at=x.created_at JOIN core.Customer c ON c.customer_id=o.buyer_customer_id JOIN sales.SalesOrderItem i ON i.order_id=o.order_id JOIN finance.Payment p ON p.order_id=o.order_id WHERE p.currency_code<>o.currency_code OR i.currency_code<>o.currency_code)
    THROW 51512,'Order, item and payment currency mismatch.',1;
 IF EXISTS(SELECT p.payment_id FROM finance.Payment p JOIN finance.Refund r ON r.payment_id=p.payment_id WHERE r.status='SUCCEEDED' GROUP BY p.payment_id,p.amount HAVING SUM(r.amount)>p.amount)
    THROW 51513,'Successful refunds exceed their payment amount.',1;
 IF EXISTS(SELECT 1 FROM @Orders x JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder o ON o.buyer_customer_id=c.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id LEFT JOIN finance.Payment p ON p.order_id=o.order_id AND p.status='SUCCEEDED' WHERE x.n<=8 GROUP BY o.order_id,i.sale_price HAVING COALESCE(SUM(p.amount),0)<>i.sale_price)
    THROW 51514,'Completed-order successful payment total does not reconcile.',1;
 IF EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=v.vehicle_id AND h.valid_to IS NULL WHERE v.vin LIKE 'D3SYN%' AND h.customer_id<>v.current_owner_customer_id)
    THROW 51515,'Current owner does not match active ownership history.',1;
 IF EXISTS(SELECT 1 FROM @Orders x JOIN core.Customer buyer ON buyer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.buyer_n),4)) JOIN sales.SalesOrder o ON o.buyer_customer_id=buyer.customer_id AND o.created_at=x.created_at JOIN sales.SalesOrderItem i ON i.order_id=o.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE x.n<=8 AND (v.current_owner_customer_id<>buyer.customer_id OR v.lifecycle_status<>'SOLD' OR NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=buyer.customer_id AND h.valid_from=DATEADD(day,-2,o.completed_at) AND h.valid_to IS NULL)))
    THROW 51524,'Completed-sale owner projection validation failed.',1;
 IF EXISTS(SELECT v.vehicle_id FROM vehicle.Vehicle v JOIN sales.SalesOrderItem i ON i.vehicle_id=v.vehicle_id JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE o.status='COMPLETED' GROUP BY v.vehicle_id HAVING COUNT_BIG(*)>1)
    THROW 51516,'Duplicate completed sale detected for a vehicle.',1;

  COMMIT TRANSACTION;
 SELECT N'06 Sales, finance and delivery' AS phase_name,DB_NAME() AS target_database,N'COMMITTED' AS status,
        18 AS expected_orders,@ordersInserted AS orders_inserted,18-@ordersInserted AS orders_exact_match_skipped,
        18 AS expected_order_items,@itemsInserted AS items_inserted,18-@itemsInserted AS order_items_exact_match_skipped,
        26 AS expected_payments,@paymentsInserted AS payments_inserted,26-@paymentsInserted AS payments_exact_match_skipped,
        5 AS expected_refunds,@refundsInserted AS refunds_inserted,5-@refundsInserted AS refunds_exact_match_skipped,
        12 AS expected_transfers,@transfersInserted AS transfers_inserted,12-@transfersInserted AS transfers_exact_match_skipped,
        12 AS expected_deliveries,@deliveriesInserted AS deliveries_inserted,12-@deliveriesInserted AS deliveries_exact_match_skipped,
        8 AS expected_sale_history_rows,@saleHistoryInserted AS sale_history_rows_inserted,8-@saleHistoryInserted AS sale_history_exact_match_skipped,
        8 AS expected_dispatch_movements,@dispatchesInserted AS dispatches_inserted,8-@dispatchesInserted AS dispatch_exact_match_skipped,
        N'PASS' AS validation_result,N'Phase 10 final validation permitted after reviewing all counts and zero conflicts.' AS next_phase;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SELECT N'06 Sales, finance and delivery' AS phase_name,DB_NAME() AS target_database,N'ROLLED_BACK' AS status,ERROR_NUMBER() AS error_number,ERROR_MESSAGE() AS error_detail,N'No subsequent phase is permitted.' AS next_phase;
 THROW;
END CATCH;
GO
