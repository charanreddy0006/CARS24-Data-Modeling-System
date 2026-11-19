/* READ-ONLY diagnostic for the existing CARS24DataModelingSystem database.
   Expected object definitions are derived from the canonical Day 2 SQL sources,
   especially 09_indexes.sql. This script does not repair or modify anything. */
USE [master];
GO
SET NOCOUNT ON;

SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) AS server_name,
       CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS product_version,
       CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS edition,
       TRY_CONVERT(int, SERVERPROPERTY('EngineEdition')) AS engine_edition,
       DB_ID(N'CARS24DataModelingSystem') AS target_database_id,
       CASE WHEN DB_ID(N'CARS24DataModelingSystem') IS NULL THEN N'MISSING' ELSE N'EXISTS' END AS existence_status;

SELECT [name] AS database_name, [state_desc], [is_read_only], [compatibility_level],
       [create_date], HAS_DBACCESS([name]) AS has_db_access
FROM sys.databases WHERE [name] = N'CARS24DataModelingSystem';
GO

/* Target must exist to run the catalog and data diagnostics below. */
USE [CARS24DataModelingSystem];
GO
SET NOCOUNT ON;

SELECT DB_NAME() AS current_database, d.[state_desc], d.[is_read_only], d.[compatibility_level]
FROM sys.databases AS d WHERE d.[database_id] = DB_ID();
/* If can_view_definition is 0, catalog visibility may be incomplete; do not
   interpret missing-object rows as definitive until run with sufficient rights. */
SELECT HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DEFINITION') AS can_view_definition,
       HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DATABASE STATE') AS can_view_database_state;

DECLARE @ExpectedSchemas TABLE ([schema_name] sysname PRIMARY KEY);
INSERT INTO @ExpectedSchemas VALUES
    (N'ref'), (N'core'), (N'vehicle'), (N'inspection'), (N'acquisition'),
    (N'inventory'), (N'marketplace'), (N'sales'), (N'finance'), (N'delivery');

DECLARE @ExpectedTables TABLE ([schema_name] sysname NOT NULL, [table_name] sysname NOT NULL,
    PRIMARY KEY ([schema_name], [table_name]));
INSERT INTO @ExpectedTables VALUES
    (N'ref',N'City'),
    (N'core',N'Branch'),(N'core',N'Employee'),(N'core',N'EmployeeRole'),(N'core',N'Customer'),(N'core',N'CustomerContact'),(N'core',N'CustomerAddress'),
    (N'vehicle',N'VehicleBrand'),(N'vehicle',N'VehicleModel'),(N'vehicle',N'VehicleVariant'),(N'vehicle',N'Vehicle'),(N'vehicle',N'VehicleRegistration'),(N'vehicle',N'VehicleOwnershipHistory'),(N'vehicle',N'VehicleSubmission'),
    (N'inspection',N'Inspection'),(N'inspection',N'InspectionReport'),(N'inspection',N'InspectionItem'),(N'inspection',N'Defect'),(N'inspection',N'VehicleValuation'),
    (N'acquisition',N'PurchaseOffer'),(N'acquisition',N'PurchaseAgreement'),(N'acquisition',N'VehicleAcquisition'),
    (N'inventory',N'Inventory'),(N'inventory',N'InventoryMovement'),
    (N'marketplace',N'VehicleListing'),(N'marketplace',N'ListingImage'),(N'marketplace',N'CustomerEnquiry'),(N'marketplace',N'VehicleReservation'),
    (N'sales',N'SalesOrder'),(N'sales',N'SalesOrderItem'),(N'finance',N'Payment'),(N'finance',N'Refund'),
    (N'delivery',N'OwnershipTransfer'),(N'delivery',N'VehicleDelivery');

/* Expected schema and table coverage. */
SELECT e.[schema_name], CASE WHEN s.[schema_id] IS NULL THEN N'MISSING' ELSE N'PRESENT' END AS status
FROM @ExpectedSchemas AS e LEFT JOIN sys.schemas AS s ON s.[name] = e.[schema_name]
ORDER BY e.[schema_name];
SELECT e.[schema_name], e.[table_name], CASE WHEN t.[object_id] IS NULL THEN N'MISSING' ELSE N'PRESENT' END AS status
FROM @ExpectedTables AS e LEFT JOIN sys.schemas AS s ON s.[name] = e.[schema_name]
LEFT JOIN sys.tables AS t ON t.[schema_id] = s.[schema_id] AND t.[name] = e.[table_name]
ORDER BY e.[schema_name], e.[table_name];
SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS unexpected_table
FROM sys.tables AS t JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id])
WHERE NOT EXISTS (SELECT 1 FROM @ExpectedTables AS e WHERE e.[schema_name] = s.[schema_name] AND e.[table_name] = t.[name])
ORDER BY schema_name, unexpected_table;
SELECT e.[schema_name], e.[table_name], COALESCE(SUM(ps.[rows]),0) AS approximate_row_count
FROM @ExpectedTables AS e
LEFT JOIN sys.schemas AS s ON s.[name] = e.[schema_name]
LEFT JOIN sys.tables AS t ON t.[schema_id] = s.[schema_id] AND t.[name] = e.[table_name]
LEFT JOIN sys.partitions AS ps ON ps.[object_id] = t.[object_id] AND ps.[index_id] IN (0,1)
GROUP BY e.[schema_name], e.[table_name] ORDER BY e.[schema_name], e.[table_name];

