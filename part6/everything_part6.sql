-- ============================================
-- PART VI: PL/SQL DEVELOPMENT
-- Agricultural Data Management System
-- ============================================

-- ========== STEP 1: EXCEPTION DEFINITIONS ==========
-- Custom exceptions for our agricultural system
DECLARE
    -- Custom exceptions
    invalid_county_data EXCEPTION;
    PRAGMA EXCEPTION_INIT(invalid_county_data, -20001);
    
    negative_population EXCEPTION;
    PRAGMA EXCEPTION_INIT(negative_population, -20002);
    
    no_data_found_custom EXCEPTION;
    PRAGMA EXCEPTION_INIT(no_data_found_custom, -20003);
BEGIN
    NULL; -- Just for declaration
END;
/

-- ========== STEP 2: FUNCTIONS (3-5 required) ==========

-- FUNCTION 1: Calculate farming percentage (Calculation function)
CREATE OR REPLACE FUNCTION CALC_FARMING_PERCENTAGE(
    p_total_households IN NUMBER,
    p_farming_households IN NUMBER
) RETURN VARCHAR2
IS
    v_percentage NUMBER;
    v_result VARCHAR2(50);
BEGIN
    -- Validation
    IF p_total_households <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Total households must be greater than 0');
    END IF;
    
    IF p_farming_households < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Farming households cannot be negative');
    END IF;
    
    IF p_farming_households > p_total_households THEN
        RAISE_APPLICATION_ERROR(-20003, 'Farming households cannot exceed total households');
    END IF;
    
    -- Calculation
    v_percentage := (p_farming_households / p_total_households) * 100;
    
    -- Format result
    v_result := ROUND(v_percentage, 2) || '%';
    
    RETURN v_result;
    
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        RETURN '0%';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END CALC_FARMING_PERCENTAGE;
/

-- FUNCTION 2: Validate county data (Validation function)
CREATE OR REPLACE FUNCTION VALIDATE_COUNTY_DATA(
    p_county_name IN VARCHAR2,
    p_total_households IN NUMBER
) RETURN VARCHAR2
IS
    v_validation_result VARCHAR2(100);
BEGIN
    -- Check for NULL values
    IF p_county_name IS NULL THEN
        v_validation_result := 'INVALID: County name cannot be NULL';
    ELSIF LENGTH(TRIM(p_county_name)) = 0 THEN
        v_validation_result := 'INVALID: County name cannot be empty';
    ELSIF p_total_households IS NULL THEN
        v_validation_result := 'INVALID: Total households cannot be NULL';
    ELSIF p_total_households <= 0 THEN
        v_validation_result := 'INVALID: Total households must be positive';
    ELSE
        v_validation_result := 'VALID: County data is acceptable';
    END IF;
    
    RETURN v_validation_result;
END VALIDATE_COUNTY_DATA;
/

-- FUNCTION 3: Lookup county farming intensity (Lookup function)
CREATE OR REPLACE FUNCTION GET_FARMING_INTENSITY(
    p_county_id IN NUMBER
) RETURN VARCHAR2
IS
    v_farming_percent NUMBER;
    v_intensity VARCHAR2(20);
BEGIN
    -- Calculate farming percentage
    SELECT (FARMING_HOUSEHOLDS * 100.0 / TOTAL_HOUSEHOLDS)
    INTO v_farming_percent
    FROM COUNTIES
    WHERE COUNTY_ID = p_county_id;
    
    -- Categorize intensity
    IF v_farming_percent >= 70 THEN
        v_intensity := 'HIGH';
    ELSIF v_farming_percent >= 40 THEN
        v_intensity := 'MEDIUM';
    ELSE
        v_intensity := 'LOW';
    END IF;
    
    RETURN v_intensity;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'COUNTY_NOT_FOUND';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END GET_FARMING_INTENSITY;
/

-- FUNCTION 4: Calculate average crop households (Calculation function)
CREATE OR REPLACE FUNCTION GET_AVG_CROP_HOUSEHOLDS(
    p_crop_name IN VARCHAR2
) RETURN NUMBER
IS
    v_average NUMBER;
BEGIN
    SELECT AVG(cas.HOUSEHOLDS_COUNT)
    INTO v_average
    FROM COUNTY_AGRIC_STATS cas
    JOIN CROPS c ON cas.CROP_ID = c.CROP_ID
    WHERE c.CROP_NAME = p_crop_name;
    
    -- Handle NULL result
    IF v_average IS NULL THEN
        v_average := 0;
    END IF;
    
    RETURN ROUND(v_average, 2);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END GET_AVG_CROP_HOUSEHOLDS;
/

-- FUNCTION 5: Check if county exists (Validation function)
CREATE OR REPLACE FUNCTION COUNTY_EXISTS(
    p_county_name IN VARCHAR2
) RETURN BOOLEAN
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM COUNTIES
    WHERE UPPER(COUNTY_NAME) = UPPER(p_county_name);
    
    RETURN (v_count > 0);
END COUNTY_EXISTS;
/

-- ========== STEP 3: PROCEDURES (3-5 required) ==========

