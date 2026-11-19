USE [CARS24DataModelingSystem];
GO

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
GO

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
GO

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
GO
