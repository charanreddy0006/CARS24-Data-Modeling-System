/*
  Day 3 read-only readiness check. Run this first in SSMS.
  It reports current prerequisites and synthetic-key collisions; it does not
  create, alter, or modify database objects or data.
*/
USE [master];
GO
SET NOCOUNT ON;

DECLARE @TargetDatabase sysname = N'CARS24DataModelingSystem';
DECLARE @TargetId int = DB_ID(@TargetDatabase);
SELECT @TargetDatabase AS expected_database,
       DB_NAME() AS execution_database,
       @TargetId AS database_id,
       CASE WHEN @TargetId IS NULL THEN N'BLOCKED' ELSE N'FOUND' END AS existence_result,
       CONVERT(nvarchar(128), SERVERPROPERTY(N'ServerName')) AS server_name,
       CONVERT(nvarchar(128), SERVERPROPERTY(N'ProductVersion')) AS product_version,
       CASE WHEN @TargetId IS NOT NULL AND HAS_DBACCESS(@TargetDatabase) = 1 THEN N'PASS' ELSE N'BLOCKED' END AS access_result;

IF @TargetId IS NULL OR ISNULL(HAS_DBACCESS(@TargetDatabase),0) <> 1
BEGIN
    SELECT N'BLOCKED' AS readiness_status,
           N'Target database is missing or not accessible to this login. No data was inspected.' AS detail;
    RETURN;
END;

DECLARE @DbState nvarchar(60), @ReadOnly bit, @Compatibility int;
SELECT @DbState = [state_desc], @ReadOnly = [is_read_only], @Compatibility = [compatibility_level]
FROM sys.databases WHERE [database_id] = @TargetId;
SELECT @TargetDatabase AS database_name, @DbState AS state_desc, @ReadOnly AS is_read_only,
       @Compatibility AS compatibility_level,
       CASE WHEN @DbState = N'ONLINE' AND @ReadOnly = 0 THEN N'PASS' ELSE N'BLOCKED' END AS database_result;
IF @DbState<>N'ONLINE' OR @ReadOnly=1
BEGIN
    SELECT N'BLOCKED' AS readiness_status,N'Target database must be ONLINE and writable for a later, separately authorized generation run. This script performed no writes.' AS detail;
    RETURN;
END;

/* Execute the remaining catalog/data checks in the intended database. */
EXEC sys.sp_executesql N'
USE [CARS24DataModelingSystem];
SET NOCOUNT ON;

DECLARE @ExpectedSchemas TABLE (schema_name sysname PRIMARY KEY);
INSERT INTO @ExpectedSchemas VALUES
 (N''ref''),(N''core''),(N''vehicle''),(N''inspection''),(N''acquisition''),
 (N''inventory''),(N''marketplace''),(N''sales''),(N''finance''),(N''delivery'');

DECLARE @ExpectedTables TABLE (schema_name sysname, table_name sysname, PRIMARY KEY(schema_name,table_name));
INSERT INTO @ExpectedTables VALUES
 (N''ref'',N''City''),
 (N''core'',N''Branch''),(N''core'',N''Employee''),(N''core'',N''EmployeeRole''),(N''core'',N''Customer''),(N''core'',N''CustomerContact''),(N''core'',N''CustomerAddress''),
 (N''vehicle'',N''VehicleBrand''),(N''vehicle'',N''VehicleModel''),(N''vehicle'',N''VehicleVariant''),(N''vehicle'',N''Vehicle''),(N''vehicle'',N''VehicleRegistration''),(N''vehicle'',N''VehicleOwnershipHistory''),(N''vehicle'',N''VehicleSubmission''),
 (N''inspection'',N''Inspection''),(N''inspection'',N''InspectionReport''),(N''inspection'',N''InspectionItem''),(N''inspection'',N''Defect''),(N''inspection'',N''VehicleValuation''),
 (N''acquisition'',N''PurchaseOffer''),(N''acquisition'',N''PurchaseAgreement''),(N''acquisition'',N''VehicleAcquisition''),
 (N''inventory'',N''Inventory''),(N''inventory'',N''InventoryMovement''),
 (N''marketplace'',N''VehicleListing''),(N''marketplace'',N''ListingImage''),(N''marketplace'',N''CustomerEnquiry''),(N''marketplace'',N''VehicleReservation''),
 (N''sales'',N''SalesOrder''),(N''sales'',N''SalesOrderItem''),(N''finance'',N''Payment''),(N''finance'',N''Refund''),
 (N''delivery'',N''OwnershipTransfer''),(N''delivery'',N''VehicleDelivery'');

IF EXISTS (SELECT 1 FROM @ExpectedSchemas e LEFT JOIN sys.schemas s ON s.name=e.schema_name WHERE s.schema_id IS NULL)
   OR EXISTS (SELECT 1 FROM @ExpectedTables e LEFT JOIN sys.schemas s ON s.name=e.schema_name LEFT JOIN sys.tables t ON t.schema_id=s.schema_id AND t.name=e.table_name WHERE t.object_id IS NULL)
BEGIN
    SELECT N''BLOCKED'' AS readiness_status,
           N''One or more expected Day 2 schemas/tables are missing; later data checks were not run.'' AS detail;
    RETURN;
END;

SELECT e.schema_name,
       CASE WHEN s.schema_id IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS schema_result
FROM @ExpectedSchemas AS e LEFT JOIN sys.schemas AS s ON s.name=e.schema_name ORDER BY e.schema_name;
SELECT e.schema_name,e.table_name,
       CASE WHEN t.object_id IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS table_result
FROM @ExpectedTables AS e LEFT JOIN sys.schemas AS s ON s.name=e.schema_name
LEFT JOIN sys.tables AS t ON t.schema_id=s.schema_id AND t.name=e.table_name
ORDER BY e.schema_name,e.table_name;

SELECT N''PRIMARY_KEY'' AS object_type,COUNT_BIG(*) AS actual_count,CONVERT(bigint,34) AS expected_count
FROM sys.key_constraints AS k JOIN sys.tables AS t ON t.object_id=k.parent_object_id JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE k.type=''PK''
UNION ALL SELECT N''FOREIGN_KEY'',COUNT_BIG(*),CONVERT(bigint,62)
FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.object_id=f.parent_object_id JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id)
UNION ALL SELECT N''UNIQUE_CONSTRAINT'',COUNT_BIG(*) ,CONVERT(bigint,19)
FROM sys.key_constraints AS k JOIN sys.tables AS t ON t.object_id=k.parent_object_id JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE k.type=''UQ''
UNION ALL SELECT N''CHECK_CONSTRAINT'',COUNT_BIG(*),CONVERT(bigint,79)
FROM sys.check_constraints AS c JOIN sys.tables AS t ON t.object_id=c.parent_object_id JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id)
UNION ALL SELECT N''DEFAULT_CONSTRAINT'',COUNT_BIG(*),CONVERT(bigint,8)
FROM sys.default_constraints AS d JOIN sys.tables AS t ON t.object_id=d.parent_object_id JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id)
UNION ALL SELECT N''TOTAL_INDEX'',COUNT_BIG(*),CONVERT(bigint,113)
FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id=i.object_id JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE i.index_id>0;

