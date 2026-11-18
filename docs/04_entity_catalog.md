# Entity Catalog

The catalog evaluates the proposed candidates. **Core** means finalized for this Day 1 lifecycle; **extension** means intentionally excluded from the initial relational model. Keys are logical identifiers; physical types are deferred. Entity classes: master, reference, transaction, associative/detail, or history.

| Candidate / decision | Purpose and reason | Key; important attributes | Relationships; class; scope |
|---|---|---|---|
| Customer — retain | One person identity may buy and sell. | PK CustomerID; display/legal name, status, created time. | 1:M contacts, addresses, submissions, enquiries, reservations, orders; master; Core. |
| CustomerAddress — retain | Dated postal/service addresses. | PK AddressID; customer, lines, city, postal code, validity, type. | M:1 Customer and City; history/master; Core. |
| CustomerContact — retain | Multiple email/phone channels and verification state. | PK ContactID; customer, type, value, verified, validity. | M:1 Customer; master/history; Core. |
| City — retain | Location reference for branches and addresses. | PK CityID; name, state code, country code. | 1:M Branch/Address; reference; Core. |
| Branch — retain | Operational site and inventory location. | PK BranchID; CityID, code, name, address summary, status. | M:1 City; 1:M Employee/Inventory; master; Core. |
| Employee — retain | Staff identity for assignment and attribution. | PK EmployeeID; branch, employee code, name, active dates. | M:1 Branch; 1:M assigned work; master; Core. |
| EmployeeRole — retain as assignment | Role definitions and employee-role assignment, with effective dates. | PK EmployeeRoleID; EmployeeID, role code, dates. | M:1 Employee; associative/history; Core. |
| VehicleBrand — retain | Normalized manufacturer reference. | PK BrandID; name. | 1:M VehicleModel; reference; Core. |
| VehicleModel — retain | Manufacturer model reference. | PK ModelID; BrandID, model name. | M:1 Brand; 1:M Variant/Vehicle; reference; Core. |
| VehicleVariant — retain | Optional trim/variant reference. | PK VariantID; ModelID, variant name, year range. | M:1 Model; reference; Core. |
| FuelType — merge | Candidate is a small controlled value; represent as `fuel_type_code` reference value in catalog model. | Code/name. | Vehicle attribute; reference; Core value set, not separate table. |
| TransmissionType — merge | Same treatment as fuel type. | Code/name. | Vehicle attribute; reference; Core value set. |
| Vehicle — retain | Stable identity and present lifecycle state. | PK VehicleID; model/variant, manufacture year, VIN/chassis, engine no., fuel/transmission, current owner, state. | Links to all lifecycle history; master; Core. |
| VehicleRegistration — retain | Effective-dated registration identifier(s). | PK RegistrationID; VehicleID, registration no., state, validity. | M:1 Vehicle; history; Core. |
| VehicleOwnershipHistory — retain | Effective-dated chain of owners. | PK OwnershipHistoryID; VehicleID, CustomerID, from/to, basis/reference. | M:1 Vehicle and Customer; history; Core. |
| VehicleSubmission — add | Records seller's intake request independent of vehicle identity and acquisition. | PK SubmissionID; vehicle, submitter, branch, submitted time, status/reason. | M:1 Vehicle/Customer; transaction; Core. |
| Inspection — retain | Appointment and inspection event. | PK InspectionID; vehicle, submission, inspector, scheduled/completed time, status. | M:1 Vehicle; 1:0..1 report; transaction; Core. |
| InspectionReport — retain | Finalized inspection conclusion. | PK ReportID; unique InspectionID, outcome, summary, finalized time. | 1:1 Inspection; transaction; Core. |
| InspectionItem — retain as result | Checklist result per report and checklist code; not the reusable template itself. | PK InspectionItemID; report, item code, outcome, note. | M:1 report; associative/detail; Core. |
| Defect — retain | Observed issue tied to a report/item. | PK DefectID; report/item, category, severity, description, estimate. | M:1 report, optional item; transaction; Core. |
| VehicleValuation — retain | Dated valuation snapshot. | PK ValuationID; vehicle, report, assessor, amount, currency, basis, time. | M:1 vehicle/report; transaction/history; Core. |
| PurchaseOffer — retain | Seller-facing proposed purchase terms and decision history. | PK OfferID; submission, valuation, seller, amount/currency, issued/expiry, status. | M:1 submission/valuation/customer; transaction; Core. |
| PurchaseAgreement — retain | Executed purchase terms/evidence reference. | PK AgreementID; offer, seller, signed time, reference, status. | M:1 offer/seller; transaction; Core. |
| VehicleAcquisition — retain | Completed transfer into marketplace/company custody. | PK AcquisitionID; unique agreement, vehicle, seller, amount/currency/date. | 1:1 agreement; M:1 vehicle/seller; transaction; Core. |
| Inventory — retain | Current inventory position per vehicle. | PK InventoryID; unique vehicle, branch, location code, status, since. | 1:1 current Vehicle; 1:M movement; master/current state; Core. |
| InventoryMovement — retain | Append-only custody/location events. | PK MovementID; inventory, from/to branch/location, type, actor, time, reason. | M:1 inventory/employee; history; Core. |
| VehicleListing — retain | Marketplace listing and publication lifecycle. | PK ListingID; vehicle, branch, price/currency, status, publication/closure times. | M:1 vehicle/branch; 1:M image/enquiry; history/transaction; Core. |
| ListingImage — retain as metadata | Image reference, ordering, caption; binary storage excluded. | PK ListingImageID; listing, URI/reference, position. | M:1 listing; detail; Core. |
| CustomerEnquiry — retain | Buyer contact about a listing. | PK EnquiryID; listing, customer, channel, time, status, assigned employee. | M:1 listing/customer; transaction; Core. |
| VehicleReservation — retain | Time-bounded exclusive hold on listing/vehicle. | PK ReservationID; listing, customer, start/expiry, status, converted order. | M:1 listing/customer; optional order; transaction; Core. |
| SalesOrder — retain | Buyer commercial transaction. | PK OrderID; buyer, status, currency, totals, dates. | 1:M order items/payments; transfer/delivery; transaction; Core. |
| SalesOrderItem — retain | Vehicle-level order detail. | PK OrderItemID; order, vehicle, price/currency; unique vehicle/order. | M:1 order/vehicle; associative/detail; Core. |
| Payment — retain | Payment attempt/capture/reversal record tied to order. | PK PaymentID; order, provider reference, amount/currency, status, timestamps. | M:1 order; 1:M refunds; transaction; Core. |
| Refund — retain | Refund attempt/event against payment. | PK RefundID; payment, amount/currency, provider ref, status, time. | M:1 payment; transaction; Core. |
| LoanApplication — exclude | Financing underwriting is out of stated core lifecycle; payment can be recorded without modeling lender decisioning. | Would require applicant/lender/status/decision data. | Potential M:1 order/customer; extension. |
| OwnershipTransfer — retain | Administrative title-transfer tracking. | PK TransferID; order item, from/to customer, status, submitted/completed time, authority ref. | M:1 order item and customers; transaction/history; Core. |
| VehicleDelivery — retain | Handover planning and outcome. | PK DeliveryID; order item, recipient, branch/address, schedule, result/time. | M:1 order item/customer/branch; transaction; Core. |

## Candidate consolidation and additions

Customer roles are not separate Buyer/Seller entities. InspectionReport is the finalized outcome, while InspectionItem stores checklist results; no duplicate report-detail object is needed. `Defect` is an observed exception and does not duplicate checklist rows. FuelType and TransmissionType remain controlled reference domains but are codes in this core model to avoid two one-column reference tables; a physical implementation may promote them if governance requires. VehicleSubmission was added because submission is a process event, not a property of the enduring vehicle. LoanApplication is excluded pending financing scope. Listing and reservation rows are retained as history rather than overwriting one current row.

All finalized entities above are mandatory for the selected complete lifecycle except optional child/event records such as contact alternatives, address alternatives, variant, inspection report before completion, defects, images, enquiries, refunds, transfer and delivery during their respective stages.