/* Key and constraint inventory and exact FK-name coverage. */
SELECT N'PRIMARY_KEY' AS object_type, COUNT_BIG(*) AS actual_count, CONVERT(bigint,34) AS expected_count
FROM sys.key_constraints AS k JOIN sys.tables AS t ON t.[object_id] = k.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE k.[type] = 'PK'
UNION ALL
SELECT N'UNIQUE_CONSTRAINT', COUNT_BIG(*), CONVERT(bigint,19)
FROM sys.key_constraints AS k JOIN sys.tables AS t ON t.[object_id] = k.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE k.[type] = 'UQ'
UNION ALL
SELECT N'FOREIGN_KEY', COUNT_BIG(*), CONVERT(bigint,62)
FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.[object_id] = f.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id])
UNION ALL
SELECT N'CHECK_CONSTRAINT', COUNT_BIG(*), CONVERT(bigint,79)
FROM sys.check_constraints AS c JOIN sys.tables AS t ON t.[object_id] = c.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id])
UNION ALL
SELECT N'DEFAULT_CONSTRAINT', COUNT_BIG(*), CONVERT(bigint,8)
FROM sys.default_constraints AS d JOIN sys.tables AS t ON t.[object_id] = d.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]);

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name, k.[name] AS constraint_name,
       k.[type_desc], kc.[key_columns], i.[is_disabled], i.[is_unique], i.[type_desc] AS backing_index_type
FROM sys.key_constraints AS k JOIN sys.tables AS t ON t.[object_id] = k.[parent_object_id]
LEFT JOIN sys.indexes AS i ON i.[object_id] = k.[parent_object_id] AND i.[index_id] = k.[unique_index_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id])
OUTER APPLY
(
    SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(c.[name]) + N' ' + CASE WHEN ic.[is_descending_key] = 1 THEN N'DESC' ELSE N'ASC' END), N';')
           WITHIN GROUP (ORDER BY ic.[key_ordinal]) AS key_columns
    FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.[object_id] = ic.[object_id] AND c.[column_id] = ic.[column_id]
    WHERE ic.[object_id] = k.[parent_object_id] AND ic.[index_id] = k.[unique_index_id] AND ic.[key_ordinal] > 0
) AS kc
ORDER BY schema_name, table_name, constraint_name;

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name, f.[name] AS foreign_key_name,
       OBJECT_SCHEMA_NAME(f.[referenced_object_id]) AS parent_schema, OBJECT_NAME(f.[referenced_object_id]) AS parent_table,
       fkcols.[child_columns], fkcols.[parent_columns],
       f.[delete_referential_action_desc], f.[update_referential_action_desc], f.[is_disabled], f.[is_not_trusted]
FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.[object_id] = f.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id])
OUTER APPLY
(
    SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(cc.[name])), N';') WITHIN GROUP (ORDER BY fkc.[constraint_column_id]) AS child_columns,
           STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(pc.[name])), N';') WITHIN GROUP (ORDER BY fkc.[constraint_column_id]) AS parent_columns
    FROM sys.foreign_key_columns AS fkc
    JOIN sys.columns AS cc ON cc.[object_id] = fkc.[parent_object_id] AND cc.[column_id] = fkc.[parent_column_id]
    JOIN sys.columns AS pc ON pc.[object_id] = fkc.[referenced_object_id] AND pc.[column_id] = fkc.[referenced_column_id]
    WHERE fkc.[constraint_object_id] = f.[object_id]
) AS fkcols
ORDER BY schema_name, table_name, foreign_key_name;

