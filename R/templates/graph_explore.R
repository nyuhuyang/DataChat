logs <- c(logs, "[graph_explore] Starting graph exploration")

# ---------------------------------------------------------------------------
# Helper: case-insensitive column lookup (returns ACTUAL column name)
# ---------------------------------------------------------------------------
find_col <- function(df, candidates) {
  cols_lower <- tolower(names(df))
  for (cand in candidates) {
    idx <- which(cols_lower == cand)[1]
    if (!is.na(idx)) return(names(df)[idx])
  }
  NA_character_
}

find_edge_cols <- function(df) {
  src <- find_col(df, c("node_from", "from", "source", "src", "source_id", "from_id", "src_id"))
  tgt <- find_col(df, c("node_to", "to", "target", "tgt", "target_id", "to_id", "tgt_id"))
  if (!is.na(src) && !is.na(tgt)) return(list(src = src, tgt = tgt))
  if (ncol(df) >= 2) return(list(src = names(df)[1], tgt = names(df)[2]))
  NULL
}

find_node_id <- function(df) {
  res <- find_col(df, c("node_id", "id", "node", "name", "label"))
  if (!is.na(res)) return(res)
  if (ncol(df) >= 1) return(names(df)[1])
  NULL
}

# ---------------------------------------------------------------------------
# Auto-detect nodes and edges from selected datasets
# ---------------------------------------------------------------------------
nodes_df <- NULL
edges_df <- NULL
edge_src_col <- NULL
edge_tgt_col <- NULL

for (nm in names(datasets)) {
  df <- datasets[[nm]]
  nm_lower <- tolower(nm)
  if (grepl("edge", nm_lower)) {
    edge_cols <- find_edge_cols(df)
    if (!is.null(edge_cols)) {
      edges_df <- df
      edge_src_col <- edge_cols$src
      edge_tgt_col <- edge_cols$tgt
    }
  }
  if (grepl("node", nm_lower)) {
    if (!is.null(find_node_id(df))) nodes_df <- df
  }
  if (is.null(edges_df)) {
    edge_cols <- find_edge_cols(df)
    if (!is.null(edge_cols)) {
      edges_df <- df
      edge_src_col <- edge_cols$src
      edge_tgt_col <- edge_cols$tgt
    }
  }
  if (is.null(nodes_df) && !is.null(find_node_id(df))) {
    nodes_df <- df
  }
}

