-- Tablespace Configuration Script
-- Author: Fatime
-- Date: December 2025

-- Create data tablespace
CREATE TABLESPACE AGRI_DATA 
DATAFILE 'agri_data01.dbf' 
SIZE 50M 
AUTOEXTEND ON 
NEXT 10M 
MAXSIZE UNLIMITED;

-- Create index tablespace
CREATE TABLESPACE AGRI_IDX 
DATAFILE 'agri_idx01.dbf' 
SIZE 25M 
AUTOEXTEND ON 
NEXT 10M 
MAXSIZE UNLIMITED;

-- Create temporary tablespace
CREATE TEMPORARY TABLESPACE AGRI_TEMP 
TEMPFILE 'agri_temp01.dbf' 
SIZE 50M 
AUTOEXTEND ON 
NEXT 10M 
MAXSIZE UNLIMITED;

-- Verify tablespace creation
SELECT tablespace_name, contents, status, extent_management 
FROM dba_tablespaces 
WHERE tablespace_name LIKE 'AGRI_%';