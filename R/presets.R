# ============================================================================
# Preset Prompts: Helper functions for loading and executing templates
# ============================================================================

# List all available presets with metadata
list_presets <- function() {
  list(
    list(
      id = "head",
      label = "Head: schema headers",
      file = NULL,
      description = "Combine headers (column names/types/missing) across all datasets"
    ),
    list(
      id = "node_type_distribution",
      label = "Node: node_type distribution",
      file = "node_type_distribution.R",
      description = "Count nodes by type with visualization"
    ),
    list(
      id = "edge_type_count",
      label = "Edge: edge_type count",
      file = "edge_type_count.R",
      description = "Count edges by type with visualization"
    ),
    list(
      id = "node_edge_join_summary",
      label = "Node–Edge: node_type_pair summary",
      file = "node_edge_join_summary.R",
      description = "Analyze node type pairs across edges and nodes"
    ),
    list(
      id = "schema_check",
      label = "Schema check",
      file = "schema_check.R",
      description = "Inspect all selected datasets schemas and data quality"
    ),
    list(
      id = "force_network",
      label = "Network: force graph",
      file = "force_network.R",
      description = "Render a force-directed network graph from nodes/edges"
    ),
    list(
      id = "graph_explore",
      label = "Network: explore graph",
      file = NULL,
      description = "Explore graph with filters (node_type, edge_type, node_symbol) and limits"
    )
  )
}

# Get full path to a template file
get_template_path <- function(template_file) {
  file.path("R", "templates", template_file)
}

