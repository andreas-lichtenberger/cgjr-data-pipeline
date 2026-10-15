require_columns <- function(data, required) {
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Required columns are absent: ", paste(missing, collapse = ", "))
}

check_key <- function(data, keys) {
  require_columns(data, keys)
  if (anyNA(data[, keys]) ||
      any(vapply(data[, keys, drop = FALSE], function(x) any(as.character(x) == ""), logical(1)))) {
    stop("Key fields must not be missing or blank.")
  }
  if (anyDuplicated(data[, keys])) stop("Duplicate ", paste(keys, collapse = "-"), " keys.")
}

check_data <- function(data) {
  require_columns(data, c("country_code", "year", "indicator", "value"))
  if (!nrow(data)) stop("Dataset is empty.")
  if (!is.integer(data$year)) stop("Year must be integer.")
  if (!is.numeric(data$value)) stop("Value must be numeric.")
  check_key(data, c("country_code", "year", "indicator"))
  if (any(!is.na(data$value) & !is.finite(data$value))) stop("Values must be finite or missing.")
  if (anyNA(data$value)) warning("Missing values: investigate coverage.")
  invisible(TRUE)
}

check_bounds <- function(value, lower = -Inf, upper = Inf) {
  if (any(value < lower | value > upper, na.rm = TRUE)) {
    stop("Values outside permitted bounds [", lower, ", ", upper, "].")
  }
}