DECLARE @ExpectedForeignKeys TABLE ([foreign_key_name] sysname PRIMARY KEY);
INSERT INTO @ExpectedForeignKeys VALUES
    (N'FK_Branch_City_city_id'),(N'FK_CustomerAddress_City_city_id'),(N'FK_CustomerAddress_Customer_customer_id'),(N'FK_CustomerContact_Customer_customer_id'),
    (N'FK_CustomerEnquiry_Customer_customer_id'),(N'FK_CustomerEnquiry_Employee_assigned_employee_id'),(N'FK_CustomerEnquiry_VehicleListing_listing_id'),
    (N'FK_Defect_InspectionItem_inspection_item_id'),(N'FK_Defect_InspectionReport_report_id'),(N'FK_Employee_Branch_branch_id'),(N'FK_EmployeeRole_Employee_employee_id'),
    (N'FK_Inspection_Employee_inspector_employee_id'),(N'FK_Inspection_Vehicle_vehicle_id'),(N'FK_Inspection_VehicleSubmission_submission_id'),
    (N'FK_InspectionItem_InspectionReport_report_id'),(N'FK_InspectionReport_Inspection_inspection_id'),(N'FK_Inventory_Branch_branch_id'),
    (N'FK_Inventory_Vehicle_vehicle_id'),(N'FK_InventoryMovement_Branch_from_branch_id'),(N'FK_InventoryMovement_Branch_to_branch_id'),
    (N'FK_InventoryMovement_Employee_employee_id'),(N'FK_InventoryMovement_Inventory_inventory_id'),(N'FK_ListingImage_VehicleListing_listing_id'),
    (N'FK_OwnershipTransfer_Customer_from_customer_id'),(N'FK_OwnershipTransfer_Customer_to_customer_id'),(N'FK_OwnershipTransfer_SalesOrderItem_order_item_id'),
    (N'FK_Payment_SalesOrder_order_id'),(N'FK_PurchaseAgreement_Customer_seller_customer_id'),(N'FK_PurchaseAgreement_PurchaseOffer_offer_id'),
    (N'FK_PurchaseOffer_Customer_seller_customer_id'),(N'FK_PurchaseOffer_VehicleSubmission_submission_id'),(N'FK_PurchaseOffer_VehicleValuation_valuation_id'),
    (N'FK_Refund_Payment_payment_id'),(N'FK_SalesOrder_Customer_buyer_customer_id'),(N'FK_SalesOrderItem_SalesOrder_order_id'),
    (N'FK_SalesOrderItem_Vehicle_vehicle_id'),(N'FK_SalesOrderItem_VehicleReservation_reservation_id'),(N'FK_Vehicle_Customer_current_owner_customer_id'),
    (N'FK_Vehicle_VehicleModel_model_id'),(N'FK_Vehicle_VehicleVariant_variant_id_model_id'),(N'FK_VehicleAcquisition_Customer_seller_customer_id'),
    (N'FK_VehicleAcquisition_PurchaseAgreement_agreement_id'),(N'FK_VehicleAcquisition_Vehicle_vehicle_id'),(N'FK_VehicleDelivery_Branch_branch_id'),
    (N'FK_VehicleDelivery_Customer_recipient_customer_id'),(N'FK_VehicleDelivery_CustomerAddress_delivery_address_id'),
    (N'FK_VehicleDelivery_SalesOrderItem_order_item_id'),(N'FK_VehicleListing_Branch_branch_id'),(N'FK_VehicleListing_Vehicle_vehicle_id'),
    (N'FK_VehicleModel_VehicleBrand_brand_id'),(N'FK_VehicleOwnershipHistory_Customer_customer_id'),(N'FK_VehicleOwnershipHistory_Vehicle_vehicle_id'),
    (N'FK_VehicleRegistration_Vehicle_vehicle_id'),(N'FK_VehicleReservation_Customer_customer_id'),(N'FK_VehicleReservation_VehicleListing_listing_id'),
    (N'FK_VehicleSubmission_Branch_branch_id'),(N'FK_VehicleSubmission_Customer_seller_customer_id'),(N'FK_VehicleSubmission_Vehicle_vehicle_id'),
    (N'FK_VehicleValuation_Employee_assessor_employee_id'),(N'FK_VehicleValuation_InspectionReport_report_id'),
    (N'FK_VehicleValuation_Vehicle_vehicle_id'),(N'FK_VehicleVariant_VehicleModel_model_id');
SELECT e.[foreign_key_name], N'MISSING' AS status FROM @ExpectedForeignKeys AS e
LEFT JOIN sys.foreign_keys AS f ON f.[name] = e.[foreign_key_name] WHERE f.[object_id] IS NULL ORDER BY e.[foreign_key_name];
SELECT f.[name] AS unexpected_foreign_key FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.[object_id] = f.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id])
WHERE NOT EXISTS (SELECT 1 FROM @ExpectedForeignKeys AS e WHERE e.[foreign_key_name] = f.[name]) ORDER BY f.[name];

SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name, c.[name] AS constraint_name,
       c.[definition], c.[is_disabled], c.[is_not_trusted]
FROM sys.check_constraints AS c JOIN sys.tables AS t ON t.[object_id] = c.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) ORDER BY schema_name, table_name, constraint_name;
SELECT SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name, d.[name] AS constraint_name,
       d.[definition], c.[name] AS column_name
FROM sys.default_constraints AS d JOIN sys.tables AS t ON t.[object_id] = d.[parent_object_id]
JOIN sys.columns AS c ON c.[object_id] = d.[parent_object_id] AND c.[column_id] = d.[parent_column_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) ORDER BY schema_name, table_name, constraint_name;