# Load template code as a string
load_template <- function(preset_id) {
  presets <- list_presets()
  preset <- Filter(function(p) p$id == preset_id, presets)

  if (length(preset) == 0) {
    return(NULL)
  }

  if (preset_id == "graph_explore") {
    return(paste(
      "logs <- c(logs, '[graph_explore] Starting graph exploration')",
      "",
      "nodes_df <- NULL",
      "edges_df <- NULL",
      "edge_src_col <- NULL",
      "edge_tgt_col <- NULL",
      "",
      "find_edge_cols <- function(df) {",
      "  cols <- tolower(names(df))",
      "  src_candidates <- c('node_from','from','source','src','source_id','from_id','src_id')",
      "  tgt_candidates <- c('node_to','to','target','tgt','target_id','to_id','tgt_id')",
      "  src <- src_candidates[src_candidates %in% cols][1]",
      "  tgt <- tgt_candidates[tgt_candidates %in% cols][1]",
      "  if (!is.na(src) && !is.na(tgt)) return(list(src = src, tgt = tgt))",
      "  if (ncol(df) >= 2) return(list(src = names(df)[1], tgt = names(df)[2]))",
      "  NULL",
      "}",
      "",
      "find_node_id <- function(df) {",
      "  cols <- tolower(names(df))",
      "  id_candidates <- c('node_id','id','node','name','label')",
      "  idc <- id_candidates[id_candidates %in% cols][1]",
      "  if (!is.na(idc)) return(idc)",
      "  if (ncol(df) >= 1) return(names(df)[1])",
      "  NULL",
      "}",
      "",
      "for (nm in names(datasets)) {",
      "  df <- datasets[[nm]]",
      "  nm_lower <- tolower(nm)",
      "  if (grepl('edge', nm_lower)) {",
      "    edge_cols <- find_edge_cols(df)",
      "    if (!is.null(edge_cols)) {",
      "      edges_df <- df",
      "      edge_src_col <- edge_cols$src",
      "      edge_tgt_col <- edge_cols$tgt",
      "    }",
      "  }",
      "  if (grepl('node', nm_lower)) {",
      "    if (!is.null(find_node_id(df))) nodes_df <- df",
      "  }",
      "  if (is.null(edges_df)) {",
      "    edge_cols <- find_edge_cols(df)",
      "    if (!is.null(edge_cols)) {",
      "      edges_df <- df",
      "      edge_src_col <- edge_cols$src",
      "      edge_tgt_col <- edge_cols$tgt",
      "    }",
      "  }",
      "  if (is.null(nodes_df) && !is.null(find_node_id(df))) {",
      "    nodes_df <- df",
      "  }",
      "}",
      "",
      "if (is.null(edges_df) || is.null(nodes_df)) {",
      "  result_table <- data.frame(Message = 'Need both nodes and edges datasets selected.')",
      "  logs <- c(logs, '[graph_explore] Missing nodes or edges dataset')",
      "} else {",
      "  node_id_col <- find_node_id(nodes_df)",
      "  name_col <- if ('node_symbol' %in% tolower(names(nodes_df))) 'node_symbol' else if ('name' %in% tolower(names(nodes_df))) 'name' else if ('label' %in% tolower(names(nodes_df))) 'label' else node_id_col",
      "  node_type_col <- if ('node_type' %in% tolower(names(nodes_df))) 'node_type' else NA_character_",
      "  edge_type_col <- if ('edge_type' %in% tolower(names(edges_df))) 'edge_type' else NA_character_",
      "",
      "  if (length(params) == 0) {",
      "    node_types <- if (!is.na(node_type_col)) sort(unique(as.character(nodes_df[[node_type_col]]))) else character(0)",
      "    edge_types <- if (!is.na(edge_type_col)) sort(unique(as.character(edges_df[[edge_type_col]]))) else character(0)",
      "    result_table <- data.frame(",
      "      option = c(rep('node_type', length(node_types)), rep('edge_type', length(edge_types))),",
      "      value = c(node_types, edge_types),",
      "      stringsAsFactors = FALSE",
      "    )",
      "    logs <- c(logs, '[graph_explore] Returned available node_type and edge_type values')",
      "  } else {",
      "    nodes_work <- nodes_df",
      "    edges_work <- edges_df",
      "",
      "    if (!is.null(params$node_type) && !is.na(node_type_col)) {",
      "      nodes_work <- nodes_work[nodes_work[[node_type_col]] %in% params$node_type, , drop = FALSE]",
      "    }",
      "    if (!is.null(params$node_symbol)) {",
      "      nodes_work <- nodes_work[nodes_work[[name_col]] %in% params$node_symbol, , drop = FALSE]",
      "    }",
      "    if (!is.null(params$edge_type) && !is.na(edge_type_col)) {",
      "      edges_work <- edges_work[edges_work[[edge_type_col]] %in% params$edge_type, , drop = FALSE]",
      "    }",
      "",
      "    keep_ids <- as.character(nodes_work[[node_id_col]])",
      "    if (!is.null(params$node_symbol)) {",
      "      edges_work <- edges_work[edges_work[[edge_src_col]] %in% keep_ids | edges_work[[edge_tgt_col]] %in% keep_ids, , drop = FALSE]",
      "      if (nrow(edges_work) > 0) {",
      "        neighbor_ids <- unique(c(as.character(edges_work[[edge_src_col]]), as.character(edges_work[[edge_tgt_col]])))",
      "        nodes_work <- nodes_df[nodes_df[[node_id_col]] %in% neighbor_ids, , drop = FALSE]",
      "      }",
      "    } else {",
      "      edges_work <- edges_work[edges_work[[edge_src_col]] %in% keep_ids & edges_work[[edge_tgt_col]] %in% keep_ids, , drop = FALSE]",
      "    }",
      "",
      "    if (!is.null(params$max_edges)) {",
      "      max_edges <- suppressWarnings(as.integer(params$max_edges[[1]]))",
      "      if (!is.na(max_edges) && nrow(edges_work) > max_edges) {",
      "        edges_work <- utils::head(edges_work, max_edges)",
      "      }",
      "    }",
      "",
      "    if (!is.null(params$max_nodes)) {",
      "      max_nodes <- suppressWarnings(as.integer(params$max_nodes[[1]]))",
      "      if (!is.na(max_nodes) && nrow(nodes_work) > max_nodes) {",
      "        nodes_work <- utils::head(nodes_work, max_nodes)",
      "      }",
      "    }",
      "",
      "    if (nrow(nodes_work) == 0 || nrow(edges_work) == 0) {",
      "      result_table <- data.frame(Message = 'No data after filters. Relax filters or check values.')",
      "      logs <- c(logs, '[graph_explore] No data after filters')",
      "    } else {",
      "      nodes <- data.frame(",
      "        name = as.character(nodes_work[[name_col]]),",
      "        group = if (!is.na(node_type_col)) as.character(nodes_work[[node_type_col]]) else 'node',",
      "        stringsAsFactors = FALSE",
      "      )",
      "      src_idx <- match(edges_work[[edge_src_col]], nodes_work[[node_id_col]]) - 1",
      "      tgt_idx <- match(edges_work[[edge_tgt_col]], nodes_work[[node_id_col]]) - 1",
      "      valid <- !is.na(src_idx) & !is.na(tgt_idx) & src_idx >= 0 & tgt_idx >= 0",
      "      links <- data.frame(source = src_idx[valid], target = tgt_idx[valid], value = 1)",
      "      if (nrow(links) == 0) {",
      "        result_table <- data.frame(Message = 'No valid links after matching IDs. Check filters.')",
      "        logs <- c(logs, '[graph_explore] No valid links after filtering')",
      "      } else {",
      "        result_table <- data.frame(",
      "          Metric = c('nodes', 'edges', 'filters'),",
      "          Value = c(nrow(nodes), nrow(links), paste(names(params), unlist(params), sep = '=', collapse = '; ')),",
      "          stringsAsFactors = FALSE",
      "        )",
      "        result_plot <- forceNetwork(",
      "          Links = links, Nodes = nodes,",
      "          Source = 'source', Target = 'target',",
      "          Value = 'value', NodeID = 'name', Group = 'group',",
      "          opacity = 0.8, zoom = TRUE,",
      "          fontSize = 12, linkDistance = 80",
      "        )",
      "        logs <- c(logs, sprintf('[graph_explore] nodes=%d edges=%d', nrow(nodes), nrow(links)))",
      "      }",
      "    }",
      "  }",
      "}",
      sep = "\n"
    ))
  }

  if (preset_id == "head") {
    return(paste(
      "logs <- c(logs, '[head] Building combined head(5) table')",
      "rows <- list()",
      "max_cols <- 0",
      "for (nm in names(datasets)) {",
        "  df <- datasets[[nm]]",
        "  if (!is.data.frame(df)) next",
        "  max_cols <- max(max_cols, ncol(df))",
      "}",
      "col_names <- paste0('col_', seq_len(max_cols))",
      "single_mode <- (length(datasets) == 1)",
      "for (nm in names(datasets)) {",
        "  df <- datasets[[nm]]",
        "  if (!is.data.frame(df)) next",
        "  ncols <- ncol(df)",
      "  head_df <- utils::head(df, 5)",
      "  head_df <- dplyr::mutate(head_df, dplyr::across(dplyr::everything(), as.character))",
      "  if (!single_mode) {",
      "    # header row with real column names as data",
      "    header_vals <- rep('', max_cols)",
      "    if (ncols > 0) header_vals[1:ncols] <- names(df)",
      "    header_row <- as.data.frame(as.list(header_vals), stringsAsFactors = FALSE)",
      "    names(header_row) <- col_names",
      "    header_row <- dplyr::mutate(header_row, source = nm, .before = 1)",
      "  }",
      "  # data rows padded to max_cols",
      "  if (single_mode) {",
      "    data_block <- head_df",
      "  } else {",
      "    if (ncols == 0) {",
      "      data_block <- data.frame(matrix('', nrow = 0, ncol = max_cols))",
      "    } else {",
      "      data_block <- as.data.frame(head_df, stringsAsFactors = FALSE)",
      "      if (ncols < max_cols) {",
      "        for (i in (ncols + 1):max_cols) data_block[[i]] <- ''",
      "      }",
      "    }",
      "    names(data_block) <- col_names",
      "    data_block <- dplyr::mutate(data_block, source = nm, .before = 1)",
      "  }",
      "  if (!single_mode) {",
      "    blank_row <- as.data.frame(as.list(rep('', max_cols)), stringsAsFactors = FALSE)",
      "    names(blank_row) <- col_names",
      "    blank_row <- dplyr::mutate(blank_row, source = '', .before = 1)",
      "    rows[[length(rows) + 1]] <- header_row",
      "  }",
        "  rows[[length(rows) + 1]] <- data_block",
      "  if (!single_mode) rows[[length(rows) + 1]] <- blank_row",
      "}",
      "if (length(rows) == 0 || max_cols == 0) {",
      "  result_table <- data.frame(Message = 'No datasets available.')",
      "} else {",
      "  result_table <- dplyr::bind_rows(rows)",
      "}",
      "logs <- c(logs, sprintf('[head] sources=%d rows=%d', length(rows), nrow(result_table)))",
      sep = "\n"
    ))
  }

  template_file <- preset[[1]]$file
  template_path <- get_template_path(template_file)

  if (!file.exists(template_path)) {
    return(NULL)
  }

  tryCatch({
    readLines(template_path, warn = FALSE) %>%
      paste(collapse = "\n")
  }, error = function(e) {
    NULL
  })
}

