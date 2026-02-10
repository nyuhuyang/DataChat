#!/usr/bin/env Rscript

source("R/io_read_any.R")
source("R/summarize_dataset.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("Usage: Rscript scripts/01_describe_file.R <input_file> [output_dir]\n")
  quit(status = 1)
}

input_file <- args[1]
output_dir <- if (length(args) > 1) args[2] else "data/output"

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

cat("Reading", input_file, "...\n")
data <- io_read_any(input_file)

cat("Summarizing...\n")
summary <- summarize_dataset(data)

rds_path <- file.path(output_dir, "dataset_description.rds")
saveRDS(summary, rds_path)
cat("Saved RDS to", rds_path, "\n")

write_description_markdown <- function(summary, file_path) {
  md <- c(
    "# Dataset Description",
    "",
    paste("**Rows:**", summary$rows),
    paste("**Columns:**", summary$cols),
    "",
    "## Column Summary",
    ""
  )

  for (col_info in summary$columns) {
    md <- c(md,
      paste0("### ", col_info$name),
      paste0("- Type: `", col_info$type, "`"),
      paste0("- Missing: ", col_info$missing_count, " (", col_info$missing_pct, "%)"),
      ""
    )

    if (!is.null(col_info$stats)) {
      md <- c(md,
        "**Statistics:**",
        paste0("- Min: ", format(col_info$stats$min, digits = 4)),
        paste0("- Median: ", format(col_info$stats$median, digits = 4)),
        paste0("- Mean: ", format(col_info$stats$mean, digits = 4)),
        paste0("- Max: ", format(col_info$stats$max, digits = 4)),
        ""
      )
    }

    if (!is.null(col_info$top_values)) {
      md <- c(md,
        paste0("**Top values:** ", paste(col_info$top_values, collapse = ", ")),
        ""
      )
    }
  }

  writeLines(md, file_path)
}

md_path <- file.path(output_dir, "dataset_description.md")
write_description_markdown(summary, md_path)
cat("Saved Markdown to", md_path, "\n")

cat("Done.\n")
