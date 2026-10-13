library(dplyr)
library(ggplot2)

analytical <- read.csv("data/processed/analytical.csv", stringsAsFactors = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

chart <- ggplot(analytical, aes(year, gdp_growth, colour = country_name)) +
  geom_line(na.rm = FALSE) +
  labs(
    title = "GDP Growth by Country", x = "Year", y = "Annual growth (%)",
    colour = "Country", caption = "Source: World Bank, World Development Indicators."
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave("outputs/figures/gdp_growth.png", chart, width = 8, height = 5, dpi = 150)

summary_table <- analytical |>
  filter(!is.na(gdp_growth)) |>
  arrange(country_code, year) |>
  group_by(country_code, country_name) |>
  slice(1) |>
  ungroup() |>
  select(country_code, country_name, year, gdp_growth)
write.csv(summary_table, "outputs/tables/country_summary.csv", row.names = FALSE)