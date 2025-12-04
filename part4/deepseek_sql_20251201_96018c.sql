-- 1. Create temporary tablespace
CREATE TEMPORARY TABLESPACE AGRI_TEMP 
TEMPFILE 'agri_temp01.dbf' 
SIZE 50M AUTOEXTEND ON;

-- 2. Set memory parameters
ALTER SYSTEM SET SGA_TARGET=1G SCOPE=BOTH;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET=500M SCOPE=BOTH;

-- 3. Set maxsize for autoextend
ALTER DATABASE DATAFILE 'agri_data01.dbf' 
AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;

ALTER DATABASE DATAFILE 'agri_idx01.dbf' 
AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;

-- 4. Verify all settings
SELECT tablespace_name, contents, status 
FROM dba_tablespaces 
WHERE tablespace_name LIKE 'AGRI_%';

SELECT name, value 
FROM v$parameter 
WHERE name IN ('sga_target', 'pga_aggregate_target');

-- 5. Show user details
SELECT username, default_tablespace, temporary_tablespace, account_status
FROM dba_users 
WHERE username = 'FATIME_ADMIN';