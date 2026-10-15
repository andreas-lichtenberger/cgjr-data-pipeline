# Automated validation

No new packages are required: checks use base R and the existing dplyr/ggplot2.
Source `R/05_quality_checks.R` and call `validate_pipeline()` explicitly when
working interactively. Running the file with Rscript calls it automatically.
Checks do not delete missing values, drop flags, remap countries, or change
the WDI-left analytical sample.

The concise examples below refer to the checker functions and to `wdi`, `ilo`,
`analytical`, `countries`, `calendar` and `expected` as constructed inside
`validate_pipeline()`. Classification describes the action on failure, not
whether the current data pass.

| Check | Risk | Classification | Concise R example |
| --- | --- | --- | --- |
| Required columns and nonempty inputs | An API/schema change produces incomplete data or an empty result | STOP | `require_columns(ilo, c("country_code", "year", "indicator", "value", "source", "status"))` |
| Configuration keys and year ranges | Duplicate configuration rows multiply observations; reversed windows exclude them | STOP | `check_key(countries, "country_code"); stopifnot(all(countries$start_year <= countries$end_year))` |
| Country-year-indicator uniqueness and nonmissing keys | Duplicate or blank keys multiply joins or match unrelated rows | STOP | `check_key(ilo, c("country_code", "year", "indicator"))` |
| Integer years, numeric finite-or-missing values | Fractional years can be truncated; character values or infinities corrupt calculations | STOP | `check_data(ilo)` |
| Configured countries and years | Wrong code standards or out-of-scope observations contaminate the sample | STOP | `stopifnot(all(analytical$country_code %in% countries$country_code))` |
| Missing configured country entirely | An apparently complete output silently excludes a requested country | STOP | `stopifnot(all(countries$country_code %in% analytical$country_code))` |
| Unit and population selection | Mixing sex/age groups or a proportion with a percentage changes interpretation | STOP | `stopifnot(all(ilo$unit == "percent"), all(ilo$sex == "SEX_T"), all(ilo$classif1 == "AGE_YTHADULT_YGE15"))` |
| Employment-to-population bounds | A ratio in percent cannot be below zero or above 100 | STOP | `check_bounds(ilo$value, 0, 100)` |
| Nonnegative GDP-per-capita and population | Negative levels are invalid for the selected series | STOP | `check_bounds(wdi$value[wdi$variable %in% c("population", "gdp_per_capita")], 0)` |
| GDP-growth lower bound | A decline below -100 percent is inconsistent with nonnegative GDP levels | STOP | `check_bounds(wdi$value[wdi$variable == "gdp_growth"], -100)` |
| Extreme GDP-growth magnitude | A large annual movement may be genuine, but merits review | WARNING | `if (any(abs(wdi$value[wdi$variable == "gdp_growth"]) > 50, na.rm = TRUE)) warning("Review extreme growth")` |
| Missing values and absent configured years | Coverage can deteriorate even when every country appears | WARNING | `if (anyNA(ilo$value)) warning("Missing ILO values"); anti_join(calendar, analytical, by = c("country_code", "year"))` |
| Missing source identifiers | Provenance is lost | WARNING | `if (anyNA(ilo$source) || any(ilo$source == "")) warning("Missing source")` |
| Missing/blank status count | A blank flag must not be treated as an assurance of quality | INFORMATION | `message(sum(is.na(ilo$status) | ilo$status == ""), " missing/blank status flags")` |
| Unique country-year keys before joins | Joining multiple sources or indicators on country-year can multiply rows | STOP | `check_key(ilo, c("country_code", "year"))` |
| Unmatched country-years | A left join omits ILO-only keys; an inner join could also discard WDI-only keys | WARNING plus INFORMATION counts | `anti_join(ilo, distinct(wdi, country_code, year), by = c("country_code", "year"))` |
| Join cardinality and analytical-key preservation | Silent row loss or multiplication changes the sample | STOP | `stopifnot(nrow(analytical) == nrow(distinct(wdi, country_code, year)))` |
| Values and source/status retained after joining | A wrong join or filtering of flags can silently alter observations | STOP | `left_join(analytical[c("country_code", "year")], ilo, by = c("country_code", "year"))` is compared field-by-field with the analytical columns |
| Full-join diagnostic counts | Stale diagnostics can misrepresent the current sample | STOP | `stopifnot(nrow(detail) == matched + wdi_only + ilo_only)` plus separate category-count assertions |
| Previous-calendar-year growth identity | Reverse ordering or cross-country lagging gives the wrong derived growth | WARNING | `100 * (current_gdp_per_capita / previous_same_country_gdp_per_capita - 1)` is independently compared with the stored series |
| Latest WDI table identity | Selecting the first ascending year contradicts the latest-value description | WARNING | `group_by(analytical, country_code) |> filter(!is.na(gdp_growth)) |> slice_max(year, n = 1)` is compared with the saved table |
| ILO table and rendered plot consistency | A nonempty file can still contain the wrong countries, years or values | STOP in tests | `source("tests/test_ilostat_analysis.R")` checks rendered point keys/values, latest values, coverage, gaps and statuses |
| Files exist and are nonempty | Missing, empty or stale outputs may look like a completed run | STOP | `stopifnot(all(file.exists(expected)), all(file.info(expected)$size > 0))` |
| End-to-end clean-session run | Hidden global objects or old outputs mask missing dependencies or run-order errors | STOP on execution errors; warnings remain visible | Run `Rscript --vanilla tests/run_clean_pipeline.R` |

The 50-percent growth threshold is a review heuristic, not an economic
identity. No upper bound is imposed on positive GDP growth. Bounds check
consistency with the unit labels; those labels alone cannot independently
authenticate the original provider's units.

## Execution and interpretation

From the repository root:

```r
source("R/05_quality_checks.R")
validate_pipeline()
source("tests/test_quality_checks.R")
```

For an independent end-to-end run, use a terminal:

```text
Rscript --vanilla tests/run_clean_pipeline.R
```

This runner copies only code, configuration and tests into a temporary
directory, downloads fresh WDI/ILOSTAT data, executes every stage in order
with separate script environments, and runs all tests. It copies no existing
data or output files. The temporary directory is removed even on failure;
the real project's data and outputs are untouched. Network access and the
already documented R packages are required. A network failure is a failed
online run, not a skipped test or proof of a data defect.

An exit code of zero establishes execution/structural success, not absence
of analytical warnings. The current GDP-per-capita growth and WDI latest-year
table checks deliberately warn about known inconsistencies; this validation
task does not change their formulas or output definitions. Review those
warnings before using the outputs in a publication.
