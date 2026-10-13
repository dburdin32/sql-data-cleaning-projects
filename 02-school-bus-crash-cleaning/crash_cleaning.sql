-- ============================================================
-- Project 2: Cleaning Crash Data
-- Full SQL Query File
-- Database: SQLite
-- ============================================================


-- ============================================================
-- STEP 0: Load raw data into database
-- (Performed via Python: df.to_sql('crashes_raw', conn))
-- ============================================================


-- ============================================================
-- STEP 1: Remove Irrelevant Data
-- Drop columns: REPORT_NUMBER, OFFICER_ID, VEHICLE_COLOR
-- ============================================================

DROP TABLE IF EXISTS crashes_step1;

CREATE TABLE crashes_step1 AS
SELECT
    CRASH_ID,
    CRASH_DATE,
    CRASH_TIME,
    COUNTY,
    INJURY_TYPE,
    WEATHER,
    ROAD_SURFACE,
    LIGHTING,
    NUM_VEHICLES,
    SPEED_LIMIT
FROM crashes_raw;

-- Verify
SELECT COUNT(*) AS row_count FROM crashes_step1;


-- ============================================================
-- STEP 2: Remove Duplicate Data
-- Keep first occurrence based on all content fields
-- ============================================================

DROP TABLE IF EXISTS crashes_step2;

CREATE TABLE crashes_step2 AS
SELECT
    CRASH_ID,
    CRASH_DATE,
    CRASH_TIME,
    COUNTY,
    INJURY_TYPE,
    WEATHER,
    ROAD_SURFACE,
    LIGHTING,
    NUM_VEHICLES,
    SPEED_LIMIT
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY CRASH_DATE, CRASH_TIME, COUNTY, INJURY_TYPE,
                         WEATHER, ROAD_SURFACE, LIGHTING,
                         NUM_VEHICLES, SPEED_LIMIT
            ORDER BY CRASH_ID
        ) AS rn
    FROM crashes_step1
)
WHERE rn = 1;

-- Verify: how many duplicates were removed
SELECT
    (SELECT COUNT(*) FROM crashes_step1) AS before_dedup,
    (SELECT COUNT(*) FROM crashes_step2) AS after_dedup,
    (SELECT COUNT(*) FROM crashes_step1) -
    (SELECT COUNT(*) FROM crashes_step2) AS duplicates_removed;


-- ============================================================
-- STEP 3: Fix Structural Errors
-- Note: Title Case standardization and malformed date removal
-- are performed in Python before loading crashes_step3.
-- The query below verifies no malformed dates remain.
-- ============================================================

-- Check for malformed dates (should return 0 rows after Python fix)
SELECT CRASH_DATE, COUNT(*) AS cnt
FROM crashes_step3
WHERE CRASH_DATE NOT LIKE '____-__-__'
   OR CRASH_DATE IS NULL
GROUP BY CRASH_DATE;

-- Check for inconsistent casing (should return 0 rows after Python fix)
SELECT DISTINCT INJURY_TYPE FROM crashes_step3 ORDER BY INJURY_TYPE;
SELECT DISTINCT WEATHER      FROM crashes_step3 ORDER BY WEATHER;
SELECT DISTINCT ROAD_SURFACE FROM crashes_step3 ORDER BY ROAD_SURFACE;
SELECT DISTINCT LIGHTING     FROM crashes_step3 ORDER BY LIGHTING;

-- Verify row count after structural fix
SELECT COUNT(*) AS row_count FROM crashes_step3;


-- ============================================================
-- STEP 4: Type Conversion
-- CRASH_HOUR extracted via Python; loaded into crashes_step4
-- Verify the new CRASH_HOUR column looks correct
-- ============================================================

-- Preview hour distribution
SELECT CRASH_HOUR, COUNT(*) AS cnt
FROM crashes_step4
GROUP BY CRASH_HOUR
ORDER BY CRASH_HOUR;


-- ============================================================
-- STEP 5: Handle Missing Data
-- Check missing value counts before fill
-- ============================================================

