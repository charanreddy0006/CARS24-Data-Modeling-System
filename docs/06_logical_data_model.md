# Logical Data Model

Logical types are technology-neutral: **Identifier**, **Text**, **Code**, **Boolean**, **Date**, **Timestamp**, **Integer**, **Decimal**, **Amount**, **CurrencyCode**, **URI**. `*` means mandatory; `?` means nullable. Each listed ID is a PK unless noted. Candidate uniqueness is stated explicitly. SQL Server physical types/index syntax are deferred.

## Conventions

Names use singular PascalCase entities and descriptive attributes. Statuses are controlled codes, with transitions validated by workflow. Monetary records store amount and currency; default currency is INR. `created_at`/event times are UTC instants; effective dates use half-open intervals `[from,to)`. Audit actors are employee references where a staff action occurs. No history table cascades on parent deletion.

## Relations and attributes

For compactness, every relation's complete attribute list is given below; descriptions and logical types are expanded in [data dictionary](08_data_dictionary.md). FKs use `FK→Table.Attribute`; `UQ` marks candidate unique constraints; `CK` describes logical checks.

### Organization and customer

| Table / purpose | Attributes (type; nullability; keys/constraints) |
|---|---|
| City — location reference | city_id (Identifier PK); city_name (Text*); state_code (Code*); country_code (Code* default IN); UQ(city_name,state_code,country_code). |
| Branch — operating site | branch_id (Identifier PK); city_id (Identifier* FK→City); branch_code (Code* UQ); branch_name (Text*); address_text (Text?); status (Code*). |
| Employee — staff identity | employee_id (Identifier PK); branch_id (Identifier* FK→Branch); employee_code (Code* UQ); display_name (Text*); active_from (Date*); active_to (Date?). |
| EmployeeRole — dated role assignment | employee_role_id (Identifier PK); employee_id (Identifier* FK→Employee); role_code (Code*); valid_from (Timestamp*); valid_to (Timestamp?); UQ(employee_id,role_code,valid_from). |
| Customer — person identity | customer_id (Identifier PK); display_name (Text*); legal_name (Text?); status (Code*); created_at (Timestamp*). |
| CustomerContact — contact point | contact_id (Identifier PK); customer_id (Identifier* FK→Customer); contact_type (Code*); contact_value (Text*); is_verified (Boolean* default false); valid_from (Timestamp*); valid_to (Timestamp?). UQ(customer_id,contact_type,contact_value,valid_from). |
| CustomerAddress — dated address | address_id (Identifier PK); customer_id (Identifier* FK→Customer); city_id (Identifier* FK→City); address_type (Code*); address_line1 (Text*); address_line2 (Text?); postal_code (Code*); valid_from (Timestamp*); valid_to (Timestamp?). |

### Vehicle catalog and identity

| Table / purpose | Attributes (type; nullability; keys/constraints) |
|---|---|
| VehicleBrand — manufacturer | brand_id (Identifier PK); brand_name (Text* UQ). |
| VehicleModel — model within brand | model_id (Identifier PK); brand_id (Identifier* FK→VehicleBrand); model_name (Text*); UQ(brand_id,model_name). |
| VehicleVariant — optional trim | variant_id (Identifier PK); model_id (Identifier* FK→VehicleModel); variant_name (Text*); UQ(model_id,variant_name). |
| Vehicle — enduring asset identity | vehicle_id (Identifier PK); model_id (Identifier* FK→VehicleModel); variant_id (Identifier? FK→VehicleVariant); manufacture_year (Integer*); vin (Code? UQ when supplied); engine_number (Code?); fuel_type_code (Code*); transmission_type_code (Code*); current_owner_customer_id (Identifier* FK→Customer); lifecycle_status (Code*); created_at (Timestamp*). CK(year in accepted range); variant must belong to model (APP/TX). |
| VehicleRegistration — dated registration | registration_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle); registration_number (Code*); issuing_state_code (Code*); valid_from (Date*); valid_to (Date?); UQ(registration_number,valid_from). No overlapping current registration assignment (TX). |
| VehicleOwnershipHistory — owner intervals | ownership_history_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle); customer_id (Identifier* FK→Customer); valid_from (Timestamp*); valid_to (Timestamp?); basis_code (Code*); evidence_reference (Text?); UQ(vehicle_id,valid_from); non-overlap per vehicle (TX). |
| VehicleSubmission — intake attempt | submission_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle); seller_customer_id (Identifier* FK→Customer); branch_id (Identifier* FK→Branch); submitted_at (Timestamp*); status (Code*); closed_at (Timestamp?); outcome_reason (Text?). |