SELECT N'DISABLED_FOREIGN_KEY' AS object_type, SCHEMA_NAME(t.[schema_id]) AS schema_name, t.[name] AS table_name, f.[name] AS object_name
FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.[object_id] = f.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE f.[is_disabled] = 1
UNION ALL
SELECT N'UNTRUSTED_FOREIGN_KEY', SCHEMA_NAME(t.[schema_id]), t.[name], f.[name]
FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.[object_id] = f.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE f.[is_not_trusted] = 1
UNION ALL
SELECT N'DISABLED_CHECK', SCHEMA_NAME(t.[schema_id]), t.[name], c.[name]
FROM sys.check_constraints AS c JOIN sys.tables AS t ON t.[object_id] = c.[parent_object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE c.[is_disabled] = 1 OR c.[is_not_trusted] = 1
UNION ALL
SELECT N'DISABLED_INDEX', SCHEMA_NAME(t.[schema_id]), t.[name], i.[name]
FROM sys.indexes AS i JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE i.[is_disabled] = 1;

/* Exact index manifest sourced from 09_indexes.sql. Key column order/direction,
   INCLUDE list, uniqueness, and filter predicate are compared below. */
DECLARE @ExpectedIndexes TABLE
(
    [schema_name] sysname NOT NULL, [table_name] sysname NOT NULL, [index_name] sysname NOT NULL,
    [is_unique] bit NOT NULL, [key_columns] nvarchar(1000) NOT NULL,
    [include_columns] nvarchar(1000) NOT NULL, [filter_definition] nvarchar(1000) NULL,
    PRIMARY KEY ([schema_name], [table_name], [index_name])
);
INSERT INTO @ExpectedIndexes VALUES
    (N'core', N'Branch', N'IX_Branch_city_id', 0, N'[city_id] ASC', N'', NULL),
    (N'core', N'Employee', N'IX_Employee_branch_id', 0, N'[branch_id] ASC', N'', NULL),
    (N'core', N'CustomerContact', N'IX_CustomerContact_type_value', 0, N'[contact_type] ASC;[contact_value] ASC', N'', NULL),
    (N'core', N'CustomerAddress', N'IX_CustomerAddress_customer_id', 0, N'[customer_id] ASC', N'', NULL),
    (N'core', N'CustomerAddress', N'IX_CustomerAddress_city_id', 0, N'[city_id] ASC', N'', NULL),
    (N'vehicle', N'Vehicle', N'IX_Vehicle_model_id', 0, N'[model_id] ASC', N'', NULL),
    (N'vehicle', N'Vehicle', N'IX_Vehicle_variant_id_model_id', 0, N'[variant_id] ASC;[model_id] ASC', N'', N'[variant_id] IS NOT NULL'),
    (N'vehicle', N'Vehicle', N'UX_Vehicle_vin', 1, N'[vin] ASC', N'', N'[vin] IS NOT NULL'),
    (N'vehicle', N'Vehicle', N'IX_Vehicle_current_owner_customer_id', 0, N'[current_owner_customer_id] ASC', N'', NULL),
    (N'vehicle', N'VehicleOwnershipHistory', N'IX_VehicleOwnershipHistory_customer_id', 0, N'[customer_id] ASC', N'', NULL),
    (N'vehicle', N'VehicleSubmission', N'IX_VehicleSubmission_vehicle_id', 0, N'[vehicle_id] ASC', N'', NULL),
    (N'vehicle', N'VehicleSubmission', N'IX_VehicleSubmission_seller_customer_id_submitted_at', 0, N'[seller_customer_id] ASC;[submitted_at] ASC', N'', NULL),
    (N'vehicle', N'VehicleSubmission', N'IX_VehicleSubmission_branch_id', 0, N'[branch_id] ASC', N'', NULL),
    (N'vehicle', N'VehicleRegistration', N'IX_VehicleRegistration_vehicle_id', 0, N'[vehicle_id] ASC', N'', NULL),
    (N'vehicle', N'VehicleRegistration', N'IX_VehicleRegistration_registration_number', 0, N'[registration_number] ASC', N'', NULL),
    (N'inspection', N'Inspection', N'IX_Inspection_vehicle_id', 0, N'[vehicle_id] ASC', N'', NULL),
    (N'inspection', N'Inspection', N'IX_Inspection_submission_id', 0, N'[submission_id] ASC', N'', N'[submission_id] IS NOT NULL'),
    (N'inspection', N'Inspection', N'IX_Inspection_inspector_employee_id', 0, N'[inspector_employee_id] ASC', N'', N'[inspector_employee_id] IS NOT NULL'),
    (N'inspection', N'InspectionItem', N'IX_InspectionItem_report_id', 0, N'[report_id] ASC', N'', NULL),
    (N'inspection', N'Defect', N'IX_Defect_report_id', 0, N'[report_id] ASC', N'', NULL),
    (N'inspection', N'Defect', N'IX_Defect_inspection_item_id', 0, N'[inspection_item_id] ASC', N'', N'[inspection_item_id] IS NOT NULL'),
    (N'inspection', N'VehicleValuation', N'IX_VehicleValuation_vehicle_id_valued_at', 0, N'[vehicle_id] ASC;[valued_at] DESC', N'', NULL),
    (N'inspection', N'VehicleValuation', N'IX_VehicleValuation_report_id', 0, N'[report_id] ASC', N'', N'[report_id] IS NOT NULL'),
    (N'inspection', N'VehicleValuation', N'IX_VehicleValuation_assessor_employee_id', 0, N'[assessor_employee_id] ASC', N'', NULL),
    (N'acquisition', N'PurchaseOffer', N'IX_PurchaseOffer_submission_id', 0, N'[submission_id] ASC', N'', NULL),
    (N'acquisition', N'PurchaseOffer', N'IX_PurchaseOffer_valuation_id', 0, N'[valuation_id] ASC', N'', NULL),
    (N'acquisition', N'PurchaseOffer', N'IX_PurchaseOffer_seller_customer_id', 0, N'[seller_customer_id] ASC', N'', NULL),
    (N'acquisition', N'PurchaseAgreement', N'IX_PurchaseAgreement_offer_id', 0, N'[offer_id] ASC', N'', NULL),
    (N'acquisition', N'PurchaseAgreement', N'IX_PurchaseAgreement_seller_customer_id', 0, N'[seller_customer_id] ASC', N'', NULL),
    (N'acquisition', N'VehicleAcquisition', N'IX_VehicleAcquisition_vehicle_id', 0, N'[vehicle_id] ASC', N'', NULL),
    (N'acquisition', N'VehicleAcquisition', N'IX_VehicleAcquisition_seller_customer_id', 0, N'[seller_customer_id] ASC', N'', NULL),
    (N'inventory', N'Inventory', N'IX_Inventory_branch_id_status', 0, N'[branch_id] ASC;[status] ASC', N'', NULL),
    (N'inventory', N'InventoryMovement', N'IX_InventoryMovement_inventory_id_occurred_at', 0, N'[inventory_id] ASC;[occurred_at] DESC', N'', NULL),
    (N'inventory', N'InventoryMovement', N'IX_InventoryMovement_from_branch_id', 0, N'[from_branch_id] ASC', N'', N'[from_branch_id] IS NOT NULL'),
    (N'inventory', N'InventoryMovement', N'IX_InventoryMovement_to_branch_id', 0, N'[to_branch_id] ASC', N'', N'[to_branch_id] IS NOT NULL'),
    (N'inventory', N'InventoryMovement', N'IX_InventoryMovement_employee_id', 0, N'[employee_id] ASC', N'', N'[employee_id] IS NOT NULL'),
    (N'marketplace', N'VehicleListing', N'IX_VehicleListing_branch_id', 0, N'[branch_id] ASC', N'', NULL),
    (N'marketplace', N'VehicleListing', N'IX_VehicleListing_vehicle_id', 0, N'[vehicle_id] ASC', N'', NULL),
    (N'marketplace', N'VehicleListing', N'UX_VehicleListing_active_vehicle', 1, N'[vehicle_id] ASC', N'', N'[status] = ''ACTIVE'''),
    (N'marketplace', N'CustomerEnquiry', N'IX_CustomerEnquiry_listing_id_received_at', 0, N'[listing_id] ASC;[received_at] DESC', N'', NULL),
    (N'marketplace', N'CustomerEnquiry', N'IX_CustomerEnquiry_customer_id', 0, N'[customer_id] ASC', N'', NULL),
    (N'marketplace', N'CustomerEnquiry', N'IX_CustomerEnquiry_assigned_employee_id', 0, N'[assigned_employee_id] ASC', N'', N'[assigned_employee_id] IS NOT NULL'),
    (N'marketplace', N'VehicleReservation', N'IX_VehicleReservation_listing_id_created_at', 0, N'[listing_id] ASC;[created_at] DESC', N'', NULL),
    (N'marketplace', N'VehicleReservation', N'UX_VehicleReservation_active_listing', 1, N'[listing_id] ASC', N'', N'[status] = ''ACTIVE'''),
    (N'marketplace', N'VehicleReservation', N'IX_VehicleReservation_customer_id', 0, N'[customer_id] ASC', N'', NULL),
    (N'sales', N'SalesOrder', N'IX_SalesOrder_buyer_customer_id_created_at', 0, N'[buyer_customer_id] ASC;[created_at] DESC', N'', NULL),
    (N'sales', N'SalesOrderItem', N'IX_SalesOrderItem_vehicle_id', 0, N'[vehicle_id] ASC', N'', NULL),
    (N'sales', N'SalesOrderItem', N'UX_SalesOrderItem_reservation_id', 1, N'[reservation_id] ASC', N'', N'[reservation_id] IS NOT NULL'),
    (N'sales', N'SalesOrderItem', N'UX_SalesOrderItem_one_item_per_order', 1, N'[order_id] ASC', N'', NULL),
    (N'finance', N'Payment', N'IX_Payment_order_id_initiated_at', 0, N'[order_id] ASC;[initiated_at] DESC', N'', NULL),
    (N'finance', N'Payment', N'UX_Payment_provider_reference', 1, N'[provider_code] ASC;[provider_reference] ASC', N'', N'[provider_reference] IS NOT NULL'),
    (N'finance', N'Refund', N'IX_Refund_payment_id_requested_at', 0, N'[payment_id] ASC;[requested_at] DESC', N'', NULL),
    (N'finance', N'Refund', N'UX_Refund_provider_reference', 1, N'[provider_reference] ASC', N'', N'[provider_reference] IS NOT NULL'),
    (N'delivery', N'OwnershipTransfer', N'IX_OwnershipTransfer_order_item_id', 0, N'[order_item_id] ASC', N'', NULL),
    (N'delivery', N'OwnershipTransfer', N'IX_OwnershipTransfer_from_customer_id', 0, N'[from_customer_id] ASC', N'', NULL),
    (N'delivery', N'OwnershipTransfer', N'IX_OwnershipTransfer_to_customer_id', 0, N'[to_customer_id] ASC', N'', NULL),
    (N'delivery', N'VehicleDelivery', N'IX_VehicleDelivery_order_item_id', 0, N'[order_item_id] ASC', N'', NULL),
    (N'delivery', N'VehicleDelivery', N'IX_VehicleDelivery_recipient_customer_id', 0, N'[recipient_customer_id] ASC', N'', NULL),
    (N'delivery', N'VehicleDelivery', N'IX_VehicleDelivery_branch_id', 0, N'[branch_id] ASC', N'', N'[branch_id] IS NOT NULL'),
    (N'delivery', N'VehicleDelivery', N'IX_VehicleDelivery_delivery_address_id', 0, N'[delivery_address_id] ASC', N'', N'[delivery_address_id] IS NOT NULL')
;

;WITH ActualIndexDefinitions AS
(
    SELECT s.[name] AS schema_name, t.[name] AS table_name, i.[name] AS index_name,
           i.[is_unique], i.[is_primary_key], i.[is_unique_constraint], i.[is_disabled], i.[is_hypothetical], i.[type_desc], i.[has_filter], i.[filter_definition],
           COALESCE(k.[key_columns], N'') AS key_columns, COALESCE(x.[include_columns], N'') AS include_columns
    FROM sys.indexes AS i JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(c.[name]) + N' ' + CASE WHEN ic.[is_descending_key] = 1 THEN N'DESC' ELSE N'ASC' END), N';')
               WITHIN GROUP (ORDER BY ic.[key_ordinal]) AS key_columns
        FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.[object_id] = ic.[object_id] AND c.[column_id] = ic.[column_id]
        WHERE ic.[object_id] = i.[object_id] AND ic.[index_id] = i.[index_id] AND ic.[key_ordinal] > 0
    ) AS k
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(c.[name])), N';')
               WITHIN GROUP (ORDER BY ic.[index_column_id]) AS include_columns
        FROM sys.index_columns AS ic JOIN sys.columns AS c ON c.[object_id] = ic.[object_id] AND c.[column_id] = ic.[column_id]
        WHERE ic.[object_id] = i.[object_id] AND ic.[index_id] = i.[index_id] AND ic.[is_included_column] = 1
    ) AS x
    WHERE i.[index_id] > 0
)
SELECT e.[schema_name], e.[table_name], e.[index_name],
       CASE WHEN a.[index_name] IS NULL THEN N'MISSING'
            WHEN a.[is_unique] = e.[is_unique]
             AND a.[type_desc] = N'NONCLUSTERED'
             AND a.[is_primary_key] = 0 AND a.[is_unique_constraint] = 0
             AND a.[has_filter] = CASE WHEN e.[filter_definition] IS NULL THEN 0 ELSE 1 END
             AND a.[key_columns] = e.[key_columns]
             AND a.[include_columns] = e.[include_columns]
             AND LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(a.[filter_definition],N''),N' ',N''),NCHAR(9),N''),N'[',N''),N']',N''),N'(',N''),N')',N''))
               = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(e.[filter_definition],N''),N' ',N''),NCHAR(9),N''),N'[',N''),N']',N''),N'(',N''),N')',N''))
             AND a.[is_disabled] = 0 AND a.[is_hypothetical] = 0 THEN N'MATCH'
            ELSE N'DEFINITION_MISMATCH' END AS comparison_status,
       e.[is_unique] AS expected_unique, a.[is_unique] AS actual_unique,
       e.[key_columns] AS expected_key_columns, a.[key_columns] AS actual_key_columns,
       e.[include_columns] AS expected_include_columns, a.[include_columns] AS actual_include_columns,
       e.[filter_definition] AS expected_filter, a.[filter_definition] AS actual_filter,
       a.[has_filter], a.[is_disabled], a.[is_hypothetical], a.[is_primary_key], a.[is_unique_constraint], a.[type_desc]
