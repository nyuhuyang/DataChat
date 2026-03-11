library(testthat)

if (requireNamespace("DataChat", quietly = TRUE)) {
  library(DataChat)
  test_check("DataChat")
} else {
  test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
}
