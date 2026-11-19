USE [CARS24DataModelingSystem];
GO

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
