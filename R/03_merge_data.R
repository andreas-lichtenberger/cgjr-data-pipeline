library(dplyr)

clean <- read.csv("data/processed/wdi_long.csv", stringsAsFactors = FALSE)
indicators <- read.csv("config/indicators.csv", stringsAsFactors = FALSE)
checks <- new.env()
sys.source("R/05_quality_checks.R", envir = checks)
checks$check_data(clean)
analytical <- distinct(clean, country_code, country_name, year)

for (variable_name in indicators$variable) {
  series <- clean |>
    filter(variable == variable_name) |>
    select(country_code, year, value)
  names(series)[names(series) == "value"] <- variable_name
  checks$check_key(series, c("country_code", "year"))
  analytical <- left_join(analytical, series, by = c("country_code", "year"))
}

analytical <- analytical |>
  arrange(country_code, desc(year)) |>
  mutate(gdp_per_capita_growth = 100 * (gdp_per_capita / lag(gdp_per_capita) - 1))

ilostat <- read.csv("data/processed/ilostat_long.csv", stringsAsFactors = FALSE)
checks$check_data(ilostat)
checks$require_columns(ilostat, c("source", "status"))
checks$check_key(ilostat, c("country_code", "year"))
checks$check_key(analytical, c("country_code", "year"))
ilostat_series <- ilostat |>
  select(country_code, year, value, source, status) |>
  rename(
    employment_to_population = value,
    employment_to_population_source = source,
    employment_to_population_status = status
  )
expected_rows <- nrow(analytical)
analytical <- left_join(analytical, ilostat_series, by = c("country_code", "year"))
if (nrow(analytical) != expected_rows) stop("ILOSTAT join changed the WDI-left row count.")

write.csv(analytical, "data/processed/analytical.csv", row.names = FALSE, na = "")