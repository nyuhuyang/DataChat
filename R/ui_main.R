# ============================================================================
# UI: Top-level UI assembly
# ============================================================================

build_ui <- function() {
  page_sidebar(
    title = "Data NotebookLM",
    theme = bs_theme(
      preset = "bootstrap",
      bg = "#ffffff",
      fg = "#212529",
      primary = "#343a40",
      secondary = "#6c757d",
      success = "#6c757d",
      info = "#6c757d",
      warning = "#6c757d",
      danger = "#6c757d",
      light = "#f8f9fa",
      dark = "#212529"
    ),
    shinyjs::useShinyjs(),
    ui_head_tags(),
    sidebar = ui_sidebar(),
    layout_columns(
      ui_chat_panel(),
      ui_artifacts_panel(),
      col_widths = c(6, 6)
    )
  )
}
