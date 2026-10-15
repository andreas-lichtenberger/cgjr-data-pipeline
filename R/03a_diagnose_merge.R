library(dplyr)

wdi <- read.csv("data/processed/wdi_long.csv", stringsAsFactors = FALSE)
ilostat <- read.csv("data/processed/ilostat_long.csv", stringsAsFactors = FALSE)
indicators <- read.csv("config/indicators.csv", stringsAsFactors = FALSE)
ilo_indicator <- read.csv("config/ilostat_indicators.csv", stringsAsFactors = FALSE)
countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)

required_wdi <- c(
  "country_code", "country_name", "year", "indicator", "variable", "value", "unit"
)
required_ilo <- c(
  "country_code", "year", "indicator", "value", "source", "status",
  "status_label", "source_label", "unit"
)
missing_wdi <- setdiff(required_wdi, names(wdi))
missing_ilo <- setdiff(required_ilo, names(ilostat))
if (length(missing_wdi) > 0L) {
  stop("WDI data is missing required columns: ", paste(missing_wdi, collapse = ", "))
}
if (length(missing_ilo) > 0L) {
  stop("ILOSTAT data is missing required columns: ", paste(missing_ilo, collapse = ", "))
}
if (nrow(ilo_indicator) != 1L) {
  stop("Expected exactly one configured ILOSTAT indicator.")
}

to_integer_year <- function(year, source_name) {
  converted <- suppressWarnings(as.integer(as.character(year)))
  if (anyNA(converted)) {
    stop(source_name, " year contains missing or non-integer values.")
  }
  converted
}

wdi$year <- to_integer_year(wdi$year, "WDI")
ilostat$year <- to_integer_year(ilostat$year, "ILOSTAT")
countries$start_year <- to_integer_year(countries$start_year, "Configured start")
countries$end_year <- to_integer_year(countries$end_year, "Configured end")

if (!is.integer(wdi$year) || !is.integer(ilostat$year)) {
  stop("WDI and ILOSTAT years must both be integer.")
}
if (!is.numeric(wdi$value) || !is.numeric(ilostat$value)) {
  stop("WDI and ILOSTAT values must both be numeric.")
}

valid_iso3 <- function(code) {
  !is.na(code) & grepl("^[A-Z]{3}$", code)
}
if (!all(valid_iso3(wdi$country_code))) {
  stop("WDI country codes are not all uppercase three-letter ISO codes.")
}
if (!all(valid_iso3(ilostat$country_code))) {
  stop("ILOSTAT country codes are not all uppercase three-letter ISO codes.")
}

wdi_duplicate_keys <- anyDuplicated(wdi[, c("country_code", "year", "indicator")])
ilo_duplicate_keys <- anyDuplicated(ilostat[, c("country_code", "year", "indicator")])
if (wdi_duplicate_keys > 0L) {
  stop("WDI country-year-indicator key is not unique; diagnostics halted before joining.")
}
if (ilo_duplicate_keys > 0L) {
  stop("ILOSTAT country-year-indicator key is not unique; diagnostics halted before joining.")
}

configured_wdi_units <- setNames(indicators$unit, indicators$indicator)
wdi_unit_report <- lapply(indicators$indicator, function(code) {
  observed <- sort(unique(wdi$unit[wdi$indicator == code]))
  expected <- configured_wdi_units[[code]]
  if (length(observed) != 1L || !identical(observed, expected)) {
    stop("WDI unit mismatch for ", code, "; expected '", expected,
         "', observed: ", paste(observed, collapse = ", "))
  }
  data.frame(
    source = "WDI",
    indicator = code,
    expected_unit = expected,
    observed_units = paste(observed, collapse = ", "),
    severity = "STOP",
    result = "PASS",
    stringsAsFactors = FALSE
  )
})
ilo_observed_units <- sort(unique(ilostat$unit))
if (length(ilo_observed_units) != 1L ||
    !identical(ilo_observed_units, ilo_indicator$unit[[1]])) {
  stop(
    "ILOSTAT unit mismatch; expected '", ilo_indicator$unit[[1]],
    "', observed: ", paste(ilo_observed_units, collapse = ", ")
  )
}
unit_report <- bind_rows(
  bind_rows(wdi_unit_report),
  data.frame(
    source = "ILOSTAT",
    indicator = ilo_indicator$dataset_id[[1]],
    expected_unit = ilo_indicator$unit[[1]],
    observed_units = paste(ilo_observed_units, collapse = ", "),
    severity = "STOP",
    result = "PASS",
    stringsAsFactors = FALSE
  )
)