SELECT N''DISABLED_OR_UNTRUSTED_FK'' AS issue_type,SCHEMA_NAME(t.schema_id) AS schema_name,t.name AS table_name,f.name AS object_name
FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.object_id=f.parent_object_id
JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE f.is_disabled=1 OR f.is_not_trusted=1
UNION ALL SELECT N''DISABLED_OR_UNTRUSTED_CHECK'',SCHEMA_NAME(t.schema_id),t.name,c.name
FROM sys.check_constraints AS c JOIN sys.tables AS t ON t.object_id=c.parent_object_id
JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE c.is_disabled=1 OR c.is_not_trusted=1
UNION ALL SELECT N''DISABLED_INDEX'',SCHEMA_NAME(t.schema_id),t.name,i.name
FROM sys.indexes AS i JOIN sys.tables AS t ON t.object_id=i.object_id
JOIN @ExpectedSchemas AS s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE i.is_disabled=1;

/* Actual row counts for every table, restricted to the modeled 34-table set. */
SELECT e.schema_name,e.table_name,COALESCE(SUM(ps.rows),0) AS approximate_row_count
FROM @ExpectedTables AS e LEFT JOIN sys.schemas AS s ON s.name=e.schema_name
LEFT JOIN sys.tables AS t ON t.schema_id=s.schema_id AND t.name=e.table_name
LEFT JOIN sys.partitions AS ps ON ps.object_id=t.object_id AND ps.index_id IN (0,1)
GROUP BY e.schema_name,e.table_name ORDER BY e.schema_name,e.table_name;

/* Known Day 2 marker checks; counts are descriptive and not assertions of a clean install. */
SELECT N''SYNVIN'' AS marker_type,COUNT_BIG(*) AS matching_rows FROM vehicle.Vehicle WHERE vin LIKE ''SYNVIN%''
UNION ALL SELECT N''D2_BRANCH'',COUNT_BIG(*) FROM core.Branch WHERE branch_code IN (''HYD-CEN'',''MUM-WST'',''BLR-SOU'',''PUN-CEN'',''DEL-SOU'',''CHE-CEN'',''AMD-CEN'',''RJK-CEN'')
UNION ALL SELECT N''D2_EMPLOYEE'',COUNT_BIG(*) FROM core.Employee WHERE employee_code LIKE ''EMP-SYN-%''
UNION ALL SELECT N''D2_CUSTOMER'',COUNT_BIG(*) FROM core.Customer WHERE display_name IN (N''Synthetic Customer Alpha'',N''Synthetic Customer Beta'',N''Synthetic Customer Gamma'')
UNION ALL SELECT N''D2_AGREEMENT'',COUNT_BIG(*) FROM acquisition.PurchaseAgreement WHERE agreement_reference=''SYN-AGR-0001''
UNION ALL SELECT N''D2_PAYMENT'',COUNT_BIG(*) FROM finance.Payment WHERE provider_code=''SYNTHETIC_PROVIDER'' AND provider_reference=''SYN-PAY-0001''
UNION ALL SELECT N''D2_REFUND'',COUNT_BIG(*) FROM finance.Refund WHERE provider_reference=''SYN-REF-0001''
UNION ALL SELECT N''D2_TRANSFER'',COUNT_BIG(*) FROM delivery.OwnershipTransfer WHERE authority_reference=''SYN-TRANSFER-0001''
UNION ALL SELECT N''D2_DELIVERY'',COUNT_BIG(*) FROM delivery.VehicleDelivery WHERE handover_reference=''SYN-HANDOVER-0001''
UNION ALL SELECT N''D2_INSPECTION'',COUNT_BIG(*) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND v.vin LIKE ''SYNVIN%''
UNION ALL SELECT N''D2_REPORT'',COUNT_BIG(*) FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND v.vin LIKE ''SYNVIN%''
UNION ALL SELECT N''D2_CHECKLIST_ITEMS'',COUNT_BIG(*) FROM inspection.InspectionItem it JOIN inspection.InspectionReport r ON r.report_id=it.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND v.vin LIKE ''SYNVIN%''
UNION ALL SELECT N''D2_DEFECT'',COUNT_BIG(*) FROM inspection.Defect WHERE description=N''Synthetic minor exterior mark.''
UNION ALL SELECT N''D2_VALUATIONS'',COUNT_BIG(*) FROM inspection.VehicleValuation val JOIN vehicle.Vehicle v ON v.vehicle_id=val.vehicle_id WHERE val.valued_at=CONVERT(datetime2(0),''2026-01-05T09:00:00'') AND v.vin LIKE ''SYNVIN%''
UNION ALL SELECT N''D2_INVENTORY'',COUNT_BIG(*) FROM inventory.Inventory i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin=''SYNVIN0000000000001''
UNION ALL SELECT N''D2_LISTING'',COUNT_BIG(*) FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin=''SYNVIN0000000000001'' AND l.listed_at=CONVERT(datetime2(0),''2026-01-08T09:00:00'');

/* Every family below is derived from deterministic natural/event keys used by
   phases 01-06. Any existing row is a reconciliation blocker, not a skip. */
