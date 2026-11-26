/* Day 3 final validation. Strictly read-only; run after all approved phases. */
USE [CARS24DataModelingSystem];
GO
SET NOCOUNT ON;
IF DB_NAME()<>N'CARS24DataModelingSystem'
BEGIN
    SELECT N'BLOCKED' AS validation_status,N'Wrong database selected.' AS detail;
    RETURN;
END;

SELECT DB_NAME() AS target_database,d.state_desc,d.is_read_only,d.compatibility_level,
       CASE WHEN d.state_desc='ONLINE' AND d.is_read_only=0 THEN N'PASS' ELSE N'BLOCKED' END AS database_status
FROM sys.databases d WHERE d.database_id=DB_ID();

DECLARE @Targets TABLE(schema_name sysname,table_name sysname,target_count bigint,PRIMARY KEY(schema_name,table_name));
INSERT INTO @Targets VALUES
(N'ref',N'City',8),(N'core',N'Branch',8),(N'core',N'Employee',25),(N'core',N'EmployeeRole',25),(N'core',N'Customer',100),(N'core',N'CustomerContact',175),(N'core',N'CustomerAddress',125),
(N'vehicle',N'VehicleBrand',8),(N'vehicle',N'VehicleModel',7),(N'vehicle',N'VehicleVariant',4),(N'vehicle',N'Vehicle',70),(N'vehicle',N'VehicleRegistration',70),(N'vehicle',N'VehicleOwnershipHistory',78),(N'vehicle',N'VehicleSubmission',70),
(N'inspection',N'Inspection',65),(N'inspection',N'InspectionReport',60),(N'inspection',N'InspectionItem',420),(N'inspection',N'Defect',100),(N'inspection',N'VehicleValuation',55),
(N'acquisition',N'PurchaseOffer',50),(N'acquisition',N'PurchaseAgreement',35),(N'acquisition',N'VehicleAcquisition',32),
(N'inventory',N'Inventory',32),(N'inventory',N'InventoryMovement',63),
(N'marketplace',N'VehicleListing',35),(N'marketplace',N'ListingImage',120),(N'marketplace',N'CustomerEnquiry',100),(N'marketplace',N'VehicleReservation',25),
(N'sales',N'SalesOrder',19),(N'sales',N'SalesOrderItem',19),(N'finance',N'Payment',27),(N'finance',N'Refund',6),(N'delivery',N'OwnershipTransfer',13),(N'delivery',N'VehicleDelivery',13);

/* Actual counts for every modeled table. The proposed cumulative targets below
   are exact only for a clean documented Day 2 baseline plus all Day 3 phases.
   An actual database with extra legitimate rows must be reconciled; the
   validator does not delete data or silently treat an excess as success. */
DECLARE @CountSql nvarchar(max)=N'';
SELECT @CountSql=STRING_AGG(CONVERT(nvarchar(max),N'SELECT N'''+REPLACE(schema_name+N'.'+table_name,N'''',N'''''')+N''' AS table_name,COUNT_BIG(*) AS actual_count,CONVERT(bigint,'+CONVERT(nvarchar(30),target_count)+N') AS proposed_target FROM '+QUOTENAME(schema_name)+N'.'+QUOTENAME(table_name)),N' UNION ALL ')
FROM @Targets;
EXEC sys.sp_executesql @CountSql;

/* Per-phase cohort counts. These are current-state markers, not persisted
   insert/skip metrics; each generation phase prints those in its own output. */
SELECT N'Day3 vehicle VINs' AS cohort,COUNT_BIG(*) AS row_count FROM vehicle.Vehicle WHERE vin LIKE 'D3SYN%'
UNION ALL SELECT N'Day3 employees',COUNT_BIG(*) FROM core.Employee WHERE employee_code LIKE 'D3-EMP-%'
UNION ALL SELECT N'Day3 customers',COUNT_BIG(*) FROM core.Customer WHERE display_name LIKE N'D3 Synthetic Customer %'
UNION ALL SELECT N'Day3 offers',COUNT_BIG(*) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%'
UNION ALL SELECT N'Day3 listings',COUNT_BIG(*) FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.description LIKE N'Day 3 synthetic listing %'
UNION ALL SELECT N'Day3 enquiries',COUNT_BIG(*) FROM marketplace.CustomerEnquiry WHERE message_reference LIKE N'D3-ENQ-%'
UNION ALL SELECT N'Day3 payments',COUNT_BIG(*) FROM finance.Payment WHERE provider_code='D3_SYNTHETIC' AND provider_reference LIKE 'D3-PAY-%'
UNION ALL SELECT N'Day3 refunds',COUNT_BIG(*) FROM finance.Refund WHERE provider_reference LIKE 'D3-REF-%';

/* Status distributions show the operational mix instead of just totals. */
SELECT N'Vehicle' AS table_name,lifecycle_status AS status_code,COUNT_BIG(*) AS row_count FROM vehicle.Vehicle GROUP BY lifecycle_status
UNION ALL SELECT N'VehicleSubmission',status,COUNT_BIG(*) FROM vehicle.VehicleSubmission GROUP BY status
UNION ALL SELECT N'Inspection',status,COUNT_BIG(*) FROM inspection.Inspection GROUP BY status
UNION ALL SELECT N'InspectionReport',outcome_code,COUNT_BIG(*) FROM inspection.InspectionReport GROUP BY outcome_code
UNION ALL SELECT N'VehicleValuation',status,COUNT_BIG(*) FROM inspection.VehicleValuation GROUP BY status
UNION ALL SELECT N'PurchaseOffer',status,COUNT_BIG(*) FROM acquisition.PurchaseOffer GROUP BY status
UNION ALL SELECT N'PurchaseAgreement',status,COUNT_BIG(*) FROM acquisition.PurchaseAgreement GROUP BY status
UNION ALL SELECT N'Inventory',status,COUNT_BIG(*) FROM inventory.Inventory GROUP BY status
UNION ALL SELECT N'VehicleListing',status,COUNT_BIG(*) FROM marketplace.VehicleListing GROUP BY status
UNION ALL SELECT N'CustomerEnquiry',status,COUNT_BIG(*) FROM marketplace.CustomerEnquiry GROUP BY status
UNION ALL SELECT N'VehicleReservation',status,COUNT_BIG(*) FROM marketplace.VehicleReservation GROUP BY status
UNION ALL SELECT N'SalesOrder',status,COUNT_BIG(*) FROM sales.SalesOrder GROUP BY status
UNION ALL SELECT N'Payment',status,COUNT_BIG(*) FROM finance.Payment GROUP BY status
UNION ALL SELECT N'Refund',status,COUNT_BIG(*) FROM finance.Refund GROUP BY status
UNION ALL SELECT N'OwnershipTransfer',status,COUNT_BIG(*) FROM delivery.OwnershipTransfer GROUP BY status
UNION ALL SELECT N'VehicleDelivery',status,COUNT_BIG(*) FROM delivery.VehicleDelivery GROUP BY status
ORDER BY table_name,status_code;

/* Object health: these issue result sets should be empty. */
SELECT N'DISABLED_OR_UNTRUSTED_FOREIGN_KEY' AS issue_type,SCHEMA_NAME(t.schema_id) AS schema_name,t.name AS table_name,f.name AS object_name
FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id WHERE f.is_disabled=1 OR f.is_not_trusted=1
UNION ALL SELECT N'DISABLED_OR_UNTRUSTED_CHECK',SCHEMA_NAME(t.schema_id),t.name,c.name
FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id WHERE c.is_disabled=1 OR c.is_not_trusted=1
UNION ALL SELECT N'DISABLED_INDEX',SCHEMA_NAME(t.schema_id),t.name,i.name
FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id WHERE i.index_id>0 AND i.is_disabled=1;

/* Cross-row workflow and temporal issues. Empty result sets mean no listed issues. */
SELECT h1.vehicle_id,h1.ownership_history_id,h2.ownership_history_id AS overlapping_history_id
FROM vehicle.VehicleOwnershipHistory h1 JOIN vehicle.VehicleOwnershipHistory h2 ON h1.vehicle_id=h2.vehicle_id AND h1.ownership_history_id<h2.ownership_history_id
AND h1.valid_from<COALESCE(h2.valid_to,CONVERT(datetime2(0),'9999-12-31T23:59:59')) AND h2.valid_from<COALESCE(h1.valid_to,CONVERT(datetime2(0),'9999-12-31T23:59:59'));
SELECT v.vehicle_id,v.vin,v.current_owner_customer_id
FROM vehicle.Vehicle v WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=v.current_owner_customer_id AND h.valid_to IS NULL);
SELECT r1.registration_number,r1.registration_id,r2.registration_id AS overlapping_registration_id
FROM vehicle.VehicleRegistration r1 JOIN vehicle.VehicleRegistration r2 ON r1.registration_number=r2.registration_number AND r1.registration_id<r2.registration_id
AND r1.valid_from<COALESCE(r2.valid_to,CONVERT(date,'99991231',112)) AND r2.valid_from<COALESCE(r1.valid_to,CONVERT(date,'99991231',112));
SELECT d.defect_id,d.report_id,d.inspection_item_id AS item_id_with_wrong_report
FROM inspection.Defect d JOIN inspection.InspectionItem i ON i.inspection_item_id=d.inspection_item_id WHERE d.report_id<>i.report_id;
SELECT val.valuation_id,val.vehicle_id,val.report_id
FROM inspection.VehicleValuation val JOIN inspection.InspectionReport r ON r.report_id=val.report_id
JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id WHERE val.vehicle_id<>i.vehicle_id;
SELECT ac.acquisition_id,ac.vehicle_id AS acquired_vehicle_id,s.vehicle_id AS submitted_vehicle_id,ac.seller_customer_id,s.seller_customer_id AS submission_seller_id
FROM acquisition.VehicleAcquisition ac JOIN acquisition.PurchaseAgreement a ON a.agreement_id=ac.agreement_id
JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id
WHERE ac.vehicle_id<>s.vehicle_id OR ac.seller_customer_id<>s.seller_customer_id OR a.seller_customer_id<>s.seller_customer_id OR o.seller_customer_id<>s.seller_customer_id OR a.status<>'SIGNED' OR o.status<>'ACCEPTED';
SELECT inv.inventory_id,inv.vehicle_id FROM inventory.Inventory inv
WHERE NOT EXISTS(SELECT 1 FROM acquisition.VehicleAcquisition ac WHERE ac.vehicle_id=inv.vehicle_id);
WITH ordered AS
(
 SELECT m.*,LAG(m.to_branch_id) OVER(PARTITION BY m.inventory_id ORDER BY m.occurred_at,m.movement_id) AS previous_to_branch,
        LAG(m.to_location_code) OVER(PARTITION BY m.inventory_id ORDER BY m.occurred_at,m.movement_id) AS previous_to_location
 FROM inventory.InventoryMovement m
)
SELECT movement_id,inventory_id,from_branch_id,from_location_code,previous_to_branch,previous_to_location
FROM ordered WHERE movement_type IN ('TRANSFER','DISPATCH') AND
 (from_branch_id IS NULL OR from_location_code IS NULL OR previous_to_branch IS NULL OR previous_to_location IS NULL
  OR from_branch_id<>previous_to_branch OR from_location_code<>previous_to_location);
SELECT l.listing_id,l.vehicle_id FROM marketplace.VehicleListing l WHERE l.status='ACTIVE'
AND NOT EXISTS(SELECT 1 FROM inventory.Inventory i WHERE i.vehicle_id=l.vehicle_id AND i.status IN ('AVAILABLE','HELD','PREPARATION'));
SELECT vehicle_id,COUNT_BIG(*) AS active_listing_count FROM marketplace.VehicleListing WHERE status='ACTIVE' GROUP BY vehicle_id HAVING COUNT_BIG(*)>1;
SELECT v.vehicle_id,COUNT_BIG(*) AS active_reservation_count FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id
WHERE r.status='ACTIVE' GROUP BY v.vehicle_id HAVING COUNT_BIG(*)>1;
SELECT i.order_item_id,o.buyer_customer_id,r.customer_id AS reservation_customer,v.vehicle_id,l.vehicle_id AS reserved_listing_vehicle
FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id
JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id
WHERE o.buyer_customer_id<>r.customer_id OR v.vehicle_id<>l.vehicle_id;
SELECT v.vehicle_id,COUNT_BIG(*) AS completed_sales FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id
WHERE o.status='COMPLETED' GROUP BY v.vehicle_id HAVING COUNT_BIG(*)>1;
SELECT p.payment_id,p.order_id FROM finance.Payment p JOIN sales.SalesOrder o ON o.order_id=p.order_id WHERE p.currency_code<>o.currency_code;
SELECT p.payment_id,p.amount,SUM(r.amount) AS successful_refunds FROM finance.Payment p JOIN finance.Refund r ON r.payment_id=p.payment_id
WHERE p.status='SUCCEEDED' AND r.status='SUCCEEDED' GROUP BY p.payment_id,p.amount HAVING SUM(r.amount)>p.amount;
SELECT t.transfer_id,t.order_item_id,t.from_customer_id,owner.customer_id AS recorded_owner,t.to_customer_id,o.buyer_customer_id,v.vehicle_id AS transfer_vehicle,i.vehicle_id AS sold_vehicle
FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id
LEFT JOIN vehicle.VehicleOwnershipHistory owner ON owner.vehicle_id=v.vehicle_id AND owner.valid_to IS NULL
WHERE t.to_customer_id<>o.buyer_customer_id OR (t.status='COMPLETED' AND (t.completed_at IS NULL OR t.authority_reference IS NULL))
   OR (t.status='COMPLETED' AND NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory priorOwner WHERE priorOwner.vehicle_id=v.vehicle_id AND priorOwner.customer_id=t.from_customer_id AND priorOwner.valid_to=t.completed_at))
   OR (t.status='COMPLETED' AND owner.customer_id<>t.to_customer_id);
SELECT d.delivery_id,d.order_item_id,d.recipient_customer_id,o.buyer_customer_id,d.status,d.scheduled_at,d.completed_at
FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id
WHERE d.recipient_customer_id<>o.buyer_customer_id OR (d.status='COMPLETED' AND (d.completed_at IS NULL OR d.scheduled_at IS NULL)) OR o.status='CANCELLED';
SELECT order_item_id,COUNT_BIG(*) AS transfer_count FROM delivery.OwnershipTransfer GROUP BY order_item_id HAVING COUNT_BIG(*)>1;
SELECT order_item_id,COUNT_BIG(*) AS delivery_count FROM delivery.VehicleDelivery GROUP BY order_item_id HAVING COUNT_BIG(*)>1;
SELECT o.order_id,i.order_item_id,i.sale_price,COALESCE(SUM(CASE WHEN p.status='SUCCEEDED' THEN p.amount ELSE 0 END),0) AS successful_payment_total
FROM sales.SalesOrder o JOIN sales.SalesOrderItem i ON i.order_id=o.order_id LEFT JOIN finance.Payment p ON p.order_id=o.order_id
WHERE o.status='COMPLETED' GROUP BY o.order_id,i.order_item_id,i.sale_price HAVING COALESCE(SUM(CASE WHEN p.status='SUCCEEDED' THEN p.amount ELSE 0 END),0)<>i.sale_price;

/* DDL-level FK and CHECK enforcement. Review output; DBCC does not certify the
   application-level checks above or verify live SQL execution history. */
DECLARE @DbccViolations TABLE([Table] nvarchar(256),[Constraint] nvarchar(256),[Where] nvarchar(max));
INSERT INTO @DbccViolations EXEC(N'DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS, ALL_ERRORMSGS');
SELECT [Table],[Constraint],[Where] FROM @DbccViolations;

/* Aggregate gate: every mandatory database, object-health, workflow and
   constraint diagnostic is included below. Earlier result sets are useful
   detail views, not independent gates. */
DECLARE @CountMismatchSql nvarchar(max)=N'', @CountMismatchCount bigint=0;
SELECT @CountMismatchSql=STRING_AGG(CONVERT(nvarchar(max),
    N'SELECT COUNT_BIG(*) AS actual_count,CONVERT(bigint,'+CONVERT(nvarchar(30),target_count)+N') AS target_count FROM '+QUOTENAME(schema_name)+N'.'+QUOTENAME(table_name)),N' UNION ALL ')
FROM @Targets;
SET @CountMismatchSql=N'SELECT @m=SUM(CASE WHEN actual_count<>target_count THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) FROM ('+@CountMismatchSql+N') AS counts;';
EXEC sys.sp_executesql @CountMismatchSql,N'@m bigint OUTPUT',@m=@CountMismatchCount OUTPUT;

DECLARE @ValidationFailures TABLE(check_name nvarchar(200) NOT NULL, failure_count bigint NOT NULL);
/* Independently reconstruct Phase 01's employee/customer/contact/address rows
   from ordinal rules; the checks below compare both expected and actual sets. */
DECLARE @ExpectedEmployees TABLE(employee_code varchar(30) PRIMARY KEY,branch_code varchar(30),display_name nvarchar(150),role_code varchar(30),active_from date,active_to date NULL,role_from datetime2(0),role_to datetime2(0) NULL);
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<21)
INSERT @ExpectedEmployees
SELECT CONCAT('D3-EMP-',RIGHT(CONCAT('0000',n),4)),
 CASE (n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END,
 CONCAT(N'Day 3 Synthetic Employee ',RIGHT(CONCAT(N'0000',n),4)),
 CASE (n-1)%4 WHEN 0 THEN 'INSPECTOR' WHEN 1 THEN 'SALES_EXECUTIVE' WHEN 2 THEN 'INVENTORY_MANAGER' ELSE 'BRANCH_MANAGER' END,
 CONVERT(date,'20260201',112),CONVERT(date,NULL),CONVERT(datetime2(0),'2026-02-01T00:00:00'),CONVERT(datetime2(0),NULL) FROM n OPTION(MAXRECURSION 100);
DECLARE @ExpectedCustomers TABLE(n int PRIMARY KEY,display_name nvarchar(150),legal_name nvarchar(150),status varchar(20),created_at datetime2(0));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<97)
INSERT @ExpectedCustomers
SELECT n,CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',n),4)),CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',n),4)),
 CASE WHEN n%19=0 THEN 'INACTIVE' WHEN n%37=0 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
 DATEADD(second,n,CONVERT(datetime2(0),'2026-02-01T10:00:00')) FROM n OPTION(MAXRECURSION 100);
