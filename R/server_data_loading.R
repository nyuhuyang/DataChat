# ============================================================================
# Server: Data loading handlers (file upload, existing files, checkbox list)
# ============================================================================

server_data_loading <- function(input, output, session,
                                 data_sources, selected_sources,
                                 active_dataset, active_dataset_metadata,
                                 messages, artifacts, data_load_msg,
                                 kg_ready, files_refresh) {
  register_loaded_entry <- function(entry, messages, artifacts, data_load_msg,
                                    data_sources, selected_sources,
                                    active_dataset, active_dataset_metadata,
                                    profile_info = NULL) {
    preview_result <- entry$preview_result
    data <- entry$data
    source_label <- entry$display_name

    if (!preview_result$success) {
      data_load_msg(paste("\u274c Error:", preview_result$error))
      return(FALSE)
    }

    if ("error" %in% names(data) && !is.null(data$error) && data$error) {
      data_load_msg(paste("\u274c Error:", data$message))
      return(FALSE)
    }

    source_type <- infer_source_type(data)
    source_id <- add_data_source(
      data = data,
      filename = source_label,
      source_type = source_type,
      data_sources = data_sources,
      preview_summary = preview_result$summary,
      file_path = entry$source_file_path,
      source_file_name = entry$source_file_name,
      sheet_name = entry$sheet_name,
      profile_info = profile_info
    )
    source_obj <- data_sources$sources[[source_id]]

    if (source_type == "nodes") {
      selected_sources$nodes_id <- source_id
      active_dataset(data)
      active_dataset_metadata(list(
        file_name = source_label,
        upload_time = Sys.time(),
        row_count = nrow(data),
        col_count = ncol(data)
      ))
    } else if (source_type == "edges") {
      selected_sources$edges_id <- source_id
    } else if (source_type == "metadata") {
      selected_sources$metadata_id <- source_id
    }

    data_load_msg(sprintf(
      "\u2713 Loaded %s: %d rows \u00d7 %d cols [%s]",
      source_label, nrow(data), ncol(data), toupper(source_type)
    ))

    summary_info <- preview_result$summary
    summary_text <- sprintf(
      "\U0001f4ca Data Summary:\n\u2022 Format: %s\n\u2022 Dimensions: %d rows \u00d7 %d cols\n\u2022 Numeric cols: %d | Categorical cols: %d\n\u2022 Missing rate: %.2f%%",
      summary_info$detected_format,
      summary_info$rows,
      summary_info$cols,
      summary_info$numeric_columns,
      summary_info$categorical_columns,
      summary_info$missing_rate_pct
    )

    if (!is.null(summary_info$sheet_name) && nzchar(summary_info$sheet_name)) {
      summary_text <- paste0(summary_text, "\n\u2022 Sheet: ", summary_info$sheet_name)
    }

    if (length(summary_info$columns_with_missing) > 0 && length(summary_info$columns_with_missing) <= 5) {
      summary_text <- paste0(
        summary_text,
        "\n\u2022 Cols with missing: ",
        paste(summary_info$columns_with_missing, collapse = ", ")
      )
    }

    messages$list[[length(messages$list) + 1]] <- list(
      role = "system",
      content = paste0("\u2713 Dataset loaded: ", source_label, "\n\n", summary_text),
      timestamp = Sys.time()
    )

    log_lines <- c(
      artifacts$logs,
      paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset loaded: ", source_label),
      paste0("  Format: ", summary_info$detected_format),
      paste0("  Dimensions: ", summary_info$rows, " rows \u00d7 ", summary_info$cols, " cols"),
      paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
      paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
      if (!is.null(summary_info$sheet_name) && nzchar(summary_info$sheet_name)) paste0("  Sheet: ", summary_info$sheet_name) else character(0),
      paste0("  Profile cache: ", if (isTRUE(source_obj$profile_cache_hit)) "reused" else "rebuilt"),
      paste0("  Profile: ", source_obj$profile_md_path)
    )
    artifacts$logs <- paste(log_lines, collapse = "\n")

    if (length(summary_info$detection_warnings) > 0) {
      warning_msg <- paste0(
        "\u26a0\ufe0f Detection notes:\n\u2022 ",
        paste(summary_info$detection_warnings, collapse = "\n\u2022 ")
      )
      artifacts$logs <- paste(artifacts$logs, warning_msg, sep = "\n")
    }

    artifacts$result_table <- NULL
    artifacts$result_plot <- NULL
    TRUE
  }

  prepare_profile_entries <- function(entries) {
    lapply(entries, function(entry) {
      if (!entry$preview_result$success) {
        return(entry)
      }

      data <- entry$data
      entry$source_type <- infer_source_type(data)
      entry$schema_text <- generate_schema_text(data)
      entry$source_id <- generate_source_id(entry$display_name)
      entry
    })
  }

  build_shared_profile_info <- function(entries, source_file_name, source_file_path) {
    valid_entries <- Filter(function(entry) {
      isTRUE(entry$preview_result$success) &&
        !("error" %in% names(entry$data) && isTRUE(entry$data$error))
    }, entries)

    if (length(valid_entries) == 0) {
      return(NULL)
    }

    profile_entries <- lapply(valid_entries, function(entry) {
      list(
        file_name = entry$display_name,
        sheet_name = entry$sheet_name,
        source_type = entry$source_type,
        source_id = entry$source_id,
        data = entry$data,
        schema_text = entry$schema_text,
        preview_summary = entry$preview_result$summary
      )
    })

    write_combined_dataset_profile(
      profile_entries = profile_entries,
      dataset_name = source_file_name,
      file_path = source_file_path
    )
  }

  # List existing files in data/input folder
  list_input_files <- reactive({
    files_refresh()
    input_dir <- datachat_input_dir()
    if (!dir.exists(input_dir)) {
      return(NULL)
    }

    files <- list.files(input_dir, full.names = TRUE)

    if (length(files) == 0) {
      return(NULL)
    }

    # Sort by modification time (newest first)
    files <- files[order(file.info(files)$mtime, decreasing = TRUE)]
    return(files)
  })

  # UI to show existing files (checkbox list)
  output$existing_files_ui <- renderUI({
    files <- list_input_files()
    if (is.null(files) || length(files) == 0) {
      return(NULL)
    }

    file_labels <- lapply(files, function(file_path) {
      file_name <- basename(file_path)
      file_size <- round(file.info(file_path)$size / 1024, 1) # KB
      HTML(sprintf(
        "%s<br><small style='color:#666;'>%s KB</small>",
        file_name,
        file_size
      ))
    })

    div(
      checkboxGroupInput(
        "input_files_list",
        NULL,
        choiceNames = file_labels,
        choiceValues = files,
        selected = character(0)
      )
    )
  })

  # Handle file load button clicks
  observe({
    files <- list_input_files()
    if (!is.null(files)) {
      lapply(seq_along(files), function(i) {
        observeEvent(input[[paste0("load_file_", i)]], {
          file_path <- files[i]
          file_name <- basename(file_path)

          # Simulate file input by calling the same logic as file_input
          session$sendCustomMessage("loadFileFromPath", list(
            path = file_path,
            name = file_name
          ))

          # Actually load the file directly here
          tryCatch({
            entries <- prepare_profile_entries(build_file_entries(file_path))
            shared_profile_info <- build_shared_profile_info(entries, file_name, file_path)
            lapply(entries, function(entry) {
              tryCatch({
                register_loaded_entry(
                  entry = entry,
                  messages = messages,
                  artifacts = artifacts,
                  data_load_msg = data_load_msg,
                  data_sources = data_sources,
                  selected_sources = selected_sources,
                  active_dataset = active_dataset,
                  active_dataset_metadata = active_dataset_metadata,
                  profile_info = shared_profile_info
                )
              }, error = function(e) {
                data_load_msg(paste("\u274c Error:", e$message))
              })
            })
          }, error = function(e) {
            data_load_msg(paste("\u274c Error:", e$message))
          })
        })
      })
    }
  })

  # Load selected files from data/input list (auto-detect node/edge)
  observeEvent(input$input_files_list, {
    selected_files <- input$input_files_list
    if (is.null(selected_files) || length(selected_files) == 0) {
      artifacts$selected_files <- character(0)
      return()
    }
    artifacts$selected_files <- selected_files

    for (file_path in selected_files) {
      file_name <- basename(file_path)

      # Skip if already loaded
      already_loaded <- any(vapply(data_sources$sources, function(s) {
        identical(s$file_name %||% s$name, file_name)
      }, logical(1)))
      if (already_loaded) next

      tryCatch({
        entries <- prepare_profile_entries(build_file_entries(file_path))
        shared_profile_info <- build_shared_profile_info(entries, file_name, file_path)
        lapply(entries, function(entry) {
          tryCatch({
            register_loaded_entry(
              entry = entry,
              messages = messages,
              artifacts = artifacts,
              data_load_msg = data_load_msg,
              data_sources = data_sources,
              selected_sources = selected_sources,
              active_dataset = active_dataset,
              active_dataset_metadata = active_dataset_metadata,
              profile_info = shared_profile_info
            )
          }, error = function(e) {
            data_load_msg(paste("\u274c Error:", e$message))
          })
        })

      }, error = function(e) {
        data_load_msg(paste("\u274c Error:", e$message))
      })
    }
  })

  # File upload handler with multi-format support
  observeEvent(input$file_input, {
    req(input$file_input)

    file_path <- input$file_input$datapath
    file_name <- input$file_input$name

    # Copy uploaded file to data/input directory
    dir.create(datachat_input_dir(), showWarnings = FALSE, recursive = TRUE)
    input_path <- file.path(datachat_input_dir(), file_name)
    file.copy(file_path, input_path, overwrite = TRUE)
    cat("[", format(Sys.time(), "%H:%M:%S"), "] File copied to", input_path, "\n")
    files_refresh(files_refresh() + 1)

    tryCatch({
      entries <- prepare_profile_entries(build_file_entries(input_path))
      shared_profile_info <- build_shared_profile_info(entries, file_name, input_path)
      lapply(entries, function(entry) {
        entry$source_file_path <- input_path
        tryCatch({
          register_loaded_entry(
            entry = entry,
            messages = messages,
            artifacts = artifacts,
            data_load_msg = data_load_msg,
            data_sources = data_sources,
            selected_sources = selected_sources,
            active_dataset = active_dataset,
            active_dataset_metadata = active_dataset_metadata,
            profile_info = shared_profile_info
          )
        }, error = function(e) {
          data_load_msg(paste("\u274c Error:", e$message))
          artifacts$logs <- paste(
            artifacts$logs,
            paste0("[ERROR] ", e$message),
            sep = "\n"
          )
        })
      })
    }, error = function(e) {
      data_load_msg(paste("\u274c Error:", e$message))
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[ERROR] ", e$message),
        sep = "\n"
      )
    })
  })
}
