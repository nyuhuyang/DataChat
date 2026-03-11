test_that("infer_source_type distinguishes nodes, edges, and metadata", {
  expect_identical(infer_source_type(data.frame(from = 1, to = 2)), "edges")
  expect_identical(infer_source_type(data.frame(id = 1, label = "A")), "nodes")
  expect_identical(infer_source_type(data.frame(category = "A", value = 1)), "metadata")
})

test_that("generate_source_id includes file stem and formatted timestamp", {
  source_id <- generate_source_id("nodes.csv", as.POSIXct("2026-03-10 08:09:10.123", tz = "UTC"))

  expect_match(source_id, "^nodes_20260310_080910")
})

test_that("add_data_source stores metadata and get_selected_sources retrieves it", {
  data_sources <- new.env(parent = emptyenv())
  data_sources$sources <- list()
  data_sources$source_order <- character(0)

  df <- data.frame(id = 1:2, label = c("a", "b"))
  profile_info <- list(
    profile_text = "profile text",
    profile_md_path = "profiles/nodes.md",
    profile_rds_path = "profiles/nodes.rds",
    profile_cache_hit = TRUE
  )

  source_id <- add_data_source(
    data = df,
    filename = "nodes.csv",
    source_type = "nodes",
    data_sources = data_sources,
    source_file_name = "nodes.csv",
    profile_info = profile_info
  )

  selected <- get_selected_sources(data_sources, list(nodes_id = source_id, edges_id = NULL, metadata_id = NULL))
  stored <- selected$nodes

  expect_true(source_id %in% data_sources$source_order)
  expect_identical(stored$id, source_id)
  expect_identical(stored$type, "nodes")
  expect_identical(stored$file_name, "nodes.csv")
  expect_identical(stored$profile_text, "profile text")
  expect_true(stored$profile_cache_hit)
})
