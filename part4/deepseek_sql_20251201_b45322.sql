-- Verification Script
-- Author: Fatime
-- Date: December 2025

-- 1. Verify PDB status
SELECT name, open_mode, restricted 
FROM v$pdbs 
WHERE name = 'MON_25858_FATIME_AGRISUPPLY_DB';

-- 2. Verify tablespaces
SELECT tablespace_name, file_name, bytes/1024/1024 as size_mb,
       autoextensible, maxbytes/1024/1024 as max_size_mb
FROM dba_data_files 
WHERE tablespace_name LIKE 'AGRI_%'
UNION ALL
SELECT tablespace_name, file_name, bytes/1024/1024 as size_mb,
       autoextensible, maxbytes/1024/1024 as max_size_mb
FROM dba_temp_files 
WHERE tablespace_name LIKE 'AGRI_%';

-- 3. Verify admin user
SELECT username, account_status, default_tablespace,
       temporary_tablespace, created, profile
FROM dba_users 
WHERE username = 'FATIME_ADMIN';

-- 4. Verify privileges
SELECT privilege, admin_option
FROM dba_sys_privs 
WHERE grantee = 'FATIME_ADMIN'
ORDER BY privilege;

-- 5. Verify archive logging
SELECT log_mode, force_logging, flashback_on 
FROM v$database;

-- 6. Complete system summary
SELECT 'PDB: ' || SYS_CONTEXT('USERENV', 'CON_NAME') as database_info FROM DUAL
UNION ALL
SELECT 'Tablespaces: ' || COUNT(*) || ' created' 
FROM dba_tablespaces 
WHERE tablespace_name LIKE 'AGRI_%'
UNION ALL
SELECT 'Admin User: ' || username || ' - ' || account_status
FROM dba_users 
WHERE username = 'FATIME_ADMIN';