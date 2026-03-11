# ============================================================================
# Template: Node-Edge Join Summary
# ============================================================================
# Inputs: datasets (list), selected (vector of source_ids), params (list)
# Outputs: result_table, result_plot, logs

logs <- c()

# Find node and edge datasets using heuristics
node_dataset <- NULL
edge_dataset <- NULL
node_source_id <- NULL
edge_source_id <- NULL

for (source_id in selected) {
  ds <- datasets[[source_id]]
  if (is.null(ds)) next

  cols_lower <- tolower(colnames(ds))

  # Heuristic: edges have from/to or source/target or node_from/node_to or similar pair columns
  edge_indicators <- c("from", "source", "src", "start", "origin", "node_from")
  target_indicators <- c("to", "target", "tgt", "dest", "destination", "end", "node_to")

  has_source <- any(cols_lower %in% edge_indicators)
  has_target <- any(cols_lower %in% target_indicators)
  has_from_to <- has_source && has_target

  # Heuristic: nodes have id/node_id and (name/label or node_type)
  has_id <- any(cols_lower %in% c("id", "node_id", "nodeid", "node"))
  has_node_attr <- any(cols_lower %in% c("name", "label", "type", "node_type", "nodetype"))

  if (has_from_to) {
    edge_dataset <- ds
    edge_source_id <- source_id
  }

  if (has_id && has_node_attr) {
    node_dataset <- ds
    node_source_id <- source_id
  }
}

# Check if we have the required data
if (is.null(edge_dataset)) {
  result_table <- NULL
  result_plot <- NULL

  # Show available columns for debugging
  col_info <- c()
  for (source_id in selected) {
    ds <- datasets[[source_id]]
    if (!is.null(ds)) {
      col_info <- c(col_info, paste0(source_id, ": ", paste(colnames(ds), collapse = ", ")))
    }
  }

  logs <- paste0(
    "Error: No edge dataset found.\n",
    "Expected edge dataset with columns like:\n",
    "  - Edge source: from, source, src, start, or origin\n",
    "  - Edge target: to, target, tgt, dest, destination, or end\n\n",
    "Your dataset columns:\n",
    paste("  - ", col_info, collapse = "\n")
  )
} else if (is.null(node_dataset)) {
  # Edge-only analysis: check for node_type_pair or similar columns
  if ("node_type_pair" %in% colnames(edge_dataset) ||
      any(tolower(colnames(edge_dataset)) %in% c("node_type_pair", "pair", "type_pair"))) {
    logs <- c(
      paste0("Dataset: ", edge_source_id),
      paste0("Rows: ", nrow(edge_dataset), ", Columns: ", ncol(edge_dataset)),
      ""
    )

    result_table <- edge_dataset %>%
      group_by(node_type_pair) %>%
      summarise(count = n(), .groups = 'drop') %>%
      arrange(desc(count)) %>%
      as.data.frame()

    logs <- c(logs, paste0("Found ", nrow(result_table), " unique node type pairs"))

    top_n_param <- if (!is.null(params$top_n)) params$top_n else 20
    plot_data <- head(result_table, top_n_param)

    result_plot <- ggplot(plot_data, aes(x = reorder(node_type_pair, -count), y = count)) +
      geom_bar(stat = "identity", fill = "#e74c3c", alpha = 0.7) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9)) +
      labs(
        title = "Node Type Pair Distribution",
        x = "Pair",
        y = "Count",
        subtitle = paste0("Top ", top_n_param, " out of ", nrow(result_table), " pairs")
      )

    logs <- c(logs, paste0("Chart shows top ", top_n_param, " type pairs (from node_type_pair column)"))
  } else {
    result_table <- NULL
    result_plot <- NULL
    logs <- paste0(
      "Error: No node dataset found and edge dataset lacks 'node_type_pair' column.\n",
      "Please upload both node and edge datasets, or edge dataset with 'node_type_pair' column."
    )
  }
} else {
  # Both datasets available: attempt join
  logs <- c(
    paste0("Node dataset: ", node_source_id, " (", nrow(node_dataset), " rows)"),
    paste0("Edge dataset: ", edge_source_id, " (", nrow(edge_dataset), " rows)"),
    ""
  )

  # Check if edge dataset has pre-computed node_type_pair
  if ("node_type_pair" %in% colnames(edge_dataset)) {
    logs <- c(logs, "Using pre-computed node_type_pair column")

    result_table <- edge_dataset %>%
      group_by(node_type_pair) %>%
      summarise(count = n(), .groups = 'drop') %>%
      arrange(desc(count)) %>%
      rename(pair = node_type_pair) %>%
      as.data.frame()
  } else {
    # Attempt to join nodes on edges
    logs <- c(logs, "Joining edge endpoints with node attributes...")

    # Identify id columns (check for variations)
    id_col <- if ("node_id" %in% colnames(node_dataset)) "node_id" else "id"

    # Identify source/target columns (check for variations)
    source_col <- if ("node_from" %in% colnames(edge_dataset)) {
      "node_from"
    } else if ("source" %in% colnames(edge_dataset)) {
      "source"
    } else {
      "from"
    }

    target_col <- if ("node_to" %in% colnames(edge_dataset)) {
      "node_to"
    } else if ("target" %in% colnames(edge_dataset)) {
      "target"
    } else {
      "to"
    }

    # Check if node_type exists
    if (!("node_type" %in% colnames(node_dataset))) {
      result_table <- NULL
      result_plot <- NULL
      logs <- c(
        logs,
        "Error: Node dataset must have a 'node_type' column for join analysis."
      )
      return()
    }

    # Prepare node types lookup
    node_types <- node_dataset %>%
      select(all_of(c(id_col, "node_type"))) %>%
      rename(node_id = all_of(id_col))

    # Prepare edges
    edges_with_types <- edge_dataset %>%
      select(all_of(c(source_col, target_col))) %>%
      rename(source = all_of(source_col), target = all_of(target_col))

    # Left join source and target node types
    edges_with_types <- edges_with_types %>%
      left_join(
        node_types %>% rename(source_type = node_type),
        by = c(source = "node_id")
      ) %>%
      left_join(
        node_types %>% rename(target_type = node_type),
        by = c(target = "node_id")
      )

    # Count valid pairs (where both source and target have types)
    result_table <- edges_with_types %>%
      filter(!is.na(source_type) & !is.na(target_type)) %>%
      mutate(pair = paste(source_type, "→", target_type)) %>%
      group_by(pair) %>%
      summarise(count = n(), .groups = 'drop') %>%
      arrange(desc(count)) %>%
      as.data.frame()

    logs <- c(
      logs,
      paste0("Successfully joined. Found ", nrow(result_table), " unique type pair(s)")
    )
  }

  # Create plot
  top_n_param <- if (!is.null(params$top_n)) params$top_n else 20
  plot_data <- head(result_table, top_n_param)

  result_plot <- ggplot(plot_data, aes(x = reorder(pair, -count), y = count)) +
    geom_bar(stat = "identity", fill = "#e74c3c", alpha = 0.7) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9)) +
    labs(
      title = "Node Type Pair Distribution (Edge Analysis)",
      x = "Pair",
      y = "Count",
      subtitle = paste0("Top ", top_n_param, " out of ", nrow(result_table), " pairs")
    )

  logs <- c(logs, paste0("Chart shows top ", top_n_param, " type pairs"))
}