# ---------------------------------------------------------------------------
# Validate: both nodes and edges must be present
# ---------------------------------------------------------------------------
if (is.null(edges_df) || is.null(nodes_df)) {
  result_table <- data.frame(
    Message = "Need both nodes and edges datasets selected.",
    stringsAsFactors = FALSE
  )
  logs <- c(logs, "[graph_explore] Missing nodes or edges dataset")
} else {
  node_id_col <- find_node_id(nodes_df)
  name_col <- find_col(nodes_df, c("node_symbol", "name", "label"))
  if (is.na(name_col)) name_col <- node_id_col
  node_type_col <- find_col(nodes_df, c("node_type"))
  edge_type_col <- find_col(edges_df, c("edge_type"))

  logs <- c(logs, sprintf("[graph_explore] node_id=%s name=%s node_type=%s edge_type=%s",
    node_id_col, name_col,
    ifelse(is.na(node_type_col), "N/A", node_type_col),
    ifelse(is.na(edge_type_col), "N/A", edge_type_col)))

  # -------------------------------------------------------------------------
  # No params: show available filter options as a hint table
  # -------------------------------------------------------------------------
  if (length(params) == 0) {
    node_types <- if (!is.na(node_type_col)) sort(unique(as.character(nodes_df[[node_type_col]]))) else character(0)
    edge_types <- if (!is.na(edge_type_col)) sort(unique(as.character(edges_df[[edge_type_col]]))) else character(0)

    hint_rows <- list()

    # Usage hint row
    hint_rows[[length(hint_rows) + 1]] <- data.frame(
      option = "USAGE",
      value = "/graph_explore node_type=Gene edge_type=interacts_with max_nodes=100 max_edges=500",
      stringsAsFactors = FALSE
    )

    # Available filters
    if (length(node_types) > 0) {
      hint_rows[[length(hint_rows) + 1]] <- data.frame(
        option = rep("node_type", length(node_types)),
        value = node_types,
        stringsAsFactors = FALSE
      )
    } else {
      hint_rows[[length(hint_rows) + 1]] <- data.frame(
        option = "node_type",
        value = "(not available - no node_type column found)",
        stringsAsFactors = FALSE
      )
    }

    if (length(edge_types) > 0) {
      hint_rows[[length(hint_rows) + 1]] <- data.frame(
        option = rep("edge_type", length(edge_types)),
        value = edge_types,
        stringsAsFactors = FALSE
      )
    } else {
      hint_rows[[length(hint_rows) + 1]] <- data.frame(
        option = "edge_type",
        value = "(not available - no edge_type column found)",
        stringsAsFactors = FALSE
      )
    }

    # Optional params hint
    hint_rows[[length(hint_rows) + 1]] <- data.frame(
      option = c("node_symbol", "max_nodes", "max_edges"),
      value = c(
        "Filter by node name/symbol (e.g. node_symbol=caffeine)",
        "Limit number of nodes (e.g. max_nodes=100)",
        "Limit number of edges (e.g. max_edges=500)"
      ),
      stringsAsFactors = FALSE
    )

    result_table <- dplyr::bind_rows(hint_rows)
    logs <- c(logs, "[graph_explore] No params provided - showing available filter options")
    logs <- c(logs, "[graph_explore] Hint: run with params, e.g. /graph_explore node_type=Gene max_edges=200")

  } else {
    # -----------------------------------------------------------------------
    # Params provided: apply filters and render graph
    # -----------------------------------------------------------------------

    # Warn about unrecognized params
    known_params <- c("node_type", "edge_type", "node_symbol", "max_nodes", "max_edges")
    unknown <- setdiff(names(params), known_params)
    if (length(unknown) > 0) {
      logs <- c(logs, paste0(
        "[graph_explore] WARNING: unknown params ignored: ",
        paste(unknown, collapse = ", "),
        ". Valid params: ", paste(known_params, collapse = ", ")
      ))
    }

    # Warn if filtering on columns that don't exist
    if (!is.null(params$node_type) && is.na(node_type_col)) {
      logs <- c(logs, "[graph_explore] WARNING: node_type filter requested but no node_type column found in nodes data")
    }
    if (!is.null(params$edge_type) && is.na(edge_type_col)) {
      logs <- c(logs, "[graph_explore] WARNING: edge_type filter requested but no edge_type column found in edges data")
    }

    nodes_work <- nodes_df
    edges_work <- edges_df

    if (!is.null(params$node_type) && !is.na(node_type_col)) {
      nodes_work <- nodes_work[nodes_work[[node_type_col]] %in% params$node_type, , drop = FALSE]
      logs <- c(logs, sprintf("[graph_explore] After node_type filter: %d nodes", nrow(nodes_work)))
    }
    if (!is.null(params$node_symbol)) {
      # Case-insensitive match on node symbol/name
      matches <- tolower(as.character(nodes_work[[name_col]])) %in% tolower(params$node_symbol)
      nodes_work <- nodes_work[matches, , drop = FALSE]
      logs <- c(logs, sprintf("[graph_explore] After node_symbol filter: %d nodes", nrow(nodes_work)))
    }
    if (!is.null(params$edge_type) && !is.na(edge_type_col)) {
      edges_work <- edges_work[edges_work[[edge_type_col]] %in% params$edge_type, , drop = FALSE]
      logs <- c(logs, sprintf("[graph_explore] After edge_type filter: %d edges", nrow(edges_work)))
    }

    keep_ids <- as.character(nodes_work[[node_id_col]])
    if (!is.null(params$node_symbol)) {
      edges_work <- edges_work[edges_work[[edge_src_col]] %in% keep_ids | edges_work[[edge_tgt_col]] %in% keep_ids, , drop = FALSE]
      if (nrow(edges_work) > 0) {
        neighbor_ids <- unique(c(as.character(edges_work[[edge_src_col]]), as.character(edges_work[[edge_tgt_col]])))
        nodes_work <- nodes_df[nodes_df[[node_id_col]] %in% neighbor_ids, , drop = FALSE]
      }
    } else {
      edges_work <- edges_work[edges_work[[edge_src_col]] %in% keep_ids & edges_work[[edge_tgt_col]] %in% keep_ids, , drop = FALSE]
    }

    # Apply edge limit (user-specified or default 500)
    max_edges <- if (!is.null(params$max_edges)) {
      suppressWarnings(as.integer(params$max_edges[[1]]))
    } else {
      500L
    }
    if (!is.na(max_edges) && nrow(edges_work) > max_edges) {
      logs <- c(logs, sprintf("[graph_explore] Capping edges from %d to %d (use max_edges= to change)", nrow(edges_work), max_edges))
      edges_work <- utils::head(edges_work, max_edges)
    }

    # Apply node limit (user-specified or default 200)
    max_nodes <- if (!is.null(params$max_nodes)) {
      suppressWarnings(as.integer(params$max_nodes[[1]]))
    } else {
      200L
    }
    if (!is.na(max_nodes) && nrow(nodes_work) > max_nodes) {
      logs <- c(logs, sprintf("[graph_explore] Capping nodes from %d to %d (use max_nodes= to change)", nrow(nodes_work), max_nodes))
      nodes_work <- utils::head(nodes_work, max_nodes)
    }

    if (nrow(nodes_work) == 0 || nrow(edges_work) == 0) {
      result_table <- data.frame(Message = "No data after filters. Check filter values in Logs tab.")
      logs <- c(logs, sprintf("[graph_explore] No data after filters (nodes=%d edges=%d)", nrow(nodes_work), nrow(edges_work)))
    } else {
      nodes <- data.frame(
        name = as.character(nodes_work[[name_col]]),
        group = if (!is.na(node_type_col)) as.character(nodes_work[[node_type_col]]) else "node",
        stringsAsFactors = FALSE
      )
      src_idx <- match(edges_work[[edge_src_col]], nodes_work[[node_id_col]]) - 1
      tgt_idx <- match(edges_work[[edge_tgt_col]], nodes_work[[node_id_col]]) - 1
      valid <- !is.na(src_idx) & !is.na(tgt_idx) & src_idx >= 0 & tgt_idx >= 0
      links <- data.frame(source = src_idx[valid], target = tgt_idx[valid], value = 1)
      if (nrow(links) == 0) {
        result_table <- data.frame(Message = "No valid links after matching IDs. Check filters.")
        logs <- c(logs, "[graph_explore] No valid links after filtering")
      } else {
        result_table <- data.frame(
          Metric = c("nodes", "edges", "filters"),
          Value = c(nrow(nodes), nrow(links), paste(names(params), unlist(params), sep = "=", collapse = "; ")),
          stringsAsFactors = FALSE
        )
        result_plot <- forceNetwork(
          Links = links, Nodes = nodes,
          Source = "source", Target = "target",
          Value = "value", NodeID = "name", Group = "group",
          opacity = 0.8, zoom = TRUE,
          fontSize = 12, linkDistance = 80
        )
        logs <- c(logs, sprintf("[graph_explore] nodes=%d edges=%d", nrow(nodes), nrow(links)))
      }
    }
  }
}
