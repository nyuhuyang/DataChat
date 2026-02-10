# ============================================================================
# Template: Node Type Distribution
# ============================================================================
# Inputs: datasets (list), selected (vector of source_ids), params (list)
# Outputs: result_table, result_plot, logs

logs <- c()

# Find a dataset with node_type column
node_dataset <- NULL
node_source_id <- NULL

for (source_id in selected) {
  ds <- datasets[[source_id]]
  if (!is.null(ds) && "node_type" %in% colnames(ds)) {
    node_dataset <- ds
    node_source_id <- source_id
    break
  }
}

if (is.null(node_dataset)) {
  result_table <- NULL
  result_plot <- NULL
  logs <- paste0(
    "Error: No dataset with 'node_type' column found.\n",
    "Selected datasets: ", paste(selected, collapse = ", "),
    "\nPlease upload a node dataset with a 'node_type' column."
  )
} else {
  # Log source information
  logs <- c(
    paste0("Dataset: ", node_source_id),
    paste0("Rows: ", nrow(node_dataset), ", Columns: ", ncol(node_dataset)),
    ""
  )

  # Count by node_type
  result_table <- node_dataset %>%
    group_by(node_type) %>%
    summarise(count = n(), .groups = 'drop') %>%
    arrange(desc(count)) %>%
    as.data.frame()

  logs <- c(logs, paste0("Found ", nrow(result_table), " unique node types"))

  # Create bar plot (top 20)
  top_n_param <- if (!is.null(params$top_n)) params$top_n else 20
  plot_data <- head(result_table, top_n_param)

  result_plot <- ggplot(plot_data, aes(x = reorder(node_type, -count), y = count)) +
    geom_bar(stat = "identity", fill = "#6c5ce7", alpha = 0.7) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9)) +
    labs(
      title = "Node Type Distribution",
      x = "Node Type",
      y = "Count",
      subtitle = paste0("Top ", top_n_param, " out of ", nrow(result_table), " types")
    )

  logs <- c(logs, paste0("Chart shows top ", top_n_param, " node types"))
}
