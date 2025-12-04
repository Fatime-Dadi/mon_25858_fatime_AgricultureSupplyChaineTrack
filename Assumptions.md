# DESIGN ASSUMPTIONS & NORMALIZATION JUSTIFICATION

## 1. Normalization Approach (3NF)

### 1.1 Initial Denormalized Structure
Based on the Kenya agriculture dataset, initial data contained:
- Region details repeated for each farmer
- Crop details repeated in each harvest record
- Transport details mixed with quality metrics

### 1.2 First Normal Form (1NF)
- **Repeating groups eliminated**: Separate tables for regions, farmers, crops
- **Atomic values ensured**: Each column contains single values
- **Primary keys defined**: Unique identifiers for each entity

### 1.3 Second Normal Form (2NF)
- **Partial dependencies removed**:
  - Region attributes dependent only on RegionID (not HarvestID)
  - Crop attributes dependent only on CropID (not HarvestID)
  - Farmer attributes dependent only on FarmerID (not HarvestID)
- **All non-key attributes fully dependent on primary keys**

### 1.4 Third Normal Form (3NF)
- **Transitive dependencies eliminated**:
  - Warehouse location dependent on WarehouseID (not TransportID)
  - Vehicle details dependent on VehicleID (not TransportID)
  - No non-prime attribute transitively dependent on any key

## 2. Business Assumptions

### 2.1 Supply Chain Flow
1. One harvest can only be transported once (1:1 relationship)
2. One transport can result in multiple quality checks during transit
3. One transport results in one market sale transaction
4. Farmers operate in one region only (no multi-location farming)

### 2.2 Data Volume Estimates
- 50,000+ farmers in Kenya agricultural system
- 200,000+ harvest records annually
- 150,000+ transport shipments
- 500,000+ quality check records (multiple per shipment)

### 2.3 BI & Analytics Considerations
- FACT tables designed for aggregation (HARVEST, TRANSPORT, SALES)
- DIMENSION tables support slicing (TIME, REGION, CROP, FARMER)
- Slowly Changing Dimensions: REGION as Type 2 (historical tracking)
- Audit trails implemented for critical transactions

## 3. Technical Assumptions

### 3.1 Oracle Database Specific
- NUMBER data types for precise decimal calculations
- VARCHAR2 for variable-length character data
- DATE and TIMESTAMP for temporal data
- CHECK constraints for data integrity

### 3.2 Performance Considerations
- Indexes on all foreign keys
- Partitioning on date columns (HarvestDate, SaleDate)
- Materialized views for frequent aggregations

## 4. Constraints & Validation Rules

### 4.1 Business Rules Enforced
- Quantity must be positive (> 0)
- Sale price must be positive (> 0)
- Dates must be valid (HarvestDate ≤ DispatchDate ≤ SaleDate)
- Quality status limited to predefined values

### 4.2 Referential Integrity
- Cascade delete NOT implemented (historical preservation)
- Foreign keys enforce valid relationships
- Orphan records prevented through FK constraints
