run_clean_pipeline <- function() {
  root <- getwd()
  workspace <- tempfile("cgjr-validation-")
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  on.exit(setwd(root), add = TRUE, after = FALSE)
  if (!all(file.copy(c("R", "config", "tests"), workspace, recursive = TRUE))) {
    stop("Could not copy pipeline code/configuration into the isolated validation directory.")
  }
  setwd(workspace)
  scripts <- c(
    "R/01_download_wdi.R", "R/01b_download_ilostat.R",
    "R/02_clean_wdi.R", "R/02b_clean_ilostat.R",
    "R/03a_diagnose_merge.R", "R/03_merge_data.R",
    "R/04_analysis.R", "R/04b_ilostat_analysis.R"
  )
  for (script in scripts) {
    message("Running ", script)
    sys.source(script, envir = new.env())
  }
  checks <- new.env()
  sys.source("R/05_quality_checks.R", envir = checks)
  checks$validate_pipeline()
  for (test in c("tests/test_quality_checks.R", "tests/test_pipeline.R",
                 "tests/test_ilostat_analysis.R")) {
    sys.source(test, envir = new.env())
  }
  message("Clean-session pipeline completed; inspect warnings. Existing project data/outputs were not touched.")
}

run_clean_pipeline()
