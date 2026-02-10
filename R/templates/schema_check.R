# ============================================================================
# Template: Schema Check
# ============================================================================
# Inputs: datasets (list), selected (vector of source_ids), params (list)
# Outputs: result_table, result_plot, logs

logs <- c()

if (length(selected) == 0 || all(is.null(datasets[selected]))) {
  result_table <- NULL
  result_plot <- NULL
  logs <- "Error: No datasets selected for schema check."
} else {
  # Build schema summary for all selected datasets
  schema_rows <- list()

  for (source_id in selected) {
    ds <- datasets[[source_id]]
    if (is.null(ds)) next

    for (col_name in colnames(ds)) {
      col_data <- ds[[col_name]]
      col_type <- class(col_data)[1]

      # Calculate missing stats
      n_missing <- sum(is.na(col_data))
      pct_missing <- round(100 * n_missing / nrow(ds), 1)

      schema_rows[[length(schema_rows) + 1]] <- data.frame(
        dataset = source_id,
        column = col_name,
        type = col_type,
        n_missing = n_missing,
        pct_missing = pct_missing,
        n_rows = nrow(ds),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(schema_rows) == 0) {
    result_table <- NULL
    result_plot <- NULL
    logs <- "Error: Could not extract schema from selected datasets."
  } else {
    result_table <- do.call(rbind, schema_rows) %>% as.data.frame()

    # Create logs with summary
    logs <- c(
      paste0("Schema Check for ", length(selected), " dataset(s):"),
      ""
    )

    for (source_id in selected) {
      ds <- datasets[[source_id]]
      if (is.null(ds)) next

      logs <- c(
        logs,
        paste0("• ", source_id),
        paste0("  Rows: ", nrow(ds), " | Columns: ", ncol(ds)),
        paste0("  Columns: ", paste(colnames(ds), collapse = ", "))
      )

      # Check for common issues
      has_id <- any(c("id", "node_id", "edge_id") %in% colnames(ds))
      has_type <- any(c("node_type", "edge_type") %in% colnames(ds))
      has_from_to <- ("from" %in% colnames(ds) || "source" %in% colnames(ds)) &&
                     ("to" %in% colnames(ds) || "target" %in% colnames(ds))

      if (!has_id && !has_type && !has_from_to) {
        logs <- c(logs, "  ⚠️  Warning: No ID, type, or edge structure columns detected")
      }

      # Check for missing values
      cols_with_missing <- colnames(ds)[colSums(is.na(ds)) > 0]
      if (length(cols_with_missing) > 0) {
        logs <- c(logs, paste0("  ⚠️  Columns with missing data: ", paste(cols_with_missing, collapse = ", ")))
      }

      logs <- c(logs, "")
    }

    # Create visualization: missing rate by column (if any missing data exists)
    plot_data_missing <- result_table %>%
      filter(pct_missing > 0) %>%
      slice_max(pct_missing, n = 20)

    if (nrow(plot_data_missing) > 0) {
      result_plot <- ggplot(plot_data_missing, aes(x = reorder(column, -pct_missing), y = pct_missing, fill = dataset)) +
        geom_bar(stat = "identity", position = "dodge", alpha = 0.7) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9)) +
        labs(
          title = "Missing Data Rate by Column",
          x = "Column",
          y = "% Missing",
          fill = "Dataset"
        )

      logs <- c(logs, "Visualization: Top 20 columns by missing data rate")
    } else {
      # No missing data: show data type distribution instead
      logs <- c(logs, "No missing data detected - showing data type distribution")

      type_summary <- result_table %>%
        group_by(dataset, type) %>%
        summarise(count = n(), .groups = 'drop') %>%
        as.data.frame()

      result_plot <- ggplot(type_summary, aes(x = dataset, y = count, fill = type)) +
        geom_bar(stat = "identity", alpha = 0.7) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9)) +
        labs(
          title = "Data Type Distribution",
          x = "Dataset",
          y = "Column Count",
          fill = "Data Type"
        )
    }
  }
}
