USE [CARS24DataModelingSystem];
GO

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
GO

/* Expected counts on a clean database: 8 cities and branches, 4 employees and
   roles, 3 customers/contacts/addresses, 8 brands, 7 models, 4 variants, and
   3 vehicle, registration, ownership, submission, inspection, report, and
   valuation rows; 9 inspection items; one defect; and one linked row for each
   later lifecycle relation. Synthetic names/references only. */
