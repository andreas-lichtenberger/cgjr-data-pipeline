check_data <- function(data) {
  required <- c("country_code", "year", "indicator", "value")
  if (!all(required %in% names(data))) stop("Required columns are absent.")
  if (!is.integer(data$year)) stop("Year must be integer.")
  if (!is.numeric(data$value)) stop("Value must be numeric.")
  keys <- data[, c("country_code", "year", "indicator")]
  if (anyDuplicated(keys)) stop("Duplicate country-year-indicator keys.")
  if (anyNA(data$value)) warning("Missing values: investigate coverage.")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  clean <- read.csv("data/processed/wdi_long.csv", stringsAsFactors = FALSE)
  check_data(clean)
  countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
  if (!all(countries$country_code %in% clean$country_code)) {
    stop("A configured country is missing.")
  }
  expected <- c("outputs/figures/gdp_growth.png", "outputs/tables/country_summary.csv")
  if (!all(file.exists(expected))) stop("An expected output is absent.")
  if (any(file.info(expected)$size == 0)) stop("An expected output is empty.")
  message("Baseline checks completed. Review all warnings.")
}