test_that("execute_user_code supports single-data execution", {
  df <- data.frame(value = c(1, 2, 3))
  code <- "result_table <- data.frame(total = sum(df$value)); print('done')"

  result <- execute_user_code(code, data = df)

  expect_true(result$success)
  expect_equal(result$result_table$total, 6)
  expect_match(result$output, "done")
})

test_that("execute_user_code binds selected multi-source datasets by type", {
  sources_list <- list(
    nodes = list(data = data.frame(id = 1:2, label = c("A", "B"))),
    edges = list(data = data.frame(from = 1, to = 2))
  )
  code <- paste(
    "result_table <- data.frame(",
    "nodes = nrow(df_nodes),",
    "edges = nrow(df_edges),",
    "has_df = exists('df', inherits = FALSE)",
    ")"
  )

  result <- execute_user_code(code, sources_list = sources_list)

  expect_true(result$success)
  expect_equal(result$result_table$nodes, 2)
  expect_equal(result$result_table$edges, 1)
  expect_false(result$result_table$has_df)
})

test_that("execute_user_code reports execution errors without crashing", {
  result <- execute_user_code("stop('boom')", data = data.frame(x = 1))

  expect_false(result$success)
  expect_match(result$output, "\\[ERROR\\] boom")
  expect_null(result$result_table)
})
