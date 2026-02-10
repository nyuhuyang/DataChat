#!/usr/bin/env Rscript

source("R/io_read_any.R")
source("R/analysis_helpers.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("Usage: Rscript scripts/02_run_analysis.R <input_file> [output_dir]\n")
  quit(status = 1)
}

input_file <- args[1]
output_dir <- if (length(args) > 1) args[2] else "data/output"

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

cat("Reading", input_file, "...\n")
data <- io_read_any(input_file)

numeric_cols <- names(data)[sapply(data, is.numeric)]
categorical_cols <- names(data)[sapply(data, function(x) is.character(x) || is.factor(x))]

analysis_results <- list()

if (length(numeric_cols) > 0) {
  cat("Computing numeric column statistics...\n")
  analysis_results$numeric_summary <- lapply(numeric_cols, function(col) {
    col_data <- data[[col]][!is.na(data[[col]])]
    list(
      column = col,
      mean = mean(col_data),
      median = median(col_data),
      sd = sd(col_data),
      min = min(col_data),
      max = max(col_data)
    )
  })
}

if (length(categorical_cols) > 0) {
  cat("Computing categorical column frequencies...\n")
  analysis_results$categorical_summary <- lapply(categorical_cols, function(col) {
    list(
      column = col,
      top_values = head(sort(table(data[[col]]), decreasing = TRUE), 5)
    )
  })
}

if (length(numeric_cols) >= 2) {
  cat("Computing correlation matrix...\n")
  analysis_results$correlation_matrix <- compute_correlation_matrix(data)
}

output_path <- file.path(output_dir, "analysis_results.rds")
saveRDS(analysis_results, output_path)
cat("Saved", output_path, "\n")

cat("Done.\n")