-- PROCEDURE 1: Add new county (INSERT operation)
CREATE OR REPLACE PROCEDURE ADD_NEW_COUNTY(
    p_county_name IN VARCHAR2,
    p_sub_county IN VARCHAR2 DEFAULT NULL,
    p_total_households IN NUMBER,
    p_farming_households IN NUMBER,
    p_out_county_id OUT NUMBER
)
IS
    v_validation_result VARCHAR2(100);
BEGIN
    -- Validate input
    v_validation_result := VALIDATE_COUNTY_DATA(p_county_name, p_total_households);
    
    IF v_validation_result != 'VALID: County data is acceptable' THEN
        RAISE_APPLICATION_ERROR(-20001, v_validation_result);
    END IF;
    
    -- Check if county already exists
    IF COUNTY_EXISTS(p_county_name) AND p_sub_county IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'County already exists');
    END IF;
    
    -- Insert new county
    INSERT INTO COUNTIES (COUNTY_NAME, SUB_COUNTY, TOTAL_HOUSEHOLDS, FARMING_HOUSEHOLDS)
    VALUES (p_county_name, p_sub_county, p_total_households, p_farming_households)
    RETURNING COUNTY_ID INTO p_out_county_id;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('County added successfully. ID: ' || p_out_county_id);
    
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003, 'Duplicate county/sub-county combination');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20004, 'Error adding county: ' || SQLERRM);
END ADD_NEW_COUNTY;
/

-- PROCEDURE 2: Update farming statistics (UPDATE operation)
CREATE OR REPLACE PROCEDURE UPDATE_FARMING_STATS(
    p_county_id IN NUMBER,
    p_new_farming_households IN NUMBER,
    p_rows_updated OUT NUMBER
)
IS
    v_total_households NUMBER;
BEGIN
    -- Get current total households
    SELECT TOTAL_HOUSEHOLDS
    INTO v_total_households
    FROM COUNTIES
    WHERE COUNTY_ID = p_county_id;
    
    -- Validate new farming households
    IF p_new_farming_households > v_total_households THEN
        RAISE_APPLICATION_ERROR(-20005, 
            'Farming households (' || p_new_farming_households || 
            ') cannot exceed total households (' || v_total_households || ')');
    END IF;
    
    IF p_new_farming_households < 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Farming households cannot be negative');
    END IF;
    
    -- Update the record
    UPDATE COUNTIES
    SET FARMING_HOUSEHOLDS = p_new_farming_households
    WHERE COUNTY_ID = p_county_id;
    
    p_rows_updated := SQL%ROWCOUNT;
    
    IF p_rows_updated = 0 THEN
        RAISE_APPLICATION_ERROR(-20007, 'County not found');
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Updated ' || p_rows_updated || ' row(s)');
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20008, 'County ID ' || p_county_id || ' not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END UPDATE_FARMING_STATS;
/

-- PROCEDURE 3: Delete county and related data (DELETE operation)
CREATE OR REPLACE PROCEDURE DELETE_COUNTY_DATA(
    p_county_id IN NUMBER,
    p_cascade IN BOOLEAN DEFAULT FALSE
)
IS
    v_county_name VARCHAR2(100);
    v_agric_stats_count NUMBER;
BEGIN
    -- Get county name for messaging
    SELECT COUNTY_NAME INTO v_county_name
    FROM COUNTIES
    WHERE COUNTY_ID = p_county_id;
    
    -- Check if county has agricultural statistics
    SELECT COUNT(*) INTO v_agric_stats_count
    FROM COUNTY_AGRIC_STATS
    WHERE COUNTY_ID = p_county_id;
    
    IF v_agric_stats_count > 0 AND NOT p_cascade THEN
        RAISE_APPLICATION_ERROR(-20009, 
            'County has ' || v_agric_stats_count || 
            ' agricultural records. Use cascade=TRUE to delete all.');
    END IF;
    
    -- Delete agricultural statistics first (if cascade)
    IF p_cascade THEN
        DELETE FROM COUNTY_AGRIC_STATS
        WHERE COUNTY_ID = p_county_id;
        
        DBMS_OUTPUT.PUT_LINE('Deleted ' || SQL%ROWCOUNT || ' agricultural records');
    END IF;
    
    -- Delete the county
    DELETE FROM COUNTIES
    WHERE COUNTY_ID = p_county_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'County not found');
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('County "' || v_county_name || '" deleted successfully');
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20011, 'County ID ' || p_county_id || ' not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END DELETE_COUNTY_DATA;
/

-- PROCEDURE 4: Bulk insert crop data (INSERT with cursor)
CREATE OR REPLACE PROCEDURE BULK_INSERT_CROP_DATA(
    p_county_id IN NUMBER,
    p_crop_data IN SYS_REFCURSOR
)
IS
    TYPE crop_rec_type IS RECORD (
        crop_name VARCHAR2(50),
        households_count NUMBER
    );
    
    v_crop_rec crop_rec_type;
    v_crop_id NUMBER;
    v_inserted_count NUMBER := 0;
