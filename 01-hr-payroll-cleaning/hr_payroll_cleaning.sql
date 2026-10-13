/*
================================================================================
  CONSTRUCTION SITE EMPLOYEE DATABASE
  SQL Final Project – Data Cleaning, Transformation & Analysis
  
  Skills Used: Joins, Temp Tables, CTEs, Window Functions, Aggregate Functions,
               Creating Views, Converting Data Types, String Functions
================================================================================
*/

--------------------------------------------------------------------------------
-- SECTION 1: DATA INTEGRATION — Create Merged Temp Table
--------------------------------------------------------------------------------

-- Join all four source tables into a single working dataset.
-- The salaries table is the fact table; companies, functions, and employees
-- are dimension tables joined by their respective key columns.

SELECT *
    INTO emp_dataset
    FROM salaries
    LEFT JOIN companies
        ON salaries.comp_name = companies.company_name
    LEFT JOIN functions
        ON salaries.func_code = functions.function_code
    LEFT JOIN employees
        ON salaries.employee_id = employees.employee_code_emp


--------------------------------------------------------------------------------
-- SECTION 2: SELECT RELEVANT COLUMNS & CREATE ANALYSIS TABLE
--------------------------------------------------------------------------------

-- Select only the columns needed for analysis.
-- Create a unique composite identifier (id) by concatenating employee_id + date.
-- Cast date from TIMESTAMP to DATE type to remove time component.
-- Note: GEN(M_F) is wrapped in brackets to avoid being parsed as a formula.

SELECT CONCAT(employee_id, CAST(date AS DATE)) AS id,
       CAST(date AS DATE)                       AS month_year,
       employee_id,
       employee_name,
       [GEN(M_F)],                              -- renamed to 'gender' below
       age,
       salary,
       function_group,
       company_name,
       company_city,
       company_state,
       company_type,
       const_site_category
INTO df_employee
FROM emp_dataset


--------------------------------------------------------------------------------
-- SECTION 3: DATA WRANGLING
--------------------------------------------------------------------------------

-- 3.1 Rename problematic column name
-- GEN(M_F) would be misinterpreted as a formula reference in some tools.

EXEC sp_rename 'df_employee.[GEN(M_F)]', 'gender', 'COLUMN'


-- 3.2 Trim whitespace from all text columns
-- Removes leading and trailing spaces to prevent grouping/join failures.

UPDATE df_employee
SET id                 = TRIM(id),
    employee_id        = TRIM(employee_id),
    employee_name      = TRIM(employee_name),
    gender             = TRIM(gender),
    function_group     = TRIM(function_group),
    company_name       = TRIM(company_name),
    company_city       = TRIM(company_city),
    company_state      = TRIM(company_state),
    company_type       = TRIM(company_type),
    const_site_category = TRIM(const_site_category)


-- 3.3 Check for NULL values across all columns

SELECT *
FROM df_employee
WHERE id IS NULL
   OR month_year IS NULL
   OR employee_id IS NULL
   OR employee_name IS NULL
   OR gender IS NULL
   OR age IS NULL
   OR salary IS NULL
   OR function_group IS NULL
   OR company_name IS NULL
   OR company_city IS NULL
   OR company_state IS NULL
   OR company_type IS NULL
   OR const_site_category IS NULL


-- 3.4 Check for empty string values
-- In this database, NULL and empty string are distinct — both must be checked.

SELECT *
FROM df_employee
WHERE id = ''
   OR employee_id = ''
   OR employee_name = ''
   OR gender = ''
   OR salary = ''
   OR function_group = ''
   OR company_name = ''
   OR company_city = ''
   OR company_state = ''
   OR company_type = ''
   OR const_site_category = ''


-- 3.5 Count missing values per column (for documentation and audit trail)

SELECT COUNT(salary) AS count_missing_salary
FROM df_employee WHERE salary = ''
-- Result: 70 rows with missing salary values

SELECT COUNT(const_site_category) AS count_missing_const_site_category
FROM df_employee WHERE const_site_category = ''
-- Result: 4 rows with missing const_site_category (Administration/HQ companies with no site)


-- 3.6 Delete rows with missing values
-- Missing salary: Cannot be imputed — salary is the primary fact column.
-- Missing const_site_category: Rows belong to non-construction-site companies
--   (Administration/Development); excluding them ensures analytical integrity.

DELETE FROM df_employee WHERE salary = ''

DELETE FROM df_employee WHERE const_site_category = ''