-- Count missing values per column
SELECT
    SUM(CASE WHEN INJURY_TYPE  IS NULL THEN 1 ELSE 0 END) AS missing_injury_type,
    SUM(CASE WHEN WEATHER      IS NULL THEN 1 ELSE 0 END) AS missing_weather,
    SUM(CASE WHEN ROAD_SURFACE IS NULL THEN 1 ELSE 0 END) AS missing_road_surface,
    SUM(CASE WHEN LIGHTING     IS NULL THEN 1 ELSE 0 END) AS missing_lighting,
    SUM(CASE WHEN CRASH_HOUR   IS NULL THEN 1 ELSE 0 END) AS missing_crash_hour
FROM crashes_step4;

-- Note: NULL fills (→ 'Unknown' / -1) are applied in Python,
-- then saved as crashes_step5. Verify below:
SELECT
    SUM(CASE WHEN INJURY_TYPE  IS NULL THEN 1 ELSE 0 END) AS missing_injury_type,
    SUM(CASE WHEN WEATHER      IS NULL THEN 1 ELSE 0 END) AS missing_weather,
    SUM(CASE WHEN ROAD_SURFACE IS NULL THEN 1 ELSE 0 END) AS missing_road_surface,
    SUM(CASE WHEN LIGHTING     IS NULL THEN 1 ELSE 0 END) AS missing_lighting,
    SUM(CASE WHEN CRASH_HOUR   IS NULL THEN 1 ELSE 0 END) AS missing_crash_hour
FROM crashes_step5;
-- All values should be 0


-- ============================================================
-- STEP 6: Standardize / Normalize
-- Merge synonymous category labels
-- Applied in Python; verify distinct values below
-- ============================================================

-- Verify weather categories after standardization
SELECT WEATHER, COUNT(*) AS cnt
FROM crashes_step6
GROUP BY WEATHER
ORDER BY cnt DESC;

-- Verify road surface categories
SELECT ROAD_SURFACE, COUNT(*) AS cnt
FROM crashes_step6
GROUP BY ROAD_SURFACE
ORDER BY cnt DESC;


-- ============================================================
-- STEP 7: Deal with Outliers
-- Valid SPEED_LIMIT range: 1 to 80 mph
-- ============================================================

-- Identify outliers
SELECT SPEED_LIMIT, COUNT(*) AS cnt
FROM crashes_step6
WHERE SPEED_LIMIT <= 0 OR SPEED_LIMIT > 80
GROUP BY SPEED_LIMIT
ORDER BY SPEED_LIMIT;

-- Remove outlier rows
DROP TABLE IF EXISTS crashes_step7;

CREATE TABLE crashes_step7 AS
SELECT *
FROM crashes_step6
WHERE SPEED_LIMIT >= 1
  AND SPEED_LIMIT <= 80;

-- Verify
SELECT
    (SELECT COUNT(*) FROM crashes_step6) AS before_outlier_removal,
    (SELECT COUNT(*) FROM crashes_step7) AS after_outlier_removal,
    (SELECT COUNT(*) FROM crashes_step6) -
    (SELECT COUNT(*) FROM crashes_step7) AS outliers_removed;


-- ============================================================
-- STEP 8: Validate Data
-- Confirm integrity of cleaned dataset
-- ============================================================

SELECT
    COUNT(*)                                          AS total_rows,
    COUNT(DISTINCT CRASH_ID)                          AS unique_crash_ids,
    SUM(CASE WHEN NUM_VEHICLES < 1
              OR NUM_VEHICLES > 10
             THEN 1 ELSE 0 END)                       AS invalid_vehicle_count,
    SUM(CASE WHEN SPEED_LIMIT < 1
              OR SPEED_LIMIT > 80
             THEN 1 ELSE 0 END)                       AS invalid_speed_limit,
    SUM(CASE WHEN INJURY_TYPE NOT IN (
                 'No Injury', 'Possible Injury',
                 'Evident Injury', 'Fatal Injury', 'Unknown')
             THEN 1 ELSE 0 END)                       AS unexpected_injury_values,
    SUM(CASE WHEN CRASH_DATE IS NULL
             THEN 1 ELSE 0 END)                       AS null_crash_dates,
    SUM(CASE WHEN LIGHTING IS NULL
             THEN 1 ELSE 0 END)                       AS null_lighting