BEGIN
    -- Process each crop record from cursor
    LOOP
        FETCH p_crop_data INTO v_crop_rec;
        EXIT WHEN p_crop_data%NOTFOUND;
        
        -- Get crop ID
        BEGIN
            SELECT CROP_ID INTO v_crop_id
            FROM CROPS
            WHERE CROP_NAME = v_crop_rec.crop_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20012, 'Crop not found: ' || v_crop_rec.crop_name);
        END;
        
        -- Insert crop data
        INSERT INTO COUNTY_AGRIC_STATS (
            COUNTY_ID, CROP_ID, HOUSEHOLDS_COUNT, YEAR
        ) VALUES (
            p_county_id, v_crop_id, v_crop_rec.households_count, EXTRACT(YEAR FROM SYSDATE)
        );
        
        v_inserted_count := v_inserted_count + 1;
    END LOOP;
    
    CLOSE p_crop_data;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Inserted ' || v_inserted_count || ' crop records');
    
EXCEPTION
    WHEN OTHERS THEN
        IF p_crop_data%ISOPEN THEN
            CLOSE p_crop_data;
        END IF;
        ROLLBACK;
        RAISE;
END BULK_INSERT_CROP_DATA;
/

-- ========== STEP 4: CURSORS (Explicit cursor example) ==========

-- CURSOR 1: Process county agricultural data
CREATE OR REPLACE PROCEDURE PROCESS_COUNTY_AGRIC_DATA(
    p_min_households IN NUMBER DEFAULT 1000
)
IS
    -- Explicit cursor declaration
    CURSOR county_cursor IS
        SELECT c.COUNTY_ID, c.COUNTY_NAME, c.FARMING_HOUSEHOLDS,
               CALC_FARMING_PERCENTAGE(c.TOTAL_HOUSEHOLDS, c.FARMING_HOUSEHOLDS) AS FARMING_PERCENT,
               GET_FARMING_INTENSITY(c.COUNTY_ID) AS INTENSITY
        FROM COUNTIES c
        WHERE c.FARMING_HOUSEHOLDS >= p_min_households
        ORDER BY c.FARMING_HOUSEHOLDS DESC;
    
    -- Record type for cursor
    TYPE county_rec_type IS RECORD (
        county_id COUNTIES.COUNTY_ID%TYPE,
        county_name COUNTIES.COUNTY_NAME%TYPE,
        farming_households COUNTIES.FARMING_HOUSEHOLDS%TYPE,
        farming_percent VARCHAR2(50),
        intensity VARCHAR2(20)
    );
    
    v_county_rec county_rec_type;
    v_processed_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Processing counties with >= ' || p_min_households || ' farming households');
    DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 60, '='));
    
    -- Open cursor
    OPEN county_cursor;
    
    -- Fetch and process each row
    LOOP
        FETCH county_cursor INTO v_county_rec;
        EXIT WHEN county_cursor%NOTFOUND;
        
        -- Process the record
        v_processed_count := v_processed_count + 1;
        
        DBMS_OUTPUT.PUT_LINE(
            'County: ' || v_county_rec.county_name || 
            ' | ID: ' || v_county_rec.county_id ||
            ' | Farming: ' || TO_CHAR(v_county_rec.farming_households, '999,999,999') ||
            ' | Percent: ' || v_county_rec.farming_percent ||
            ' | Intensity: ' || v_county_rec.intensity
        );
        
        -- Example: Update based on intensity
        IF v_county_rec.intensity = 'HIGH' THEN
            -- Could add additional processing here
            NULL;
        END IF;
    END LOOP;
    
    -- Close cursor
    CLOSE county_cursor;
    
    DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 60, '='));
    DBMS_OUTPUT.PUT_LINE('Total counties processed: ' || v_processed_count);
    
EXCEPTION
    WHEN OTHERS THEN
        IF county_cursor%ISOPEN THEN
            CLOSE county_cursor;
        END IF;
        RAISE;
END PROCESS_COUNTY_AGRIC_DATA;
/

-- CURSOR 2: Bulk collect example (optimized)
CREATE OR REPLACE PROCEDURE BULK_PROCESS_CROP_STATS
IS
    -- Define a record type
    TYPE crop_stat_rec IS RECORD (
        crop_name CROPS.CROP_NAME%TYPE,
        total_households NUMBER,
        county_count NUMBER
    );
    
    -- Define a table type
    TYPE crop_stat_table IS TABLE OF crop_stat_rec;
    
    -- Declare the table
    v_crop_stats crop_stat_table;
    
    CURSOR crop_cursor IS
        SELECT c.CROP_NAME,
               SUM(cas.HOUSEHOLDS_COUNT) AS total_households,
               COUNT(DISTINCT cas.COUNTY_ID) AS county_count
        FROM CROPS c
        JOIN COUNTY_AGRIC_STATS cas ON c.CROP_ID = cas.CROP_ID
        GROUP BY c.CROP_NAME
        ORDER BY total_households DESC;
BEGIN
    -- Bulk collect into table
    OPEN crop_cursor;
    FETCH crop_cursor BULK COLLECT INTO v_crop_stats;
    CLOSE crop_cursor;
    
    -- Process the bulk collected data
    DBMS_OUTPUT.PUT_LINE('Top Crops by Households:');
    DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 60, '='));
    
    FOR i IN 1..LEAST(v_crop_stats.COUNT, 10) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_crop_stats(i).crop_name, 20) || ' | ' ||
            RPAD(TO_CHAR(v_crop_stats(i).total_households, '999,999,999'), 15) || ' households | ' ||
            RPAD(v_crop_stats(i).county_count, 3) || ' counties'
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 60, '='));
    DBMS_OUTPUT.PUT_LINE('Total crops processed: ' || v_crop_stats.COUNT);
    
