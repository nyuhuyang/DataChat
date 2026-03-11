# ============================================================================
# Server: Run history list and view buttons
# ============================================================================

server_history <- function(input, output, session, run_history, artifacts) {

  # Run history list
  output$run_history_list <- renderUI({
    if (length(run_history$runs) == 0) {
      return(div(
        class = "alert alert-secondary",
        "No runs yet. Send a query to generate artifacts!",
        style = "margin: 20px;"
      ))
    }

    # Reverse to show most recent first
    runs_rev <- rev(run_history$runs)

    run_cards <- lapply(runs_rev, function(run) {
      is_selected <- !is.null(run_history$selected_run_id) &&
                     run_history$selected_run_id == run$run_id

      # Status badge
      status_badge <- if (run$execution_status == "success") {
        span("\u2713 Success", class = "badge bg-secondary", style = "font-size: 10px;")
      } else {
        span("\u2717 Failed", class = "badge bg-dark", style = "font-size: 10px;")
      }

      # Mode badge
      mode_badge <- span(
        run$mode,
        class = "badge bg-secondary",
        style = "font-size: 10px; margin-left: 5px;"
      )

      # Sources badge (if available in run record)
      sources_badge <- if (!is.null(run$sources_used)) {
        source_types <- c()
        if (!is.null(run$sources_used$nodes)) source_types <- c(source_types, "N")
        if (!is.null(run$sources_used$edges)) source_types <- c(source_types, "E")
        if (!is.null(run$sources_used$metadata)) source_types <- c(source_types, "M")

        if (length(source_types) > 0) {
          span(
            paste(source_types, collapse="|"),
            class = "badge bg-secondary",
            style = "font-size: 9px; margin-left: 5px;",
            title = "Sources: N=Nodes, E=Edges, M=Metadata"
          )
        }
      }

      # Card styling
      card_style <- if (is_selected) {
        "border: 2px solid #6c757d; background-color: #f2f2f2; margin-bottom: 10px; padding: 12px; border-radius: 6px;"
      } else {
        "border: 1px solid #dee2e6; margin-bottom: 10px; padding: 12px; border-radius: 6px;"
      }

      div(
        style = card_style,
        # Header with timestamp and badges
        div(
          style = "display: flex; justify-content: space-between; margin-bottom: 8px;",
          div(format(run$timestamp, "%H:%M:%S"), style = "color: #666; font-size: 11px;"),
          div(sources_badge, mode_badge, status_badge)
        ),
        # Query text
        p(
          strong("Query: "),
          run$user_query,
          style = "margin-bottom: 8px; font-size: 13px; word-wrap: break-word;"
        ),
        # Action buttons
        div(
          style = "display: flex; gap: 5px; flex-wrap: wrap;",
          if (run$artifacts$table_artifact$exists) {
            actionButton(
              paste0("view_table_", run$run_id),
              NULL,
              icon = icon("table"),
              class = "btn-sm btn-outline-secondary",
              title = "View table"
            )
          },
          if (run$artifacts$plot_artifact$exists) {
            actionButton(
              paste0("view_plot_", run$run_id),
              NULL,
              icon = icon("chart-line"),
              class = "btn-sm btn-outline-secondary",
              title = "View plot"
            )
          },
          actionButton(
            paste0("view_code_", run$run_id),
            "Code",
            class = "btn-sm btn-outline-secondary"
          )
        )
      )
    })

    do.call(tagList, run_cards)
  })

  # Observe artifact view buttons
  observe({
    req(length(run_history$runs) > 0)

    lapply(run_history$runs, function(run) {
      # View table button
      if (run$artifacts$table_artifact$exists) {
        observeEvent(input[[paste0("view_table_", run$run_id)]], {
          artifacts$result_table <- run$artifacts$table_artifact$full
          artifacts$generated_code <- run$generated_code
          shinyjs::runjs("document.querySelector('[data-value=\"Table\"]').click()")
          run_history$selected_run_id <- run$run_id
        }, ignoreInit = TRUE)
      }

      # View plot button
      if (run$artifacts$plot_artifact$exists) {
        observeEvent(input[[paste0("view_plot_", run$run_id)]], {
          artifacts$result_plot <- run$artifacts$plot_artifact$plot_object
          artifacts$generated_code <- run$generated_code
          shinyjs::runjs("document.querySelector('[data-value=\"Plot\"]').click()")
          run_history$selected_run_id <- run$run_id
        }, ignoreInit = TRUE)
      }

      # View code button
      observeEvent(input[[paste0("view_code_", run$run_id)]], {
        artifacts$generated_code <- run$generated_code
        if (run$artifacts$table_artifact$exists) {
          artifacts$result_table <- run$artifacts$table_artifact$full
        }
        if (run$artifacts$plot_artifact$exists) {
          artifacts$result_plot <- run$artifacts$plot_artifact$plot_object
        }
        shinyjs::runjs("document.querySelector('[data-value=\"Generated R Code\"]').click()")
        run_history$selected_run_id <- run$run_id
      }, ignoreInit = TRUE)
    })
  })
}
