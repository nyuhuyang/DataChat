# ============================================================================
# Template: Edge Type Count
# ============================================================================
# Inputs: datasets (list), selected (vector of source_ids), params (list)
# Outputs: result_table, result_plot, logs

logs <- c()

# Find a dataset with edge_type column
edge_dataset <- NULL
edge_source_id <- NULL

for (source_id in selected) {
  ds <- datasets[[source_id]]
  if (!is.null(ds) && "edge_type" %in% colnames(ds)) {
    edge_dataset <- ds
    edge_source_id <- source_id
    break
  }
}

if (is.null(edge_dataset)) {
  result_table <- NULL
  result_plot <- NULL
  logs <- paste0(
    "Error: No dataset with 'edge_type' column found.\n",
    "Selected datasets: ", paste(selected, collapse = ", "),
    "\nPlease upload an edge dataset with an 'edge_type' column."
  )
} else {
  # Log source information
  logs <- c(
    paste0("Dataset: ", edge_source_id),
    paste0("Rows: ", nrow(edge_dataset), ", Columns: ", ncol(edge_dataset)),
    ""
  )

  # Count by edge_type
  result_table <- edge_dataset %>%
    group_by(edge_type) %>%
    summarise(count = n(), .groups = 'drop') %>%
    arrange(desc(count)) %>%
    as.data.frame()

  logs <- c(logs, paste0("Found ", nrow(result_table), " unique edge types"))

  # Create bar plot (top 20)
  top_n_param <- if (!is.null(params$top_n)) params$top_n else 20
  plot_data <- head(result_table, top_n_param)

  result_plot <- ggplot(plot_data, aes(x = reorder(edge_type, -count), y = count)) +
    geom_bar(stat = "identity", fill = "#27ae60", alpha = 0.7) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9)) +
    labs(
      title = "Edge Type Distribution",
      x = "Edge Type",
      y = "Count",
      subtitle = paste0("Top ", top_n_param, " out of ", nrow(result_table), " types")
    )

  logs <- c(logs, paste0("Chart shows top ", top_n_param, " edge types"))
}
