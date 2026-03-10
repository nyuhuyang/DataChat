# ============================================================================
# UI: Sidebar panel with data loader
# ============================================================================

ui_sidebar <- function() {
  sidebar(
    # Data Loader Section
    h5("Data Loader"),
    fileInput(
      "file_input",
      "Upload Data",
      accept = c(".csv", ".tsv", ".txt", ".xlsx", ".xls", ".parquet", ".parq", ".rds"),
      multiple = FALSE
    ),
    helpText(
      "Supported: CSV, TSV, XLSX, Parquet, RDS",
      style = "font-size: 11px; color: #666;"
    ),
    uiOutput("existing_files_ui"),
    fill = FALSE
  )
}
