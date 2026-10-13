# School Bus Crash Data Cleaning (SQLite)

Applies an 8-step data cleaning framework to a synthetic crash dataset, taking 825 raw rows to 794 analysis-ready rows with two engineered features (`SEASON`, `TIME_OF_DAY`).

- **Script:** [`crash_cleaning.sql`](crash_cleaning.sql): each step builds a new table so every stage can be inspected
- **Write-up:** [`report.pdf`](report.pdf): every step with the issue found, the query used, and the row count after
- **Data:** [`data/school_bus_crashes_raw.csv`](data/school_bus_crashes_raw.csv) and [`data/school_bus_crashes_cleaned.csv`](data/school_bus_crashes_cleaned.csv)

To run: load the raw CSV into SQLite as `crashes_raw` (for example with pandas `df.to_sql`), then execute the script.
