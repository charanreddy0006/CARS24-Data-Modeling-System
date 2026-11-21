/* Day 3 Phase 02. Uses the existing Day 2 vehicle catalog and branches.
   Adds 67 vehicle/submission cohorts (70 cumulative including Day 2 fixtures).
   No catalog objects or schema objects are created. */
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
IF DB_NAME()<>N'CARS24DataModelingSystem' THROW 51100,'Wrong database. Phase 02 stopped.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @lockResult int;
 EXEC @lockResult=sys.sp_getapplock @Resource=N'CARS24-Day3-Generation',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=0,@DbPrincipal=N'public';
 IF @lockResult<0 THROW 51113,'Could not obtain exclusive Day 3 generation lock.',1;
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
IF NOT EXISTS(SELECT 1 FROM core.Customer WHERE display_name=N'D3 Synthetic Customer 0001')
    THROW 51101,'Phase 01 synthetic customers are not present. Phase 02 stopped.',1;
IF (SELECT COUNT_BIG(*) FROM vehicle.Vehicle)<>3+(SELECT COUNT_BIG(*) FROM vehicle.Vehicle WHERE vin LIKE 'D3SYN%')
    THROW 51102,'Unclassified vehicle rows exist beyond the Day 2 baseline and Day 3 VIN namespace. Reconcile first.',1;
