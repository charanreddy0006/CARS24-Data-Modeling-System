/* Run after setup. Expected implementation: 10 schemas, 34 tables, 34 PKs,
   62 FKs, 19 unique constraints, 79 checks, 8 defaults, and 113 indexes.
   Outputs are grouped by validation area for SSMS review. */
SELECT DB_ID(N'CARS24DataModelingSystem') AS database_id,
       CASE WHEN DB_ID(N'CARS24DataModelingSystem') IS NULL THEN N'MISSING' ELSE N'PRESENT' END AS database_status;
GO
USE [CARS24DataModelingSystem];
GO
SET NOCOUNT ON;

/* 1. Database and schema state. */
SELECT [name] AS database_name, [state_desc], [is_read_only], [compatibility_level]
FROM sys.databases WHERE [name] = N'CARS24DataModelingSystem';

DECLARE @expectedSchemas TABLE ([schema_name] sysname PRIMARY KEY);
INSERT INTO @expectedSchemas ([schema_name]) VALUES
    (N'ref'), (N'core'), (N'vehicle'), (N'inspection'), (N'acquisition'),
    (N'inventory'), (N'marketplace'), (N'sales'), (N'finance'), (N'delivery');
SELECT e.[schema_name], CASE WHEN s.[schema_id] IS NULL THEN N'MISSING' ELSE N'PRESENT' END AS validation_status
FROM @expectedSchemas AS e LEFT JOIN sys.schemas AS s ON s.[name] = e.[schema_name]
ORDER BY e.[schema_name];
SELECT COUNT_BIG(*) AS actual_expected_schema_count, CONVERT(bigint, 10) AS expected_schema_count,
       CASE WHEN COUNT_BIG(*) = 10 THEN N'PASS' ELSE N'FAIL' END AS validation_status
FROM sys.schemas WHERE [name] IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery');

/* 2. Expected table list, missing objects, unexpected objects, and count. */
DECLARE @expectedTables TABLE ([schema_name] sysname NOT NULL, [table_name] sysname NOT NULL, PRIMARY KEY ([schema_name], [table_name]));
INSERT INTO @expectedTables ([schema_name], [table_name]) VALUES
    (N'ref', N'City'),
    (N'core', N'Branch'), (N'core', N'Employee'), (N'core', N'EmployeeRole'),
    (N'core', N'Customer'), (N'core', N'CustomerContact'), (N'core', N'CustomerAddress'),
    (N'vehicle', N'VehicleBrand'), (N'vehicle', N'VehicleModel'), (N'vehicle', N'VehicleVariant'),
    (N'vehicle', N'Vehicle'), (N'vehicle', N'VehicleRegistration'),
    (N'vehicle', N'VehicleOwnershipHistory'), (N'vehicle', N'VehicleSubmission'),
    (N'inspection', N'Inspection'), (N'inspection', N'InspectionReport'),
    (N'inspection', N'InspectionItem'), (N'inspection', N'Defect'), (N'inspection', N'VehicleValuation'),
    (N'acquisition', N'PurchaseOffer'), (N'acquisition', N'PurchaseAgreement'), (N'acquisition', N'VehicleAcquisition'),
    (N'inventory', N'Inventory'), (N'inventory', N'InventoryMovement'),
    (N'marketplace', N'VehicleListing'), (N'marketplace', N'ListingImage'),
    (N'marketplace', N'CustomerEnquiry'), (N'marketplace', N'VehicleReservation'),
    (N'sales', N'SalesOrder'), (N'sales', N'SalesOrderItem'),
    (N'finance', N'Payment'), (N'finance', N'Refund'),
    (N'delivery', N'OwnershipTransfer'), (N'delivery', N'VehicleDelivery');

SELECT e.[schema_name], e.[table_name], N'MISSING' AS validation_status
FROM @expectedTables AS e
LEFT JOIN sys.schemas AS s ON s.[name] = e.[schema_name]
LEFT JOIN sys.tables AS t ON t.[schema_id] = s.[schema_id] AND t.[name] = e.[table_name]
WHERE t.[object_id] IS NULL ORDER BY e.[schema_name], e.[table_name];

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS unexpected_table_name
FROM sys.tables AS t
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
  AND NOT EXISTS (SELECT 1 FROM @expectedTables AS e WHERE e.[schema_name] = SCHEMA_NAME(t.[schema_id]) AND e.[table_name] = t.[name])