END BULK_PROCESS_CROP_STATS;
/

-- ========== STEP 5: WINDOW FUNCTIONS ==========

-- WINDOW FUNCTION 1: ROW_NUMBER, RANK, DENSE_RANK
CREATE OR REPLACE PROCEDURE ANALYZE_COUNTY_RANKINGS
IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('County Rankings by Farming Households:');
    DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 80, '='));
    
    FOR rec IN (
        SELECT 
            COUNTY_NAME,
            FARMING_HOUSEHOLDS,
            ROW_NUMBER() OVER (ORDER BY FARMING_HOUSEHOLDS DESC) AS row_num,
            RANK() OVER (ORDER BY FARMING_HOUSEHOLDS DESC) AS rank_pos,
            DENSE_RANK() OVER (ORDER BY FARMING_HOUSEHOLDS DESC) AS dense_rank_pos,
            ROUND((FARMING_HOUSEHOLDS * 100.0 / TOTAL_HOUSEHOLDS), 2) AS farming_percent
        FROM COUNTIES
        WHERE COUNTY_NAME != 'KENYA'
        ORDER BY FARMING_HOUSEHOLDS DESC
        FETCH FIRST 10 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            'Row#' || LPAD(rec.row_num, 3) || 
            ' | Rank: ' || LPAD(rec.rank_pos, 3) ||
            ' | Dense Rank: ' || LPAD(rec.dense_rank_pos, 3) ||
            ' | County: ' || RPAD(rec.COUNTY_NAME, 20) ||
            ' | Farming: ' || LPAD(TO_CHAR(rec.FARMING_HOUSEHOLDS, '999,999,999'), 12) ||
            ' | Percent: ' || LPAD(rec.farming_percent || '%', 8)
        );
    END LOOP;
END ANALYZE_COUNTY_RANKINGS;
/

-- WINDOW FUNCTION 2: LAG, LEAD with PARTITION BY
CREATE OR REPLACE PROCEDURE ANALYZE_CROP_TRENDS
IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Crop Production Trends (Using LAG/LEAD):');
    DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 90, '='));
    
    FOR rec IN (
        SELECT 
            COUNTY_NAME,
            CROP_NAME,
            HOUSEHOLDS_COUNT,
            LAG(HOUSEHOLDS_COUNT) OVER (
                PARTITION BY COUNTY_NAME 
                ORDER BY HOUSEHOLDS_COUNT DESC
            ) AS prev_crop_households,
            LEAD(HOUSEHOLDS_COUNT) OVER (
                PARTITION BY COUNTY_NAME 
                ORDER BY HOUSEHOLDS_COUNT DESC
            ) AS next_crop_households,
            HOUSEHOLDS_COUNT - LAG(HOUSEHOLDS_COUNT, 1, 0) OVER (
                PARTITION BY COUNTY_NAME 
                ORDER BY HOUSEHOLDS_COUNT DESC
            ) AS diff_from_prev,
            ROUND(
                AVG(HOUSEHOLDS_COUNT) OVER (
                    PARTITION BY COUNTY_NAME
                ), 0
            ) AS avg_county_households
        FROM (
            SELECT c.COUNTY_NAME, cr.CROP_NAME, cas.HOUSEHOLDS_COUNT
            FROM COUNTIES c
            JOIN COUNTY_AGRIC_STATS cas ON c.COUNTY_ID = cas.COUNTY_ID
            JOIN CROPS cr ON cas.CROP_ID = cr.CROP_ID
            WHERE cas.CROP_ID IS NOT NULL
            AND c.COUNTY_NAME != 'KENYA'
        )
        WHERE ROWNUM <= 20
        ORDER BY COUNTY_NAME, HOUSEHOLDS_COUNT DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.COUNTY_NAME, 15) || ' | ' ||
            RPAD(rec.CROP_NAME, 15) || ' | ' ||
            LPAD(TO_CHAR(rec.HOUSEHOLDS_COUNT, '999,999'), 10) || ' households | ' ||
            'Prev: ' || LPAD(NVL(TO_CHAR(rec.prev_crop_households, '999,999'), 'N/A'), 9) || ' | ' ||
            'Next: ' || LPAD(NVL(TO_CHAR(rec.next_crop_households, '999,999'), 'N/A'), 9) || ' | ' ||
            'Avg County: ' || LPAD(TO_CHAR(rec.avg_county_households, '999,999'), 10)
        );
    END LOOP;
END ANALYZE_CROP_TRENDS;
/

-- WINDOW FUNCTION 3: Aggregates with OVER clause
CREATE OR REPLACE FUNCTION GET_COUNTY_STATS_WINDOW(
    p_county_id IN NUMBER
) RETURN SYS_REFCURSOR
IS
    v_result SYS_REFCURSOR;
