library(dplyr)

raw <- read.csv("data/raw/ilostat.csv", stringsAsFactors = FALSE)
countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
indicator <- read.csv("config/ilostat_indicators.csv", stringsAsFactors = FALSE)
if (nrow(indicator) != 1L) stop("Expected exactly one configured ILOSTAT indicator.")

required <- c(
  "ref_area", "source", "indicator", "sex", "classif1",
  "time", "obs_value", "source.label", "sex.label", "classif1.label"
)
missing <- setdiff(required, names(raw))
if (length(missing) > 0L) {
  stop("Expected ILOSTAT columns are absent: ", paste(missing, collapse = ", "))
}
if (!all(raw$indicator == indicator$indicator_code)) {
  stop("ILOSTAT raw file contains an unexpected indicator code.")
}
selected_sex <- indicator$sex[[1]]
selected_classif1 <- indicator$classif1[[1]]

status <- if ("obs_status" %in% names(raw)) {
  as.character(raw$obs_status)
} else {
  warning("ILOSTAT supplied no observation-status field; processed status is unavailable.")
  rep(NA_character_, nrow(raw))
}
status_label <- if ("obs_status.label" %in% names(raw)) {
  as.character(raw[["obs_status.label"]])
} else {
  rep(NA_character_, nrow(raw))
}
year <- suppressWarnings(as.integer(raw$time))
value <- suppressWarnings(as.numeric(raw$obs_value))
if (anyNA(year)) stop("ILOSTAT time contains values that cannot be converted to years.")
if (any(!is.na(raw$obs_value) & is.na(value))) {
  stop("ILOSTAT observation values contain non-numeric data.")
}

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
clean <- data.frame(
  country_code = raw$ref_area,
  year = year,
  indicator = indicator$dataset_id,
  value = value,
  source = raw$source,
  status = status,
  source_label = raw$source.label,
  sex = raw$sex,
  sex_label = raw$sex.label,
  classif1 = raw$classif1,
  classif1_label = raw$classif1.label,
  status_label = status_label,
  unit = indicator$unit,
  stringsAsFactors = FALSE
) |>
  inner_join(countries[, c("country_code", "start_year", "end_year")],
             by = "country_code") |>
  filter(
    year >= start_year, year <= end_year,
    sex == selected_sex, classif1 == selected_classif1
  ) |>
  select(-start_year, -end_year) |>
  arrange(country_code, year)

if (nrow(clean) == 0L) stop("No ILOSTAT observations remain after filtering.")
if (anyDuplicated(clean[, c("country_code", "year", "indicator")])) {
  stop("Duplicate country-year-indicator keys in cleaned ILOSTAT data.")
}

write.csv(clean, "data/processed/ilostat_long.csv", row.names = FALSE, na = "")