ORDER BY schema_name, unexpected_table_name;

SELECT COUNT_BIG(*) AS actual_table_count, CONVERT(bigint, 34) AS expected_table_count,
       CASE WHEN COUNT_BIG(*) = 34 THEN N'PASS' ELSE N'FAIL' END AS validation_status
FROM sys.tables AS t
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery');

/* 3. Keys and constraints. Names and target columns are returned for review. */
SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name,
       kc.[name] AS key_name, kc.[type_desc] AS key_type,
       COUNT_BIG(*) AS actual_key_count, CONVERT(bigint, 1) AS expected_primary_key_per_table
FROM sys.key_constraints AS kc JOIN sys.tables AS t ON t.[object_id] = kc.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
GROUP BY SCHEMA_NAME(t.[schema_id]), t.[name], kc.[name], kc.[type_desc]
ORDER BY schema_name, table_name, key_type, key_name;

SELECT COUNT_BIG(*) AS actual_primary_key_count, CONVERT(bigint, 34) AS expected_primary_key_count,
       CASE WHEN COUNT_BIG(*) = 34 THEN N'PASS' ELSE N'FAIL' END AS validation_status
FROM sys.key_constraints AS kc JOIN sys.tables AS t ON t.[object_id] = kc.[parent_object_id]
WHERE kc.[type] = 'PK' AND SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery');

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS child_table,
       fk.[name] AS foreign_key_name, OBJECT_SCHEMA_NAME(fk.[referenced_object_id]) AS parent_schema,
       OBJECT_NAME(fk.[referenced_object_id]) AS parent_table, fk.[is_disabled], fk.[is_not_trusted]
FROM sys.foreign_keys AS fk JOIN sys.tables AS t ON t.[object_id] = fk.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
ORDER BY schema_name, child_table, foreign_key_name;

