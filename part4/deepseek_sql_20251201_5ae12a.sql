-- Memory Configuration Script
-- Author: Fatime
-- Date: December 2025

-- Set memory parameters
ALTER SYSTEM SET SGA_TARGET=1G SCOPE=BOTH;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET=500M SCOPE=BOTH;

-- Verify memory settings
SELECT name, value, isdefault, description 
FROM v$parameter 
WHERE name IN ('sga_target', 'pga_aggregate_target');

-- Show current memory allocation
SELECT component, current_size/1024/1024 as current_size_mb,
       min_size/1024/1024 as min_size_mb,
       max_size/1024/1024 as max_size_mb
FROM v$memory_dynamic_components 
WHERE current_size > 0;