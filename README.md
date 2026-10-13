# SQL Data Cleaning and Analysis Projects

Two end-to-end SQL projects that take messy raw data through a documented cleaning pipeline to analysis-ready tables, then answer business questions with it.

**D'Andre Burdin** | M.S. Data Science, Hawaii Pacific University (DSCI 6600)

| Project | Data | Raw to clean | SQL techniques | Engine |
|---|---|---|---|---|
| [01 HR Payroll Cleaning and Analysis](01-hr-payroll-cleaning/) | 4 relational tables, construction company payroll | 8,049 to 7,787 records | Multi-table joins, temp tables, CTEs, `ROW_NUMBER()`, `FIRST_VALUE()`, `RANK()`, string functions, type casting | SQL Server (T-SQL) |
| [02 School Bus Crash Data Cleaning](02-school-bus-crash-cleaning/) | 825 crash reports | 825 to 794 rows, 2 derived features | 8-step cleaning framework, window-function deduplication, `CASE` feature engineering, validation checks | SQLite + pandas |

## Project 1: HR Payroll Cleaning and Analysis

A construction holding company's payroll is spread across four tables (salaries, companies, employees, job functions). The audit found **12 distinct data quality issues** before any analysis could start:

- 186 duplicate payroll rows, removed with a CTE and `ROW_NUMBER()`
- 70 null salaries and 8 HR test records (salary = R$1,000,000)
- Typos ("Goianiaa", "Commerciall"), inconsistent casing, padded whitespace
- A column name (`GEN(M_F)`) that parsed as a formula, fixed with `sp_rename`
- Timestamps stored where only the month mattered

**Analysis highlights** (13 business questions):
- Average salary fell **5.1%** over 13 months while headcount grew 23.9%, driven by hiring into lower-wage roles rather than pay cuts
- Engineering earns **2x the company average**; Trainees earn 41% below it
- The largest company-level gender pay gap (121%) traces to role mix, not unequal pay for the same role; within function groups, gaps stay under 6%

[SQL script](01-hr-payroll-cleaning/hr_payroll_cleaning.sql) | [Write-up](01-hr-payroll-cleaning/report.pdf) | [Query results](01-hr-payroll-cleaning/analysis_results.csv)

## Project 2: School Bus Crash Data Cleaning

Prepares a crash dataset for studying how injury severity relates to season, time of day, weather, road surface, and lighting. Built to mirror real crash-reporting problems: duplicates, malformed dates ("13/32/2021", "00-00-0000"), mixed casing, nulls, and impossible speed limits.

| Step | Action | Rows |
|---|---|---|
| 1 | Drop irrelevant columns (report number, officer ID, bus color) | 825 |
| 2 | Remove duplicates via `ROW_NUMBER()` over all content fields | 812 |
| 3 | Fix structural errors: casing, malformed dates | 802 |
| 4 | Type conversion, extract crash hour | 802 |
| 5 | Handle missing values explicitly (`Unknown` / -1) | 802 |
| 6 | Merge synonymous weather and road labels | 802 |
| 7 | Remove invalid speed limits | 794 |
| 8 | Validate integrity | 794 |
| + | Derive `SEASON` and `TIME_OF_DAY`; consolidate injury and lighting categories | 794 |

[SQL script](02-school-bus-crash-cleaning/crash_cleaning.sql) | [Write-up](02-school-bus-crash-cleaning/report.pdf) | [Raw data](02-school-bus-crash-cleaning/data/school_bus_crashes_raw.csv) | [Clean data](02-school-bus-crash-cleaning/data/school_bus_crashes_cleaned.csv)

## Data note

Both datasets are synthetic teaching datasets provided for coursework. Employee names, companies, and crash records are fictional.

## Contact

[LinkedIn](https://www.linkedin.com/in/d-andre-burdin-m-s-d-s-82136bb7/) | [VA loan approval ML capstone](https://github.com/dburdin32/va-loan-approval-fairness)
