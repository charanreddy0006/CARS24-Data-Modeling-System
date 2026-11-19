/* New-database preflight for 00_run_complete_database_setup.sql.
   For an existing target database, use 00_continue_database_setup.sql. */
USE [master];
GO
SET NOCOUNT ON;

DECLARE @targetDatabaseId int = DB_ID(N'CARS24DataModelingSystem');
DECLARE @majorVersion int = TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));
DECLARE @createDatabasePermission bit = COALESCE(HAS_PERMS_BY_NAME(NULL, N'SERVER', N'CREATE ANY DATABASE'), 0);
DECLARE @onlineWritable bit = CASE WHEN EXISTS
(
    SELECT 1 FROM sys.databases
    WHERE [database_id] = @targetDatabaseId
      AND [state_desc] = N'ONLINE'
      AND [is_read_only] = 0
      AND [compatibility_level] >= 110
) THEN 1 ELSE 0 END;
DECLARE @metadataVisible bit = CASE
    WHEN @targetDatabaseId IS NULL THEN 1
    ELSE COALESCE(HAS_PERMS_BY_NAME(N'CARS24DataModelingSystem', N'DATABASE', N'VIEW DEFINITION'), 0)
END;
DECLARE @ready bit = CASE
    WHEN COALESCE(@majorVersion, 0) >= 17
     AND @targetDatabaseId IS NULL
     AND @createDatabasePermission = 1 THEN 1 ELSE 0 END;

SELECT CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) AS server_name,
       CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS product_version,
       @majorVersion AS product_major_version,
       CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS edition,
       TRY_CONVERT(int, SERVERPROPERTY('EngineEdition')) AS engine_edition,
       DB_NAME() AS current_database;

SELECT N'CARS24DataModelingSystem' AS target_database_name,
       CASE WHEN @targetDatabaseId IS NULL THEN N'MISSING' ELSE N'EXISTS' END AS existence_status,
       d.[state_desc], d.[is_read_only], d.[compatibility_level],
       @onlineWritable AS online_writable_compatible,
       @metadataVisible AS metadata_visible,
       @createDatabasePermission AS can_create_database
FROM (VALUES (1)) AS seed(n)
LEFT JOIN sys.databases AS d ON d.[database_id] = @targetDatabaseId;

SELECT CASE WHEN @ready = 1 THEN N'READY' ELSE N'NOT READY' END AS pre_execution_status,
       CASE
           WHEN COALESCE(@majorVersion, 0) < 17 THEN N'SQL Server 2025 (major version 17) or newer is required.'
           WHEN @targetDatabaseId IS NOT NULL THEN N'The target already exists. Do not run the new-database master; inspect using 00_continue_database_setup.sql.'
           WHEN @createDatabasePermission = 0 THEN N'CREATE ANY DATABASE server permission is required for the new-database master.'
           ELSE N'New-database prerequisites passed.'
       END AS detail;
GO