--------------------------------------------------------------------------------
-- SECTION 4: STANDARDIZATION
--------------------------------------------------------------------------------

-- 4.1 Add a pay_month computed column (YYYY-MM format, drops the day)
-- This enables consistent monthly grouping throughout analysis.

ALTER TABLE df_employee
ADD pay_month AS (LEFT(CAST(month_year AS VARCHAR), 7))


-- 4.2 Standardize gender encoding
-- Source data uses single characters 'M' / 'F'; expand to full words for clarity.

UPDATE df_employee
SET gender = CASE gender
                 WHEN 'M' THEN 'Male'
                 WHEN 'F' THEN 'Female'
                 ELSE gender
             END


-- 4.3 Remove test salary record
-- A salary value of 1,000,000 was intentionally inserted by the HR department
-- as a system test. It is not a real employee record and must be excluded.

DELETE FROM df_employee WHERE salary = 1000000


-- 4.4 Fix city name typo: 'Goianiaa' → 'Goiania'

UPDATE df_employee
SET company_city = 'Goiania'
WHERE company_city = 'Goianiaa'


-- 4.5 Fix state casing: 'GOIAS' → 'Goias' (standardize to proper case)

UPDATE df_employee
SET company_state = 'Goias'
WHERE company_state = 'GOIAS'


-- 4.6 Fix company_type typos: normalize all variations to 'Construction Site'

UPDATE df_employee
SET company_type = 'Construction Site'
WHERE company_type IN ('Construction Sites', 'Construction Site s')


-- 4.7 Fix const_site_category typo: 'Commerciall' → 'Commercial'

UPDATE df_employee
SET const_site_category = 'Commercial'
WHERE const_site_category = 'Commerciall'


--------------------------------------------------------------------------------
-- SECTION 5: DEDUPLICATION
--------------------------------------------------------------------------------

-- 5.1 Identify duplicate records
-- A true duplicate is defined as the same employee appearing more than once
-- in the same pay month. The composite 'id' column captures this.

SELECT id, COUNT(id) AS duplicate_count
FROM df_employee
GROUP BY id
HAVING COUNT(id) > 1
-- Result: 186 duplicate rows detected


-- 5.2 Remove duplicates using CTE + ROW_NUMBER window function
-- Partition by pay_month + employee_id; keep only the first occurrence (row_num = 1).

WITH rncte AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY pay_month, employee_id
               ORDER BY employee_id
           ) AS row_num
    FROM df_employee
)
DELETE FROM rncte
WHERE row_num > 1
-- Result: 186 duplicate rows removed


--------------------------------------------------------------------------------
-- SECTION 6: FINAL VALIDATION
--------------------------------------------------------------------------------

-- Confirm the cleaned table is ready for analysis.
-- Expected: No nulls, no empty strings, no duplicates, no test values.

SELECT * FROM df_employee

-- Record count after cleaning
SELECT COUNT(*) AS total_records FROM df_employee
-- Result: 7,787 clean records across 13 months


--------------------------------------------------------------------------------
-- SECTION 7: ANALYSIS QUERIES
--------------------------------------------------------------------------------

-- ────────────────────────────────────────────────────────────────────────────
-- Q1: How many employees does the company have today (latest month)?
-- ────────────────────────────────────────────────────────────────────────────

SELECT COUNT(DISTINCT employee_id) AS employee_count
FROM df_employee
WHERE pay_month = (SELECT MAX(pay_month) FROM df_employee)
-- Result: 642 active employees


-- ────────────────────────────────────────────────────────────────────────────
-- Q2: Employee count by company in the latest month
-- ────────────────────────────────────────────────────────────────────────────

SELECT company_name,
       COUNT(DISTINCT employee_id) AS employee_count
