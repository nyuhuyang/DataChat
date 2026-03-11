test_that("generate_r_code routes common prompts to expected code templates", {
  summary_code <- generate_r_code("summary stats", "schema")
  hist_code <- generate_r_code("show distribution", "schema")
  network_code <- generate_r_code("network graph", "schema")
  default_code <- generate_r_code("unknown prompt", "schema")

  expect_match(summary_code, "summary\\(df\\)")
  expect_match(hist_code, "geom_histogram")
  expect_match(network_code, "forceNetwork")
  expect_match(default_code, "head\\(df, 10\\)")
})

test_that("generate_code_with_mode falls back to rule-based code when LLM credentials are missing", {
  code <- generate_code_with_mode("summary", "schema", use_llm = TRUE, base_url = "", api_key = "")

  expect_match(code, "Warning: LLM enabled but credentials missing")
  expect_match(code, "summary\\(df\\)")
})

test_that("build_execution_summary_text summarizes tables and plot classes", {
  exec_result <- list(
    success = TRUE,
    output = "analysis complete",
    result_table = data.frame(a = 1:2, b = c("x", "y")),
    result_plot = structure(list(), class = c("ggplot", "plot"))
  )

  summary_text <- build_execution_summary_text(exec_result, max_rows = 1, max_cols = 1)

  expect_match(summary_text, "Execution success: TRUE")
  expect_match(summary_text, "Console output:")
  expect_match(summary_text, "Result table: 2 rows x 2 columns")
  expect_match(summary_text, "Result plot class: ggplot, plot")
})
