/* Day 3 Phase 04. Offers, agreements, acquisitions and inventory ledger. */
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
IF DB_NAME()<>N'CARS24DataModelingSystem' THROW 51300,'Wrong database. Phase 04 stopped.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @lockResult int;
 EXEC @lockResult=sys.sp_getapplock @Resource=N'CARS24-Day3-Generation',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=0,@DbPrincipal=N'public';
 IF @lockResult<0 THROW 51309,'Could not obtain exclusive Day 3 generation lock.',1;
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
IF (SELECT COUNT_BIG(*) FROM inspection.VehicleValuation val JOIN vehicle.Vehicle v ON v.vehicle_id=val.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>52
    THROW 51301,'Phase 03 valuation cohort is incomplete. Phase 04 stopped.',1;
IF EXISTS(SELECT 1 FROM vehicle.Vehicle WHERE vin LIKE 'D3SYN%' AND lifecycle_status NOT IN ('SUBMITTED','IN_STOCK'))
    THROW 51302,'Day 3 vehicle status conflict exists. Phase 04 stopped.',1;
/* A prior phase execution is atomic: its cohort must be wholly absent or
   complete. Reject manually partial or mixed event families before writes. */
IF (SELECT COUNT_BIG(*) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%') NOT IN (0,49)
 OR (SELECT COUNT_BIG(*) FROM acquisition.PurchaseAgreement a JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%') NOT IN (0,34)
 OR (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%') NOT IN (0,31)
 OR (SELECT COUNT_BIG(*) FROM inventory.Inventory i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%') NOT IN (0,31)
 OR (SELECT COUNT_BIG(*) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%') NOT IN (0,54)
 OR ((SELECT COUNT_BIG(*) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')=0 AND ((SELECT COUNT_BIG(*) FROM acquisition.PurchaseAgreement a JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>0 OR (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>0 OR (SELECT COUNT_BIG(*) FROM inventory.Inventory i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>0 OR (SELECT COUNT_BIG(*) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>0))
 OR ((SELECT COUNT_BIG(*) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')=49 AND ((SELECT COUNT_BIG(*) FROM acquisition.PurchaseAgreement a JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>34 OR (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>31 OR (SELECT COUNT_BIG(*) FROM inventory.Inventory i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>31 OR (SELECT COUNT_BIG(*) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>54))
    THROW 51323,'Phase 04 cohort is partial or inconsistent; reconcile before retry.',1;
IF EXISTS
(
 SELECT 1 FROM vehicle.Vehicle v JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id
 WHERE v.vin LIKE 'D3SYN%' AND
 ((NOT EXISTS(SELECT 1 FROM acquisition.VehicleAcquisition ac WHERE ac.vehicle_id=v.vehicle_id)
   AND (v.lifecycle_status<>'SUBMITTED' OR s.status<>'SUBMITTED' OR s.closed_at IS NOT NULL))
  OR (EXISTS(SELECT 1 FROM acquisition.VehicleAcquisition ac WHERE ac.vehicle_id=v.vehicle_id)
   AND (v.lifecycle_status<>'IN_STOCK' OR s.status<>'ACCEPTED' OR s.closed_at IS NULL)))
) THROW 51324,'Vehicle/submission lifecycle does not match the complete Phase 04 initial-or-complete state.',1;

DECLARE @O TABLE(n int PRIMARY KEY,vin varchar(30),offered_at datetime2(0),expires_at datetime2(0),amount decimal(19,4),status varchar(20),decision_at datetime2(0) NULL);
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<49)
INSERT INTO @O
SELECT n,CONCAT('D3SYN',RIGHT(CONCAT('000000000000',n),12)),
       DATEADD(hour,12,DATEADD(day,1,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))),
       DATEADD(day,7,DATEADD(hour,12,DATEADD(day,1,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00'))))),
       CONVERT(decimal(19,4),(500000+(n%20)*25000)*0.88),
       CASE WHEN n<=34 THEN 'ACCEPTED' WHEN n<=40 THEN 'DECLINED' WHEN n<=45 THEN 'EXPIRED' ELSE 'ISSUED' END,
       CASE WHEN n<=34 THEN DATEADD(hour,3,DATEADD(hour,12,DATEADD(day,1,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))))
            WHEN n<=40 THEN DATEADD(hour,2,DATEADD(hour,12,DATEADD(day,1,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))))
            WHEN n<=45 THEN DATEADD(hour,1,DATEADD(day,7,DATEADD(hour,12,DATEADD(day,1,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))))) ELSE NULL END
FROM n OPTION(MAXRECURSION 100);

DECLARE @A TABLE(n int PRIMARY KEY,agreement_reference varchar(40) UNIQUE,status varchar(20),signed_at datetime2(0));
INSERT INTO @A SELECT n,CONCAT('D3-AGR-',RIGHT(CONCAT('0000',n),4)),CASE WHEN n<=31 THEN 'SIGNED' WHEN n=32 THEN 'VOID' ELSE 'CANCELLED' END,DATEADD(day,2,o.offered_at) FROM @O o WHERE n<=34;

/* Reject changed or multiply-matched stable event keys. */
IF EXISTS
(
 SELECT 1 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN core.Customer c ON c.customer_id=s.seller_customer_id JOIN inspection.VehicleValuation val ON val.vehicle_id=v.vehicle_id AND val.valued_at=DATEADD(day,1,DATEADD(hour,9,DATEADD(day,3+x.n,CONVERT(datetime2(0),'2026-02-01T00:00:00'))))
 JOIN acquisition.PurchaseOffer o ON o.submission_id=s.submission_id AND o.offered_at=x.offered_at
 WHERE o.valuation_id<>val.valuation_id OR o.seller_customer_id<>s.seller_customer_id OR o.amount<>x.amount OR o.currency_code<>'INR'
    OR o.expires_at<>x.expires_at OR o.status<>x.status OR ISNULL(o.decision_at,'9999-12-31')<>ISNULL(x.decision_at,'9999-12-31')
) THROW 51303,'Purchase offer natural-key payload conflict. Phase 04 stopped.',1;
IF EXISTS(SELECT o.submission_id,o.offered_at FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%' GROUP BY o.submission_id,o.offered_at HAVING COUNT_BIG(*)>1)
    THROW 51304,'Ambiguous Day 3 purchase offer event key. Phase 04 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @A x JOIN acquisition.PurchaseAgreement a ON a.agreement_reference=x.agreement_reference
 JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id
 JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id
 WHERE a.status<>x.status OR a.signed_at<>x.signed_at OR o.offered_at<>DATEADD(day,-2,x.signed_at) OR a.seller_customer_id<>s.seller_customer_id
) THROW 51305,'Purchase agreement key/payload conflict. Phase 04 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @O o JOIN vehicle.Vehicle v ON v.vin=o.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN acquisition.PurchaseOffer offer ON offer.submission_id=s.submission_id AND offer.offered_at=o.offered_at
 JOIN @A a ON a.n=o.n JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference
 WHERE o.n<=34 AND ag.offer_id<>offer.offer_id
) THROW 51306,'Agreement is linked to a different offer. Phase 04 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @O o JOIN vehicle.Vehicle v ON v.vin=o.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN acquisition.PurchaseOffer offer ON offer.submission_id=s.submission_id AND offer.offered_at=o.offered_at
 JOIN @A a ON a.n=o.n JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference
 JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=ag.agreement_id
 WHERE o.n<=31 AND (ac.vehicle_id<>v.vehicle_id OR ac.seller_customer_id<>s.seller_customer_id OR ac.amount<>o.amount OR ac.currency_code<>'INR' OR ac.acquired_at<>DATEADD(hour,2,ag.signed_at))
) THROW 51307,'Acquisition natural-key payload conflict. Phase 04 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @O o JOIN vehicle.Vehicle v ON v.vin=o.vin JOIN acquisition.PurchaseOffer offer ON offer.offered_at=o.offered_at
 JOIN vehicle.VehicleSubmission s ON s.submission_id=offer.submission_id AND s.vehicle_id=v.vehicle_id
 JOIN @A a ON a.n=o.n JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference
 JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=ag.agreement_id
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Branch initialBranch ON initialBranch.branch_code=CASE (o.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 LEFT JOIN core.Branch finalBranch ON finalBranch.branch_code=CASE (o.n+1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 WHERE o.n<=31 AND (inv.since_at<>DATEADD(minute,10,ac.acquired_at) OR inv.status<>'AVAILABLE'
    OR NOT ((inv.branch_id=initialBranch.branch_id AND inv.location_code='D3-YARD-A')
         OR (o.n<=23 AND inv.branch_id=finalBranch.branch_id AND inv.location_code='D3-YARD-B')))
) THROW 51308,'Inventory payload conflict. Phase 04 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Branch initialBranch ON initialBranch.branch_code=CASE (x.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 JOIN core.Employee staff ON staff.employee_code='D3-EMP-0011'
 JOIN inventory.InventoryMovement m ON m.inventory_id=inv.inventory_id AND m.occurred_at=inv.since_at
 WHERE x.n<=31 AND (m.movement_type<>'RECEIPT' OR m.from_branch_id IS NOT NULL OR m.from_location_code IS NOT NULL
    OR m.to_branch_id<>initialBranch.branch_id OR m.to_location_code<>'D3-YARD-A' OR m.employee_id<>staff.employee_id OR m.reason<>N'Day 3 synthetic acquisition receipt')
) THROW 51312,'Inventory receipt event payload conflict. Phase 04 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Branch initialBranch ON initialBranch.branch_code=CASE (x.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 JOIN core.Branch dest ON dest.branch_code=CASE (x.n+1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 JOIN core.Employee staff ON staff.employee_code='D3-EMP-0011'
 JOIN inventory.InventoryMovement m ON m.inventory_id=inv.inventory_id AND m.occurred_at=DATEADD(day,2,inv.since_at)
 WHERE x.n<=23 AND (m.movement_type<>'TRANSFER' OR m.from_branch_id<>initialBranch.branch_id OR m.from_location_code<>'D3-YARD-A'
    OR m.to_branch_id<>dest.branch_id OR m.to_location_code<>'D3-YARD-B' OR m.employee_id<>staff.employee_id OR m.reason<>N'Day 3 synthetic inter-branch transfer')
) THROW 51313,'Inventory transfer event payload conflict. Phase 04 stopped.',1;

 /* The package lock and transaction were acquired before mutable prechecks. */
 DECLARE @offersInserted int=0,@agreementsInserted int=0,@acquisitionsInserted int=0,@inventoryInserted int=0,@movementInserted int=0;

 INSERT INTO acquisition.PurchaseOffer(submission_id,valuation_id,seller_customer_id,offered_at,expires_at,amount,currency_code,status,decision_at)
 SELECT s.submission_id,val.valuation_id,s.seller_customer_id,x.offered_at,x.expires_at,x.amount,'INR',x.status,x.decision_at
 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN inspection.VehicleValuation val ON val.vehicle_id=v.vehicle_id AND val.valued_at=DATEADD(day,1,DATEADD(hour,9,DATEADD(day,3+x.n,CONVERT(datetime2(0),'2026-02-01T00:00:00'))))
 WHERE NOT EXISTS(SELECT 1 FROM acquisition.PurchaseOffer z WITH(UPDLOCK,HOLDLOCK) WHERE z.submission_id=s.submission_id AND z.offered_at=x.offered_at);
 SET @offersInserted=@@ROWCOUNT;

 INSERT INTO acquisition.PurchaseAgreement(offer_id,seller_customer_id,agreement_reference,signed_at,status)
 SELECT o.offer_id,s.seller_customer_id,a.agreement_reference,a.signed_at,a.status
 FROM @A a JOIN @O x ON x.n=a.n JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN acquisition.PurchaseOffer o ON o.submission_id=s.submission_id AND o.offered_at=x.offered_at
 WHERE NOT EXISTS(SELECT 1 FROM acquisition.PurchaseAgreement z WITH(UPDLOCK,HOLDLOCK) WHERE z.agreement_reference=a.agreement_reference);
 SET @agreementsInserted=@@ROWCOUNT;

 INSERT INTO acquisition.VehicleAcquisition(agreement_id,vehicle_id,seller_customer_id,acquired_at,amount,currency_code)
 SELECT a.agreement_id,v.vehicle_id,s.seller_customer_id,DATEADD(hour,2,a.signed_at),x.amount,'INR'
 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN @A sa ON sa.n=x.n JOIN acquisition.PurchaseAgreement a ON a.agreement_reference=sa.agreement_reference
 WHERE x.n<=31 AND NOT EXISTS(SELECT 1 FROM acquisition.VehicleAcquisition z WITH(UPDLOCK,HOLDLOCK) WHERE z.agreement_id=a.agreement_id);
 SET @acquisitionsInserted=@@ROWCOUNT;

 INSERT INTO inventory.Inventory(vehicle_id,branch_id,location_code,status,since_at)
 SELECT v.vehicle_id,initialBranch.branch_id,'D3-YARD-A','AVAILABLE',DATEADD(minute,10,ac.acquired_at)
 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN @A sa ON sa.n=x.n
 JOIN acquisition.PurchaseAgreement a ON a.agreement_reference=sa.agreement_reference JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=a.agreement_id
 JOIN core.Branch initialBranch ON initialBranch.branch_code=CASE (x.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 WHERE x.n<=31 AND NOT EXISTS(SELECT 1 FROM inventory.Inventory z WITH(UPDLOCK,HOLDLOCK) WHERE z.vehicle_id=v.vehicle_id);
 SET @inventoryInserted=@@ROWCOUNT;

 INSERT INTO inventory.InventoryMovement(inventory_id,to_branch_id,to_location_code,movement_type,employee_id,occurred_at,reason)
 SELECT inv.inventory_id,initialBranch.branch_id,'D3-YARD-A','RECEIPT',staff.employee_id,inv.since_at,N'Day 3 synthetic acquisition receipt'
 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Branch initialBranch ON initialBranch.branch_code=CASE (x.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 JOIN core.Employee staff ON staff.employee_code='D3-EMP-0011'
 WHERE x.n<=31 AND NOT EXISTS(SELECT 1 FROM inventory.InventoryMovement z WITH(UPDLOCK,HOLDLOCK) WHERE z.inventory_id=inv.inventory_id AND z.occurred_at=inv.since_at);
 SET @movementInserted=@@ROWCOUNT;

 INSERT INTO inventory.InventoryMovement(inventory_id,from_branch_id,from_location_code,to_branch_id,to_location_code,movement_type,employee_id,occurred_at,reason)
 SELECT inv.inventory_id,initialBranch.branch_id,'D3-YARD-A',dest.branch_id,'D3-YARD-B','TRANSFER',staff.employee_id,DATEADD(day,2,inv.since_at),N'Day 3 synthetic inter-branch transfer'
 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 JOIN core.Branch initialBranch ON initialBranch.branch_code=CASE (x.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 JOIN core.Branch dest ON dest.branch_code=CASE (x.n+1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 JOIN core.Employee staff ON staff.employee_code='D3-EMP-0011'
 WHERE x.n<=23 AND dest.branch_id<>inv.branch_id
   AND NOT EXISTS(SELECT 1 FROM inventory.InventoryMovement z WITH(UPDLOCK,HOLDLOCK) WHERE z.inventory_id=inv.inventory_id AND z.occurred_at=DATEADD(day,2,inv.since_at));
 SET @movementInserted=@movementInserted+@@ROWCOUNT;

 UPDATE inv SET branch_id=dest.branch_id,location_code='D3-YARD-B'
 FROM inventory.Inventory inv JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id
 JOIN @O x ON x.vin=v.vin
 JOIN core.Branch dest ON dest.branch_code=CASE (x.n+1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 WHERE x.n<=23 AND inv.location_code='D3-YARD-A';
 IF @@ROWCOUNT NOT IN (0,23) THROW 51315,'Unexpected inventory-position update cardinality.',1;

 UPDATE v SET lifecycle_status='IN_STOCK'
 FROM vehicle.Vehicle v JOIN @O x ON x.vin=v.vin JOIN @A a ON a.n=x.n JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference
 JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=ag.agreement_id WHERE x.n<=31 AND v.lifecycle_status='SUBMITTED';
 IF @@ROWCOUNT NOT IN (0,31) THROW 51316,'Unexpected vehicle lifecycle update cardinality.',1;
 UPDATE s SET status='ACCEPTED',closed_at=ac.acquired_at
 FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id JOIN @O x ON x.vin=v.vin JOIN @A a ON a.n=x.n
 JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=ag.agreement_id
 WHERE x.n<=31 AND s.submitted_at=DATEADD(hour,1,v.created_at) AND s.status='SUBMITTED';
 IF @@ROWCOUNT NOT IN (0,31) THROW 51317,'Unexpected submission lifecycle update cardinality.',1;

 IF EXISTS(SELECT 1 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN @A a ON a.n=x.n JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=ag.agreement_id WHERE x.n<=31 AND (v.lifecycle_status<>'IN_STOCK' OR NOT EXISTS(SELECT 1 FROM inventory.Inventory i WHERE i.vehicle_id=v.vehicle_id)))
    THROW 51310,'Post-insert acquisition/inventory validation failed.',1;
 IF EXISTS(SELECT 1 FROM @O x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at) JOIN @A a ON a.n=x.n JOIN acquisition.PurchaseAgreement ag ON ag.agreement_reference=a.agreement_reference JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=ag.agreement_id WHERE x.n<=31 AND (s.status<>'ACCEPTED' OR s.closed_at<>ac.acquired_at))
    THROW 51314,'Post-insert submission acceptance validation failed.',1;
 IF EXISTS(SELECT 1 FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id WHERE m.movement_type='TRANSFER' AND (m.from_branch_id IS NULL OR m.to_branch_id IS NULL OR m.from_branch_id=m.to_branch_id))
    THROW 51311,'Post-insert inventory movement validation failed.',1;
 IF (SELECT COUNT_BIG(*) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>49
    THROW 51318,'Exact Day 3 offer cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM acquisition.PurchaseAgreement a JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>34
    THROW 51319,'Exact Day 3 agreement cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>31
    THROW 51320,'Exact Day 3 acquisition cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM inventory.Inventory i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>31
    THROW 51321,'Exact Day 3 inventory cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>54
    THROW 51322,'Exact Day 3 movement cohort count failed.',1;

 COMMIT TRANSACTION;
 SELECT N'04 Acquisition and inventory' AS phase_name,DB_NAME() AS target_database,N'COMMITTED' AS status,
        49 AS expected_offers,@offersInserted AS offers_inserted,49-@offersInserted AS exact_match_skipped,
        34 AS expected_agreements,@agreementsInserted AS agreements_inserted,34-@agreementsInserted AS exact_match_skipped,
        31 AS expected_acquisitions,@acquisitionsInserted AS acquisitions_inserted,31-@acquisitionsInserted AS exact_match_skipped,
        31 AS expected_inventory_positions,@inventoryInserted AS inventory_inserted,31-@inventoryInserted AS exact_match_skipped,
        54 AS expected_movement_rows,@movementInserted AS movement_rows_inserted,54-@movementInserted AS exact_match_skipped,
        N'PASS' AS validation_result,N'Phase 05 permitted after reviewing counts and zero conflicts.' AS next_phase;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SELECT N'04 Acquisition and inventory' AS phase_name,DB_NAME() AS target_database,N'ROLLED_BACK' AS status,ERROR_NUMBER() AS error_number,ERROR_MESSAGE() AS error_detail,N'No subsequent phase is permitted.' AS next_phase;
 THROW;
END CATCH;
GO