### Assessment and acquisition

| Table / purpose | Attributes (type; nullability; keys/constraints) |
|---|---|
| Inspection — appointment/event | inspection_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle); submission_id (Identifier? FK→VehicleSubmission); inspector_employee_id (Identifier? FK→Employee); scheduled_at (Timestamp*); completed_at (Timestamp?); status (Code*). |
| InspectionReport — final outcome | report_id (Identifier PK); inspection_id (Identifier* FK→Inspection UQ); outcome_code (Code*); summary (Text?); finalized_at (Timestamp*). |
| InspectionItem — checklist result | inspection_item_id (Identifier PK); report_id (Identifier* FK→InspectionReport); item_code (Code*); outcome_code (Code*); note (Text?); UQ(report_id,item_code). |
| Defect — observed condition issue | defect_id (Identifier PK); report_id (Identifier* FK→InspectionReport); inspection_item_id (Identifier? FK→InspectionItem); category_code (Code*); severity_code (Code*); description (Text*); repair_estimate (Amount?); currency_code (CurrencyCode?); |
| VehicleValuation — dated estimate | valuation_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle); report_id (Identifier? FK→InspectionReport); assessor_employee_id (Identifier* FK→Employee); valued_at (Timestamp*); amount (Amount* CK >= 0); currency_code (CurrencyCode* default INR); basis (Text*); status (Code*). |
| PurchaseOffer — seller terms | offer_id (Identifier PK); submission_id (Identifier* FK→VehicleSubmission); valuation_id (Identifier* FK→VehicleValuation); seller_customer_id (Identifier* FK→Customer); offered_at (Timestamp*); expires_at (Timestamp*); amount (Amount* CK >= 0); currency_code (CurrencyCode* default INR); status (Code*); decision_at (Timestamp?); |
| PurchaseAgreement — executed terms | agreement_id (Identifier PK); offer_id (Identifier* FK→PurchaseOffer); seller_customer_id (Identifier* FK→Customer); agreement_reference (Code* UQ); signed_at (Timestamp*); status (Code*); |
| VehicleAcquisition — completed intake transfer | acquisition_id (Identifier PK); agreement_id (Identifier* FK→PurchaseAgreement UQ); vehicle_id (Identifier* FK→Vehicle); seller_customer_id (Identifier* FK→Customer); acquired_at (Timestamp*); amount (Amount* CK >= 0); currency_code (CurrencyCode*); |

### Inventory and marketplace

| Table / purpose | Attributes (type; nullability; keys/constraints) |
|---|---|
| Inventory — current position | inventory_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle UQ); branch_id (Identifier* FK→Branch); location_code (Code*); status (Code*); since_at (Timestamp*). |
| InventoryMovement — custody event | movement_id (Identifier PK); inventory_id (Identifier* FK→Inventory); from_branch_id (Identifier? FK→Branch); from_location_code (Code?); to_branch_id (Identifier? FK→Branch); to_location_code (Code?); movement_type (Code*); employee_id (Identifier? FK→Employee); occurred_at (Timestamp*); reason (Text*); |
| VehicleListing — offer to market | listing_id (Identifier PK); vehicle_id (Identifier* FK→Vehicle); branch_id (Identifier* FK→Branch); listed_at (Timestamp*); closed_at (Timestamp?); status (Code*); asking_price (Amount* CK >= 0); currency_code (CurrencyCode* default INR); description (Text?). One active listing per vehicle (TX/UQ policy). |
| ListingImage — image reference metadata | listing_image_id (Identifier PK); listing_id (Identifier* FK→VehicleListing); image_reference (URI*); display_order (Integer*); caption (Text?); UQ(listing_id,display_order). |
| CustomerEnquiry — listing contact | enquiry_id (Identifier PK); listing_id (Identifier* FK→VehicleListing); customer_id (Identifier* FK→Customer); assigned_employee_id (Identifier? FK→Employee); channel_code (Code*); received_at (Timestamp*); status (Code*); message_reference (Text?). |
| VehicleReservation — time-bound hold | reservation_id (Identifier PK); listing_id (Identifier* FK→VehicleListing); customer_id (Identifier* FK→Customer); created_at (Timestamp*); expires_at (Timestamp*); status (Code*); released_at (Timestamp?); CK(expires_at > created_at); only one active reservation per vehicle (TX). |