BEGIN
    OPEN v_result FOR
        SELECT 
            c.COUNTY_NAME,
            cr.CROP_NAME,
            cas.HOUSEHOLDS_COUNT,
            ROUND(AVG(cas.HOUSEHOLDS_COUNT) OVER (
                PARTITION BY c.COUNTY_ID
            ), 0) AS avg_households,
            SUM(cas.HOUSEHOLDS_COUNT) OVER (
                PARTITION BY c.COUNTY_ID
            ) AS total_county_households,
            ROUND((cas.HOUSEHOLDS_COUNT * 100.0 / 
                SUM(cas.HOUSEHOLDS_COUNT) OVER (
                    PARTITION BY c.COUNTY_ID
                )), 2) AS percent_of_total,
            RANK() OVER (
                PARTITION BY c.COUNTY_ID 
                ORDER BY cas.HOUSEHOLDS_COUNT DESC
            ) AS crop_rank
        FROM COUNTIES c
        JOIN COUNTY_AGRIC_STATS cas ON c.COUNTY_ID = cas.COUNTY_ID
        JOIN CROPS cr ON cas.CROP_ID = cr.CROP_ID
        WHERE c.COUNTY_ID = p_county_id
        AND cas.CROP_ID IS NOT NULL
        ORDER BY cas.HOUSEHOLDS_COUNT DESC;
    
    RETURN v_result;
END GET_COUNTY_STATS_WINDOW;
/

-- ========== STEP 6: PACKAGES ==========

-- PACKAGE 1: COUNTY_MANAGEMENT_PKG
CREATE OR REPLACE PACKAGE COUNTY_MANAGEMENT_PKG AS
    -- Public function declarations
    FUNCTION CALC_FARMING_PERCENTAGE(
        p_total_households IN NUMBER,
        p_farming_households IN NUMBER
    ) RETURN VARCHAR2;
    
    FUNCTION VALIDATE_COUNTY_DATA(
        p_county_name IN VARCHAR2,
        p_total_households IN NUMBER
    ) RETURN VARCHAR2;
    
    -- Public procedure declarations
    PROCEDURE ADD_NEW_COUNTY(
        p_county_name IN VARCHAR2,
        p_sub_county IN VARCHAR2 DEFAULT NULL,
        p_total_households IN NUMBER,
        p_farming_households IN NUMBER,
        p_out_county_id OUT NUMBER
    );
    
    PROCEDURE UPDATE_FARMING_STATS(
        p_county_id IN NUMBER,
        p_new_farming_households IN NUMBER,
        p_rows_updated OUT NUMBER
    );
    
    PROCEDURE GET_COUNTY_REPORT(
        p_county_id IN NUMBER,
        p_report OUT SYS_REFCURSOR
    );
    
    -- Public cursor declaration
    CURSOR get_top_counties(p_limit NUMBER) RETURN COUNTIES%ROWTYPE;
    
END COUNTY_MANAGEMENT_PKG;
/

CREATE OR REPLACE PACKAGE BODY COUNTY_MANAGEMENT_PKG AS
    
    -- Implementation of farming percentage calculation
    FUNCTION CALC_FARMING_PERCENTAGE(
        p_total_households IN NUMBER,
        p_farming_households IN NUMBER
    ) RETURN VARCHAR2
    IS
        v_percentage NUMBER;
    BEGIN
        IF p_total_households <= 0 THEN
            RETURN 'INVALID: Total households <= 0';
        END IF;
        
        v_percentage := (p_farming_households / p_total_households) * 100;
        RETURN ROUND(v_percentage, 2) || '%';
    END CALC_FARMING_PERCENTAGE;
    
    -- Implementation of county data validation
    FUNCTION VALIDATE_COUNTY_DATA(
        p_county_name IN VARCHAR2,
        p_total_households IN NUMBER
    ) RETURN VARCHAR2
    IS
    BEGIN
        IF p_county_name IS NULL OR LENGTH(TRIM(p_county_name)) = 0 THEN
            RETURN 'INVALID: County name required';
        ELSIF p_total_households IS NULL OR p_total_households <= 0 THEN
            RETURN 'INVALID: Total households must be positive';
        ELSE
            RETURN 'VALID';
        END IF;
    END VALIDATE_COUNTY_DATA;
    
    -- Implementation of add new county
    PROCEDURE ADD_NEW_COUNTY(
        p_county_name IN VARCHAR2,
        p_sub_county IN VARCHAR2 DEFAULT NULL,
        p_total_households IN NUMBER,
        p_farming_households IN NUMBER,
        p_out_county_id OUT NUMBER
    )
    IS
        v_validation VARCHAR2(100);
    BEGIN
        v_validation := VALIDATE_COUNTY_DATA(p_county_name, p_total_households);
        
        IF v_validation != 'VALID' THEN
            RAISE_APPLICATION_ERROR(-20001, v_validation);
        END IF;
        
        INSERT INTO COUNTIES (
            COUNTY_NAME, SUB_COUNTY, TOTAL_HOUSEHOLDS, FARMING_HOUSEHOLDS
        ) VALUES (
            p_county_name, p_sub_county, p_total_households, p_farming_households
        )
        RETURNING COUNTY_ID INTO p_out_county_id;
        
        COMMIT;
    END ADD_NEW_COUNTY;
    
    -- Implementation of update farming stats
    PROCEDURE UPDATE_FARMING_STATS(
        p_county_id IN NUMBER,
        p_new_farming_households IN NUMBER,
        p_rows_updated OUT NUMBER
    )
    IS
    BEGIN
        UPDATE COUNTIES
        SET FARMING_HOUSEHOLDS = p_new_farming_households
        WHERE COUNTY_ID = p_county_id;
        
        p_rows_updated := SQL%ROWCOUNT;
        COMMIT;
    END UPDATE_FARMING_STATS;
    
    -- Implementation of county report
    PROCEDURE GET_COUNTY_REPORT(
        p_county_id IN NUMBER,
        p_report OUT SYS_REFCURSOR
    )
    IS
    BEGIN
        OPEN p_report FOR
            SELECT 
                c.COUNTY_NAME,
                c.TOTAL_HOUSEHOLDS,
                c.FARMING_HOUSEHOLDS,
                CALC_FARMING_PERCENTAGE(c.TOTAL_HOUSEHOLDS, c.FARMING_HOUSEHOLDS) AS FARMING_PERCENT,
                (SELECT COUNT(*) FROM COUNTY_AGRIC_STATS WHERE COUNTY_ID = c.COUNTY_ID) AS TOTAL_RECORDS,
                (SELECT COUNT(DISTINCT CROP_ID) FROM COUNTY_AGRIC_STATS WHERE COUNTY_ID = c.COUNTY_ID) AS CROP_TYPES,
                (SELECT COUNT(DISTINCT LIVESTOCK_ID) FROM COUNTY_AGRIC_STATS WHERE COUNTY_ID = c.COUNTY_ID) AS LIVESTOCK_TYPES
            FROM COUNTIES c
            WHERE c.COUNTY_ID = p_county_id;
    END GET_COUNTY_REPORT;
    
    -- Implementation of public cursor
    CURSOR get_top_counties(p_limit NUMBER) RETURN COUNTIES%ROWTYPE IS
        SELECT *
        FROM COUNTIES
        WHERE COUNTY_NAME != 'KENYA'
        ORDER BY FARMING_HOUSEHOLDS DESC
        FETCH FIRST p_limit ROWS ONLY;
        