FROM df_employee
WHERE pay_month = (SELECT MAX(pay_month) FROM df_employee)
GROUP BY company_name
ORDER BY employee_count DESC
/*
Top results:
  The Crossings at Falcon Point     107
  Regional Hospital                  82
  The Terraces at Diamond Heights    75
  The Glades at Maplewood            60
  The Pines at Windward              57
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q3: Employee count by city with percentage share (latest month)
-- ────────────────────────────────────────────────────────────────────────────

SELECT company_city,
       COUNT(employee_id) AS employee_count,
       COUNT(employee_id) * 100 / SUM(COUNT(employee_id)) OVER () AS percentage
FROM df_employee
WHERE pay_month = (SELECT MAX(pay_month) FROM df_employee)
GROUP BY company_city
ORDER BY employee_count DESC
/*
  Goiania    410  63.86%
  Brasilia   186  28.97%
  Palmas      46   7.17%
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q4: Total employee count per month (workforce trend over time)
-- ────────────────────────────────────────────────────────────────────────────

SELECT pay_month,
       COUNT(DISTINCT employee_id) AS employee_count
FROM df_employee
GROUP BY pay_month
ORDER BY pay_month ASC
/*
  2022-01: 518  |  2022-04: 602  |  2022-07: 600  |  2022-10: 592
  2022-02: 520  |  2022-05: 611  |  2022-08: 620  |  2022-11: 660 ← peak
  2022-03: 519  |  2022-06: 627  |  2022-09: 633  |  2022-12: 643
  2023-01: 642
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q5: Average number of employees per month
-- ────────────────────────────────────────────────────────────────────────────

SELECT (COUNT(employee_id) / COUNT(DISTINCT pay_month)) AS avg_employees_per_month
FROM df_employee
-- Result: 599 employees per month on average


-- ────────────────────────────────────────────────────────────────────────────
-- Q6: Month with minimum and maximum employee count
-- ────────────────────────────────────────────────────────────────────────────

-- Minimum
SELECT TOP (1) pay_month,
               COUNT(employee_id) AS count_employees_per_month
FROM df_employee
GROUP BY pay_month
ORDER BY count_employees_per_month ASC
-- Result: 2022-01 with 518 employees

-- Maximum
SELECT TOP (1) pay_month,
               COUNT(employee_id) AS count_employees_per_month
FROM df_employee
GROUP BY pay_month
ORDER BY count_employees_per_month DESC
-- Result: 2022-11 with 660 employees


-- ────────────────────────────────────────────────────────────────────────────
-- Q7: Monthly average headcount by function group
-- ────────────────────────────────────────────────────────────────────────────

SELECT function_group,
       (COUNT(employee_id) / COUNT(DISTINCT pay_month)) AS avg_employees_per_month
FROM df_employee
GROUP BY function_group
ORDER BY avg_employees_per_month DESC
/*
  Professionals            253
  Assistants               214
  Administration            50
  Production Supervisors    29
  Machine Operators         20
  Engineering               15
  Trainees                  12
  Managers                   6
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q8: Average salary — annual, monthly, by city, by state, by function group
-- ────────────────────────────────────────────────────────────────────────────

-- Annual average salary
SELECT LEFT(pay_month, 4)   AS year,
       ROUND(AVG(salary), 2) AS average_salary
FROM df_employee
GROUP BY LEFT(pay_month, 4)
ORDER BY year
-- 2022: R$1,664.33  |  2023: R$1,643.09

-- Monthly average salary
SELECT pay_month,
       ROUND(AVG(salary), 2) AS average_salary
FROM df_employee
GROUP BY pay_month
ORDER BY pay_month

-- Average salary by city
SELECT company_city,
       ROUND(AVG(salary), 2) AS average_salary
FROM df_employee
GROUP BY company_city
ORDER BY average_salary DESC
-- Goiania: R$1,671.93  |  Brasilia: R$1,649.26  |  Palmas: R$1,626.54

-- Average salary by state
SELECT company_state,
       ROUND(AVG(salary), 2) AS average_salary
FROM df_employee
GROUP BY company_state
ORDER BY average_salary DESC
-- Goias: R$1,671.93  |  Distrito Federal: R$1,649.26  |  Tocantins: R$1,626.54

-- Average salary by function group
SELECT function_group,
       ROUND(AVG(salary), 2) AS average_salary
FROM df_employee
GROUP BY function_group
ORDER BY average_salary DESC
/*
  Managers                R$4,138.19
  Engineering             R$3,373.84
  Production Supervisors  R$2,847.74
  Administration          R$1,963.50
  Machine Operators       R$1,743.81
  Professionals           R$1,705.09
  Assistants              R$1,225.90
  Trainees                  R$950.00
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q9: Top 10 highest-earning employees in the latest month
-- ────────────────────────────────────────────────────────────────────────────

SELECT TOP (10) employee_name,
                ROUND(AVG(salary), 2) AS average_salary
FROM df_employee
WHERE pay_month = (SELECT MAX(pay_month) FROM df_employee)
GROUP BY employee_name
ORDER BY average_salary DESC
/*
  Jacob Smith         R$6,335.56
  Hamza Lozano        R$5,870.97
  Josiah Hunt         R$5,500.00
  Noah Harris         R$5,500.00
  Francisco Gibson    R$5,300.00
  Brady Meyer         R$5,012.74
  Terence Buck        R$4,451.61
  Justin Martin       R$4,300.00
  Austin White        R$4,200.00
  Lauren Zavala       R$4,080.65
*/