IF (SELECT COUNT_BIG(*) FROM vehicle.VehicleSubmission)<>3+(SELECT COUNT_BIG(*) FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')
    THROW 51103,'Unclassified submission rows exist or the prior phase is incomplete. Reconcile first.',1;

DECLARE @Vehicles TABLE
(
    n int PRIMARY KEY, vin varchar(30) UNIQUE, engine_number varchar(40) UNIQUE,
    brand_name nvarchar(100),model_name nvarchar(100),variant_name nvarchar(120) NULL,
    manufacture_year smallint,fuel varchar(15),transmission varchar(15),customer_name nvarchar(150),
    branch_code varchar(30),registration_number varchar(15),state_code varchar(2),
    created_at datetime2(0),submitted_at datetime2(0)
);
;WITH n AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<67),
catalog AS
(
 SELECT v.n,m.brand_name,m.model_name,m.variant_name
 FROM n v
 JOIN (VALUES
  (0,N'Maruti Suzuki',N'Swift',N'VXi Synthetic'),(1,N'Hyundai',N'Creta',N'SX Synthetic'),
  (2,N'Tata Motors',N'Nexon',N'XZ+ Synthetic'),(3,N'Mahindra',N'XUV700',NULL),
  (4,N'Honda',N'City',N'V Synthetic'),(5,N'Toyota',N'Innova Crysta',NULL),(6,N'Kia',N'Seltos',NULL)
 ) m(slot,brand_name,model_name,variant_name) ON m.slot=(v.n-1)%7
)
INSERT INTO @Vehicles
SELECT c.n,CONCAT('D3SYN',RIGHT(CONCAT('000000000000',c.n),12)),CONCAT('D3ENG',RIGHT(CONCAT('0000000',c.n),7)),
       c.brand_name,c.model_name,c.variant_name,CONVERT(smallint,2016+c.n%10),
       CASE c.n%5 WHEN 0 THEN 'DIESEL' WHEN 1 THEN 'PETROL' WHEN 2 THEN 'PETROL' WHEN 3 THEN 'CNG' ELSE 'ELECTRIC' END,
       CASE c.n%4 WHEN 0 THEN 'MANUAL' WHEN 1 THEN 'AUTOMATIC' WHEN 2 THEN 'AMT' ELSE 'CVT' END,
       CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',c.n),4)),
       CASE (c.n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN' WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END,
       CASE (c.n-1)%8 WHEN 0 THEN CONCAT('TS09ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 1 THEN CONCAT('MH01ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 2 THEN CONCAT('KA03ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 3 THEN CONCAT('MH12ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 4 THEN CONCAT('DL01ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 5 THEN CONCAT('TN09ZZ',RIGHT(CONCAT('0000',c.n),4)) WHEN 6 THEN CONCAT('GJ01ZZ',RIGHT(CONCAT('0000',c.n),4)) ELSE CONCAT('GJ03ZZ',RIGHT(CONCAT('0000',c.n),4)) END,
       CASE (c.n-1)%8 WHEN 0 THEN 'TG' WHEN 1 THEN 'MH' WHEN 2 THEN 'KA' WHEN 3 THEN 'MH' WHEN 4 THEN 'DL' WHEN 5 THEN 'TN' ELSE 'GJ' END,
       DATEADD(day,c.n,CONVERT(datetime2(0),'2026-02-01T09:00:00')),
       DATEADD(hour,1,DATEADD(day,c.n,CONVERT(datetime2(0),'2026-02-01T09:00:00')))
FROM catalog c OPTION(MAXRECURSION 100);

IF (SELECT COUNT_BIG(*) FROM @Vehicles)<>67 THROW 51104,'Vehicle source cohort count is not 67.',1;
IF EXISTS(SELECT 1 FROM @Vehicles x LEFT JOIN core.Customer c ON c.display_name=x.customer_name GROUP BY x.customer_name HAVING COUNT(c.customer_id)<>1)
    THROW 51105,'A deterministic Day 3 owner key is missing or ambiguous.',1;
IF EXISTS(SELECT 1 FROM @Vehicles x LEFT JOIN core.Branch b ON b.branch_code=x.branch_code GROUP BY x.branch_code HAVING COUNT(DISTINCT b.branch_id)<>1)
    THROW 51106,'A required Day 2 branch key is missing or ambiguous.',1;
IF EXISTS(SELECT 1 FROM @Vehicles x LEFT JOIN vehicle.VehicleBrand b ON b.brand_name=x.brand_name LEFT JOIN vehicle.VehicleModel m ON m.brand_id=b.brand_id AND m.model_name=x.model_name GROUP BY x.brand_name,x.model_name HAVING COUNT(DISTINCT m.model_id)<>1)
    THROW 51107,'A required catalog model is missing or ambiguous.',1;
IF EXISTS(SELECT 1 FROM @Vehicles x JOIN vehicle.VehicleBrand b ON b.brand_name=x.brand_name JOIN vehicle.VehicleModel m ON m.brand_id=b.brand_id AND m.model_name=x.model_name WHERE x.variant_name IS NOT NULL AND NOT EXISTS(SELECT 1 FROM vehicle.VehicleVariant v WHERE v.model_id=m.model_id AND v.variant_name=x.variant_name))
    THROW 51108,'A required catalog variant is missing.',1;

IF EXISTS
(
 SELECT 1 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
 JOIN vehicle.VehicleModel m ON m.model_id=v.model_id JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id
 LEFT JOIN vehicle.VehicleVariant va ON va.variant_id=v.variant_id AND va.model_id=v.model_id
 JOIN core.Customer owner ON owner.customer_id=v.current_owner_customer_id
 WHERE b.brand_name<>x.brand_name OR m.model_name<>x.model_name OR ISNULL(va.variant_name,N'')<>ISNULL(x.variant_name,N'')
    OR v.manufacture_year<>x.manufacture_year OR ISNULL(v.engine_number,'')<>x.engine_number OR v.fuel_type_code<>x.fuel OR v.transmission_type_code<>x.transmission
    OR owner.display_name<>x.customer_name OR v.lifecycle_status<>'SUBMITTED' OR v.created_at<>x.created_at
) THROW 51109,'VIN natural-key payload conflict. Phase 02 stopped without writing.',1;
IF EXISTS(SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin GROUP BY x.vin HAVING COUNT_BIG(*)>1)
    THROW 51110,'Ambiguous VIN key. Phase 02 stopped.',1;
IF EXISTS(SELECT x.engine_number FROM @Vehicles x JOIN vehicle.Vehicle v ON v.engine_number=x.engine_number WHERE v.vin<>x.vin)
    THROW 51128,'Engine number alternate-key collision. Phase 02 stopped.',1;
IF EXISTS(SELECT x.registration_number FROM @Vehicles x JOIN vehicle.VehicleRegistration r ON r.registration_number=x.registration_number WHERE r.valid_from<>CONVERT(date,x.created_at) OR NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v WHERE v.vin=x.vin AND v.vehicle_id=r.vehicle_id))
    THROW 51129,'Registration alternate-key collision. Phase 02 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Vehicles x JOIN vehicle.VehicleRegistration r ON r.registration_number=x.registration_number AND r.valid_from=CONVERT(date,x.created_at)
 JOIN vehicle.Vehicle v ON v.vehicle_id=r.vehicle_id
 WHERE v.vin<>x.vin OR r.issuing_state_code<>x.state_code OR r.valid_to IS NOT NULL
) THROW 51111,'Registration natural-key payload conflict. Phase 02 stopped.',1;
IF EXISTS(SELECT x.registration_number FROM @Vehicles x JOIN vehicle.VehicleRegistration r ON r.registration_number=x.registration_number AND r.valid_to IS NULL GROUP BY x.registration_number HAVING COUNT_BIG(*)>1)
    THROW 51117,'Ambiguous active registration key. Phase 02 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN core.Customer c ON c.display_name=x.customer_name
 JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=v.vehicle_id AND h.valid_from=x.created_at
 WHERE h.customer_id<>c.customer_id OR h.valid_to IS NOT NULL OR h.basis_code<>'REGISTERED_OWNER' OR h.evidence_reference<>N'Day 3 synthetic initial registered-owner fixture'
) THROW 51118,'Ownership-history natural-key payload conflict. Phase 02 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=x.submitted_at
 JOIN core.Customer seller ON seller.customer_id=s.seller_customer_id JOIN core.Branch branch ON branch.branch_id=s.branch_id
 WHERE seller.display_name<>x.customer_name OR branch.branch_code<>x.branch_code OR s.status<>'SUBMITTED' OR s.closed_at IS NOT NULL OR s.outcome_reason IS NOT NULL
) THROW 51112,'Submission natural-key payload conflict. Phase 02 stopped.',1;
IF EXISTS(SELECT s.vehicle_id,s.submitted_at FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%' GROUP BY s.vehicle_id,s.submitted_at HAVING COUNT_BIG(*)>1)
    THROW 51119,'Ambiguous Day 3 submission event key. Phase 02 stopped.',1;

 /* The package lock and transaction were acquired before mutable prechecks. */
 DECLARE @vehicleInserted int=0,@registrationInserted int=0,@ownerInserted int=0,@submissionInserted int=0;

 INSERT INTO vehicle.Vehicle(model_id,variant_id,manufacture_year,vin,engine_number,fuel_type_code,transmission_type_code,current_owner_customer_id,lifecycle_status,created_at)
 SELECT m.model_id,va.variant_id,x.manufacture_year,x.vin,x.engine_number,x.fuel,x.transmission,c.customer_id,'SUBMITTED',x.created_at
 FROM @Vehicles x JOIN vehicle.VehicleBrand b ON b.brand_name=x.brand_name JOIN vehicle.VehicleModel m ON m.brand_id=b.brand_id AND m.model_name=x.model_name
 LEFT JOIN vehicle.VehicleVariant va ON va.model_id=m.model_id AND va.variant_name=x.variant_name JOIN core.Customer c ON c.display_name=x.customer_name
 WHERE NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v WITH(UPDLOCK,HOLDLOCK) WHERE v.vin=x.vin);
 SET @vehicleInserted=@@ROWCOUNT;

 INSERT INTO vehicle.VehicleRegistration(vehicle_id,registration_number,issuing_state_code,valid_from)
 SELECT v.vehicle_id,x.registration_number,x.state_code,CONVERT(date,x.created_at)
 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
 WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleRegistration r WITH(UPDLOCK,HOLDLOCK) WHERE r.registration_number=x.registration_number AND r.valid_from=CONVERT(date,x.created_at));
 SET @registrationInserted=@@ROWCOUNT;

 INSERT INTO vehicle.VehicleOwnershipHistory(vehicle_id,customer_id,valid_from,basis_code,evidence_reference)
 SELECT v.vehicle_id,c.customer_id,x.created_at,'REGISTERED_OWNER',N'Day 3 synthetic initial registered-owner fixture'
 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN core.Customer c ON c.display_name=x.customer_name
 WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WITH(UPDLOCK,HOLDLOCK) WHERE h.vehicle_id=v.vehicle_id AND h.valid_from=x.created_at);
 SET @ownerInserted=@@ROWCOUNT;

 INSERT INTO vehicle.VehicleSubmission(vehicle_id,seller_customer_id,branch_id,submitted_at,status)
 SELECT v.vehicle_id,c.customer_id,b.branch_id,x.submitted_at,'SUBMITTED'
 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN core.Customer c ON c.display_name=x.customer_name JOIN core.Branch b ON b.branch_code=x.branch_code
 WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleSubmission s WITH(UPDLOCK,HOLDLOCK) WHERE s.vehicle_id=v.vehicle_id AND s.submitted_at=x.submitted_at);
 SET @submissionInserted=@@ROWCOUNT;

 IF EXISTS(SELECT 1 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin WHERE v.current_owner_customer_id<>(SELECT c.customer_id FROM core.Customer c WHERE c.display_name=x.customer_name))
    THROW 51114,'Post-insert vehicle owner validation failed.',1;
 IF EXISTS(SELECT 1 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin WHERE NOT EXISTS(SELECT 1 FROM vehicle.VehicleOwnershipHistory h WHERE h.vehicle_id=v.vehicle_id AND h.customer_id=v.current_owner_customer_id AND h.valid_to IS NULL))
    THROW 51115,'Post-insert current-owner history validation failed.',1;
 IF EXISTS(SELECT 1 FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin WHERE (SELECT COUNT_BIG(*) FROM vehicle.VehicleRegistration r WHERE r.vehicle_id=v.vehicle_id AND r.valid_to IS NULL)<>1)
    THROW 51116,'Post-insert active registration validation failed.',1;

 /* Reconcile complete expected payloads, not just successful joins or totals. */
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x
  LEFT JOIN vehicle.Vehicle v ON v.vin=x.vin
  LEFT JOIN vehicle.VehicleModel m ON m.model_id=v.model_id
  LEFT JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id
  LEFT JOIN vehicle.VehicleVariant va ON va.variant_id=v.variant_id
  LEFT JOIN core.Customer owner ON owner.customer_id=v.current_owner_customer_id
  WHERE v.vehicle_id IS NULL OR b.brand_name<>x.brand_name OR m.model_name<>x.model_name
     OR ISNULL(va.variant_name,N'')<>ISNULL(x.variant_name,N'') OR v.manufacture_year<>x.manufacture_year
     OR v.vin<>x.vin OR ISNULL(v.engine_number,'')<>x.engine_number OR v.fuel_type_code<>x.fuel
     OR v.transmission_type_code<>x.transmission OR owner.display_name<>x.customer_name
     OR v.lifecycle_status<>'SUBMITTED' OR v.created_at<>x.created_at
 ) THROW 51120,'Complete vehicle payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
  LEFT JOIN vehicle.VehicleRegistration r ON r.vehicle_id=v.vehicle_id
       AND r.registration_number=x.registration_number AND r.valid_from=CONVERT(date,x.created_at)
  GROUP BY x.vin HAVING COUNT_BIG(r.registration_id)<>1
 ) THROW 51121,'Expected registration key does not resolve exactly once.',1;
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN vehicle.VehicleRegistration r ON r.vehicle_id=v.vehicle_id
  WHERE r.registration_number=x.registration_number AND r.valid_from=CONVERT(date,x.created_at)
    AND (r.issuing_state_code<>x.state_code OR r.valid_to IS NOT NULL)
 ) THROW 51122,'Complete registration payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN core.Customer c ON c.display_name=x.customer_name
  LEFT JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=v.vehicle_id AND h.valid_from=x.created_at
  GROUP BY x.vin,c.customer_id HAVING COUNT_BIG(h.ownership_history_id)<>1
 ) THROW 51123,'Expected ownership event does not resolve exactly once.',1;
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN core.Customer c ON c.display_name=x.customer_name
  JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=v.vehicle_id AND h.valid_from=x.created_at
  WHERE h.customer_id<>c.customer_id OR h.valid_to IS NOT NULL OR h.basis_code<>'REGISTERED_OWNER'
     OR h.evidence_reference<>N'Day 3 synthetic initial registered-owner fixture'
 ) THROW 51124,'Complete ownership payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
  LEFT JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=x.submitted_at
  GROUP BY x.vin HAVING COUNT_BIG(s.submission_id)<>1
 ) THROW 51125,'Expected submission event does not resolve exactly once.',1;
 IF EXISTS
 (
  SELECT x.vin FROM @Vehicles x JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN core.Customer c ON c.display_name=x.customer_name JOIN core.Branch b ON b.branch_code=x.branch_code
  JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=x.submitted_at
  WHERE s.seller_customer_id<>c.customer_id OR s.branch_id<>b.branch_id OR s.status<>'SUBMITTED'
    OR s.closed_at IS NOT NULL OR s.outcome_reason IS NOT NULL
 ) THROW 51126,'Complete submission payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT x.engine_number FROM @Vehicles x JOIN vehicle.Vehicle v ON v.engine_number=x.engine_number
  GROUP BY x.engine_number HAVING COUNT_BIG(*)<>1
 ) THROW 51127,'Generated engine number is duplicated.',1;

 COMMIT TRANSACTION;
 SELECT N'02 Catalog and vehicle intake' AS phase_name,DB_NAME() AS target_database,N'COMMITTED' AS status,
        67 AS expected_vehicle_keys,@vehicleInserted AS vehicles_inserted,67-@vehicleInserted AS vehicles_exact_match_skipped,
        67 AS expected_registration_keys,@registrationInserted AS registrations_inserted,67-@registrationInserted AS registrations_exact_match_skipped,
        67 AS expected_owner_history_keys,@ownerInserted AS ownership_rows_inserted,67-@ownerInserted AS ownership_rows_exact_match_skipped,
        67 AS expected_submission_keys,@submissionInserted AS submissions_inserted,67-@submissionInserted AS submissions_exact_match_skipped,
        N'PASS' AS validation_result,N'Phase 03 permitted after reviewing counts and zero conflicts.' AS next_phase;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SELECT N'02 Catalog and vehicle intake' AS phase_name,DB_NAME() AS target_database,N'ROLLED_BACK' AS status,ERROR_NUMBER() AS error_number,ERROR_MESSAGE() AS error_detail,N'No subsequent phase is permitted.' AS next_phase;
 THROW;
END CATCH;
GO