DECLARE @D3KeyFamilies TABLE(key_family sysname PRIMARY KEY,matching_rows bigint NOT NULL);
INSERT INTO @D3KeyFamilies(key_family,matching_rows)
SELECT N''EMPLOYEE_CODE'',COUNT_BIG(*) FROM core.Employee WHERE employee_code LIKE ''D3-EMP-%''
UNION ALL SELECT N''EMPLOYEE_ROLE'',COUNT_BIG(*) FROM core.EmployeeRole r JOIN core.Employee e ON e.employee_id=r.employee_id WHERE e.employee_code LIKE ''D3-EMP-%''
UNION ALL SELECT N''CUSTOMER_NAME'',COUNT_BIG(*) FROM core.Customer WHERE display_name LIKE N''D3 Synthetic Customer %''
UNION ALL SELECT N''CUSTOMER_CONTACT'',COUNT_BIG(*) FROM core.CustomerContact x JOIN core.Customer c ON c.customer_id=x.customer_id WHERE c.display_name LIKE N''D3 Synthetic Customer %''
UNION ALL SELECT N''CUSTOMER_ADDRESS'',COUNT_BIG(*) FROM core.CustomerAddress x JOIN core.Customer c ON c.customer_id=x.customer_id WHERE c.display_name LIKE N''D3 Synthetic Customer %''
UNION ALL SELECT N''CUSTOMER_EMAIL_ALTERNATE_KEY'',COUNT_BIG(*) FROM core.CustomerContact WHERE contact_type=''EMAIL'' AND contact_value LIKE N''day3.customer.%@example.invalid''
UNION ALL SELECT N''CUSTOMER_PHONE_ALTERNATE_KEY'',COUNT_BIG(*) FROM core.CustomerContact WHERE contact_type=''PHONE'' AND contact_value LIKE N''+91-00000-%''
UNION ALL SELECT N''CUSTOMER_ADDRESS_ALTERNATE_KEY'',COUNT_BIG(*) FROM core.CustomerAddress WHERE address_line1 LIKE N''D3 Synthetic Address %'' OR address_line1 LIKE N''D3 Synthetic Mailing Address %''
UNION ALL SELECT N''VIN'',COUNT_BIG(*) FROM vehicle.Vehicle WHERE vin LIKE ''D3SYN%''
UNION ALL SELECT N''ENGINE_NUMBER'',COUNT_BIG(*) FROM vehicle.Vehicle WHERE engine_number LIKE ''D3ENG%''
UNION ALL SELECT N''REGISTRATION_NUMBER'',COUNT_BIG(*) FROM vehicle.VehicleRegistration WHERE registration_number LIKE ''[A-Z][A-Z][0-9][0-9]ZZ%''
UNION ALL SELECT N''OWNERSHIP_EVENT'',COUNT_BIG(*) FROM vehicle.VehicleOwnershipHistory h JOIN vehicle.Vehicle v ON v.vehicle_id=h.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''SUBMISSION_EVENT'',COUNT_BIG(*) FROM vehicle.VehicleSubmission s JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''INSPECTION_EVENT'',COUNT_BIG(*) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''INSPECTION_REPORT'',COUNT_BIG(*) FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''INSPECTION_ITEM'',COUNT_BIG(*) FROM inspection.InspectionItem x JOIN inspection.InspectionReport r ON r.report_id=x.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''DEFECT'',COUNT_BIG(*) FROM inspection.Defect d JOIN inspection.InspectionReport r ON r.report_id=d.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''VALUATION_EVENT'',COUNT_BIG(*) FROM inspection.VehicleValuation x JOIN vehicle.Vehicle v ON v.vehicle_id=x.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''PURCHASE_OFFER_EVENT'',COUNT_BIG(*) FROM acquisition.PurchaseOffer o JOIN vehicle.VehicleSubmission s ON s.submission_id=o.submission_id JOIN vehicle.Vehicle v ON v.vehicle_id=s.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''PURCHASE_AGREEMENT_REFERENCE'',COUNT_BIG(*) FROM acquisition.PurchaseAgreement WHERE agreement_reference LIKE ''D3-AGR-%''
UNION ALL SELECT N''ACQUISITION'',COUNT_BIG(*) FROM acquisition.VehicleAcquisition a JOIN vehicle.Vehicle v ON v.vehicle_id=a.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''INVENTORY_POSITION'',COUNT_BIG(*) FROM inventory.Inventory x JOIN vehicle.Vehicle v ON v.vehicle_id=x.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''INVENTORY_MOVEMENT_EVENT'',COUNT_BIG(*) FROM inventory.InventoryMovement m JOIN inventory.Inventory x ON x.inventory_id=m.inventory_id JOIN vehicle.Vehicle v ON v.vehicle_id=x.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''LISTING_EVENT'',COUNT_BIG(*) FROM marketplace.VehicleListing l JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''LISTING_IMAGE_KEY'',COUNT_BIG(*) FROM marketplace.ListingImage im JOIN marketplace.VehicleListing l ON l.listing_id=im.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''ENQUIRY_KEY'',COUNT_BIG(*) FROM marketplace.CustomerEnquiry q LEFT JOIN marketplace.VehicleListing l ON l.listing_id=q.listing_id LEFT JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE q.message_reference LIKE N''D3-ENQ-%'' OR v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''RESERVATION_EVENT'',COUNT_BIG(*) FROM marketplace.VehicleReservation r JOIN marketplace.VehicleListing l ON l.listing_id=r.listing_id JOIN vehicle.Vehicle v ON v.vehicle_id=l.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''SALES_ORDER_EVENT'',COUNT_BIG(*) FROM sales.SalesOrder o JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE c.display_name LIKE N''D3 Synthetic Customer %'' AND o.created_at>=''2026-02-01''
UNION ALL SELECT N''SALES_ORDER_ITEM'',COUNT_BIG(*) FROM sales.SalesOrderItem i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''PAYMENT_REFERENCE'',COUNT_BIG(*) FROM finance.Payment WHERE provider_code=''D3_SYNTHETIC'' OR provider_reference LIKE ''D3-%''
UNION ALL SELECT N''REFUND_REFERENCE'',COUNT_BIG(*) FROM finance.Refund WHERE provider_reference LIKE ''D3-%''
UNION ALL SELECT N''OWNERSHIP_TRANSFER_REFERENCE'',COUNT_BIG(*) FROM delivery.OwnershipTransfer t LEFT JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id LEFT JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE t.authority_reference LIKE ''D3-TR-%'' OR v.vin LIKE ''D3SYN%''
UNION ALL SELECT N''DELIVERY_REFERENCE'',COUNT_BIG(*) FROM delivery.VehicleDelivery d LEFT JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id LEFT JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE d.handover_reference LIKE ''D3-HAND-%'' OR v.vin LIKE ''D3SYN%'';
SELECT key_family,matching_rows FROM @D3KeyFamilies ORDER BY key_family;