FROM @ExpectedIndexes AS e LEFT JOIN ActualIndexDefinitions AS a
  ON a.[schema_name] = e.[schema_name] AND a.[table_name] = e.[table_name] AND a.[index_name] = e.[index_name]
ORDER BY e.[schema_name], e.[table_name], e.[index_name];

/* Any non-constraint index on a managed table not in the 60-index manifest is unexpected. */
;WITH ActualNames AS
(
    SELECT s.[name] AS schema_name, t.[name] AS table_name, i.[name] AS index_name,
           i.[is_primary_key], i.[is_unique_constraint], i.[is_disabled], i.[type_desc]
    FROM sys.indexes AS i JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
    JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
    JOIN @ExpectedSchemas AS es ON es.[schema_name] = s.[name]
    WHERE i.[index_id] > 0
)
SELECT a.* FROM ActualNames AS a
WHERE a.[is_primary_key] = 0 AND a.[is_unique_constraint] = 0
  AND NOT EXISTS (SELECT 1 FROM @ExpectedIndexes AS e WHERE e.[schema_name] = a.[schema_name] AND e.[table_name] = a.[table_name] AND e.[index_name] = a.[index_name])
ORDER BY a.[schema_name], a.[table_name], a.[index_name];

/* User-created statistics with a planned index name can explain CREATE INDEX
   collision errors even when the index itself is absent. */
