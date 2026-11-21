/* Day 3 Phase 05. Listings, synthetic media references, enquiries and holds. */
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
IF DB_NAME()<>N'CARS24DataModelingSystem' THROW 51400,'Wrong database. Phase 05 stopped.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @lockResult int;
 EXEC @lockResult=sys.sp_getapplock @Resource=N'CARS24-Day3-Generation',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=0,@DbPrincipal=N'public';
 IF @lockResult<0 THROW 51406,'Could not obtain exclusive Day 3 generation lock.',1;
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
IF (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>31
    THROW 51401,'Phase 04 acquisition cohort is incomplete. Phase 05 stopped.',1;

DECLARE @L TABLE(n int PRIMARY KEY,vehicle_n int,listed_at datetime2(0),closed_at datetime2(0) NULL,status varchar(20),asking_price decimal(19,4));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<34)
INSERT INTO @L
SELECT n,CASE WHEN n<=31 THEN n ELSE n-31 END,
       DATEADD(day,CASE WHEN n<=31 THEN 5 ELSE 20 END,inv.since_at),
       CASE WHEN n BETWEEN 4 AND 18 OR n BETWEEN 19 AND 21 OR n BETWEEN 32 AND 34 THEN NULL ELSE DATEADD(day,60,DATEADD(day,CASE WHEN n<=31 THEN 5 ELSE 20 END,inv.since_at)) END,
       CASE WHEN n BETWEEN 4 AND 18 OR n BETWEEN 32 AND 34 THEN 'ACTIVE'
            WHEN n BETWEEN 19 AND 21 THEN 'PAUSED' WHEN n BETWEEN 26 AND 31 THEN 'WITHDRAWN' ELSE 'CLOSED' END,
       CONVERT(decimal(19,4),(500000+(CASE WHEN n<=31 THEN n ELSE n-31 END%20)*25000)*1.03)
FROM n JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',CASE WHEN n<=31 THEN n ELSE n-31 END),12))
JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id OPTION(MAXRECURSION 100);

DECLARE @Images TABLE(listing_n int,display_order int,image_reference nvarchar(500),caption nvarchar(200),PRIMARY KEY(listing_n,display_order));
INSERT INTO @Images
SELECT l.n,o.display_order,
       CONCAT(N'https://media.example.invalid/day3/vehicle-',RIGHT(CONCAT(N'0000',l.vehicle_n),4),N'/photo-',o.display_order,N'.jpg'),
       CONCAT(N'Synthetic exterior/interior view ',o.display_order)
FROM @L l JOIN (VALUES(1),(2),(3),(4)) o(display_order) ON o.display_order<=CASE WHEN l.n<=17 THEN 4 ELSE 3 END;

DECLARE @E TABLE(n int PRIMARY KEY,listing_n int,customer_n int,received_at datetime2(0),channel varchar(20),status varchar(20),message_reference nvarchar(300));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<99)
INSERT INTO @E
SELECT n,((n-1)%33)+1,((n-1)%97)+1,
       DATEADD(hour,2,DATEADD(day,1,DATEADD(day,CASE WHEN ((n-1)%33)+1<=31 THEN 5 ELSE 20 END,
         (SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=((n-1)%33)+1)))),
       CASE n%5 WHEN 0 THEN 'WEB' WHEN 1 THEN 'PHONE' WHEN 2 THEN 'BRANCH' WHEN 3 THEN 'PARTNER' ELSE 'OTHER' END,
       CASE n%4 WHEN 0 THEN 'OPEN' WHEN 1 THEN 'IN_PROGRESS' WHEN 2 THEN 'RESOLVED' ELSE 'CLOSED' END,
       CONCAT(N'D3-ENQ-',RIGHT(CONCAT(N'0000',n),4))
FROM n OPTION(MAXRECURSION 120);

