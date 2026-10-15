# Growth and Jobs Data Pipeline

Participant starter for the GitHub, VS Code and Copilot hands-on exercise.
Use public aggregate data only. This starter deliberately contains four
recoverable issues: execution alone does not establish analytical correctness.

## Setup

Open this repository folder in VS Code, install the four required R packages, set your working directory, create a branch

- Open New Terminal
- Click on "+" -> "R Terminal"
- Set your working directory by running 'setwd("your_path")' in the terminal. E.g. `setwd("c:/Users/wb566769/OneDrive - WBG/Documents/cgjr-data-pipeline")`
- Check the working directory by running `getwd()`
- Copy the following code then press enter: `install.packages(c("WDI", "dplyr", "ggplot2", "Rilostat"))`
- Create and publish a branch named `first name`. E.g. `yann-branch`; do not work directly on `main`.

## Baseline

The configuration selects Brazil, Indonesia, Kenya and Viet Nam for 2010-2023.
WDI supplies GDP growth, GDP per capita (constant 2015 US$) and population.

Source each script, in this order:

 R/01_download_wdi.R
 R/01b_download_ilostat.R
 R/02_clean_wdi.R
 R/02b_clean_ilostat.R
 R/03a_diagnose_merge.R
 R/03_merge_data.R
 R/04_analysis.R
 R/04b_ilostat_analysis.R
 R/05_quality_checks.R
 tests/test_pipeline.R
 tests/test_ilostat_analysis.R
 tests/test_quality_checks.R

To source a script, open it in the editor and click on the arrow on the top right or type source("filepath") in the terminal - for example `source("R/01_download_wdi.R")`

The ILOSTAT scripts download and clean the configured annual employment-to-population ratio for total sex and age 15+. The cleaned observations are joined to the WDI analytical data by country and year; the ILOSTAT source identifier and status are retained. The selected ILOSTAT dataset currently does not provide an observation-status field, so its processed status values are blank and the cleaner reports a warning.

Run `R/03a_diagnose_merge.R` after both clean scripts, then inspect `data/processed/wdi_ilostat_merge_report.csv` and `data/processed/wdi_ilostat_merge_detail.csv` before running `R/03_merge_data.R`. The diagnostic uses a full join and preserves unmatched rows, missing values, and ILOSTAT source/status metadata. It does not modify `analytical.csv` or decide which source controls the analysis sample.

The scripts create their data and output directories automatically. Downloads
and generated outputs are ignored by Git. Expected baseline outputs are
`outputs/figures/gdp_growth.png` and `outputs/tables/country_summary.csv`.
The summary is intended to describe the latest available GDP-growth observation.
Investigate warnings and failed checks, even when plots are produced.

### ILOSTAT chart and coverage table

From a fresh R session with the project root as the working directory, run
`source("R/04b_ilostat_analysis.R")` after the analytical dataset has been
generated. It writes `outputs/figures/employment_to_population.png` (300 dpi)
and `outputs/tables/employment_to_population_summary.csv`, leaving existing
WDI outputs unchanged.

The chart shows annual employment-to-population ratios for total sex, age 15+,
with a common percent scale across country panels. Points are observed entries
in the analytical dataset (ILO modelled estimates, not survey microdata).
Unavailable configured years break the lines and receive baseline tick marks;
they are not interpolated. The table gives the latest non-missing year/value,
its source/status, and coverage relative to each country's configured year range.
Countries with no values remain in the table with zero coverage and blank
latest values. Blank status means unavailable, not an inferred quality rating.

Run `source("tests/test_ilostat_analysis.R")` to compare plot values and metadata
with the analytical input, verify latest values independently, and exercise
missing-year, all-missing-country, status-retention and duplicate-key cases.
The tests regenerate the chart and table using the current analytical input.

### Full-pipeline validation

Run `source("R/05_quality_checks.R"); validate_pipeline()` to check existing
files. Sourcing the checker defines functions; call `validate_pipeline()`
explicitly. For a fresh online end-to-end run without touching existing data
or outputs, run `Rscript --vanilla tests/run_clean_pipeline.R` in a terminal.
The runner uses a temporary directory with no pre-existing generated files.
See [validation.md](docs/validation.md) for each check's risk, severity and
concise R example. Structural failures stop; coverage and known calculation
inconsistencies warn without silently removing observations.

## Your Work

1. Explain the workflow before editing; inspect the configuration and scripts.
2. Diagnose and fix at least three issues. See Issue solution if needed.
3. Add `R/01b_download_ilostat.R` and `R/02b_clean_ilostat.R`. Use an annual
   employment-to-population ratio for total sex, age 15+ (series ID: EMP_2WAP_SEX_AGE_RT_A).
4. Filter to the configured countries and years. Keep raw files in `data/raw/`.
5. Merge using explicit country-year keys after checking uniqueness and types.
   Report matched, WDI-only and ILO-only rows before deciding on the sample.
6. Add an ILOSTAT trend plot.
7. Extend quality checks for columns, keys, types, bounds, missingness, country
   coverage.
8. Update README, `docs/data_dictionary.md` from verified code and results, including the new run order.
9. Review diffs, stage only intended files, commit with a title and explanatory
   body, push and open a pull request. Leave the PR open; do not merge.

## Files You Will Use

- `config/`: country list, years and WDI indicator definitions.
- `R/`: download, clean, merge, analysis and quality-check scripts.
- `tests/test_pipeline.R`: baseline smoke test and duplicate-key edge test.
- `docs/`: working data dictionary.
- `.github/pull_request_template.md`: your submission checklist.

Never commit downloaded data, generated outputs, credentials, confidential
material or person-level records. Review Source Control before every commit.
