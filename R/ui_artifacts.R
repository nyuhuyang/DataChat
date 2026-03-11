# ============================================================================
# UI: Artifacts panel (right column) with tabs
# ============================================================================

ui_artifacts_panel <- function() {
  card(
    full_screen = TRUE,
    navset_tab(
      id = "artifact_tabs",
      nav_panel(
        "Table",
        DT::dataTableOutput("artifact_table")
      ),
      nav_panel(
        "Plot",
        uiOutput("artifact_plot_ui")
      ),
      nav_panel(
        "Generated R Code",
        div(
          style = "height: 500px; overflow-y: auto;",
          verbatimTextOutput("artifact_code")
        )
      ),
      nav_panel(
        "Logs",
        div(
          style = "height: 500px; overflow-y: auto;",
          verbatimTextOutput("artifact_logs")
        )
      ),
      nav_panel(
        "History",
        div(
          style = "padding: 15px; height: 500px; overflow-y: auto;",
          uiOutput("run_history_list")
        )
      )
    )
  )
}
