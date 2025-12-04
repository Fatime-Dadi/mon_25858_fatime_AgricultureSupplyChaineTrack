-- Admin User Setup Script
-- Author: Fatime
-- Date: December 2025

-- Create admin user (if not exists)
DECLARE
    user_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO user_exists 
    FROM dba_users 
    WHERE username = 'FATIME_ADMIN';
    
    IF user_exists = 0 THEN
        EXECUTE IMMEDIATE 'CREATE USER FATIME_ADMIN IDENTIFIED BY Fatime';
    END IF;
END;
/

-- Grant privileges
GRANT DBA TO FATIME_ADMIN;
GRANT CREATE SESSION TO FATIME_ADMIN;

-- Configure user settings
ALTER USER FATIME_ADMIN 
DEFAULT TABLESPACE AGRI_DATA 
TEMPORARY TABLESPACE AGRI_TEMP 
QUOTA UNLIMITED ON AGRI_DATA 
QUOTA UNLIMITED ON AGRI_IDX;

-- Unlock account if locked
ALTER USER FATIME_ADMIN ACCOUNT UNLOCK;

-- Verify user setup
SELECT username, default_tablespace, temporary_tablespace, 
       account_status, authentication_type
FROM dba_users 
WHERE username = 'FATIME_ADMIN';