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

Phase4_Database/
├── README.md # This file
├── project_overview.md # Detailed project description
├── scripts/
│ ├── 01_pdb_setup.sql # PDB creation and connection
│ ├── 02_tablespaces.sql # Tablespace creation
│ ├── 03_admin_user.sql # Admin user setup
│ ├── 04_memory_config.sql # Memory parameters
│ └── 05_verification.sql # Verification queries
└── screenshots/
├── pdb_connected.png # Connection verification
└── setup_complete.png # Complete setup verification


## Verification Queries
To verify the setup, run the following queries:

```sql
-- Verify PDB connection
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') as CURRENT_PDB FROM DUAL;

-- Verify tablespaces
SELECT tablespace_name, contents, status FROM dba_tablespaces WHERE tablespace_name LIKE 'AGRI_%';

-- Verify admin user
SELECT username, default_tablespace, temporary_tablespace, account_status 
FROM dba_users 
WHERE username = 'FATIME_ADMIN';

-- Verify memory parameters
SELECT name, value FROM v$parameter 
WHERE name IN ('sga_target', 'pga_aggregate_target');

Prerequisites
Oracle Database 21c installed

SYSDBA privileges

Sufficient disk space for tablespaces

Installation
Connect as SYSDBA: sqlplus sys/your_password as sysdba

Run scripts in order from the scripts/ directory

Verify setup using verification queries

Author
Name: Fatime Dadi Wardougou

Student ID: 25858

Group: MON

