# Phase IV: Database Creation - AgriSupply System

## Project Overview
This project involves creating and configuring an Oracle 21c pluggable database (PDB) for the AgriSupply management system. The database follows the naming convention: `GrpName_StudentId_FirstName_ProjectName_DB`.

## Database Details
- **Database Name**: MON_25858_FATIME_AGRISUPPLY_DB
- **Admin User**: FATIME_ADMIN
- **Password**: Fatime
- **Privileges**: DBA role with full administrative access
- **Oracle Version**: 21c Enterprise Edition

## Setup Steps Completed

### 1. PDB Creation and Configuration
- Created PDB: `MON_25858_FATIME_AGRISUPPLY_DB`
- Opened and connected to the PDB
- Verified connection using SYS_CONTEXT

### 2. Tablespace Configuration
- **Data Tablespace**: AGRI_DATA (50MB, autoextend ON)
- **Index Tablespace**: AGRI_IDX (25MB, autoextend ON)
- **Temporary Tablespace**: AGRI_TEMP (50MB, autoextend ON)
- All tablespaces configured with AUTOEXTEND and MAXSIZE UNLIMITED

### 3. User Administration
- Created admin user: `FATIME_ADMIN`
- Password: `Fatime`
- Granted DBA privileges
- Granted CREATE SESSION privilege
- Set default tablespace: AGRI_DATA
- Account status: OPEN and unlocked

### 4. Memory Configuration
- SGA_TARGET: 1GB
- PGA_AGGREGATE_TARGET: 500MB
- Configured at PDB level

### 5. Archive Logging
- Archive logging enabled at CDB level
- Configured for point-in-time recovery

## File Structure