DECLARE @expectedForeignKeys TABLE ([foreign_key_name] sysname PRIMARY KEY);
INSERT INTO @expectedForeignKeys ([foreign_key_name]) VALUES
    (N'FK_Branch_City_city_id'), (N'FK_CustomerAddress_City_city_id'),
    (N'FK_CustomerAddress_Customer_customer_id'), (N'FK_CustomerContact_Customer_customer_id'),
    (N'FK_CustomerEnquiry_Customer_customer_id'), (N'FK_CustomerEnquiry_Employee_assigned_employee_id'),
    (N'FK_CustomerEnquiry_VehicleListing_listing_id'), (N'FK_Defect_InspectionItem_inspection_item_id'),
    (N'FK_Defect_InspectionReport_report_id'), (N'FK_Employee_Branch_branch_id'),
    (N'FK_EmployeeRole_Employee_employee_id'), (N'FK_Inspection_Employee_inspector_employee_id'),
    (N'FK_Inspection_Vehicle_vehicle_id'), (N'FK_Inspection_VehicleSubmission_submission_id'),
    (N'FK_InspectionItem_InspectionReport_report_id'), (N'FK_InspectionReport_Inspection_inspection_id'),
    (N'FK_Inventory_Branch_branch_id'), (N'FK_Inventory_Vehicle_vehicle_id'),
    (N'FK_InventoryMovement_Branch_from_branch_id'), (N'FK_InventoryMovement_Branch_to_branch_id'),
    (N'FK_InventoryMovement_Employee_employee_id'), (N'FK_InventoryMovement_Inventory_inventory_id'),
    (N'FK_ListingImage_VehicleListing_listing_id'), (N'FK_OwnershipTransfer_Customer_from_customer_id'),
    (N'FK_OwnershipTransfer_Customer_to_customer_id'), (N'FK_OwnershipTransfer_SalesOrderItem_order_item_id'),
    (N'FK_Payment_SalesOrder_order_id'), (N'FK_PurchaseAgreement_Customer_seller_customer_id'),
    (N'FK_PurchaseAgreement_PurchaseOffer_offer_id'), (N'FK_PurchaseOffer_Customer_seller_customer_id'),
    (N'FK_PurchaseOffer_VehicleSubmission_submission_id'), (N'FK_PurchaseOffer_VehicleValuation_valuation_id'),
    (N'FK_Refund_Payment_payment_id'), (N'FK_SalesOrder_Customer_buyer_customer_id'),
    (N'FK_SalesOrderItem_SalesOrder_order_id'), (N'FK_SalesOrderItem_Vehicle_vehicle_id'),
    (N'FK_SalesOrderItem_VehicleReservation_reservation_id'), (N'FK_Vehicle_Customer_current_owner_customer_id'),
    (N'FK_Vehicle_VehicleModel_model_id'), (N'FK_Vehicle_VehicleVariant_variant_id_model_id'),
    (N'FK_VehicleAcquisition_Customer_seller_customer_id'), (N'FK_VehicleAcquisition_PurchaseAgreement_agreement_id'),
    (N'FK_VehicleAcquisition_Vehicle_vehicle_id'), (N'FK_VehicleDelivery_Branch_branch_id'),
    (N'FK_VehicleDelivery_Customer_recipient_customer_id'), (N'FK_VehicleDelivery_CustomerAddress_delivery_address_id'),
    (N'FK_VehicleDelivery_SalesOrderItem_order_item_id'), (N'FK_VehicleListing_Branch_branch_id'),
    (N'FK_VehicleListing_Vehicle_vehicle_id'), (N'FK_VehicleModel_VehicleBrand_brand_id'),
    (N'FK_VehicleOwnershipHistory_Customer_customer_id'), (N'FK_VehicleOwnershipHistory_Vehicle_vehicle_id'),
    (N'FK_VehicleRegistration_Vehicle_vehicle_id'), (N'FK_VehicleReservation_Customer_customer_id'),
    (N'FK_VehicleReservation_VehicleListing_listing_id'), (N'FK_VehicleSubmission_Branch_branch_id'),
    (N'FK_VehicleSubmission_Customer_seller_customer_id'), (N'FK_VehicleSubmission_Vehicle_vehicle_id'),
    (N'FK_VehicleValuation_Employee_assessor_employee_id'), (N'FK_VehicleValuation_InspectionReport_report_id'),
    (N'FK_VehicleValuation_Vehicle_vehicle_id'), (N'FK_VehicleVariant_VehicleModel_model_id');

SELECT e.[foreign_key_name], N'MISSING' AS validation_status
FROM @expectedForeignKeys AS e LEFT JOIN sys.foreign_keys AS fk ON fk.[name] = e.[foreign_key_name]
WHERE fk.[object_id] IS NULL ORDER BY e.[foreign_key_name];
SELECT fk.[name] AS unexpected_foreign_key_name, N'UNEXPECTED' AS validation_status
FROM sys.foreign_keys AS fk JOIN sys.tables AS t ON t.[object_id] = fk.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
  AND NOT EXISTS (SELECT 1 FROM @expectedForeignKeys AS e WHERE e.[foreign_key_name] = fk.[name])
ORDER BY unexpected_foreign_key_name;

SELECT COUNT_BIG(*) AS actual_foreign_key_count, CONVERT(bigint, 62) AS expected_foreign_key_count,
       COALESCE(SUM(CASE WHEN fk.[is_disabled] = 1 OR fk.[is_not_trusted] = 1 THEN 1 ELSE 0 END), 0) AS disabled_or_untrusted_foreign_keys,
       CASE WHEN COUNT_BIG(*) = 62 AND COALESCE(SUM(CASE WHEN fk.[is_disabled] = 1 OR fk.[is_not_trusted] = 1 THEN 1 ELSE 0 END), 0) = 0 THEN N'PASS' ELSE N'FAIL' END AS validation_status
FROM sys.foreign_keys AS fk JOIN sys.tables AS t ON t.[object_id] = fk.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery');

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name,
       cc.[name] AS check_name, cc.[definition], cc.[is_disabled], cc.[is_not_trusted]
FROM sys.check_constraints AS cc JOIN sys.tables AS t ON t.[object_id] = cc.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
ORDER BY schema_name, table_name, check_name;

