/* GENERATED FILE. Regenerate with generate_continuation_setup.ps1. */

/* Continues an existing database; it never creates, drops, or overwrites the database. */

USE [master];

GO

EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
SET NOCOUNT ON;

SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) AS server_name,
       CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS product_version,
       TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) AS product_major_version,
       CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS edition;

DECLARE @targetDatabaseId int = DB_ID(N'CARS24DataModelingSystem');
IF @targetDatabaseId IS NULL
    THROW 52000, 'Continuation blocked: CARS24DataModelingSystem does not exist. This script never creates the database.', 1;

SELECT [name] AS database_name, [state_desc], [is_read_only], [compatibility_level]
FROM sys.databases WHERE [database_id] = @targetDatabaseId;

IF COALESCE(TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion')), 0) < 17
    THROW 52001, 'Continuation blocked: SQL Server 2025 (major version 17) or newer is required.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE [database_id] = @targetDatabaseId AND [state_desc] = N'ONLINE' AND [is_read_only] = 0 AND [compatibility_level] >= 110)
    THROW 52002, 'Continuation blocked: target database must be online, writable, and compatibility level 110 or newer.', 1;
USE [CARS24DataModelingSystem];
SELECT HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'VIEW DEFINITION') AS can_view_definition,
       HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'CREATE TABLE') AS can_create_table,
       HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'CREATE SCHEMA') AS can_create_schema;
IF HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'VIEW DEFINITION') <> 1
    THROW 52004, 'Continuation blocked: VIEW DEFINITION permission on the target database is required so object-conflict checks can see the complete catalog.', 1;
IF HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'CREATE TABLE') <> 1
    THROW 52005, 'Continuation blocked: CREATE TABLE permission on the target database is required.', 1;
IF EXISTS
(
    SELECT 1 FROM (VALUES (N'ref'), (N'core'), (N'vehicle'), (N'inspection'), (N'acquisition'),
                          (N'inventory'), (N'marketplace'), (N'sales'), (N'finance'), (N'delivery')) AS expected([schema_name])
    WHERE SCHEMA_ID(expected.[schema_name]) IS NULL
)
AND HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'CREATE SCHEMA') <> 1
    THROW 52006, 'Continuation blocked: CREATE SCHEMA permission is required because one or more managed schemas are missing.', 1;

DECLARE @managedSchemas TABLE ([schema_name] sysname PRIMARY KEY);
INSERT INTO @managedSchemas ([schema_name]) VALUES
    (N'ref'), (N'core'), (N'vehicle'), (N'inspection'), (N'acquisition'),
    (N'inventory'), (N'marketplace'), (N'sales'), (N'finance'), (N'delivery');

SELECT m.[schema_name], CASE WHEN s.[schema_id] IS NULL THEN N'WILL_CREATE' ELSE N'ALREADY_PRESENT' END AS schema_status
FROM @managedSchemas AS m LEFT JOIN sys.schemas AS s ON s.[name] = m.[schema_name]
ORDER BY m.[schema_name];
SELECT m.[schema_name], HAS_PERMS_BY_NAME(m.[schema_name], N'SCHEMA', N'ALTER') AS can_create_objects_in_schema
FROM @managedSchemas AS m JOIN sys.schemas AS s ON s.[name] = m.[schema_name]
ORDER BY m.[schema_name];
IF EXISTS
(
    SELECT 1 FROM @managedSchemas AS m JOIN sys.schemas AS s ON s.[name] = m.[schema_name]
    WHERE COALESCE(HAS_PERMS_BY_NAME(m.[schema_name], N'SCHEMA', N'ALTER'), 0) <> 1
)
    THROW 52007, 'Continuation blocked: ALTER permission on each existing managed schema is required.', 1;

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

DECLARE @objectConflicts TABLE
(
    [schema_name] sysname NOT NULL,
    [object_name] sysname NOT NULL,
    [object_type] nvarchar(60) NOT NULL,
    [reason] nvarchar(200) NOT NULL
);

DECLARE @expectedExistingTableCount int =
(
    SELECT COUNT(*)
    FROM @expectedTables AS e
    JOIN sys.schemas AS s ON s.[name] = e.[schema_name]
    JOIN sys.tables AS t ON t.[schema_id] = s.[schema_id] AND t.[name] = e.[table_name]
);

/* Any object using an expected table name or any other object in a managed
   schema is reviewed manually before setup. */
INSERT INTO @objectConflicts ([schema_name], [object_name], [object_type], [reason])
SELECT s.[name], o.[name], o.[type_desc],
       CASE WHEN e.[table_name] IS NOT NULL
            THEN N'Expected table name already exists; review current definition and state.'
            ELSE N'Unexpected object in a managed schema; review before continuing.' END
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.[schema_id] = o.[schema_id]
LEFT JOIN @expectedTables AS e ON e.[schema_name] = s.[name] AND e.[table_name] = o.[name]
WHERE e.[table_name] IS NOT NULL
   OR EXISTS (SELECT 1 FROM @managedSchemas AS m WHERE m.[schema_name] = s.[name]);

SELECT [schema_name], [object_name], [object_type], [reason]
FROM @objectConflicts ORDER BY [schema_name], [object_name], [object_type];
SELECT CASE
           WHEN @expectedExistingTableCount = 0 AND NOT EXISTS (SELECT 1 FROM @objectConflicts) THEN N'READY'
           WHEN @expectedExistingTableCount = 34 THEN N'COMPLETE_MODEL_PRESENT_REVIEW_REQUIRED'
           WHEN @expectedExistingTableCount > 0 THEN N'PARTIAL_IMPLEMENTATION_CONFLICT'
           ELSE N'UNEXPECTED_OBJECT_CONFLICT'
       END AS preflight_status,
       @expectedExistingTableCount AS existing_expected_table_count,
       34 AS expected_table_count;

IF EXISTS (SELECT 1 FROM @objectConflicts)
    THROW 52003, 'Continuation blocked: existing or unexpected objects conflict with the expected model. No schema, table, index, or seed batch will run. Inspect and resolve manually.', 1;

EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 1;
SELECT N'READY_TO_CONTINUE' AS continuation_status,
       N'Database is online/writable and no conflicting tables/objects were found in managed schemas.' AS detail;

GO

/* BEGIN SOURCE: 02_create_schemas.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF SCHEMA_ID(N'ref') IS NULL EXEC(N'CREATE SCHEMA [ref]');
IF SCHEMA_ID(N'core') IS NULL EXEC(N'CREATE SCHEMA [core]');
IF SCHEMA_ID(N'vehicle') IS NULL EXEC(N'CREATE SCHEMA [vehicle]');
IF SCHEMA_ID(N'inspection') IS NULL EXEC(N'CREATE SCHEMA [inspection]');
IF SCHEMA_ID(N'acquisition') IS NULL EXEC(N'CREATE SCHEMA [acquisition]');
IF SCHEMA_ID(N'inventory') IS NULL EXEC(N'CREATE SCHEMA [inventory]');
IF SCHEMA_ID(N'marketplace') IS NULL EXEC(N'CREATE SCHEMA [marketplace]');
IF SCHEMA_ID(N'sales') IS NULL EXEC(N'CREATE SCHEMA [sales]');
IF SCHEMA_ID(N'finance') IS NULL EXEC(N'CREATE SCHEMA [finance]');
IF SCHEMA_ID(N'delivery') IS NULL EXEC(N'CREATE SCHEMA [delivery]');
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 02_create_schemas.sql */

/* BEGIN SOURCE: 03_reference_tables.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
/* City is the only finalized Day 1 reference relation in this scope.
   Fuel, transmission, and status domains remain checked code columns. */