DECLARE @SchemaCount bigint=(SELECT COUNT_BIG(*) FROM sys.schemas WHERE name IN (N''ref'',N''core'',N''vehicle'',N''inspection'',N''acquisition'',N''inventory'',N''marketplace'',N''sales'',N''finance'',N''delivery'')),
        @TableCount bigint=(SELECT COUNT_BIG(*) FROM sys.tables t JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id)),
        @PkCount bigint=(SELECT COUNT_BIG(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE k.type=''PK''),
        @FkCount bigint=(SELECT COUNT_BIG(*) FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id)),
        @UqCount bigint=(SELECT COUNT_BIG(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE k.type=''UQ''),
        @CheckCount bigint=(SELECT COUNT_BIG(*) FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id)),
        @DefaultCount bigint=(SELECT COUNT_BIG(*) FROM sys.default_constraints d JOIN sys.tables t ON t.object_id=d.parent_object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id)),
        @IndexCount bigint=(SELECT COUNT_BIG(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE i.index_id>0),
        @NamedIndexCount bigint=(SELECT COUNT_BIG(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id JOIN @ExpectedSchemas s ON s.schema_name=SCHEMA_NAME(t.schema_id) WHERE i.index_id>0 AND (i.name LIKE N''IX[_]%'' OR i.name LIKE N''UX[_]%'')),
        @BadConstraintCount bigint=(SELECT COUNT_BIG(*) FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)+(SELECT COUNT_BIG(*) FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)+(SELECT COUNT_BIG(*) FROM sys.indexes WHERE index_id>0 AND is_disabled=1),
        @D3KeyCount bigint=(SELECT COALESCE(SUM(matching_rows),0) FROM @D3KeyFamilies);
DECLARE @FixtureFindings TABLE(fixture_group sysname PRIMARY KEY, failure_count bigint NOT NULL);
/* Expected values below are transcribed from database/10_seed_reference_data.sql.
   Compare by natural keys; never bind these checks to identity values. */
INSERT INTO @FixtureFindings VALUES
(N''Cities'',
 (SELECT COUNT_BIG(*) FROM (VALUES (N''Hyderabad'',''TG''),(N''Mumbai'',''MH''),(N''Bengaluru'',''KA''),(N''Pune'',''MH''),(N''Delhi'',''DL''),(N''Chennai'',''TN''),(N''Ahmedabad'',''GJ''),(N''Rajkot'',''GJ'')) e(city_name,state_code)
  WHERE (SELECT COUNT_BIG(*) FROM ref.City c WHERE c.city_name=e.city_name AND c.state_code=e.state_code AND c.country_code=''IN'')<>1)
 +(SELECT COUNT_BIG(*) FROM ref.City WHERE city_name IN(N''Hyderabad'',N''Mumbai'',N''Bengaluru'',N''Pune'',N''Delhi'',N''Chennai'',N''Ahmedabad'',N''Rajkot'') AND country_code<>''IN'')),
(N''Branches'',
 (SELECT COUNT_BIG(*) FROM (VALUES (''HYD-CEN'',N''Hyderabad Central'',N''Hyderabad''),( ''MUM-WST'',N''Mumbai West'',N''Mumbai''),( ''BLR-SOU'',N''Bengaluru South'',N''Bengaluru''),( ''PUN-CEN'',N''Pune Central'',N''Pune''),( ''DEL-SOU'',N''Delhi South'',N''Delhi''),( ''CHE-CEN'',N''Chennai Central'',N''Chennai''),( ''AMD-CEN'',N''Ahmedabad Central'',N''Ahmedabad''),( ''RJK-CEN'',N''Rajkot Central'',N''Rajkot'')) e(branch_code,branch_name,city_name)
  WHERE (SELECT COUNT_BIG(*) FROM core.Branch b JOIN ref.City c ON c.city_id=b.city_id WHERE b.branch_code=e.branch_code AND b.branch_name=e.branch_name AND b.address_text=CONCAT(N''Synthetic branch address, '',e.city_name) AND b.status=''ACTIVE'' AND c.city_name=e.city_name AND c.country_code=''IN'')<>1)
 +(SELECT ABS(COUNT_BIG(*)-8) FROM core.Branch WHERE branch_code IN(''HYD-CEN'',''MUM-WST'',''BLR-SOU'',''PUN-CEN'',''DEL-SOU'',''CHE-CEN'',''AMD-CEN'',''RJK-CEN''))),
(N''EmployeesAndRoles'',
 (SELECT COUNT_BIG(*) FROM (VALUES (''EMP-SYN-001'',N''Synthetic Staff One'',''HYD-CEN'',''BRANCH_MANAGER''),( ''EMP-SYN-002'',N''Synthetic Staff Two'',''MUM-WST'',''INSPECTOR''),( ''EMP-SYN-003'',N''Synthetic Staff Three'',''BLR-SOU'',''SALES_EXECUTIVE''),( ''EMP-SYN-004'',N''Synthetic Staff Four'',''PUN-CEN'',''INVENTORY_MANAGER'')) e(employee_code,display_name,branch_code,role_code)
  WHERE (SELECT COUNT_BIG(*) FROM core.Employee x JOIN core.Branch b ON b.branch_id=x.branch_id WHERE x.employee_code=e.employee_code AND x.display_name=e.display_name AND b.branch_code=e.branch_code AND x.active_from=CONVERT(date,''20260101'',112) AND x.active_to IS NULL)<>1
     OR (SELECT COUNT_BIG(*) FROM core.Employee x JOIN core.EmployeeRole r ON r.employee_id=x.employee_id WHERE x.employee_code=e.employee_code AND r.role_code=e.role_code AND r.valid_from=CONVERT(datetime2(0),''2026-01-01T00:00:00'') AND r.valid_to IS NULL)<>1)
 +(SELECT ABS(COUNT_BIG(*)-4) FROM core.Employee WHERE employee_code LIKE ''EMP-SYN-%'')),
(N''CustomersContactsAddresses'',
 (SELECT COUNT_BIG(*) FROM (VALUES (N''Synthetic Customer Alpha'',N''Synthetic Customer Alpha'',N''alpha@example.invalid'',N''Hyderabad'',N''Synthetic address A'',''500001''),(N''Synthetic Customer Beta'',N''Synthetic Customer Beta'',N''beta@example.invalid'',N''Mumbai'',N''Synthetic address B'',''400001''),(N''Synthetic Customer Gamma'',NULL,NULL,N''Bengaluru'',N''Synthetic address C'',''560001'')) e(display_name,legal_name,email,city_name,address_line1,postal_code)
  WHERE (SELECT COUNT_BIG(*) FROM core.Customer c WHERE c.display_name=e.display_name AND ((e.legal_name IS NULL AND c.legal_name IS NULL) OR c.legal_name=e.legal_name) AND c.status=''ACTIVE'' AND c.created_at=CONVERT(datetime2(0),''2026-01-02T10:00:00''))<>1
     OR (e.email IS NOT NULL AND (SELECT COUNT_BIG(*) FROM core.Customer c JOIN core.CustomerContact x ON x.customer_id=c.customer_id WHERE c.display_name=e.display_name AND x.contact_type=''EMAIL'' AND x.contact_value=e.email AND x.is_verified=0 AND x.valid_from=CONVERT(datetime2(0),''2026-01-02T10:00:00'') AND x.valid_to IS NULL)<>1)
     OR (e.display_name=N''Synthetic Customer Alpha'' AND (SELECT COUNT_BIG(*) FROM core.Customer c JOIN core.CustomerContact x ON x.customer_id=c.customer_id WHERE c.display_name=e.display_name AND x.contact_type=''PHONE'' AND x.contact_value=N''+919000000001'' AND x.is_verified=0 AND x.valid_from=CONVERT(datetime2(0),''2026-01-02T10:00:00'') AND x.valid_to IS NULL)<>1)
     OR (SELECT COUNT_BIG(*) FROM core.Customer c JOIN core.CustomerAddress a ON a.customer_id=c.customer_id JOIN ref.City city ON city.city_id=a.city_id WHERE c.display_name=e.display_name AND city.city_name=e.city_name AND city.country_code=''IN'' AND a.address_type=''HOME'' AND a.address_line1=e.address_line1 AND a.address_line2 IS NULL AND a.postal_code=e.postal_code AND a.valid_from=CONVERT(datetime2(0),''2026-01-02T10:00:00'') AND a.valid_to IS NULL)<>1)
 +(SELECT ABS(COUNT_BIG(*)-3) FROM core.Customer WHERE display_name IN(N''Synthetic Customer Alpha'',N''Synthetic Customer Beta'',N''Synthetic Customer Gamma''))
 +(SELECT ABS(COUNT_BIG(*)-3) FROM core.CustomerContact x JOIN core.Customer c ON c.customer_id=x.customer_id WHERE c.display_name IN(N''Synthetic Customer Alpha'',N''Synthetic Customer Beta'',N''Synthetic Customer Gamma''))
 +(SELECT ABS(COUNT_BIG(*)-3) FROM core.CustomerAddress x JOIN core.Customer c ON c.customer_id=x.customer_id WHERE c.display_name IN(N''Synthetic Customer Alpha'',N''Synthetic Customer Beta'',N''Synthetic Customer Gamma''))),
(N''Catalog'',
 (SELECT ABS(COUNT_BIG(*)-8) FROM vehicle.VehicleBrand WHERE brand_name IN(N''Maruti Suzuki'',N''Hyundai'',N''Tata Motors'',N''Mahindra'',N''Honda'',N''Toyota'',N''Kia'',N''Volkswagen''))
 +(SELECT ABS(COUNT_BIG(*)-7) FROM vehicle.VehicleModel m JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id WHERE (b.brand_name=N''Hyundai'' AND m.model_name=N''Creta'') OR (b.brand_name=N''Maruti Suzuki'' AND m.model_name=N''Swift'') OR (b.brand_name=N''Tata Motors'' AND m.model_name=N''Nexon'') OR (b.brand_name=N''Mahindra'' AND m.model_name=N''XUV700'') OR (b.brand_name=N''Honda'' AND m.model_name=N''City'') OR (b.brand_name=N''Toyota'' AND m.model_name=N''Innova Crysta'') OR (b.brand_name=N''Kia'' AND m.model_name=N''Seltos''))
 +(SELECT ABS(COUNT_BIG(*)-4) FROM vehicle.VehicleVariant v JOIN vehicle.VehicleModel m ON m.model_id=v.model_id JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id WHERE (b.brand_name=N''Hyundai'' AND m.model_name=N''Creta'' AND v.variant_name=N''SX Synthetic'') OR (b.brand_name=N''Maruti Suzuki'' AND m.model_name=N''Swift'' AND v.variant_name=N''VXi Synthetic'') OR (b.brand_name=N''Tata Motors'' AND m.model_name=N''Nexon'' AND v.variant_name=N''XZ+ Synthetic'') OR (b.brand_name=N''Honda'' AND m.model_name=N''City'' AND v.variant_name=N''V Synthetic''))
 +(SELECT ABS(COUNT_BIG(*)-8) FROM vehicle.VehicleBrand)
 +(SELECT ABS(COUNT_BIG(*)-7) FROM vehicle.VehicleModel)
 +(SELECT ABS(COUNT_BIG(*)-4) FROM vehicle.VehicleVariant)),
(N''VehicleRegistrationOwnershipSubmission'',
 (SELECT COUNT_BIG(*) FROM (VALUES (''SYNVIN00000000001'',''SYNENG0001'',2022,''PETROL'',''MANUAL'',N''Synthetic Customer Alpha'',N''Hyundai'',N''Creta'',N''SX Synthetic'',''TS09AB1234'',''TG'',''HYD-CEN''),( ''SYNVIN00000000002'',''SYNENG0002'',2021,''PETROL'',''MANUAL'',N''Synthetic Customer Beta'',N''Maruti Suzuki'',N''Swift'',N''VXi Synthetic'',''MH02CD5678'',''MH'',''MUM-WST''),( ''SYNVIN00000000003'',''SYNENG0003'',2023,''ELECTRIC'',''AUTOMATIC'',N''Synthetic Customer Gamma'',N''Tata Motors'',N''Nexon'',N''XZ+ Synthetic'',''KA03EF9012'',''KA'',''BLR-SOU'')) e(vin,engine_number,manufacture_year,fuel,transmission,owner_name,brand_name,model_name,variant_name,registration_number,state_code,branch_code)
  WHERE NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN vehicle.VehicleModel m ON m.model_id=v.model_id JOIN vehicle.VehicleBrand b ON b.brand_id=m.brand_id JOIN vehicle.VehicleVariant va ON va.variant_id=v.variant_id AND va.model_id=v.model_id JOIN core.Customer c ON c.customer_id=v.current_owner_customer_id WHERE v.vin=e.vin AND v.engine_number=e.engine_number AND v.manufacture_year=e.manufacture_year AND v.fuel_type_code=e.fuel AND v.transmission_type_code=e.transmission AND v.lifecycle_status=CASE WHEN e.vin=''SYNVIN00000000001'' THEN ''RESERVED'' ELSE ''SUBMITTED'' END AND v.created_at=CONVERT(datetime2(0),''2026-01-03T09:00:00'') AND c.display_name=e.owner_name AND b.brand_name=e.brand_name AND m.model_name=e.model_name AND va.variant_name=e.variant_name)
     OR NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN vehicle.VehicleRegistration r ON r.vehicle_id=v.vehicle_id WHERE v.vin=e.vin AND r.registration_number=e.registration_number AND r.issuing_state_code=e.state_code AND r.valid_from=CONVERT(date,''20260103'',112) AND r.valid_to IS NULL)
     OR NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN core.Customer c ON c.display_name=e.owner_name JOIN vehicle.VehicleOwnershipHistory h ON h.vehicle_id=v.vehicle_id AND h.customer_id=c.customer_id WHERE v.vin=e.vin AND h.valid_from=CONVERT(datetime2(0),''2026-01-03T09:00:00'') AND h.valid_to IS NULL AND h.basis_code=''REGISTERED_OWNER'' AND h.evidence_reference=N''Synthetic educational ownership fixture'')
      OR NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN core.Customer c ON c.display_name=e.owner_name JOIN core.Branch b ON b.branch_code=e.branch_code JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id AND s.seller_customer_id=c.customer_id AND s.branch_id=b.branch_id WHERE v.vin=e.vin AND s.submitted_at=CONVERT(datetime2(0),''2026-01-03T10:00:00'') AND ((e.vin=''SYNVIN00000000001'' AND s.status=''ACCEPTED'' AND s.closed_at=CONVERT(datetime2(0),''2026-01-07T09:00:00'')) OR (e.vin<>''SYNVIN00000000001'' AND s.status=''SUBMITTED'' AND s.closed_at IS NULL)) AND s.outcome_reason IS NULL))
 +(SELECT ABS(COUNT_BIG(*)-3) FROM vehicle.Vehicle WHERE vin LIKE ''SYNVIN%'')),