wdi_codes <- sort(unique(wdi$country_code))
ilo_codes <- sort(unique(ilostat$country_code))
configured_codes <- sort(unique(countries$country_code))
wdi_only_codes <- setdiff(wdi_codes, ilo_codes)
ilo_only_codes <- setdiff(ilo_codes, wdi_codes)
not_configured_codes <- setdiff(union(wdi_codes, ilo_codes), configured_codes)
country_code_result <- if (length(wdi_only_codes) == 0L &&
                           length(ilo_only_codes) == 0L &&
                           length(not_configured_codes) == 0L) {
  "PASS"
} else {
  "REVIEW"
}

if (nrow(distinct(wdi, country_code, year, country_name)) !=
    nrow(distinct(wdi, country_code, year))) {
  stop("WDI country-year keys map to multiple country names.")
}
wdi_wide <- distinct(wdi, country_code, country_name, year)
for (variable_name in indicators$variable) {
  series <- wdi |>
    filter(variable == variable_name) |>
    select(country_code, year, value)
  if (anyDuplicated(series[, c("country_code", "year")])) {
    stop("WDI country-year key is not unique for variable ", variable_name, ".")
  }
  names(series)[names(series) == "value"] <- variable_name
  wdi_wide <- left_join(wdi_wide, series, by = c("country_code", "year"))
}
if (anyDuplicated(wdi_wide[, c("country_code", "year")])) {
  stop("WDI country-year key is not unique after reshaping.")
}
if (anyDuplicated(ilostat[, c("country_code", "year")])) {
  stop("ILOSTAT country-year key is not unique for the selected dataset.")
}

ilo_detail <- ilostat |>
  select(
    country_code, year, indicator, value, unit, source, status, status_label,
    source_label, sex, sex_label, classif1, classif1_label
  ) |>
  rename(
    employment_to_population = value,
    employment_to_population_unit = unit,
    employment_to_population_indicator = indicator,
    employment_to_population_source = source,
    employment_to_population_status = status,
    employment_to_population_status_label = status_label,
    employment_to_population_source_label = source_label,
    employment_to_population_sex = sex,
    employment_to_population_sex_label = sex_label,
    employment_to_population_classif1 = classif1,
    employment_to_population_classif1_label = classif1_label
  )

merge_detail <- full_join(
  mutate(wdi_wide, wdi_present = TRUE),
  mutate(ilo_detail, ilostat_present = TRUE),
  by = c("country_code", "year")
) |>
  mutate(
    merge_status = case_when(
      !is.na(wdi_present) & !is.na(ilostat_present) ~ "matched",
      !is.na(wdi_present) ~ "WDI-only",
      !is.na(ilostat_present) ~ "ILOSTAT-only",
      TRUE ~ "unclassified"
    )
  ) |>
  arrange(country_code, year)

counts <- table(factor(
  merge_detail$merge_status,
  levels = c("matched", "WDI-only", "ILOSTAT-only")
))
missing_wdi_values <- sum(is.na(wdi$value))
missing_ilo_values <- sum(is.na(ilostat$value))
missing_ilo_status <- sum(is.na(ilostat$status) | ilostat$status == "")
ilo_status_available <- any(!is.na(ilostat$status) & ilostat$status != "")
status_severity <- if (ilo_status_available && missing_ilo_status > 0L) {
  "WARNING"
} else if (ilo_status_available) {
  "INFORMATIONAL"
} else {
  "INFORMATIONAL"
}
status_result <- if (ilo_status_available && missing_ilo_status > 0L) {
  "Some status flags are missing; all rows and flags are retained."
} else if (ilo_status_available) {
  "Status flags are present; all rows and flags are retained."
} else {
  paste0(
    missing_ilo_status, " of ", nrow(ilostat),
    " rows have no status flag; status fields remain in the detail file."
  )
}

