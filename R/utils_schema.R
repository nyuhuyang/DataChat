# ============================================================================
# Schema text generation
# ============================================================================

# Generate formatted schema text for LLM
generate_schema_text <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    return("No data available")
  }

  schema_parts <- c()
  schema_parts <- c(schema_parts, paste0("Dataset: ", nrow(data), " rows, ", ncol(data), " columns\n"))
  schema_parts <- c(schema_parts, "Columns:")

  for (col_name in names(data)) {
    col_type <- class(data[[col_name]])[1]
    missing_count <- sum(is.na(data[[col_name]]))
    missing_pct <- round(100 * missing_count / nrow(data), 1)

    # Add range/sample info
    sample_info <- ""
    if (is.numeric(data[[col_name]])) {
      range_vals <- range(data[[col_name]], na.rm = TRUE)
      sample_info <- sprintf(" [range: %.2f to %.2f]", range_vals[1], range_vals[2])
    } else if (is.factor(data[[col_name]]) || is.character(data[[col_name]])) {
      unique_vals <- unique(data[[col_name]])
      if (length(unique_vals) <= 5) {
        sample_info <- paste0(" [values: ", paste(head(unique_vals, 5), collapse = ", "), "]")
      } else {
        sample_info <- paste0(" [", length(unique_vals), " unique values]")
      }
    }

    schema_parts <- c(schema_parts,
                     sprintf("  - %s: %s (%.1f%% missing)%s",
                             col_name, col_type, missing_pct, sample_info))
  }

  return(paste(schema_parts, collapse = "\n"))
}