DECLARE @ExpectedContacts TABLE(display_name nvarchar(150),contact_type varchar(10),contact_value nvarchar(254),is_verified bit,valid_from datetime2(0),valid_to datetime2(0) NULL,PRIMARY KEY(display_name,contact_type));
INSERT @ExpectedContacts
SELECT display_name,'EMAIL',CONCAT(N'day3.customer.',RIGHT(CONCAT(N'0000',n),4),N'@example.invalid'),0,created_at,NULL FROM @ExpectedCustomers
UNION ALL SELECT display_name,'PHONE',CONCAT(N'+91-00000-',RIGHT(CONCAT(N'00000',n),5)),0,created_at,NULL FROM @ExpectedCustomers WHERE n<=75;
DECLARE @ExpectedAddresses TABLE(display_name nvarchar(150),address_line1 nvarchar(200),address_line2 nvarchar(200) NULL,city_name nvarchar(100),postal_code varchar(6),address_type varchar(20),valid_from datetime2(0),valid_to datetime2(0) NULL,PRIMARY KEY(display_name,address_line1));
INSERT @ExpectedAddresses
SELECT display_name,CONCAT(N'D3 Synthetic Address ',RIGHT(CONCAT(N'0000',n),4)),CONVERT(nvarchar(200),NULL),CASE (n-1)%8 WHEN 0 THEN N'Hyderabad' WHEN 1 THEN N'Mumbai' WHEN 2 THEN N'Bengaluru' WHEN 3 THEN N'Pune' WHEN 4 THEN N'Delhi' WHEN 5 THEN N'Chennai' WHEN 6 THEN N'Ahmedabad' ELSE N'Rajkot' END,RIGHT(CONCAT('100000',100000+n),6),'HOME',created_at,NULL FROM @ExpectedCustomers
UNION ALL SELECT display_name,CONCAT(N'D3 Synthetic Mailing Address ',RIGHT(CONCAT(N'0000',n),4)),CONVERT(nvarchar(200),NULL),CASE n%8 WHEN 0 THEN N'Hyderabad' WHEN 1 THEN N'Mumbai' WHEN 2 THEN N'Bengaluru' WHEN 3 THEN N'Pune' WHEN 4 THEN N'Delhi' WHEN 5 THEN N'Chennai' WHEN 6 THEN N'Ahmedabad' ELSE N'Rajkot' END,RIGHT(CONCAT('100000',200000+n),6),'MAILING',DATEADD(day,30,created_at),NULL FROM @ExpectedCustomers WHERE n<=25;
INSERT @ValidationFailures VALUES(N'Independent Phase 01 employee payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.employee_code,e.branch_code,e.display_name,e.active_from,e.active_to FROM @ExpectedEmployees e EXCEPT SELECT a.employee_code,b.branch_code,a.display_name,a.active_from,a.active_to FROM core.Employee a JOIN core.Branch b ON b.branch_id=a.branch_id WHERE a.employee_code LIKE 'D3-EMP-%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT a.employee_code,b.branch_code,a.display_name,a.active_from,a.active_to FROM core.Employee a JOIN core.Branch b ON b.branch_id=a.branch_id WHERE a.employee_code LIKE 'D3-EMP-%' EXCEPT SELECT e.employee_code,e.branch_code,e.display_name,e.active_from,e.active_to FROM @ExpectedEmployees e) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 01 employee-role payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.employee_code,e.role_code,e.role_from,e.role_to FROM @ExpectedEmployees e EXCEPT SELECT a.employee_code,r.role_code,r.valid_from,r.valid_to FROM core.EmployeeRole r JOIN core.Employee a ON a.employee_id=r.employee_id WHERE a.employee_code LIKE 'D3-EMP-%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT a.employee_code,r.role_code,r.valid_from,r.valid_to FROM core.EmployeeRole r JOIN core.Employee a ON a.employee_id=r.employee_id WHERE a.employee_code LIKE 'D3-EMP-%' EXCEPT SELECT e.employee_code,e.role_code,e.role_from,e.role_to FROM @ExpectedEmployees e) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 01 customer payload',
 (SELECT COUNT_BIG(*) FROM (SELECT display_name,legal_name,status,created_at FROM @ExpectedCustomers EXCEPT SELECT display_name,legal_name,status,created_at FROM core.Customer WHERE display_name LIKE N'D3 Synthetic Customer %') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT display_name,legal_name,status,created_at FROM core.Customer WHERE display_name LIKE N'D3 Synthetic Customer %' EXCEPT SELECT display_name,legal_name,status,created_at FROM @ExpectedCustomers) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 01 contact payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.display_name,e.contact_type,e.contact_value,e.is_verified,e.valid_from,e.valid_to FROM @ExpectedContacts e EXCEPT SELECT c.display_name,x.contact_type,x.contact_value,x.is_verified,x.valid_from,x.valid_to FROM core.CustomerContact x JOIN core.Customer c ON c.customer_id=x.customer_id WHERE c.display_name LIKE N'D3 Synthetic Customer %') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT c.display_name,x.contact_type,x.contact_value,x.is_verified,x.valid_from,x.valid_to FROM core.CustomerContact x JOIN core.Customer c ON c.customer_id=x.customer_id WHERE c.display_name LIKE N'D3 Synthetic Customer %' EXCEPT SELECT display_name,contact_type,contact_value,is_verified,valid_from,valid_to FROM @ExpectedContacts) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 01 address payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.display_name,e.address_line1,e.address_line2,e.city_name,e.postal_code,e.address_type,e.valid_from,e.valid_to FROM @ExpectedAddresses e EXCEPT SELECT c.display_name,a.address_line1,a.address_line2,city.city_name,a.postal_code,a.address_type,a.valid_from,a.valid_to FROM core.CustomerAddress a JOIN core.Customer c ON c.customer_id=a.customer_id JOIN ref.City city ON city.city_id=a.city_id WHERE c.display_name LIKE N'D3 Synthetic Customer %') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT c.display_name,a.address_line1,a.address_line2,city.city_name,a.postal_code,a.address_type,a.valid_from,a.valid_to FROM core.CustomerAddress a JOIN core.Customer c ON c.customer_id=a.customer_id JOIN ref.City city ON city.city_id=a.city_id WHERE c.display_name LIKE N'D3 Synthetic Customer %' EXCEPT SELECT display_name,address_line1,address_line2,city_name,postal_code,address_type,valid_from,valid_to FROM @ExpectedAddresses) x));
DECLARE @ExpectedVehicles TABLE(n int PRIMARY KEY,vin varchar(30),engine_number varchar(40),brand_name nvarchar(100),model_name nvarchar(100),variant_name nvarchar(120) NULL,manufacture_year smallint,fuel varchar(15),transmission varchar(15),initial_owner nvarchar(150),branch_code varchar(30),registration_number varchar(15),state_code varchar(2),created_at datetime2(0),submitted_at datetime2(0));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<67), vehicle_catalog AS
(SELECT x.n,m.brand_name,m.model_name,m.variant_name FROM n x JOIN (VALUES
 (0,N'Maruti Suzuki',N'Swift',N'VXi Synthetic'),(1,N'Hyundai',N'Creta',N'SX Synthetic'),(2,N'Tata Motors',N'Nexon',N'XZ+ Synthetic'),(3,N'Mahindra',N'XUV700',CONVERT(nvarchar(120),NULL)),(4,N'Honda',N'City',N'V Synthetic'),(5,N'Toyota',N'Innova Crysta',CONVERT(nvarchar(120),NULL)),(6,N'Kia',N'Seltos',CONVERT(nvarchar(120),NULL))) m(slot,brand_name,model_name,variant_name) ON m.slot=(x.n-1)%7)
