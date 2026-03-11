# ============================================================================
# Dataset profiling: summarize data and persist profile artifacts
# ============================================================================

sanitize_profile_stem <- function(filename) {
  stem <- tools::file_path_sans_ext(basename(filename))
  stem <- gsub("[^A-Za-z0-9._-]+", "_", stem)
  if (!nzchar(stem)) {
    return("dataset")
  }
  stem
}

get_profile_cache_paths <- function(filename, output_dir = datachat_profiles_dir()) {
  profile_stem <- paste0(sanitize_profile_stem(filename), "_profile")
  list(
    profile_stem = profile_stem,
    md_path = file.path(output_dir, paste0(profile_stem, ".md")),
    rds_path = file.path(output_dir, paste0(profile_stem, ".rds"))
  )
}

get_profile_file_signature <- function(file_path) {
  if (is.null(file_path) || !file.exists(file_path)) {
    return(NULL)
  }

  info <- file.info(file_path)
  if (nrow(info) == 0) {
    return(NULL)
  }

  list(
    normalized_path = normalizePath(file_path, winslash = "/", mustWork = FALSE),
    size = unname(info$size[[1]]),
    mtime = as.character(info$mtime[[1]])
  )
}

same_profile_signature <- function(x, y) {
  if (is.null(x) || is.null(y)) {
    return(FALSE)
  }

  identical(x$normalized_path, y$normalized_path) &&
    identical(x$size, y$size) &&
    identical(x$mtime, y$mtime)
}

format_profile_value <- function(x) {
  if (length(x) == 0 || all(is.na(x))) {
    return("NA")
  }

  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return("NA")
  }

  if (is.numeric(x)) {
    return(format(round(x[1], 3), trim = TRUE, scientific = FALSE))
  }

  as.character(x[1])
}

find_candidate_columns <- function(data, patterns) {
  cols <- names(data)
  cols_lower <- tolower(cols)
  matches <- unique(unlist(lapply(patterns, function(pattern) {
    cols[grepl(pattern, cols_lower, perl = TRUE)]
  })))

  matches[seq_len(min(length(matches), 8))]
}

build_column_profile <- function(data, col_name, max_levels = 5) {
  col_data <- data[[col_name]]
  col_class <- class(col_data)[1]
  missing_count <- sum(is.na(col_data))
  missing_pct <- round(100 * missing_count / max(1, nrow(data)), 1)
  unique_count <- dplyr::n_distinct(col_data, na.rm = TRUE)

  details <- c(sprintf("type=%s", col_class))
  details <- c(details, sprintf("missing=%.1f%%", missing_pct))
  details <- c(details, sprintf("unique=%s", unique_count))

  if (is.numeric(col_data)) {
    non_missing <- col_data[!is.na(col_data)]
    if (length(non_missing) > 0) {
      qs <- stats::quantile(non_missing, probs = c(0, 0.5, 1), names = FALSE, na.rm = TRUE)
      details <- c(
        details,
        sprintf("min=%s", format_profile_value(qs[1])),
        sprintf("median=%s", format_profile_value(qs[2])),
        sprintf("max=%s", format_profile_value(qs[3]))
      )
    }
  } else {
    top_values <- sort(table(as.character(col_data)), decreasing = TRUE)
    if (length(top_values) > 0) {
      top_values <- head(top_values, max_levels)
      top_text <- paste(
        sprintf("%s (%s)", names(top_values), as.integer(top_values)),
        collapse = ", "
      )
      details <- c(details, sprintf("top=%s", top_text))
    }
  }

  sprintf("- %s: %s", col_name, paste(details, collapse = " | "))
}

generate_profile_summary_text <- function(data, filename, source_type, source_id,
                                          schema_text, preview_summary = NULL,
                                          max_columns = 12) {
  numeric_cols <- names(data)[vapply(data, is.numeric, logical(1))]
  categorical_cols <- names(data)[vapply(data, function(x) is.character(x) || is.factor(x), logical(1))]

  likely_id_cols <- find_candidate_columns(data, c("(^id$)", "_id$", "^node_id$", "^edge_id$"))
  likely_join_cols <- find_candidate_columns(
    data,
    c("(^id$)", "_id$", "^from$", "^to$", "^source$", "^target$", "^node_from$", "^node_to$")
  )

  profile_lines <- c(
    sprintf("Dataset Profile: %s", filename),
    sprintf("Source Type: %s", source_type),
    sprintf("Dimensions: %d rows x %d columns", nrow(data), ncol(data)),
    sprintf("Numeric columns: %d", length(numeric_cols)),
    sprintf("Categorical columns: %d", length(categorical_cols))
  )

  if (!is.null(preview_summary)) {
    profile_lines <- c(
      profile_lines,
      sprintf("Detected format: %s", preview_summary$detected_format %||% "unknown"),
      sprintf("Overall missing rate: %.2f%%", preview_summary$missing_rate_pct %||% 0)
    )
  }

  if (length(likely_id_cols) > 0) {
    profile_lines <- c(profile_lines, sprintf("Likely ID columns: %s", paste(likely_id_cols, collapse = ", ")))
  }

  if (length(likely_join_cols) > 0) {
    profile_lines <- c(profile_lines, sprintf("Likely join columns: %s", paste(likely_join_cols, collapse = ", ")))
  }

  profile_lines <- c(profile_lines, "", "Column Profiles:")

  for (col_name in head(names(data), max_columns)) {
    profile_lines <- c(profile_lines, build_column_profile(data, col_name))
  }

  if (ncol(data) > max_columns) {
    profile_lines <- c(profile_lines, sprintf("- ... %d more column(s) omitted from brief profile", ncol(data) - max_columns))
  }

  profile_lines <- c(profile_lines, "", "Schema:", schema_text)

  paste(profile_lines, collapse = "\n")
}