(N''Day2LifecycleFixture'',
 (SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.Employee e ON e.employee_id=i.inspector_employee_id WHERE v.vin=''SYNVIN00000000001'' AND e.employee_code=''EMP-SYN-002'' AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND i.completed_at=CONVERT(datetime2(0),''2026-01-04T10:00:00'') AND i.status=''COMPLETED'') THEN 1 ELSE 0 END)
 +(SELECT COUNT_BIG(*) FROM (VALUES (''SYNVIN00000000001'',''EMP-SYN-002''),( ''SYNVIN00000000002'',''EMP-SYN-002''),( ''SYNVIN00000000003'',''EMP-SYN-002'')) e(vin,employee_code) WHERE (SELECT COUNT_BIG(*) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN vehicle.VehicleSubmission s ON s.submission_id=i.submission_id JOIN core.Employee emp ON emp.employee_id=i.inspector_employee_id WHERE v.vin=e.vin AND emp.employee_code=e.employee_code AND s.submitted_at=CONVERT(datetime2(0),''2026-01-03T10:00:00'') AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND i.completed_at=CONVERT(datetime2(0),''2026-01-04T10:00:00'') AND i.status=''COMPLETED'')<>1)
 +(SELECT ABS(COUNT_BIG(*)-3) FROM inspection.Inspection i JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''SYNVIN%'' AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00''))
 +(SELECT ABS(COUNT_BIG(*)-9) FROM inspection.InspectionItem x JOIN inspection.InspectionReport r ON r.report_id=x.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''SYNVIN%'' AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND x.outcome_code=''PASS'' AND x.note=N''Synthetic checklist result.'')
 +(SELECT COUNT_BIG(*) FROM (VALUES(''SYNVIN00000000001'',''ENGINE''),(''SYNVIN00000000001'',''BRAKES''),(''SYNVIN00000000001'',''BODY''),(''SYNVIN00000000002'',''ENGINE''),(''SYNVIN00000000002'',''BRAKES''),(''SYNVIN00000000002'',''BODY''),(''SYNVIN00000000003'',''ENGINE''),(''SYNVIN00000000003'',''BRAKES''),(''SYNVIN00000000003'',''BODY'')) e(vin,item_code) WHERE NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN inspection.Inspection i ON i.vehicle_id=v.vehicle_id JOIN inspection.InspectionReport r ON r.inspection_id=i.inspection_id JOIN inspection.InspectionItem it ON it.report_id=r.report_id WHERE v.vin=e.vin AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND it.item_code=e.item_code AND it.outcome_code=''PASS'' AND it.note=N''Synthetic checklist result.''))),
