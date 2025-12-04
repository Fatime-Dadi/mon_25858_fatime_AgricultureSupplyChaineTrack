# DATA DICTIONARY
## Agriculture Supply Chain Management System

### 1. DIMENSION TABLES

#### 1.1 REGION
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| RegionID | NUMBER(10) | PRIMARY KEY | Unique region identifier |
| Country | VARCHAR2(50) | NOT NULL | Country name (e.g., Kenya) |
| County | VARCHAR2(50) | NOT NULL | County name (e.g., Kilifi) |
| SubCounty | VARCHAR2(50) | NULL | Sub-county name |

#### 1.2 FARMER
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| FarmerID | NUMBER(10) | PRIMARY KEY | Unique farmer identifier |
| FirstName | VARCHAR2(50) | NOT NULL | Farmer's first name |
| LastName | VARCHAR2(50) | NOT NULL | Farmer's last name |
| RegionID | NUMBER(10) | FOREIGN KEY REFERENCES REGION(RegionID) | Farmer's location |
| ContactPhone | VARCHAR2(20) | NULL | Contact phone number |

#### 1.3 CROP_TYPE
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| CropID | NUMBER(5) | PRIMARY KEY | Crop type identifier |
| CropName | VARCHAR2(30) | UNIQUE, NOT NULL | Crop name (e.g., Maize, Sorghum) |
| Category | VARCHAR2(20) | NULL | Category (Cereal, Tuber, Legume) |

#### 1.4 VEHICLE
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| VehicleID | NUMBER(10) | PRIMARY KEY | Vehicle identifier |
| VehicleType | VARCHAR2(30) | NOT NULL | Type (Truck, Van, Refrigerated) |
| Capacity | NUMBER(10,2) | NOT NULL | Capacity in kilograms |
| Registration | VARCHAR2(20) | UNIQUE, NOT NULL | Vehicle registration number |

#### 1.5 WAREHOUSE
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| WarehouseID | NUMBER(10) | PRIMARY KEY | Warehouse identifier |
| WarehouseName | VARCHAR2(50) | NOT NULL | Warehouse name |
| Location | VARCHAR2(100) | NOT NULL | Physical location |
| Capacity | NUMBER(10,2) | NOT NULL | Storage capacity (kg) |
| TemperatureControl | CHAR(1) | CHECK IN ('Y','N') | Has temperature control? |

### 2. FACT TABLES

#### 2.1 HARVEST
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| HarvestID | NUMBER(15) | PRIMARY KEY | Harvest record identifier |
| FarmerID | NUMBER(10) | FOREIGN KEY REFERENCES FARMER(FarmerID) | Farmer who harvested |
| CropID | NUMBER(5) | FOREIGN KEY REFERENCES CROP_TYPE(CropID) | Crop type harvested |
| Quantity | NUMBER(10,2) | NOT NULL, CHECK > 0 | Quantity in kilograms |
| HarvestDate | DATE | NOT NULL | Date of harvest |
| FarmingMethod | VARCHAR2(20) | NULL | Method (Irrigation, Rainfed) |

#### 2.2 TRANSPORT
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| TransportID | NUMBER(15) | PRIMARY KEY | Transport shipment identifier |
| HarvestID | NUMBER(15) | FOREIGN KEY REFERENCES HARVEST(HarvestID) | Harvest being transported |
| VehicleID | NUMBER(10) | FOREIGN KEY REFERENCES VEHICLE(VehicleID) | Vehicle used |
| WarehouseID | NUMBER(10) | FOREIGN KEY REFERENCES WAREHOUSE(WarehouseID) | Source warehouse |
| RouteDetails | VARCHAR2(200) | NULL | Transport route details |
| DispatchDate | DATE | NOT NULL | Date of dispatch |
| EstimatedArrival | DATE | NULL | Estimated arrival date |

#### 2.3 QUALITY_CHECK
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| QualityID | NUMBER(15) | PRIMARY KEY | Quality check identifier |
| TransportID | NUMBER(15) | FOREIGN KEY REFERENCES TRANSPORT(TransportID) | Transport shipment checked |
| Temperature | NUMBER(5,2) | NULL | Temperature in Celsius |
| Humidity | NUMBER(5,2) | NULL | Humidity percentage |
| CheckTimestamp | TIMESTAMP | NOT NULL | Time of quality check |
| Status | VARCHAR2(10) | CHECK IN ('PASS','FAIL','ALERT') | Quality status |

#### 2.4 MARKET_SALE
| Column | Data Type | Constraint | Description |
|--------|-----------|------------|-------------|
| SaleID | NUMBER(15) | PRIMARY KEY | Sale transaction identifier |
| TransportID | NUMBER(15) | FOREIGN KEY REFERENCES TRANSPORT(TransportID) | Transported goods sold |
| SaleDate | DATE | NOT NULL | Date of sale |
| SalePrice | NUMBER(10,2) | NOT NULL, CHECK > 0 | Price per kilogram |
| TotalAmount | NUMBER(12,2) | NOT NULL, CHECK > 0 | Total sale amount |
| CustomerType | VARCHAR2(20) | NULL | Type (Wholesaler, Retailer) |