SELECT N'UNIQUE_CONSTRAINT' AS structure_type, COUNT_BIG(*) AS actual_count, CONVERT(bigint, 19) AS expected_count,
       CASE WHEN COUNT_BIG(*) = 19 THEN N'PASS' ELSE N'FAIL' END AS validation_status
FROM sys.key_constraints AS kc JOIN sys.tables AS t ON t.[object_id] = kc.[parent_object_id]
WHERE kc.[type] = 'UQ' AND SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
UNION ALL SELECT N'CHECK_CONSTRAINT', COUNT_BIG(*), CONVERT(bigint, 79), CASE WHEN COUNT_BIG(*) = 79 THEN N'PASS' ELSE N'FAIL' END
FROM sys.check_constraints AS cc JOIN sys.tables AS t ON t.[object_id] = cc.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
UNION ALL SELECT N'DEFAULT_CONSTRAINT', COUNT_BIG(*), CONVERT(bigint, 8), CASE WHEN COUNT_BIG(*) = 8 THEN N'PASS' ELSE N'FAIL' END
FROM sys.default_constraints AS dc JOIN sys.tables AS t ON t.[object_id] = dc.[parent_object_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
UNION ALL SELECT N'TOTAL_INDEX', COUNT_BIG(*), CONVERT(bigint, 113), CASE WHEN COUNT_BIG(*) = 113 THEN N'PASS' ELSE N'FAIL' END
FROM sys.indexes AS i JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
WHERE i.[index_id] > 0 AND SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery');

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name,
       dc.[name] AS default_name, c.[name] AS column_name, dc.[definition]
FROM sys.default_constraints AS dc
JOIN sys.tables AS t ON t.[object_id] = dc.[parent_object_id]
JOIN sys.columns AS c ON c.[object_id] = dc.[parent_object_id] AND c.[column_id] = dc.[parent_column_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
ORDER BY schema_name, table_name, default_name;

/* 4. Index definitions, including filtered and unique indexes. */
SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name,
       i.[name] AS index_name, i.[type_desc] AS index_type, i.[is_unique], i.[is_primary_key],
       i.[has_filter], i.[filter_definition],
       STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(c.[name])), N', ') WITHIN GROUP (ORDER BY ic.[key_ordinal]) AS key_columns
FROM sys.indexes AS i
JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
JOIN sys.index_columns AS ic ON ic.[object_id] = i.[object_id] AND ic.[index_id] = i.[index_id] AND ic.[is_included_column] = 0
JOIN sys.columns AS c ON c.[object_id] = ic.[object_id] AND c.[column_id] = ic.[column_id]
WHERE SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery') AND i.[index_id] > 0
GROUP BY SCHEMA_NAME(t.[schema_id]), t.[name], i.[name], i.[type_desc], i.[is_unique], i.[is_primary_key], i.[has_filter], i.[filter_definition]
ORDER BY schema_name, table_name, index_name;