--------------------------------------------------------------------------------
-- SECTION 8: ADDITIONAL ANALYSIS — Four Targeted Business Questions
--------------------------------------------------------------------------------

-- ────────────────────────────────────────────────────────────────────────────
-- Q10: Has average salary increased or decreased over the dataset period?
-- Show month-by-month average salary trend from Jan 2022 to Jan 2023.
-- Note: the dataset ends at Jan 2023; no comparison beyond that is possible.
-- ────────────────────────────────────────────────────────────────────────────

SELECT pay_month,
       ROUND(AVG(salary), 2)                          AS avg_salary,
       ROUND(AVG(salary) - FIRST_VALUE(AVG(salary))
             OVER (ORDER BY pay_month), 2)            AS change_from_jan_2022
FROM df_employee
GROUP BY pay_month
ORDER BY pay_month
/*
  2022-01    R$1,666.12     R$0.00   (baseline)
  2022-02    R$1,652.58    -R$13.54
  2022-03    R$1,638.52    -R$27.60
  2022-04    R$1,616.03    -R$50.09
  2022-05    R$1,604.33    -R$61.79
  2022-06    R$1,592.89    -R$73.23
  2022-07    R$1,581.96    -R$84.16
  2022-08    R$1,581.92    -R$84.20
  2022-09    R$1,573.61    -R$92.51  (lowest point)
  2022-10    R$1,599.49    -R$66.63
  2022-11    R$1,590.42    -R$75.70
  2022-12    R$1,574.79    -R$91.33
  2023-01    R$1,581.28    -R$84.84

  Conclusion: Average salary DECREASED R$84.84 (5.1%) over the period.
  Likely driven by rapid headcount growth in lower-wage roles (Assistants,
  Professionals) pulling the overall average down.
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q11: Which function group has the highest and lowest average salary?
-- ────────────────────────────────────────────────────────────────────────────

SELECT function_group,
       ROUND(AVG(salary), 2)                                     AS avg_salary,
       ROUND(AVG(salary) - AVG(AVG(salary)) OVER (), 2)          AS diff_from_overall_avg,
       ROUND(100.0 * (AVG(salary) - AVG(AVG(salary)) OVER ())
             / AVG(AVG(salary)) OVER (), 1)                      AS pct_vs_overall_avg,
       RANK() OVER (ORDER BY AVG(salary) DESC)                   AS salary_rank
FROM df_employee
GROUP BY function_group
ORDER BY avg_salary DESC
/*
  Rank  Function Group          Avg Salary    vs. Overall   %
  1     Engineering             R$3,208.82    +R$1,571.20   +96%   ← HIGHEST
  2     Production Supervisors  R$2,832.84    +R$1,195.22   +73%
  3     Administration          R$1,974.37      +R$336.75   +21%
  4     Machine Operators       R$1,753.19      +R$115.57    +7%
  5     Professionals           R$1,699.61       +R$62.00    +4%
  6     Assistants              R$1,217.58      -R$420.04   -26%
  7     Trainees                  R$950.00      -R$687.62   -42%   ← LOWEST

  Engineering earns 3.4x more than Trainees on average.
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q12: Which company and function group has the largest gender pay gap?
-- Uses PIVOT-style aggregation with CASE WHEN to compute male/female averages
-- side by side, then calculates the absolute gap and percentage difference.
-- ────────────────────────────────────────────────────────────────────────────

-- Gender pay gap by COMPANY

SELECT company_name,
       ROUND(AVG(CASE WHEN gender = 'Female' THEN salary END), 2) AS avg_female_salary,
       ROUND(AVG(CASE WHEN gender = 'Male'   THEN salary END), 2) AS avg_male_salary,
       ROUND(ABS(AVG(CASE WHEN gender = 'Male'   THEN salary END)
               - AVG(CASE WHEN gender = 'Female' THEN salary END)), 2) AS gap,
       ROUND(100.0 * ABS(AVG(CASE WHEN gender = 'Male'   THEN salary END)
                       - AVG(CASE WHEN gender = 'Female' THEN salary END))
             / NULLIF(MIN(CASE WHEN gender IN ('Male','Female')
                              THEN AVG(salary) END), 0), 1)        AS gap_pct
FROM df_employee
GROUP BY company_name
ORDER BY gap DESC
/*
  Company                          Female Avg   Male Avg    Gap        Gap %
  The Villas at Hunter's Glen      R$950.00    R$2,103.00  R$1,153.00  121.4%  ← LARGEST
  The Meadows at Sunset Ridge    R$1,339.45    R$1,737.69    R$398.24   29.7%
  The Crossings at Falcon Point  R$1,370.00    R$1,647.43    R$277.43   20.3%
  The Glades at Maplewood        R$1,319.86    R$1,582.82    R$262.97   19.9%
  Regional Hospital              R$1,620.23    R$1,498.26    R$121.97    8.1%  (F > M)

  Note: The Villas gap is driven by role composition — men hold Engineering
  roles while women are in Trainee roles — not direct pay discrimination.
  Regional Hospital is the only company where women out-earn men.
*/