INSERT @ExpectedVehicles
SELECT c.n,CONCAT('D3SYN',RIGHT(CONCAT('000000000000',c.n),12)),CONCAT('D3ENG',RIGHT(CONCAT('0000000',c.n),7)),c.brand_name,c.model_name,c.variant_name,CONVERT(smallint,2016+c.n%10),
 CASE c.n%5 WHEN 0 THEN 'DIESEL' WHEN 1 THEN 'PETROL' WHEN 2 THEN 'PETROL' WHEN 3 THEN 'CNG' ELSE 'ELECTRIC' END,
 CASE c.n%4 WHEN 0 THEN 'MANUAL' WHEN 1 THEN 'AUTOMATIC' WHEN 2 THEN 'AMT' ELSE 'CVT' END,
 CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',c.n),4)),
 CASE (c.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END,
 CASE (c.n-1)%8 WHEN 0 THEN CONCAT('TS09ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 1 THEN CONCAT('MH01ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 2 THEN CONCAT('KA03ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 3 THEN CONCAT('MH12ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 4 THEN CONCAT('DL01ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 5 THEN CONCAT('TN09ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 6 THEN CONCAT('GJ01ZZ',RIGHT(CONCAT('0000',c.n),4)) ELSE CONCAT('GJ03ZZ',RIGHT(CONCAT('0000',c.n),4)) END,
 CASE (c.n-1)%8 WHEN 0 THEN 'TG' WHEN 1 THEN 'MH' WHEN 2 THEN 'KA' WHEN 3 THEN 'MH' WHEN 4 THEN 'DL' WHEN 5 THEN 'TN' ELSE 'GJ' END,
 DATEADD(day,c.n,CONVERT(datetime2(0),'2026-02-01T09:00:00')),DATEADD(hour,1,DATEADD(day,c.n,CONVERT(datetime2(0),'2026-02-01T09:00:00')))
FROM vehicle_catalog c OPTION(MAXRECURSION 100);
INSERT @ValidationFailures VALUES(N'Independent Phase 02 complete vehicle identity payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.engine_number,e.brand_name,e.model_name,e.variant_name,e.manufacture_year,e.fuel,e.transmission,e.created_at FROM @ExpectedVehicles e EXCEPT SELECT v.vin,v.engine_number,b.brand_name,m.model_name,va.variant_name,v.manufacture_year,v.fuel_type_code,v.transmission_type_code,v.created_at FROM vehicle.Vehicle v JOIN vehicle.VehicleModel m ON m.model_id=v.model_id JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id LEFT JOIN vehicle.VehicleVariant va ON va.variant_id=v.variant_id AND va.model_id=v.model_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin,v.engine_number,b.brand_name,m.model_name,va.variant_name,v.manufacture_year,v.fuel_type_code,v.transmission_type_code,v.created_at FROM vehicle.Vehicle v JOIN vehicle.VehicleModel m ON m.model_id=v.model_id JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id LEFT JOIN vehicle.VehicleVariant va ON va.variant_id=v.variant_id AND va.model_id=v.model_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin,e.engine_number,e.brand_name,e.model_name,e.variant_name,e.manufacture_year,e.fuel,e.transmission,e.created_at FROM @ExpectedVehicles e) AS unexpected_vehicle_payload));
INSERT @ValidationFailures VALUES(N'Independent Phase 02 registration payload and owner relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.registration_number,e.state_code,CONVERT(date,e.created_at) AS valid_from,CONVERT(date,NULL) AS valid_to FROM @ExpectedVehicles e EXCEPT SELECT v.vin,r.registration_number,r.issuing_state_code,r.valid_from,r.valid_to FROM vehicle.VehicleRegistration r JOIN vehicle.Vehicle v ON v.vehicle_id=r.vehicle_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin,r.registration_number,r.issuing_state_code,r.valid_from,r.valid_to FROM vehicle.VehicleRegistration r JOIN vehicle.Vehicle v ON v.vehicle_id=r.vehicle_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin,e.registration_number,e.state_code,CONVERT(date,e.created_at),CONVERT(date,NULL) FROM @ExpectedVehicles e) AS unexpected_registration_payload));
INSERT @ValidationFailures VALUES(N'Independent Phase 02 initial ownership history payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.initial_owner,e.created_at,'REGISTERED_OWNER' AS basis_code,N'Day 3 synthetic initial registered-owner fixture' AS evidence_reference FROM @ExpectedVehicles e EXCEPT SELECT v.vin,c.display_name,h.valid_from,h.basis_code,h.evidence_reference FROM vehicle.VehicleOwnershipHistory h JOIN vehicle.Vehicle v ON v.vehicle_id=h.vehicle_id JOIN core.Customer c ON c.customer_id=h.customer_id WHERE v.vin LIKE 'D3SYN%' AND h.valid_from=v.created_at) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 02 submission payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.initial_owner,e.branch_code,e.submitted_at FROM @ExpectedVehicles e EXCEPT SELECT v.vin,c.display_name,b.branch_code,s.submitted_at FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id JOIN core.Customer c ON c.customer_id=s.seller_customer_id JOIN core.Branch b ON b.branch_id=s.branch_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin,c.display_name,b.branch_code,s.submitted_at FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id JOIN core.Customer c ON c.customer_id=s.seller_customer_id JOIN core.Branch b ON b.branch_id=s.branch_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin,e.initial_owner,e.branch_code,e.submitted_at FROM @ExpectedVehicles e) AS unexpected_submission_payload));
INSERT @ValidationFailures VALUES(N'Independent final vehicle, owner, and submission lifecycle projection',
 (SELECT COUNT_BIG(*) FROM @ExpectedVehicles e JOIN vehicle.Vehicle v ON v.vin=e.vin JOIN core.Customer owner ON owner.customer_id=v.current_owner_customer_id
  WHERE v.lifecycle_status<>CASE WHEN e.n<=3 THEN 'LISTED' WHEN e.n<=10 THEN 'RESERVED' WHEN e.n<=18 THEN 'SOLD' WHEN e.n<=31 THEN 'IN_STOCK' ELSE 'SUBMITTED' END
   OR owner.display_name<>CASE WHEN e.n BETWEEN 11 AND 16 THEN CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',89+e.n-10),4)) WHEN e.n BETWEEN 17 AND 18 THEN CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',40+e.n-10),4)) ELSE e.initial_owner END)
 +(SELECT COUNT_BIG(*) FROM @ExpectedVehicles e JOIN vehicle.Vehicle v ON v.vin=e.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=e.submitted_at
  WHERE s.status<>CASE WHEN e.n<=31 THEN 'ACCEPTED' ELSE 'SUBMITTED' END
    OR (e.n<=31 AND (s.closed_at IS NULL OR s.closed_at<>DATEADD(hour,2,DATEADD(day,2,DATEADD(hour,12,DATEADD(day,4+e.n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))))))
   OR (e.n>31 AND s.closed_at IS NOT NULL) OR s.outcome_reason IS NOT NULL));
DECLARE @ExpectedInspections TABLE(n int PRIMARY KEY,vin varchar(30),submission_at datetime2(0),scheduled_at datetime2(0),completed_at datetime2(0) NULL,status varchar(20),employee_code varchar(30));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<62)
INSERT @ExpectedInspections
SELECT n,CONCAT('D3SYN',RIGHT(CONCAT('000000000000',n),12)),DATEADD(hour,1,DATEADD(day,n,CONVERT(datetime2(0),'2026-02-01T09:00:00'))),DATEADD(hour,9,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00'))),
 CASE WHEN n<=57 THEN DATEADD(minute,60,DATEADD(hour,9,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))) END,
 CASE WHEN n<=57 THEN 'COMPLETED' WHEN n<=60 THEN 'SCHEDULED' WHEN n=61 THEN 'CANCELLED' ELSE 'NO_SHOW' END,
 CONCAT('D3-EMP-',RIGHT(CONCAT('0000',1+((n-1)%6)*4),4)) FROM n OPTION(MAXRECURSION 100);
DECLARE @ExpectedItems TABLE(n int,item_code varchar(40),outcome_code varchar(20),note nvarchar(500),PRIMARY KEY(n,item_code));
INSERT @ExpectedItems
SELECT i.n,x.item_code,CASE WHEN x.item_code='ENGINE' AND i.n%11=0 THEN 'FAIL' WHEN x.item_code='BRAKES' AND i.n%13=0 THEN 'FAIL' WHEN x.item_code='ROAD_TEST' AND i.n%17=0 THEN 'NOT_CHECKED' ELSE 'PASS' END,CONCAT(N'Day 3 synthetic checklist; cohort ',RIGHT(CONCAT(N'0000',i.n),4))
FROM @ExpectedInspections i JOIN (VALUES('ENGINE'),('BRAKES'),('BODY'),('ELECTRICAL'),('TYRES'),('INTERIOR'),('ROAD_TEST')) x(item_code) ON i.n<=57
UNION ALL SELECT n,'SAFETY','PASS',CONCAT(N'Day 3 synthetic safety check; cohort ',RIGHT(CONCAT(N'0000',n),4)) FROM @ExpectedInspections WHERE n BETWEEN 1 AND 12;
DECLARE @ExpectedDefects TABLE(n int,defect_no int,item_code varchar(40),category varchar(20),severity varchar(20),repair_estimate decimal(19,4),description nvarchar(150),PRIMARY KEY(n,defect_no));
INSERT @ExpectedDefects
SELECT n,1,CASE WHEN n%2=0 THEN 'BODY' ELSE 'ENGINE' END,CASE WHEN n%3=0 THEN 'MECHANICAL' WHEN n%3=1 THEN 'COSMETIC' ELSE 'ELECTRICAL' END,CASE WHEN n%17=0 THEN 'HIGH' WHEN n%5=0 THEN 'MEDIUM' ELSE 'LOW' END,CONVERT(decimal(19,4),500+n*50+250),CONCAT(N'D3 synthetic defect ',RIGHT(CONCAT(N'0000',n),4),N'-1') FROM @ExpectedInspections WHERE n<=57
UNION ALL SELECT n,2,'ENGINE',CASE WHEN n%2=0 THEN 'SAFETY' ELSE 'COSMETIC' END,'MEDIUM',CONVERT(decimal(19,4),500+n*50+500),CONCAT(N'D3 synthetic defect ',RIGHT(CONCAT(N'0000',n),4),N'-2') FROM @ExpectedInspections WHERE n<=42;
DECLARE @ExpectedValuations TABLE(n int PRIMARY KEY,vin varchar(30),scheduled_at datetime2(0),valued_at datetime2(0),amount decimal(19,4),status varchar(20),basis nvarchar(200),employee_code varchar(30));
INSERT @ExpectedValuations
SELECT n,vin,scheduled_at,DATEADD(day,1,scheduled_at),CONVERT(decimal(19,4),500000+(n%20)*25000),CASE WHEN n%10=0 THEN 'REJECTED' WHEN n%7=0 THEN 'SUPERSEDED' ELSE 'APPROVED' END,CONCAT(N'Day 3 synthetic valuation; inspection cohort ',RIGHT(CONCAT(N'0000',n),4)),employee_code FROM @ExpectedInspections WHERE n<=52;
INSERT @ValidationFailures VALUES(N'Independent Phase 03 inspection payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.vin AS submission_vin,e.submission_at,e.scheduled_at,e.completed_at,e.status,e.employee_code FROM @ExpectedInspections e EXCEPT SELECT v.vin,submissionVehicle.vin,s.submitted_at,i.scheduled_at,i.completed_at,i.status,emp.employee_code FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN vehicle.VehicleSubmission s ON s.submission_id=i.submission_id JOIN vehicle.Vehicle submissionVehicle ON submissionVehicle.vehicle_id=s.vehicle_id JOIN core.Employee emp ON emp.employee_id=i.inspector_employee_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin AS inspection_vehicle_vin,submissionVehicle.vin AS submission_vehicle_vin,s.submitted_at,i.scheduled_at,i.completed_at,i.status,emp.employee_code FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN vehicle.VehicleSubmission s ON s.submission_id=i.submission_id JOIN vehicle.Vehicle submissionVehicle ON submissionVehicle.vehicle_id=s.vehicle_id JOIN core.Employee emp ON emp.employee_id=i.inspector_employee_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin AS inspection_vehicle_vin,e.vin AS submission_vehicle_vin,e.submission_at,e.scheduled_at,e.completed_at,e.status,e.employee_code FROM @ExpectedInspections e) AS unexpected_inspection_rows));
INSERT @ValidationFailures VALUES(N'Independent Phase 03 report payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.scheduled_at,CASE WHEN e.n%9=0 THEN 'FAIL' WHEN e.n%4=0 THEN 'CONDITIONAL' ELSE 'PASS' END AS outcome_code,CONCAT(N'Day 3 synthetic inspection report ',RIGHT(CONCAT(N'0000',e.n),4)) AS summary,DATEADD(minute,5,e.completed_at) AS finalized_at FROM @ExpectedInspections e WHERE e.n<=57 EXCEPT SELECT v.vin,i.scheduled_at,r.outcome_code,r.summary,r.finalized_at FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin,i.scheduled_at,r.outcome_code,r.summary,r.finalized_at FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin,e.scheduled_at,CASE WHEN e.n%9=0 THEN 'FAIL' WHEN e.n%4=0 THEN 'CONDITIONAL' ELSE 'PASS' END,CONCAT(N'Day 3 synthetic inspection report ',RIGHT(CONCAT(N'0000',e.n),4)),DATEADD(minute,5,e.completed_at) FROM @ExpectedInspections e WHERE e.n<=57) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 03 inspection-item payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT i.vin,i.scheduled_at,e.item_code,e.outcome_code,e.note FROM @ExpectedItems e JOIN @ExpectedInspections i ON i.n=e.n EXCEPT SELECT v.vin,i.scheduled_at,it.item_code,it.outcome_code,it.note FROM inspection.InspectionItem it JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin,i.scheduled_at,it.item_code,it.outcome_code,it.note FROM inspection.InspectionItem it JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT i.vin,i.scheduled_at,e.item_code,e.outcome_code,e.note FROM @ExpectedItems e JOIN @ExpectedInspections i ON i.n=e.n) x));
INSERT @ValidationFailures VALUES(N'Independent Phase 03 defect payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT d.n,i.vin,i.scheduled_at,d.defect_no,d.item_code,d.category,d.severity,d.repair_estimate,'INR' AS currency_code,d.description FROM @ExpectedDefects d JOIN @ExpectedInspections i ON i.n=d.n EXCEPT SELECT TRY_CONVERT(int,SUBSTRING(a.description,21,4)),v.vin,ins.scheduled_at,TRY_CONVERT(int,RIGHT(a.description,1)),it.item_code,a.category_code,a.severity_code,a.repair_estimate,a.currency_code,a.description FROM inspection.Defect a JOIN inspection.InspectionItem it ON it.inspection_item_id=a.inspection_item_id JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection ins ON ins.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=ins.vehicle_id WHERE a.description LIKE N'D3 synthetic defect %') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,SUBSTRING(a.description,21,4)) AS inspection_n,v.vin,ins.scheduled_at,TRY_CONVERT(int,RIGHT(a.description,1)) AS defect_no,it.item_code,a.category_code,a.severity_code,a.repair_estimate,a.currency_code,a.description FROM inspection.Defect a JOIN inspection.InspectionItem it ON it.inspection_item_id=a.inspection_item_id JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection ins ON ins.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=ins.vehicle_id WHERE a.description LIKE N'D3 synthetic defect %' EXCEPT SELECT d.n,i.vin,i.scheduled_at,d.defect_no,d.item_code,d.category,d.severity,d.repair_estimate,'INR',d.description FROM @ExpectedDefects d JOIN @ExpectedInspections i ON i.n=d.n) AS unexpected_defect_rows)
 +(SELECT COUNT_BIG(*) FROM inspection.Defect a JOIN inspection.InspectionItem it ON it.inspection_item_id=a.inspection_item_id WHERE a.description LIKE N'D3 synthetic defect %' AND a.report_id<>it.report_id));
INSERT @ValidationFailures VALUES(N'Independent Phase 03 valuation payload and relationships',
  (SELECT COUNT_BIG(*) FROM (SELECT e.vin AS valuation_vehicle_vin,e.vin AS report_vehicle_vin,e.scheduled_at,e.valued_at,e.amount,e.status,e.basis,'INR' AS currency_code,e.employee_code FROM @ExpectedValuations e EXCEPT SELECT v.vin,reportVehicle.vin,i.scheduled_at,x.valued_at,x.amount,x.status,x.basis,x.currency_code,emp.employee_code FROM inspection.VehicleValuation x JOIN vehicle.Vehicle v ON v.vehicle_id=x.vehicle_id JOIN core.Employee emp ON emp.employee_id=x.assessor_employee_id JOIN inspection.InspectionReport r ON r.report_id=x.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle reportVehicle ON reportVehicle.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%') AS unexpected_valuation_rows)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin AS valuation_vehicle_vin,reportVehicle.vin AS report_vehicle_vin,i.scheduled_at,x.valued_at,x.amount,x.status,x.basis,x.currency_code,emp.employee_code FROM inspection.VehicleValuation x JOIN vehicle.Vehicle v ON v.vehicle_id=x.vehicle_id JOIN core.Employee emp ON emp.employee_id=x.assessor_employee_id JOIN inspection.InspectionReport r ON r.report_id=x.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle reportVehicle ON reportVehicle.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin AS valuation_vehicle_vin,e.vin AS report_vehicle_vin,e.scheduled_at,e.valued_at,e.amount,e.status,e.basis,'INR' AS currency_code,e.employee_code FROM @ExpectedValuations e) AS unexpected_valuation_rows));
DECLARE @ExpectedOffers TABLE(n int PRIMARY KEY,vin varchar(30),offered_at datetime2(0),expires_at datetime2(0),amount decimal(19,4),status varchar(20),decision_at datetime2(0) NULL);
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<49), calc AS
(SELECT n,DATEADD(hour,12,DATEADD(day,4+n,CONVERT(datetime2(0),'2026-02-01T00:00:00'))) offered_at FROM n)
INSERT @ExpectedOffers
SELECT c.n,CONCAT('D3SYN',RIGHT(CONCAT('000000000000',c.n),12)),c.offered_at,DATEADD(day,7,c.offered_at),CONVERT(decimal(19,4),(500000+(c.n%20)*25000)*0.88),
 CASE WHEN c.n<=34 THEN 'ACCEPTED' WHEN c.n<=40 THEN 'DECLINED' WHEN c.n<=45 THEN 'EXPIRED' ELSE 'ISSUED' END,
 CASE WHEN c.n<=34 THEN DATEADD(hour,3,c.offered_at) WHEN c.n<=40 THEN DATEADD(hour,2,c.offered_at) WHEN c.n<=45 THEN DATEADD(hour,1,DATEADD(day,7,c.offered_at)) END FROM calc c OPTION(MAXRECURSION 100);
DECLARE @ExpectedAgreements TABLE(n int PRIMARY KEY,agreement_reference varchar(40),status varchar(20),signed_at datetime2(0));
INSERT @ExpectedAgreements SELECT n,CONCAT('D3-AGR-',RIGHT(CONCAT('0000',n),4)),CASE WHEN n<=31 THEN 'SIGNED' WHEN n=32 THEN 'VOID' ELSE 'CANCELLED' END,DATEADD(day,2,offered_at) FROM @ExpectedOffers WHERE n<=34;
INSERT @ValidationFailures VALUES(N'Independent Phase 04 purchase-offer payload and lineage',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin,e.offered_at,e.expires_at,e.amount,'INR' AS currency_code,e.status,e.decision_at,v.initial_owner FROM @ExpectedOffers e JOIN @ExpectedVehicles v ON v.n=e.n EXCEPT SELECT v.vin,o.offered_at,o.expires_at,o.amount,o.currency_code,o.status,o.decision_at,seller.display_name FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id JOIN core.Customer seller ON seller.customer_id=o.seller_customer_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin,o.offered_at,o.expires_at,o.amount,o.currency_code,o.status,o.decision_at,seller.display_name FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id JOIN core.Customer seller ON seller.customer_id=o.seller_customer_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT e.vin,e.offered_at,e.expires_at,e.amount,'INR',e.status,e.decision_at,v.initial_owner FROM @ExpectedOffers e JOIN @ExpectedVehicles v ON v.n=e.n) AS unexpected_offer_payload));
INSERT @ValidationFailures VALUES(N'Independent Phase 04 offer-to-valuation and report relationship',
 (SELECT COUNT_BIG(*) FROM @ExpectedOffers eo
  JOIN @ExpectedVehicles ev ON ev.n=eo.n
  JOIN @ExpectedInspections ei ON ei.n=eo.n
  LEFT JOIN vehicle.Vehicle v ON v.vin=eo.vin
  LEFT JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=ev.submitted_at
  LEFT JOIN acquisition.PurchaseOffer o ON o.submission_id=s.submission_id AND o.offered_at=eo.offered_at
  OUTER APPLY (SELECT COUNT_BIG(*) AS matching_valuation_count,MIN(x.valuation_id) AS expected_valuation_id
               FROM inspection.VehicleValuation x WHERE x.vehicle_id=v.vehicle_id AND x.valued_at=DATEADD(day,1,ei.scheduled_at)) expectedValuation
  WHERE v.vehicle_id IS NULL OR s.submission_id IS NULL OR o.offer_id IS NULL OR expectedValuation.matching_valuation_count<>1
     OR o.valuation_id<>expectedValuation.expected_valuation_id
     OR NOT EXISTS
       (SELECT 1 FROM inspection.VehicleValuation attached
        JOIN inspection.InspectionReport r ON r.report_id=attached.report_id
        JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id
        JOIN vehicle.Vehicle reportVehicle ON reportVehicle.vehicle_id=i.vehicle_id
        WHERE attached.valuation_id=o.valuation_id AND attached.vehicle_id=v.vehicle_id
          AND attached.valued_at=DATEADD(day,1,ei.scheduled_at)
          AND reportVehicle.vin=ei.vin AND i.scheduled_at=ei.scheduled_at)));
INSERT @ValidationFailures VALUES(N'Independent Phase 04 agreement payload and offer relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT e.agreement_reference,e.status,e.signed_at,e.n FROM @ExpectedAgreements e EXCEPT SELECT a.agreement_reference,a.status,a.signed_at,TRY_CONVERT(int,RIGHT(a.agreement_reference,4)) FROM acquisition.PurchaseAgreement a WHERE a.agreement_reference LIKE 'D3-AGR-%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT a.agreement_reference,a.status,a.signed_at,TRY_CONVERT(int,RIGHT(a.agreement_reference,4)) AS agreement_n FROM acquisition.PurchaseAgreement a WHERE a.agreement_reference LIKE 'D3-AGR-%' EXCEPT SELECT agreement_reference,status,signed_at,n FROM @ExpectedAgreements) AS unexpected_agreement_rows)
 +(SELECT COUNT_BIG(*) FROM acquisition.PurchaseAgreement a JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND (a.agreement_reference<>CONCAT('D3-AGR-',RIGHT(CONCAT('0000',TRY_CONVERT(int,RIGHT(a.agreement_reference,4))),4)) OR o.offered_at<>DATEADD(day,-2,a.signed_at) OR a.seller_customer_id<>s.seller_customer_id)));
INSERT @ValidationFailures VALUES(N'Independent Phase 04 acquisition payload and lineage',
 (SELECT COUNT_BIG(*) FROM (SELECT ev.vin,ev.initial_owner,ea.agreement_reference,eo.amount,'INR' AS currency_code,DATEADD(hour,2,ea.signed_at) AS acquired_at FROM @ExpectedOffers eo JOIN @ExpectedAgreements ea ON ea.n=eo.n JOIN @ExpectedVehicles ev ON ev.n=eo.n WHERE eo.n<=31 EXCEPT SELECT v.vin,seller.display_name,a.agreement_reference,ac.amount,ac.currency_code,ac.acquired_at FROM acquisition.VehicleAcquisition ac JOIN acquisition.PurchaseAgreement a ON a.agreement_id=ac.agreement_id JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id JOIN core.Customer seller ON seller.customer_id=ac.seller_customer_id WHERE v.vin LIKE 'D3SYN%') AS expected_acquisition_payload)
 +(SELECT COUNT_BIG(*) FROM (SELECT v.vin AS vehicle_vin,seller.display_name AS seller_name,a.agreement_reference,ac.amount AS acquisition_amount,ac.currency_code,ac.acquired_at FROM acquisition.VehicleAcquisition ac JOIN acquisition.PurchaseAgreement a ON a.agreement_id=ac.agreement_id JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id JOIN core.Customer seller ON seller.customer_id=ac.seller_customer_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT ev.vin AS vehicle_vin,ev.initial_owner AS seller_name,ea.agreement_reference,eo.amount AS acquisition_amount,'INR' AS currency_code,DATEADD(hour,2,ea.signed_at) AS acquired_at FROM @ExpectedOffers eo JOIN @ExpectedAgreements ea ON ea.n=eo.n JOIN @ExpectedVehicles ev ON ev.n=eo.n WHERE eo.n<=31) AS unexpected_acquisition_payload));
DECLARE @ExpectedListings TABLE(n int PRIMARY KEY,vehicle_n int,listed_at datetime2(0),closed_at datetime2(0) NULL,status varchar(20),asking_price decimal(19,4),branch_code varchar(30),inventory_since datetime2(0));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<34), src AS
(SELECT ord.n,CASE WHEN ord.n<=31 THEN ord.n ELSE ord.n-31 END vehicle_n,
        DATEADD(minute,10,DATEADD(hour,2,DATEADD(day,2,o.offered_at))) inventory_since
 FROM n AS ord
 JOIN @ExpectedOffers AS o ON o.n=CASE WHEN ord.n<=31 THEN ord.n ELSE ord.n-31 END)
INSERT @ExpectedListings
SELECT s.n,s.vehicle_n,DATEADD(day,CASE WHEN s.n<=31 THEN 5 ELSE 20 END,s.inventory_since),
 CASE WHEN s.n BETWEEN 11 AND 16 THEN DATEADD(minute,15,DATEADD(day,45,DATEADD(day,5,s.inventory_since))) WHEN s.n BETWEEN 17 AND 18 THEN DATEADD(day,50,DATEADD(day,5,s.inventory_since)) WHEN s.n BETWEEN 4 AND 10 OR s.n BETWEEN 19 AND 21 OR s.n BETWEEN 32 AND 34 THEN NULL ELSE DATEADD(day,60,DATEADD(day,CASE WHEN s.n<=31 THEN 5 ELSE 20 END,s.inventory_since)) END,
 CASE WHEN s.n BETWEEN 11 AND 18 THEN 'SOLD' WHEN s.n BETWEEN 4 AND 18 OR s.n BETWEEN 32 AND 34 THEN 'ACTIVE' WHEN s.n BETWEEN 19 AND 21 THEN 'PAUSED' WHEN s.n BETWEEN 26 AND 31 THEN 'WITHDRAWN' ELSE 'CLOSED' END,
 CONVERT(decimal(19,4),(500000+(s.vehicle_n%20)*25000)*1.03),
 CASE WHEN s.vehicle_n<=23 THEN CASE (s.vehicle_n+1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END
 ELSE CASE (s.vehicle_n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END END,s.inventory_since FROM src s OPTION(MAXRECURSION 100);
INSERT @ValidationFailures VALUES(N'Independent Phase 05 listing payload and branch relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vehicle_n,e.listed_at,e.closed_at,e.status,e.asking_price,'INR' AS currency_code,e.branch_code,CONCAT(N'Day 3 synthetic listing ',RIGHT(CONCAT(N'0000',e.n),4)) description FROM @ExpectedListings e EXCEPT SELECT TRY_CONVERT(int,RIGHT(v.vin,12)),l.listed_at,l.closed_at,l.status,l.asking_price,l.currency_code,b.branch_code,l.description FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id JOIN core.Branch b ON b.branch_id=l.branch_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,l.listed_at,l.closed_at,l.status,l.asking_price,l.currency_code,b.branch_code,l.description FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id JOIN core.Branch b ON b.branch_id=l.branch_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT vehicle_n,listed_at,closed_at,status,asking_price,'INR',branch_code,CONCAT(N'Day 3 synthetic listing ',RIGHT(CONCAT(N'0000',n),4)) AS description FROM @ExpectedListings) AS unexpected_listing_rows));
INSERT @ValidationFailures VALUES(N'Independent Phase 05 listing-image payload and relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT l.vehicle_n,l.n,ord.display_order,CONCAT(N'https://media.example.invalid/day3/vehicle-',RIGHT(CONCAT(N'0000',l.vehicle_n),4),N'/photo-',ord.display_order,N'.jpg') image_reference,CONCAT(N'Synthetic exterior/interior view ',ord.display_order) caption FROM @ExpectedListings l JOIN (VALUES(1),(2),(3),(4)) ord(display_order) ON ord.display_order<=CASE WHEN l.n<=17 THEN 4 ELSE 3 END EXCEPT SELECT TRY_CONVERT(int,RIGHT(v.vin,12)),TRY_CONVERT(int,RIGHT(l.description,4)),im.display_order,im.image_reference,im.caption FROM marketplace.ListingImage im JOIN marketplace.VehicleListing l ON l.listing_id=im.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,TRY_CONVERT(int,RIGHT(l.description,4)) AS listing_n,im.display_order,im.image_reference,im.caption FROM marketplace.ListingImage im JOIN marketplace.VehicleListing l ON l.listing_id=im.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT l.vehicle_n,l.n,ord.display_order,CONCAT(N'https://media.example.invalid/day3/vehicle-',RIGHT(CONCAT(N'0000',l.vehicle_n),4),N'/photo-',ord.display_order,N'.jpg') AS image_reference,CONCAT(N'Synthetic exterior/interior view ',ord.display_order) AS caption FROM @ExpectedListings l JOIN (VALUES(1),(2),(3),(4)) ord(display_order) ON ord.display_order<=CASE WHEN l.n<=17 THEN 4 ELSE 3 END) AS unexpected_listing_image_rows));
DECLARE @ExpectedEnquiries TABLE(n int PRIMARY KEY,listing_n int,customer_n int,received_at datetime2(0),channel varchar(20),status varchar(20),message_reference nvarchar(300));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<99)
INSERT @ExpectedEnquiries
SELECT seq.n,((seq.n-1)%33)+1,((seq.n-1)%97)+1,DATEADD(hour,2,DATEADD(day,1,l.listed_at)),CASE seq.n%5 WHEN 0 THEN 'WEB' WHEN 1 THEN 'PHONE' WHEN 2 THEN 'BRANCH' WHEN 3 THEN 'PARTNER' ELSE 'OTHER' END,CASE seq.n%4 WHEN 0 THEN 'OPEN' WHEN 1 THEN 'IN_PROGRESS' WHEN 2 THEN 'RESOLVED' ELSE 'CLOSED' END,CONCAT(N'D3-ENQ-',RIGHT(CONCAT(N'0000',seq.n),4)) FROM n AS seq JOIN @ExpectedListings l ON l.n=((seq.n-1)%33)+1 OPTION(MAXRECURSION 120);
INSERT @ValidationFailures VALUES(N'Independent Phase 05 enquiry payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT l.n,e.customer_n,e.received_at,e.channel,e.status,e.message_reference FROM @ExpectedEnquiries e JOIN @ExpectedListings l ON l.n=e.listing_n EXCEPT SELECT TRY_CONVERT(int,RIGHT(listing.description,4)),TRY_CONVERT(int,RIGHT(c.display_name,4)),q.received_at,q.channel_code,q.status,q.message_reference FROM marketplace.CustomerEnquiry q JOIN marketplace.VehicleListing listing ON listing.listing_id=q.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=listing.vehicle_id JOIN core.Customer c ON c.customer_id=q.customer_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(listing.description,4)) AS listing_n,TRY_CONVERT(int,RIGHT(c.display_name,4)) AS customer_n,q.received_at,q.channel_code,q.status,q.message_reference FROM marketplace.CustomerEnquiry q JOIN marketplace.VehicleListing listing ON listing.listing_id=q.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=listing.vehicle_id JOIN core.Customer c ON c.customer_id=q.customer_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT l.n,e.customer_n,e.received_at,e.channel,e.status,e.message_reference FROM @ExpectedEnquiries e JOIN @ExpectedListings l ON l.n=e.listing_n) AS unexpected_enquiry_rows)
 +(SELECT COUNT_BIG(*) FROM marketplace.CustomerEnquiry q WHERE q.message_reference LIKE N'D3-ENQ-%' AND (q.assigned_employee_id IS NULL OR NOT EXISTS(SELECT 1 FROM core.Employee e WHERE e.employee_id=q.assigned_employee_id AND e.employee_code='D3-EMP-0002'))));
DECLARE @ExpectedReservations TABLE(n int PRIMARY KEY,listing_n int,customer_n int,created_at datetime2(0),expires_at datetime2(0),status varchar(20),released_at datetime2(0) NULL);
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<24), source AS
(SELECT seq.n,seq.n+3 AS listing_n,CASE WHEN seq.n<=7 THEN DATEADD(hour,seq.n,CONVERT(datetime2(0),'2026-10-30T09:00:00')) WHEN seq.n<=13 THEN DATEADD(day,40,DATEADD(day,5,l.inventory_since)) ELSE DATEADD(day,10,l.inventory_since) END AS created_at FROM n AS seq JOIN @ExpectedListings l ON l.n=seq.n+3)
INSERT @ExpectedReservations
SELECT s.n,s.listing_n,CASE WHEN s.n<=7 THEN 80+s.n WHEN s.n<=13 THEN 82+s.n ELSE 70+s.n END,s.created_at,DATEADD(day,3,s.created_at),CASE WHEN s.n<=7 THEN 'ACTIVE' WHEN s.n<=13 THEN 'CONVERTED' WHEN s.n<=18 THEN 'RELEASED' ELSE 'EXPIRED' END,
 CASE WHEN s.n<=7 THEN NULL WHEN s.n<=13 THEN DATEADD(minute,10,s.created_at) WHEN s.n<=18 THEN DATEADD(day,2,s.created_at) ELSE DATEADD(day,3,s.created_at) END FROM source s OPTION(MAXRECURSION 100);
INSERT @ValidationFailures VALUES(N'Independent Phase 05 reservation payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT l.n,r.customer_n,r.created_at,r.expires_at,r.status,r.released_at FROM @ExpectedReservations r JOIN @ExpectedListings l ON l.n=r.listing_n EXCEPT SELECT TRY_CONVERT(int,RIGHT(listing.description,4)),TRY_CONVERT(int,RIGHT(c.display_name,4)),r.created_at,r.expires_at,r.status,r.released_at FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing listing ON listing.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=listing.vehicle_id JOIN core.Customer c ON c.customer_id=r.customer_id WHERE v.vin LIKE 'D3SYN%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(listing.description,4)) AS listing_n,TRY_CONVERT(int,RIGHT(c.display_name,4)) AS customer_n,r.created_at,r.expires_at,r.status,r.released_at FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing listing ON listing.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=listing.vehicle_id JOIN core.Customer c ON c.customer_id=r.customer_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT l.n,r.customer_n,r.created_at,r.expires_at,r.status,r.released_at FROM @ExpectedReservations r JOIN @ExpectedListings l ON l.n=r.listing_n) AS unexpected_reservation_rows));
DECLARE @ExpectedOrders TABLE(n int PRIMARY KEY,vehicle_n int,buyer_n int,reservation_n int NULL,created_at datetime2(0),status varchar(20),confirmed_at datetime2(0) NULL,completed_at datetime2(0) NULL,cancelled_at datetime2(0) NULL,sale_price decimal(19,4));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<18), base AS
(SELECT n,n+10 vehicle_n,CASE WHEN n<=6 THEN 89+n WHEN n<=10 THEN 40+n ELSE 43+n END buyer_n,CASE WHEN n<=6 THEN n+7 END reservation_n,
 CASE WHEN n<=8 THEN 'COMPLETED' WHEN n IN(9,10,11,12,16,17) THEN 'CONFIRMED' WHEN n=13 THEN 'DRAFT' ELSE 'CANCELLED' END status FROM n)