END COUNTY_MANAGEMENT_PKG;
/

-- PACKAGE 2: AGRICULTURAL_ANALYSIS_PKG
CREATE OR REPLACE PACKAGE AGRICULTURAL_ANALYSIS_PKG AS
    
    -- Analysis functions
    FUNCTION GET_TOP_CROP(p_county_id IN NUMBER) RETURN VARCHAR2;
    FUNCTION CALC_AGRIC_DIVERSITY(p_county_id IN NUMBER) RETURN NUMBER;
    
    -- Analysis procedures
    PROCEDURE GENERATE_COUNTY_ANALYSIS(p_county_id IN NUMBER);
    PROCEDURE COMPARE_COUNTIES(p_county_id1 IN NUMBER, p_county_id2 IN NUMBER);
    
    -- Bulk operations
    PROCEDURE UPDATE_ALL_CROP_DATA(p_percentage_increase IN NUMBER);
    
END AGRICULTURAL_ANALYSIS_PKG;
/

CREATE OR REPLACE PACKAGE BODY AGRICULTURAL_ANALYSIS_PKG AS
    
    FUNCTION GET_TOP_CROP(p_county_id IN NUMBER) RETURN VARCHAR2
    IS
        v_top_crop VARCHAR2(50);
    BEGIN
        SELECT cr.CROP_NAME INTO v_top_crop
        FROM COUNTY_AGRIC_STATS cas
        JOIN CROPS cr ON cas.CROP_ID = cr.CROP_ID
        WHERE cas.COUNTY_ID = p_county_id
        AND cas.HOUSEHOLDS_COUNT = (
            SELECT MAX(HOUSEHOLDS_COUNT)
            FROM COUNTY_AGRIC_STATS
            WHERE COUNTY_ID = p_county_id
            AND CROP_ID IS NOT NULL
        )
        AND ROWNUM = 1;
        
        RETURN v_top_crop;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'No crop data';
    END GET_TOP_CROP;
    
    FUNCTION CALC_AGRIC_DIVERSITY(p_county_id IN NUMBER) RETURN NUMBER
    IS
        v_crop_types NUMBER;
        v_livestock_types NUMBER;
        v_total_types NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT CROP_ID) INTO v_crop_types
        FROM COUNTY_AGRIC_STATS
        WHERE COUNTY_ID = p_county_id
        AND CROP_ID IS NOT NULL;
        
        SELECT COUNT(DISTINCT LIVESTOCK_ID) INTO v_livestock_types
        FROM COUNTY_AGRIC_STATS
        WHERE COUNTY_ID = p_county_id
        AND LIVESTOCK_ID IS NOT NULL;
        
        v_total_types := v_crop_types + v_livestock_types;
        
        -- Diversity score: 0-10 scale
        IF v_total_types >= 10 THEN
            RETURN 10;
        ELSE
            RETURN v_total_types;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END CALC_AGRIC_DIVERSITY;
    
    PROCEDURE GENERATE_COUNTY_ANALYSIS(p_county_id IN NUMBER)
    IS
        v_county_name COUNTIES.COUNTY_NAME%TYPE;
        v_farming_percent VARCHAR2(50);
        v_top_crop VARCHAR2(50);
        v_diversity_score NUMBER;
    BEGIN
        -- Get county name
        SELECT COUNTY_NAME INTO v_county_name
        FROM COUNTIES
        WHERE COUNTY_ID = p_county_id;
        
        -- Calculate farming percentage
        SELECT COUNTY_MANAGEMENT_PKG.CALC_FARMING_PERCENTAGE(
            TOTAL_HOUSEHOLDS, FARMING_HOUSEHOLDS
        ) INTO v_farming_percent
        FROM COUNTIES
        WHERE COUNTY_ID = p_county_id;
        
        -- Get top crop
        v_top_crop := GET_TOP_CROP(p_county_id);
        
        -- Calculate diversity score
        v_diversity_score := CALC_AGRIC_DIVERSITY(p_county_id);
        
        -- Output analysis
        DBMS_OUTPUT.PUT_LINE('County Analysis Report');
        DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 50, '='));
        DBMS_OUTPUT.PUT_LINE('County: ' || v_county_name);
        DBMS_OUTPUT.PUT_LINE('Farming Percentage: ' || v_farming_percent);
        DBMS_OUTPUT.PUT_LINE('Top Crop: ' || v_top_crop);
        DBMS_OUTPUT.PUT_LINE('Agricultural Diversity: ' || v_diversity_score || '/10');
        
        -- Interpretation
        IF v_diversity_score >= 7 THEN
            DBMS_OUTPUT.PUT_LINE('Interpretation: Highly diversified agriculture');
        ELSIF v_diversity_score >= 4 THEN
            DBMS_OUTPUT.PUT_LINE('Interpretation: Moderately diversified');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Interpretation: Low diversity, specialized farming');
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: County not found');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    END GENERATE_COUNTY_ANALYSIS;
    
    PROCEDURE COMPARE_COUNTIES(p_county_id1 IN NUMBER, p_county_id2 IN NUMBER)
    IS
        v_county1_name COUNTIES.COUNTY_NAME%TYPE;
        v_county2_name COUNTIES.COUNTY_NAME%TYPE;
        v_county1_farming NUMBER;
        v_county2_farming NUMBER;
    BEGIN
        -- Get county names
        SELECT COUNTY_NAME, FARMING_HOUSEHOLDS 
        INTO v_county1_name, v_county1_farming
        FROM COUNTIES WHERE COUNTY_ID = p_county_id1;
        
        SELECT COUNTY_NAME, FARMING_HOUSEHOLDS 
        INTO v_county2_name, v_county2_farming
        FROM COUNTIES WHERE COUNTY_ID = p_county_id2;
        
        DBMS_OUTPUT.PUT_LINE('County Comparison Report');
        DBMS_OUTPUT.PUT_LINE('=' || RPAD('=', 50, '='));
        DBMS_OUTPUT.PUT_LINE(v_county1_name || ': ' || TO_CHAR(v_county1_farming, '999,999') || ' farming households');
        DBMS_OUTPUT.PUT_LINE(v_county2_name || ': ' || TO_CHAR(v_county2_farming, '999,999') || ' farming households');
        
        IF v_county1_farming > v_county2_farming THEN
            DBMS_OUTPUT.PUT_LINE('Difference: ' || v_county1_name || ' has ' || 
                TO_CHAR(v_county1_farming - v_county2_farming, '999,999') || ' more farming households');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Difference: ' || v_county2_name || ' has ' || 
                TO_CHAR(v_county2_farming - v_county1_farming, '999,999') || ' more farming households');
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: One or both counties not found');
    END COMPARE_COUNTIES;
    
    PROCEDURE UPDATE_ALL_CROP_DATA(p_percentage_increase IN NUMBER)
    IS
        v_updated_count NUMBER := 0;
    BEGIN
        -- Update all crop households by percentage
        UPDATE COUNTY_AGRIC_STATS
        SET HOUSEHOLDS_COUNT = HOUSEHOLDS_COUNT * (1 + (p_percentage_increase / 100))
        WHERE CROP_ID IS NOT NULL;
        
        v_updated_count := SQL%ROWCOUNT;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Updated ' || v_updated_count || ' crop records by ' || p_percentage_increase || '%');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END UPDATE_ALL_CROP_DATA;
    
