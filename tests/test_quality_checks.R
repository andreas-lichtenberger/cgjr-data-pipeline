source("R/05_quality_checks.R")

expect_error <- function(expression, pattern) {
  result <- tryCatch({ force(expression); NULL }, error = identity)
  stopifnot(inherits(result, "error"), grepl(pattern, conditionMessage(result)))
}
fixture <- data.frame(
  country_code = "BRA", year = 2020L, indicator = "example", value = 50
)
stopifnot(isTRUE(check_data(fixture)))
expect_error(check_data(fixture[, -4]), "Required columns")
expect_error(check_data(rbind(fixture, fixture)), "Duplicate")
invalid <- fixture
invalid$year <- 2020.5
expect_error(check_data(invalid), "integer")
invalid <- fixture
invalid$country_code <- NA_character_
expect_error(check_data(invalid), "missing or blank")
invalid <- fixture
invalid$value <- "50"
expect_error(check_data(invalid), "numeric")
invalid$value <- Inf
expect_error(check_data(invalid), "finite")
expect_error(check_bounds(c(50, 101), 0, 100), "bounds")
expect_error(check_bounds(-1, 0), "bounds")
check_bounds(c(0, 100, NA), 0, 100)
invalid <- fixture
invalid$value <- NA_real_
warned <- FALSE
withCallingHandlers(check_data(invalid), warning = function(condition) {
  warned <<- TRUE
  invokeRestart("muffleWarning")
})
stopifnot(warned, nrow(invalid) == 1L)
message("Quality-check edge tests passed.")
