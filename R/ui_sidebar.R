# ============================================================================
# UI: Sidebar panel with data loader
# ============================================================================

# Parse DATACHAT_LLM_* env vars into a named list of "base_url::model" values
get_llm_providers <- function() {
  all_env <- Sys.getenv()
  llm_vars <- names(all_env)[grepl("^DATACHAT_LLM_", names(all_env))]
  # Auto-load .env if vars not found yet
  if (length(llm_vars) == 0 && file.exists(datachat_file(".env"))) {
    if (exists("load_dotenv", mode = "function")) load_dotenv()
    all_env <- Sys.getenv()
    llm_vars <- names(all_env)[grepl("^DATACHAT_LLM_", names(all_env))]
  }
  if (length(llm_vars) == 0) {
    cat("[providers] No DATACHAT_LLM_* env vars found\n")
    return(NULL)
  }

  providers <- list()
  for (var in llm_vars) {
    label <- sub("^DATACHAT_LLM_", "", var)
    label <- gsub("_", " ", label)
    val <- all_env[[var]]
    # Value format in .env: base_url|model → store as base_url::model
    parts <- strsplit(val, "[|]")[[1]]
    if (length(parts) == 2) {
      providers[[label]] <- paste0(parts[1], "::", parts[2])
      cat("[providers]", label, "->", parts[1], "|", parts[2], "\n")
    }
  }
  providers
}

ui_sidebar <- function() {
  has_env_key <- nzchar(Sys.getenv("DATACHAT_API_KEY", ""))
  providers <- get_llm_providers()

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

    # LLM Configuration Section
    hr(style = "margin: 15px 0;"),
    h5("LLM Settings"),
    checkboxInput("use_llm", "Enable LLM mode", value = TRUE),
    if (!is.null(providers) && length(providers) > 0) {
      selectInput(
        "llm_provider",
        "Provider",
        choices = providers
      )
    } else {
      helpText(
        "No providers configured. Add DATACHAT_LLM_* to .env",
        style = "font-size: 11px; color: #dc3545;"
      )
    },
    helpText(
      if (has_env_key) "API key loaded from .env" else "Set DATACHAT_API_KEY in .env file",
      style = paste0("font-size: 11px; color: ", if (has_env_key) "#28a745;" else "#dc3545;")
    ),
    fill = FALSE
  )
}
