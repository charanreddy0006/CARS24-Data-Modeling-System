USE [CARS24DataModelingSystem];
GO

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
GO

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
GO

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
GO

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
GO
