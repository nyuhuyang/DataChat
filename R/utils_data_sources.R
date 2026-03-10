# ============================================================================
# Data source management: type inference, ID generation, source pool
# ============================================================================

# Infer data source type from column names and structure
infer_source_type <- function(data) {
  cols <- tolower(names(data))

  # Check for edge indicators (from-to relationships)
  if (("from" %in% cols || "source" %in% cols) && ("to" %in% cols || "target" %in% cols)) {
    return("edges")
  }

  # Check for node indicators (IDs with names/labels)
  if ("id" %in% cols && ("name" %in% cols || "label" %in% cols)) {
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
add_data_source <- function(data, filename, source_type, data_sources) {
  source_id <- generate_source_id(filename)

  source_obj <- list(
    id = source_id,
    name = filename,
    type = source_type,
    data = data,
    schema_text = generate_schema_text(data),
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
