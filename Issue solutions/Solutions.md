## Issues:
- Duplicate observation added in 02_clean_wdi.R
- GDP-per-capita growth uses the wrong comparison observations in 03_merge_data.R
- The summary selects the earliest observation instead of the latest in 04_analysis.R
- Duplicate keys trigger a warning when the test requires an error (see 05_quality_checks.R and test_pipeline.R).