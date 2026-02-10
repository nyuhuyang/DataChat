logs <- c(logs, "[force_network] Starting force-directed graph")

nodes_df <- NULL
edges_df <- NULL
edge_src_col <- NULL
edge_tgt_col <- NULL

find_edge_cols <- function(df) {
  cols <- tolower(names(df))
  src_candidates <- c("node_from", "from", "source", "src", "source_id", "from_id", "src_id")
  tgt_candidates <- c("node_to", "to", "target", "tgt", "target_id", "to_id", "tgt_id")
  src <- src_candidates[src_candidates %in% cols][1]
  tgt <- tgt_candidates[tgt_candidates %in% cols][1]
  if (!is.na(src) && !is.na(tgt)) return(list(src = src, tgt = tgt))
  if (ncol(df) >= 2) return(list(src = names(df)[1], tgt = names(df)[2]))
  NULL
}

find_node_id <- function(df) {
  cols <- tolower(names(df))
  id_candidates <- c("node_id", "id", "node", "name", "label")
  idc <- id_candidates[id_candidates %in% cols][1]
  if (!is.na(idc)) return(idc)
  if (ncol(df) >= 1) return(names(df)[1])
  NULL
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

  name_col <- if ("node_symbol" %in% tolower(names(nodes_df))) {
    "node_symbol"
  } else if ("name" %in% tolower(names(nodes_df))) {
    "name"
  } else if ("label" %in% tolower(names(nodes_df))) {
    "label"
  } else {
    node_id_col
  }
  node_type_col <- if ("node_type" %in% tolower(names(nodes_df))) "node_type" else NA_character_
  edge_type_col <- if ("edge_type" %in% tolower(names(edges_df))) "edge_type" else NA_character_

  nodes_work <- nodes_df
  edges_work <- edges_df

  if (!is.null(params$node_type) && !is.na(node_type_col)) {
    nodes_work <- nodes_work[nodes_work[[node_type_col]] %in% params$node_type, , drop = FALSE]
  }
  if (!is.null(params$node_symbol)) {
    nodes_work <- nodes_work[nodes_work[[name_col]] %in% params$node_symbol, , drop = FALSE]
  }
  if (!is.null(params$edge_type) && !is.na(edge_type_col)) {
    edges_work <- edges_work[edges_work[[edge_type_col]] %in% params$edge_type, , drop = FALSE]
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

  if (!is.null(params$max_edges)) {
    max_edges <- suppressWarnings(as.integer(params$max_edges[[1]]))
    if (!is.na(max_edges) && nrow(edges_work) > max_edges) {
      edges_work <- utils::head(edges_work, max_edges)
    }
  }

  if (!is.null(params$max_nodes)) {
    max_nodes <- suppressWarnings(as.integer(params$max_nodes[[1]]))
    if (!is.na(max_nodes) && nrow(nodes_work) > max_nodes) {
      nodes_work <- utils::head(nodes_work, max_nodes)
    }
  }

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
    result_table <- data.frame(Message = "No valid links after matching nodes to edges. Check node IDs.")
    logs <- c(logs, "[force_network] No valid links after matching IDs")
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
    logs <- c(logs, sprintf("[force_network] nodes=%d edges=%d", nrow(nodes), nrow(links)))
  }
}
