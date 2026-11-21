/* Day 3 Phase 03. Deterministic inspection/report/checklist/defect/valuation rows. */
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
IF DB_NAME()<>N'CARS24DataModelingSystem' THROW 51200,'Wrong database. Phase 03 stopped.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @lockResult int;
 EXEC @lockResult=sys.sp_getapplock @Resource=N'CARS24-Day3-Generation',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=0,@DbPrincipal=N'public';
 IF @lockResult<0 THROW 51208,'Could not obtain exclusive Day 3 generation lock.',1;
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
IF (SELECT COUNT_BIG(*) FROM vehicle.Vehicle WHERE vin LIKE 'D3SYN%')<>67 OR
   (SELECT COUNT_BIG(*) FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>67
    THROW 51201,'Phase 02 cohort is missing or incomplete. Phase 03 stopped.',1;
IF (SELECT COUNT_BIG(*) FROM inspection.Inspection)<>3+(SELECT COUNT_BIG(*) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')
    THROW 51202,'Unclassified inspection records exist. Reconcile before Phase 03.',1;

DECLARE @I TABLE(n int PRIMARY KEY,vin varchar(30),scheduled_at datetime2(0),completed_at datetime2(0) NULL,status varchar(20),employee_code varchar(30));
;WITH n AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<62)
INSERT INTO @I
SELECT n,CONCAT('D3SYN',RIGHT(CONCAT('000000000000',n),12)),
       DATEADD(hour,9,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00'))),
       CASE WHEN n<=57 THEN DATEADD(minute,60,DATEADD(hour,9,DATEADD(day,3+n,CONVERT(datetime2(0),'2026-02-01T00:00:00')))) ELSE NULL END,
       CASE WHEN n<=57 THEN 'COMPLETED' WHEN n<=60 THEN 'SCHEDULED' WHEN n=61 THEN 'CANCELLED' ELSE 'NO_SHOW' END,
       CONCAT('D3-EMP-',RIGHT(CONCAT('0000',1+((n-1)%6)*4),4))
FROM n OPTION(MAXRECURSION 100);

DECLARE @Items TABLE(n int, item_code varchar(40),outcome_code varchar(20),note nvarchar(500),PRIMARY KEY(n,item_code));
INSERT INTO @Items
SELECT i.n,x.item_code,
       CASE WHEN x.item_code='ENGINE' AND i.n%11=0 THEN 'FAIL' WHEN x.item_code='BRAKES' AND i.n%13=0 THEN 'FAIL'
            WHEN x.item_code='ROAD_TEST' AND i.n%17=0 THEN 'NOT_CHECKED' ELSE 'PASS' END,
       CONCAT(N'Day 3 synthetic checklist; cohort ',RIGHT(CONCAT(N'0000',i.n),4))
FROM @I i JOIN (VALUES ('ENGINE'),('BRAKES'),('BODY'),('ELECTRICAL'),('TYRES'),('INTERIOR'),('ROAD_TEST')) x(item_code) ON i.n<=57
UNION ALL SELECT i.n,'SAFETY','PASS',CONCAT(N'Day 3 synthetic safety check; cohort ',RIGHT(CONCAT(N'0000',i.n),4)) FROM @I i WHERE i.n BETWEEN 1 AND 12;

/* Every existing event key must match the planned payload exactly. */
IF EXISTS
(
 SELECT 1 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN core.Employee e ON e.employee_code=x.employee_code JOIN inspection.Inspection z ON z.vehicle_id=v.vehicle_id AND z.scheduled_at=x.scheduled_at
 WHERE z.submission_id<>s.submission_id OR ISNULL(z.inspector_employee_id,-1)<>e.employee_id OR z.status<>x.status OR ISNULL(z.completed_at,'9999-12-31')<>ISNULL(x.completed_at,'9999-12-31')
) THROW 51203,'Inspection event payload conflict. Phase 03 stopped.',1;
IF EXISTS(SELECT i.vehicle_id,i.scheduled_at FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%' GROUP BY i.vehicle_id,i.scheduled_at HAVING COUNT_BIG(*)>1)
    THROW 51214,'Ambiguous Day 3 inspection event key. Phase 03 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inspection.Inspection z ON z.vehicle_id=v.vehicle_id AND z.scheduled_at=x.scheduled_at
 JOIN inspection.InspectionReport r ON r.inspection_id=z.inspection_id
 WHERE x.status<>'COMPLETED' OR r.finalized_at<>DATEADD(minute,5,x.completed_at) OR r.outcome_code<>CASE WHEN x.n%9=0 THEN 'FAIL' WHEN x.n%4=0 THEN 'CONDITIONAL' ELSE 'PASS' END
      OR ISNULL(r.summary,N'')<>CONCAT(N'Day 3 synthetic inspection report ',RIGHT(CONCAT(N'0000',x.n),4))
) THROW 51204,'Inspection report payload conflict. Phase 03 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @Items x JOIN @I i ON i.n=x.n JOIN vehicle.Vehicle v ON v.vin=i.vin JOIN inspection.Inspection z ON z.vehicle_id=v.vehicle_id AND z.scheduled_at=i.scheduled_at
 JOIN inspection.InspectionReport r ON r.inspection_id=z.inspection_id JOIN inspection.InspectionItem it ON it.report_id=r.report_id AND it.item_code=x.item_code
 WHERE it.outcome_code<>x.outcome_code OR ISNULL(it.note,N'')<>x.note
) THROW 51205,'Inspection checklist payload conflict. Phase 03 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM
 (
  SELECT i.n,1 AS defect_no,CASE WHEN i.n%3=0 THEN 'MECHANICAL' WHEN i.n%3=1 THEN 'COSMETIC' ELSE 'ELECTRICAL' END AS category,
         CASE WHEN i.n%17=0 THEN 'HIGH' WHEN i.n%5=0 THEN 'MEDIUM' ELSE 'LOW' END AS severity,CASE WHEN i.n%2=0 THEN 'BODY' ELSE 'ENGINE' END AS item_code
  FROM @I i WHERE i.n<=57
  UNION ALL SELECT i.n,2,CASE WHEN i.n%2=0 THEN 'SAFETY' ELSE 'COSMETIC' END,'MEDIUM','ENGINE' FROM @I i WHERE i.n<=42
 ) d
 JOIN @I x ON x.n=d.n JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inspection.Inspection z ON z.vehicle_id=v.vehicle_id AND z.scheduled_at=x.scheduled_at
 JOIN inspection.InspectionReport r ON r.inspection_id=z.inspection_id
 JOIN inspection.Defect actual ON actual.description=CONCAT(N'D3 synthetic defect ',RIGHT(CONCAT(N'0000',d.n),4),N'-',d.defect_no)
 JOIN inspection.InspectionItem it ON it.report_id=r.report_id AND it.item_code=d.item_code
 WHERE actual.report_id<>r.report_id OR actual.inspection_item_id<>it.inspection_item_id OR actual.category_code<>d.category OR actual.severity_code<>d.severity
    OR actual.repair_estimate<>CONVERT(decimal(19,4),500+d.n*50+d.defect_no*250) OR actual.currency_code<>'INR'
) THROW 51206,'Defect natural-key payload conflict. Phase 03 stopped.',1;
IF EXISTS
(
 SELECT actual.description FROM inspection.Defect actual
 WHERE actual.description LIKE N'D3 synthetic defect %'
 GROUP BY actual.description HAVING COUNT_BIG(*)>1
) THROW 51213,'Ambiguous synthetic defect key. Phase 03 stopped.',1;
IF EXISTS
(
 SELECT 1 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inspection.Inspection z ON z.vehicle_id=v.vehicle_id AND z.scheduled_at=x.scheduled_at
 JOIN inspection.VehicleValuation val ON val.vehicle_id=v.vehicle_id AND val.valued_at=DATEADD(day,1,z.scheduled_at)
 JOIN core.Employee e ON e.employee_code=x.employee_code
 WHERE val.assessor_employee_id<>e.employee_id OR val.report_id<>(SELECT r.report_id FROM inspection.InspectionReport r WHERE r.inspection_id=z.inspection_id)
    OR val.amount<>CONVERT(decimal(19,4),500000+(x.n%20)*25000) OR val.currency_code<>'INR'
    OR val.status<>CASE WHEN x.n%10=0 THEN 'REJECTED' WHEN x.n%7=0 THEN 'SUPERSEDED' ELSE 'APPROVED' END
    OR val.basis<>CONCAT(N'Day 3 synthetic valuation; inspection cohort ',RIGHT(CONCAT(N'0000',x.n),4))
) THROW 51207,'Valuation event payload conflict. Phase 03 stopped.',1;
IF EXISTS(SELECT val.vehicle_id,val.valued_at FROM inspection.VehicleValuation val JOIN vehicle.Vehicle v ON v.vehicle_id=val.vehicle_id WHERE v.vin LIKE 'D3SYN%' GROUP BY val.vehicle_id,val.valued_at HAVING COUNT_BIG(*)>1)
    THROW 51215,'Ambiguous Day 3 valuation event key. Phase 03 stopped.',1;

 /* The package lock and transaction were acquired before mutable prechecks. */
 DECLARE @inspectionInserted int=0,@reportInserted int=0,@itemInserted int=0,@defectInserted int=0,@valuationInserted int=0;

 INSERT INTO inspection.Inspection(vehicle_id,submission_id,inspector_employee_id,scheduled_at,completed_at,status)
 SELECT v.vehicle_id,s.submission_id,e.employee_id,x.scheduled_at,x.completed_at,x.status
 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
 JOIN core.Employee e ON e.employee_code=x.employee_code
 WHERE NOT EXISTS(SELECT 1 FROM inspection.Inspection i WITH(UPDLOCK,HOLDLOCK) WHERE i.vehicle_id=v.vehicle_id AND i.scheduled_at=x.scheduled_at);
 SET @inspectionInserted=@@ROWCOUNT;

 INSERT INTO inspection.InspectionReport(inspection_id,outcome_code,summary,finalized_at)
 SELECT i.inspection_id,CASE WHEN x.n%9=0 THEN 'FAIL' WHEN x.n%4=0 THEN 'CONDITIONAL' ELSE 'PASS' END,
        CONCAT(N'Day 3 synthetic inspection report ',RIGHT(CONCAT(N'0000',x.n),4)),DATEADD(minute,5,x.completed_at)
 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=x.scheduled_at
 WHERE x.status='COMPLETED' AND NOT EXISTS(SELECT 1 FROM inspection.InspectionReport r WITH(UPDLOCK,HOLDLOCK) WHERE r.inspection_id=i.inspection_id);
 SET @reportInserted=@@ROWCOUNT;

 INSERT INTO inspection.InspectionItem(report_id,item_code,outcome_code,note)
 SELECT r.report_id,x.item_code,x.outcome_code,x.note
 FROM @Items x JOIN @I j ON j.n=x.n JOIN vehicle.Vehicle v ON v.vin=j.vin JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=j.scheduled_at
 JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id
 WHERE NOT EXISTS(SELECT 1 FROM inspection.InspectionItem z WITH(UPDLOCK,HOLDLOCK) WHERE z.report_id=r.report_id AND z.item_code=x.item_code);
 SET @itemInserted=@@ROWCOUNT;

 ;WITH defects AS
 (
  SELECT i.n,1 AS defect_no,CASE WHEN i.n%3=0 THEN 'MECHANICAL' WHEN i.n%3=1 THEN 'COSMETIC' ELSE 'ELECTRICAL' END AS category,
         CASE WHEN i.n%17=0 THEN 'HIGH' WHEN i.n%5=0 THEN 'MEDIUM' ELSE 'LOW' END AS severity
  FROM @I i WHERE i.n<=57
  UNION ALL SELECT i.n,2,CASE WHEN i.n%2=0 THEN 'SAFETY' ELSE 'COSMETIC' END,'MEDIUM' FROM @I i WHERE i.n<=42
 )
 INSERT INTO inspection.Defect(report_id,inspection_item_id,category_code,severity_code,description,repair_estimate,currency_code)
 SELECT r.report_id,it.inspection_item_id,d.category,d.severity,
        CONCAT(N'D3 synthetic defect ',RIGHT(CONCAT(N'0000',d.n),4),N'-',d.defect_no),CONVERT(decimal(19,4),500+d.n*50+d.defect_no*250),'INR'
 FROM defects d JOIN @I j ON j.n=d.n JOIN vehicle.Vehicle v ON v.vin=j.vin JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=j.scheduled_at
 JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id
 JOIN inspection.InspectionItem it ON it.report_id=r.report_id AND it.item_code=CASE WHEN d.defect_no=1 THEN 'BODY' ELSE 'ENGINE' END
 WHERE NOT EXISTS(SELECT 1 FROM inspection.Defect z WITH(UPDLOCK,HOLDLOCK) WHERE z.report_id=r.report_id AND z.description=CONCAT(N'D3 synthetic defect ',RIGHT(CONCAT(N'0000',d.n),4),N'-',d.defect_no));
 SET @defectInserted=@@ROWCOUNT;

 INSERT INTO inspection.VehicleValuation(vehicle_id,report_id,assessor_employee_id,valued_at,amount,currency_code,basis,status)
 SELECT v.vehicle_id,r.report_id,e.employee_id,DATEADD(day,1,i.scheduled_at),CONVERT(decimal(19,4),500000+(x.n%20)*25000),'INR',
        CONCAT(N'Day 3 synthetic valuation; inspection cohort ',RIGHT(CONCAT(N'0000',x.n),4)),
        CASE WHEN x.n%10=0 THEN 'REJECTED' WHEN x.n%7=0 THEN 'SUPERSEDED' ELSE 'APPROVED' END
 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=x.scheduled_at
 JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id JOIN core.Employee e ON e.employee_code=x.employee_code
 WHERE x.n<=52 AND NOT EXISTS(SELECT 1 FROM inspection.VehicleValuation z WITH(UPDLOCK,HOLDLOCK) WHERE z.vehicle_id=v.vehicle_id AND z.valued_at=DATEADD(day,1,i.scheduled_at));
 SET @valuationInserted=@@ROWCOUNT;

 IF (SELECT COUNT_BIG(*) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>62
    THROW 51209,'Post-insert inspection count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>57
    THROW 51210,'Post-insert report count failed.',1;
 IF EXISTS(SELECT 1 FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id WHERE i.status<>'COMPLETED')
    THROW 51211,'A report exists for a non-completed inspection.',1;
 IF EXISTS(SELECT 1 FROM inspection.Defect d JOIN inspection.InspectionItem it ON it.inspection_item_id=d.inspection_item_id WHERE d.report_id<>it.report_id)
    THROW 51212,'Defect and checklist item report keys disagree.',1;
 IF (SELECT COUNT_BIG(*) FROM inspection.InspectionItem it JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>411
    THROW 51216,'Post-insert Day 3 checklist item count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM inspection.Defect WHERE description LIKE N'D3 synthetic defect %')<>99
    THROW 51217,'Post-insert Day 3 defect count failed.',1;
 IF (SELECT COUNT_BIG(*) FROM inspection.VehicleValuation val JOIN vehicle.Vehicle v ON v.vehicle_id=val.vehicle_id WHERE v.vin LIKE 'D3SYN%')<>52
    THROW 51218,'Post-insert Day 3 valuation count failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.submitted_at=DATEADD(hour,1,v.created_at)
  JOIN core.Employee e ON e.employee_code=x.employee_code
  LEFT JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=x.scheduled_at
  WHERE i.inspection_id IS NULL OR i.submission_id<>s.submission_id OR i.inspector_employee_id<>e.employee_id
     OR i.status<>x.status OR ISNULL(i.completed_at,'9999-12-31')<>ISNULL(x.completed_at,'9999-12-31')
 ) THROW 51219,'Complete inspection/submission payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=x.scheduled_at
  LEFT JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id
  WHERE (x.status='COMPLETED' AND (r.report_id IS NULL OR r.outcome_code<>CASE WHEN x.n%9=0 THEN 'FAIL' WHEN x.n%4=0 THEN 'CONDITIONAL' ELSE 'PASS' END
      OR r.finalized_at<>DATEADD(minute,5,x.completed_at) OR ISNULL(r.summary,N'')<>CONCAT(N'Day 3 synthetic inspection report ',RIGHT(CONCAT(N'0000',x.n),4)))
     OR (x.status<>'COMPLETED' AND r.report_id IS NOT NULL)
 ) THROW 51220,'Complete report payload/cardinality reconciliation failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @Items x JOIN @I j ON j.n=x.n JOIN vehicle.Vehicle v ON v.vin=j.vin
  JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=j.scheduled_at
  JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id
  LEFT JOIN inspection.InspectionItem it ON it.report_id=r.report_id AND it.item_code=x.item_code
  WHERE it.inspection_item_id IS NULL OR it.outcome_code<>x.outcome_code OR ISNULL(it.note,N'')<>x.note
 ) THROW 51221,'Complete checklist payload reconciliation failed.',1;
 IF EXISTS
 (
  SELECT expected.n,expected.defect_no
  FROM (SELECT n,1 AS defect_no FROM @I WHERE n<=57 UNION ALL SELECT n,2 FROM @I WHERE n<=42) expected
  JOIN @I x ON x.n=expected.n JOIN vehicle.Vehicle v ON v.vin=x.vin
  JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id AND i.scheduled_at=x.scheduled_at
  JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id
  LEFT JOIN inspection.Defect d ON d.report_id=r.report_id AND d.description=CONCAT(N'D3 synthetic defect ',RIGHT(CONCAT(N'0000',expected.n),4),N'-',expected.defect_no)
  WHERE d.defect_id IS NULL OR d.currency_code<>'INR' OR d.repair_estimate<>CONVERT(decimal(19,4),500+expected.n*50+expected.defect_no*250)
 ) THROW 51222,'Exact defect event reconciliation failed.',1;
 IF EXISTS
 (
  SELECT 1 FROM @I x JOIN vehicle.Vehicle v ON v.vin=x.vin
  LEFT JOIN inspection.VehicleValuation z ON z.vehicle_id=v.vehicle_id AND z.valued_at=DATEADD(day,1,x.scheduled_at)
  WHERE x.n<=52 AND (z.valuation_id IS NULL OR z.amount<>CONVERT(decimal(19,4),500000+(x.n%20)*25000)
     OR z.currency_code<>'INR' OR z.status<>CASE WHEN x.n%10=0 THEN 'REJECTED' WHEN x.n%7=0 THEN 'SUPERSEDED' ELSE 'APPROVED' END)
 ) THROW 51223,'Complete valuation event reconciliation failed.',1;

 COMMIT TRANSACTION;
 SELECT N'03 Inspection and valuation' AS phase_name,DB_NAME() AS target_database,N'COMMITTED' AS status,
        62 AS expected_inspections,@inspectionInserted AS inspections_inserted,62-@inspectionInserted AS exact_match_skipped,
        57 AS expected_reports,@reportInserted AS reports_inserted,57-@reportInserted AS exact_match_skipped,
        411 AS expected_checklist_items,@itemInserted AS checklist_items_inserted,411-@itemInserted AS exact_match_skipped,
        99 AS expected_defects,@defectInserted AS defects_inserted,99-@defectInserted AS exact_match_skipped,
        52 AS expected_valuations,@valuationInserted AS valuations_inserted,52-@valuationInserted AS exact_match_skipped,
        N'PASS' AS validation_result,N'Phase 04 permitted after reviewing counts and zero conflicts.' AS next_phase;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SELECT N'03 Inspection and valuation' AS phase_name,DB_NAME() AS target_database,N'ROLLED_BACK' AS status,ERROR_NUMBER() AS error_number,ERROR_MESSAGE() AS error_detail,N'No subsequent phase is permitted.' AS next_phase;
 THROW;
END CATCH;
GO