INSERT @ExpectedOrders
SELECT b.n,b.vehicle_n,b.buyer_n,b.reservation_n,CASE WHEN b.n<=6 THEN DATEADD(minute,15,DATEADD(day,40,l.listed_at)) ELSE DATEADD(day,45,l.listed_at) END,b.status,
 CASE WHEN b.status IN('CONFIRMED','COMPLETED') THEN CASE WHEN b.n<=6 THEN DATEADD(minute,15,DATEADD(day,40,l.listed_at)) ELSE DATEADD(day,45,l.listed_at) END END,
 CASE WHEN b.status='COMPLETED' THEN DATEADD(day,5,CASE WHEN b.n<=6 THEN DATEADD(minute,15,DATEADD(day,40,l.listed_at)) ELSE DATEADD(day,45,l.listed_at) END) END,
 CASE WHEN b.status='CANCELLED' THEN DATEADD(day,1,CASE WHEN b.n<=6 THEN DATEADD(minute,15,DATEADD(day,40,l.listed_at)) ELSE DATEADD(day,45,l.listed_at) END) END,
 CONVERT(decimal(19,4),(500000+(b.vehicle_n%20)*25000)*1.03*0.985)
FROM base b JOIN @ExpectedListings l ON l.n=b.vehicle_n;
INSERT @ValidationFailures VALUES(N'Independent Phase 06 sales-order payload',
 (SELECT COUNT_BIG(*) FROM (SELECT e.buyer_n,e.created_at,e.status,e.confirmed_at,e.completed_at,e.cancelled_at,'INR' currency FROM @ExpectedOrders e EXCEPT SELECT TRY_CONVERT(int,RIGHT(c.display_name,4)),o.created_at,o.status,o.confirmed_at,o.completed_at,o.cancelled_at,o.currency_code FROM sales.SalesOrder o JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE c.display_name LIKE N'D3 Synthetic Customer %' AND o.created_at>='2026-02-01') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(c.display_name,4)) AS buyer_n,o.created_at,o.status,o.confirmed_at,o.completed_at,o.cancelled_at,o.currency_code FROM sales.SalesOrder o JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE c.display_name LIKE N'D3 Synthetic Customer %' AND o.created_at>='2026-02-01' EXCEPT SELECT buyer_n,created_at,status,confirmed_at,completed_at,cancelled_at,'INR' FROM @ExpectedOrders) AS unexpected_sales_order_rows));
