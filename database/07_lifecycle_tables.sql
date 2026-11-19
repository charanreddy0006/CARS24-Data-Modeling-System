USE [CARS24DataModelingSystem];
GO

/* Remaining finalized Day 1 relations. Parent relations are created in 01–06. */
IF SCHEMA_ID(N'inspection') IS NULL EXEC(N'CREATE SCHEMA [inspection]');
IF SCHEMA_ID(N'acquisition') IS NULL EXEC(N'CREATE SCHEMA [acquisition]');
IF SCHEMA_ID(N'inventory') IS NULL EXEC(N'CREATE SCHEMA [inventory]');
IF SCHEMA_ID(N'marketplace') IS NULL EXEC(N'CREATE SCHEMA [marketplace]');
IF SCHEMA_ID(N'sales') IS NULL EXEC(N'CREATE SCHEMA [sales]');
IF SCHEMA_ID(N'finance') IS NULL EXEC(N'CREATE SCHEMA [finance]');
IF SCHEMA_ID(N'delivery') IS NULL EXEC(N'CREATE SCHEMA [delivery]');
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO

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
GO
