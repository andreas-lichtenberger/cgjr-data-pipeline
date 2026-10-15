source("R/05_quality_checks.R")

clean <- read.csv("data/processed/wdi_long.csv", stringsAsFactors = FALSE)
stopifnot(nrow(clean) > 0L, isTRUE(check_data(clean)))
ilo <- read.csv("data/processed/ilostat_long.csv", stringsAsFactors = FALSE)
ilo_config <- read.csv("config/ilostat_indicators.csv", stringsAsFactors = FALSE)
countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
country_index <- match(ilo$country_code, countries$country_code)
stopifnot(
  nrow(ilo) > 0L,
  all(c("country_code", "year", "indicator", "value", "source", "status") %in% names(ilo)),
  is.integer(ilo$year),
  all(ilo$indicator == ilo_config$dataset_id[[1]]),
  all(ilo$sex == ilo_config$sex[[1]]),
  all(ilo$classif1 == ilo_config$classif1[[1]]),
  !anyNA(country_index),
  all(ilo$year >= countries$start_year[country_index]),
  all(ilo$year <= countries$end_year[country_index]),
  !anyDuplicated(ilo[, c("country_code", "year", "indicator")])
)
analytical <- read.csv("data/processed/analytical.csv", stringsAsFactors = FALSE)
stopifnot("employment_to_population" %in% names(analytical))
merge_detail <- read.csv(
  "data/processed/wdi_ilostat_merge_detail.csv", stringsAsFactors = FALSE
)
merge_report <- read.csv(
  "data/processed/wdi_ilostat_merge_report.csv", stringsAsFactors = FALSE
)
stopifnot(
  nrow(merge_detail) == length(unique(paste(merge_detail$country_code, merge_detail$year))),
  all(c("employment_to_population_status", "merge_status") %in% names(merge_detail)),
  sum(merge_detail$merge_status == "matched") ==
    as.integer(merge_report$result[merge_report$check == "Matched country-year rows"]),
  sum(merge_detail$merge_status == "WDI-only") ==
    as.integer(merge_report$result[merge_report$check == "WDI-only country-year rows"]),
  sum(merge_detail$merge_status == "ILOSTAT-only") ==
    as.integer(merge_report$result[merge_report$check == "ILOSTAT-only country-year rows"])
)
outputs <- c("outputs/figures/gdp_growth.png", "outputs/tables/country_summary.csv")
stopifnot(all(file.exists(outputs)), all(file.info(outputs)$size > 0))
message("Smoke test passed.")

fixture <- data.frame(
  country_code = c("BRA", "BRA"), year = c(2020L, 2021L),
  indicator = c("NY.GDP.MKTP.KD.ZG", "NY.GDP.MKTP.KD.ZG"),
  value = c(-3.3, 4.8)
)
stopifnot(isTRUE(check_data(fixture)))
invalid <- rbind(fixture, fixture[1, ])
duplicate_rejected <- tryCatch(
  { check_data(invalid); FALSE },
  error = function(condition) TRUE
)
if (!duplicate_rejected) stop("Edge test failed: duplicate input must raise an error.")
message("Duplicate-key edge test passed.")

validate_pipeline()