IF OBJECT_ID(N'ref.City', N'U') IS NULL
BEGIN
    CREATE TABLE [ref].[City]
    (
        [city_id] INT IDENTITY(1,1) NOT NULL,
        [city_name] NVARCHAR(100) NOT NULL,
        [state_code] VARCHAR(2) NOT NULL,
        [country_code] VARCHAR(2) NOT NULL
            CONSTRAINT [DF_City_country_code] DEFAULT ('IN'),
        CONSTRAINT [PK_City] PRIMARY KEY ([city_id]),
        CONSTRAINT [UQ_City_city_name_state_code_country_code]
            UNIQUE ([city_name], [state_code], [country_code]),
        CONSTRAINT [CK_City_state_code_upper] CHECK ([state_code] = UPPER([state_code])),
        CONSTRAINT [CK_City_country_code_upper] CHECK ([country_code] = UPPER([country_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 03_reference_tables.sql */

/* BEGIN SOURCE: 04_core_tables.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'core.Branch', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Branch]
    (
        [branch_id] INT IDENTITY(1,1) NOT NULL,
        [city_id] INT NOT NULL,
        [branch_code] VARCHAR(30) NOT NULL,
        [branch_name] NVARCHAR(150) NOT NULL,
        [address_text] NVARCHAR(500) NULL,
        [status] VARCHAR(20) NOT NULL,
        CONSTRAINT [PK_Branch] PRIMARY KEY ([branch_id]),
        CONSTRAINT [UQ_Branch_branch_code] UNIQUE ([branch_code]),
        CONSTRAINT [FK_Branch_City_city_id] FOREIGN KEY ([city_id]) REFERENCES [ref].[City] ([city_id]),
        CONSTRAINT [CK_Branch_status] CHECK ([status] IN ('ACTIVE', 'INACTIVE', 'CLOSED')),
        CONSTRAINT [CK_Branch_code_upper] CHECK ([branch_code] = UPPER([branch_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'core.Employee', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Employee]
    (
        [employee_id] INT IDENTITY(1,1) NOT NULL,
        [branch_id] INT NOT NULL,
        [employee_code] VARCHAR(30) NOT NULL,
        [display_name] NVARCHAR(150) NOT NULL,
        [active_from] DATE NOT NULL,
        [active_to] DATE NULL,
        CONSTRAINT [PK_Employee] PRIMARY KEY ([employee_id]),
        CONSTRAINT [UQ_Employee_employee_code] UNIQUE ([employee_code]),
        CONSTRAINT [FK_Employee_Branch_branch_id] FOREIGN KEY ([branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [CK_Employee_active_dates] CHECK ([active_to] IS NULL OR [active_to] >= [active_from]),
        CONSTRAINT [CK_Employee_code_upper] CHECK ([employee_code] = UPPER([employee_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'core.EmployeeRole', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[EmployeeRole]
    (
        [employee_role_id] INT IDENTITY(1,1) NOT NULL,
        [employee_id] INT NOT NULL,
        [role_code] VARCHAR(30) NOT NULL,
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        CONSTRAINT [PK_EmployeeRole] PRIMARY KEY ([employee_role_id]),
        CONSTRAINT [FK_EmployeeRole_Employee_employee_id] FOREIGN KEY ([employee_id]) REFERENCES [core].[Employee] ([employee_id]),
        CONSTRAINT [UQ_EmployeeRole_employee_id_role_code_valid_from] UNIQUE ([employee_id], [role_code], [valid_from]),
        CONSTRAINT [CK_EmployeeRole_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from]),
        CONSTRAINT [CK_EmployeeRole_role_code_upper] CHECK ([role_code] = UPPER([role_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'core.Customer', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Customer]
    (
        [customer_id] INT IDENTITY(1,1) NOT NULL,
        [display_name] NVARCHAR(150) NOT NULL,
        [legal_name] NVARCHAR(150) NULL,
        [status] VARCHAR(20) NOT NULL,
        [created_at] DATETIME2(0) NOT NULL
            CONSTRAINT [DF_Customer_created_at] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Customer] PRIMARY KEY ([customer_id]),
        CONSTRAINT [CK_Customer_status] CHECK ([status] IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'core.CustomerContact', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[CustomerContact]
    (
        [contact_id] INT IDENTITY(1,1) NOT NULL,
        [customer_id] INT NOT NULL,
        [contact_type] VARCHAR(10) NOT NULL,
        [contact_value] NVARCHAR(254) NOT NULL,
        [is_verified] BIT NOT NULL
            CONSTRAINT [DF_CustomerContact_is_verified] DEFAULT (0),
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        CONSTRAINT [PK_CustomerContact] PRIMARY KEY ([contact_id]),
        CONSTRAINT [FK_CustomerContact_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [UQ_CustomerContact_customer_type_value_valid_from]
            UNIQUE ([customer_id], [contact_type], [contact_value], [valid_from]),
        CONSTRAINT [CK_CustomerContact_type] CHECK ([contact_type] IN ('EMAIL', 'PHONE', 'OTHER')),
        CONSTRAINT [CK_CustomerContact_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'core.CustomerAddress', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[CustomerAddress]
    (
        [address_id] INT IDENTITY(1,1) NOT NULL,
        [customer_id] INT NOT NULL,
        [city_id] INT NOT NULL,
        [address_type] VARCHAR(20) NOT NULL,
        [address_line1] NVARCHAR(200) NOT NULL,
        [address_line2] NVARCHAR(200) NULL,
        [postal_code] VARCHAR(6) NOT NULL,
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        CONSTRAINT [PK_CustomerAddress] PRIMARY KEY ([address_id]),
        CONSTRAINT [FK_CustomerAddress_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [FK_CustomerAddress_City_city_id] FOREIGN KEY ([city_id]) REFERENCES [ref].[City] ([city_id]),
        CONSTRAINT [CK_CustomerAddress_type] CHECK ([address_type] IN ('HOME', 'MAILING', 'DELIVERY', 'OTHER')),
        CONSTRAINT [CK_CustomerAddress_pin_code] CHECK ([postal_code] NOT LIKE '%[^0-9]%' AND LEN([postal_code]) = 6),
        CONSTRAINT [CK_CustomerAddress_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 04_core_tables.sql */

/* BEGIN SOURCE: 05_vehicle_catalog.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.VehicleBrand', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[VehicleBrand]
    (
        [brand_id] INT IDENTITY(1,1) NOT NULL,
        [brand_name] NVARCHAR(100) NOT NULL,
        CONSTRAINT [PK_VehicleBrand] PRIMARY KEY ([brand_id]),
        CONSTRAINT [UQ_VehicleBrand_brand_name] UNIQUE ([brand_name])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.VehicleModel', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[VehicleModel]
    (
        [model_id] INT IDENTITY(1,1) NOT NULL,
        [brand_id] INT NOT NULL,
        [model_name] NVARCHAR(100) NOT NULL,
        CONSTRAINT [PK_VehicleModel] PRIMARY KEY ([model_id]),
        CONSTRAINT [FK_VehicleModel_VehicleBrand_brand_id] FOREIGN KEY ([brand_id]) REFERENCES [vehicle].[VehicleBrand] ([brand_id]),
        CONSTRAINT [UQ_VehicleModel_brand_id_model_name] UNIQUE ([brand_id], [model_name]),
        CONSTRAINT [UQ_VehicleModel_model_id_brand_id] UNIQUE ([model_id], [brand_id])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.VehicleVariant', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[VehicleVariant]
    (
        [variant_id] INT IDENTITY(1,1) NOT NULL,
        [model_id] INT NOT NULL,
        [variant_name] NVARCHAR(120) NOT NULL,
        CONSTRAINT [PK_VehicleVariant] PRIMARY KEY ([variant_id]),
        CONSTRAINT [FK_VehicleVariant_VehicleModel_model_id] FOREIGN KEY ([model_id]) REFERENCES [vehicle].[VehicleModel] ([model_id]),
        CONSTRAINT [UQ_VehicleVariant_model_id_variant_name] UNIQUE ([model_id], [variant_name]),
        CONSTRAINT [UQ_VehicleVariant_variant_id_model_id] UNIQUE ([variant_id], [model_id])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 05_vehicle_catalog.sql */

/* BEGIN SOURCE: 06_vehicle_identity.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.Vehicle', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[Vehicle]
    (
        [vehicle_id] INT IDENTITY(1,1) NOT NULL,
        [model_id] INT NOT NULL,
        [variant_id] INT NULL,
        [manufacture_year] SMALLINT NOT NULL,
        [vin] VARCHAR(30) NULL,
        [engine_number] VARCHAR(40) NULL,
        [fuel_type_code] VARCHAR(15) NOT NULL,
        [transmission_type_code] VARCHAR(15) NOT NULL,
        [current_owner_customer_id] INT NOT NULL,
        [lifecycle_status] VARCHAR(20) NOT NULL,
        [created_at] DATETIME2(0) NOT NULL
            CONSTRAINT [DF_Vehicle_created_at] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Vehicle] PRIMARY KEY ([vehicle_id]),
        CONSTRAINT [FK_Vehicle_VehicleModel_model_id] FOREIGN KEY ([model_id]) REFERENCES [vehicle].[VehicleModel] ([model_id]),
        CONSTRAINT [FK_Vehicle_VehicleVariant_variant_id_model_id] FOREIGN KEY ([variant_id], [model_id]) REFERENCES [vehicle].[VehicleVariant] ([variant_id], [model_id]),
        CONSTRAINT [FK_Vehicle_Customer_current_owner_customer_id] FOREIGN KEY ([current_owner_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [CK_Vehicle_manufacture_year] CHECK ([manufacture_year] BETWEEN 1886 AND 2100),
        CONSTRAINT [CK_Vehicle_fuel_type_code] CHECK ([fuel_type_code] IN ('PETROL', 'DIESEL', 'CNG', 'ELECTRIC', 'HYBRID')),
        CONSTRAINT [CK_Vehicle_transmission_type_code] CHECK ([transmission_type_code] IN ('MANUAL', 'AUTOMATIC', 'AMT', 'CVT', 'DCT')),
        CONSTRAINT [CK_Vehicle_lifecycle_status] CHECK ([lifecycle_status] IN ('SUBMITTED', 'UNDER_REVIEW', 'ACQUIRED', 'IN_STOCK', 'LISTED', 'RESERVED', 'SOLD', 'WITHDRAWN', 'REJECTED')),
        CONSTRAINT [CK_Vehicle_vin_upper] CHECK ([vin] IS NULL OR [vin] = UPPER([vin])),
        CONSTRAINT [CK_Vehicle_engine_number_upper] CHECK ([engine_number] IS NULL OR [engine_number] = UPPER([engine_number]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.VehicleRegistration', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[VehicleRegistration]
    (
        [registration_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [registration_number] VARCHAR(15) NOT NULL,
        [issuing_state_code] VARCHAR(2) NOT NULL,
        [valid_from] DATE NOT NULL,
        [valid_to] DATE NULL,
        CONSTRAINT [PK_VehicleRegistration] PRIMARY KEY ([registration_id]),
        CONSTRAINT [FK_VehicleRegistration_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [UQ_VehicleRegistration_number_valid_from] UNIQUE ([registration_number], [valid_from]),
        CONSTRAINT [CK_VehicleRegistration_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from]),
        CONSTRAINT [CK_VehicleRegistration_state_code_upper] CHECK ([issuing_state_code] = UPPER([issuing_state_code])),
        CONSTRAINT [CK_VehicleRegistration_number_upper] CHECK ([registration_number] = UPPER([registration_number]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.VehicleOwnershipHistory', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[VehicleOwnershipHistory]
    (
        [ownership_history_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [customer_id] INT NOT NULL,
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        [basis_code] VARCHAR(20) NOT NULL,
        [evidence_reference] NVARCHAR(200) NULL,
        CONSTRAINT [PK_VehicleOwnershipHistory] PRIMARY KEY ([ownership_history_id]),
        CONSTRAINT [FK_VehicleOwnershipHistory_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_VehicleOwnershipHistory_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [UQ_VehicleOwnershipHistory_vehicle_id_valid_from] UNIQUE ([vehicle_id], [valid_from]),
        CONSTRAINT [CK_VehicleOwnershipHistory_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from]),
        CONSTRAINT [CK_VehicleOwnershipHistory_basis_code] CHECK ([basis_code] IN ('REGISTERED_OWNER', 'ACQUISITION', 'SALE', 'CORRECTION'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'vehicle.VehicleSubmission', N'U') IS NULL
BEGIN
    CREATE TABLE [vehicle].[VehicleSubmission]
    (
        [submission_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [seller_customer_id] INT NOT NULL,
        [branch_id] INT NOT NULL,
        [submitted_at] DATETIME2(0) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [closed_at] DATETIME2(0) NULL,
        [outcome_reason] NVARCHAR(300) NULL,
        CONSTRAINT [PK_VehicleSubmission] PRIMARY KEY ([submission_id]),
        CONSTRAINT [FK_VehicleSubmission_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_VehicleSubmission_Customer_seller_customer_id] FOREIGN KEY ([seller_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [FK_VehicleSubmission_Branch_branch_id] FOREIGN KEY ([branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [CK_VehicleSubmission_status] CHECK ([status] IN ('SUBMITTED', 'UNDER_REVIEW', 'ACCEPTED', 'REJECTED', 'WITHDRAWN', 'CLOSED')),
        CONSTRAINT [CK_VehicleSubmission_closed_at] CHECK ([closed_at] IS NULL OR [closed_at] >= [submitted_at])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 06_vehicle_identity.sql */

/* BEGIN SOURCE: 07_lifecycle_tables.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
/* Remaining finalized Day 1 relations. Parent relations are created in 01â€“06. */
IF SCHEMA_ID(N'inspection') IS NULL EXEC(N'CREATE SCHEMA [inspection]');
IF SCHEMA_ID(N'acquisition') IS NULL EXEC(N'CREATE SCHEMA [acquisition]');
IF SCHEMA_ID(N'inventory') IS NULL EXEC(N'CREATE SCHEMA [inventory]');
IF SCHEMA_ID(N'marketplace') IS NULL EXEC(N'CREATE SCHEMA [marketplace]');
IF SCHEMA_ID(N'sales') IS NULL EXEC(N'CREATE SCHEMA [sales]');
IF SCHEMA_ID(N'finance') IS NULL EXEC(N'CREATE SCHEMA [finance]');
IF SCHEMA_ID(N'delivery') IS NULL EXEC(N'CREATE SCHEMA [delivery]');
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inspection.Inspection', N'U') IS NULL
BEGIN
    CREATE TABLE [inspection].[Inspection]
    (
        [inspection_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [submission_id] INT NULL,
        [inspector_employee_id] INT NULL,
        [scheduled_at] DATETIME2(0) NOT NULL,
        [completed_at] DATETIME2(0) NULL,
        [status] VARCHAR(20) NOT NULL,
        CONSTRAINT [PK_Inspection] PRIMARY KEY ([inspection_id]),
        CONSTRAINT [FK_Inspection_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_Inspection_VehicleSubmission_submission_id] FOREIGN KEY ([submission_id]) REFERENCES [vehicle].[VehicleSubmission] ([submission_id]),
        CONSTRAINT [FK_Inspection_Employee_inspector_employee_id] FOREIGN KEY ([inspector_employee_id]) REFERENCES [core].[Employee] ([employee_id]),
        CONSTRAINT [CK_Inspection_status] CHECK ([status] IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inspection.InspectionReport', N'U') IS NULL
BEGIN
    CREATE TABLE [inspection].[InspectionReport]
    (
        [report_id] INT IDENTITY(1,1) NOT NULL,
        [inspection_id] INT NOT NULL,
        [outcome_code] VARCHAR(20) NOT NULL,
        [summary] NVARCHAR(1000) NULL,
        [finalized_at] DATETIME2(0) NOT NULL,
        CONSTRAINT [PK_InspectionReport] PRIMARY KEY ([report_id]),
        CONSTRAINT [FK_InspectionReport_Inspection_inspection_id] FOREIGN KEY ([inspection_id]) REFERENCES [inspection].[Inspection] ([inspection_id]),
        CONSTRAINT [UQ_InspectionReport_inspection_id] UNIQUE ([inspection_id]),
        CONSTRAINT [CK_InspectionReport_outcome] CHECK ([outcome_code] IN ('PASS', 'FAIL', 'CONDITIONAL'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inspection.InspectionItem', N'U') IS NULL
BEGIN
    CREATE TABLE [inspection].[InspectionItem]
    (
        [inspection_item_id] INT IDENTITY(1,1) NOT NULL,
        [report_id] INT NOT NULL,
        [item_code] VARCHAR(40) NOT NULL,
        [outcome_code] VARCHAR(20) NOT NULL,
        [note] NVARCHAR(500) NULL,
        CONSTRAINT [PK_InspectionItem] PRIMARY KEY ([inspection_item_id]),
        CONSTRAINT [FK_InspectionItem_InspectionReport_report_id] FOREIGN KEY ([report_id]) REFERENCES [inspection].[InspectionReport] ([report_id]),
        CONSTRAINT [UQ_InspectionItem_report_id_item_code] UNIQUE ([report_id], [item_code]),
        CONSTRAINT [CK_InspectionItem_outcome] CHECK ([outcome_code] IN ('PASS', 'FAIL', 'NOT_APPLICABLE', 'NOT_CHECKED')),
        CONSTRAINT [CK_InspectionItem_item_code_upper] CHECK ([item_code] = UPPER([item_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inspection.Defect', N'U') IS NULL
BEGIN
    CREATE TABLE [inspection].[Defect]
    (
        [defect_id] INT IDENTITY(1,1) NOT NULL,
        [report_id] INT NOT NULL,
        [inspection_item_id] INT NULL,
        [category_code] VARCHAR(30) NOT NULL,
        [severity_code] VARCHAR(20) NOT NULL,
        [description] NVARCHAR(1000) NOT NULL,
        [repair_estimate] DECIMAL(19,4) NULL,
        [currency_code] CHAR(3) NULL,
        CONSTRAINT [PK_Defect] PRIMARY KEY ([defect_id]),
        CONSTRAINT [FK_Defect_InspectionReport_report_id] FOREIGN KEY ([report_id]) REFERENCES [inspection].[InspectionReport] ([report_id]),
        CONSTRAINT [FK_Defect_InspectionItem_inspection_item_id] FOREIGN KEY ([inspection_item_id]) REFERENCES [inspection].[InspectionItem] ([inspection_item_id]),
        CONSTRAINT [CK_Defect_category] CHECK ([category_code] IN ('MECHANICAL', 'ELECTRICAL', 'COSMETIC', 'STRUCTURAL', 'SAFETY', 'OTHER')),
        CONSTRAINT [CK_Defect_severity] CHECK ([severity_code] IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
        CONSTRAINT [CK_Defect_repair_estimate] CHECK ([repair_estimate] IS NULL OR [repair_estimate] >= 0),
        CONSTRAINT [CK_Defect_currency_pair] CHECK (([repair_estimate] IS NULL AND [currency_code] IS NULL) OR ([repair_estimate] IS NOT NULL AND [currency_code] IS NOT NULL)),
        CONSTRAINT [CK_Defect_currency_upper] CHECK ([currency_code] IS NULL OR [currency_code] = UPPER([currency_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inspection.VehicleValuation', N'U') IS NULL
BEGIN
    CREATE TABLE [inspection].[VehicleValuation]
    (
        [valuation_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [report_id] INT NULL,
        [assessor_employee_id] INT NOT NULL,
        [valued_at] DATETIME2(0) NOT NULL,
        [amount] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL
            CONSTRAINT [DF_VehicleValuation_currency_code] DEFAULT ('INR'),
        [basis] NVARCHAR(1000) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        CONSTRAINT [PK_VehicleValuation] PRIMARY KEY ([valuation_id]),
        CONSTRAINT [FK_VehicleValuation_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_VehicleValuation_InspectionReport_report_id] FOREIGN KEY ([report_id]) REFERENCES [inspection].[InspectionReport] ([report_id]),
        CONSTRAINT [FK_VehicleValuation_Employee_assessor_employee_id] FOREIGN KEY ([assessor_employee_id]) REFERENCES [core].[Employee] ([employee_id]),
        CONSTRAINT [CK_VehicleValuation_amount] CHECK ([amount] >= 0),
        CONSTRAINT [CK_VehicleValuation_currency_upper] CHECK ([currency_code] = UPPER([currency_code])),
        CONSTRAINT [CK_VehicleValuation_status] CHECK ([status] IN ('DRAFT', 'APPROVED', 'REJECTED', 'SUPERSEDED'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'acquisition.PurchaseOffer', N'U') IS NULL
BEGIN
    CREATE TABLE [acquisition].[PurchaseOffer]
    (
        [offer_id] INT IDENTITY(1,1) NOT NULL,
        [submission_id] INT NOT NULL,
        [valuation_id] INT NOT NULL,
        [seller_customer_id] INT NOT NULL,
        [offered_at] DATETIME2(0) NOT NULL,
        [expires_at] DATETIME2(0) NOT NULL,
        [amount] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL
            CONSTRAINT [DF_PurchaseOffer_currency_code] DEFAULT ('INR'),
        [status] VARCHAR(20) NOT NULL,
        [decision_at] DATETIME2(0) NULL,
        CONSTRAINT [PK_PurchaseOffer] PRIMARY KEY ([offer_id]),
        CONSTRAINT [FK_PurchaseOffer_VehicleSubmission_submission_id] FOREIGN KEY ([submission_id]) REFERENCES [vehicle].[VehicleSubmission] ([submission_id]),
        CONSTRAINT [FK_PurchaseOffer_VehicleValuation_valuation_id] FOREIGN KEY ([valuation_id]) REFERENCES [inspection].[VehicleValuation] ([valuation_id]),
        CONSTRAINT [FK_PurchaseOffer_Customer_seller_customer_id] FOREIGN KEY ([seller_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [CK_PurchaseOffer_dates] CHECK ([expires_at] > [offered_at] AND ([decision_at] IS NULL OR [decision_at] >= [offered_at])),
        CONSTRAINT [CK_PurchaseOffer_amount] CHECK ([amount] >= 0),
        CONSTRAINT [CK_PurchaseOffer_currency_upper] CHECK ([currency_code] = UPPER([currency_code])),
        CONSTRAINT [CK_PurchaseOffer_status] CHECK ([status] IN ('DRAFT', 'ISSUED', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'WITHDRAWN'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'acquisition.PurchaseAgreement', N'U') IS NULL
BEGIN
    CREATE TABLE [acquisition].[PurchaseAgreement]
    (
        [agreement_id] INT IDENTITY(1,1) NOT NULL,
        [offer_id] INT NOT NULL,
        [seller_customer_id] INT NOT NULL,
        [agreement_reference] VARCHAR(40) NOT NULL,
        [signed_at] DATETIME2(0) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        CONSTRAINT [PK_PurchaseAgreement] PRIMARY KEY ([agreement_id]),
        CONSTRAINT [FK_PurchaseAgreement_PurchaseOffer_offer_id] FOREIGN KEY ([offer_id]) REFERENCES [acquisition].[PurchaseOffer] ([offer_id]),
        CONSTRAINT [FK_PurchaseAgreement_Customer_seller_customer_id] FOREIGN KEY ([seller_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [UQ_PurchaseAgreement_agreement_reference] UNIQUE ([agreement_reference]),
        CONSTRAINT [CK_PurchaseAgreement_status] CHECK ([status] IN ('SIGNED', 'VOID', 'CANCELLED')),
        CONSTRAINT [CK_PurchaseAgreement_reference_upper] CHECK ([agreement_reference] = UPPER([agreement_reference]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'acquisition.VehicleAcquisition', N'U') IS NULL
BEGIN
    CREATE TABLE [acquisition].[VehicleAcquisition]
    (
        [acquisition_id] INT IDENTITY(1,1) NOT NULL,
        [agreement_id] INT NOT NULL,
        [vehicle_id] INT NOT NULL,
        [seller_customer_id] INT NOT NULL,
        [acquired_at] DATETIME2(0) NOT NULL,
        [amount] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL,
        CONSTRAINT [PK_VehicleAcquisition] PRIMARY KEY ([acquisition_id]),
        CONSTRAINT [FK_VehicleAcquisition_PurchaseAgreement_agreement_id] FOREIGN KEY ([agreement_id]) REFERENCES [acquisition].[PurchaseAgreement] ([agreement_id]),
        CONSTRAINT [FK_VehicleAcquisition_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_VehicleAcquisition_Customer_seller_customer_id] FOREIGN KEY ([seller_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [UQ_VehicleAcquisition_agreement_id] UNIQUE ([agreement_id]),
        CONSTRAINT [CK_VehicleAcquisition_amount] CHECK ([amount] >= 0),
        CONSTRAINT [CK_VehicleAcquisition_currency_upper] CHECK ([currency_code] = UPPER([currency_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inventory.Inventory', N'U') IS NULL
BEGIN
    CREATE TABLE [inventory].[Inventory]
    (
        [inventory_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [branch_id] INT NOT NULL,
        [location_code] VARCHAR(30) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [since_at] DATETIME2(0) NOT NULL,
        CONSTRAINT [PK_Inventory] PRIMARY KEY ([inventory_id]),
        CONSTRAINT [FK_Inventory_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_Inventory_Branch_branch_id] FOREIGN KEY ([branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [UQ_Inventory_vehicle_id] UNIQUE ([vehicle_id]),
        CONSTRAINT [CK_Inventory_status] CHECK ([status] IN ('AVAILABLE', 'HELD', 'IN_TRANSIT', 'PREPARATION', 'SOLD', 'NOT_AVAILABLE'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'inventory.InventoryMovement', N'U') IS NULL
BEGIN
    CREATE TABLE [inventory].[InventoryMovement]
    (
        [movement_id] INT IDENTITY(1,1) NOT NULL,
        [inventory_id] INT NOT NULL,
        [from_branch_id] INT NULL,
        [from_location_code] VARCHAR(30) NULL,
        [to_branch_id] INT NULL,
        [to_location_code] VARCHAR(30) NULL,
        [movement_type] VARCHAR(20) NOT NULL,
        [employee_id] INT NULL,
        [occurred_at] DATETIME2(0) NOT NULL,
        [reason] NVARCHAR(500) NOT NULL,
        CONSTRAINT [PK_InventoryMovement] PRIMARY KEY ([movement_id]),
        CONSTRAINT [FK_InventoryMovement_Inventory_inventory_id] FOREIGN KEY ([inventory_id]) REFERENCES [inventory].[Inventory] ([inventory_id]),
        CONSTRAINT [FK_InventoryMovement_Branch_from_branch_id] FOREIGN KEY ([from_branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [FK_InventoryMovement_Branch_to_branch_id] FOREIGN KEY ([to_branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [FK_InventoryMovement_Employee_employee_id] FOREIGN KEY ([employee_id]) REFERENCES [core].[Employee] ([employee_id]),
        CONSTRAINT [CK_InventoryMovement_type] CHECK ([movement_type] IN ('RECEIPT', 'TRANSFER', 'DISPATCH', 'ADJUSTMENT')),
        CONSTRAINT [CK_InventoryMovement_from_pair] CHECK (([from_branch_id] IS NULL AND [from_location_code] IS NULL) OR ([from_branch_id] IS NOT NULL AND [from_location_code] IS NOT NULL)),
        CONSTRAINT [CK_InventoryMovement_to_pair] CHECK (([to_branch_id] IS NULL AND [to_location_code] IS NULL) OR ([to_branch_id] IS NOT NULL AND [to_location_code] IS NOT NULL)),
        CONSTRAINT [CK_InventoryMovement_has_endpoint] CHECK ([from_branch_id] IS NOT NULL OR [to_branch_id] IS NOT NULL)
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'marketplace.VehicleListing', N'U') IS NULL
BEGIN
    CREATE TABLE [marketplace].[VehicleListing]
    (
        [listing_id] INT IDENTITY(1,1) NOT NULL,
        [vehicle_id] INT NOT NULL,
        [branch_id] INT NOT NULL,
        [listed_at] DATETIME2(0) NOT NULL,
        [closed_at] DATETIME2(0) NULL,
        [status] VARCHAR(20) NOT NULL,
        [asking_price] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL
            CONSTRAINT [DF_VehicleListing_currency_code] DEFAULT ('INR'),
        [description] NVARCHAR(1000) NULL,
        CONSTRAINT [PK_VehicleListing] PRIMARY KEY ([listing_id]),
        CONSTRAINT [FK_VehicleListing_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_VehicleListing_Branch_branch_id] FOREIGN KEY ([branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [CK_VehicleListing_closed_at] CHECK ([closed_at] IS NULL OR [closed_at] >= [listed_at]),
        CONSTRAINT [CK_VehicleListing_asking_price] CHECK ([asking_price] >= 0),
        CONSTRAINT [CK_VehicleListing_currency_upper] CHECK ([currency_code] = UPPER([currency_code])),
        CONSTRAINT [CK_VehicleListing_status] CHECK ([status] IN ('DRAFT', 'ACTIVE', 'PAUSED', 'CLOSED', 'WITHDRAWN', 'SOLD'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'marketplace.ListingImage', N'U') IS NULL
BEGIN
    CREATE TABLE [marketplace].[ListingImage]
    (
        [listing_image_id] INT IDENTITY(1,1) NOT NULL,
        [listing_id] INT NOT NULL,
        [image_reference] NVARCHAR(500) NOT NULL,
        [display_order] INT NOT NULL,
        [caption] NVARCHAR(200) NULL,
        CONSTRAINT [PK_ListingImage] PRIMARY KEY ([listing_image_id]),
        CONSTRAINT [FK_ListingImage_VehicleListing_listing_id] FOREIGN KEY ([listing_id]) REFERENCES [marketplace].[VehicleListing] ([listing_id]),
        CONSTRAINT [UQ_ListingImage_listing_id_display_order] UNIQUE ([listing_id], [display_order]),
        CONSTRAINT [CK_ListingImage_display_order] CHECK ([display_order] > 0)
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'marketplace.CustomerEnquiry', N'U') IS NULL
BEGIN
    CREATE TABLE [marketplace].[CustomerEnquiry]
    (
        [enquiry_id] INT IDENTITY(1,1) NOT NULL,
        [listing_id] INT NOT NULL,
        [customer_id] INT NOT NULL,
        [assigned_employee_id] INT NULL,
        [channel_code] VARCHAR(20) NOT NULL,
        [received_at] DATETIME2(0) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [message_reference] NVARCHAR(300) NULL,
        CONSTRAINT [PK_CustomerEnquiry] PRIMARY KEY ([enquiry_id]),
        CONSTRAINT [FK_CustomerEnquiry_VehicleListing_listing_id] FOREIGN KEY ([listing_id]) REFERENCES [marketplace].[VehicleListing] ([listing_id]),
        CONSTRAINT [FK_CustomerEnquiry_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [FK_CustomerEnquiry_Employee_assigned_employee_id] FOREIGN KEY ([assigned_employee_id]) REFERENCES [core].[Employee] ([employee_id]),
        CONSTRAINT [CK_CustomerEnquiry_channel] CHECK ([channel_code] IN ('WEB', 'PHONE', 'BRANCH', 'PARTNER', 'OTHER')),
        CONSTRAINT [CK_CustomerEnquiry_status] CHECK ([status] IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'marketplace.VehicleReservation', N'U') IS NULL
BEGIN
    CREATE TABLE [marketplace].[VehicleReservation]
    (
        [reservation_id] INT IDENTITY(1,1) NOT NULL,
        [listing_id] INT NOT NULL,
        [customer_id] INT NOT NULL,
        [created_at] DATETIME2(0) NOT NULL,
        [expires_at] DATETIME2(0) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [released_at] DATETIME2(0) NULL,
        CONSTRAINT [PK_VehicleReservation] PRIMARY KEY ([reservation_id]),
        CONSTRAINT [FK_VehicleReservation_VehicleListing_listing_id] FOREIGN KEY ([listing_id]) REFERENCES [marketplace].[VehicleListing] ([listing_id]),
        CONSTRAINT [FK_VehicleReservation_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [CK_VehicleReservation_expiry] CHECK ([expires_at] > [created_at]),
        CONSTRAINT [CK_VehicleReservation_release] CHECK ([released_at] IS NULL OR [released_at] >= [created_at]),
        CONSTRAINT [CK_VehicleReservation_status] CHECK ([status] IN ('ACTIVE', 'CONVERTED', 'RELEASED', 'EXPIRED'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'sales.SalesOrder', N'U') IS NULL
BEGIN
    CREATE TABLE [sales].[SalesOrder]
    (
        [order_id] INT IDENTITY(1,1) NOT NULL,
        [buyer_customer_id] INT NOT NULL,
        [created_at] DATETIME2(0) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [currency_code] CHAR(3) NOT NULL
            CONSTRAINT [DF_SalesOrder_currency_code] DEFAULT ('INR'),
        [confirmed_at] DATETIME2(0) NULL,
        [completed_at] DATETIME2(0) NULL,
        [cancelled_at] DATETIME2(0) NULL,
        CONSTRAINT [PK_SalesOrder] PRIMARY KEY ([order_id]),
        CONSTRAINT [FK_SalesOrder_Customer_buyer_customer_id] FOREIGN KEY ([buyer_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [CK_SalesOrder_status] CHECK ([status] IN ('DRAFT', 'CONFIRMED', 'COMPLETED', 'CANCELLED')),
        CONSTRAINT [CK_SalesOrder_currency_upper] CHECK ([currency_code] = UPPER([currency_code])),
        CONSTRAINT [CK_SalesOrder_event_dates] CHECK (([confirmed_at] IS NULL OR [confirmed_at] >= [created_at]) AND ([completed_at] IS NULL OR [completed_at] >= [created_at]) AND ([cancelled_at] IS NULL OR [cancelled_at] >= [created_at]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'sales.SalesOrderItem', N'U') IS NULL
BEGIN
    CREATE TABLE [sales].[SalesOrderItem]
    (
        [order_item_id] INT IDENTITY(1,1) NOT NULL,
        [order_id] INT NOT NULL,
        [vehicle_id] INT NOT NULL,
        [reservation_id] INT NULL,
        [sale_price] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL,
        CONSTRAINT [PK_SalesOrderItem] PRIMARY KEY ([order_item_id]),
        CONSTRAINT [FK_SalesOrderItem_SalesOrder_order_id] FOREIGN KEY ([order_id]) REFERENCES [sales].[SalesOrder] ([order_id]),
        CONSTRAINT [FK_SalesOrderItem_Vehicle_vehicle_id] FOREIGN KEY ([vehicle_id]) REFERENCES [vehicle].[Vehicle] ([vehicle_id]),
        CONSTRAINT [FK_SalesOrderItem_VehicleReservation_reservation_id] FOREIGN KEY ([reservation_id]) REFERENCES [marketplace].[VehicleReservation] ([reservation_id]),
        CONSTRAINT [UQ_SalesOrderItem_order_id_vehicle_id] UNIQUE ([order_id], [vehicle_id]),
        CONSTRAINT [CK_SalesOrderItem_sale_price] CHECK ([sale_price] >= 0),
        CONSTRAINT [CK_SalesOrderItem_currency_upper] CHECK ([currency_code] = UPPER([currency_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'finance.Payment', N'U') IS NULL
BEGIN
    CREATE TABLE [finance].[Payment]
    (
        [payment_id] INT IDENTITY(1,1) NOT NULL,
        [order_id] INT NOT NULL,
        [provider_code] VARCHAR(30) NOT NULL,
        [provider_reference] VARCHAR(100) NULL,
        [payment_method_code] VARCHAR(30) NOT NULL,
        [amount] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [initiated_at] DATETIME2(0) NOT NULL,
        [settled_at] DATETIME2(0) NULL,
        CONSTRAINT [PK_Payment] PRIMARY KEY ([payment_id]),
        CONSTRAINT [FK_Payment_SalesOrder_order_id] FOREIGN KEY ([order_id]) REFERENCES [sales].[SalesOrder] ([order_id]),
        CONSTRAINT [CK_Payment_amount] CHECK ([amount] > 0),
        CONSTRAINT [CK_Payment_status] CHECK ([status] IN ('PENDING', 'SUCCEEDED', 'FAILED', 'REVERSED')),
        CONSTRAINT [CK_Payment_settled_at] CHECK ([settled_at] IS NULL OR [settled_at] >= [initiated_at]),
        CONSTRAINT [CK_Payment_currency_upper] CHECK ([currency_code] = UPPER([currency_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'finance.Refund', N'U') IS NULL
BEGIN
    CREATE TABLE [finance].[Refund]
    (
        [refund_id] INT IDENTITY(1,1) NOT NULL,
        [payment_id] INT NOT NULL,
        [provider_reference] VARCHAR(100) NULL,
        [amount] DECIMAL(19,4) NOT NULL,
        [currency_code] CHAR(3) NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [requested_at] DATETIME2(0) NOT NULL,
        [settled_at] DATETIME2(0) NULL,
        CONSTRAINT [PK_Refund] PRIMARY KEY ([refund_id]),
        CONSTRAINT [FK_Refund_Payment_payment_id] FOREIGN KEY ([payment_id]) REFERENCES [finance].[Payment] ([payment_id]),
        CONSTRAINT [CK_Refund_amount] CHECK ([amount] > 0),
        CONSTRAINT [CK_Refund_status] CHECK ([status] IN ('PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
        CONSTRAINT [CK_Refund_settled_at] CHECK ([settled_at] IS NULL OR [settled_at] >= [requested_at]),
        CONSTRAINT [CK_Refund_currency_upper] CHECK ([currency_code] = UPPER([currency_code]))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'delivery.OwnershipTransfer', N'U') IS NULL
BEGIN
    CREATE TABLE [delivery].[OwnershipTransfer]
    (
        [transfer_id] INT IDENTITY(1,1) NOT NULL,
        [order_item_id] INT NOT NULL,
        [from_customer_id] INT NOT NULL,
        [to_customer_id] INT NOT NULL,
        [status] VARCHAR(20) NOT NULL,
        [submitted_at] DATETIME2(0) NULL,
        [completed_at] DATETIME2(0) NULL,
        [authority_reference] VARCHAR(100) NULL,
        CONSTRAINT [PK_OwnershipTransfer] PRIMARY KEY ([transfer_id]),
        CONSTRAINT [FK_OwnershipTransfer_SalesOrderItem_order_item_id] FOREIGN KEY ([order_item_id]) REFERENCES [sales].[SalesOrderItem] ([order_item_id]),
        CONSTRAINT [FK_OwnershipTransfer_Customer_from_customer_id] FOREIGN KEY ([from_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [FK_OwnershipTransfer_Customer_to_customer_id] FOREIGN KEY ([to_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [CK_OwnershipTransfer_status] CHECK ([status] IN ('NOT_STARTED', 'SUBMITTED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED')),
        CONSTRAINT [CK_OwnershipTransfer_event_dates] CHECK ([completed_at] IS NULL OR [submitted_at] IS NULL OR [completed_at] >= [submitted_at]),
        CONSTRAINT [CK_OwnershipTransfer_distinct_parties] CHECK ([from_customer_id] <> [to_customer_id])
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
IF OBJECT_ID(N'delivery.VehicleDelivery', N'U') IS NULL
BEGIN
    CREATE TABLE [delivery].[VehicleDelivery]
    (
        [delivery_id] INT IDENTITY(1,1) NOT NULL,
        [order_item_id] INT NOT NULL,
        [recipient_customer_id] INT NOT NULL,
        [branch_id] INT NULL,
        [delivery_address_id] INT NULL,
        [scheduled_at] DATETIME2(0) NULL,
        [completed_at] DATETIME2(0) NULL,
        [status] VARCHAR(20) NOT NULL,
        [handover_reference] VARCHAR(100) NULL,
        CONSTRAINT [PK_VehicleDelivery] PRIMARY KEY ([delivery_id]),
        CONSTRAINT [FK_VehicleDelivery_SalesOrderItem_order_item_id] FOREIGN KEY ([order_item_id]) REFERENCES [sales].[SalesOrderItem] ([order_item_id]),
        CONSTRAINT [FK_VehicleDelivery_Customer_recipient_customer_id] FOREIGN KEY ([recipient_customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [FK_VehicleDelivery_Branch_branch_id] FOREIGN KEY ([branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [FK_VehicleDelivery_CustomerAddress_delivery_address_id] FOREIGN KEY ([delivery_address_id]) REFERENCES [core].[CustomerAddress] ([address_id]),
        CONSTRAINT [CK_VehicleDelivery_status] CHECK ([status] IN ('SCHEDULED', 'IN_TRANSIT', 'COMPLETED', 'FAILED', 'CANCELLED'))
    );
END;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 07_lifecycle_tables.sql */

/* BEGIN SOURCE: 08_constraints.sql */

USE [CARS24DataModelingSystem];

GO

/* Row checks and key constraints are declared alongside table definitions.
   Cross-row/temporal rules below intentionally remain transactional or
   application validations; a simple CHECK constraint cannot enforce them. */
/* Transactional/application rules (not reducible to row CHECK constraints):
   - Ownership intervals for a vehicle cannot overlap; current_owner_customer_id
     must match the active history row.
   - A registration number may have only one simultaneous active assignment.
   - Submission seller must match owner/authority; inspection submission must
     refer to the same vehicle; report/defect item must belong to that report.
   - Offer, valuation, submission, seller, agreement, acquisition, and vehicle
     must agree across their relationship chain.
   - Acquisition and current owner projection need an organization/ownership
     policy; Day 1 currently models current owners as Customer only.
   - Listing publication eligibility, one active hold per vehicle across all
     listing rows, matching order/buyer/reservation/item/vehicle, currency
     consistency, and completed-sale uniqueness require serialized workflow.
   - Cumulative successful refunds cannot exceed the captured successful
     payment; this needs transaction locking/aggregate validation.
   - Ownership transfer and delivery recipient/vehicle must match the order.
   Variant-to-model consistency is enforced by the composite FK in
   06_vehicle_identity.sql. One-item-per-order and one active listing/hold per
   listing have supporting unique indexes in 09_indexes.sql. */

GO

/* END SOURCE: 08_constraints.sql */

/* BEGIN SOURCE: 09_indexes.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
/* SQL Server does not automatically index foreign keys. These indexes support
   modeled joins and lookup paths; PK/UQ constraints already create indexes. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.Branch') AND name = N'IX_Branch_city_id')
    CREATE INDEX [IX_Branch_city_id] ON [core].[Branch] ([city_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.Employee') AND name = N'IX_Employee_branch_id')
    CREATE INDEX [IX_Employee_branch_id] ON [core].[Employee] ([branch_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.CustomerContact') AND name = N'IX_CustomerContact_type_value')
    CREATE INDEX [IX_CustomerContact_type_value] ON [core].[CustomerContact] ([contact_type], [contact_value]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.CustomerAddress') AND name = N'IX_CustomerAddress_customer_id')
    CREATE INDEX [IX_CustomerAddress_customer_id] ON [core].[CustomerAddress] ([customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.CustomerAddress') AND name = N'IX_CustomerAddress_city_id')
    CREATE INDEX [IX_CustomerAddress_city_id] ON [core].[CustomerAddress] ([city_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.Vehicle') AND name = N'IX_Vehicle_model_id')
    CREATE INDEX [IX_Vehicle_model_id] ON [vehicle].[Vehicle] ([model_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.Vehicle') AND name = N'IX_Vehicle_variant_id_model_id')
    CREATE INDEX [IX_Vehicle_variant_id_model_id] ON [vehicle].[Vehicle] ([variant_id], [model_id]) WHERE [variant_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.Vehicle') AND name = N'UX_Vehicle_vin')
    CREATE UNIQUE INDEX [UX_Vehicle_vin] ON [vehicle].[Vehicle] ([vin]) WHERE [vin] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.Vehicle') AND name = N'IX_Vehicle_current_owner_customer_id')
    CREATE INDEX [IX_Vehicle_current_owner_customer_id] ON [vehicle].[Vehicle] ([current_owner_customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.VehicleOwnershipHistory') AND name = N'IX_VehicleOwnershipHistory_customer_id')
    CREATE INDEX [IX_VehicleOwnershipHistory_customer_id] ON [vehicle].[VehicleOwnershipHistory] ([customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.VehicleSubmission') AND name = N'IX_VehicleSubmission_vehicle_id')
    CREATE INDEX [IX_VehicleSubmission_vehicle_id] ON [vehicle].[VehicleSubmission] ([vehicle_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.VehicleSubmission') AND name = N'IX_VehicleSubmission_seller_customer_id_submitted_at')
    CREATE INDEX [IX_VehicleSubmission_seller_customer_id_submitted_at] ON [vehicle].[VehicleSubmission] ([seller_customer_id], [submitted_at]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.VehicleSubmission') AND name = N'IX_VehicleSubmission_branch_id')
    CREATE INDEX [IX_VehicleSubmission_branch_id] ON [vehicle].[VehicleSubmission] ([branch_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.VehicleRegistration') AND name = N'IX_VehicleRegistration_vehicle_id')
    CREATE INDEX [IX_VehicleRegistration_vehicle_id] ON [vehicle].[VehicleRegistration] ([vehicle_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'vehicle.VehicleRegistration') AND name = N'IX_VehicleRegistration_registration_number')
    CREATE INDEX [IX_VehicleRegistration_registration_number] ON [vehicle].[VehicleRegistration] ([registration_number]);

/* Lifecycle foreign keys and selective lookup paths. Existing PK/UQ indexes
   are reused when their leading key columns already support the FK. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.Inspection') AND name = N'IX_Inspection_vehicle_id')
    CREATE INDEX [IX_Inspection_vehicle_id] ON [inspection].[Inspection] ([vehicle_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.Inspection') AND name = N'IX_Inspection_submission_id')
    CREATE INDEX [IX_Inspection_submission_id] ON [inspection].[Inspection] ([submission_id]) WHERE [submission_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.Inspection') AND name = N'IX_Inspection_inspector_employee_id')
    CREATE INDEX [IX_Inspection_inspector_employee_id] ON [inspection].[Inspection] ([inspector_employee_id]) WHERE [inspector_employee_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.InspectionItem') AND name = N'IX_InspectionItem_report_id')
    CREATE INDEX [IX_InspectionItem_report_id] ON [inspection].[InspectionItem] ([report_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.Defect') AND name = N'IX_Defect_report_id')
    CREATE INDEX [IX_Defect_report_id] ON [inspection].[Defect] ([report_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.Defect') AND name = N'IX_Defect_inspection_item_id')
    CREATE INDEX [IX_Defect_inspection_item_id] ON [inspection].[Defect] ([inspection_item_id]) WHERE [inspection_item_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.VehicleValuation') AND name = N'IX_VehicleValuation_vehicle_id_valued_at')
    CREATE INDEX [IX_VehicleValuation_vehicle_id_valued_at] ON [inspection].[VehicleValuation] ([vehicle_id], [valued_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.VehicleValuation') AND name = N'IX_VehicleValuation_report_id')
    CREATE INDEX [IX_VehicleValuation_report_id] ON [inspection].[VehicleValuation] ([report_id]) WHERE [report_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inspection.VehicleValuation') AND name = N'IX_VehicleValuation_assessor_employee_id')
    CREATE INDEX [IX_VehicleValuation_assessor_employee_id] ON [inspection].[VehicleValuation] ([assessor_employee_id]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.PurchaseOffer') AND name = N'IX_PurchaseOffer_submission_id')
    CREATE INDEX [IX_PurchaseOffer_submission_id] ON [acquisition].[PurchaseOffer] ([submission_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.PurchaseOffer') AND name = N'IX_PurchaseOffer_valuation_id')
    CREATE INDEX [IX_PurchaseOffer_valuation_id] ON [acquisition].[PurchaseOffer] ([valuation_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.PurchaseOffer') AND name = N'IX_PurchaseOffer_seller_customer_id')
    CREATE INDEX [IX_PurchaseOffer_seller_customer_id] ON [acquisition].[PurchaseOffer] ([seller_customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.PurchaseAgreement') AND name = N'IX_PurchaseAgreement_offer_id')
    CREATE INDEX [IX_PurchaseAgreement_offer_id] ON [acquisition].[PurchaseAgreement] ([offer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.PurchaseAgreement') AND name = N'IX_PurchaseAgreement_seller_customer_id')
    CREATE INDEX [IX_PurchaseAgreement_seller_customer_id] ON [acquisition].[PurchaseAgreement] ([seller_customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.VehicleAcquisition') AND name = N'IX_VehicleAcquisition_vehicle_id')
    CREATE INDEX [IX_VehicleAcquisition_vehicle_id] ON [acquisition].[VehicleAcquisition] ([vehicle_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'acquisition.VehicleAcquisition') AND name = N'IX_VehicleAcquisition_seller_customer_id')
    CREATE INDEX [IX_VehicleAcquisition_seller_customer_id] ON [acquisition].[VehicleAcquisition] ([seller_customer_id]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inventory.Inventory') AND name = N'IX_Inventory_branch_id_status')
    CREATE INDEX [IX_Inventory_branch_id_status] ON [inventory].[Inventory] ([branch_id], [status]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inventory.InventoryMovement') AND name = N'IX_InventoryMovement_inventory_id_occurred_at')
    CREATE INDEX [IX_InventoryMovement_inventory_id_occurred_at] ON [inventory].[InventoryMovement] ([inventory_id], [occurred_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inventory.InventoryMovement') AND name = N'IX_InventoryMovement_from_branch_id')
    CREATE INDEX [IX_InventoryMovement_from_branch_id] ON [inventory].[InventoryMovement] ([from_branch_id]) WHERE [from_branch_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inventory.InventoryMovement') AND name = N'IX_InventoryMovement_to_branch_id')
    CREATE INDEX [IX_InventoryMovement_to_branch_id] ON [inventory].[InventoryMovement] ([to_branch_id]) WHERE [to_branch_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'inventory.InventoryMovement') AND name = N'IX_InventoryMovement_employee_id')
    CREATE INDEX [IX_InventoryMovement_employee_id] ON [inventory].[InventoryMovement] ([employee_id]) WHERE [employee_id] IS NOT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.VehicleListing') AND name = N'IX_VehicleListing_branch_id')
    CREATE INDEX [IX_VehicleListing_branch_id] ON [marketplace].[VehicleListing] ([branch_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.VehicleListing') AND name = N'IX_VehicleListing_vehicle_id')
    CREATE INDEX [IX_VehicleListing_vehicle_id] ON [marketplace].[VehicleListing] ([vehicle_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.VehicleListing') AND name = N'UX_VehicleListing_active_vehicle')
    CREATE UNIQUE INDEX [UX_VehicleListing_active_vehicle] ON [marketplace].[VehicleListing] ([vehicle_id]) WHERE [status] = 'ACTIVE';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.CustomerEnquiry') AND name = N'IX_CustomerEnquiry_listing_id_received_at')
    CREATE INDEX [IX_CustomerEnquiry_listing_id_received_at] ON [marketplace].[CustomerEnquiry] ([listing_id], [received_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.CustomerEnquiry') AND name = N'IX_CustomerEnquiry_customer_id')
    CREATE INDEX [IX_CustomerEnquiry_customer_id] ON [marketplace].[CustomerEnquiry] ([customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.CustomerEnquiry') AND name = N'IX_CustomerEnquiry_assigned_employee_id')
    CREATE INDEX [IX_CustomerEnquiry_assigned_employee_id] ON [marketplace].[CustomerEnquiry] ([assigned_employee_id]) WHERE [assigned_employee_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.VehicleReservation') AND name = N'IX_VehicleReservation_listing_id_created_at')
    CREATE INDEX [IX_VehicleReservation_listing_id_created_at] ON [marketplace].[VehicleReservation] ([listing_id], [created_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.VehicleReservation') AND name = N'UX_VehicleReservation_active_listing')
    CREATE UNIQUE INDEX [UX_VehicleReservation_active_listing] ON [marketplace].[VehicleReservation] ([listing_id]) WHERE [status] = 'ACTIVE';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'marketplace.VehicleReservation') AND name = N'IX_VehicleReservation_customer_id')
    CREATE INDEX [IX_VehicleReservation_customer_id] ON [marketplace].[VehicleReservation] ([customer_id]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'sales.SalesOrder') AND name = N'IX_SalesOrder_buyer_customer_id_created_at')
    CREATE INDEX [IX_SalesOrder_buyer_customer_id_created_at] ON [sales].[SalesOrder] ([buyer_customer_id], [created_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'sales.SalesOrderItem') AND name = N'IX_SalesOrderItem_vehicle_id')
    CREATE INDEX [IX_SalesOrderItem_vehicle_id] ON [sales].[SalesOrderItem] ([vehicle_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'sales.SalesOrderItem') AND name = N'UX_SalesOrderItem_reservation_id')
    CREATE UNIQUE INDEX [UX_SalesOrderItem_reservation_id] ON [sales].[SalesOrderItem] ([reservation_id]) WHERE [reservation_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'sales.SalesOrderItem') AND name = N'UX_SalesOrderItem_one_item_per_order')
    CREATE UNIQUE INDEX [UX_SalesOrderItem_one_item_per_order] ON [sales].[SalesOrderItem] ([order_id]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payment') AND name = N'IX_Payment_order_id_initiated_at')
    CREATE INDEX [IX_Payment_order_id_initiated_at] ON [finance].[Payment] ([order_id], [initiated_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Payment') AND name = N'UX_Payment_provider_reference')
    CREATE UNIQUE INDEX [UX_Payment_provider_reference] ON [finance].[Payment] ([provider_code], [provider_reference]) WHERE [provider_reference] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Refund') AND name = N'IX_Refund_payment_id_requested_at')
    CREATE INDEX [IX_Refund_payment_id_requested_at] ON [finance].[Refund] ([payment_id], [requested_at] DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'finance.Refund') AND name = N'UX_Refund_provider_reference')
    CREATE UNIQUE INDEX [UX_Refund_provider_reference] ON [finance].[Refund] ([provider_reference]) WHERE [provider_reference] IS NOT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.OwnershipTransfer') AND name = N'IX_OwnershipTransfer_order_item_id')
    CREATE INDEX [IX_OwnershipTransfer_order_item_id] ON [delivery].[OwnershipTransfer] ([order_item_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.OwnershipTransfer') AND name = N'IX_OwnershipTransfer_from_customer_id')
    CREATE INDEX [IX_OwnershipTransfer_from_customer_id] ON [delivery].[OwnershipTransfer] ([from_customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.OwnershipTransfer') AND name = N'IX_OwnershipTransfer_to_customer_id')
    CREATE INDEX [IX_OwnershipTransfer_to_customer_id] ON [delivery].[OwnershipTransfer] ([to_customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.VehicleDelivery') AND name = N'IX_VehicleDelivery_order_item_id')
    CREATE INDEX [IX_VehicleDelivery_order_item_id] ON [delivery].[VehicleDelivery] ([order_item_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.VehicleDelivery') AND name = N'IX_VehicleDelivery_recipient_customer_id')
    CREATE INDEX [IX_VehicleDelivery_recipient_customer_id] ON [delivery].[VehicleDelivery] ([recipient_customer_id]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.VehicleDelivery') AND name = N'IX_VehicleDelivery_branch_id')
    CREATE INDEX [IX_VehicleDelivery_branch_id] ON [delivery].[VehicleDelivery] ([branch_id]) WHERE [branch_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'delivery.VehicleDelivery') AND name = N'IX_VehicleDelivery_delivery_address_id')
    CREATE INDEX [IX_VehicleDelivery_delivery_address_id] ON [delivery].[VehicleDelivery] ([delivery_address_id]) WHERE [delivery_address_id] IS NOT NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* Index rationale:
   - Branch.city_id and Employee.branch_id: branch/city and employee/site joins.
   - (contact_type, contact_value): phone/email lookup; contact values are
     sensitive. The contact uniqueness index already starts with customer_id.
   - CustomerAddress.customer_id and city_id: address history and city joins.
   - Vehicle.model_id, optional (variant_id, model_id), and current_owner:
     catalog, variant consistency, and owner lookup.
   - filtered unique VIN: exact VIN lookup without restricting multiple NULLs.
   - VehicleRegistration.vehicle_id and registration_number: history joins and
     exact registration lookup; historical duplicates across dates are allowed.
   - OwnershipHistory.customer_id: owner history lookup (vehicle_id is covered
     by its unique vehicle/start constraint).
   - Submission.vehicle_id, (seller_customer_id, submitted_at), branch_id:
     vehicle history, seller timeline, and intake-branch queue. Role, catalog,
     and address/customer FK prefixes are covered by existing UQ structures.
   - Lifecycle indexes cover inspection/assessment history, acquisition joins,
     inventory movement timelines, listing/enquiry/reservation lookups, buyer
     order history, payment/refund reconciliation, and transfer/delivery joins.
   - Filtered unique indexes enforce supplied provider references, one active
     listing per vehicle, one active hold per listing, and non-NULL VINs.
   - One item per order is an explicit initial-scope policy from BR-025. */

GO

/* END SOURCE: 09_indexes.sql */

/* BEGIN SOURCE: 10_seed_reference_data.sql */

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
SET XACT_ABORT ON;
BEGIN TRANSACTION;

/* Predictable educational fixtures only; all customer names are synthetic. */
INSERT INTO [ref].[City] ([city_name], [state_code], [country_code])
SELECT src.[city_name], src.[state_code], 'IN'
FROM (VALUES
    (N'Hyderabad', 'TG'), (N'Mumbai', 'MH'), (N'Bengaluru', 'KA'),
    (N'Pune', 'MH'), (N'Delhi', 'DL'), (N'Chennai', 'TN'),
    (N'Ahmedabad', 'GJ'), (N'Rajkot', 'GJ')
) AS src([city_name], [state_code])
WHERE NOT EXISTS
(
    SELECT 1 FROM [ref].[City] AS c
    WHERE c.[city_name] = src.[city_name] AND c.[state_code] = src.[state_code] AND c.[country_code] = 'IN'
);

INSERT INTO [core].[Branch] ([city_id], [branch_code], [branch_name], [address_text], [status])
SELECT c.[city_id], src.[branch_code], src.[branch_name], src.[address_text], 'ACTIVE'
FROM (VALUES
    ('HYD-CEN', N'Hyderabad Central', N'Synthetic branch address, Hyderabad'),
    ('MUM-WST', N'Mumbai West', N'Synthetic branch address, Mumbai'),
    ('BLR-SOU', N'Bengaluru South', N'Synthetic branch address, Bengaluru'),
    ('PUN-CEN', N'Pune Central', N'Synthetic branch address, Pune'),
    ('DEL-SOU', N'Delhi South', N'Synthetic branch address, Delhi'),
    ('CHE-CEN', N'Chennai Central', N'Synthetic branch address, Chennai'),
    ('AMD-CEN', N'Ahmedabad Central', N'Synthetic branch address, Ahmedabad'),
    ('RJK-CEN', N'Rajkot Central', N'Synthetic branch address, Rajkot')
) AS src([branch_code], [branch_name], [address_text])
JOIN [ref].[City] AS c ON c.[city_name] = CASE src.[branch_code]
    WHEN 'HYD-CEN' THEN N'Hyderabad' WHEN 'MUM-WST' THEN N'Mumbai'
    WHEN 'BLR-SOU' THEN N'Bengaluru' WHEN 'PUN-CEN' THEN N'Pune'
    WHEN 'DEL-SOU' THEN N'Delhi' WHEN 'CHE-CEN' THEN N'Chennai'
    WHEN 'AMD-CEN' THEN N'Ahmedabad' ELSE N'Rajkot' END
WHERE NOT EXISTS (SELECT 1 FROM [core].[Branch] AS b WHERE b.[branch_code] = src.[branch_code]);

INSERT INTO [core].[Employee] ([branch_id], [employee_code], [display_name], [active_from])
SELECT b.[branch_id], src.[employee_code], src.[display_name], CONVERT(date, '20260101', 112)
FROM (VALUES
    ('EMP-SYN-001', N'Synthetic Staff One', 'HYD-CEN'),
    ('EMP-SYN-002', N'Synthetic Staff Two', 'MUM-WST'),
    ('EMP-SYN-003', N'Synthetic Staff Three', 'BLR-SOU'),
    ('EMP-SYN-004', N'Synthetic Staff Four', 'PUN-CEN')
) AS src([employee_code], [display_name], [branch_code])
JOIN [core].[Branch] AS b ON b.[branch_code] = src.[branch_code]
WHERE NOT EXISTS (SELECT 1 FROM [core].[Employee] AS e WHERE e.[employee_code] = src.[employee_code]);

INSERT INTO [core].[EmployeeRole] ([employee_id], [role_code], [valid_from])
SELECT e.[employee_id], src.[role_code], CONVERT(datetime2(0), '2026-01-01T00:00:00')
FROM (VALUES ('EMP-SYN-001', 'BRANCH_MANAGER'), ('EMP-SYN-002', 'INSPECTOR'),
             ('EMP-SYN-003', 'SALES_EXECUTIVE'), ('EMP-SYN-004', 'INVENTORY_MANAGER')) AS src([employee_code], [role_code])
JOIN [core].[Employee] AS e ON e.[employee_code] = src.[employee_code]
WHERE NOT EXISTS (SELECT 1 FROM [core].[EmployeeRole] AS er WHERE er.[employee_id] = e.[employee_id] AND er.[role_code] = src.[role_code] AND er.[valid_from] = CONVERT(datetime2(0), '2026-01-01T00:00:00'));

INSERT INTO [core].[Customer] ([display_name], [legal_name], [status], [created_at])
SELECT src.[display_name], src.[legal_name], 'ACTIVE', CONVERT(datetime2(0), '2026-01-02T10:00:00')
FROM (VALUES (N'Synthetic Customer Alpha', N'Synthetic Customer Alpha'),
             (N'Synthetic Customer Beta', N'Synthetic Customer Beta'),
             (N'Synthetic Customer Gamma', NULL)) AS src([display_name], [legal_name])
WHERE NOT EXISTS (SELECT 1 FROM [core].[Customer] AS c WHERE c.[display_name] = src.[display_name]);

INSERT INTO [core].[CustomerContact] ([customer_id], [contact_type], [contact_value], [is_verified], [valid_from])
SELECT c.[customer_id], src.[contact_type], src.[contact_value], 0, CONVERT(datetime2(0), '2026-01-02T10:00:00')
FROM (VALUES (N'Synthetic Customer Alpha', 'EMAIL', N'alpha@example.invalid'),
             (N'Synthetic Customer Alpha', 'PHONE', N'+919000000001'),
             (N'Synthetic Customer Beta', 'EMAIL', N'beta@example.invalid')) AS src([display_name], [contact_type], [contact_value])
JOIN [core].[Customer] AS c ON c.[display_name] = src.[display_name]
WHERE NOT EXISTS (SELECT 1 FROM [core].[CustomerContact] AS cc WHERE cc.[customer_id] = c.[customer_id] AND cc.[contact_type] = src.[contact_type] AND cc.[contact_value] = src.[contact_value] AND cc.[valid_from] = CONVERT(datetime2(0), '2026-01-02T10:00:00'));

INSERT INTO [core].[CustomerAddress] ([customer_id], [city_id], [address_type], [address_line1], [address_line2], [postal_code], [valid_from])
SELECT c.[customer_id], city.[city_id], 'HOME', src.[address_line1], NULL, src.[postal_code], CONVERT(datetime2(0), '2026-01-02T10:00:00')
FROM (VALUES (N'Synthetic Customer Alpha', N'Hyderabad', N'Synthetic address A', '500001'),
             (N'Synthetic Customer Beta', N'Mumbai', N'Synthetic address B', '400001'),
             (N'Synthetic Customer Gamma', N'Bengaluru', N'Synthetic address C', '560001')) AS src([display_name], [city_name], [address_line1], [postal_code])
JOIN [core].[Customer] AS c ON c.[display_name] = src.[display_name]
JOIN [ref].[City] AS city ON city.[city_name] = src.[city_name] AND city.[country_code] = 'IN'
WHERE NOT EXISTS (SELECT 1 FROM [core].[CustomerAddress] AS ca WHERE ca.[customer_id] = c.[customer_id] AND ca.[address_line1] = src.[address_line1]);

INSERT INTO [vehicle].[VehicleBrand] ([brand_name])
SELECT src.[brand_name] FROM (VALUES (N'Maruti Suzuki'), (N'Hyundai'), (N'Tata Motors'), (N'Mahindra'), (N'Honda'), (N'Toyota'), (N'Kia'), (N'Volkswagen')) AS src([brand_name])
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleBrand] AS b WHERE b.[brand_name] = src.[brand_name]);

INSERT INTO [vehicle].[VehicleModel] ([brand_id], [model_name])
SELECT b.[brand_id], src.[model_name]
FROM (VALUES (N'Hyundai', N'Creta'), (N'Maruti Suzuki', N'Swift'), (N'Tata Motors', N'Nexon'),
             (N'Mahindra', N'XUV700'), (N'Honda', N'City'), (N'Toyota', N'Innova Crysta'), (N'Kia', N'Seltos')) AS src([brand_name], [model_name])
JOIN [vehicle].[VehicleBrand] AS b ON b.[brand_name] = src.[brand_name]
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleModel] AS m WHERE m.[brand_id] = b.[brand_id] AND m.[model_name] = src.[model_name]);

INSERT INTO [vehicle].[VehicleVariant] ([model_id], [variant_name])
SELECT m.[model_id], src.[variant_name]
FROM (VALUES (N'Hyundai', N'Creta', N'SX Synthetic'), (N'Maruti Suzuki', N'Swift', N'VXi Synthetic'),
             (N'Tata Motors', N'Nexon', N'XZ+ Synthetic'), (N'Honda', N'City', N'V Synthetic')) AS src([brand_name], [model_name], [variant_name])
JOIN [vehicle].[VehicleBrand] AS b ON b.[brand_name] = src.[brand_name]
JOIN [vehicle].[VehicleModel] AS m ON m.[brand_id] = b.[brand_id] AND m.[model_name] = src.[model_name]
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleVariant] AS v WHERE v.[model_id] = m.[model_id] AND v.[variant_name] = src.[variant_name]);

INSERT INTO [vehicle].[Vehicle] ([model_id], [variant_id], [manufacture_year], [vin], [engine_number], [fuel_type_code], [transmission_type_code], [current_owner_customer_id], [lifecycle_status], [created_at])
SELECT m.[model_id], v.[variant_id], src.[manufacture_year], src.[vin], src.[engine_number], src.[fuel], src.[transmission], c.[customer_id], 'SUBMITTED', CONVERT(datetime2(0), '2026-01-03T09:00:00')
FROM (VALUES (N'Hyundai', N'Creta', N'SX Synthetic', 2022, 'SYNVIN00000000001', 'SYNENG0001', 'PETROL', 'MANUAL', N'Synthetic Customer Alpha'),
             (N'Maruti Suzuki', N'Swift', N'VXi Synthetic', 2021, 'SYNVIN00000000002', 'SYNENG0002', 'PETROL', 'MANUAL', N'Synthetic Customer Beta'),
             (N'Tata Motors', N'Nexon', N'XZ+ Synthetic', 2023, 'SYNVIN00000000003', 'SYNENG0003', 'ELECTRIC', 'AUTOMATIC', N'Synthetic Customer Gamma')) AS src([brand_name], [model_name], [variant_name], [manufacture_year], [vin], [engine_number], [fuel], [transmission], [display_name])
JOIN [vehicle].[VehicleBrand] AS b ON b.[brand_name] = src.[brand_name]
JOIN [vehicle].[VehicleModel] AS m ON m.[brand_id] = b.[brand_id] AND m.[model_name] = src.[model_name]
JOIN [vehicle].[VehicleVariant] AS v ON v.[model_id] = m.[model_id] AND v.[variant_name] = src.[variant_name]
JOIN [core].[Customer] AS c ON c.[display_name] = src.[display_name]
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[Vehicle] AS existing WHERE existing.[vin] = src.[vin]);

INSERT INTO [vehicle].[VehicleRegistration] ([vehicle_id], [registration_number], [issuing_state_code], [valid_from])
SELECT v.[vehicle_id], src.[registration_number], src.[state_code], CONVERT(date, '20260103', 112)
FROM (VALUES ('TS09AB1234', 'TG', 'SYNVIN00000000001'), ('MH02CD5678', 'MH', 'SYNVIN00000000002'), ('KA03EF9012', 'KA', 'SYNVIN00000000003')) AS src([registration_number], [state_code], [vin])
JOIN [vehicle].[Vehicle] AS v ON v.[vin] = src.[vin]
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleRegistration] AS r WHERE r.[registration_number] = src.[registration_number] AND r.[valid_from] = CONVERT(date, '20260103', 112));

INSERT INTO [vehicle].[VehicleOwnershipHistory] ([vehicle_id], [customer_id], [valid_from], [basis_code], [evidence_reference])
SELECT v.[vehicle_id], c.[customer_id], CONVERT(datetime2(0), '2026-01-03T09:00:00'), 'REGISTERED_OWNER', N'Synthetic educational ownership fixture'
FROM (VALUES ('SYNVIN00000000001', N'Synthetic Customer Alpha'), ('SYNVIN00000000002', N'Synthetic Customer Beta'), ('SYNVIN00000000003', N'Synthetic Customer Gamma')) AS src([vin], [display_name])
JOIN [vehicle].[Vehicle] AS v ON v.[vin] = src.[vin]
JOIN [core].[Customer] AS c ON c.[display_name] = src.[display_name]
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleOwnershipHistory] AS h WHERE h.[vehicle_id] = v.[vehicle_id] AND h.[valid_from] = CONVERT(datetime2(0), '2026-01-03T09:00:00'));

INSERT INTO [vehicle].[VehicleSubmission] ([vehicle_id], [seller_customer_id], [branch_id], [submitted_at], [status])
SELECT v.[vehicle_id], c.[customer_id], b.[branch_id], CONVERT(datetime2(0), '2026-01-03T10:00:00'), 'SUBMITTED'
FROM (VALUES ('SYNVIN00000000001', N'Synthetic Customer Alpha', 'HYD-CEN'), ('SYNVIN00000000002', N'Synthetic Customer Beta', 'MUM-WST'), ('SYNVIN00000000003', N'Synthetic Customer Gamma', 'BLR-SOU')) AS src([vin], [display_name], [branch_code])
JOIN [vehicle].[Vehicle] AS v ON v.[vin] = src.[vin]
JOIN [core].[Customer] AS c ON c.[display_name] = src.[display_name]
JOIN [core].[Branch] AS b ON b.[branch_code] = src.[branch_code]
WHERE NOT EXISTS (SELECT 1 FROM [vehicle].[VehicleSubmission] AS s WHERE s.[vehicle_id] = v.[vehicle_id] AND s.[submitted_at] = CONVERT(datetime2(0), '2026-01-03T10:00:00'));

/* Small linked lifecycle fixture for the remaining finalized relations. */
INSERT INTO [inspection].[Inspection] ([vehicle_id], [submission_id], [inspector_employee_id], [scheduled_at], [completed_at], [status])
SELECT v.[vehicle_id], s.[submission_id], e.[employee_id], CONVERT(datetime2(0), '2026-01-04T09:00:00'), CONVERT(datetime2(0), '2026-01-04T10:00:00'), 'COMPLETED'
FROM (VALUES ('SYNVIN00000000001', 'EMP-SYN-002'), ('SYNVIN00000000002', 'EMP-SYN-002'), ('SYNVIN00000000003', 'EMP-SYN-002')) AS src([vin], [employee_code])
JOIN [vehicle].[Vehicle] AS v ON v.[vin] = src.[vin]
JOIN [vehicle].[VehicleSubmission] AS s ON s.[vehicle_id] = v.[vehicle_id] AND s.[submitted_at] = CONVERT(datetime2(0), '2026-01-03T10:00:00')
JOIN [core].[Employee] AS e ON e.[employee_code] = src.[employee_code]
WHERE NOT EXISTS (SELECT 1 FROM [inspection].[Inspection] AS i WHERE i.[vehicle_id] = v.[vehicle_id] AND i.[scheduled_at] = CONVERT(datetime2(0), '2026-01-04T09:00:00'));

INSERT INTO [inspection].[InspectionReport] ([inspection_id], [outcome_code], [summary], [finalized_at])
SELECT i.[inspection_id], 'PASS', N'Synthetic educational inspection summary.', CONVERT(datetime2(0), '2026-01-04T10:05:00')
FROM [inspection].[Inspection] AS i
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = i.[vehicle_id]
WHERE i.[scheduled_at] = CONVERT(datetime2(0), '2026-01-04T09:00:00')
  AND v.[vin] IN ('SYNVIN00000000001', 'SYNVIN00000000002', 'SYNVIN00000000003')
  AND NOT EXISTS (SELECT 1 FROM [inspection].[InspectionReport] AS r WHERE r.[inspection_id] = i.[inspection_id]);

INSERT INTO [inspection].[InspectionItem] ([report_id], [item_code], [outcome_code], [note])
SELECT r.[report_id], src.[item_code], 'PASS', N'Synthetic checklist result.'
FROM [inspection].[InspectionReport] AS r
JOIN [inspection].[Inspection] AS i ON i.[inspection_id] = r.[inspection_id]
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = i.[vehicle_id]
CROSS JOIN (VALUES ('ENGINE', 1), ('BRAKES', 2), ('BODY', 3)) AS src([item_code], [ordinal])
WHERE i.[scheduled_at] = CONVERT(datetime2(0), '2026-01-04T09:00:00')
  AND v.[vin] IN ('SYNVIN00000000001', 'SYNVIN00000000002', 'SYNVIN00000000003')
  AND NOT EXISTS (SELECT 1 FROM [inspection].[InspectionItem] AS it WHERE it.[report_id] = r.[report_id] AND it.[item_code] = src.[item_code]);

INSERT INTO [inspection].[Defect] ([report_id], [inspection_item_id], [category_code], [severity_code], [description], [repair_estimate], [currency_code])
SELECT r.[report_id], it.[inspection_item_id], 'COSMETIC', 'LOW', N'Synthetic minor exterior mark.', 1500.00, 'INR'
FROM [inspection].[InspectionReport] AS r
JOIN [inspection].[Inspection] AS i ON i.[inspection_id] = r.[inspection_id]
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = i.[vehicle_id]
JOIN [inspection].[InspectionItem] AS it ON it.[report_id] = r.[report_id] AND it.[item_code] = 'BODY'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [inspection].[Defect] AS d WHERE d.[report_id] = r.[report_id] AND d.[description] = N'Synthetic minor exterior mark.');

INSERT INTO [inspection].[VehicleValuation] ([vehicle_id], [report_id], [assessor_employee_id], [valued_at], [amount], [currency_code], [basis], [status])
SELECT v.[vehicle_id], r.[report_id], e.[employee_id], CONVERT(datetime2(0), '2026-01-05T09:00:00'), src.[amount], 'INR', N'Synthetic educational valuation fixture.', 'APPROVED'
FROM (VALUES ('SYNVIN00000000001', CAST(850000 AS decimal(19,4))), ('SYNVIN00000000002', CAST(600000 AS decimal(19,4))), ('SYNVIN00000000003', CAST(1100000 AS decimal(19,4)))) AS src([vin], [amount])
JOIN [vehicle].[Vehicle] AS v ON v.[vin] = src.[vin]
JOIN [inspection].[Inspection] AS i ON i.[vehicle_id] = v.[vehicle_id] AND i.[scheduled_at] = CONVERT(datetime2(0), '2026-01-04T09:00:00')
JOIN [inspection].[InspectionReport] AS r ON r.[inspection_id] = i.[inspection_id]
JOIN [core].[Employee] AS e ON e.[employee_code] = 'EMP-SYN-001'
WHERE NOT EXISTS (SELECT 1 FROM [inspection].[VehicleValuation] AS val WHERE val.[vehicle_id] = v.[vehicle_id] AND val.[valued_at] = CONVERT(datetime2(0), '2026-01-05T09:00:00'));

INSERT INTO [acquisition].[PurchaseOffer] ([submission_id], [valuation_id], [seller_customer_id], [offered_at], [expires_at], [amount], [currency_code], [status], [decision_at])
SELECT s.[submission_id], val.[valuation_id], c.[customer_id], CONVERT(datetime2(0), '2026-01-05T10:00:00'), CONVERT(datetime2(0), '2026-01-12T10:00:00'), 825000.00, 'INR', 'ACCEPTED', CONVERT(datetime2(0), '2026-01-06T10:00:00')
FROM [vehicle].[Vehicle] AS v
JOIN [vehicle].[VehicleSubmission] AS s ON s.[vehicle_id] = v.[vehicle_id] AND s.[submitted_at] = CONVERT(datetime2(0), '2026-01-03T10:00:00')
JOIN [inspection].[VehicleValuation] AS val ON val.[vehicle_id] = v.[vehicle_id] AND val.[valued_at] = CONVERT(datetime2(0), '2026-01-05T09:00:00')
JOIN [core].[Customer] AS c ON c.[display_name] = N'Synthetic Customer Alpha'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [acquisition].[PurchaseOffer] AS o WHERE o.[submission_id] = s.[submission_id] AND o.[offered_at] = CONVERT(datetime2(0), '2026-01-05T10:00:00'));

INSERT INTO [acquisition].[PurchaseAgreement] ([offer_id], [seller_customer_id], [agreement_reference], [signed_at], [status])
SELECT o.[offer_id], c.[customer_id], 'SYN-AGR-0001', CONVERT(datetime2(0), '2026-01-06T11:00:00'), 'SIGNED'
FROM [acquisition].[PurchaseOffer] AS o
JOIN [vehicle].[VehicleSubmission] AS s ON s.[submission_id] = o.[submission_id]
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = s.[vehicle_id]
JOIN [core].[Customer] AS c ON c.[display_name] = N'Synthetic Customer Alpha'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [acquisition].[PurchaseAgreement] AS a WHERE a.[agreement_reference] = 'SYN-AGR-0001');

INSERT INTO [acquisition].[VehicleAcquisition] ([agreement_id], [vehicle_id], [seller_customer_id], [acquired_at], [amount], [currency_code])
SELECT a.[agreement_id], v.[vehicle_id], c.[customer_id], CONVERT(datetime2(0), '2026-01-07T09:00:00'), 825000.00, 'INR'
FROM [acquisition].[PurchaseAgreement] AS a
JOIN [acquisition].[PurchaseOffer] AS o ON o.[offer_id] = a.[offer_id]
JOIN [vehicle].[VehicleSubmission] AS s ON s.[submission_id] = o.[submission_id]
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = s.[vehicle_id]
JOIN [core].[Customer] AS c ON c.[display_name] = N'Synthetic Customer Alpha'
WHERE a.[agreement_reference] = 'SYN-AGR-0001'
  AND NOT EXISTS (SELECT 1 FROM [acquisition].[VehicleAcquisition] AS ac WHERE ac.[agreement_id] = a.[agreement_id]);

UPDATE [vehicle].[Vehicle]
SET [lifecycle_status] = 'IN_STOCK'
WHERE [vin] = 'SYNVIN00000000001' AND [lifecycle_status] = 'SUBMITTED';
UPDATE [vehicle].[VehicleSubmission]
SET [status] = 'ACCEPTED', [closed_at] = CONVERT(datetime2(0), '2026-01-07T09:00:00')
WHERE [vehicle_id] = (SELECT [vehicle_id] FROM [vehicle].[Vehicle] WHERE [vin] = 'SYNVIN00000000001')
  AND [submitted_at] = CONVERT(datetime2(0), '2026-01-03T10:00:00') AND [status] = 'SUBMITTED';

INSERT INTO [inventory].[Inventory] ([vehicle_id], [branch_id], [location_code], [status], [since_at])
SELECT v.[vehicle_id], b.[branch_id], 'YARD-A1', 'AVAILABLE', CONVERT(datetime2(0), '2026-01-07T09:05:00')
FROM [vehicle].[Vehicle] AS v JOIN [core].[Branch] AS b ON b.[branch_code] = 'HYD-CEN'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [inventory].[Inventory] AS inv WHERE inv.[vehicle_id] = v.[vehicle_id]);

INSERT INTO [inventory].[InventoryMovement] ([inventory_id], [to_branch_id], [to_location_code], [movement_type], [employee_id], [occurred_at], [reason])
SELECT inv.[inventory_id], inv.[branch_id], inv.[location_code], 'RECEIPT', e.[employee_id], CONVERT(datetime2(0), '2026-01-07T09:05:00'), N'Synthetic initial inventory receipt.'
FROM [inventory].[Inventory] AS inv
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = inv.[vehicle_id]
JOIN [core].[Employee] AS e ON e.[employee_code] = 'EMP-SYN-004'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [inventory].[InventoryMovement] AS m WHERE m.[inventory_id] = inv.[inventory_id] AND m.[occurred_at] = CONVERT(datetime2(0), '2026-01-07T09:05:00'));

INSERT INTO [marketplace].[VehicleListing] ([vehicle_id], [branch_id], [listed_at], [status], [asking_price], [currency_code], [description])
SELECT v.[vehicle_id], b.[branch_id], CONVERT(datetime2(0), '2026-01-08T09:00:00'), 'ACTIVE', 899000.00, 'INR', N'Synthetic educational listing.'
FROM [vehicle].[Vehicle] AS v JOIN [core].[Branch] AS b ON b.[branch_code] = 'HYD-CEN'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [marketplace].[VehicleListing] AS l WHERE l.[vehicle_id] = v.[vehicle_id] AND l.[listed_at] = CONVERT(datetime2(0), '2026-01-08T09:00:00'));

INSERT INTO [marketplace].[ListingImage] ([listing_id], [image_reference], [display_order], [caption])
SELECT l.[listing_id], N'https://example.invalid/synthetic/vehicle-1/front.jpg', 1, N'Synthetic sample image reference'
FROM [marketplace].[VehicleListing] AS l
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = l.[vehicle_id]
WHERE v.[vin] = 'SYNVIN00000000001' AND l.[listed_at] = CONVERT(datetime2(0), '2026-01-08T09:00:00')
  AND NOT EXISTS (SELECT 1 FROM [marketplace].[ListingImage] AS li WHERE li.[listing_id] = l.[listing_id] AND li.[display_order] = 1);

INSERT INTO [marketplace].[CustomerEnquiry] ([listing_id], [customer_id], [assigned_employee_id], [channel_code], [received_at], [status], [message_reference])
SELECT l.[listing_id], c.[customer_id], e.[employee_id], 'WEB', CONVERT(datetime2(0), '2026-01-08T10:00:00'), 'OPEN', N'SYNTH-ENQUIRY-001'
FROM [marketplace].[VehicleListing] AS l
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = l.[vehicle_id]
JOIN [core].[Customer] AS c ON c.[display_name] = N'Synthetic Customer Beta'
JOIN [core].[Employee] AS e ON e.[employee_code] = 'EMP-SYN-003'
WHERE v.[vin] = 'SYNVIN00000000001' AND l.[listed_at] = CONVERT(datetime2(0), '2026-01-08T09:00:00')
  AND NOT EXISTS (SELECT 1 FROM [marketplace].[CustomerEnquiry] AS en WHERE en.[listing_id] = l.[listing_id] AND en.[customer_id] = c.[customer_id] AND en.[received_at] = CONVERT(datetime2(0), '2026-01-08T10:00:00'));

INSERT INTO [marketplace].[VehicleReservation] ([listing_id], [customer_id], [created_at], [expires_at], [status], [released_at])
SELECT l.[listing_id], c.[customer_id], CONVERT(datetime2(0), '2026-01-09T09:00:00'), CONVERT(datetime2(0), '2026-01-12T09:00:00'), 'CONVERTED', CONVERT(datetime2(0), '2026-01-09T09:10:00')
FROM [marketplace].[VehicleListing] AS l
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = l.[vehicle_id]
JOIN [core].[Customer] AS c ON c.[display_name] = N'Synthetic Customer Beta'
WHERE v.[vin] = 'SYNVIN00000000001' AND l.[listed_at] = CONVERT(datetime2(0), '2026-01-08T09:00:00')
  AND NOT EXISTS (SELECT 1 FROM [marketplace].[VehicleReservation] AS r WHERE r.[listing_id] = l.[listing_id] AND r.[customer_id] = c.[customer_id] AND r.[created_at] = CONVERT(datetime2(0), '2026-01-09T09:00:00'));

INSERT INTO [sales].[SalesOrder] ([buyer_customer_id], [created_at], [status], [currency_code], [confirmed_at])
SELECT c.[customer_id], CONVERT(datetime2(0), '2026-01-09T09:15:00'), 'CONFIRMED', 'INR', CONVERT(datetime2(0), '2026-01-09T09:15:00')
FROM [core].[Customer] AS c
WHERE c.[display_name] = N'Synthetic Customer Beta'
  AND NOT EXISTS (SELECT 1 FROM [sales].[SalesOrder] AS o WHERE o.[buyer_customer_id] = c.[customer_id] AND o.[created_at] = CONVERT(datetime2(0), '2026-01-09T09:15:00'));

INSERT INTO [sales].[SalesOrderItem] ([order_id], [vehicle_id], [reservation_id], [sale_price], [currency_code])
SELECT o.[order_id], v.[vehicle_id], r.[reservation_id], 890000.00, 'INR'
FROM [sales].[SalesOrder] AS o
JOIN [core].[Customer] AS buyer ON buyer.[customer_id] = o.[buyer_customer_id]
JOIN [vehicle].[Vehicle] AS v ON v.[vin] = 'SYNVIN00000000001'
JOIN [marketplace].[VehicleListing] AS l ON l.[vehicle_id] = v.[vehicle_id] AND l.[listed_at] = CONVERT(datetime2(0), '2026-01-08T09:00:00')
JOIN [marketplace].[VehicleReservation] AS r ON r.[listing_id] = l.[listing_id] AND r.[customer_id] = buyer.[customer_id] AND r.[created_at] = CONVERT(datetime2(0), '2026-01-09T09:00:00')
WHERE buyer.[display_name] = N'Synthetic Customer Beta' AND o.[created_at] = CONVERT(datetime2(0), '2026-01-09T09:15:00')
  AND NOT EXISTS (SELECT 1 FROM [sales].[SalesOrderItem] AS oi WHERE oi.[order_id] = o.[order_id] AND oi.[vehicle_id] = v.[vehicle_id]);

UPDATE [marketplace].[VehicleListing]
SET [status] = 'PAUSED'
WHERE [vehicle_id] = (SELECT [vehicle_id] FROM [vehicle].[Vehicle] WHERE [vin] = 'SYNVIN00000000001')
  AND [listed_at] = CONVERT(datetime2(0), '2026-01-08T09:00:00') AND [status] = 'ACTIVE';
UPDATE [inventory].[Inventory]
SET [status] = 'HELD'
WHERE [vehicle_id] = (SELECT [vehicle_id] FROM [vehicle].[Vehicle] WHERE [vin] = 'SYNVIN00000000001')
  AND [status] = 'AVAILABLE';
UPDATE [vehicle].[Vehicle]
SET [lifecycle_status] = 'RESERVED'
WHERE [vin] = 'SYNVIN00000000001' AND [lifecycle_status] = 'IN_STOCK';

INSERT INTO [finance].[Payment] ([order_id], [provider_code], [provider_reference], [payment_method_code], [amount], [currency_code], [status], [initiated_at], [settled_at])
SELECT o.[order_id], 'SYNTHETIC_PROVIDER', 'SYN-PAY-0001', 'UPI', 890000.00, 'INR', 'SUCCEEDED', CONVERT(datetime2(0), '2026-01-09T09:20:00'), CONVERT(datetime2(0), '2026-01-09T09:21:00')
FROM [sales].[SalesOrder] AS o
JOIN [core].[Customer] AS c ON c.[customer_id] = o.[buyer_customer_id]
WHERE c.[display_name] = N'Synthetic Customer Beta' AND o.[created_at] = CONVERT(datetime2(0), '2026-01-09T09:15:00')
  AND NOT EXISTS (SELECT 1 FROM [finance].[Payment] AS p WHERE p.[provider_code] = 'SYNTHETIC_PROVIDER' AND p.[provider_reference] = 'SYN-PAY-0001');

INSERT INTO [finance].[Refund] ([payment_id], [provider_reference], [amount], [currency_code], [status], [requested_at])
SELECT p.[payment_id], 'SYN-REF-0001', 1000.00, 'INR', 'PENDING', CONVERT(datetime2(0), '2026-01-10T09:00:00')
FROM [finance].[Payment] AS p
WHERE p.[provider_code] = 'SYNTHETIC_PROVIDER' AND p.[provider_reference] = 'SYN-PAY-0001'
  AND NOT EXISTS (SELECT 1 FROM [finance].[Refund] AS r WHERE r.[provider_reference] = 'SYN-REF-0001');

INSERT INTO [delivery].[OwnershipTransfer] ([order_item_id], [from_customer_id], [to_customer_id], [status], [submitted_at], [authority_reference])
SELECT oi.[order_item_id], seller.[customer_id], buyer.[customer_id], 'SUBMITTED', CONVERT(datetime2(0), '2026-01-10T10:00:00'), 'SYN-TRANSFER-0001'
FROM [sales].[SalesOrderItem] AS oi
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = oi.[vehicle_id]
JOIN [sales].[SalesOrder] AS o ON o.[order_id] = oi.[order_id]
JOIN [core].[Customer] AS buyer ON buyer.[customer_id] = o.[buyer_customer_id]
JOIN [core].[Customer] AS seller ON seller.[display_name] = N'Synthetic Customer Alpha'
WHERE v.[vin] = 'SYNVIN00000000001' AND buyer.[display_name] = N'Synthetic Customer Beta'
  AND NOT EXISTS (SELECT 1 FROM [delivery].[OwnershipTransfer] AS t WHERE t.[authority_reference] = 'SYN-TRANSFER-0001');

INSERT INTO [delivery].[VehicleDelivery] ([order_item_id], [recipient_customer_id], [branch_id], [delivery_address_id], [scheduled_at], [status], [handover_reference])
SELECT oi.[order_item_id], buyer.[customer_id], b.[branch_id], a.[address_id], CONVERT(datetime2(0), '2026-01-14T10:00:00'), 'SCHEDULED', 'SYN-HANDOVER-0001'
FROM [sales].[SalesOrderItem] AS oi
JOIN [vehicle].[Vehicle] AS v ON v.[vehicle_id] = oi.[vehicle_id]
JOIN [sales].[SalesOrder] AS o ON o.[order_id] = oi.[order_id]
JOIN [core].[Customer] AS buyer ON buyer.[customer_id] = o.[buyer_customer_id]
JOIN [core].[CustomerAddress] AS a ON a.[customer_id] = buyer.[customer_id] AND a.[address_line1] = N'Synthetic address B'
JOIN [core].[Branch] AS b ON b.[branch_code] = 'HYD-CEN'
WHERE v.[vin] = 'SYNVIN00000000001'
  AND NOT EXISTS (SELECT 1 FROM [delivery].[VehicleDelivery] AS d WHERE d.[handover_reference] = 'SYN-HANDOVER-0001');

COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* Expected counts on a clean database: 8 cities and branches, 4 employees and
   roles, 3 customers/contacts/addresses, 8 brands, 7 models, 4 variants, and
   3 vehicle, registration, ownership, submission, inspection, report, and
   valuation rows; 9 inspection items; one defect; and one linked row for each
   later lifecycle relation. Synthetic names/references only. */

GO

/* END SOURCE: 10_seed_reference_data.sql */

/* BEGIN SOURCE: 11_post_execution_validation.sql */

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
/* Run after setup. Expected implementation: 10 schemas, 34 tables, 34 PKs,
   62 FKs, 19 unique constraints, 79 checks, 8 defaults, and 113 indexes.
   Outputs are grouped by validation area for SSMS review. */
SELECT DB_ID(N'CARS24DataModelingSystem') AS database_id,
       CASE WHEN DB_ID(N'CARS24DataModelingSystem') IS NULL THEN N'MISSING' ELSE N'PRESENT' END AS database_status;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

USE [CARS24DataModelingSystem];

GO

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1
BEGIN
    BEGIN TRY
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
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;
        THROW;
    END CATCH;
END;

GO

/* END SOURCE: 11_post_execution_validation.sql */

EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = NULL;
GO