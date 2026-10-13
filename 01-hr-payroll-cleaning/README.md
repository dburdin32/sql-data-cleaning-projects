# HR Payroll Cleaning and Analysis (SQL Server)

Cleans and analyzes 13 months of construction company payroll data spread across four relational tables, then answers 13 workforce and compensation questions.

- **Script:** [`hr_payroll_cleaning.sql`](hr_payroll_cleaning.sql): integration, cleaning, standardization, deduplication, validation, and analysis, with query results documented inline
- **Write-up:** [`report.pdf`](report.pdf)
- **Results:** [`analysis_results.csv`](analysis_results.csv)
- **Source tables:** [`data/`](data/) (salaries, companies, employees, functions; semicolon-delimited)

To run: import the four CSVs into SQL Server as tables with the same names, then execute the script top to bottom.
