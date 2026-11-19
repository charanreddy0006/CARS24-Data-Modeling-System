USE [CARS24DataModelingSystem];
GO

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
GO
