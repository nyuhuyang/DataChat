plot_histogram <- function(data, col_name, title = NULL) {
  col_data <- data[[col_name]]
  clean_data <- col_data[!is.na(col_data)]

  if (length(clean_data) == 0) {
    return(NULL)
  }

  hist(
    clean_data,
    main = title %||% paste("Distribution of", col_name),
    xlab = col_name,
    ylab = "Frequency",
    col = "steelblue",
    breaks = 30
  )
}

plot_boxplot <- function(data, col_name, title = NULL) {
  col_data <- data[[col_name]]
  clean_data <- col_data[!is.na(col_data)]

  if (length(clean_data) == 0) {
    return(NULL)
  }

  boxplot(
    clean_data,
    main = title %||% paste("Boxplot of", col_name),
    ylab = col_name,
    col = "steelblue"
  )
}

plot_barplot <- function(data, col_name, top_n = 10, title = NULL) {
  col_data <- data[[col_name]]
  counts <- sort(table(col_data), decreasing = TRUE)[1:top_n]

  barplot(
    counts,
    main = title %||% paste("Top values of", col_name),
    xlab = col_name,
    ylab = "Count",
    col = "steelblue",
    las = 2
  )
}

compute_correlation_matrix <- function(data) {
  numeric_cols <- names(data)[sapply(data, is.numeric)]
  if (length(numeric_cols) < 2) {
    return(NULL)
  }

  numeric_data <- data[numeric_cols]
  cor(numeric_data, use = "complete.obs")
}
