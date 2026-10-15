# Issue Log

## Duplicate country-year-indicator keys

- **Likely cause:** `R/02_clean_wdi.R` appended the first cleaned observation
  a second time. `R/05_quality_checks.R` only warned for duplicate keys, while
  `tests/test_pipeline.R` expects duplicated input to be rejected with an error.
- **Fix:** removed the extra row append from the cleaner and changed duplicate
  key validation from a warning to an error. No calculated series or output
  definitions were changed.
- **Validation:** sourced `R/02_clean_wdi.R`, `R/03_merge_data.R`, and
  `R/04_analysis.R` in order using R 4.5.3; completed successfully. Ran
  `tests/test_pipeline.R`; both the smoke test and duplicate-key edge test
  passed (exit code 0).
- **Additional verification tests to consider:**
  1. Check `anyDuplicated(clean[c("country_code", "year", "indicator")]) == 0`
     immediately after cleaning.
  2. Pass a fixture with a repeated country-year-indicator row to
     `check_data()` and assert that it raises an error; pass a unique-key
     fixture and assert that it returns `TRUE`.

## ILOSTAT presentation outputs (2026-10-15)

- Added `R/04b_ilostat_analysis.R` to generate a country-panel ratio chart and
  latest-value/coverage table from the cleaned analytical data, without
  changing the analytical sample or existing WDI outputs.
- Missing configured years are explicit in the display data, break line
  segments, and receive baseline tick marks. Latest values exclude missing
  values only for selection; zero-coverage countries remain in the table.
  Source/status fields are retained.
- Reviewed the proposed changes and generated figure. Increased year-label
  spacing after visual inspection to prevent crowded endpoint labels.
- Validation with R 4.5.3:
  `Rscript --vanilla tests/test_ilostat_analysis.R` passed, checking exact
  input values and metadata, rendered point country/year/value mappings,
  latest values, missing periods, gap markers, zero-coverage countries,
  retained status flags, and duplicate-key rejection.
- `Rscript --vanilla tests/test_pipeline.R` passed; `git diff --check` passed.
  SHA256 comparisons confirmed that `analytical.csv`, the GDP growth plot,
  and the existing country summary were unchanged by the test run.
- Observed table: 2023 latest values of 57.915 (Brazil), 65.653 (Indonesia),
  63.814 (Kenya), and 72.335 (Viet Nam), all percent; each has 14/14 available
  years (100% coverage). The source provides no status flags.

## Full-pipeline automated validation (2026-10-15)

- Extended `R/05_quality_checks.R` with reusable schema/key/bounds checks and
  `validate_pipeline()` for input configuration, cleaned data types, coverage,
  units/population concepts, join cardinality, retained values/source/status,
  generated files, and independent calculation/table consistency checks.
- Wired key checks into the analytical joins before they can multiply rows.
  Corrected diagnostic year conversion to reject fractional years rather than
  silently truncate them. No sample or economic calculation was changed.
- Added `tests/test_quality_checks.R` for schema, duplicate/missing keys,
  types, nonfinite values, bounds, and missing-value warnings.
- Added `tests/run_clean_pipeline.R`: a fresh-download run in a temporary
  code/configuration-only workspace, with separate stage environments and all
  tests. It does not reuse or overwrite repository data/outputs.
- Reviewed the diff and ran the focused edge tests and current-file validator:
  passed (exit code 0), with two analytical warnings described below.
- Ran `Rscript --vanilla tests/run_clean_pipeline.R` with R 4.5.3: online WDI
  and ILOSTAT retrieval, all transformations, plots, tables, and tests completed
  (exit code 0). Diagnostics: 56 matched keys, 0 WDI-only, 0 ILOSTAT-only.
- Expected review messages remain visible: no ILOSTAT status field supplied;
  GDP-per-capita growth disagrees with the previous-calendar-year identity;
  WDI summary does not select the latest available year. Execution success
  does not mean these known analytical issues are resolved.
- The check inventory, risks, concise R examples and severities are documented
  in `docs/validation.md`. No new package was introduced.
