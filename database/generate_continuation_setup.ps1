param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '00_continue_database_setup.sql')
)

$ErrorActionPreference = 'Stop'
$sourceFiles = @(
    '02_create_schemas.sql',
    '03_reference_tables.sql',
    '04_core_tables.sql',
    '05_vehicle_catalog.sql',
    '06_vehicle_identity.sql',
    '07_lifecycle_tables.sql',
    '08_constraints.sql',
    '09_indexes.sql',
    '10_seed_reference_data.sql',
    '11_post_execution_validation.sql'
)

$blocks = [System.Collections.Generic.List[string]]::new()
$blocks.Add('/* GENERATED FILE. Regenerate with generate_continuation_setup.ps1. */')
$blocks.Add('/* Continues an existing database; it never creates, drops, or overwrites the database. */')
$blocks.Add('USE [master];')
$blocks.Add('GO')
$blocks.Add(@'
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
'@)
$blocks.Add('GO')

foreach ($fileName in $sourceFiles) {
    $path = Join-Path $PSScriptRoot $fileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required source script is missing: $path"
    }

    $blocks.Add("/* BEGIN SOURCE: $fileName */")
    $content = Get-Content -LiteralPath $path -Raw
    $batches = [regex]::Split($content, '(?im)^\s*GO\s*(?:--[^\r\n]*)?\s*$')
    foreach ($batch in $batches) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $trimmed = $batch.Trim()
        if ($trimmed -match '(?is)^USE\s+\[[^]]+\]\s*;?\s*$') {
            # Context switches are harmless if the gate is closed. Every
            # database-changing or validation batch is guarded below.
            $blocks.Add($trimmed)
        }
        elseif ([string]::IsNullOrWhiteSpace([regex]::Replace([regex]::Replace($trimmed, '(?s)/\*.*?\*/', ''), '(?m)--.*$', ''))) {
            # A comments-only source batch has no executable statement for
            # BEGIN TRY to contain. Preserve its documentation as a plain batch.
            $blocks.Add($trimmed)
        }
        else {
            $blocks.Add("IF TRY_CONVERT(bit, SESSION_CONTEXT(N'CARS24_Day2_Continue_Gate')) = 1`r`nBEGIN`r`n    BEGIN TRY`r`n$trimmed`r`n    END TRY`r`n    BEGIN CATCH`r`n        EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = 0;`r`n        THROW;`r`n    END CATCH;`r`nEND;")
        }
        $blocks.Add('GO')
    }
    $blocks.Add("/* END SOURCE: $fileName */")
}

$blocks.Add("EXEC sys.sp_set_session_context @key = N'CARS24_Day2_Continue_Gate', @value = NULL;`r`nGO")

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$outputText = [regex]::Replace(($blocks -join "`r`n`r`n"), '(?m)[ \t]+$', '')
$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($resolvedOutput, $outputText, $encoding)
Write-Output "Generated $resolvedOutput from $($sourceFiles.Count) continuation source SQL files."
