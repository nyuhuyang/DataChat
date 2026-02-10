infer_column_type <- function(x) {
  if (is.logical(x)) {
    "logical"
  } else if (inherits(x, "Date") || inherits(x, "POSIXct")) {
    "datetime"
  } else if (is.numeric(x)) {
    "numeric"
  } else if (is.character(x) || is.factor(x)) {
    "categorical"
  } else {
    "other"
  }
}

summarize_column <- function(name, col) {
  col_type <- infer_column_type(col)
  missing_count <- sum(is.na(col))
  missing_pct <- round(100 * missing_count / length(col), 2)

  summary_info <- list(
    name = name,
    type = col_type,
    missing_count = missing_count,
    missing_pct = missing_pct
  )

  if (col_type == "numeric") {
    clean_col <- col[!is.na(col)]
    if (length(clean_col) > 0) {
      summary_info$stats <- list(
        min = min(clean_col, na.rm = TRUE),
        median = median(clean_col, na.rm = TRUE),
        mean = mean(clean_col, na.rm = TRUE),
        max = max(clean_col, na.rm = TRUE)
      )
    }
  } else if (col_type == "categorical") {
    top_values <- head(names(sort(table(col), decreasing = TRUE)), 5)
    summary_info$top_values <- top_values
  }

  return(summary_info)
}

summarize_dataset <- function(data) {
  list(
    rows = nrow(data),
    cols = ncol(data),
    columns = lapply(names(data), function(name) {
      summarize_column(name, data[[name]])
    })
  )
}