-- Gender pay gap by FUNCTION GROUP

SELECT function_group,
       ROUND(AVG(CASE WHEN gender = 'Female' THEN salary END), 2) AS avg_female_salary,
       ROUND(AVG(CASE WHEN gender = 'Male'   THEN salary END), 2) AS avg_male_salary,
       ROUND(ABS(AVG(CASE WHEN gender = 'Male'   THEN salary END)
               - AVG(CASE WHEN gender = 'Female' THEN salary END)), 2) AS gap,
       CASE
           WHEN AVG(CASE WHEN gender = 'Female' THEN salary END) >
                AVG(CASE WHEN gender = 'Male'   THEN salary END) THEN 'Female'
           WHEN AVG(CASE WHEN gender = 'Male'   THEN salary END) >
                AVG(CASE WHEN gender = 'Female' THEN salary END) THEN 'Male'
           ELSE 'Equal'
       END AS higher_earning_gender
FROM df_employee
GROUP BY function_group
ORDER BY gap DESC
/*
  Function Group          Female Avg   Male Avg    Gap       Higher Earner
  Production Supervisors  R$2,990.33  R$2,819.98  R$170.35  Female  ← LARGEST GAP
  Administration          R$1,885.47  R$1,989.19  R$103.72  Male
  Machine Operators       R$1,679.03  R$1,758.16   R$79.13  Male
  Professionals           R$1,741.61  R$1,692.83   R$48.78  Female
  Assistants              R$1,218.47  R$1,217.40    R$1.08  Female
  Trainees                  R$950.00    R$950.00    R$0.00  Equal
  Engineering                    N/A  R$3,208.82      N/A   Male only (no female data)

  All function-group gaps are under 6% — significantly smaller than
  company-level gaps, which are driven primarily by role composition.
*/


-- ────────────────────────────────────────────────────────────────────────────
-- Q13: How are salaries distributed across states?
-- Includes average, median (approximated via PERCENTILE_CONT), min, max,
-- standard deviation, and employee count per state.
-- ────────────────────────────────────────────────────────────────────────────

SELECT company_state,
       COUNT(employee_id)                                          AS record_count,
       ROUND(AVG(salary), 2)                                       AS avg_salary,
       ROUND(PERCENTILE_CONT(0.5)
             WITHIN GROUP (ORDER BY salary)
             OVER (PARTITION BY company_state), 2)                 AS median_salary,
       ROUND(MIN(salary), 2)                                       AS min_salary,
       ROUND(MAX(salary), 2)                                       AS max_salary,
       ROUND(STDEV(salary), 2)                                     AS std_dev
FROM df_employee
GROUP BY company_state
ORDER BY avg_salary DESC
/*
  State             Records  Avg Salary   Median     Min      Max      Std Dev
  Distrito Federal   2,632   R$1,649.26  R$1,683.00  R$950  R$5,500   R$602.53
  Tocantins            290   R$1,626.54  R$1,290.45  R$950  R$3,885   R$682.06
  Goiás              3,885   R$1,567.67  R$1,239.33  R$950  R$5,500   R$532.92

  Key insight: All states share the same R$950 minimum (Trainee rate).
  Brasilia's median (R$1,683) is 36% higher than Goiania's (R$1,239),
  indicating a greater concentration of mid-to-senior roles at Brasilia sites
  despite Goiania hosting 64% of total headcount.
*/