generate_combined_profile_summary <- function(entries, dataset_name) {
  if (length(entries) == 0) {
    return("No dataset entries available.")
  }

  if (length(entries) == 1 && (is.null(entries[[1]]$sheet_name) || !nzchar(entries[[1]]$sheet_name))) {
    entry <- entries[[1]]
    return(generate_profile_summary_text(
      data = entry$data,
      filename = dataset_name,
      source_type = entry$source_type,
      source_id = entry$source_id,
      schema_text = entry$schema_text,
      preview_summary = entry$preview_summary
    ))
  }

  total_rows <- sum(vapply(entries, function(entry) entry$preview_summary$rows %||% 0, numeric(1)))
  total_cols <- sum(vapply(entries, function(entry) entry$preview_summary$cols %||% 0, numeric(1)))

  profile_lines <- c(
    sprintf("Workbook Profile: %s", dataset_name),
    sprintf("Sheets profiled: %d", length(entries)),
    sprintf("Total rows across sheets: %d", total_rows),
    sprintf("Total columns across sheets: %d", total_cols),
    ""
  )

  for (entry in entries) {
    sheet_label <- entry$sheet_name %||% entry$file_name
    profile_lines <- c(
      profile_lines,
      paste0("=== Sheet: ", sheet_label, " ==="),
      generate_profile_summary_text(
        data = entry$data,
        filename = paste0(dataset_name, "::", sheet_label),
        source_type = entry$source_type,
        source_id = entry$source_id,
        schema_text = entry$schema_text,
        preview_summary = entry$preview_summary
      ),
      ""
    )
  }

  paste(profile_lines, collapse = "\n")
}

write_combined_dataset_profile <- function(profile_entries, dataset_name,
                                           file_path = NULL,
                                           output_dir = datachat_profiles_dir()) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  cache_paths <- get_profile_cache_paths(dataset_name, output_dir)
  file_signature <- get_profile_file_signature(file_path)

  if (file.exists(cache_paths$rds_path)) {
    cached_profile <- tryCatch(readRDS(cache_paths$rds_path), error = function(e) NULL)
    if (!is.null(cached_profile) && same_profile_signature(cached_profile$file_signature, file_signature)) {
      cached_markdown <- if (file.exists(cache_paths$md_path)) {
        paste(readLines(cache_paths$md_path, warn = FALSE), collapse = "\n")
      } else {
        NULL
      }

      return(list(
        profile_text = cached_profile$summary_text,
        profile_markdown = cached_markdown,
        profile_md_path = cache_paths$md_path,
        profile_rds_path = cache_paths$rds_path,
        profile_cache_hit = TRUE
      ))
    }
  }

  summary_text <- generate_combined_profile_summary(profile_entries, dataset_name)

  profile_obj <- list(
    file_name = dataset_name,
    generated_at = as.character(Sys.time()),
    file_signature = file_signature,
    entry_count = length(profile_entries),
    entries = lapply(profile_entries, function(entry) {
      list(
        file_name = entry$file_name,
        sheet_name = entry$sheet_name,
        source_type = entry$source_type,
        row_count = nrow(entry$data),
        col_count = ncol(entry$data),
        preview_summary = entry$preview_summary,
        schema_text = entry$schema_text
      )
    }),
    summary_text = summary_text
  )

  markdown <- paste(
    paste0("# Dataset Profile: ", dataset_name),
    "",
    "```text",
    summary_text,
    "```",
    sep = "\n"
  )

  writeLines(markdown, cache_paths$md_path, useBytes = TRUE)
  saveRDS(profile_obj, cache_paths$rds_path)

  list(
    profile_text = summary_text,
    profile_markdown = markdown,
    profile_md_path = cache_paths$md_path,
    profile_rds_path = cache_paths$rds_path,
    profile_cache_hit = FALSE
  )
}

build_selected_profile_context <- function(selected_ids, data_sources) {
  if (length(selected_ids) == 0) {
    return("No selected datasets.")
  }

  context_parts <- c()
  seen_profile_paths <- character(0)

  for (source_id in selected_ids) {
    source <- data_sources$sources[[source_id]]
    if (is.null(source)) next

     profile_path <- source$profile_md_path %||% ""
     if (nzchar(profile_path) && profile_path %in% seen_profile_paths) {
       next
     }

    context_parts <- c(
      context_parts,
      paste0(
        "[", toupper(source$type), "] ", source$name, " (", source$row_count, "x", source$col_count, ")\n",
        source$profile_text %||% source$schema_text
      )
    )

    if (nzchar(profile_path)) {
      seen_profile_paths <- c(seen_profile_paths, profile_path)
    }
  }

  paste(context_parts, collapse = "\n\n")
}
