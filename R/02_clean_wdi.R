library(dplyr)

raw <- read.csv("data/raw/wdi.csv", stringsAsFactors = FALSE)
countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
indicators <- read.csv("config/indicators.csv", stringsAsFactors = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

clean <- bind_rows(lapply(seq_len(nrow(indicators)), function(index) {
  data.frame(
    country_code = raw$iso3c,
    country_name = raw$country,
    year = as.integer(raw$year),
    indicator = indicators$indicator[index],
    variable = indicators$variable[index],
    value = as.numeric(raw[[indicators$indicator[index]]]),
    unit = indicators$unit[index],
    source = "WDI"
  )
})) |>
  inner_join(countries[, c("country_code", "start_year", "end_year")],
             by = "country_code") |>
  filter(year >= start_year, year <= end_year) |>
  select(-start_year, -end_year) |>
  arrange(country_code, year, indicator)

if (nrow(clean) == 0L) stop("No observations remain after filtering.")
write.csv(clean, "data/processed/wdi_long.csv", row.names = FALSE, na = "")