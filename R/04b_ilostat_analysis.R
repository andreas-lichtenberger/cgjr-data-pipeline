library(dplyr)
library(ggplot2)

prepare_ilostat_outputs <- function(analytical, countries) {
  required <- c(
    "country_code", "year", "employment_to_population",
    "employment_to_population_source", "employment_to_population_status"
  )
  missing <- setdiff(required, names(analytical))
  if (length(missing) > 0L) {
    stop("Analytical data is missing columns: ", paste(missing, collapse = ", "))
  }
  if (anyNA(countries) || anyDuplicated(countries$country_code) ||
      any(countries$start_year > countries$end_year)) {
    stop("Country configuration must have unique codes and valid year ranges.")
  }
  if (!is.numeric(analytical$year) || anyNA(analytical$year) ||
      any(!is.finite(analytical$year) | analytical$year != trunc(analytical$year))) {
    stop("Analytical years must be non-missing whole numbers.")
  }
  analytical$year <- as.integer(analytical$year)
  if (anyDuplicated(analytical[, c("country_code", "year")])) {
    stop("Analytical country-year keys must be unique before plotting.")
  }
  country_index <- match(analytical$country_code, countries$country_code)
  if (anyNA(country_index) ||
      any(analytical$year < countries$start_year[country_index] |
          analytical$year > countries$end_year[country_index])) {
    stop("Analytical observations are outside the configured countries or years.")
  }
  value <- analytical$employment_to_population
  if (!is.numeric(value) ||
      any(!is.na(value) & (!is.finite(value) | value < 0 | value > 100))) {
    stop("Employment-to-population values must be numeric percentages from 0 to 100.")
  }

  calendar <- bind_rows(lapply(seq_len(nrow(countries)), function(index) {
    data.frame(
      country_code = countries$country_code[index],
      country_name = countries$country_name[index],
      year = seq.int(countries$start_year[index], countries$end_year[index])
    )
  }))
  plot_data <- calendar |>
    left_join(analytical[, required], by = c("country_code", "year")) |>
    arrange(country_code, year) |>
    group_by(country_code) |>
    mutate(line_segment = cumsum(is.na(employment_to_population))) |>
    ungroup()

  latest <- plot_data |>
    filter(!is.na(employment_to_population)) |>
    group_by(country_code) |>
    slice_max(year, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(
      country_code, latest_year = year, latest_value_percent = employment_to_population,
      source = employment_to_population_source, status = employment_to_population_status
    )
  coverage <- plot_data |>
    group_by(country_code, country_name) |>
    summarise(
      expected_years = n(),
      available_years = sum(!is.na(employment_to_population)),
      .groups = "drop"
    ) |>
    mutate(
      missing_years = expected_years - available_years,
      coverage_percent = round(100 * available_years / expected_years, 1)
    ) |>
    left_join(latest, by = "country_code") |>
    select(
      country_code, country_name, latest_year, latest_value_percent,
      available_years, expected_years, missing_years, coverage_percent, source, status
    )
  list(plot_data = plot_data, summary = coverage)
}

analytical <- read.csv("data/processed/analytical.csv", stringsAsFactors = FALSE)
countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
ilo_config <- read.csv("config/ilostat_indicators.csv", stringsAsFactors = FALSE)
if (nrow(ilo_config) != 1L ||
    ilo_config$dataset_id != "EMP_2WAP_SEX_AGE_RT_A" ||
    ilo_config$unit != "percent" || ilo_config$sex != "SEX_T" ||
    ilo_config$classif1 != "AGE_YTHADULT_YGE15") {
  stop("This chart requires the configured annual employment-to-population ratio, total sex, age 15+, in percent.")
}
ilo_outputs <- prepare_ilostat_outputs(analytical, countries)
ilo_plot_data <- ilo_outputs$plot_data
ilo_summary <- ilo_outputs$summary
if (any(ilo_summary$missing_years > 0L)) {
  warning("Some employment-to-population years are unavailable; inspect the coverage table and chart gaps.")
}

ilo_chart <- ggplot(
  ilo_plot_data,
  aes(year, employment_to_population, group = interaction(country_code, line_segment))
) +
  geom_line(colour = "#264653", linewidth = 0.7, na.rm = TRUE) +
  geom_point(colour = "#264653", size = 1.4, na.rm = TRUE) +
  geom_rug(
    data = filter(ilo_plot_data, is.na(employment_to_population)),
    aes(x = year), inherit.aes = FALSE, sides = "b", colour = "#A23E2A"
  ) +
  facet_wrap(~country_name, ncol = 2) +
  scale_x_continuous(
    breaks = sort(unique(c(
      seq(min(countries$start_year), max(countries$end_year), by = 5),
      max(countries$end_year)
    ))),
    minor_breaks = NULL
  ) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, by = 25)) +
  labs(
    title = "Employment-to-population ratio",
    subtitle = "People aged 15 and above, total sex | Annual modelled estimates",
    x = NULL, y = "Employment-to-population ratio (%)",
    caption = paste(
      "Source: ILOSTAT, ILO modelled estimates. Dataset: EMP_2WAP_SEX_AGE_RT_A.",
      "Points are available annual values; lines do not bridge missing years.",
      "Baseline tick marks identify unavailable years. No interpolation is applied.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.text = element_text(face = "bold", hjust = 0),
    plot.title = element_text(face = "bold", size = 16),
    plot.caption = element_text(hjust = 0, size = 8, colour = "grey30"),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    panel.spacing = grid::unit(1.2, "lines")
  )

dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
ggsave(
  "outputs/figures/employment_to_population.png", plot = ilo_chart,
  width = 9, height = 6.5, units = "in", dpi = 300, bg = "white"
)
write.csv(
  ilo_summary, "outputs/tables/employment_to_population_summary.csv",
  row.names = FALSE, na = ""
)
