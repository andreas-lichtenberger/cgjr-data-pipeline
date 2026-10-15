if (!requireNamespace("Rilostat", quietly = TRUE)) {
  stop("Package 'Rilostat' is required. Install it with install.packages('Rilostat').")
}

countries <- read.csv("config/countries.csv", stringsAsFactors = FALSE)
indicator <- read.csv("config/ilostat_indicators.csv", stringsAsFactors = FALSE)
if (nrow(indicator) != 1L) stop("Expected exactly one configured ILOSTAT indicator.")

toc <- Rilostat::get_ilostat_toc(quiet = TRUE)
toc_entry <- toc[toc$id == indicator$dataset_id, ]
if (nrow(toc_entry) != 1L) {
  stop("Configured ILOSTAT dataset ID was not found exactly once in the current table of contents.")
}
if (toc_entry$freq != "A") stop("Configured ILOSTAT dataset is not annual.")

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
raw <- Rilostat::get_ilostat(
  id = indicator$dataset_id,
  type = "both",
  filters = list(
    ref_area = countries$country_code,
    sex = indicator$sex,
    classif1 = indicator$classif1,
    timefrom = min(countries$start_year),
    timeto = max(countries$end_year)
  ),
  cache = FALSE,
  quiet = FALSE
)

required <- c(
  "ref_area", "source", "indicator", "sex", "classif1",
  "time", "obs_value", "source.label", "sex.label", "classif1.label"
)
missing <- setdiff(required, names(raw))
if (length(missing) > 0L) {
  stop("Expected ILOSTAT columns are absent: ", paste(missing, collapse = ", "))
}
if (nrow(raw) == 0L) stop("ILOSTAT returned no observations for the configured filters.")
if (!all(raw$indicator == indicator$indicator_code)) {
  stop("ILOSTAT returned an unexpected indicator code.")
}

write.csv(raw, "data/raw/ilostat.csv", row.names = FALSE, na = "")
write.csv(
  data.frame(
    source = "ILOSTAT",
    dataset_id = indicator$dataset_id,
    source_url = "https://ilostat.ilo.org/data/bulk/",
    retrieved_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  ),
  "data/raw/ilostat_retrieval.csv", row.names = FALSE
)