DECLARE @R TABLE(n int PRIMARY KEY,listing_n int,customer_n int,created_at datetime2(0),expires_at datetime2(0),status varchar(20),released_at datetime2(0) NULL);
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<24)
INSERT INTO @R
SELECT n,n+3,CASE WHEN n<=7 THEN 80+n WHEN n<=13 THEN 82+n ELSE 70+n END,
       CASE WHEN n<=7 THEN DATEADD(hour,n,CONVERT(datetime2(0),'2026-10-30T09:00:00'))
            WHEN n<=13 THEN DATEADD(day,40,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3)))
            ELSE DATEADD(day,5,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3))) END,
       CASE WHEN n<=7 THEN DATEADD(day,3,DATEADD(hour,n,CONVERT(datetime2(0),'2026-10-30T09:00:00')))
            WHEN n<=13 THEN DATEADD(day,3,DATEADD(day,40,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3))))
            ELSE DATEADD(day,3,DATEADD(day,5,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3)))) END,
       CASE WHEN n<=7 THEN 'ACTIVE' WHEN n<=13 THEN 'CONVERTED' WHEN n<=18 THEN 'RELEASED' ELSE 'EXPIRED' END,
       CASE WHEN n<=7 THEN NULL WHEN n<=13 THEN DATEADD(minute,10,DATEADD(day,40,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3))))
            WHEN n<=18 THEN DATEADD(day,2,DATEADD(day,5,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3))))
            ELSE DATEADD(day,3,DATEADD(day,5,DATEADD(day,5,(SELECT inv.since_at FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id WHERE l.n=n+3)))) END
FROM n OPTION(MAXRECURSION 100);

IF EXISTS(SELECT 1 FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id JOIN marketplace.VehicleListing x ON x.vehicle_id=v.vehicle_id AND x.listed_at=l.listed_at WHERE x.branch_id<>inv.branch_id OR ISNULL(x.closed_at,'9999-12-31')<>ISNULL(l.closed_at,'9999-12-31') OR x.status<>l.status OR x.asking_price<>l.asking_price OR x.currency_code<>'INR' OR ISNULL(x.description,N'')<>CONCAT(N'Day 3 synthetic listing ',RIGHT(CONCAT(N'0000',l.n),4)))
    THROW 51402,'Listing natural-key payload conflict. Phase 05 stopped.',1;