END AGRICULTURAL_ANALYSIS_PKG;
/

-- ========== STEP 7: TESTING SCRIPTS ==========

-- Test Function 1: CALC_FARMING_PERCENTAGE
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing CALC_FARMING_PERCENTAGE:');
    DBMS_OUTPUT.PUT_LINE('1000 total, 500 farming: ' || CALC_FARMING_PERCENTAGE(1000, 500));
    DBMS_OUTPUT.PUT_LINE('5000 total, 2500 farming: ' || CALC_FARMING_PERCENTAGE(5000, 2500));
    DBMS_OUTPUT.PUT_LINE('0 total, 0 farming: ' || CALC_FARMING_PERCENTAGE(0, 0));
END;
/

-- Test Function 2: VALIDATE_COUNTY_DATA
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing VALIDATE_COUNTY_DATA:');
    DBMS_OUTPUT.PUT_LINE('Valid data: ' || VALIDATE_COUNTY_DATA('Test County', 1000));
    DBMS_OUTPUT.PUT_LINE('NULL name: ' || VALIDATE_COUNTY_DATA(NULL, 1000));
    DBMS_OUTPUT.PUT_LINE('Zero households: ' || VALIDATE_COUNTY_DATA('Test', 0));
END;
/

-- Test Function 3: GET_FARMING_INTENSITY
DECLARE
    v_county_id NUMBER;
