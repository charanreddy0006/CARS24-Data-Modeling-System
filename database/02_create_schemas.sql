USE [CARS24DataModelingSystem];
GO

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
GO
