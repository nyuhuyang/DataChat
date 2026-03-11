test_that("generate_schema_text handles empty data", {
  expect_identical(generate_schema_text(NULL), "No data available")
  expect_identical(generate_schema_text(data.frame()), "No data available")
})

test_that("generate_schema_text includes types, missingness, and sample info", {
  df <- data.frame(
    amount = c(1, 5, NA),
    status = c("new", "old", "new"),
    group = factor(c("A", "B", "A")),
    stringsAsFactors = FALSE
  )

  schema <- generate_schema_text(df)

  expect_match(schema, "Dataset: 3 rows, 3 columns")
  expect_match(schema, "amount: numeric \\(33\\.3% missing\\) \\[range: 1\\.00 to 5\\.00\\]")
  expect_match(schema, "status: character \\(0\\.0% missing\\) \\[values: new, old\\]")
  expect_match(schema, "group: factor \\(0\\.0% missing\\) \\[values: A, B\\]")
})
