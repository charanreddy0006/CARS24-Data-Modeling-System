# Normalization Analysis

The logical OLTP relations target 3NF. This assessment assumes the candidate keys and functional dependencies stated here; future requirements may change them.

## First Normal Form (1NF)

**Definition:** each row/column intersection contains one atomic value, with no repeating groups. **Prevents:** ambiguous multivalued fields and awkward searching/updating.

**Unnormalized example:** `Vehicle(VehicleID, RegistrationNumbers="KA01...; MH02...", Inspections="date/outcome, date/outcome")`. **Improvement:** one Vehicle row, multiple VehicleRegistration rows, and multiple Inspection rows. Checklist findings are separate InspectionItem rows, one item code per report row. Contacts and addresses are similarly separate rather than `phone1`, `phone2` columns. Each relation then contains scalar logical values; a message/document/image is represented by a reference or opaque content value rather than a repeating list.

## Second Normal Form (2NF)

**Definition:** relation is in 1NF and each non-key attribute depends on the whole candidate key, not part of a composite key. **Prevents:** partial-dependency update anomalies.

Most relations use a single surrogate PK, so partial dependency on a component of that PK cannot occur. Natural uniqueness constraints still matter. Consider an unnormalized `OrderLine(OrderID, VehicleID, VehicleModelName, BuyerName, SalePrice)` keyed by `(OrderID, VehicleID)`. BuyerName depends only on OrderID; VehicleModelName depends only on VehicleID. Split into SalesOrder(OrderID, BuyerCustomerID), SalesOrderItem(OrderItemID, OrderID, VehicleID, SalePrice), and Vehicle(VehicleID, ModelID) with catalog tables. For the composite candidate key `(ReportID, ItemCode)` in InspectionItem, result/note depend on the pair, while item-code descriptions belong in a checklist reference if detailed labels become governed data.

## Third Normal Form (3NF)

**Definition:** relation is in 2NF and no non-key attribute transitively depends on a key through another non-key attribute. For each relation, the non-key facts depend on the key, the whole key, and nothing but the key.

| Relation | Main functional dependency | 3NF reasoning |
|---|---|---|
| Customer | CustomerID → names, status, created_at | Contact/address values are separate because customer has many of each. |
| VehicleModel | ModelID → BrandID, ModelName; (BrandID, ModelName) is candidate key | BrandName is stored only in VehicleBrand, avoiding model→brand→brand-name transitivity. |
| Vehicle | VehicleID → ModelID, identifiers, current lifecycle state | Model and brand descriptions remain in catalog; owner identity details remain in Customer/history. |
| VehicleOwnershipHistory | OwnershipHistoryID → vehicle, customer, interval, basis | Customer name is not copied into ownership history; owner details join by FK. |
| InspectionReport | ReportID → InspectionID, outcome, summary, finalized time | Vehicle data is obtained via Inspection rather than duplicated. |
| VehicleValuation | ValuationID → vehicle, report, assessor, date, amount, basis | Assessor and customer names are referenced, not repeated; each valuation is an independent snapshot. |
| InventoryMovement | MovementID → inventory, endpoints, time, actor, reason | Branch names and employee names remain in their master tables. |
| SalesOrderItem | OrderItemID → order, vehicle, price | Buyer is on SalesOrder and model is on Vehicle; neither is copied onto item. |
| Payment | PaymentID → order, provider ref, amount, status | Buyer and vehicle are joined through order, avoiding duplicated order-level facts. |
| Refund | RefundID → payment, provider ref, amount, status | Order, buyer and provider details are obtained through Payment; only refund facts remain. |

**Transitive dependency example:** `Vehicle(VehicleID, ModelID, ModelName, BrandID, BrandName)` implies VehicleID→ModelID→ModelName/BrandID→BrandName. Splitting VehicleModel and VehicleBrand removes that dependency. **Update anomaly:** renaming a brand requires edits to many vehicle rows in the denormalized design. **Insert anomaly:** cannot add a brand/model until a vehicle exists. **Delete anomaly:** deleting the last vehicle of a model would erase model/brand facts. Catalog relations prevent these anomalies.

## Anomalies addressed

- **Repeating groups:** multiple inspection outcomes, contacts, payments and movements become separate related rows.
- **Partial dependencies:** order buyer and vehicle model attributes are separated from composite order-line data.
- **Transitive dependencies:** city/state, brand/model, customer contact and employee role descriptions are not duplicated into transaction rows.
- **Update anomalies:** one authoritative brand/model/customer/branch fact is maintained.
- **Insert anomalies:** reference/catalog and customer rows can exist before a vehicle or order.
- **Delete anomalies:** transaction history does not depend on retaining a current listing; normal deletion is restricted and records are closed/cancelled.

No deliberate denormalization is proposed. `Vehicle.lifecycle_status` and `Inventory` current position are operational current-state representations, not copied historical detail; they must be transactionally maintained against their event history. They are explicit design tradeoffs and should be reconciled periodically. Status labels and code descriptions may be promoted to lookup tables when reference governance requires it.