(N''Day2ReportsDefectsValuations'',
 (SELECT ABS(COUNT_BIG(*)-3) FROM inspection.InspectionReport r JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin LIKE ''SYNVIN%'' AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND r.outcome_code=''PASS'' AND r.summary=N''Synthetic educational inspection summary.'' AND r.finalized_at=CONVERT(datetime2(0),''2026-01-04T10:05:00''))
 +(SELECT ABS(COUNT_BIG(*)-1) FROM inspection.Defect d JOIN inspection.InspectionItem it ON it.inspection_item_id=d.inspection_item_id JOIN inspection.InspectionReport r ON r.report_id=d.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin=''SYNVIN00000000001'' AND it.item_code=''BODY'' AND d.category_code=''COSMETIC'' AND d.severity_code=''LOW'' AND d.description=N''Synthetic minor exterior mark.'' AND d.repair_estimate=1500 AND d.currency_code=''INR'')
 +(SELECT COUNT_BIG(*) FROM inspection.Defect d JOIN inspection.InspectionItem it ON it.inspection_item_id=d.inspection_item_id WHERE d.description=N''Synthetic minor exterior mark.'' AND d.report_id<>it.report_id)
 +(SELECT COUNT_BIG(*) FROM (VALUES (''SYNVIN00000000001'',850000),( ''SYNVIN00000000002'',600000),( ''SYNVIN00000000003'',1100000)) e(vin,amount) WHERE NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN inspection.VehicleValuation val ON val.vehicle_id=v.vehicle_id JOIN inspection.InspectionReport r ON r.report_id=val.report_id JOIN inspection.Inspection i ON i.inspection_id=r.inspection_id AND i.vehicle_id=v.vehicle_id JOIN core.Employee emp ON emp.employee_id=val.assessor_employee_id WHERE v.vin=e.vin AND i.scheduled_at=CONVERT(datetime2(0),''2026-01-04T09:00:00'') AND val.valued_at=CONVERT(datetime2(0),''2026-01-05T09:00:00'') AND val.amount=e.amount AND val.currency_code=''INR'' AND val.basis=N''Synthetic educational valuation fixture.'' AND val.status=''APPROVED'' AND emp.employee_code=''EMP-SYN-001''))),
