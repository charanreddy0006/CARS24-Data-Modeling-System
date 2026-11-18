# Data Dictionary

Logical types and key abbreviations: `ID` identifier; `Text`; `Code`; `Bool`; `Date`; `Timestamp` (UTC instant); `Int`; `Decimal`/`Amount`; `Currency`; `URI`. `PK`, `FK`, `UQ` identify key role; `—` is not a key. `Y/N` under Nullable means nullable. Attribute sets below are complete; refer to [logical model](06_logical_data_model.md) for constraints and relationship details.

| Entity | Attribute | Description | Logical Type | PK/FK | Nullable |
|---|---|---|---|---|---|
| City | city_id | Stable city identifier | ID | PK | N |
| City | city_name | City name | Text | — | N |
| City | state_code | State/UT code | Code | — | N |
| City | country_code | Country code; default IN | Code | — | N |
| Branch | branch_id | Branch identifier | ID | PK | N |
| Branch | city_id | Branch city | ID | FK City | N |
| Branch | branch_code | Business branch code | Code | UQ | N |
| Branch | branch_name | Display name | Text | — | N |
| Branch | address_text | Branch address summary | Text | — | Y |
| Branch | status | Operating state | Code | — | N |
| Employee | employee_id | Employee identifier | ID | PK | N |
| Employee | branch_id | Assigned branch | ID | FK Branch | N |
| Employee | employee_code | Workforce identifier | Code | UQ | N |
| Employee | display_name | Staff display name | Text | — | N |
| Employee | active_from | Employment active date | Date | — | N |
| Employee | active_to | Employment end date | Date | — | Y |
| EmployeeRole | employee_role_id | Assignment identifier | ID | PK | N |
| EmployeeRole | employee_id | Assigned employee | ID | FK Employee | N |
| EmployeeRole | role_code | Controlled business role | Code | — | N |
| EmployeeRole | valid_from | Assignment start | Timestamp | — | N |
| EmployeeRole | valid_to | Assignment end | Timestamp | — | Y |
| Customer | customer_id | Person identifier | ID | PK | N |
| Customer | display_name | Preferred name | Text | — | N |
| Customer | legal_name | Legal name when needed | Text | — | Y |
| Customer | status | Customer account state | Code | — | N |
| Customer | created_at | Registration instant | Timestamp | — | N |
| CustomerContact | contact_id | Contact record identifier | ID | PK | N |
| CustomerContact | customer_id | Contact owner | ID | FK Customer | N |
| CustomerContact | contact_type | Phone/email/etc. | Code | — | N |
| CustomerContact | contact_value | Contact value | Text | — | N |
| CustomerContact | is_verified | Verification flag | Bool | — | N |
| CustomerContact | valid_from | Start of validity | Timestamp | — | N |
| CustomerContact | valid_to | End of validity | Timestamp | — | Y |
| CustomerAddress | address_id | Address record identifier | ID | PK | N |
| CustomerAddress | customer_id | Address owner | ID | FK Customer | N |
| CustomerAddress | city_id | Address city | ID | FK City | N |
| CustomerAddress | address_type | Home, delivery, etc. | Code | — | N |
| CustomerAddress | address_line1 | Primary address line | Text | — | N |
| CustomerAddress | address_line2 | Additional line | Text | — | Y |
| CustomerAddress | postal_code | Postal/PIN code | Code | — | N |
| CustomerAddress | valid_from | Start of validity | Timestamp | — | N |
| CustomerAddress | valid_to | End of validity | Timestamp | — | Y |
| VehicleBrand | brand_id | Brand identifier | ID | PK | N |
| VehicleBrand | brand_name | Manufacturer name | Text | UQ | N |
| VehicleModel | model_id | Model identifier | ID | PK | N |
| VehicleModel | brand_id | Manufacturer reference | ID | FK VehicleBrand | N |
| VehicleModel | model_name | Model name | Text | UQ with brand | N |
| VehicleVariant | variant_id | Variant identifier | ID | PK | N |
| VehicleVariant | model_id | Parent model | ID | FK VehicleModel | N |
| VehicleVariant | variant_name | Trim/variant name | Text | UQ with model | N |
| Vehicle | vehicle_id | Stable vehicle identifier | ID | PK | N |
| Vehicle | model_id | Catalog model | ID | FK VehicleModel | N |
| Vehicle | variant_id | Optional catalog variant | ID | FK VehicleVariant | Y |
| Vehicle | manufacture_year | Year manufactured | Int | CK | N |
| Vehicle | vin | VIN/chassis identity where available | Code | UQ when present | Y |
| Vehicle | engine_number | Engine identifier | Code | — | Y |
| Vehicle | fuel_type_code | Controlled fuel code | Code | — | N |
| Vehicle | transmission_type_code | Controlled transmission code | Code | — | N |
| Vehicle | current_owner_customer_id | Current registered owner | ID | FK Customer | N |
| Vehicle | lifecycle_status | Current lifecycle state | Code | — | N |
| Vehicle | created_at | Vehicle record creation instant | Timestamp | — | N |
| VehicleRegistration | registration_id | Registration record identifier | ID | PK | N |
| VehicleRegistration | vehicle_id | Registered vehicle | ID | FK Vehicle | N |
| VehicleRegistration | registration_number | Issued registration number | Code | UQ with valid_from | N |
| VehicleRegistration | issuing_state_code | Issuing state/UT | Code | — | N |
| VehicleRegistration | valid_from | Registration start | Date | — | N |
| VehicleRegistration | valid_to | Registration end | Date | — | Y |
| VehicleOwnershipHistory | ownership_history_id | Ownership interval identifier | ID | PK | N |
| VehicleOwnershipHistory | vehicle_id | Vehicle owned | ID | FK Vehicle | N |
| VehicleOwnershipHistory | customer_id | Owner during interval | ID | FK Customer | N |
| VehicleOwnershipHistory | valid_from | Ownership start | Timestamp | — | N |
| VehicleOwnershipHistory | valid_to | Ownership end | Timestamp | — | Y |
| VehicleOwnershipHistory | basis_code | Ownership basis/role | Code | — | N |
| VehicleOwnershipHistory | evidence_reference | Supporting evidence reference | Text | — | Y |
| VehicleSubmission | submission_id | Intake attempt identifier | ID | PK | N |
| VehicleSubmission | vehicle_id | Submitted vehicle | ID | FK Vehicle | N |
| VehicleSubmission | seller_customer_id | Submitting seller | ID | FK Customer | N |
| VehicleSubmission | branch_id | Intake branch | ID | FK Branch | N |
| VehicleSubmission | submitted_at | Submission instant | Timestamp | — | N |
| VehicleSubmission | status | Submission state | Code | — | N |
| VehicleSubmission | closed_at | Closure instant | Timestamp | — | Y |
| VehicleSubmission | outcome_reason | Closure reason | Text | — | Y |
| Inspection | inspection_id | Inspection event identifier | ID | PK | N |
| Inspection | vehicle_id | Inspected vehicle | ID | FK Vehicle | N |
| Inspection | submission_id | Related intake, if any | ID | FK VehicleSubmission | Y |
| Inspection | inspector_employee_id | Assigned inspector | ID | FK Employee | Y |
| Inspection | scheduled_at | Appointment instant | Timestamp | — | N |
| Inspection | completed_at | Completion instant | Timestamp | — | Y |
| Inspection | status | Appointment/event state | Code | — | N |
| InspectionReport | report_id | Final report identifier | ID | PK | N |
| InspectionReport | inspection_id | Inspected event | ID | FK Inspection, UQ | N |
| InspectionReport | outcome_code | Final outcome | Code | — | N |
| InspectionReport | summary | Findings summary | Text | — | Y |
| InspectionReport | finalized_at | Report finalization instant | Timestamp | — | N |
| InspectionItem | inspection_item_id | Checklist result identifier | ID | PK | N |
| InspectionItem | report_id | Parent report | ID | FK InspectionReport | N |
| InspectionItem | item_code | Checklist criterion | Code | UQ with report | N |
| InspectionItem | outcome_code | Criterion result | Code | — | N |
| InspectionItem | note | Inspector note | Text | — | Y |
| Defect | defect_id | Defect identifier | ID | PK | N |
| Defect | report_id | Parent report | ID | FK InspectionReport | N |
| Defect | inspection_item_id | Related checklist result | ID | FK InspectionItem | Y |
| Defect | category_code | Defect category | Code | — | N |
| Defect | severity_code | Severity | Code | — | N |
| Defect | description | Observed issue | Text | — | N |
| Defect | repair_estimate | Estimated repair amount | Amount | — | Y |
| Defect | currency_code | Currency for estimate | Currency | — | Y |
| VehicleValuation | valuation_id | Valuation identifier | ID | PK | N |
| VehicleValuation | vehicle_id | Valued vehicle | ID | FK Vehicle | N |
| VehicleValuation | report_id | Assessment basis report | ID | FK InspectionReport | Y |
| VehicleValuation | assessor_employee_id | Valuation staff member | ID | FK Employee | N |
| VehicleValuation | valued_at | Valuation instant | Timestamp | — | N |
| VehicleValuation | amount | Estimated value | Amount | CK >= 0 | N |
| VehicleValuation | currency_code | Valuation currency; default INR | Currency | — | N |
| VehicleValuation | basis | Basis/notes | Text | — | N |
| VehicleValuation | status | Review state | Code | — | N |
| PurchaseOffer | offer_id | Offer identifier | ID | PK | N |
| PurchaseOffer | submission_id | Seller intake | ID | FK VehicleSubmission | N |
| PurchaseOffer | valuation_id | Supporting valuation | ID | FK VehicleValuation | N |
| PurchaseOffer | seller_customer_id | Offer recipient | ID | FK Customer | N |
| PurchaseOffer | offered_at | Issue instant | Timestamp | — | N |
| PurchaseOffer | expires_at | Expiration instant | Timestamp | — | N |
| PurchaseOffer | amount | Offered amount | Amount | CK >= 0 | N |
| PurchaseOffer | currency_code | Offer currency; default INR | Currency | — | N |
| PurchaseOffer | status | Offer state | Code | — | N |
| PurchaseOffer | decision_at | Seller decision instant | Timestamp | — | Y |
| PurchaseAgreement | agreement_id | Agreement identifier | ID | PK | N |
| PurchaseAgreement | offer_id | Offer accepted | ID | FK PurchaseOffer | N |
| PurchaseAgreement | seller_customer_id | Agreement seller | ID | FK Customer | N |
| PurchaseAgreement | agreement_reference | Agreement business reference | Code | UQ | N |
| PurchaseAgreement | signed_at | Signing instant | Timestamp | — | N |
| PurchaseAgreement | status | Agreement state | Code | — | N |
| VehicleAcquisition | acquisition_id | Acquisition event identifier | ID | PK | N |
| VehicleAcquisition | agreement_id | Executed agreement | ID | FK PurchaseAgreement, UQ | N |
| VehicleAcquisition | vehicle_id | Acquired vehicle | ID | FK Vehicle | N |
| VehicleAcquisition | seller_customer_id | Transferor | ID | FK Customer | N |
| VehicleAcquisition | acquired_at | Acquisition instant | Timestamp | — | N |
| VehicleAcquisition | amount | Acquisition consideration | Amount | CK >= 0 | N |
| VehicleAcquisition | currency_code | Acquisition currency | Currency | — | N |
| Inventory | inventory_id | Current stock position identifier | ID | PK | N |
| Inventory | vehicle_id | Stock vehicle | ID | FK Vehicle, UQ | N |
| Inventory | branch_id | Current branch | ID | FK Branch | N |
| Inventory | location_code | Current local location | Code | — | N |
| Inventory | status | Stock/hold state | Code | — | N |
| Inventory | since_at | Current placement instant | Timestamp | — | N |
| InventoryMovement | movement_id | Movement event identifier | ID | PK | N |
| InventoryMovement | inventory_id | Moved inventory record | ID | FK Inventory | N |
| InventoryMovement | from_branch_id | Origin branch | ID | FK Branch | Y |
| InventoryMovement | from_location_code | Origin location | Code | — | Y |
| InventoryMovement | to_branch_id | Destination branch | ID | FK Branch | Y |
| InventoryMovement | to_location_code | Destination location | Code | — | Y |
| InventoryMovement | movement_type | Receipt/transfer/dispatch etc. | Code | — | N |
| InventoryMovement | employee_id | Responsible employee | ID | FK Employee | Y |
| InventoryMovement | occurred_at | Event instant | Timestamp | — | N |
| InventoryMovement | reason | Event reason | Text | — | N |
| VehicleListing | listing_id | Listing identifier | ID | PK | N |
| VehicleListing | vehicle_id | Advertised vehicle | ID | FK Vehicle | N |
| VehicleListing | branch_id | Managing branch | ID | FK Branch | N |
| VehicleListing | listed_at | Publication instant | Timestamp | — | N |
| VehicleListing | closed_at | Closure instant | Timestamp | — | Y |
| VehicleListing | status | Listing state | Code | — | N |
| VehicleListing | asking_price | Advertised price | Amount | CK >= 0 | N |
| VehicleListing | currency_code | Price currency; default INR | Currency | — | N |
| VehicleListing | description | Public description | Text | — | Y |
| ListingImage | listing_image_id | Image metadata identifier | ID | PK | N |
| ListingImage | listing_id | Parent listing | ID | FK VehicleListing | N |
| ListingImage | image_reference | External asset reference | URI | — | N |
| ListingImage | display_order | Display position | Int | UQ with listing | N |
| ListingImage | caption | Image caption | Text | — | Y |
| CustomerEnquiry | enquiry_id | Enquiry identifier | ID | PK | N |
| CustomerEnquiry | listing_id | Enquired listing | ID | FK VehicleListing | N |
| CustomerEnquiry | customer_id | Interested customer | ID | FK Customer | N |
| CustomerEnquiry | assigned_employee_id | Follow-up owner | ID | FK Employee | Y |
| CustomerEnquiry | channel_code | Contact channel | Code | — | N |
| CustomerEnquiry | received_at | Enquiry instant | Timestamp | — | N |
| CustomerEnquiry | status | Follow-up state | Code | — | N |
| CustomerEnquiry | message_reference | Message content reference | Text | — | Y |
| VehicleReservation | reservation_id | Reservation identifier | ID | PK | N |
| VehicleReservation | listing_id | Reserved listing | ID | FK VehicleListing | N |
| VehicleReservation | customer_id | Requesting customer | ID | FK Customer | N |
| VehicleReservation | created_at | Reservation start | Timestamp | — | N |
| VehicleReservation | expires_at | Hold expiry | Timestamp | CK > created_at | N |
| VehicleReservation | status | Hold state | Code | — | N |
| VehicleReservation | released_at | Release/expiry instant | Timestamp | — | Y |
| SalesOrder | order_id | Sales transaction identifier | ID | PK | N |
| SalesOrder | buyer_customer_id | Purchasing customer | ID | FK Customer | N |
| SalesOrder | created_at | Order creation instant | Timestamp | — | N |
| SalesOrder | status | Order state | Code | — | N |
| SalesOrder | currency_code | Order currency; default INR | Currency | — | N |
| SalesOrder | confirmed_at | Confirmation instant | Timestamp | — | Y |
| SalesOrder | completed_at | Completion instant | Timestamp | — | Y |
| SalesOrder | cancelled_at | Cancellation instant | Timestamp | — | Y |
| SalesOrderItem | order_item_id | Order detail identifier | ID | PK | N |
| SalesOrderItem | order_id | Parent order | ID | FK SalesOrder | N |
| SalesOrderItem | vehicle_id | Vehicle sold | ID | FK Vehicle | N |
| SalesOrderItem | reservation_id | Converted reservation | ID | FK VehicleReservation, UQ | Y |
| SalesOrderItem | sale_price | Agreed sale amount | Amount | CK >= 0 | N |
| SalesOrderItem | currency_code | Sale currency | Currency | — | N |
| Payment | payment_id | Payment attempt identifier | ID | PK | N |
| Payment | order_id | Paid order | ID | FK SalesOrder | N |
| Payment | provider_code | Payment provider | Code | — | N |
| Payment | provider_reference | Idempotent external reference | Code | UQ with provider | Y |
| Payment | payment_method_code | Payment method | Code | — | N |
| Payment | amount | Attempt/captured amount | Amount | CK > 0 | N |
| Payment | currency_code | Payment currency | Currency | — | N |
| Payment | status | Attempt/reconciliation state | Code | — | N |
| Payment | initiated_at | Attempt time | Timestamp | — | N |
| Payment | settled_at | Settlement time | Timestamp | — | Y |
| Refund | refund_id | Refund attempt identifier | ID | PK | N |
| Refund | payment_id | Refunded payment | ID | FK Payment | N |
| Refund | provider_reference | External refund reference | Code | UQ when present | Y |
| Refund | amount | Refund amount | Amount | CK > 0 | N |
| Refund | currency_code | Refund currency | Currency | — | N |
| Refund | status | Refund processing state | Code | — | N |
| Refund | requested_at | Request time | Timestamp | — | N |
| Refund | settled_at | Completion time | Timestamp | — | Y |
| OwnershipTransfer | transfer_id | Transfer case identifier | ID | PK | N |
| OwnershipTransfer | order_item_id | Sold vehicle detail | ID | FK SalesOrderItem | N |
| OwnershipTransfer | from_customer_id | Current transferor | ID | FK Customer | N |
| OwnershipTransfer | to_customer_id | Buyer/transferee | ID | FK Customer | N |
| OwnershipTransfer | status | Transfer case state | Code | — | N |
| OwnershipTransfer | submitted_at | Submission time | Timestamp | — | Y |
| OwnershipTransfer | completed_at | Completion time | Timestamp | — | Y |
| OwnershipTransfer | authority_reference | Authority case/evidence | Code | — | Y |
| VehicleDelivery | delivery_id | Delivery attempt identifier | ID | PK | N |
| VehicleDelivery | order_item_id | Sold vehicle detail | ID | FK SalesOrderItem | N |
| VehicleDelivery | recipient_customer_id | Handover recipient | ID | FK Customer | N |
| VehicleDelivery | branch_id | Origin branch, if applicable | ID | FK Branch | Y |
| VehicleDelivery | delivery_address_id | Destination address, if applicable | ID | FK CustomerAddress | Y |
| VehicleDelivery | scheduled_at | Planned handover time | Timestamp | — | Y |
| VehicleDelivery | completed_at | Completed handover time | Timestamp | — | Y |
| VehicleDelivery | status | Delivery outcome/state | Code | — | N |
| VehicleDelivery | handover_reference | Signed handover evidence | Code | — | Y |

## Key fields and controlled values

All PKs are stable generated logical identifiers. Business unique identifiers include employee/branch codes, brand name, model within brand, variant within model, supplied VIN, agreement reference, provider transaction reference, and listing image order per listing. Registration number uniqueness is effective-dated, not assumed globally forever. Status fields cover customer, branch, submission, inspection, offer, agreement, inventory, listing, reservation, order, payment, refund, transfer and delivery. Datetimes include created/issued/scheduled/completed/settled/effective timestamps; date-only registration and manufacture values remain dates. Monetary values use amount + currency and INR default where described. Audit fields are event time, employee actor when applicable, reason/evidence references; a full technical created_by/updated_by standard is to be specified in physical design.