# Safe execution of template code
# Inputs:
#   code: template script as string
#   datasets: named list of data.frames (names = source_id)
#   selected: character vector of source_ids to use
#   params: optional list of parameters (e.g., top_n = 20)
execute_template <- function(code, datasets, selected, params = list()) {
  # Load required packages into parent environment first
  library(dplyr, warn.conflicts = FALSE)
  library(ggplot2)
  library(tibble)
  library(networkD3)

  # Create execution environment with base parent (allows package access)
  exec_env <- new.env(parent = .BaseNamespaceEnv)

  # Bind input variables
  assign("datasets", datasets, envir = exec_env)
  assign("selected", selected, envir = exec_env)
  assign("params", params, envir = exec_env)

  # Initialize output variables (template must set these)
  assign("result_table", NULL, envir = exec_env)
  assign("result_plot", NULL, envir = exec_env)
  assign("logs", character(0), envir = exec_env)

  # Make dplyr, ggplot2, tibble functions available in exec_env
  tryCatch({
    eval(quote({
      # Import key functions from dplyr
      `%>%` <- dplyr::`%>%`
      select <- dplyr::select
      filter <- dplyr::filter
      mutate <- dplyr::mutate
      group_by <- dplyr::group_by
      summarise <- dplyr::summarise
      arrange <- dplyr::arrange
      left_join <- dplyr::left_join
      slice_max <- dplyr::slice_max
      across <- dplyr::across
      rename <- dplyr::rename

      # Import key functions from ggplot2
      ggplot <- ggplot2::ggplot
      aes <- ggplot2::aes
      aes_string <- ggplot2::aes_string
      geom_bar <- ggplot2::geom_bar
      geom_histogram <- ggplot2::geom_histogram
      geom_point <- ggplot2::geom_point
      geom_line <- ggplot2::geom_line
      geom_blank <- ggplot2::geom_blank
      theme_minimal <- ggplot2::theme_minimal
      theme_void <- ggplot2::theme_void
      theme <- ggplot2::theme
      labs <- ggplot2::labs
      ggtitle <- ggplot2::ggtitle
      element_text <- ggplot2::element_text
      reorder <- stats::reorder
      forceNetwork <- networkD3::forceNetwork
    }), envir = exec_env)
  }, error = function(e) {
    cat("Warning: Error importing functions:", e$message, "\n")
  })

  # Capture output and execute code
  output_capture <- capture.output({
    execution_result <- tryCatch({
      eval(parse(text = code), envir = exec_env)
      list(success = TRUE, error = NULL)
    }, error = function(e) {
      list(success = FALSE, error = e$message)
    })
  })

  # Extract results from execution environment
  result_table <- NULL
  result_plot <- NULL
  logs_output <- character(0)

  tryCatch({
    result_table <- get("result_table", envir = exec_env)
  }, error = function(e) {})

  tryCatch({
    result_plot <- get("result_plot", envir = exec_env)
  }, error = function(e) {})

  tryCatch({
    logs_output <- get("logs", envir = exec_env)
  }, error = function(e) {})

  # Combine logs and execution output
  final_output <- paste(output_capture, collapse = "\n")

  if (!execution_result$success) {
    final_output <- paste0(final_output, "\n[ERROR] ", execution_result$error)
  }

  # Convert logs to string
  if (is.null(logs_output) || length(logs_output) == 0) {
    logs_str <- final_output
  } else if (is.character(logs_output) && length(logs_output) > 0) {
    logs_str <- paste(logs_output, collapse = "\n")
    if (nchar(final_output) > 0) {
      logs_str <- paste(logs_str, final_output, sep = "\n---\n")
    }
  } else {
    logs_str <- final_output
  }

  return(list(
    output = logs_str,
    result_table = result_table,
    result_plot = result_plot,
    success = execution_result$success
  ))
}
