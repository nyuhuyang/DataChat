logs <- c(logs, "[force_network] Starting force-directed graph")

nodes_df <- NULL
edges_df <- NULL
edge_src_col <- NULL
edge_tgt_col <- NULL

# Case-insensitive column lookup: returns the ACTUAL column name from df
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

pick_node_key_col <- function(nodes_df, edges_df, edge_src_col, edge_tgt_col, id_col, label_col) {
  edge_values <- unique(c(as.character(edges_df[[edge_src_col]]), as.character(edges_df[[edge_tgt_col]])))

  id_hits <- sum(edge_values %in% as.character(nodes_df[[id_col]]))
  label_hits <- if (!is.na(label_col)) {
    sum(edge_values %in% as.character(nodes_df[[label_col]]))
  } else {
    -1L
  }

  if (label_hits > id_hits) {
    return(label_col)
  }

  id_col
}

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

if (is.null(edges_df)) {
  result_table <- data.frame(Message = "No edges dataset found. Need columns like from/to or source/target.")
  logs <- c(logs, "[force_network] No edges dataset found")
} else {
  if (is.null(nodes_df)) {
    node_ids <- unique(c(edges_df[[edge_src_col]], edges_df[[edge_tgt_col]]))
    nodes_df <- data.frame(id = node_ids, name = node_ids, stringsAsFactors = FALSE)
    node_id_col <- "id"
  } else {
    node_id_col <- find_node_id(nodes_df)
  }

  name_col <- find_col(nodes_df, c("node_symbol", "name", "label"))
  if (is.na(name_col)) name_col <- node_id_col
  node_type_col <- find_col(nodes_df, c("node_type"))
  edge_type_col <- find_col(edges_df, c("edge_type"))
  node_key_col <- pick_node_key_col(nodes_df, edges_df, edge_src_col, edge_tgt_col, node_id_col, name_col)

  logs <- c(logs, sprintf("[force_network] node_id=%s name=%s node_key=%s node_type=%s edge_type=%s",
    node_id_col, name_col, node_key_col,
    ifelse(is.na(node_type_col), "N/A", node_type_col),
    ifelse(is.na(edge_type_col), "N/A", edge_type_col)))

  nodes_work <- nodes_df
  edges_work <- edges_df

  if (!is.null(params$node_type) && !is.na(node_type_col)) {
    nodes_work <- nodes_work[nodes_work[[node_type_col]] %in% params$node_type, , drop = FALSE]
    logs <- c(logs, sprintf("[force_network] After node_type filter: %d nodes", nrow(nodes_work)))
  }
  if (!is.null(params$node_symbol)) {
    # Case-insensitive match on node symbol/name
    matches <- tolower(as.character(nodes_work[[name_col]])) %in% tolower(params$node_symbol)
    nodes_work <- nodes_work[matches, , drop = FALSE]
    logs <- c(logs, sprintf("[force_network] After node_symbol filter: %d nodes", nrow(nodes_work)))
  }
  if (!is.null(params$edge_type) && !is.na(edge_type_col)) {
    edges_work <- edges_work[edges_work[[edge_type_col]] %in% params$edge_type, , drop = FALSE]
    logs <- c(logs, sprintf("[force_network] After edge_type filter: %d edges", nrow(edges_work)))
  }

  keep_keys <- as.character(nodes_work[[node_key_col]])
  if (!is.null(params$node_symbol)) {
    edges_work <- edges_work[
      as.character(edges_work[[edge_src_col]]) %in% keep_keys |
      as.character(edges_work[[edge_tgt_col]]) %in% keep_keys,
      ,
      drop = FALSE
    ]
    if (nrow(edges_work) > 0) {
      neighbor_keys <- unique(c(as.character(edges_work[[edge_src_col]]), as.character(edges_work[[edge_tgt_col]])))
      nodes_work <- nodes_df[as.character(nodes_df[[node_key_col]]) %in% neighbor_keys, , drop = FALSE]
    }
  } else {
    edges_work <- edges_work[
      as.character(edges_work[[edge_src_col]]) %in% keep_keys &
      as.character(edges_work[[edge_tgt_col]]) %in% keep_keys,
      ,
      drop = FALSE
    ]
  }

  # Apply edge limit (user-specified or default 500)
  max_edges <- if (!is.null(params$max_edges)) {
    suppressWarnings(as.integer(params$max_edges[[1]]))
  } else {
    500L
  }
  if (!is.na(max_edges) && nrow(edges_work) > max_edges) {
    logs <- c(logs, sprintf("[force_network] Capping edges from %d to %d (use max_edges= to change)", nrow(edges_work), max_edges))
    edges_work <- utils::head(edges_work, max_edges)
  }

  if (nrow(edges_work) > 0) {
    edge_keys <- unique(c(as.character(edges_work[[edge_src_col]]), as.character(edges_work[[edge_tgt_col]])))
    nodes_work <- nodes_work[as.character(nodes_work[[node_key_col]]) %in% edge_keys, , drop = FALSE]
    logs <- c(logs, sprintf("[force_network] Nodes kept after edge alignment: %d", nrow(nodes_work)))
  }

  # Apply node limit (user-specified or default 200)
  max_nodes <- if (!is.null(params$max_nodes)) {
    suppressWarnings(as.integer(params$max_nodes[[1]]))
  } else {
    200L
  }
  if (!is.na(max_nodes) && nrow(nodes_work) > max_nodes) {
    logs <- c(logs, sprintf("[force_network] Capping nodes from %d to %d (use max_nodes= to change)", nrow(nodes_work), max_nodes))
    nodes_work <- utils::head(nodes_work, max_nodes)
  }

  if (nrow(nodes_work) == 0 || nrow(edges_work) == 0) {
    result_table <- data.frame(Message = "No data after filters. Check filter values in Logs tab.")
    logs <- c(logs, sprintf("[force_network] No data after filters (nodes=%d edges=%d)", nrow(nodes_work), nrow(edges_work)))
  } else {
    nodes <- data.frame(
      name = as.character(nodes_work[[name_col]]),
      group = if (!is.na(node_type_col)) as.character(nodes_work[[node_type_col]]) else "node",
      stringsAsFactors = FALSE
    )

    src_idx <- match(as.character(edges_work[[edge_src_col]]), as.character(nodes_work[[node_key_col]])) - 1
    tgt_idx <- match(as.character(edges_work[[edge_tgt_col]]), as.character(nodes_work[[node_key_col]])) - 1
    valid <- !is.na(src_idx) & !is.na(tgt_idx) & src_idx >= 0 & tgt_idx >= 0
    links <- data.frame(
      source = src_idx[valid],
      target = tgt_idx[valid],
      value = rep(1, sum(valid)),
      stringsAsFactors = FALSE
    )

    if (nrow(links) == 0) {
      result_table <- data.frame(Message = "No valid links after matching nodes to edges. Check node IDs.")
      logs <- c(logs, "[force_network] No valid links after matching IDs")
    } else {
      filters_text <- if (length(params) > 0) {
        paste(names(params), unlist(params), sep = "=", collapse = "; ")
      } else {
        ""
      }
      result_table <- data.frame(
        Metric = c("nodes", "edges", "filters"),
        Value = c(nrow(nodes), nrow(links), filters_text),
        stringsAsFactors = FALSE
      )
      result_plot <- forceNetwork(
        Links = links, Nodes = nodes,
        Source = "source", Target = "target",
        Value = "value", NodeID = "name", Group = "group",
        opacity = 0.8, zoom = TRUE,
        fontSize = 12, linkDistance = 80
      )
      logs <- c(logs, sprintf("[force_network] nodes=%d edges=%d", nrow(nodes), nrow(links)))
    }
  }
}