/* 5. Seed record counts. Clean install expectations are in 10_seed_reference_data.sql. */
SELECT N'ref.City' AS table_name, COUNT_BIG(*) AS row_count FROM [ref].[City]
UNION ALL SELECT N'core.Branch', COUNT_BIG(*) FROM [core].[Branch]
UNION ALL SELECT N'core.Employee', COUNT_BIG(*) FROM [core].[Employee]
UNION ALL SELECT N'core.EmployeeRole', COUNT_BIG(*) FROM [core].[EmployeeRole]
UNION ALL SELECT N'core.Customer', COUNT_BIG(*) FROM [core].[Customer]
UNION ALL SELECT N'core.CustomerContact', COUNT_BIG(*) FROM [core].[CustomerContact]
UNION ALL SELECT N'core.CustomerAddress', COUNT_BIG(*) FROM [core].[CustomerAddress]
UNION ALL SELECT N'vehicle.VehicleBrand', COUNT_BIG(*) FROM [vehicle].[VehicleBrand]
UNION ALL SELECT N'vehicle.VehicleModel', COUNT_BIG(*) FROM [vehicle].[VehicleModel]
UNION ALL SELECT N'vehicle.VehicleVariant', COUNT_BIG(*) FROM [vehicle].[VehicleVariant]
UNION ALL SELECT N'vehicle.Vehicle', COUNT_BIG(*) FROM [vehicle].[Vehicle]
UNION ALL SELECT N'vehicle.VehicleRegistration', COUNT_BIG(*) FROM [vehicle].[VehicleRegistration]
UNION ALL SELECT N'vehicle.VehicleOwnershipHistory', COUNT_BIG(*) FROM [vehicle].[VehicleOwnershipHistory]
UNION ALL SELECT N'vehicle.VehicleSubmission', COUNT_BIG(*) FROM [vehicle].[VehicleSubmission]
UNION ALL SELECT N'inspection.Inspection', COUNT_BIG(*) FROM [inspection].[Inspection]
UNION ALL SELECT N'inspection.InspectionReport', COUNT_BIG(*) FROM [inspection].[InspectionReport]
UNION ALL SELECT N'inspection.InspectionItem', COUNT_BIG(*) FROM [inspection].[InspectionItem]
UNION ALL SELECT N'inspection.Defect', COUNT_BIG(*) FROM [inspection].[Defect]
UNION ALL SELECT N'inspection.VehicleValuation', COUNT_BIG(*) FROM [inspection].[VehicleValuation]
UNION ALL SELECT N'acquisition.PurchaseOffer', COUNT_BIG(*) FROM [acquisition].[PurchaseOffer]
UNION ALL SELECT N'acquisition.PurchaseAgreement', COUNT_BIG(*) FROM [acquisition].[PurchaseAgreement]
UNION ALL SELECT N'acquisition.VehicleAcquisition', COUNT_BIG(*) FROM [acquisition].[VehicleAcquisition]
UNION ALL SELECT N'inventory.Inventory', COUNT_BIG(*) FROM [inventory].[Inventory]
UNION ALL SELECT N'inventory.InventoryMovement', COUNT_BIG(*) FROM [inventory].[InventoryMovement]
UNION ALL SELECT N'marketplace.VehicleListing', COUNT_BIG(*) FROM [marketplace].[VehicleListing]
UNION ALL SELECT N'marketplace.ListingImage', COUNT_BIG(*) FROM [marketplace].[ListingImage]
UNION ALL SELECT N'marketplace.CustomerEnquiry', COUNT_BIG(*) FROM [marketplace].[CustomerEnquiry]
UNION ALL SELECT N'marketplace.VehicleReservation', COUNT_BIG(*) FROM [marketplace].[VehicleReservation]
UNION ALL SELECT N'sales.SalesOrder', COUNT_BIG(*) FROM [sales].[SalesOrder]
UNION ALL SELECT N'sales.SalesOrderItem', COUNT_BIG(*) FROM [sales].[SalesOrderItem]
UNION ALL SELECT N'finance.Payment', COUNT_BIG(*) FROM [finance].[Payment]
UNION ALL SELECT N'finance.Refund', COUNT_BIG(*) FROM [finance].[Refund]
UNION ALL SELECT N'delivery.OwnershipTransfer', COUNT_BIG(*) FROM [delivery].[OwnershipTransfer]
UNION ALL SELECT N'delivery.VehicleDelivery', COUNT_BIG(*) FROM [delivery].[VehicleDelivery]
ORDER BY table_name;

/* 6. Duplicate business identifiers. Every result set should be empty. */
SELECT [city_name], [state_code], [country_code], COUNT_BIG(*) AS duplicate_count FROM [ref].[City] GROUP BY [city_name], [state_code], [country_code] HAVING COUNT_BIG(*) > 1;
SELECT [branch_code], COUNT_BIG(*) AS duplicate_count FROM [core].[Branch] GROUP BY [branch_code] HAVING COUNT_BIG(*) > 1;
SELECT [employee_code], COUNT_BIG(*) AS duplicate_count FROM [core].[Employee] GROUP BY [employee_code] HAVING COUNT_BIG(*) > 1;
SELECT [brand_name], COUNT_BIG(*) AS duplicate_count FROM [vehicle].[VehicleBrand] GROUP BY [brand_name] HAVING COUNT_BIG(*) > 1;
SELECT [vin], COUNT_BIG(*) AS duplicate_count FROM [vehicle].[Vehicle] WHERE [vin] IS NOT NULL GROUP BY [vin] HAVING COUNT_BIG(*) > 1;
SELECT [provider_code], [provider_reference], COUNT_BIG(*) AS duplicate_count FROM [finance].[Payment] WHERE [provider_reference] IS NOT NULL GROUP BY [provider_code], [provider_reference] HAVING COUNT_BIG(*) > 1;
SELECT [provider_reference], COUNT_BIG(*) AS duplicate_count FROM [finance].[Refund] WHERE [provider_reference] IS NOT NULL GROUP BY [provider_reference] HAVING COUNT_BIG(*) > 1;