(N''Day2AcquisitionInventoryMovement'',
 (SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN vehicle.VehicleSubmission s ON s.vehicle_id=v.vehicle_id JOIN core.Customer seller ON seller.customer_id=s.seller_customer_id JOIN inspection.VehicleValuation val ON val.vehicle_id=v.vehicle_id JOIN acquisition.PurchaseOffer o ON o.submission_id=s.submission_id AND o.valuation_id=val.valuation_id JOIN acquisition.PurchaseAgreement a ON a.offer_id=o.offer_id JOIN acquisition.VehicleAcquisition ac ON ac.agreement_id=a.agreement_id AND ac.vehicle_id=v.vehicle_id JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id JOIN core.Branch b ON b.branch_id=inv.branch_id JOIN inventory.InventoryMovement m ON m.inventory_id=inv.inventory_id JOIN core.Employee emp ON emp.employee_id=m.employee_id WHERE v.vin=''SYNVIN00000000001'' AND seller.display_name=N''Synthetic Customer Alpha'' AND o.offered_at=CONVERT(datetime2(0),''2026-01-05T10:00:00'') AND o.expires_at=CONVERT(datetime2(0),''2026-01-12T10:00:00'') AND o.amount=825000 AND o.currency_code=''INR'' AND o.status=''ACCEPTED'' AND o.decision_at=CONVERT(datetime2(0),''2026-01-06T10:00:00'') AND a.agreement_reference=''SYN-AGR-0001'' AND a.status=''SIGNED'' AND a.signed_at=CONVERT(datetime2(0),''2026-01-06T11:00:00'') AND ac.acquired_at=CONVERT(datetime2(0),''2026-01-07T09:00:00'') AND ac.amount=825000 AND ac.currency_code=''INR'' AND b.branch_code=''HYD-CEN'' AND inv.location_code=''YARD-A1'' AND inv.status=''HELD'' AND inv.since_at=CONVERT(datetime2(0),''2026-01-07T09:05:00'') AND m.movement_type=''RECEIPT'' AND m.to_location_code=''YARD-A1'' AND m.employee_id=emp.employee_id AND emp.employee_code=''EMP-SYN-004'' AND m.occurred_at=inv.since_at AND m.reason=N''Synthetic initial inventory receipt.'') THEN 1 ELSE 0 END)),
(N''Day2MarketplaceLifecycle'',
 (SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN core.Branch b ON b.branch_code=''HYD-CEN'' JOIN marketplace.VehicleListing l ON l.vehicle_id=v.vehicle_id AND l.branch_id=b.branch_id JOIN marketplace.ListingImage im ON im.listing_id=l.listing_id JOIN marketplace.CustomerEnquiry q ON q.listing_id=l.listing_id JOIN core.Customer buyer ON buyer.customer_id=q.customer_id JOIN core.Employee emp ON emp.employee_id=q.assigned_employee_id JOIN marketplace.VehicleReservation r ON r.listing_id=l.listing_id AND r.customer_id=buyer.customer_id WHERE v.vin=''SYNVIN00000000001'' AND l.listed_at=CONVERT(datetime2(0),''2026-01-08T09:00:00'') AND l.status=''PAUSED'' AND l.asking_price=899000 AND l.currency_code=''INR'' AND l.description=N''Synthetic educational listing.'' AND im.image_reference=N''https://example.invalid/synthetic/vehicle-1/front.jpg'' AND im.display_order=1 AND im.caption=N''Synthetic sample image reference'' AND buyer.display_name=N''Synthetic Customer Beta'' AND emp.employee_code=''EMP-SYN-003'' AND q.channel_code=''WEB'' AND q.received_at=CONVERT(datetime2(0),''2026-01-08T10:00:00'') AND q.status=''OPEN'' AND q.message_reference=N''SYNTH-ENQUIRY-001'' AND r.created_at=CONVERT(datetime2(0),''2026-01-09T09:00:00'') AND r.expires_at=CONVERT(datetime2(0),''2026-01-12T09:00:00'') AND r.status=''CONVERTED'' AND r.released_at=CONVERT(datetime2(0),''2026-01-09T09:10:00'')) THEN 1 ELSE 0 END)
 +(SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM vehicle.Vehicle v JOIN inventory.Inventory inv ON inv.vehicle_id=v.vehicle_id JOIN sales.SalesOrderItem oi ON oi.vehicle_id=v.vehicle_id JOIN sales.SalesOrder o ON o.order_id=oi.order_id JOIN core.Customer c ON c.customer_id=o.buyer_customer_id JOIN marketplace.VehicleReservation r ON r.reservation_id=oi.reservation_id WHERE v.vin=''SYNVIN00000000001'' AND inv.status=''HELD'' AND o.created_at=CONVERT(datetime2(0),''2026-01-09T09:15:00'') AND o.status=''CONFIRMED'' AND o.currency_code=''INR'' AND o.confirmed_at=o.created_at AND oi.sale_price=890000 AND oi.currency_code=''INR'' AND c.display_name=N''Synthetic Customer Beta'' AND r.status=''CONVERTED'') THEN 1 ELSE 0 END)),
(N''Day2SalesFinanceDelivery'',
 (SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM finance.Payment p JOIN finance.Refund r ON r.payment_id=p.payment_id JOIN sales.SalesOrder o ON o.order_id=p.order_id JOIN core.Customer c ON c.customer_id=o.buyer_customer_id WHERE p.provider_code=''SYNTHETIC_PROVIDER'' AND p.provider_reference=''SYN-PAY-0001'' AND p.amount=890000 AND p.currency_code=''INR'' AND p.status=''SUCCEEDED'' AND p.initiated_at=CONVERT(datetime2(0),''2026-01-09T09:20:00'') AND p.settled_at=CONVERT(datetime2(0),''2026-01-09T09:21:00'') AND r.provider_reference=''SYN-REF-0001'' AND r.amount=1000 AND r.currency_code=''INR'' AND r.status=''PENDING'' AND c.display_name=N''Synthetic Customer Beta'') THEN 1 ELSE 0 END)
 +(SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM delivery.OwnershipTransfer t JOIN sales.SalesOrderItem i ON i.order_item_id=t.order_item_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id WHERE v.vin=''SYNVIN00000000001'' AND t.authority_reference=''SYN-TRANSFER-0001'' AND t.status=''SUBMITTED'' AND t.submitted_at=CONVERT(datetime2(0),''2026-01-10T10:00:00'')) THEN 1 ELSE 0 END)
 +(SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM delivery.VehicleDelivery d JOIN sales.SalesOrderItem i ON i.order_item_id=d.order_item_id JOIN vehicle.Vehicle v ON v.vehicle_id=i.vehicle_id JOIN core.CustomerAddress a ON a.address_id=d.delivery_address_id WHERE v.vin=''SYNVIN00000000001'' AND d.handover_reference=''SYN-HANDOVER-0001'' AND d.status=''SCHEDULED'' AND d.scheduled_at=CONVERT(datetime2(0),''2026-01-14T10:00:00'') AND a.address_line1=N''Synthetic address B'') THEN 1 ELSE 0 END)),