INSERT @ValidationFailures VALUES(N'Independent Phase 06 order-item payload and reservation relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vehicle_n,e.buyer_n,e.sale_price,e.reservation_n FROM @ExpectedOrders e EXCEPT SELECT TRY_CONVERT(int,RIGHT(v.vin,12)),TRY_CONVERT(int,RIGHT(buyer.display_name,4)),i.sale_price,TRY_CONVERT(int,RIGHT(reservationListing.description,4))-3 FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN core.Customer buyer ON buyer.customer_id=o.buyer_customer_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id LEFT JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id LEFT JOIN marketplace.VehicleListing reservationListing ON reservationListing.listing_id=r.listing_id WHERE buyer.display_name LIKE N'D3 Synthetic Customer %' AND o.created_at>='2026-02-01') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,TRY_CONVERT(int,RIGHT(buyer.display_name,4)) AS buyer_n,i.sale_price,TRY_CONVERT(int,RIGHT(reservationListing.description,4))-3 AS reservation_n FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN core.Customer buyer ON buyer.customer_id=o.buyer_customer_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id LEFT JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id LEFT JOIN marketplace.VehicleListing reservationListing ON reservationListing.listing_id=r.listing_id WHERE buyer.display_name LIKE N'D3 Synthetic Customer %' AND o.created_at>='2026-02-01' EXCEPT SELECT vehicle_n,buyer_n,sale_price,reservation_n FROM @ExpectedOrders) AS unexpected_order_item_rows)
 +(SELECT COUNT_BIG(*) FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE o.created_at>='2026-02-01' AND (i.currency_code<>'INR' OR (o.status IN('COMPLETED','CONFIRMED','DRAFT','CANCELLED') AND (SELECT COUNT_BIG(*) FROM sales.SalesOrderItem x WHERE x.order_id=o.order_id)<>1))));
DECLARE @ExpectedPayments TABLE(n int PRIMARY KEY,order_n int,status varchar(20),amount decimal(19,4),initiated_at datetime2(0),settled_at datetime2(0) NULL,provider_reference varchar(100));
;WITH n AS(SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<26), mapping AS
(SELECT n,CASE WHEN n<=10 THEN (n+1)/2 WHEN n<=13 THEN n-5 WHEN n IN(14,15) THEN 9 WHEN n=16 THEN 10 WHEN n=17 THEN 11 WHEN n=18 THEN 12 WHEN n IN(19,20) THEN 13 WHEN n=21 THEN 14 WHEN n=22 THEN 15 WHEN n=23 THEN 16 WHEN n IN(24,25) THEN 17 ELSE 18 END order_n FROM n)
INSERT @ExpectedPayments
SELECT p.n,p.order_n,CASE WHEN p.n<=13 THEN 'SUCCEEDED' WHEN p.n IN(14,16,17,19,23,25) THEN 'PENDING' WHEN p.n=22 THEN 'REVERSED' ELSE 'FAILED' END,
 CASE WHEN p.n<=10 THEN o.sale_price/2 WHEN p.n<=13 THEN o.sale_price ELSE CONVERT(decimal(19,4),10000+p.n*500) END,
 DATEADD(minute,p.n*5,DATEADD(hour,1,o.created_at)),CASE WHEN p.n<=13 OR p.n=22 THEN DATEADD(minute,5,DATEADD(minute,p.n*5,DATEADD(hour,1,o.created_at))) END,CONCAT('D3-PAY-',RIGHT(CONCAT('0000',p.n),4))
