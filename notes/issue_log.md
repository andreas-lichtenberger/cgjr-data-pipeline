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
