library(dplyr)

clean <- read.csv("data/processed/wdi_long.csv", stringsAsFactors = FALSE)
indicators <- read.csv("config/indicators.csv", stringsAsFactors = FALSE)
analytical <- distinct(clean, country_code, country_name, year)

for (variable_name in indicators$variable) {
  series <- clean |>
    filter(variable == variable_name) |>
    select(country_code, year, value)
  names(series)[names(series) == "value"] <- variable_name
  analytical <- left_join(analytical, series, by = c("country_code", "year"))
}

analytical <- analytical |>
  arrange(country_code, desc(year)) |>
  mutate(gdp_per_capita_growth = 100 * (gdp_per_capita / lag(gdp_per_capita) - 1))

write.csv(analytical, "data/processed/analytical.csv", row.names = FALSE, na = "")