FROM mapping p JOIN @ExpectedOrders o ON o.n=p.order_n OPTION(MAXRECURSION 100);
INSERT @ValidationFailures VALUES(N'Independent Phase 06 payment payload and order relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT e.provider_reference,e.amount,e.status,e.initiated_at,e.settled_at,'D3_SYNTHETIC' provider_code,CASE WHEN e.n%2=0 THEN 'CARD' ELSE 'UPI' END method FROM @ExpectedPayments e EXCEPT SELECT p.provider_reference,p.amount,p.status,p.initiated_at,p.settled_at,p.provider_code,p.payment_method_code FROM finance.Payment p WHERE p.provider_code='D3_SYNTHETIC' AND p.provider_reference LIKE 'D3-PAY-%') x)
 +(SELECT COUNT_BIG(*) FROM (SELECT p.provider_reference,p.amount,p.status,p.initiated_at,p.settled_at,p.provider_code,p.payment_method_code FROM finance.Payment p WHERE p.provider_code='D3_SYNTHETIC' AND p.provider_reference LIKE 'D3-PAY-%' EXCEPT SELECT e.provider_reference,e.amount,e.status,e.initiated_at,e.settled_at,'D3_SYNTHETIC',CASE WHEN e.n%2=0 THEN 'CARD' ELSE 'UPI' END FROM @ExpectedPayments e) x)
 +(SELECT COUNT_BIG(*) FROM @ExpectedPayments e JOIN @ExpectedOrders o ON o.n=e.order_n LEFT JOIN sales.SalesOrder so ON so.created_at=o.created_at AND so.buyer_customer_id=(SELECT customer_id FROM core.Customer WHERE display_name=CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',o.buyer_n),4))) LEFT JOIN finance.Payment p ON p.provider_code='D3_SYNTHETIC' AND p.provider_reference=e.provider_reference WHERE so.order_id IS NULL OR p.order_id<>so.order_id));
DECLARE @ExpectedRefunds TABLE(n int PRIMARY KEY,payment_n int,amount decimal(19,4),status varchar(20),requested_at datetime2(0),settled_at datetime2(0) NULL,provider_reference varchar(100));
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
INSERT @ExpectedRefunds
SELECT refund_plan.n,refund_plan.payment_n,refund_plan.amount,refund_plan.status,
       DATEADD(day,refund_plan.days_after_settlement,p.settled_at),
       CASE WHEN refund_plan.status='SUCCEEDED' THEN DATEADD(minute,5,DATEADD(day,refund_plan.days_after_settlement,p.settled_at)) END,
       CONCAT('D3-REF-',RIGHT(CONCAT('0000',refund_plan.n),4))
FROM RefundPlan AS refund_plan
JOIN @ExpectedPayments AS p ON p.n=refund_plan.payment_n;
INSERT @ValidationFailures VALUES(N'Independent Phase 06 refund payload and payment relationship',
 (SELECT COUNT_BIG(*) FROM (SELECT e.provider_reference,e.amount,'INR' AS currency_code,e.status,e.requested_at,e.settled_at,p.provider_reference payment_ref FROM @ExpectedRefunds e JOIN @ExpectedPayments p ON p.n=e.payment_n EXCEPT SELECT r.provider_reference,r.amount,r.currency_code,r.status,r.requested_at,r.settled_at,p.provider_reference FROM finance.Refund r JOIN finance.Payment p ON p.payment_id=r.payment_id WHERE r.provider_reference LIKE 'D3-REF-%') x)
  +(SELECT COUNT_BIG(*) FROM (SELECT r.provider_reference,r.amount,r.currency_code,r.status,r.requested_at,r.settled_at,p.provider_reference AS payment_provider_reference FROM finance.Refund r JOIN finance.Payment p ON p.payment_id=r.payment_id WHERE r.provider_reference LIKE 'D3-REF-%' EXCEPT SELECT e.provider_reference,e.amount,'INR',e.status,e.requested_at,e.settled_at,p.provider_reference AS payment_provider_reference FROM @ExpectedRefunds e JOIN @ExpectedPayments p ON p.n=e.payment_n) AS unexpected_refund_rows));
DECLARE @ExpectedFulfillment TABLE(n int PRIMARY KEY,vehicle_n int,buyer_n int,transfer_status varchar(20),submitted_at datetime2(0),transfer_completed_at datetime2(0) NULL,delivery_status varchar(20),scheduled_at datetime2(0),delivery_completed_at datetime2(0) NULL,branch_code varchar(30),address_line1 nvarchar(200),transfer_reference varchar(100),delivery_reference varchar(100));
INSERT @ExpectedFulfillment
SELECT e.n,e.vehicle_n,e.buyer_n,
 CASE WHEN e.n<=8 THEN 'COMPLETED' WHEN e.n<=10 THEN 'IN_PROGRESS' WHEN e.n=11 THEN 'SUBMITTED' ELSE 'REJECTED' END,
 DATEADD(day,1,e.created_at),CASE WHEN e.n<=8 THEN DATEADD(day,3,e.created_at) END,
 CASE WHEN e.n<=8 THEN 'COMPLETED' WHEN e.n<=10 THEN 'SCHEDULED' WHEN e.n=11 THEN 'IN_TRANSIT' ELSE 'FAILED' END,
 DATEADD(day,4,e.created_at),CASE WHEN e.n<=8 THEN DATEADD(hour,1,DATEADD(day,4,e.created_at)) END,
 l.branch_code,CONCAT(N'D3 Synthetic Address ',RIGHT(CONCAT(N'0000',e.buyer_n),4)),CONCAT('D3-TR-',RIGHT(CONCAT('0000',e.n),4)),CONCAT('D3-HAND-',RIGHT(CONCAT('0000',e.n),4))
FROM @ExpectedOrders e JOIN @ExpectedListings l ON l.n=e.vehicle_n WHERE e.n<=12;
INSERT @ValidationFailures VALUES(N'Independent Phase 06 ownership-transfer payload and lineage',
 (SELECT COUNT_BIG(*) FROM (SELECT f.transfer_reference,f.transfer_status,f.submitted_at,f.transfer_completed_at,f.vehicle_n,f.buyer_n FROM @ExpectedFulfillment f EXCEPT SELECT t.authority_reference,t.status,t.submitted_at,t.completed_at,TRY_CONVERT(int,RIGHT(v.vin,12)),TRY_CONVERT(int,RIGHT(buyer.display_name,4)) FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.Customer buyer ON buyer.customer_id=o.buyer_customer_id WHERE t.authority_reference LIKE 'D3-TR-%') x)
  +(SELECT COUNT_BIG(*) FROM (SELECT t.authority_reference,t.status,t.submitted_at,t.completed_at,TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,TRY_CONVERT(int,RIGHT(buyer.display_name,4)) AS buyer_n FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.Customer buyer ON buyer.customer_id=o.buyer_customer_id WHERE t.authority_reference LIKE 'D3-TR-%' EXCEPT SELECT transfer_reference,transfer_status,submitted_at,transfer_completed_at,vehicle_n,buyer_n FROM @ExpectedFulfillment) AS unexpected_transfer_rows)
 +(SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.Customer seller ON seller.customer_id=t.from_customer_id WHERE t.authority_reference LIKE 'D3-TR-%' AND seller.display_name<>CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',TRY_CONVERT(int,RIGHT(v.vin,12))),4))));
INSERT @ValidationFailures VALUES(N'Independent Phase 06 delivery payload and relationships',
 (SELECT COUNT_BIG(*) FROM (SELECT f.delivery_reference,f.buyer_n,f.delivery_status,f.scheduled_at,f.delivery_completed_at,f.branch_code,f.address_line1,f.vehicle_n FROM @ExpectedFulfillment f EXCEPT SELECT d.handover_reference,TRY_CONVERT(int,RIGHT(buyer.display_name,4)),d.status,d.scheduled_at,d.completed_at,b.branch_code,a.address_line1,TRY_CONVERT(int,RIGHT(v.vin,12)) FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.Customer buyer ON buyer.customer_id=o.buyer_customer_id LEFT JOIN core.Branch b ON b.branch_id=d.branch_id LEFT JOIN core.CustomerAddress a ON a.address_id=d.delivery_address_id WHERE d.handover_reference LIKE 'D3-HAND-%') x)
  +(SELECT COUNT_BIG(*) FROM (SELECT d.handover_reference,TRY_CONVERT(int,RIGHT(buyer.display_name,4)) AS buyer_n,d.status,d.scheduled_at,d.completed_at,b.branch_code,a.address_line1,TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.Customer buyer ON buyer.customer_id=o.buyer_customer_id LEFT JOIN core.Branch b ON b.branch_id=d.branch_id LEFT JOIN core.CustomerAddress a ON a.address_id=d.delivery_address_id WHERE d.handover_reference LIKE 'D3-HAND-%' EXCEPT SELECT delivery_reference,buyer_n,delivery_status,scheduled_at,delivery_completed_at,branch_code,address_line1,vehicle_n FROM @ExpectedFulfillment) AS unexpected_delivery_rows)
 +(SELECT COUNT_BIG(*) FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE d.handover_reference LIKE 'D3-HAND-%' AND (d.recipient_customer_id<>o.buyer_customer_id OR (d.status='COMPLETED' AND (d.completed_at IS NULL OR d.scheduled_at IS NULL)))));
DECLARE @ExpectedMovements TABLE(vehicle_n int,event_type varchar(20),from_branch_code varchar(30) NULL,from_location varchar(30) NULL,to_branch_code varchar(30) NULL,to_location varchar(30) NULL,employee_code varchar(30),occurred_at datetime2(0),reason nvarchar(200));
INSERT @ExpectedMovements
SELECT v.n,'RECEIPT',NULL,NULL,v.branch_code,'D3-YARD-A','D3-EMP-0011',DATEADD(minute,10,DATEADD(hour,2,DATEADD(day,2,o.offered_at))),N'Day 3 synthetic acquisition receipt' FROM @ExpectedVehicles v JOIN @ExpectedOffers o ON o.n=v.n WHERE v.n<=31
UNION ALL SELECT v.n,'TRANSFER',v.branch_code,'D3-YARD-A',l.branch_code,'D3-YARD-B','D3-EMP-0011',DATEADD(day,2,DATEADD(minute,10,DATEADD(hour,2,DATEADD(day,2,o.offered_at)))),N'Day 3 synthetic inter-branch transfer' FROM @ExpectedVehicles v JOIN @ExpectedOffers o ON o.n=v.n JOIN @ExpectedListings l ON l.n=v.n WHERE v.n<=23
UNION ALL SELECT f.vehicle_n,'DISPATCH',l.branch_code,'D3-YARD-B',NULL,NULL,'D3-EMP-0011',f.transfer_completed_at,N'Day 3 synthetic completed-sale dispatch' FROM @ExpectedFulfillment f JOIN @ExpectedListings l ON l.n=f.vehicle_n WHERE f.n<=8;
INSERT @ValidationFailures VALUES(N'Independent complete Phase 04/06 inventory-movement ledger',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vehicle_n,e.event_type,e.from_branch_code,e.from_location,e.to_branch_code,e.to_location,e.employee_code,e.occurred_at,e.reason FROM @ExpectedMovements e EXCEPT SELECT TRY_CONVERT(int,RIGHT(v.vin,12)),m.movement_type,fb.branch_code,m.from_location_code,tb.branch_code,m.to_location_code,emp.employee_code,m.occurred_at,m.reason FROM inventory.InventoryMovement m JOIN inventory.Inventory inv ON inv.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id LEFT JOIN core.Branch fb ON fb.branch_id=m.from_branch_id LEFT JOIN core.Branch tb ON tb.branch_id=m.to_branch_id JOIN core.Employee emp ON emp.employee_id=m.employee_id WHERE v.vin LIKE 'D3SYN%') x)
  +(SELECT COUNT_BIG(*) FROM (SELECT TRY_CONVERT(int,RIGHT(v.vin,12)) AS vehicle_n,m.movement_type,fb.branch_code AS from_branch_code,m.from_location_code,tb.branch_code AS to_branch_code,m.to_location_code,emp.employee_code,m.occurred_at,m.reason FROM inventory.InventoryMovement m JOIN inventory.Inventory inv ON inv.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id LEFT JOIN core.Branch fb ON fb.branch_id=m.from_branch_id LEFT JOIN core.Branch tb ON tb.branch_id=m.to_branch_id JOIN core.Employee emp ON emp.employee_id=m.employee_id WHERE v.vin LIKE 'D3SYN%' EXCEPT SELECT vehicle_n,event_type,from_branch_code,from_location,to_branch_code,to_location,employee_code,occurred_at,reason FROM @ExpectedMovements) AS unexpected_movement_rows));
INSERT @ValidationFailures VALUES(N'Independent final inventory position and lifecycle payload',
 (SELECT COUNT_BIG(*) FROM @ExpectedVehicles e JOIN @ExpectedOffers o ON o.n=e.n JOIN @ExpectedListings l ON l.n=e.n LEFT JOIN inventory.Inventory inv ON inv.vehicle_id=(SELECT source_vehicle.vehicle_id FROM vehicle.Vehicle AS source_vehicle WHERE source_vehicle.vin=e.vin) LEFT JOIN core.Branch b ON b.branch_id=inv.branch_id
  WHERE e.n<=31 AND (inv.inventory_id IS NULL OR inv.since_at<>DATEADD(minute,10,DATEADD(hour,2,DATEADD(day,2,o.offered_at))) OR b.branch_code<>l.branch_code OR inv.location_code<>CASE WHEN e.n<=23 THEN 'D3-YARD-B' ELSE 'D3-YARD-A' END OR inv.status<>CASE WHEN e.n BETWEEN 4 AND 10 THEN 'HELD' WHEN e.n BETWEEN 11 AND 18 THEN 'SOLD' ELSE 'AVAILABLE' END)));
INSERT @ValidationFailures VALUES(N'Independent complete ownership-history payload and final owner',
 (SELECT COUNT_BIG(*) FROM (SELECT e.vin AS vehicle_vin,e.initial_owner AS owner_name,e.created_at AS valid_from,CASE WHEN e.n BETWEEN 11 AND 18 THEN f.transfer_completed_at END AS valid_to,'REGISTERED_OWNER' AS basis_code,N'Day 3 synthetic initial registered-owner fixture' AS evidence_reference FROM @ExpectedVehicles e LEFT JOIN @ExpectedFulfillment f ON f.vehicle_n=e.n AND f.n<=8 EXCEPT SELECT v.vin AS vehicle_vin,c.display_name AS owner_name,h.valid_from,h.valid_to,h.basis_code,h.evidence_reference FROM vehicle.VehicleOwnershipHistory h JOIN vehicle.Vehicle v ON v.vehicle_id=h.vehicle_id JOIN core.Customer c ON c.customer_id=h.customer_id WHERE v.vin LIKE 'D3SYN%' AND h.basis_code='REGISTERED_OWNER') AS missing_registered_owner_rows)
  +(SELECT COUNT_BIG(*) FROM (SELECT v.vin AS vehicle_vin,c.display_name AS owner_name,h.valid_from,h.valid_to,h.basis_code,h.evidence_reference FROM vehicle.VehicleOwnershipHistory h JOIN vehicle.Vehicle v ON v.vehicle_id=h.vehicle_id JOIN core.Customer c ON c.customer_id=h.customer_id WHERE v.vin LIKE 'D3SYN%' AND h.basis_code='REGISTERED_OWNER' EXCEPT SELECT e.vin AS vehicle_vin,e.initial_owner AS owner_name,e.created_at AS valid_from,CASE WHEN e.n BETWEEN 11 AND 18 THEN f.transfer_completed_at END AS valid_to,'REGISTERED_OWNER' AS basis_code,N'Day 3 synthetic initial registered-owner fixture' AS evidence_reference FROM @ExpectedVehicles e LEFT JOIN @ExpectedFulfillment f ON f.vehicle_n=e.n AND f.n<=8) AS unexpected_registered_owner_rows)
  +(SELECT COUNT_BIG(*) FROM (SELECT ev.vin AS vehicle_vin,CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',f.buyer_n),4)) AS owner_name,f.transfer_completed_at AS valid_from,CONVERT(datetime2(0),NULL) AS valid_to,'SALE' AS basis_code,f.transfer_reference AS evidence_reference FROM @ExpectedFulfillment f JOIN @ExpectedVehicles ev ON ev.n=f.vehicle_n WHERE f.n<=8 EXCEPT SELECT v.vin AS vehicle_vin,c.display_name AS owner_name,h.valid_from,h.valid_to,h.basis_code,h.evidence_reference FROM vehicle.VehicleOwnershipHistory h JOIN vehicle.Vehicle v ON v.vehicle_id=h.vehicle_id JOIN core.Customer c ON c.customer_id=h.customer_id WHERE v.vin LIKE 'D3SYN%' AND h.basis_code='SALE') AS expected_sale_owner_rows)
  +(SELECT COUNT_BIG(*) FROM (SELECT v.vin AS vehicle_vin,c.display_name AS owner_name,h.valid_from,h.valid_to,h.basis_code,h.evidence_reference FROM vehicle.VehicleOwnershipHistory h JOIN vehicle.Vehicle v ON v.vehicle_id=h.vehicle_id JOIN core.Customer c ON c.customer_id=h.customer_id WHERE v.vin LIKE 'D3SYN%' AND h.basis_code='SALE' EXCEPT SELECT ev.vin AS vehicle_vin,CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',f.buyer_n),4)) AS owner_name,f.transfer_completed_at AS valid_from,CONVERT(datetime2(0),NULL) AS valid_to,'SALE' AS basis_code,f.transfer_reference AS evidence_reference FROM @ExpectedFulfillment f JOIN @ExpectedVehicles ev ON ev.n=f.vehicle_n WHERE f.n<=8) AS unexpected_sale_owner_rows)
 +(SELECT COUNT_BIG(*) FROM @ExpectedVehicles e JOIN vehicle.Vehicle v ON v.vin=e.vin JOIN core.Customer owner ON owner.customer_id=v.current_owner_customer_id WHERE owner.display_name<>CASE WHEN e.n BETWEEN 11 AND 16 THEN CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',79+e.n),4)) WHEN e.n BETWEEN 17 AND 18 THEN CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',30+e.n),4)) ELSE e.initial_owner END));
INSERT INTO @ValidationFailures VALUES(N'Cumulative table counts differ from exact documented targets',@CountMismatchCount);
INSERT INTO @ValidationFailures VALUES(N'Database is not online and writable',
 (SELECT COUNT_BIG(*) FROM sys.databases WHERE database_id=DB_ID() AND (state_desc<>'ONLINE' OR is_read_only=1)));
INSERT INTO @ValidationFailures VALUES(N'Disabled or untrusted foreign keys',
 (SELECT COUNT_BIG(*) FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1));
INSERT INTO @ValidationFailures VALUES(N'Disabled or untrusted check constraints',
 (SELECT COUNT_BIG(*) FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1));
INSERT INTO @ValidationFailures VALUES(N'Disabled indexes',
 (SELECT COUNT_BIG(*) FROM sys.indexes WHERE index_id>0 AND is_disabled=1));
INSERT INTO @ValidationFailures VALUES(N'Missing/duplicate D3 vehicles',
 (SELECT ABS(COUNT_BIG(*)-67) FROM vehicle.Vehicle WHERE vin LIKE 'D3SYN%'));
INSERT INTO @ValidationFailures VALUES(N'Missing/duplicate D3 employees',
 (SELECT ABS(COUNT_BIG(*)-21) FROM core.Employee WHERE employee_code LIKE 'D3-EMP-%'));
INSERT INTO @ValidationFailures VALUES(N'Missing/duplicate D3 customers',
 (SELECT ABS(COUNT_BIG(*)-97) FROM core.Customer WHERE display_name LIKE N'D3 Synthetic Customer %'));
INSERT INTO @ValidationFailures VALUES(N'D3 inspection/report/item/defect/valuation cohorts differ',
 (SELECT ABS(COUNT_BIG(*)-62) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')
 +(SELECT ABS(COUNT_BIG(*)-57) FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')
 +(SELECT ABS(COUNT_BIG(*)-411) FROM inspection.InspectionItem it JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')
 +(SELECT ABS(COUNT_BIG(*)-99) FROM inspection.Defect WHERE description LIKE N'D3 synthetic defect %')
 +(SELECT ABS(COUNT_BIG(*)-52) FROM inspection.VehicleValuation val JOIN vehicle.Vehicle v ON v.vehicle_id=val.vehicle_id WHERE v.vin LIKE 'D3SYN%'));
INSERT INTO @ValidationFailures VALUES(N'D3 acquisition/inventory/movement cohorts differ',
 (SELECT ABS(COUNT_BIG(*)-49) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')
 +(SELECT ABS(COUNT_BIG(*)-34) FROM acquisition.PurchaseAgreement a JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')
 +(SELECT ABS(COUNT_BIG(*)-31) FROM acquisition.VehicleAcquisition ac JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%')
 +(SELECT ABS(COUNT_BIG(*)-31) FROM inventory.Inventory i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')
  +(SELECT ABS(COUNT_BIG(*)-62) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')
  +(SELECT ABS(COUNT_BIG(*)-31) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND m.movement_type='RECEIPT')
  +(SELECT ABS(COUNT_BIG(*)-23) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND m.movement_type='TRANSFER')
  +(SELECT ABS(COUNT_BIG(*)-8) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND m.movement_type='DISPATCH')
  +(SELECT COUNT_BIG(*) FROM inventory.InventoryMovement m JOIN inventory.Inventory i ON i.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND m.movement_type NOT IN ('RECEIPT','TRANSFER','DISPATCH')));
INSERT INTO @ValidationFailures VALUES(N'D3 marketplace cohorts differ',
 (SELECT ABS(COUNT_BIG(*)-34) FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.description LIKE N'Day 3 synthetic listing %')
 +(SELECT ABS(COUNT_BIG(*)-119) FROM marketplace.ListingImage im JOIN marketplace.VehicleListing l ON l.listing_id=im.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.description LIKE N'Day 3 synthetic listing %')
 +(SELECT ABS(COUNT_BIG(*)-99) FROM marketplace.CustomerEnquiry WHERE message_reference LIKE N'D3-ENQ-%')
 +(SELECT ABS(COUNT_BIG(*)-24) FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND r.created_at>='2026-02-01'));
INSERT INTO @ValidationFailures VALUES(N'D3 sales/finance/delivery cohorts differ',
  (SELECT ABS(COUNT_BIG(*)-18) FROM sales.SalesOrder o JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE c.display_name LIKE N'D3 Synthetic Customer %' AND o.created_at>='2026-02-01')
  +(SELECT ABS(COUNT_BIG(*)-18) FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE c.display_name LIKE N'D3 Synthetic Customer %' AND o.created_at>='2026-02-01')
  +(SELECT ABS(COUNT_BIG(*)-26) FROM finance.Payment WHERE provider_code='D3_SYNTHETIC' AND provider_reference LIKE 'D3-PAY-%')
  +(SELECT ABS(COUNT_BIG(*)-5) FROM finance.Refund WHERE provider_reference LIKE 'D3-REF-%')
  +(SELECT ABS(COUNT_BIG(*)-12) FROM delivery.OwnershipTransfer WHERE authority_reference LIKE 'D3-TR-%')
  +(SELECT ABS(COUNT_BIG(*)-12) FROM delivery.VehicleDelivery WHERE handover_reference LIKE 'D3-HAND-%'));
INSERT INTO @ValidationFailures VALUES(N'Orphan or mismatched D3 defect/report items',
 (SELECT COUNT_BIG(*) FROM inspection.Defect d LEFT JOIN inspection.InspectionItem i ON i.inspection_item_id=d.inspection_item_id WHERE d.description LIKE N'D3 synthetic defect %' AND (i.inspection_item_id IS NULL OR d.report_id<>i.report_id)));
INSERT INTO @ValidationFailures VALUES(N'D3 valuation vehicle/report mismatch',
 (SELECT COUNT_BIG(*) FROM inspection.VehicleValuation val JOIN inspection.InspectionReport r ON r.report_id=val.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=val.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND val.vehicle_id<>i.vehicle_id));
INSERT INTO @ValidationFailures VALUES(N'D3 acquisition seller/vehicle/agreement mismatch',
 (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN acquisition.PurchaseAgreement a ON a.agreement_id=ac.agreement_id JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=ac.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND (ac.vehicle_id<>s.vehicle_id OR ac.seller_customer_id<>s.seller_customer_id OR a.seller_customer_id<>s.seller_customer_id OR o.seller_customer_id<>s.seller_customer_id OR a.status<>'SIGNED' OR o.status<>'ACCEPTED')));
INSERT INTO @ValidationFailures VALUES(N'D3 inventory without acquisition',
 (SELECT COUNT_BIG(*) FROM inventory.Inventory inv JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND NOT EXISTS(SELECT 1 FROM acquisition.VehicleAcquisition ac WHERE ac.vehicle_id=inv.vehicle_id)));
INSERT INTO @ValidationFailures VALUES(N'Whole-database defect/report item mismatch',
 (SELECT COUNT_BIG(*) FROM inspection.Defect d JOIN inspection.InspectionItem i ON i.inspection_item_id=d.inspection_item_id WHERE d.report_id<>i.report_id));
INSERT INTO @ValidationFailures VALUES(N'Whole-database valuation/report vehicle mismatch',
 (SELECT COUNT_BIG(*) FROM inspection.VehicleValuation val JOIN inspection.InspectionReport r ON r.report_id=val.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id WHERE val.vehicle_id<>i.vehicle_id));
INSERT INTO @ValidationFailures VALUES(N'Whole-database acquisition seller/vehicle/agreement mismatch',
 (SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition ac JOIN acquisition.PurchaseAgreement a ON a.agreement_id=ac.agreement_id JOIN acquisition.PurchaseOffer o ON o.offer_id=a.offer_id JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id WHERE ac.vehicle_id<>s.vehicle_id OR ac.seller_customer_id<>s.seller_customer_id OR a.seller_customer_id<>s.seller_customer_id OR o.seller_customer_id<>s.seller_customer_id OR a.status<>'SIGNED' OR o.status<>'ACCEPTED'));
INSERT INTO @ValidationFailures VALUES(N'Whole-database inventory without acquisition',
 (SELECT COUNT_BIG(*) FROM inventory.Inventory inv WHERE NOT EXISTS(SELECT 1 FROM acquisition.VehicleAcquisition ac WHERE ac.vehicle_id=inv.vehicle_id)));
INSERT INTO @ValidationFailures VALUES(N'Multiple active D3 listings/reservations per vehicle',
 (SELECT COUNT_BIG(*) FROM (SELECT l.vehicle_id FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND l.status='ACTIVE' GROUP BY l.vehicle_id HAVING COUNT_BIG(*)>1) q)
 +(SELECT COUNT_BIG(*) FROM (SELECT l.vehicle_id FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE 'D3SYN%' AND r.status='ACTIVE' GROUP BY l.vehicle_id HAVING COUNT_BIG(*)>1) q));
INSERT INTO @ValidationFailures VALUES(N'D3 order/reservation buyer or vehicle mismatch',
 (SELECT COUNT_BIG(*) FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id WHERE o.buyer_customer_id<>r.customer_id OR i.vehicle_id<>l.vehicle_id));
INSERT INTO @ValidationFailures VALUES(N'D3 payment/order currency or completed sale amount mismatch',
 (SELECT COUNT_BIG(*) FROM finance.Payment p JOIN sales.SalesOrder o ON o.order_id=p.order_id WHERE p.currency_code<>o.currency_code)
 +(SELECT COUNT_BIG(*) FROM (SELECT o.order_id FROM sales.SalesOrder o JOIN sales.SalesOrderItem i ON i.order_id=o.order_id LEFT JOIN finance.Payment p ON p.order_id=o.order_id WHERE o.status='COMPLETED' GROUP BY o.order_id,i.sale_price HAVING COALESCE(SUM(CASE WHEN p.status='SUCCEEDED' THEN p.amount ELSE 0 END),0)<>i.sale_price) q));
INSERT INTO @ValidationFailures VALUES(N'Successful refunds exceed successful payment capture',
 (SELECT COUNT_BIG(*) FROM (SELECT p.payment_id FROM finance.Payment p JOIN finance.Refund r ON r.payment_id=p.payment_id WHERE p.status='SUCCEEDED' AND r.status='SUCCEEDED' GROUP BY p.payment_id,p.amount HAVING SUM(r.amount)>p.amount) q));
INSERT INTO @ValidationFailures VALUES(N'D3 completed transfer/delivery lacks required state or buyer match',
 (SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE t.to_customer_id<>o.buyer_customer_id OR (t.status='COMPLETED' AND (t.completed_at IS NULL OR t.authority_reference IS NULL)))
 +(SELECT COUNT_BIG(*) FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE d.recipient_customer_id<>o.buyer_customer_id OR (d.status='COMPLETED' AND (d.completed_at IS NULL OR d.scheduled_at IS NULL)) OR o.status='CANCELLED'));
INSERT INTO @ValidationFailures VALUES(N'Completed transfer ownership history/current owner mismatch',
 (SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE t.status='COMPLETED' AND (t.to_customer_id<>o.buyer_customer_id OR NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory prior WHERE prior.vehicle_id=i.vehicle_id AND prior.customer_id=t.from_customer_id AND prior.valid_to=t.completed_at)))
 +(SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=v.vehicle_id AND h.valid_to IS NULL WHERE t.status='COMPLETED' AND h.customer_id<>t.to_customer_id));
INSERT INTO @ValidationFailures VALUES(N'Completed delivery chronology invalid',
 (SELECT COUNT_BIG(*) FROM delivery.VehicleDelivery WHERE status='COMPLETED' AND (completed_at IS NULL OR scheduled_at IS NULL OR completed_at<scheduled_at)));
INSERT INTO @ValidationFailures VALUES(N'Overlapping ownership or registration validity periods',
 (SELECT COUNT_BIG(*) FROM vehicle.VehicleOwnershipHistory h1 JOIN vehicle.VehicleOwnershipHistory h2 ON h1.vehicle_id=h2.vehicle_id AND h1.ownership_history_id<h2.ownership_history_id AND h1.valid_from<COALESCE(h2.valid_to,CONVERT(datetime2(0),'9999-12-31T23:59:59')) AND h2.valid_from<COALESCE(h1.valid_to,CONVERT(datetime2(0),'9999-12-31T23:59:59')))
 +(SELECT COUNT_BIG(*) FROM vehicle.VehicleRegistration r1 JOIN vehicle.VehicleRegistration r2 ON r1.registration_number=r2.registration_number AND r1.registration_id<r2.registration_id AND r1.valid_from<COALESCE(r2.valid_to,CONVERT(date,'99991231',112)) AND r2.valid_from<COALESCE(r1.valid_to,CONVERT(date,'99991231',112))));
INSERT INTO @ValidationFailures VALUES(N'Current vehicle owner lacks matching active ownership history',
 (SELECT COUNT_BIG(*) FROM vehicle.Vehicle v WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=v.current_owner_customer_id AND h.valid_to IS NULL)));
INSERT INTO @ValidationFailures VALUES(N'Active listing/reservation lifecycle has unavailable inventory',
 (SELECT COUNT_BIG(*) FROM marketplace.VehicleListing l WHERE l.status='ACTIVE' AND NOT EXISTS(SELECT 1 FROM inventory.Inventory i WHERE i.vehicle_id=l.vehicle_id AND i.status IN ('AVAILABLE','HELD','PREPARATION')))
 +(SELECT COUNT_BIG(*) FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id WHERE r.status='ACTIVE' AND l.status<>'ACTIVE'));
INSERT INTO @ValidationFailures VALUES(N'Whole-database active listing has unavailable inventory',
 (SELECT COUNT_BIG(*) FROM marketplace.VehicleListing l WHERE l.status='ACTIVE' AND NOT EXISTS(SELECT 1 FROM inventory.Inventory i WHERE i.vehicle_id=l.vehicle_id AND i.status IN ('AVAILABLE','HELD','PREPARATION'))));
INSERT INTO @ValidationFailures VALUES(N'Whole-database duplicate active listings or reservations',
 (SELECT COUNT_BIG(*) FROM (SELECT vehicle_id FROM marketplace.VehicleListing WHERE status='ACTIVE' GROUP BY vehicle_id HAVING COUNT_BIG(*)>1) q)
 +(SELECT COUNT_BIG(*) FROM (SELECT l.vehicle_id FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id WHERE r.status='ACTIVE' GROUP BY l.vehicle_id HAVING COUNT_BIG(*)>1) q));
INSERT INTO @ValidationFailures VALUES(N'Whole-database order/reservation buyer or vehicle mismatch',
 (SELECT COUNT_BIG(*) FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id JOIN marketplace.VehicleReservation r ON r.reservation_id=i.reservation_id JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id WHERE o.buyer_customer_id<>r.customer_id OR i.vehicle_id<>l.vehicle_id));
INSERT INTO @ValidationFailures VALUES(N'Inventory movement chain or completed-sale uniqueness failures',
 (SELECT COUNT_BIG(*) FROM (SELECT m.movement_id,m.movement_type,m.from_branch_id,m.from_location_code,
       LAG(m.to_branch_id) OVER(PARTITION BY m.inventory_id ORDER BY m.occurred_at,m.movement_id) AS previous_to_branch,
       LAG(m.to_location_code) OVER(PARTITION BY m.inventory_id ORDER BY m.occurred_at,m.movement_id) AS previous_to_location
   FROM inventory.InventoryMovement m) chain
  WHERE movement_type IN ('TRANSFER','DISPATCH') AND
       (previous_to_branch IS NULL OR previous_to_location IS NULL OR from_branch_id IS NULL OR from_location_code IS NULL
        OR from_branch_id<>previous_to_branch OR from_location_code<>previous_to_location))
  +(SELECT COUNT_BIG(*) FROM (SELECT inventory_id,occurred_at FROM inventory.InventoryMovement GROUP BY inventory_id,occurred_at HAVING COUNT_BIG(*)>1) q)
  +(SELECT COUNT_BIG(*) FROM (SELECT inventory_id FROM inventory.InventoryMovement WHERE movement_type NOT IN ('RECEIPT','TRANSFER','DISPATCH','ADJUSTMENT') GROUP BY inventory_id) q)
 +(SELECT COUNT_BIG(*) FROM (SELECT i.vehicle_id FROM sales.SalesOrderItem i JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE o.status='COMPLETED' GROUP BY i.vehicle_id HAVING COUNT_BIG(*)>1) q));
INSERT INTO @ValidationFailures VALUES(N'Inventory position differs from last recorded destination',
 (SELECT COUNT_BIG(*) FROM inventory.Inventory inv JOIN vehicle.Vehicle v ON v.vehicle_id=inv.vehicle_id
  OUTER APPLY (SELECT TOP (1) m.to_branch_id,m.to_location_code FROM inventory.InventoryMovement m WHERE m.inventory_id=inv.inventory_id AND m.to_branch_id IS NOT NULL AND m.to_location_code IS NOT NULL ORDER BY m.occurred_at DESC,m.movement_id DESC) lastPosition
  WHERE v.vin LIKE 'D3SYN%' AND (lastPosition.to_branch_id IS NULL OR inv.branch_id<>lastPosition.to_branch_id OR inv.location_code<>lastPosition.to_location_code)));
INSERT INTO @ValidationFailures VALUES(N'Multiple transfer or delivery records for one order item',
 (SELECT COUNT_BIG(*) FROM (SELECT order_item_id FROM delivery.OwnershipTransfer GROUP BY order_item_id HAVING COUNT_BIG(*)>1) q)
 +(SELECT COUNT_BIG(*) FROM (SELECT order_item_id FROM delivery.VehicleDelivery GROUP BY order_item_id HAVING COUNT_BIG(*)>1) q));
INSERT INTO @ValidationFailures VALUES(N'DBCC constraint violations',(SELECT COUNT_BIG(*) FROM @DbccViolations));
INSERT INTO @ValidationFailures VALUES(N'Whole-database ownership history overlaps',
 (SELECT COUNT_BIG(*) FROM vehicle.VehicleOwnershipHistory h1 JOIN vehicle.VehicleOwnershipHistory h2 ON h1.vehicle_id=h2.vehicle_id AND h1.ownership_history_id<h2.ownership_history_id AND h1.valid_from<COALESCE(h2.valid_to,CONVERT(datetime2(0),'9999-12-31T23:59:59')) AND h2.valid_from<COALESCE(h1.valid_to,CONVERT(datetime2(0),'9999-12-31T23:59:59'))));
INSERT INTO @ValidationFailures VALUES(N'Whole-database current owner lacks active ownership history',
 (SELECT COUNT_BIG(*) FROM vehicle.Vehicle v WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=v.current_owner_customer_id AND h.valid_to IS NULL)));
INSERT INTO @ValidationFailures VALUES(N'Whole-database overlapping registrations',
 (SELECT COUNT_BIG(*) FROM vehicle.VehicleRegistration r1 JOIN vehicle.VehicleRegistration r2 ON r1.registration_number=r2.registration_number AND r1.registration_id<r2.registration_id AND r1.valid_from<COALESCE(r2.valid_to,CONVERT(date,'99991231',112)) AND r2.valid_from<COALESCE(r1.valid_to,CONVERT(date,'99991231',112))));
INSERT INTO @ValidationFailures VALUES(N'Whole-database payment currency mismatch',
 (SELECT COUNT_BIG(*) FROM finance.Payment p JOIN sales.SalesOrder o ON o.order_id=p.order_id WHERE p.currency_code<>o.currency_code));
INSERT INTO @ValidationFailures VALUES(N'Whole-database completed transfer/delivery party or chronology mismatch',
  (SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id LEFT JOIN vehicle.VehicleOwnershipHistory owner ON owner.vehicle_id=i.vehicle_id AND owner.valid_to IS NULL WHERE t.to_customer_id<>o.buyer_customer_id OR (t.status='COMPLETED' AND (t.completed_at IS NULL OR t.authority_reference IS NULL OR owner.customer_id<>t.to_customer_id OR NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory prior WHERE prior.vehicle_id=i.vehicle_id AND prior.customer_id=t.from_customer_id AND prior.valid_to=t.completed_at))))
  +(SELECT COUNT_BIG(*) FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN sales.SalesOrder o ON o.order_id=i.order_id WHERE d.recipient_customer_id<>o.buyer_customer_id OR (d.status='COMPLETED' AND (d.completed_at IS NULL OR d.scheduled_at IS NULL OR d.completed_at<d.scheduled_at)) OR o.status='CANCELLED'));
INSERT INTO @ValidationFailures VALUES(N'Whole-database duplicate transfer or delivery per order item',
 (SELECT COUNT_BIG(*) FROM (SELECT order_item_id FROM delivery.OwnershipTransfer GROUP BY order_item_id HAVING COUNT_BIG(*)>1) q)
 +(SELECT COUNT_BIG(*) FROM (SELECT order_item_id FROM delivery.VehicleDelivery GROUP BY order_item_id HAVING COUNT_BIG(*)>1) q));
INSERT INTO @ValidationFailures VALUES(N'Whole-database successful refunds exceed successful payment capture',
 (SELECT COUNT_BIG(*) FROM (SELECT p.payment_id FROM finance.Payment p JOIN finance.Refund r ON r.payment_id=p.payment_id WHERE p.status='SUCCEEDED' AND r.status='SUCCEEDED' GROUP BY p.payment_id,p.amount HAVING SUM(r.amount)>p.amount) q));
DECLARE @FailureCount bigint=(SELECT COUNT_BIG(*) FROM @ValidationFailures WHERE failure_count>0),
        @FailedRowCount bigint=(SELECT COALESCE(SUM(failure_count),0) FROM @ValidationFailures WHERE failure_count>0);
SELECT CASE WHEN @FailureCount=0 THEN N'PASS' ELSE N'FAIL' END AS final_validation_status,
       @FailureCount AS failed_check_count,@FailedRowCount AS total_detected_failure_count,
       N'PASS requires exact cumulative target counts, zero mandatory cohort/business failures, and zero reported DBCC constraint violations. DBCC CHECKCONSTRAINTS is not guaranteed to find every violation; this validator does not verify undocumented application rules or execution history.' AS interpretation;
SELECT check_name,failure_count FROM @ValidationFailures WHERE failure_count>0 ORDER BY check_name;
GO