rows <- list(
  data.frame(
    check = "Country-code harmonization",
    severity = if (country_code_result == "PASS") "INFORMATIONAL" else "WARNING",
    result = country_code_result,
    detail = paste0(
      "Uppercase ISO3 format passed. WDI-only codes: ",
      ifelse(length(wdi_only_codes), paste(wdi_only_codes, collapse = ", "), "none"),
      "; ILOSTAT-only codes: ",
      ifelse(length(ilo_only_codes), paste(ilo_only_codes, collapse = ", "), "none"),
      "; codes outside configuration: ",
      ifelse(length(not_configured_codes), paste(not_configured_codes, collapse = ", "), "none"),
      ". No code remapping was applied."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    check = "Common integer year type",
    severity = "INFORMATIONAL",
    result = "PASS",
    detail = paste0(
      "WDI and ILOSTAT years were converted to integer. WDI range ",
      min(wdi$year), "-", max(wdi$year), "; ILOSTAT range ",
      min(ilostat$year), "-", max(ilostat$year), "."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    check = "Country-year-indicator key uniqueness",
    severity = "STOP",
    result = "PASS",
    detail = "No duplicate WDI or ILOSTAT country-year-indicator keys."
  ),
  data.frame(
    check = "Country-year join key uniqueness",
    severity = "STOP",
    result = "PASS",
    detail = "WDI wide and ILOSTAT country-year keys are unique."
  ),
  data.frame(
    check = "Units",
    severity = "INFORMATIONAL",
    result = "PASS",
    detail = paste(
      paste0(unit_report$source, " ", unit_report$indicator, "=", unit_report$observed_units),
      collapse = "; "
    )
  ),
  data.frame(
    check = "Percentage concepts",
    severity = "INFORMATIONAL",
    result = "SEPARATE",
    detail = "GDP growth and employment-to-population are distinct percentage measures and remain separate columns; no conversion or aggregation was applied."
  ),
  data.frame(
    check = "Matched country-year rows",
    severity = "INFORMATIONAL",
    result = as.character(unname(counts[["matched"]])),
    detail = "Count from the full-join diagnostic."
  ),
  data.frame(
    check = "WDI-only country-year rows",
    severity = if (counts[["WDI-only"]] > 0L) "WARNING" else "INFORMATIONAL",
    result = as.character(unname(counts[["WDI-only"]])),
    detail = "Retained in wdi_ilostat_merge_detail.csv."
  ),
  data.frame(
    check = "ILOSTAT-only country-year rows",
    severity = if (counts[["ILOSTAT-only"]] > 0L) "WARNING" else "INFORMATIONAL",
    result = as.character(unname(counts[["ILOSTAT-only"]])),
    detail = "Retained in wdi_ilostat_merge_detail.csv."
  ),
  data.frame(
    check = "Missing WDI values",
    severity = if (missing_wdi_values > 0L) "WARNING" else "INFORMATIONAL",
    result = as.character(missing_wdi_values),
    detail = "Missing values were counted, not filtered."
  ),
  data.frame(
    check = "Missing ILOSTAT values",
    severity = if (missing_ilo_values > 0L) "WARNING" else "INFORMATIONAL",
    result = as.character(missing_ilo_values),
    detail = "Missing values were counted, not filtered."
  ),
  data.frame(
    check = "ILOSTAT status flags",
    severity = status_severity,
    result = if (ilo_status_available) "PRESENT" else "NOT SUPPLIED",
    detail = status_result
  )
)
merge_report <- bind_rows(rows)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
write.csv(
  merge_detail, "data/processed/wdi_ilostat_merge_detail.csv",
  row.names = FALSE, na = ""
)
write.csv(
  merge_report, "data/processed/wdi_ilostat_merge_report.csv",
  row.names = FALSE, na = ""
)
write.csv(
  unit_report, "data/processed/wdi_ilostat_unit_report.csv",
  row.names = FALSE, na = ""
)
print(merge_report, row.names = FALSE)

warnings <- merge_report$check[merge_report$severity == "WARNING"]
if (length(warnings) > 0L) {
  warning("Review merge diagnostics: ", paste(warnings, collapse = "; "))
}
