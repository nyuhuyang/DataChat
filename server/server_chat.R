# ============================================================================
# Server: Chat display and send message handler
# ============================================================================

server_chat <- function(input, output, session,
                         messages, artifacts, data_sources,
                         selected_sources, run_history,
                         active_dataset, active_dataset_metadata) {

  # Chat display
  output$chat_display <- renderUI({
    if (length(messages$list) == 0) {
      # Build preset command list dynamically
      preset_hints <- vapply(list_presets(), function(p) {
        paste0("/", p$id, " \u2014 ", p$description)
      }, character(1))

      return(div(
        style = "margin: 0; padding: 12px; font-size: 13px; color: #555;",
        h5("Welcome to DataChat", style = "margin-top: 0; color: #333;"),
        p("Upload data from the sidebar, then type a query below."),
        tags$strong("Free-text queries:"),
        tags$ul(
          style = "margin: 4px 0 10px 0; padding-left: 20px;",
          tags$li(tags$code("summary"), " \u2014 summary statistics"),
          tags$li(tags$code("head"), " \u2014 first rows of data"),
          tags$li(tags$code("histogram of column_name"), " \u2014 plot a histogram"),
          tags$li(tags$code("scatter x_col vs y_col"), " \u2014 scatter plot")
        ),
        tags$strong("Preset commands (slash commands):"),
        tags$ul(
          style = "margin: 4px 0 10px 0; padding-left: 20px;",
          lapply(preset_hints, function(h) tags$li(h))
        ),
        tags$strong("Graph examples:"),
        tags$ul(
          style = "margin: 4px 0 0 0; padding-left: 20px;",
          tags$li(tags$code('/force_network caffeine')),
          tags$li(tags$code('/force_network "bone marrow"')),
          tags$li(tags$code('/force_network node_type=Compound max_edges=300')),
          tags$li(tags$code('/graph_explore node_type=Anatomy max_nodes=100'))
        )
      ))
    }

    chat_html <- lapply(messages$list, function(msg) {
      bg_color <- switch(msg$role,
        user = "#f0f0f0",
        assistant = "#f5f5f5",
        system = "#ededed"
      )
      text_color <- switch(msg$role,
        user = "#333333",
        assistant = "#333333",
        system = "#333333"
      )

      div(
        style = paste0("margin-bottom: 12px; padding: 10px 12px; border-radius: 6px; background-color: ", bg_color, ";"),
        p(
          strong(paste0("[", msg$role, "]")),
          style = paste0("margin-bottom: 4px; color: ", text_color, "; font-size: 12px;")
        ),
        p(msg$content, style = "margin: 0; word-wrap: break-word; white-space: pre-wrap;"),
        tags$small(
          format(msg$timestamp, "%H:%M:%S"),
          style = "color: #666; font-size: 11px;"
        )
      )
    })

    do.call(tagList, chat_html)
  })

  # Send message handler - supports both preset and free-text modes
  observeEvent(input$send_btn, {
    # Resolve selected source IDs from checked files
    selected_files <- artifacts$selected_files
    selected_ids <- character(0)
    if (!is.null(selected_files) && length(selected_files) > 0) {
      selected_names <- basename(selected_files)
      selected_ids <- vapply(data_sources$source_order, function(id) {
        src <- data_sources$sources[[id]]
        if (!is.null(src) && src$name %in% selected_names) id else NA_character_
      }, character(1))
      selected_ids <- selected_ids[!is.na(selected_ids)]
    }

    # Determine mode from slash command in message (e.g., /node_type_distribution)
    preset_id <- NULL
    preset_params <- list()
    if (!is.null(input$user_input) && nzchar(trimws(input$user_input))) {
      cmd <- trimws(input$user_input)
      cmd <- sub("^/+", "/", cmd)
      if (startsWith(cmd, "/")) {
        token <- strsplit(cmd, "\\s+")[[1]][1]
        token <- substring(token, 2)
        preset_ids <- vapply(list_presets(), function(p) p$id, character(1))
        if (token %in% preset_ids) {
          preset_id <- token
          remainder <- trimws(sub(paste0("^/", token, "\\b"), "", cmd))
          if (nzchar(remainder)) {
            # Tokenize respecting quoted strings (e.g. "bone marrow" or key="bone marrow")
            tokens <- regmatches(remainder, gregexpr('(?:[^\\s"\']+|"[^"]*"|\'[^\']*\')+', remainder, perl = TRUE))[[1]]
            for (tok in tokens) {
              if (grepl("=", tok, fixed = TRUE)) {
                key <- sub("=.*$", "", tok)
                val <- sub("^[^=]*=", "", tok)
              } else {
                # Bare argument (no key=) → treat as node_symbol
                key <- "node_symbol"
                val <- tok
              }
              # Strip surrounding quotes
              if (grepl('^".*"$', val) || grepl("^'.*'$", val)) {
                val <- substring(val, 2, nchar(val) - 1)
              }
              if (key == "" || val == "") next
              if (!is.null(preset_params[[key]])) {
                preset_params[[key]] <- c(preset_params[[key]], val)
              } else {
                preset_params[[key]] <- val
              }
            }
          }
        }
      }
    }
    is_preset_mode <- !is.null(preset_id)

    if (!is_preset_mode) {
      req(input$user_input)
      user_msg <- input$user_input
      if (user_msg == "") return()

      use_llm <- isTRUE(input$use_llm)

      # Parse selected provider: "base_url::model"
      provider_val <- input$llm_provider
      provider_parts <- if (!is.null(provider_val) && grepl("::", provider_val, fixed = TRUE)) {
        strsplit(provider_val, "::", fixed = TRUE)[[1]]
      } else {
        c("", "")
      }

      # Add user message
      messages$list[[length(messages$list) + 1]] <- list(
        role = "user",
        content = user_msg,
        timestamp = Sys.time()
      )

      if (use_llm) {
        # ----- LLM chat mode: send conversation history to API -----
        progress <- Progress$new(session, min = 0, max = 2)
        on.exit(progress$close())
        progress$set(message = "Sending to LLM...", value = 1)

        # Build conversation history from messages (user + assistant only)
        chat_history <- Filter(
          function(msg) msg$role %in% c("user", "assistant"),
          messages$list
        )

        reply <- llm_chat(
          conversation_history = chat_history,
          base_url = provider_parts[1],
          api_key = Sys.getenv("DATACHAT_API_KEY", ""),
          model = provider_parts[2]
        )

        progress$set(message = "Done", value = 2)

        messages$list[[length(messages$list) + 1]] <- list(
          role = "assistant",
          content = reply,
          timestamp = Sys.time()
        )

        updateTextAreaInput(session, "user_input", value = "")

      } else {
        # ----- Rule-based code gen mode -----
        if (length(selected_ids) == 0) {
          shinyjs::runjs("alert('Please select at least one dataset from the left list.')")
          return()
        }

        progress <- Progress$new(session, min = 0, max = 3)
        on.exit(progress$close())

        progress$set(message = "Generating code", value = 1)

        # Build selected sources list by type
        sources_list <- list()
        for (sid in selected_ids) {
          src <- data_sources$sources[[sid]]
          if (is.null(src)) next
          if (src$type == "nodes") sources_list$nodes <- src
          if (src$type == "edges") sources_list$edges <- src
          if (src$type == "metadata") sources_list$metadata <- src
        }

        # Generate schema text for LLM context
        schema_text <- if (length(selected_ids) > 0) {
          schema_parts <- c()
          for (source_id in selected_ids) {
            source <- data_sources$sources[[source_id]]
            schema_parts <- c(schema_parts, paste0(
              "[", toupper(source$type), "] ", source$name, " (", source$row_count, "x", source$col_count, ")\n",
              source$schema_text
            ))
          }
          paste(schema_parts, collapse = "\n\n")
        } else {
          "No selected datasets."
        }

        progress$set(message = "Generating code", value = 2)

        generated_code <- generate_r_code(user_msg, schema_text)
        artifacts$generated_code <- generated_code

        progress$set(message = "Executing code", value = 3)

        exec_result <- execute_user_code(generated_code, sources_list = sources_list)

        artifacts$result_table <- exec_result$result_table
        artifacts$result_plot <- exec_result$result_plot
        artifacts$hide_colnames <- FALSE

        # Create run record
        run_id <- paste0("run_", format(Sys.time(), "%Y%m%d_%H%M%S_%OS3"))
        run_record <- list(
          run_id = run_id,
          timestamp = Sys.time(),
          user_query = user_msg,
          generated_code = generated_code,
          mode = "Rule-based",
          sources_used = list(
            nodes = selected_sources$nodes_id,
            edges = selected_sources$edges_id,
            metadata = selected_sources$metadata_id
          ),
          execution_status = if (exec_result$success) "success" else "failure",
          error_message = if (!exec_result$success) exec_result$output else NULL,
          artifacts = list(
            table_artifact = list(
              exists = !is.null(exec_result$result_table),
              full = exec_result$result_table
            ),
            plot_artifact = list(
              exists = !is.null(exec_result$result_plot),
              plot_object = exec_result$result_plot
            )
          )
        )
        run_history$runs[[length(run_history$runs) + 1]] <- run_record

        assistant_response <- paste0(
          "Generated R code for your query:\n\n",
          "```r\n", generated_code, "\n```\n\n",
          "(See 'Generated R Code' and 'Logs' tabs for execution details)"
        )

        messages$list[[length(messages$list) + 1]] <- list(
          role = "assistant",
          content = assistant_response,
          timestamp = Sys.time()
        )

        artifacts$logs <- paste(
          artifacts$logs,
          paste0("[", format(Sys.time(), "%H:%M:%S"), "] User: ", user_msg),
          paste0("[", format(Sys.time(), "%H:%M:%S"), "] Code executed"),
          paste0("Output:\n", exec_result$output),
          sep = "\n"
        )

        updateTextAreaInput(session, "user_input", value = "")
      }

    } else {
      # Preset mode
      if (length(selected_ids) == 0) {
        shinyjs::runjs("alert('Please select at least one dataset from the left list.')")
        return()
      }

      # Progress indicator
      progress <- Progress$new(session, min = 0, max = 3)
      on.exit(progress$close())

      progress$set(message = "Loading preset", value = 1)

      # Load preset template
      template_code <- load_template(preset_id)
      if (is.null(template_code)) {
        artifacts$logs <- paste(
          artifacts$logs,
          paste0("[", format(Sys.time(), "%H:%M:%S"), "] ERROR: Could not load preset template: ", preset_id),
          sep = "\n"
        )
        return()
      }

      progress$set(message = "Preparing datasets", value = 2)

      # Build datasets list from selected sources
      datasets_for_template <- list()
      for (source_id in selected_ids) {
        source <- data_sources$sources[[source_id]]
        if (!is.null(source)) {
          datasets_for_template[[source_id]] <- source$data
        }
      }

      # Get preset label for display
      presets <- list_presets()
      preset_label <- Filter(function(p) p$id == preset_id, presets)[[1]]$label

      # Add user message (preset selection)
      messages$list[[length(messages$list) + 1]] <- list(
        role = "user",
        content = paste0("\U0001f4cb Run preset: ", preset_label),
        timestamp = Sys.time()
      )

      progress$set(message = "Executing template", value = 3)

      # Execute template with selected datasets
      template_result <- execute_template(
        code = template_code,
        datasets = datasets_for_template,
        selected = selected_ids,
        params = preset_params
      )

      # Store results
      artifacts$result_table <- template_result$result_table
      artifacts$result_plot <- template_result$result_plot
      artifacts$generated_code <- template_code
      artifacts$hide_colnames <- (preset_id == "head" && length(selected_ids) > 1)
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[", format(Sys.time(), "%H:%M:%S"), "] Preset: ", preset_label),
        template_result$output,
        sep = "\n"
      )

      # Create run record
      run_id <- paste0("run_", format(Sys.time(), "%Y%m%d_%H%M%S_%OS3"))
      run_record <- list(
        run_id = run_id,
        timestamp = Sys.time(),
        user_query = preset_label,
        generated_code = template_code,
        mode = "Preset",
        sources_used = list(
          nodes = if ("nodes" %in% selected_ids) "nodes" else NULL,
          edges = if ("edges" %in% selected_ids) "edges" else NULL,
          metadata = if ("metadata" %in% selected_ids) "metadata" else NULL
        ),
        execution_status = if (template_result$success) "success" else "failure",
        error_message = if (!template_result$success) template_result$output else NULL,
        artifacts = list(
          table_artifact = list(
            exists = !is.null(template_result$result_table),
            full = template_result$result_table
          ),
          plot_artifact = list(
            exists = !is.null(template_result$result_plot),
            plot_object = template_result$result_plot
          )
        )
      )

      # Store in history
      run_history$runs[[length(run_history$runs) + 1]] <- run_record

      # Add assistant message — include hints for graph presets
      graph_preset_ids <- c("graph_explore", "force_network")
      assistant_response <- if (preset_id %in% graph_preset_ids && length(preset_params) == 0) {
        param_summary <- paste0(
          "Available filters:\n",
          "  node_type=<type>      Filter by node type\n",
          "  edge_type=<type>      Filter by edge type\n",
          "  node_symbol=<name>    Filter by node name/symbol\n",
          "  max_nodes=<n>         Limit nodes (default: 200)\n",
          "  max_edges=<n>         Limit edges (default: 500)\n"
        )
        paste0(
          "\u26a0\ufe0f No filters provided. Graph is capped at 200 nodes / 500 edges to avoid slowness.\n\n",
          param_summary, "\n",
          "Examples:\n",
          "  /", preset_id, " caffeine\n",
          '  /', preset_id, ' "bone marrow"\n',
          "  /", preset_id, " node_type=Compound max_edges=300\n",
          "  /", preset_id, " node_type=Anatomy max_nodes=100\n\n",
          'Tip: Pass a node name directly (e.g. /', preset_id, ' caffeine) to explore its neighborhood.\n',
          'Use quotes for names with spaces (e.g. /', preset_id, ' "bone marrow").\n\n',
          "See Table and Plot tabs for results."
        )
      } else if (preset_id %in% graph_preset_ids) {
        filters_used <- paste(names(preset_params), unlist(preset_params), sep = "=", collapse = ", ")
        paste0(
          "\u2705 Preset executed: ", preset_label, "\n",
          "Filters: ", filters_used, "\n\n",
          "See Table and Plot tabs for results.\n",
          "Tip: Add max_nodes= or max_edges= to limit graph size if slow."
        )
      } else {
        paste0(
          "\u2705 Preset executed: ", preset_label, "\n\n",
          "See tabs for results (Table, Plot, Logs, Generated R Code)"
        )
      }
      messages$list[[length(messages$list) + 1]] <- list(
        role = "assistant",
        content = assistant_response,
        timestamp = Sys.time()
      )

      # Reset preset selector
      updateTextAreaInput(session, "user_input", value = "")
    }
  })
}
