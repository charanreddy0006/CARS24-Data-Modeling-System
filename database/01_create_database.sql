/* Create the educational project database. Run with a SQL Server login that
   has CREATE DATABASE permission. No server settings are changed. */
IF DB_ID(N'CARS24DataModelingSystem') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [CARS24DataModelingSystem]');
END;
GO

/* Recommended for deployment: review recovery model, compatibility level,
   file placement, backup policy, and collation with the DBA. This script
   intentionally does not change those server/database settings. */
