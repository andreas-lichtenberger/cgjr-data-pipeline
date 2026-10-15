analysis <- new.env()
sys.source("R/04b_ilostat_analysis.R", envir = analysis)

input <- read.csv("data/processed/analytical.csv", stringsAsFactors = FALSE)
plotted <- analysis$ilo_plot_data
input_index <- match(
  paste(input$country_code, input$year),
  paste(plotted$country_code, plotted$year)
)
stopifnot(
  !anyNA(input_index),
  identical(plotted$employment_to_population[input_index], input$employment_to_population),
  identical(plotted$employment_to_population_source[input_index],
            input$employment_to_population_source),
  identical(plotted$employment_to_population_status[input_index],
            input$employment_to_population_status)
)
rendered <- ggplot2::ggplot_build(analysis$ilo_chart)
points <- rendered$data[[2]]
panels <- rendered$layout$layout
point_country <- panels$country_name[match(points$PANEL, panels$PANEL)]
point_index <- match(
  paste(point_country, points$x),
  paste(plotted$country_name, plotted$year)
)
stopifnot(
  !anyNA(point_index),
  isTRUE(all.equal(points$y, plotted$employment_to_population[point_index])),
  sum(!is.na(points$y)) == sum(!is.na(input$employment_to_population)),
  isTRUE(all.equal(
    sort(points$y[!is.na(points$y)]),
    sort(input$employment_to_population[!is.na(input$employment_to_population)])
  ))
)
for (code in analysis$countries$country_code) {
  available <- input[input$country_code == code &
                       !is.na(input$employment_to_population), ]
  summary_row <- analysis$ilo_summary[analysis$ilo_summary$country_code == code, ]
  stopifnot(summary_row$available_years == nrow(available))
  if (nrow(available) > 0L) {
    latest <- available[which.max(available$year), ]
    stopifnot(
      summary_row$latest_year == latest$year,
      summary_row$latest_value_percent == latest$employment_to_population
    )
  } else {
    stopifnot(is.na(summary_row$latest_year), is.na(summary_row$latest_value_percent))
  }
}

countries <- data.frame(
  country_code = c("BRA", "KEN"), country_name = c("Brazil", "Kenya"),
  start_year = c(2019L, 2019L), end_year = c(2023L, 2023L)
)
fixture <- data.frame(
  country_code = rep("BRA", 4), year = c(2019L, 2021L, 2022L, 2023L),
  employment_to_population = c(60, 62, NA_real_, NA_real_),
  employment_to_population_source = rep("test source", 4),
  employment_to_population_status = c("E", "P", NA, NA)
)
result <- analysis$prepare_ilostat_outputs(fixture, countries)
brazil <- result$plot_data[result$plot_data$country_code == "BRA", ]
summary_brazil <- result$summary[result$summary$country_code == "BRA", ]
summary_kenya <- result$summary[result$summary$country_code == "KEN", ]
stopifnot(
  nrow(result$plot_data) == 10L,
  is.na(brazil$employment_to_population[brazil$year == 2020L]),
  brazil$line_segment[brazil$year == 2019L] !=
    brazil$line_segment[brazil$year == 2021L],
  summary_brazil$latest_year == 2021L,
  summary_brazil$latest_value_percent == 62,
  summary_brazil$status == "P",
  summary_brazil$available_years == 2L,
  summary_brazil$missing_years == 3L,
  summary_brazil$coverage_percent == 40,
  summary_kenya$available_years == 0L,
  summary_kenya$coverage_percent == 0,
  is.na(summary_kenya$latest_year)
)
gap_chart <- analysis$ilo_chart
gap_chart$data <- result$plot_data
gap_chart$layers[[3]]$data <- result$plot_data[
  is.na(result$plot_data$employment_to_population), ]
gap_rendered <- ggplot2::ggplot_build(gap_chart)
gap_lines <- gap_rendered$data[[1]]
stopifnot(
  length(unique(gap_lines$group[!is.na(gap_lines$y)])) == 2L,
  nrow(gap_rendered$data[[3]]) == 8L
)
duplicate_rejected <- tryCatch(
  {
    analysis$prepare_ilostat_outputs(rbind(fixture, fixture[1, ]), countries)
    FALSE
  },
  error = function(condition) grepl("keys must be unique", conditionMessage(condition))
)
stopifnot(duplicate_rejected)
outputs <- c(
  "outputs/figures/employment_to_population.png",
  "outputs/tables/employment_to_population_summary.csv"
)
stopifnot(all(file.exists(outputs)), all(file.info(outputs)$size > 0))
message("ILOSTAT analysis tests passed: values, gaps, latest values, coverage and duplicate keys.")