### Sale, finance and fulfillment

| Table / purpose | Attributes (type; nullability; keys/constraints) |
|---|---|
| SalesOrder — buyer transaction | order_id (Identifier PK); buyer_customer_id (Identifier* FK→Customer); created_at (Timestamp*); status (Code*); currency_code (CurrencyCode* default INR); confirmed_at (Timestamp?); completed_at (Timestamp?); cancelled_at (Timestamp?); |
| SalesOrderItem — vehicle and agreed price | order_item_id (Identifier PK); order_id (Identifier* FK→SalesOrder); vehicle_id (Identifier* FK→Vehicle); reservation_id (Identifier? FK→VehicleReservation UQ); sale_price (Amount* CK >= 0); currency_code (CurrencyCode*); UQ(order_id,vehicle_id). Initial policy exactly one item/order; at most one completed order item/vehicle (TX). |
| Payment — payment attempt/transaction | payment_id (Identifier PK); order_id (Identifier* FK→SalesOrder); provider_code (Code*); provider_reference (Code?); payment_method_code (Code*); amount (Amount* CK > 0); currency_code (CurrencyCode*); status (Code*); initiated_at (Timestamp*); settled_at (Timestamp?); UQ(provider_code,provider_reference) when supplied. |
| Refund — refund attempt | refund_id (Identifier PK); payment_id (Identifier* FK→Payment); provider_reference (Code?); amount (Amount* CK > 0); currency_code (CurrencyCode*); status (Code*); requested_at (Timestamp*); settled_at (Timestamp?); UQ(provider_reference) when supplied. Cumulative settled refunds <= settled payment (TX). |
| OwnershipTransfer — title administration | transfer_id (Identifier PK); order_item_id (Identifier* FK→SalesOrderItem); from_customer_id (Identifier* FK→Customer); to_customer_id (Identifier* FK→Customer); status (Code*); submitted_at (Timestamp?); completed_at (Timestamp?); authority_reference (Code?). |
| VehicleDelivery — handover | delivery_id (Identifier PK); order_item_id (Identifier* FK→SalesOrderItem); recipient_customer_id (Identifier* FK→Customer); branch_id (Identifier? FK→Branch); delivery_address_id (Identifier? FK→CustomerAddress); scheduled_at (Timestamp?); completed_at (Timestamp?); status (Code*); handover_reference (Code?); |

## Relationship summary

All FKs above are mandatory unless marked `?`. Key cardinalities and workflow-only conditions are detailed in the conceptual model and diagrams. EmployeeRole is an employee-role assignment rather than a separate canonical role catalog; role codes are controlled reference values. Controlled code families include status, fuel, transmission, inspection, defect, movement, channel, payment method, currency, and ownership basis. Production governance may normalize them into reference tables.

## Status and history strategy

Status on an entity represents current operational state; historical inspections, valuations, offers, agreements, movements, listings, reservations, payments, refunds, transfers and deliveries remain rows. Material state transitions record timestamps and actor/reason where appropriate. `Vehicle.lifecycle_status` is a projection/current state and must be changed in the same transaction as the triggering domain event. Derivable totals are not stored as independent facts. Order amount is derived from its one item in the initial scope; no redundant order total is defined.