IF EXISTS(SELECT x.vehicle_id,x.listed_at FROM marketplace.VehicleListing x JOIN vehicle.Vehicle v ON v.vehicle_id=x.vehicle_id WHERE v.vin LIKE 'D3SYN%' GROUP BY x.vehicle_id,x.listed_at HAVING COUNT_BIG(*)>1)
    THROW 51410,'Ambiguous Day 3 listing event key. Phase 05 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @L expected JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',expected.vehicle_n),12))
 JOIN marketplace.VehicleListing activeRow ON activeRow.vehicle_id=v.vehicle_id AND activeRow.status='ACTIVE'
 WHERE expected.status='ACTIVE' AND activeRow.listed_at<>expected.listed_at
) THROW 51414,'Another active listing conflicts with the planned vehicle listing. Phase 05 stopped.',1;
IF EXISTS(SELECT 1 FROM @Images i JOIN @L source ON source.n=i.listing_n JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',source.vehicle_n),12)) JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=source.listed_at JOIN marketplace.ListingImage x ON x.listing_id=l.listing_id AND x.display_order=i.display_order WHERE x.image_reference<>i.image_reference OR ISNULL(x.caption,N'')<>ISNULL(i.caption,N''))
    THROW 51411,'Listing image natural-key payload conflict. Phase 05 stopped.',1;
IF EXISTS(SELECT listing_id,display_order FROM marketplace.ListingImage GROUP BY listing_id,display_order HAVING COUNT_BIG(*)>1)
    THROW 51412,'Ambiguous listing image key exists. Phase 05 stopped.',1;
IF EXISTS(SELECT 1 FROM @E e JOIN marketplace.CustomerEnquiry x ON x.message_reference=e.message_reference WHERE x.status<>e.status OR x.channel_code<>e.channel OR x.received_at<>e.received_at OR ISNULL(x.assigned_employee_id,-1)<>(SELECT employee_id FROM core.Employee WHERE employee_code='D3-EMP-0002'))
    THROW 51403,'Enquiry natural-key payload conflict. Phase 05 stopped.',1;
IF EXISTS(SELECT message_reference FROM marketplace.CustomerEnquiry WHERE message_reference LIKE N'D3-ENQ-%' GROUP BY message_reference HAVING COUNT_BIG(*)>1)
    THROW 51413,'Ambiguous Day 3 enquiry key. Phase 05 stopped.',1;
IF EXISTS(SELECT 1 FROM @R r JOIN @L l ON l.n=r.listing_n JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN marketplace.VehicleListing listing ON listing.vehicle_id=v.vehicle_id AND listing.listed_at=l.listed_at JOIN marketplace.VehicleReservation x ON x.listing_id=listing.listing_id AND x.created_at=r.created_at JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',r.customer_n),4)) WHERE x.customer_id<>c.customer_id OR x.expires_at<>r.expires_at OR x.status<>r.status OR ISNULL(x.released_at,'9999-12-31')<>ISNULL(r.released_at,'9999-12-31'))
    THROW 51404,'Reservation natural-key payload conflict. Phase 05 stopped.',1;
IF EXISTS(SELECT x.listing_id,x.created_at FROM marketplace.VehicleReservation x JOIN marketplace.VehicleListing l ON l.listing_id=x.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' GROUP BY x.listing_id,x.created_at HAVING COUNT_BIG(*)>1)
    THROW 51415,'Ambiguous Day 3 reservation event key. Phase 05 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @R expected JOIN @L source ON source.n=expected.listing_n
 JOIN vehicle.Vehicle targetVehicle ON targetVehicle.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',source.vehicle_n),12))
 JOIN marketplace.VehicleListing targetListing ON targetListing.vehicle_id=targetVehicle.vehicle_id AND targetListing.listed_at=source.listed_at
 JOIN core.Customer targetCustomer ON targetCustomer.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',expected.customer_n),4))
 JOIN marketplace.VehicleReservation existing ON existing.status='ACTIVE'
 JOIN marketplace.VehicleListing activeListing ON activeListing.listing_id=existing.listing_id
 WHERE expected.status='ACTIVE' AND activeListing.vehicle_id=targetVehicle.vehicle_id
   AND NOT (existing.listing_id=targetListing.listing_id AND existing.customer_id=targetCustomer.customer_id AND existing.created_at=expected.created_at)
)
    THROW 51405,'A vehicle already has an active hold across listing history. Phase 05 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @L x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
 JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 WHERE
   (EXISTS(SELECT 1 FROM @R er JOIN @L el ON el.n=er.listing_n WHERE er.status='ACTIVE' AND el.vehicle_n=x.vehicle_n)
      AND NOT ((inv.status='AVAILABLE' AND v.lifecycle_status='IN_STOCK') OR (inv.status='HELD' AND v.lifecycle_status='RESERVED')))
   OR (NOT EXISTS(SELECT 1 FROM @R er JOIN @L el ON el.n=er.listing_n WHERE er.status='ACTIVE' AND el.vehicle_n=x.vehicle_n)
      AND NOT ((inv.status='AVAILABLE' AND v.lifecycle_status IN ('IN_STOCK','LISTED'))))
) THROW 51423,'Marketplace source vehicle or inventory state is not an allowed expected state.',1;

 /* The package lock and transaction were acquired before mutable prechecks. */
 DECLARE @listingInserted int=0,@imageInserted int=0,@enquiryInserted int=0,@reservationInserted int=0;

 INSERT INTO marketplace.VehicleListing(vehicle_id,branch_id,listed_at,closed_at,status,asking_price,currency_code,description)
 SELECT v.vehicle_id,inv.branch_id,l.listed_at,l.closed_at,l.status,l.asking_price,'INR',CONCAT(N'Day 3 synthetic listing ',RIGHT(CONCAT(N'0000',l.n),4))
 FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
 WHERE NOT EXISTS(SELECT 1 FROM marketplace.VehicleListing x WITH(UPDLOCK,HOLDLOCK) WHERE x.vehicle_id=v.vehicle_id AND x.listed_at=l.listed_at);
 SET @listingInserted=@@ROWCOUNT;

 INSERT INTO marketplace.ListingImage(listing_id,image_reference,display_order,caption)
 SELECT l.listing_id,i.image_reference,i.display_order,i.caption
 FROM @Images i JOIN @L source ON source.n=i.listing_n JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',source.vehicle_n),12))
 JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=source.listed_at
 WHERE NOT EXISTS(SELECT 1 FROM marketplace.ListingImage x WITH(UPDLOCK,HOLDLOCK) WHERE x.listing_id=l.listing_id AND x.display_order=i.display_order);
 SET @imageInserted=@@ROWCOUNT;

 INSERT INTO marketplace.CustomerEnquiry(listing_id,customer_id,assigned_employee_id,channel_code,received_at,status,message_reference)
 SELECT l.listing_id,c.customer_id,e.employee_id,x.channel,x.received_at,x.status,x.message_reference
 FROM @E x JOIN @L source ON source.n=x.listing_n JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',source.vehicle_n),12))
 JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=source.listed_at
 JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.customer_n),4))
 JOIN core.Employee e ON e.employee_code='D3-EMP-0002'
 WHERE NOT EXISTS(SELECT 1 FROM marketplace.CustomerEnquiry z WITH(UPDLOCK,HOLDLOCK) WHERE z.message_reference=x.message_reference);
 SET @enquiryInserted=@@ROWCOUNT;

 INSERT INTO marketplace.VehicleReservation(listing_id,customer_id,created_at,expires_at,status,released_at)
 SELECT l.listing_id,c.customer_id,r.created_at,r.expires_at,r.status,r.released_at
 FROM @R r JOIN @L source ON source.n=r.listing_n JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',source.vehicle_n),12))
 JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=source.listed_at
 JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',r.customer_n),4))
 WHERE NOT EXISTS(SELECT 1 FROM marketplace.VehicleReservation z WITH(UPDLOCK,HOLDLOCK) WHERE z.listing_id=l.listing_id AND z.created_at=r.created_at);
 SET @reservationInserted=@@ROWCOUNT;

 UPDATE v SET lifecycle_status=CASE WHEN EXISTS(SELECT 1 FROM @R r JOIN @L source ON source.n=r.listing_n JOIN marketplace.VehicleListing listing ON listing.vehicle_id=v.vehicle_id AND listing.listed_at=source.listed_at JOIN marketplace.VehicleReservation hold ON hold.listing_id=listing.listing_id AND hold.created_at=r.created_at WHERE r.status='ACTIVE') THEN 'RESERVED' ELSE 'LISTED' END
 FROM vehicle.Vehicle v JOIN @L source ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',source.vehicle_n),12)) WHERE source.status='ACTIVE' AND v.lifecycle_status IN ('IN_STOCK','LISTED','RESERVED');
 IF @@ROWCOUNT NOT IN (0,18) THROW 51424,'Unexpected vehicle listing/reservation lifecycle update cardinality.',1;
 UPDATE inv SET status='HELD'
 FROM inventory.Inventory inv JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id JOIN @R r ON r.status='ACTIVE'
 JOIN @L source ON source.n=r.listing_n JOIN marketplace.VehicleListing listing ON listing.vehicle_id=v.vehicle_id AND listing.listed_at=source.listed_at
 WHERE v.vin LIKE 'D3SYN%' AND inv.status IN ('AVAILABLE','HELD');
 IF @@ROWCOUNT NOT IN (0,7) THROW 51425,'Unexpected inventory hold update cardinality.',1;
 IF EXISTS
 (
  SELECT 1 FROM @L x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
  JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
  WHERE x.status='ACTIVE' AND
    ((EXISTS(SELECT 1 FROM @R r WHERE r.status='ACTIVE' AND r.listing_n=x.n) AND (v.lifecycle_status<>'RESERVED' OR inv.status<>'HELD'))
     OR (NOT EXISTS(SELECT 1 FROM @R r WHERE r.status='ACTIVE' AND r.listing_n=x.n) AND (v.lifecycle_status<>'LISTED' OR inv.status<>'AVAILABLE')))
 ) THROW 51428,'Per-vehicle listing/reservation lifecycle postcondition failed.',1;

 IF EXISTS(SELECT v.vehicle_id FROM vehicle.Vehicle v JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id WHERE l.status='ACTIVE' AND v.vin LIKE 'D3SYN%' GROUP BY v.vehicle_id HAVING COUNT_BIG(*)>1)
    THROW 51407,'Multiple active Day 3 listings exist for one vehicle.',1;
 IF EXISTS(SELECT 1 FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE r.status='ACTIVE' AND v.vin LIKE 'D3SYN%' GROUP BY v.vehicle_id HAVING COUNT_BIG(*)>1)
    THROW 51408,'Multiple active Day 3 reservations exist across listing history.',1;
 IF EXISTS(SELECT 1 FROM @L l JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',l.vehicle_n),12)) JOIN marketplace.VehicleListing x ON x.vehicle_id=v.vehicle_id AND x.listed_at=l.listed_at WHERE x.branch_id<>(SELECT branch_id FROM inventory.Inventory WHERE vehicle_id=v.vehicle_id))
    THROW 51409,'Listing branch does not match the current inventory branch.',1;
 IF (SELECT COUNT_BIG(*) FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.description LIKE N'Day 3 synthetic listing %')<>34
    THROW 51416,'Exact Day 3 listing cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM marketplace.ListingImage i JOIN marketplace.VehicleListing l ON l.listing_id=i.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.description LIKE N'Day 3 synthetic listing %')<>119
    THROW 51417,'Exact Day 3 listing-image cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM marketplace.CustomerEnquiry WHERE message_reference LIKE N'D3-ENQ-%')<>99
    THROW 51418,'Exact Day 3 enquiry cohort count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND r.created_at>='2026-02-01')<>24
    THROW 51419,'Exact Day 3 reservation cohort count failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @Images x JOIN @L src ON src.n=x.listing_n
  JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',src.vehicle_n),12))
  JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=src.listed_at
  LEFT JOIN marketplace.ListingImage i ON i.listing_id=l.listing_id AND i.display_order=x.display_order
  WHERE i.listing_image_id IS NULL OR i.image_reference<>x.image_reference OR ISNULL(i.caption,N'')<>x.caption
 ) THROW 51420,'Complete listing-image payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @E x JOIN @L src ON src.n=x.listing_n
  JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',src.vehicle_n),12))
  JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=src.listed_at
  JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.customer_n),4))
  JOIN core.Employee e ON e.employee_code='D3-EMP-0002'
  LEFT JOIN marketplace.CustomerEnquiry q ON q.message_reference=x.message_reference
  WHERE q.enquiry_id IS NULL OR q.listing_id<>l.listing_id OR q.customer_id<>c.customer_id OR q.assigned_employee_id<>e.employee_id
     OR q.channel_code<>x.channel OR q.received_at<>x.received_at OR q.status<>x.status
 ) THROW 51421,'Complete enquiry payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @R x JOIN @L src ON src.n=x.listing_n
  JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',src.vehicle_n),12))
  JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=src.listed_at
  JOIN core.Customer c ON c.display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',x.customer_n),4))
  LEFT JOIN marketplace.VehicleReservation r ON r.listing_id=l.listing_id AND r.created_at=x.created_at
  WHERE r.reservation_id IS NULL OR r.customer_id<>c.customer_id OR r.expires_at<>x.expires_at OR r.status<>x.status
     OR ISNULL(r.released_at,'9999-12-31')<>ISNULL(x.released_at,'9999-12-31')
 ) THROW 51422,'Complete reservation payload reconciliation failed.',1;

 IF EXISTS
 (
  SELECT 1 FROM @L x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12))
  JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id
  LEFT JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=x.listed_at
  WHERE l.listing_id IS NULL OR l.branch_id<>inv.branch_id OR l.status<>x.status
    OR ISNULL(l.closed_at,'9999-12-31')<>ISNULL(x.closed_at,'9999-12-31') OR l.asking_price<>x.asking_price
    OR l.currency_code<>'INR' OR ISNULL(l.description,N'')<>CONCAT(N'Day 3 synthetic listing ',RIGHT(CONCAT(N'0000',x.n),4))
 ) THROW 51426,'Complete listing payload reconciliation failed.',1;
 IF EXISTS(SELECT 1 FROM @L x JOIN vehicle.Vehicle v ON v.vin=CONCAT('D3SYN',RIGHT(CONCAT('000000000000',x.vehicle_n),12)) JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.listed_at=x.listed_at WHERE l.branch_id<>inv.branch_id)
    THROW 51427,'Listing branch does not match its inventory position.',1;
 COMMIT TRANSACTION;
 SELECT N'05 Marketplace activity' AS phase_name,DB_NAME() AS target_database,N'COMMITTED' AS status,
        34 AS expected_listings,@listingInserted AS listings_inserted,34-@listingInserted AS exact_match_skipped,
        119 AS expected_images,@imageInserted AS images_inserted,119-@imageInserted AS exact_match_skipped,
        99 AS expected_enquiries,@enquiryInserted AS enquiries_inserted,99-@enquiryInserted AS exact_match_skipped,
        24 AS expected_reservations,@reservationInserted AS reservations_inserted,24-@reservationInserted AS exact_match_skipped,
        N'PASS' AS validation_result,N'Phase 06 permitted after reviewing counts and zero conflicts.' AS next_phase;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SELECT N'05 Marketplace activity' AS phase_name,DB_NAME() AS target_database,N'ROLLED_BACK' AS status,ERROR_NUMBER() AS error_number,ERROR_MESSAGE() AS error_detail,N'No subsequent phase is permitted.' AS next_phase;
 THROW;
END CATCH;
GO
