-- ============================================
-- PART VII: ADVANCED PROGRAMMING & AUDITING
-- Agricultural Census Data Management System
-- BUSINESS RULE: Agricultural survey data can only be entered/updated
-- during official survey collection periods (not after deadlines)
-- ============================================

-- ========== CLEANUP SECTION ==========
-- Drop objects in reverse dependency order (triggers first, then tables)

-- Drop triggers
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_SURVEY_AGRIC_DATA_RESTRICTION';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_SURVEY_COUNTIES_RESTRICTION';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Drop functions
BEGIN
    EXECUTE IMMEDIATE 'DROP FUNCTION LOG_SURVEY_AUDIT';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP FUNCTION CHECK_USER_RESTRICTION';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP FUNCTION CHECK_SURVEY_PERIOD';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Drop tables (in reverse dependency order)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE AGRIC_SURVEY_AUDIT';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE SYSTEM_USERS';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE SURVEY_COLLECTION_PERIODS';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

COMMIT;

-- ========== STEP 1: SURVEY PERIODS TABLE ==========
-- Defines when data collection is allowed
CREATE TABLE SURVEY_COLLECTION_PERIODS (
    PERIOD_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    SURVEY_NAME VARCHAR2(100) NOT NULL,
    START_DATE DATE NOT NULL,
    END_DATE DATE NOT NULL,
    STATUS VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (STATUS IN ('ACTIVE', 'CLOSED', 'PLANNED')),
    DESCRIPTION VARCHAR2(500),
    CONSTRAINT valid_dates CHECK (END_DATE >= START_DATE)
);

-- Insert sample survey periods - FIXED SYNTAX
INSERT INTO SURVEY_COLLECTION_PERIODS (SURVEY_NAME, START_DATE, END_DATE, DESCRIPTION) 
VALUES ('2024 Annual Agricultural Census', DATE '2024-01-15', DATE '2024-03-15', 'National agricultural data collection');

INSERT INTO SURVEY_COLLECTION_PERIODS (SURVEY_NAME, START_DATE, END_DATE, DESCRIPTION) 
VALUES ('2024 Crop Production Survey', DATE '2024-06-01', DATE '2024-08-31', 'Seasonal crop data collection');

INSERT INTO SURVEY_COLLECTION_PERIODS (SURVEY_NAME, START_DATE, END_DATE, DESCRIPTION) 
VALUES ('2024 Livestock Census', DATE '2024-09-01', DATE '2024-11-30', 'Livestock population survey');

INSERT INTO SURVEY_COLLECTION_PERIODS (SURVEY_NAME, START_DATE, END_DATE, DESCRIPTION) 
VALUES ('2025 Planning Survey', DATE '2025-01-01', DATE '2025-12-31', 'Upcoming year planning');

COMMIT;

