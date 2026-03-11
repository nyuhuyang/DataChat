test_that("sanitize_profile_stem normalizes filenames", {
  expect_identical(sanitize_profile_stem("My File (v1).csv"), "My_File_v1_")
})

test_that("generate_profile_summary_text includes structural cues", {
  df <- data.frame(
    node_id = 1:3,
    node_type = c("gene", "gene", "protein"),
    score = c(1.2, 2.5, 3.1)
  )
  schema_text <- generate_schema_text(df)

  profile_text <- generate_profile_summary_text(
    data = df,
    filename = "nodes.csv",
    source_type = "nodes",
    source_id = "nodes_1",
    schema_text = schema_text,
    preview_summary = list(detected_format = "csv", missing_rate_pct = 0)
  )

  expect_match(profile_text, "Dataset Profile: nodes.csv")
  expect_match(profile_text, "Likely ID columns: node_id")
  expect_match(profile_text, "Column Profiles:")
  expect_match(profile_text, "Schema:")
})

test_that("build_selected_profile_context deduplicates shared profile files", {
  data_sources <- list(
    sources = list(
      a = list(
        type = "nodes",
        name = "nodes.csv",
        row_count = 2,
        col_count = 2,
        profile_text = "Profile A",
        schema_text = "Schema A",
        profile_md_path = "profiles/shared.md"
      ),
      b = list(
        type = "metadata",
        name = "meta.csv",
        row_count = 1,
        col_count = 1,
        profile_text = "Profile B",
        schema_text = "Schema B",
        profile_md_path = "profiles/shared.md"
      )
    )
  )

  context <- build_selected_profile_context(c("a", "b"), data_sources)

  expect_match(context, "\\[NODES\\] nodes.csv")
  expect_no_match(context, "\\[METADATA\\] meta.csv")
})
