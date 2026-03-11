# ============================================================================
# Server: Artifact output renderers (table, plot, code, logs)
# ============================================================================

server_artifacts <- function(input, output, session, artifacts) {

  # Artifact table output
  output$artifact_table <- DT::renderDataTable({
    if (is.null(artifacts$result_table)) {
      df <- data.frame(Message = "No table result yet. Execute code that creates 'result_table'.")
      return(DT::datatable(
        df,
        options = list(pageLength = 25, scrollX = TRUE),
        rownames = FALSE,
        colnames = if (artifacts$hide_colnames) rep("", ncol(df)) else colnames(df)
      ))
    }
    df <- artifacts$result_table
    DT::datatable(
      df,
      options = list(pageLength = 25, scrollX = TRUE),
      rownames = FALSE,
      colnames = if (artifacts$hide_colnames) rep("", ncol(df)) else colnames(df)
    )
  })

  # Artifact plot output
  output$artifact_plot_ui <- renderUI({
    if (is.null(artifacts$result_plot)) {
      plotOutput("artifact_plot", height = "500px")
    } else if (inherits(artifacts$result_plot, "htmlwidget")) {
      networkD3::forceNetworkOutput("artifact_plot_widget", height = "500px")
    } else {
      plotOutput("artifact_plot", height = "500px")
    }
  })

  output$artifact_plot <- renderPlot({
    if (is.null(artifacts$result_plot)) {
      return(ggplot() + geom_blank() + theme_void() +
             ggtitle("No plot result yet. Execute code that creates 'result_plot'."))
    }
    if (inherits(artifacts$result_plot, "htmlwidget")) {
      return(NULL)
    }
    artifacts$result_plot
  })

  output$artifact_plot_widget <- networkD3::renderForceNetwork({
    if (!is.null(artifacts$result_plot) && inherits(artifacts$result_plot, "htmlwidget")) {
      artifacts$result_plot
    } else {
      NULL
    }
  })

  # Artifact generated code output
  output$artifact_code <- renderText({
    if (artifacts$generated_code == "") {
      "No code generated yet..."
    } else {
      artifacts$generated_code
    }
  })

  # Artifact logs output
  output$artifact_logs <- renderText({
    if (artifacts$logs == "") {
      "No logs yet..."
    } else {
      artifacts$logs
    }
  })
}