BEGIN
    -- Get a county ID for testing
    SELECT COUNTY_ID INTO v_county_id FROM COUNTIES WHERE ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('Testing GET_FARMING_INTENSITY for county ' || v_county_id);
    DBMS_OUTPUT.PUT_LINE('Intensity: ' || GET_FARMING_INTENSITY(v_county_id));
END;
/

-- Test Procedure 1: ADD_NEW_COUNTY
DECLARE
    v_new_id NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing ADD_NEW_COUNTY:');
    ADD_NEW_COUNTY(
        'TEST_COUNTY_' || TO_CHAR(SYSDATE, 'HH24MISS'),
        'TEST_SUBCOUNTY',
        5000,
        3000,
        v_new_id
    );
    DBMS_OUTPUT.PUT_LINE('New county ID: ' || v_new_id);
END;
/

-- Test Procedure 2: UPDATE_FARMING_STATS
DECLARE
    v_county_id NUMBER;
    v_rows_updated NUMBER;
BEGIN
    -- Get a county ID
    SELECT COUNTY_ID INTO v_county_id FROM COUNTIES WHERE ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('Testing UPDATE_FARMING_STATS for county ' || v_county_id);
    UPDATE_FARMING_STATS(v_county_id, 4000, v_rows_updated);
    DBMS_OUTPUT.PUT_LINE('Rows updated: ' || v_rows_updated);
END;
/

-- Test Window Functions
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing ANALYZE_COUNTY_RANKINGS:');
    ANALYZE_COUNTY_RANKINGS();
END;
/

-- Test Cursor Processing
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing PROCESS_COUNTY_AGRIC_DATA:');
    PROCESS_COUNTY_AGRIC_DATA(1000);
END;
/

-- Test Package 1
DECLARE
    v_report SYS_REFCURSOR;
    v_county_name COUNTIES.COUNTY_NAME%TYPE;
    v_total_households COUNTIES.TOTAL_HOUSEHOLDS%TYPE;
    v_farming_households COUNTIES.FARMING_HOUSEHOLDS%TYPE;
    v_farming_percent VARCHAR2(50);
    v_total_records NUMBER;
    v_crop_types NUMBER;
    v_livestock_types NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing COUNTY_MANAGEMENT_PKG.GET_COUNTY_REPORT:');
    
    -- Get first county
    SELECT COUNTY_ID INTO v_county_name FROM COUNTIES WHERE ROWNUM = 1;
    
    COUNTY_MANAGEMENT_PKG.GET_COUNTY_REPORT(v_county_name, v_report);
    
    FETCH v_report INTO v_county_name, v_total_households, v_farming_households, 
                        v_farming_percent, v_total_records, v_crop_types, v_livestock_types;
    CLOSE v_report;
    
    DBMS_OUTPUT.PUT_LINE('County: ' || v_county_name);
    DBMS_OUTPUT.PUT_LINE('Farming %: ' || v_farming_percent);
    DBMS_OUTPUT.PUT_LINE('Crop types: ' || v_crop_types);
    
END;
/

-- Test Package 2
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing AGRICULTURAL_ANALYSIS_PKG:');
    
    -- Get a county ID
    DECLARE
        v_county_id NUMBER;
    BEGIN
        SELECT COUNTY_ID INTO v_county_id FROM COUNTIES WHERE ROWNUM = 1;
        AGRICULTURAL_ANALYSIS_PKG.GENERATE_COUNTY_ANALYSIS(v_county_id);
    END;
END;
/

-- ========== STEP 8: ERROR LOGGING TABLE ==========
-- Create error logging table for exception handling
CREATE TABLE AGRIC_ERROR_LOG (
    ERROR_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ERROR_DATE TIMESTAMP DEFAULT SYSTIMESTAMP,
    PROCEDURE_NAME VARCHAR2(100),
    ERROR_CODE NUMBER,
    ERROR_MESSAGE VARCHAR2(4000),
    USER_NAME VARCHAR2(100) DEFAULT USER,
    ADDITIONAL_INFO VARCHAR2(4000)
);

-- Error logging procedure
CREATE OR REPLACE PROCEDURE LOG_ERROR(
    p_procedure_name IN VARCHAR2,
    p_error_code IN NUMBER,
    p_error_message IN VARCHAR2,
    p_additional_info IN VARCHAR2 DEFAULT NULL
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO AGRIC_ERROR_LOG (
        PROCEDURE_NAME, ERROR_CODE, ERROR_MESSAGE, ADDITIONAL_INFO
    ) VALUES (
        p_procedure_name, p_error_code, p_error_message, p_additional_info
    );
    
    COMMIT;
END LOG_ERROR;
/

SELECT '=== PART VI COMPLETED SUCCESSFULLY ===' FROM DUAL;
SELECT '=== PL/SQL COMPONENTS CREATED ===' FROM DUAL;
SELECT '=== 5 FUNCTIONS, 4 PROCEDURES, 2 CURSORS, 2 PACKAGES CREATED ===' FROM DUAL;
SELECT '=== WINDOW FUNCTIONS AND EXCEPTION HANDLING IMPLEMENTED ===' FROM DUAL;