FROM crashes_step7;
-- All invalid/null counts should be 0


-- ============================================================
-- STEP 9: Create Derived Columns — SEASON and TIME_OF_DAY
-- ============================================================

DROP TABLE IF EXISTS crashes_with_season;

CREATE TABLE crashes_with_season AS
SELECT
    CRASH_ID,
    CRASH_DATE,
    CRASH_TIME,
    CRASH_HOUR,
    CAST(strftime('%m', CRASH_DATE) AS INTEGER)       AS CRASH_MONTH,
    COUNTY,
    INJURY_TYPE,
    WEATHER,
    ROAD_SURFACE,
    LIGHTING,
    NUM_VEHICLES,
    SPEED_LIMIT,

    -- Season derived from month
    CASE
        WHEN CAST(strftime('%m', CRASH_DATE) AS INTEGER) IN (12, 1, 2)
            THEN 'Winter'
        WHEN CAST(strftime('%m', CRASH_DATE) AS INTEGER) IN (3, 4, 5)
            THEN 'Spring'
        WHEN CAST(strftime('%m', CRASH_DATE) AS INTEGER) IN (6, 7, 8)
            THEN 'Summer'
        WHEN CAST(strftime('%m', CRASH_DATE) AS INTEGER) IN (9, 10, 11)
            THEN 'Fall'
    END                                               AS SEASON,

    -- Time of day: Daytime = 6–19, Nighttime = 20–5
    CASE
        WHEN CRASH_HOUR >= 6  AND CRASH_HOUR <= 19 THEN 'Daytime'
        WHEN CRASH_HOUR >= 20 OR  CRASH_HOUR <= 5  THEN 'Nighttime'
        ELSE 'Unknown'
    END                                               AS TIME_OF_DAY

FROM crashes_step7;

-- Verify season distribution
SELECT SEASON, COUNT(*) AS cnt
FROM crashes_with_season
GROUP BY SEASON
ORDER BY cnt DESC;

-- Verify time of day distribution
SELECT TIME_OF_DAY, COUNT(*) AS cnt
FROM crashes_with_season
GROUP BY TIME_OF_DAY
ORDER BY cnt DESC;


-- ============================================================
-- STEP 10: Combine Categories
-- Injury:   'Possible Injury' + 'Evident Injury' → 'Light Injury'
-- Lighting: 'Dark-Street Lights Off' +
--           'Dark-No Street Lights'  → 'Dark'
-- ============================================================

DROP TABLE IF EXISTS crashes_final;

CREATE TABLE crashes_final AS
SELECT
    CRASH_ID,
    CRASH_DATE,
    CRASH_TIME,
    CRASH_HOUR,
    CRASH_MONTH,
    COUNTY,
    NUM_VEHICLES,
    SPEED_LIMIT,

    -- Combine injury categories
    CASE
        WHEN INJURY_TYPE IN ('Possible Injury', 'Evident Injury')
            THEN 'Light Injury'
        ELSE INJURY_TYPE
    END                                               AS INJURY_TYPE,

    WEATHER,
    ROAD_SURFACE,

    -- Combine lighting categories
    CASE
        WHEN LIGHTING IN ('Dark-Street Lights Off',
                          'Dark-No Street Lights')
            THEN 'Dark'
        ELSE LIGHTING
    END                                               AS LIGHTING,

    SEASON,
    TIME_OF_DAY

FROM crashes_with_season;

-- Verify final injury distribution
SELECT INJURY_TYPE, COUNT(*) AS cnt
FROM crashes_final
GROUP BY INJURY_TYPE
ORDER BY cnt DESC;

-- Verify final lighting distribution
SELECT LIGHTING, COUNT(*) AS cnt
FROM crashes_final
GROUP BY LIGHTING
ORDER BY cnt DESC;

-- Final row and column count check
SELECT COUNT(*) AS final_row_count FROM crashes_final;

-- Preview final dataset
SELECT * FROM crashes_final LIMIT 10;