-- ========== STEP 2: FARMER/USER TABLE (We need this for context) ==========
CREATE TABLE SYSTEM_USERS (
    USER_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    USERNAME VARCHAR2(50) NOT NULL UNIQUE,
    USER_TYPE VARCHAR2(20) NOT NULL CHECK (USER_TYPE IN ('FARMER', 'EXTENSION_OFFICER', 'DATA_CLERK', 'ADMIN')),
    COUNTY_ID NUMBER REFERENCES COUNTIES(COUNTY_ID),
    FULL_NAME VARCHAR2(100),
    EMAIL VARCHAR2(100),
    REGISTRATION_DATE DATE DEFAULT SYSDATE,
    STATUS VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (STATUS IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
);

-- Insert sample users - FIXED SYNTAX
INSERT INTO SYSTEM_USERS (USERNAME, USER_TYPE, COUNTY_ID, FULL_NAME) 
VALUES ('farmer_john', 'FARMER', 1, 'John Mwangi');

INSERT INTO SYSTEM_USERS (USERNAME, USER_TYPE, COUNTY_ID, FULL_NAME) 
VALUES ('clerk_mary', 'DATA_CLERK', 2, 'Mary Wanjiku');

INSERT INTO SYSTEM_USERS (USERNAME, USER_TYPE, COUNTY_ID, FULL_NAME) 
VALUES ('officer_peter', 'EXTENSION_OFFICER', 3, 'Peter Kipchoge');

INSERT INTO SYSTEM_USERS (USERNAME, USER_TYPE, COUNTY_ID, FULL_NAME) 
VALUES ('admin_sys', 'ADMIN', NULL, 'System Administrator');

COMMIT;

-- ========== STEP 3: AUDIT LOG TABLE (Enhanced) ==========
CREATE TABLE AGRIC_SURVEY_AUDIT (
    AUDIT_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    AUDIT_TIMESTAMP TIMESTAMP DEFAULT SYSTIMESTAMP,
    USER_ID NUMBER REFERENCES SYSTEM_USERS(USER_ID),
    USERNAME VARCHAR2(50) NOT NULL,
    USER_TYPE VARCHAR2(20),
    TABLE_NAME VARCHAR2(100) NOT NULL,
    DML_OPERATION VARCHAR2(10) CHECK (DML_OPERATION IN ('INSERT', 'UPDATE', 'DELETE')),
    RECORD_ID VARCHAR2(100),
    OLD_VALUES CLOB,
    NEW_VALUES CLOB,
    OPERATION_STATUS VARCHAR2(20) CHECK (OPERATION_STATUS IN ('ALLOWED', 'DENIED', 'PENDING')),
    DENIAL_REASON VARCHAR2(500),
    SURVEY_PERIOD_ID NUMBER REFERENCES SURVEY_COLLECTION_PERIODS(PERIOD_ID),
    IS_WITHIN_PERIOD CHAR(1) CHECK (IS_WITHIN_PERIOD IN ('Y', 'N')),
    IP_ADDRESS VARCHAR2(50),
    SESSION_ID VARCHAR2(100)
);

-- ========== STEP 4: CHECK SURVEY PERIOD FUNCTION ==========
CREATE OR REPLACE FUNCTION CHECK_SURVEY_PERIOD(
    p_operation_date IN DATE DEFAULT SYSDATE
) RETURN VARCHAR2
IS
    v_active_period_count NUMBER;
    v_period_name VARCHAR2(100);
    v_period_id NUMBER;
    v_result VARCHAR2(1000);
BEGIN
    -- Check if there's any active survey period covering this date
    SELECT COUNT(*), MAX(SURVEY_NAME), MAX(PERIOD_ID)
    INTO v_active_period_count, v_period_name, v_period_id
    FROM SURVEY_COLLECTION_PERIODS
    WHERE STATUS = 'ACTIVE'
    AND p_operation_date BETWEEN START_DATE AND END_DATE;
    
    IF v_active_period_count > 0 THEN
        v_result := '{"allowed": "Y", "period_id": ' || v_period_id || 
                   ', "period_name": "' || v_period_name || 
                   '", "reason": "Within active survey collection period"}';
    ELSE
        v_result := '{"allowed": "N", "period_id": null, ' ||
                   '"reason": "Outside survey collection periods. Data can only be entered during active survey windows."}';
    END IF;
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN '{"allowed": "N", "reason": "Error checking survey period: ' || SQLERRM || '"}';
END CHECK_SURVEY_PERIOD;
/

-- ========== STEP 5: RESTRICTION CHECK FOR USER TYPES ==========
CREATE OR REPLACE FUNCTION CHECK_USER_RESTRICTION(
    p_user_type IN VARCHAR2,
    p_operation_date IN DATE DEFAULT SYSDATE
) RETURN VARCHAR2
IS
    v_survey_check VARCHAR2(1000);
    v_allowed CHAR(1);
    v_reason VARCHAR2(500);
    v_period_id NUMBER;
    v_period_name VARCHAR2(100);
BEGIN
    -- First check survey period
    v_survey_check := CHECK_SURVEY_PERIOD(p_operation_date);
    v_allowed := SUBSTR(v_survey_check, 
        INSTR(v_survey_check, '"allowed": "') + 12, 1);
    
    -- Extract period info if available
    IF INSTR(v_survey_check, '"period_id": ') > 0 THEN
        v_period_id := TO_NUMBER(SUBSTR(v_survey_check,
            INSTR(v_survey_check, '"period_id": ') + 13,
            INSTR(v_survey_check, ',', INSTR(v_survey_check, '"period_id": ')) - 
            INSTR(v_survey_check, '"period_id": ') - 13
        ));
        
        v_period_name := SUBSTR(v_survey_check,
            INSTR(v_survey_check, '"period_name": "') + 17,
            INSTR(v_survey_check, '",', INSTR(v_survey_check, '"period_name": "')) - 
            INSTR(v_survey_check, '"period_name": "') - 17
        );
    END IF;
    
    v_reason := SUBSTR(v_survey_check,
        INSTR(v_survey_check, '"reason": "') + 11,
        INSTR(v_survey_check, '"}') - INSTR(v_survey_check, '"reason": "') - 11
    );
    
    -- Additional restrictions based on user type
    IF p_user_type = 'FARMER' AND v_allowed = 'N' THEN
        v_reason := 'Farmers can only submit data during survey collection periods. ' || v_reason;
    ELSIF p_user_type = 'DATA_CLERK' AND v_allowed = 'N' THEN
        v_reason := 'Data clerks cannot process entries outside survey periods. ' || v_reason;
    ELSIF p_user_type = 'ADMIN' THEN
        -- Admins can always modify data (override)
        v_allowed := 'Y';
        v_reason := 'Admin override - survey period restriction waived';
    END IF;
    
    RETURN '{"allowed": "' || v_allowed || 
           '", "period_id": ' || NVL(TO_CHAR(v_period_id), 'null') ||
           ', "period_name": "' || NVL(v_period_name, '') ||
           '", "user_type": "' || p_user_type ||
           '", "reason": "' || v_reason || '"}';
    
END CHECK_USER_RESTRICTION;
/

-- ========== STEP 6: AUDIT LOGGING FUNCTION ==========
-- SIMPLIFIED VERSION TO AVOID COMPILATION ISSUES
CREATE OR REPLACE FUNCTION LOG_SURVEY_AUDIT(
    p_user_id IN NUMBER,
    p_username IN VARCHAR2,
    p_user_type IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_dml_operation IN VARCHAR2,
    p_record_id IN VARCHAR2 DEFAULT NULL,
    p_old_values IN CLOB DEFAULT NULL,
    p_new_values IN CLOB DEFAULT NULL,
    p_operation_status IN VARCHAR2,
    p_denial_reason IN VARCHAR2 DEFAULT NULL,
    p_survey_period_id IN NUMBER DEFAULT NULL,
    p_is_within_period IN CHAR DEFAULT NULL
) RETURN NUMBER
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_audit_id NUMBER;
BEGIN
    INSERT INTO AGRIC_SURVEY_AUDIT (
        USER_ID, USERNAME, USER_TYPE, TABLE_NAME, DML_OPERATION,
        RECORD_ID, OLD_VALUES, NEW_VALUES, OPERATION_STATUS,
        DENIAL_REASON, SURVEY_PERIOD_ID, IS_WITHIN_PERIOD,
        IP_ADDRESS, SESSION_ID
    ) VALUES (
        p_user_id, p_username, p_user_type, p_table_name, p_dml_operation,
        p_record_id, p_old_values, p_new_values, p_operation_status,
        p_denial_reason, p_survey_period_id, p_is_within_period,
        SYS_CONTEXT('USERENV', 'IP_ADDRESS'), 
        SYS_CONTEXT('USERENV', 'SESSIONID')
    )
    RETURNING AUDIT_ID INTO v_audit_id;
    
    COMMIT;
    RETURN v_audit_id;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Return -1 instead of raising error to avoid trigger failure
        RETURN -1;
END LOG_SURVEY_AUDIT;
/

-- ========== STEP 7: COMPOUND TRIGGER FOR COUNTIES TABLE ==========
CREATE OR REPLACE TRIGGER TRG_SURVEY_COUNTIES_RESTRICTION
FOR INSERT OR UPDATE OR DELETE ON COUNTIES
COMPOUND TRIGGER

    -- Type declarations
    TYPE t_operation_rec IS RECORD (
        county_id COUNTIES.COUNTY_ID%TYPE,
        county_name COUNTIES.COUNTY_NAME%TYPE,
        operation_type VARCHAR2(10),
        old_values CLOB,
        new_values CLOB,
        user_id NUMBER,
        username VARCHAR2(50),
        user_type VARCHAR2(20)
    );
    
    TYPE t_operation_table IS TABLE OF t_operation_rec;
    g_operations t_operation_table := t_operation_table();
    
    -- Shared variables
    v_restriction_result VARCHAR2(1000);
    v_allowed CHAR(1);
    v_reason VARCHAR2(500);
    v_period_id NUMBER;
    v_current_user_type VARCHAR2(20);
    v_current_user_id NUMBER;
    v_current_username VARCHAR2(50);
    v_audit_id NUMBER;  -- To store function return value
    
    -- Before each row
    BEFORE EACH ROW IS
    BEGIN
        -- Get current user info
        BEGIN
            SELECT USER_ID, USERNAME, USER_TYPE 
            INTO v_current_user_id, v_current_username, v_current_user_type
            FROM SYSTEM_USERS 
            WHERE USERNAME = USER
            AND ROWNUM = 1;
        EXCEPTION 
            WHEN NO_DATA_FOUND THEN
                v_current_user_id := NULL;
                v_current_username := USER;
                v_current_user_type := 'UNKNOWN';
        END;
        
        -- Check restriction (once per statement)
        IF g_operations.COUNT = 0 THEN
            v_restriction_result := CHECK_USER_RESTRICTION(v_current_user_type, SYSDATE);
            v_allowed := SUBSTR(v_restriction_result,
                INSTR(v_restriction_result, '"allowed": "') + 12, 1);
            
            -- Extract period id if available
            IF INSTR(v_restriction_result, '"period_id": ') > 0 AND
               INSTR(v_restriction_result, '"period_id": null') = 0 THEN
                v_period_id := TO_NUMBER(SUBSTR(v_restriction_result,
                    INSTR(v_restriction_result, '"period_id": ') + 13,
                    INSTR(v_restriction_result, ',', INSTR(v_restriction_result, '"period_id": ')) - 
                    INSTR(v_restriction_result, '"period_id": ') - 13
                ));
            END IF;
            
            v_reason := SUBSTR(v_restriction_result,
                INSTR(v_restriction_result, '"reason": "') + 11,
                INSTR(v_restriction_result, '"}') - INSTR(v_restriction_result, '"reason": "') - 11
            );
        END IF;
        
        -- Store operation details
        g_operations.EXTEND;
        g_operations(g_operations.LAST).county_id := 
            CASE WHEN INSERTING THEN :NEW.COUNTY_ID ELSE :OLD.COUNTY_ID END;
        g_operations(g_operations.LAST).county_name := 
            CASE WHEN INSERTING THEN :NEW.COUNTY_NAME ELSE :OLD.COUNTY_NAME END;
        g_operations(g_operations.LAST).operation_type := 
            CASE 
                WHEN INSERTING THEN 'INSERT'
                WHEN UPDATING THEN 'UPDATE'
                WHEN DELETING THEN 'DELETE'
            END;
        g_operations(g_operations.LAST).user_id := v_current_user_id;
        g_operations(g_operations.LAST).username := v_current_username;
        g_operations(g_operations.LAST).user_type := v_current_user_type;
        
        -- Store values for audit
        IF UPDATING OR DELETING THEN
            g_operations(g_operations.LAST).old_values := 
                '{"county_name": "' || :OLD.COUNTY_NAME || 
                '", "total_households": ' || :OLD.TOTAL_HOUSEHOLDS || 
                ', "farming_households": ' || :OLD.FARMING_HOUSEHOLDS || '}';
        END IF;
        
        IF INSERTING OR UPDATING THEN
            g_operations(g_operations.LAST).new_values := 
                '{"county_name": "' || :NEW.COUNTY_NAME || 
                '", "total_households": ' || :NEW.TOTAL_HOUSEHOLDS || 
                ', "farming_households": ' || :NEW.FARMING_HOUSEHOLDS || '}';
        END IF;
        
        -- Apply restriction
        IF v_allowed = 'N' THEN
            -- Call function and store return value
            v_audit_id := LOG_SURVEY_AUDIT(
                p_user_id => v_current_user_id,
                p_username => v_current_username,
                p_user_type => v_current_user_type,
                p_table_name => 'COUNTIES',
                p_dml_operation => g_operations(g_operations.LAST).operation_type,
                p_record_id => TO_CHAR(g_operations(g_operations.LAST).county_id),
                p_old_values => g_operations(g_operations.LAST).old_values,
                p_new_values => g_operations(g_operations.LAST).new_values,
                p_operation_status => 'DENIED',
                p_denial_reason => v_reason,
                p_survey_period_id => v_period_id,
                p_is_within_period => 'N'
            );
            
            RAISE_APPLICATION_ERROR(-20999, 
                'AGRICULTURAL SURVEY RESTRICTION: ' || v_reason);
        END IF;
        
    END BEFORE EACH ROW;
    
    -- After statement
    AFTER STATEMENT IS
    BEGIN
        -- Log successful operations
        FOR i IN 1..g_operations.COUNT LOOP
            -- Call function and store return value
            v_audit_id := LOG_SURVEY_AUDIT(
                p_user_id => g_operations(i).user_id,
                p_username => g_operations(i).username,
                p_user_type => g_operations(i).user_type,
                p_table_name => 'COUNTIES',
                p_dml_operation => g_operations(i).operation_type,
                p_record_id => TO_CHAR(g_operations(i).county_id),
                p_old_values => g_operations(i).old_values,
                p_new_values => g_operations(i).new_values,
                p_operation_status => 'ALLOWED',
                p_denial_reason => NULL,
                p_survey_period_id => v_period_id,
                p_is_within_period => 'Y'
            );
        END LOOP;
        
        g_operations.DELETE;
        
    END AFTER STATEMENT;
    
END TRG_SURVEY_COUNTIES_RESTRICTION;
/

-- ========== STEP 8: SIMPLE TRIGGER FOR AGRICULTURAL DATA ==========
-- FIXED VERSION: v_user_id declared in outer scope
CREATE OR REPLACE TRIGGER TRG_SURVEY_AGRIC_DATA_RESTRICTION
BEFORE INSERT OR UPDATE OR DELETE ON COUNTY_AGRIC_STATS
DECLARE
    v_current_user_type VARCHAR2(20);
    v_restriction_result VARCHAR2(1000);
    v_allowed CHAR(1);
    v_reason VARCHAR2(500);
    v_period_id NUMBER;
    v_audit_id NUMBER;  -- For function return value
    v_user_id NUMBER;   -- MOVED TO OUTER SCOPE
BEGIN
    -- Get user type and user_id
    BEGIN
        SELECT USER_ID, USER_TYPE 
        INTO v_user_id, v_current_user_type
        FROM SYSTEM_USERS 
        WHERE USERNAME = USER
        AND ROWNUM = 1;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            v_user_id := NULL;
            v_current_user_type := 'UNKNOWN';
    END;
    
    -- Check restriction
    v_restriction_result := CHECK_USER_RESTRICTION(v_current_user_type, SYSDATE);
    v_allowed := SUBSTR(v_restriction_result,
        INSTR(v_restriction_result, '"allowed": "') + 12, 1);
    
    v_reason := SUBSTR(v_restriction_result,
        INSTR(v_restriction_result, '"reason": "') + 11,
        INSTR(v_restriction_result, '"}') - INSTR(v_restriction_result, '"reason": "') - 11
    );
    
    -- Call function and store return value
    v_audit_id := LOG_SURVEY_AUDIT(
        p_user_id => v_user_id,
        p_username => USER,
        p_user_type => v_current_user_type,
        p_table_name => 'COUNTY_AGRIC_STATS',
        p_dml_operation => CASE 
            WHEN INSERTING THEN 'INSERT'
            WHEN UPDATING THEN 'UPDATE'
            WHEN DELETING THEN 'DELETE'
        END,
        p_operation_status => CASE WHEN v_allowed = 'Y' THEN 'ALLOWED' ELSE 'DENIED' END,
        p_denial_reason => CASE WHEN v_allowed = 'N' THEN v_reason END,
        p_is_within_period => CASE WHEN v_allowed = 'Y' THEN 'Y' ELSE 'N' END
    );
    
    -- Apply restriction
    IF v_allowed = 'N' THEN
        RAISE_APPLICATION_ERROR(-20998, 
            'AGRICULTURAL DATA ENTRY RESTRICTION: ' || v_reason);
    END IF;
    
END TRG_SURVEY_AGRIC_DATA_RESTRICTION;
/

-- ========== STEP 9: TESTING ==========

-- Test 1: Check survey period function
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 1: Survey Period Check ===');
    DBMS_OUTPUT.PUT_LINE('Result: ' || CHECK_SURVEY_PERIOD(SYSDATE));
END;
/

-- Test 2: Check user restriction
DECLARE
    v_result VARCHAR2(1000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 2: User Restriction Check ===');
    
    -- Test for farmer
    v_result := CHECK_USER_RESTRICTION('FARMER', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('Farmer: ' || SUBSTR(v_result,
        INSTR(v_result, '"reason": "') + 11,
        INSTR(v_result, '"}') - INSTR(v_result, '"reason": "') - 11
    ));
    
    -- Test for admin
    v_result := CHECK_USER_RESTRICTION('ADMIN', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('Admin: ' || SUBSTR(v_result,
        INSTR(v_result, '"reason": "') + 11,
        INSTR(v_result, '"}') - INSTR(v_result, '"reason": "') - 11
    ));
END;
/

-- Test 3: Try to insert data (actual test)
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 3: Actual Insert Test ===');
    
    -- First, check if we're in a survey period
    DECLARE
        v_check VARCHAR2(1000);
        v_allowed CHAR(1);
    BEGIN
        v_check := CHECK_SURVEY_PERIOD(SYSDATE);
        v_allowed := SUBSTR(v_check, 
            INSTR(v_check, '"allowed": "') + 12, 1);
        
        IF v_allowed = 'Y' THEN
            DBMS_OUTPUT.PUT_LINE('In survey period - insert should succeed');
            -- Try to insert
            BEGIN
                INSERT INTO COUNTIES (COUNTY_NAME, TOTAL_HOUSEHOLDS, FARMING_HOUSEHOLDS)
                VALUES ('TEST_SURVEY_COUNTY', 5000, 3000);
                DBMS_OUTPUT.PUT_LINE('✓ Insert succeeded (in survey period)');
                ROLLBACK;
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('✗ Insert failed unexpectedly: ' || SQLERRM);
            END;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Outside survey period - insert should fail');
            -- Try to insert (should fail)
            BEGIN
                INSERT INTO COUNTIES (COUNTY_NAME, TOTAL_HOUSEHOLDS, FARMING_HOUSEHOLDS)
                VALUES ('TEST_SURVEY_COUNTY', 5000, 3000);
                DBMS_OUTPUT.PUT_LINE('✗ Insert should have failed but succeeded');
                ROLLBACK;
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('✓ Insert correctly blocked: ' || SQLERRM);
            END;
        END IF;
    END;
END;
/

-- Test 4: Verify audit logging
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 4: Audit Log Verification ===');
    
    DECLARE
        v_count_before NUMBER;
        v_count_after NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count_before FROM AGRIC_SURVEY_AUDIT;
        
        -- Perform test operations
        BEGIN
            INSERT INTO COUNTIES (COUNTY_NAME, TOTAL_HOUSEHOLDS, FARMING_HOUSEHOLDS)
            VALUES ('AUDIT_TEST_1', 1000, 500);
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        SELECT COUNT(*) INTO v_count_after FROM AGRIC_SURVEY_AUDIT;
        
        DBMS_OUTPUT.PUT_LINE('Audit records before: ' || v_count_before);
        DBMS_OUTPUT.PUT_LINE('Audit records after: ' || v_count_after);
        DBMS_OUTPUT.PUT_LINE('Difference: ' || (v_count_after - v_count_before));
        
        IF v_count_after > v_count_before THEN
            DBMS_OUTPUT.PUT_LINE('✓ Audit logging is working');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ Audit logging may not be working');
        END IF;
    END;
END;
/

-- ========== STEP 10: AUDIT QUERIES ==========

-- Query 1: Survey Activity Summary
SELECT '=== SURVEY ACTIVITY SUMMARY ===' FROM DUAL;

SELECT 
    USER_TYPE,
    TABLE_NAME,
    DML_OPERATION,
    OPERATION_STATUS,
    COUNT(*) AS OPERATION_COUNT,
    MIN(AUDIT_TIMESTAMP) AS FIRST_OPERATION,
    MAX(AUDIT_TIMESTAMP) AS LAST_OPERATION
FROM AGRIC_SURVEY_AUDIT
GROUP BY USER_TYPE, TABLE_NAME, DML_OPERATION, OPERATION_STATUS
ORDER BY USER_TYPE, TABLE_NAME, DML_OPERATION;

-- Query 2: Denied Operations Report
SELECT '=== DENIED OPERATIONS REPORT ===' FROM DUAL;

SELECT 
    TO_CHAR(AUDIT_TIMESTAMP, 'DD-MON-YYYY HH24:MI') AS TIMESTAMP,
    USERNAME,
    USER_TYPE,
    TABLE_NAME,
    DML_OPERATION,
    DENIAL_REASON,
    IS_WITHIN_PERIOD
FROM AGRIC_SURVEY_AUDIT
WHERE OPERATION_STATUS = 'DENIED'
ORDER BY AUDIT_TIMESTAMP DESC;

-- Query 3: Successful Operations by User Type
SELECT '=== SUCCESSFUL OPERATIONS BY USER TYPE ===' FROM DUAL;

SELECT 
    USER_TYPE,
    COUNT(*) AS TOTAL_OPERATIONS,
    COUNT(DISTINCT USERNAME) AS UNIQUE_USERS,
    LISTAGG(DISTINCT TABLE_NAME, ', ') WITHIN GROUP (ORDER BY TABLE_NAME) AS TABLES_ACCESSED
FROM AGRIC_SURVEY_AUDIT
WHERE OPERATION_STATUS = 'ALLOWED'
GROUP BY USER_TYPE
ORDER BY TOTAL_OPERATIONS DESC;

-- Query 4: Operations Timeline
SELECT '=== OPERATIONS TIMELINE (LAST 7 DAYS) ===' FROM DUAL;

SELECT 
    TRUNC(AUDIT_TIMESTAMP) AS OPERATION_DATE,
    COUNT(*) AS DAILY_OPERATIONS,
    COUNT(CASE WHEN OPERATION_STATUS = 'ALLOWED' THEN 1 END) AS ALLOWED,
    COUNT(CASE WHEN OPERATION_STATUS = 'DENIED' THEN 1 END) AS DENIED
FROM AGRIC_SURVEY_AUDIT
WHERE AUDIT_TIMESTAMP >= SYSDATE - 7
GROUP BY TRUNC(AUDIT_TIMESTAMP)
ORDER BY OPERATION_DATE DESC;

SELECT '=== PART VII COMPLETED: SURVEY DATA ENTRY RESTRICTIONS IMPLEMENTED ===' FROM DUAL;