SELECT s.[name] AS schema_name, t.[name] AS table_name, st.[name] AS colliding_statistics_name,
       st.[auto_created], st.[user_created], st.[no_recompute]
FROM sys.stats AS st JOIN sys.tables AS t ON t.[object_id] = st.[object_id]
JOIN sys.schemas AS s ON s.[schema_id] = t.[schema_id]
JOIN @ExpectedIndexes AS e ON e.[schema_name] = s.[name] AND e.[table_name] = t.[name] AND e.[index_name] = st.[name]
LEFT JOIN sys.indexes AS i ON i.[object_id] = st.[object_id] AND i.[name] = st.[name]
WHERE i.[index_id] IS NULL ORDER BY schema_name, table_name, colliding_statistics_name;

SELECT COUNT_BIG(*) AS actual_index_count_in_managed_tables, CONVERT(bigint,113) AS expected_total_index_count
FROM sys.indexes AS i JOIN sys.tables AS t ON t.[object_id] = i.[object_id]
JOIN @ExpectedSchemas AS s ON s.[schema_name] = SCHEMA_NAME(t.[schema_id]) WHERE i.[index_id] > 0;

/* Reference and synthetic seed checks. Counts above include all existing user data;
   these checks only report whether known fixture identifiers are present. */
DECLARE @ExpectedCities TABLE ([city_name] nvarchar(100), [state_code] varchar(2), PRIMARY KEY ([city_name],[state_code]));
INSERT INTO @ExpectedCities VALUES (N'Hyderabad','TG'),(N'Mumbai','MH'),(N'Bengaluru','KA'),(N'Pune','MH'),(N'Delhi','DL'),(N'Chennai','TN'),(N'Ahmedabad','GJ'),(N'Rajkot','GJ');
IF OBJECT_ID(N'ref.City', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[city_name], e.[state_code], CASE WHEN c.[city_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (N''Hyderabad'',''TG''),(N''Mumbai'',''MH''),(N''Bengaluru'',''KA''),(N''Pune'',''MH''),(N''Delhi'',''DL''),(N''Chennai'',''TN''),(N''Ahmedabad'',''GJ''),(N''Rajkot'',''GJ'')) AS e([city_name],[state_code]) LEFT JOIN [ref].[City] AS c ON c.[city_name]=e.[city_name] AND c.[state_code]=e.[state_code] AND c.[country_code]=''IN'' ORDER BY e.[city_name];';
ELSE SELECT N'ref.City' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'core.Branch', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[branch_code], CASE WHEN b.[branch_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (''HYD-CEN''),(''MUM-WST''),(''BLR-SOU''),(''PUN-CEN''),(''DEL-SOU''),(''CHE-CEN''),(''AMD-CEN''),(''RJK-CEN'')) AS e([branch_code]) LEFT JOIN [core].[Branch] AS b ON b.[branch_code]=e.[branch_code] ORDER BY e.[branch_code];';
ELSE SELECT N'core.Branch' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'core.Employee', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[employee_code], CASE WHEN a.[employee_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (''EMP-SYN-001''),(''EMP-SYN-002''),(''EMP-SYN-003''),(''EMP-SYN-004'')) AS e([employee_code]) LEFT JOIN [core].[Employee] AS a ON a.[employee_code]=e.[employee_code] ORDER BY e.[employee_code];';
ELSE SELECT N'core.Employee' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'core.Customer', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[display_name], CASE WHEN c.[customer_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (N''Synthetic Customer Alpha''),(N''Synthetic Customer Beta''),(N''Synthetic Customer Gamma'')) AS e([display_name]) LEFT JOIN [core].[Customer] AS c ON c.[display_name]=e.[display_name] ORDER BY e.[display_name];';
ELSE SELECT N'core.Customer' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'vehicle.VehicleBrand', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[brand_name], CASE WHEN b.[brand_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (N''Maruti Suzuki''),(N''Hyundai''),(N''Tata Motors''),(N''Mahindra''),(N''Honda''),(N''Toyota''),(N''Kia''),(N''Volkswagen'')) AS e([brand_name]) LEFT JOIN [vehicle].[VehicleBrand] AS b ON b.[brand_name]=e.[brand_name] ORDER BY e.[brand_name];';
ELSE SELECT N'vehicle.VehicleBrand' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'vehicle.VehicleModel', N'U') IS NOT NULL AND OBJECT_ID(N'vehicle.VehicleBrand', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[brand_name], e.[model_name], CASE WHEN m.[model_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (N''Hyundai'',N''Creta''),(N''Maruti Suzuki'',N''Swift''),(N''Tata Motors'',N''Nexon''),(N''Mahindra'',N''XUV700''),(N''Honda'',N''City''),(N''Toyota'',N''Innova Crysta''),(N''Kia'',N''Seltos'')) AS e([brand_name],[model_name]) LEFT JOIN [vehicle].[VehicleBrand] AS b ON b.[brand_name]=e.[brand_name] LEFT JOIN [vehicle].[VehicleModel] AS m ON m.[brand_id]=b.[brand_id] AND m.[model_name]=e.[model_name] ORDER BY e.[brand_name],e.[model_name];';
ELSE SELECT N'vehicle.VehicleModel' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'vehicle.Vehicle', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[vin], CASE WHEN v.[vehicle_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (''SYNVIN00000000001''),(''SYNVIN00000000002''),(''SYNVIN00000000003'')) AS e([vin]) LEFT JOIN [vehicle].[Vehicle] AS v ON v.[vin]=e.[vin] ORDER BY e.[vin];';
ELSE SELECT N'vehicle.Vehicle' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;
IF OBJECT_ID(N'vehicle.VehicleRegistration', N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT e.[registration_number], CASE WHEN r.[registration_id] IS NULL THEN N''MISSING'' ELSE N''PRESENT'' END AS fixture_status FROM (VALUES (''TS09AB1234''),(''MH02CD5678''),(''KA03EF9012'')) AS e([registration_number]) LEFT JOIN [vehicle].[VehicleRegistration] AS r ON r.[registration_number]=e.[registration_number] ORDER BY e.[registration_number];';
ELSE SELECT N'vehicle.VehicleRegistration' AS seed_table, N'SKIPPED_MISSING_TABLE' AS status;

IF OBJECT_ID(N'acquisition.PurchaseAgreement',N'U') IS NOT NULL AND OBJECT_ID(N'marketplace.CustomerEnquiry',N'U') IS NOT NULL
   AND OBJECT_ID(N'finance.Payment',N'U') IS NOT NULL AND OBJECT_ID(N'finance.Refund',N'U') IS NOT NULL
   AND OBJECT_ID(N'delivery.OwnershipTransfer',N'U') IS NOT NULL AND OBJECT_ID(N'delivery.VehicleDelivery',N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT N''PurchaseAgreement'' AS seed_object, COUNT_BIG(*) AS matching_rows FROM [acquisition].[PurchaseAgreement] WHERE [agreement_reference]=''SYN-AGR-0001'' UNION ALL SELECT N''CustomerEnquiry'',COUNT_BIG(*) FROM [marketplace].[CustomerEnquiry] WHERE [message_reference]=N''SYNTH-ENQUIRY-001'' UNION ALL SELECT N''Payment'',COUNT_BIG(*) FROM [finance].[Payment] WHERE [provider_code]=''SYNTHETIC_PROVIDER'' AND [provider_reference]=''SYN-PAY-0001'' UNION ALL SELECT N''Refund'',COUNT_BIG(*) FROM [finance].[Refund] WHERE [provider_reference]=''SYN-REF-0001'' UNION ALL SELECT N''OwnershipTransfer'',COUNT_BIG(*) FROM [delivery].[OwnershipTransfer] WHERE [authority_reference]=''SYN-TRANSFER-0001'' UNION ALL SELECT N''VehicleDelivery'',COUNT_BIG(*) FROM [delivery].[VehicleDelivery] WHERE [handover_reference]=''SYN-HANDOVER-0001'';';
ELSE SELECT N'Lifecycle marker records' AS seed_table, N'SKIPPED_ONE_OR_MORE_TABLES_MISSING' AS status;

/* Read-only integrity checks; CHECKDB can take time on a large database. */
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
DBCC CHECKDB (N'CARS24DataModelingSystem') WITH NO_INFOMSGS;
GO
