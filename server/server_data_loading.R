# ============================================================================
# Server: Data loading handlers (file upload, existing files, checkbox list)
# ============================================================================

server_data_loading <- function(input, output, session,
                                 data_sources, selected_sources,
                                 active_dataset, active_dataset_metadata,
                                 messages, artifacts, data_load_msg,
                                 kg_ready, files_refresh) {

  # List existing files in data/input folder
  list_input_files <- reactive({
    files_refresh()
    input_dir <- "data/input"
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
            preview_result <- preview_and_summarize(file_path)

            if (!preview_result$success) {
              error_msg <- preview_result$error
              data_load_msg(paste("\u274c Error:", error_msg))
              return()
            }

            data <- read_any(file_path)

            if ("error" %in% names(data) && !is.null(data$error) && data$error) {
              data_load_msg(paste("\u274c Error:", data$message))
              return()
            }

            tryCatch({
              source_type <- infer_source_type(data)
              source_id <- add_data_source(data, file_name, source_type, data_sources)

              if (source_type == "nodes") {
                selected_sources$nodes_id <- source_id
                active_dataset(data)
                active_dataset_metadata(list(
                  file_name = file_name,
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
                file_name, nrow(data), ncol(data), toupper(source_type)
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

              messages$list[[length(messages$list) + 1]] <- list(
                role = "system",
                content = paste0("\u2713 Dataset loaded: ", file_name, "\n\n", summary_text),
                timestamp = Sys.time()
              )

              artifacts$logs <- paste(
                artifacts$logs,
                paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset auto-loaded: ", file_name),
                paste0("  Format: ", summary_info$detected_format),
                paste0("  Dimensions: ", summary_info$rows, " rows \u00d7 ", summary_info$cols, " cols"),
                paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
                paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
                sep = "\n"
              )

              artifacts$result_table <- NULL
              artifacts$result_plot <- NULL

            }, error = function(e) {
              data_load_msg(paste("\u274c Error:", e$message))
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
      already_loaded <- any(vapply(data_sources$sources, function(s) s$name == file_name, logical(1)))
      if (already_loaded) next

      tryCatch({
        preview_result <- preview_and_summarize(file_path)
        if (!preview_result$success) {
          data_load_msg(paste("\u274c Error:", preview_result$error))
          next
        }

        data <- read_any(file_path)
        if ("error" %in% names(data) && !is.null(data$error) && data$error) {
          data_load_msg(paste("\u274c Error:", data$message))
          next
        }

        source_type <- infer_source_type(data)
        source_id <- add_data_source(data, file_name, source_type, data_sources)

        if (source_type == "nodes") {
          selected_sources$nodes_id <- source_id
          active_dataset(data)
          active_dataset_metadata(list(
            file_name = file_name,
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
          file_name, nrow(data), ncol(data), toupper(source_type)
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

        messages$list[[length(messages$list) + 1]] <- list(
          role = "system",
          content = paste0("\u2713 Dataset loaded: ", file_name, "\n\n", summary_text),
          timestamp = Sys.time()
        )

        artifacts$logs <- paste(
          artifacts$logs,
          paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset loaded from list: ", file_name),
          paste0("  Format: ", summary_info$detected_format),
          paste0("  Dimensions: ", summary_info$rows, " rows \u00d7 ", summary_info$cols, " cols"),
          paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
          paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
          sep = "\n"
        )

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
    dir.create("data/input", showWarnings = FALSE, recursive = TRUE)
    input_path <- file.path("data/input", file_name)
    file.copy(file_path, input_path, overwrite = TRUE)
    cat("[", format(Sys.time(), "%H:%M:%S"), "] File copied to", input_path, "\n")
    files_refresh(files_refresh() + 1)

    # Step 1: Auto-preview and summarize
    preview_result <- preview_and_summarize(file_path)

    if (!preview_result$success) {
      # Error occurred during preview/read
      error_msg <- preview_result$error
      suggestions_text <- if (length(preview_result$suggestions) > 0) {
        paste("Suggestions:", paste("\u2022 ", preview_result$suggestions, collapse = "\n"))
      } else {
        ""
      }

      data_load_msg(paste("\u274c Error:", error_msg))
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[", format(Sys.time(), "%H:%M:%S"), "] ERROR loading ", file_name),
        paste0("  Error: ", error_msg),
        if (suggestions_text != "") suggestions_text else "",
        sep = "\n"
      )

      # Show system message with error and suggestions
      messages$list[[length(messages$list) + 1]] <- list(
        role = "system",
        content = paste0(
          "\u26a0\ufe0f Failed to load ", file_name, ": ", error_msg,
          if (suggestions_text != "") paste0("\n\n", suggestions_text) else ""
        ),
        timestamp = Sys.time()
      )

      return()
    }

    # Step 2: Get full data now that preview succeeded
    data <- read_any(file_path)

    # Double-check: if read_any returns error (shouldn't happen since preview succeeded, but be safe)
    if ("error" %in% names(data) && !is.null(data$error) && data$error) {
      data_load_msg(paste("\u274c Error:", data$message))
      return()
    }

    # Success: continue with multi-source management
    tryCatch({
      # Auto-infer source type from data structure
      source_type <- infer_source_type(data)

      # Add to data source pool
      source_id <- add_data_source(data, file_name, source_type, data_sources)

      # Set as active source based on type
      if (source_type == "nodes") {
        selected_sources$nodes_id <- source_id
        active_dataset(data)
        active_dataset_metadata(list(
          file_name = file_name,
          upload_time = Sys.time(),
          row_count = nrow(data),
          col_count = ncol(data)
        ))
      } else if (source_type == "edges") {
        selected_sources$edges_id <- source_id
      } else if (source_type == "metadata") {
        selected_sources$metadata_id <- source_id
      }

      # Update status message
      data_load_msg(sprintf(
        "\u2713 Loaded %s: %d rows \u00d7 %d cols [%s]",
        file_name, nrow(data), ncol(data), toupper(source_type)
      ))

      # Build detailed summary message with preview info
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

      if (length(summary_info$columns_with_missing) > 0 && length(summary_info$columns_with_missing) <= 5) {
        summary_text <- paste0(
          summary_text,
          "\n\u2022 Cols with missing: ",
          paste(summary_info$columns_with_missing, collapse = ", ")
        )
      }

      # Add system message with summary
      messages$list[[length(messages$list) + 1]] <- list(
        role = "system",
        content = paste0(
          "\u2713 Dataset loaded: ", file_name, "\n\n", summary_text
        ),
        timestamp = Sys.time()
      )

      # Log detailed preview info to artifacts
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset auto-loaded: ", file_name),
        paste0("  Format: ", summary_info$detected_format),
        paste0("  Dimensions: ", summary_info$rows, " rows \u00d7 ", summary_info$cols, " cols"),
        paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
        paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
        sep = "\n"
      )

      # Add detection warnings if any
      if (length(summary_info$detection_warnings) > 0) {
        warning_msg <- paste0(
          "\u26a0\ufe0f Detection notes:\n\u2022 ",
          paste(summary_info$detection_warnings, collapse = "\n\u2022 ")
        )
        artifacts$logs <- paste(artifacts$logs, warning_msg, sep = "\n")
      }

      # Clear previous results when new data added
      artifacts$result_table <- NULL
      artifacts$result_plot <- NULL

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