(N''Day2FixtureTableCardinality'',
 ABS((SELECT COUNT_BIG(*) FROM ref.City)-8)+ABS((SELECT COUNT_BIG(*) FROM core.Branch)-8)+ABS((SELECT COUNT_BIG(*) FROM core.Employee)-4)+ABS((SELECT COUNT_BIG(*) FROM core.EmployeeRole)-4)+ABS((SELECT COUNT_BIG(*) FROM core.Customer)-3)+ABS((SELECT COUNT_BIG(*) FROM core.CustomerContact)-3)+ABS((SELECT COUNT_BIG(*) FROM core.CustomerAddress)-3)
 +ABS((SELECT COUNT_BIG(*) FROM vehicle.VehicleBrand)-8)+ABS((SELECT COUNT_BIG(*) FROM vehicle.VehicleModel)-7)+ABS((SELECT COUNT_BIG(*) FROM vehicle.VehicleVariant)-4)+ABS((SELECT COUNT_BIG(*) FROM vehicle.Vehicle)-3)+ABS((SELECT COUNT_BIG(*) FROM vehicle.VehicleRegistration)-3)+ABS((SELECT COUNT_BIG(*) FROM vehicle.VehicleOwnershipHistory)-3)+ABS((SELECT COUNT_BIG(*) FROM vehicle.VehicleSubmission)-3)
 +ABS((SELECT COUNT_BIG(*) FROM inspection.Inspection)-3)+ABS((SELECT COUNT_BIG(*) FROM inspection.InspectionReport)-3)+ABS((SELECT COUNT_BIG(*) FROM inspection.InspectionItem)-9)+ABS((SELECT COUNT_BIG(*) FROM inspection.Defect)-1)+ABS((SELECT COUNT_BIG(*) FROM inspection.VehicleValuation)-3)
 +ABS((SELECT COUNT_BIG(*) FROM acquisition.PurchaseOffer)-1)+ABS((SELECT COUNT_BIG(*) FROM acquisition.PurchaseAgreement)-1)+ABS((SELECT COUNT_BIG(*) FROM acquisition.VehicleAcquisition)-1)+ABS((SELECT COUNT_BIG(*) FROM inventory.Inventory)-1)+ABS((SELECT COUNT_BIG(*) FROM inventory.InventoryMovement)-1)
 +ABS((SELECT COUNT_BIG(*) FROM marketplace.VehicleListing)-1)+ABS((SELECT COUNT_BIG(*) FROM marketplace.ListingImage)-1)+ABS((SELECT COUNT_BIG(*) FROM marketplace.CustomerEnquiry)-1)+ABS((SELECT COUNT_BIG(*) FROM marketplace.VehicleReservation)-1)+ABS((SELECT COUNT_BIG(*) FROM sales.SalesOrder)-1)+ABS((SELECT COUNT_BIG(*) FROM sales.SalesOrderItem)-1)+ABS((SELECT COUNT_BIG(*) FROM finance.Payment)-1)+ABS((SELECT COUNT_BIG(*) FROM finance.Refund)-1)+ABS((SELECT COUNT_BIG(*) FROM delivery.OwnershipTransfer)-1)+ABS((SELECT COUNT_BIG(*) FROM delivery.VehicleDelivery)-1));
DECLARE @FixtureFailureCount bigint=(SELECT COUNT_BIG(*) FROM @FixtureFindings WHERE failure_count>0);
SELECT fixture_group,CASE WHEN failure_count=0 THEN N''PASS'' ELSE N''FAIL'' END AS fixture_status,failure_count FROM @FixtureFindings ORDER BY fixture_group;
DECLARE @FixtureMismatch bit=CASE WHEN @FixtureFailureCount>0 THEN 1 ELSE 0 END;
SELECT CASE WHEN @SchemaCount<>10 OR @TableCount<>34 OR @PkCount<>34 OR @FkCount<>62 OR @UqCount<>19 OR @CheckCount<>79 OR @DefaultCount<>8 OR @IndexCount<>113 OR @NamedIndexCount<>60 OR @BadConstraintCount>0 OR @FixtureMismatch=1 THEN N''BLOCKED'' WHEN @D3KeyCount>0 THEN N''BLOCKED_RECONCILE_EXISTING_D3_KEYS'' ELSE N''PASS'' END AS readiness_status,
       @SchemaCount AS schemas_found,@TableCount AS modeled_tables,@PkCount AS primary_keys,@FkCount AS foreign_keys,@UqCount AS unique_constraints,@CheckCount AS check_constraints,@DefaultCount AS default_constraints,@IndexCount AS total_indexes,@NamedIndexCount AS named_explicit_indexes,@BadConstraintCount AS disabled_or_untrusted_object_count,@FixtureMismatch AS day2_fixture_mismatch,@D3KeyCount AS existing_day3_namespace_rows,
        N''Any nonzero deterministic-key count blocks generation until every match has been reconciled against the expected payload. This report does not authorize execution.'' AS operator_action;

SELECT CASE WHEN DB_NAME()=N''CARS24DataModelingSystem'' THEN N''TARGET_OK'' ELSE N''BLOCKED'' END AS target_result,
       CASE WHEN NOT EXISTS (SELECT 1 FROM @ExpectedSchemas e LEFT JOIN sys.schemas s ON s.name=e.schema_name WHERE s.schema_id IS NULL)
              AND NOT EXISTS (SELECT 1 FROM @ExpectedTables e LEFT JOIN sys.schemas s ON s.name=e.schema_name LEFT JOIN sys.tables t ON t.schema_id=s.schema_id AND t.name=e.table_name WHERE t.object_id IS NULL)
            THEN N''STRUCTURE_PRESENT'' ELSE N''BLOCKED'' END AS structure_result,
       N''Review every result set, actual counts, fixture markers and D3 key matches before running any generation phase.'' AS operator_action;
 ';
GO


