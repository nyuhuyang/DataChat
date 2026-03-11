test_that("detect_file_params identifies delimiter from file content", {
  path <- tempfile(fileext = ".txt")
  writeLines(c("id;name", "1;alpha"), path)

  params <- detect_file_params(path)

  expect_identical(params$format, "txt")
  expect_identical(params$delimiter, ";")
  expect_true(params$has_header)
})

test_that("read_any reads csv and returns structured error for unsupported formats", {
  csv_path <- tempfile(fileext = ".csv")
  write.csv(data.frame(id = 1:2, label = c("a", "b")), csv_path, row.names = FALSE)

  csv_data <- read_any(csv_path)
  bad_data <- read_any(tempfile(fileext = ".json"))

  expect_s3_class(csv_data, "data.frame")
  expect_equal(nrow(csv_data), 2)
  expect_true(is.list(bad_data))
  expect_true(isTRUE(bad_data$error))
  expect_match(bad_data$message, "Unsupported file format")
})

test_that("preview_and_summarize returns summary, preview, and schema", {
  csv_path <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(id = c(1, 2, 3), score = c(10, NA, 30), group = c("x", "y", "x")),
    csv_path,
    row.names = FALSE
  )

  result <- preview_and_summarize(csv_path, max_rows = 2)

  expect_true(result$success)
  expect_equal(nrow(result$preview_table), 2)
  expect_identical(result$summary$rows, 3L)
  expect_identical(result$summary$cols, 3L)
  expect_equal(result$summary$numeric_columns, 2)
  expect_equal(result$summary$categorical_columns, 1)
  expect_match(result$schema, "Dataset: 3 rows, 3 columns")
})

test_that("build_file_entries creates a single entry for non-workbook files", {
  csv_path <- tempfile(fileext = ".csv")
  write.csv(data.frame(id = 1:2), csv_path, row.names = FALSE)

  entries <- build_file_entries(csv_path, max_rows = 1)

  expect_length(entries, 1)
  expect_identical(entries[[1]]$display_name, basename(csv_path))
  expect_true(entries[[1]]$preview_result$success)
  expect_s3_class(entries[[1]]$data, "data.frame")
})