/* 7. Mandatory columns are enforced NOT NULL in DDL; show the actual metadata. */
SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name, c.[name] AS mandatory_column
FROM sys.columns AS c JOIN sys.tables AS t ON t.[object_id] = c.[object_id]
WHERE c.[is_nullable] = 0 AND SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery')
ORDER BY schema_name, table_name, mandatory_column;

DECLARE @mandatoryNullCheckSql nvarchar(max);
SELECT @mandatoryNullCheckSql = STRING_AGG
(
    CONVERT(nvarchar(max),
        N'SELECT ' + QUOTENAME(SCHEMA_NAME(t.[schema_id]) + N'.' + t.[name] + N'.' + c.[name], '''') +
        N' AS column_name, COUNT_BIG(*) AS null_count FROM ' + QUOTENAME(SCHEMA_NAME(t.[schema_id])) + N'.' + QUOTENAME(t.[name]) +
        N' WHERE ' + QUOTENAME(c.[name]) + N' IS NULL HAVING COUNT_BIG(*) > 0'),
    N' UNION ALL '
)
FROM sys.columns AS c JOIN sys.tables AS t ON t.[object_id] = c.[object_id]
WHERE c.[is_nullable] = 0 AND SCHEMA_NAME(t.[schema_id]) IN (N'ref', N'core', N'vehicle', N'inspection', N'acquisition', N'inventory', N'marketplace', N'sales', N'finance', N'delivery');
IF @mandatoryNullCheckSql IS NULL
    SELECT N'PASS' AS mandatory_null_check, N'No mandatory columns were found.' AS detail;
ELSE
    EXEC sys.sp_executesql @mandatoryNullCheckSql;

/* 8. Temporal and lifecycle consistency diagnostics. These rules need TX/APP
   enforcement and should return no conflicts for the supplied synthetic data. */
SELECT h1.[vehicle_id], h1.[ownership_history_id], h2.[ownership_history_id] AS overlapping_history_id
FROM [vehicle].[VehicleOwnershipHistory] AS h1
JOIN [vehicle].[VehicleOwnershipHistory] AS h2 ON h1.[vehicle_id] = h2.[vehicle_id] AND h1.[ownership_history_id] < h2.[ownership_history_id]
 AND h1.[valid_from] < COALESCE(h2.[valid_to], CONVERT(datetime2(0), '9999-12-31T23:59:59'))
 AND h2.[valid_from] < COALESCE(h1.[valid_to], CONVERT(datetime2(0), '9999-12-31T23:59:59'));

SELECT v.[vehicle_id], v.[vin], v.[current_owner_customer_id]
FROM [vehicle].[Vehicle] AS v
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleOwnershipHistory] AS h WHERE h.[vehicle_id] = v.[vehicle_id] AND h.[customer_id] = v.[current_owner_customer_id] AND h.[valid_to] IS NULL);

SELECT N'Vehicle year/code checks' AS check_name,
       (SELECT COUNT_BIG(*) FROM [vehicle].[Vehicle] WHERE [manufacture_year] NOT BETWEEN 1886 AND 2100)
     + (SELECT COUNT_BIG(*) FROM [vehicle].[Vehicle] WHERE [fuel_type_code] NOT IN ('PETROL', 'DIESEL', 'CNG', 'ELECTRIC', 'HYBRID'))
     + (SELECT COUNT_BIG(*) FROM [vehicle].[Vehicle] WHERE [transmission_type_code] NOT IN ('MANUAL', 'AUTOMATIC', 'AMT', 'CVT', 'DCT')) AS violation_count;

/* SQL Server checks all enabled CHECK and FOREIGN KEY constraints, including
   every FK relation in the database. Empty output means no violations. */
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
GO
