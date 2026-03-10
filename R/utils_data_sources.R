# ============================================================================
# Data source management: type inference, ID generation, source pool
# ============================================================================

# Infer data source type from column names and structure
infer_source_type <- function(data) {
  cols <- names(data)
  cols <- cols[!is.na(cols) & nzchar(cols)]
  cols <- tolower(cols)

  # Check for edge indicators (from-to relationships)
  has_edge_start <- any(cols %in% c("from", "source", "node_from", "src", "source_id", "from_id"))
  has_edge_end <- any(cols %in% c("to", "target", "node_to", "tgt", "target_id", "to_id"))
  if (has_edge_start && has_edge_end) {
    return("edges")
  }

  # Check for node indicators (IDs with names/labels)
  has_node_id <- any(cols %in% c("id", "node_id", "nodeid"))
  has_node_label <- any(cols %in% c("name", "label", "node_symbol", "symbol"))
  has_node_type <- any(cols %in% c("node_type", "type"))
  if (has_node_id && (has_node_label || has_node_type)) {
    return("nodes")
  }

  # Default to metadata/other
  return("metadata")
}

# Generate unique source ID from filename and timestamp
generate_source_id <- function(filename, timestamp = Sys.time()) {
  base_name <- tools::file_path_sans_ext(filename)
  sprintf("%s_%s", base_name, format(timestamp, "%Y%m%d_%H%M%S_%OS3"))
}

# Add a new data source to the pool
add_data_source <- function(data, filename, source_type, data_sources, preview_summary = NULL,
                            file_path = NULL, source_file_name = NULL, sheet_name = NULL,
                            profile_info = NULL) {
  source_id <- generate_source_id(filename)
  schema_text <- generate_schema_text(data)

  source_obj <- list(
    id = source_id,
    name = filename,
    file_name = source_file_name %||% filename,
    sheet_name = sheet_name,
    type = source_type,
    data = data,
    schema_text = schema_text,
    profile_text = profile_info$profile_text %||% schema_text,
    profile_md_path = profile_info$profile_md_path %||% NA_character_,
    profile_rds_path = profile_info$profile_rds_path %||% NA_character_,
    profile_cache_hit = isTRUE(profile_info$profile_cache_hit),
    row_count = nrow(data),
    col_count = ncol(data),
    upload_time = Sys.time()
  )

  # Add to pool
  data_sources$sources[[source_id]] <- source_obj
  data_sources$source_order <- c(unlist(data_sources$source_order), source_id)

  return(source_id)
}

# Get currently selected sources
get_selected_sources <- function(data_sources, selected_sources) {
  sources_list <- list()

  if (!is.null(selected_sources$nodes_id)) {
    sources_list$nodes <- data_sources$sources[[selected_sources$nodes_id]]
  }
  if (!is.null(selected_sources$edges_id)) {
    sources_list$edges <- data_sources$sources[[selected_sources$edges_id]]
  }
  if (!is.null(selected_sources$metadata_id)) {
    sources_list$metadata <- data_sources$sources[[selected_sources$metadata_id]]
  }

  return(sources_list)
}