validate_pipeline <- function() {
  library(dplyr)
  read_data <- function(path) read.csv(path, stringsAsFactors = FALSE)
  countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
  indicators <- read_data("config/indicators.csv")
  ilo_config <- read_data("config/ilostat_indicators.csv")
  require_columns(countries, c("country_code", "country_name", "start_year", "end_year"))
  require_columns(indicators, c("indicator", "variable", "unit"))
  require_columns(ilo_config, c("dataset_id", "unit", "sex", "classif1"))
  check_key(countries, "country_code")
  check_key(indicators, "indicator")
  check_key(indicators, "variable")
  if (nrow(ilo_config) != 1L || anyNA(countries) ||
      !is.integer(countries$start_year) || !is.integer(countries$end_year) ||
      any(countries$start_year > countries$end_year)) stop("Invalid configuration.")

  expected <- c(
    "data/raw/wdi.csv", "data/raw/wdi_retrieval.csv",
    "data/raw/ilostat.csv", "data/raw/ilostat_retrieval.csv",
    "data/processed/wdi_long.csv", "data/processed/ilostat_long.csv",
    "data/processed/analytical.csv",
    "data/processed/wdi_ilostat_merge_detail.csv",
    "data/processed/wdi_ilostat_merge_report.csv",
    "data/processed/wdi_ilostat_unit_report.csv",
    "outputs/figures/gdp_growth.png", "outputs/tables/country_summary.csv",
    "outputs/figures/employment_to_population.png",
    "outputs/tables/employment_to_population_summary.csv"
  )
  if (!all(file.exists(expected))) {
    stop("Expected files absent: ", paste(expected[!file.exists(expected)], collapse = ", "))
  }
  if (any(file.info(expected)$size == 0 | file.info(expected)$isdir)) {
    stop("An expected file is empty or is a directory.")
  }
  require_columns(read_data("data/raw/wdi.csv"), c("iso3c", "year", indicators$indicator))
  require_columns(read_data("data/raw/ilostat.csv"),
                  c("ref_area", "time", "indicator", "obs_value", "source", "sex", "classif1"))
  wdi <- read_data("data/processed/wdi_long.csv")
  ilo <- read_data("data/processed/ilostat_long.csv")
  analytical <- read_data("data/processed/analytical.csv")
  check_data(wdi)
  check_data(ilo)
  require_columns(wdi, c("variable", "unit"))
  require_columns(ilo, c("unit", "sex", "classif1", "source", "status"))
  if (anyNA(wdi[, c("variable", "unit")]) ||
      any(!wdi$indicator %in% indicators$indicator)) {
    stop("Unexpected WDI indicator or missing variable/unit.")
  }
  require_columns(analytical, c(
    "country_code", "year", indicators$variable, "gdp_per_capita_growth",
    "employment_to_population", "employment_to_population_source",
    "employment_to_population_status"
  ))
  check_key(analytical, c("country_code", "year"))
  if (!is.integer(analytical$year)) stop("Analytical year must be integer.")
  for (data in list(wdi, ilo, analytical)) {
    index <- match(data$country_code, countries$country_code)
    if (anyNA(index) || any(data$year < countries$start_year[index] |
                           data$year > countries$end_year[index])) {
      stop("Country/year outside configured scope.")
    }
    if (!all(countries$country_code %in% data$country_code)) {
      stop("A configured country is missing entirely.")
    }
  }
  calendar <- bind_rows(lapply(seq_len(nrow(countries)), function(i) {
    data.frame(country_code = countries$country_code[i],
               year = seq.int(countries$start_year[i], countries$end_year[i]))
  }))
  for (code in indicators$indicator) {
    series <- wdi[wdi$indicator == code, ]
    definition <- indicators[indicators$indicator == code, ]
    if (!nrow(series) || anyNA(series$unit) ||
        any(series$unit != definition$unit | series$variable != definition$variable)) {
      stop("WDI variable/unit mismatch for ", code)
    }
    absent <- anti_join(calendar, series, by = c("country_code", "year"))
    if (nrow(absent)) warning(code, ": ", nrow(absent), " configured country-years absent.")
  }
  if (anyNA(ilo[, c("indicator", "unit", "sex", "classif1")]) ||
      any(ilo$indicator != ilo_config$dataset_id | ilo$unit != ilo_config$unit |
          ilo$sex != ilo_config$sex | ilo$classif1 != ilo_config$classif1)) {
    stop("ILOSTAT indicator/unit/population concept mismatch.")
  }
  check_bounds(ilo$value, 0, 100)
  check_bounds(wdi$value[wdi$variable %in% c("population", "gdp_per_capita")], 0)
  check_bounds(wdi$value[wdi$variable == "gdp_growth"], -100)
  if (any(abs(wdi$value[wdi$variable == "gdp_growth"]) > 50, na.rm = TRUE)) {
    warning("GDP growth magnitude exceeds 50 percent: review, do not automatically discard.")
  }
  if (anyNA(ilo$source) || any(ilo$source == "")) warning("Missing ILOSTAT source identifiers.")
  message("INFORMATION: ILOSTAT status flags missing/blank: ",
          sum(is.na(ilo$status) | ilo$status == ""), "/", nrow(ilo),
          "; blank status is not an inferred quality rating.")

  wdi_keys <- distinct(wdi, country_code, year)
  ilo_keys <- distinct(ilo, country_code, year)
  check_key(ilo, c("country_code", "year"))
  if (nrow(anti_join(analytical, wdi_keys, by = c("country_code", "year"))) ||
      nrow(anti_join(wdi_keys, analytical, by = c("country_code", "year")))) {
    stop("Analytical keys differ from the existing WDI-left sample.")
  }
  matched <- nrow(inner_join(wdi_keys, ilo_keys, by = c("country_code", "year")))
  wdi_only <- nrow(anti_join(wdi_keys, ilo_keys, by = c("country_code", "year")))
  ilo_only <- nrow(anti_join(ilo_keys, wdi_keys, by = c("country_code", "year")))
  message("INFORMATION: matched=", matched, "; WDI-only=", wdi_only, "; ILO-only=", ilo_only)
  if (wdi_only + ilo_only > 0L) warning("Unmatched merge keys: inspect full-join diagnostics.")
  detail <- read_data("data/processed/wdi_ilostat_merge_detail.csv")
  require_columns(detail, c("country_code", "year", "merge_status", "employment_to_population_status"))
  check_key(detail, c("country_code", "year"))
  if (nrow(detail) != matched + wdi_only + ilo_only ||
      sum(detail$merge_status == "matched") != matched ||
      sum(detail$merge_status == "WDI-only") != wdi_only ||
      sum(detail$merge_status == "ILOSTAT-only") != ilo_only) {
    stop("Merge diagnostic cardinality/count mismatch.")
  }
  same_values <- function(actual, expected) {
    isTRUE(all.equal(actual, expected, check.attributes = FALSE, tolerance = 1e-8))
  }
  for (variable in indicators$variable) {
    series <- wdi[wdi$variable == variable, c("country_code", "year", "value")]
    reference <- left_join(analytical[, c("country_code", "year")], series,
                           by = c("country_code", "year"))
    if (!same_values(analytical[[variable]], reference$value)) {
      stop("WDI values altered during merge: ", variable)
    }
  }
  reference <- left_join(analytical[, c("country_code", "year")], ilo,
                         by = c("country_code", "year"))
  for (field in c("value", "source", "status")) {
    column <- switch(field, value = "employment_to_population",
                     source = "employment_to_population_source",
                     status = "employment_to_population_status")
    if (!same_values(analytical[[column]], reference[[field]])) {
      stop("ILOSTAT values or source/status flags altered during merge: ", field)
    }
  }
  absent <- anti_join(calendar, analytical, by = c("country_code", "year"))
  if (nrow(absent)) warning(nrow(absent), " configured analytical country-years absent.")
  if (anyNA(analytical$employment_to_population)) warning("Missing analytical ILOSTAT values.")

  previous <- analytical[, c("country_code", "year", "gdp_per_capita")]
  previous$year <- previous$year + 1L
  names(previous)[3] <- "previous_gdp_per_capita"
  reference <- left_join(analytical, previous, by = c("country_code", "year"))
  expected_growth <- with(reference, 100 * (gdp_per_capita / previous_gdp_per_capita - 1))
  expected_growth[!is.finite(expected_growth)] <- NA_real_
  if (!same_values(analytical$gdp_per_capita_growth, expected_growth)) {
    warning("GDP-per-capita growth differs from same-country previous-calendar-year calculation.")
  }
  summary <- read_data("outputs/tables/country_summary.csv")
  require_columns(summary, c("country_code", "year", "gdp_growth"))
  latest <- analytical |>
    filter(!is.na(gdp_growth)) |>
    group_by(country_code) |>
    slice_max(year, n = 1, with_ties = FALSE) |>
    ungroup()
  if (!setequal(summary$country_code, latest$country_code) ||
      anyDuplicated(summary$country_code) ||
      !same_values(summary$year, latest$year[match(summary$country_code, latest$country_code)]) ||
      !same_values(summary$gdp_growth,
                   latest$gdp_growth[match(summary$country_code, latest$country_code)])) {
    warning("WDI summary does not match latest available GDP-growth observations.")
  }
  message("Structural checks passed. Review warnings before publication; no rows were removed.")
  invisible(TRUE)
}

if (sys.nframe() == 0L) validate_pipeline()