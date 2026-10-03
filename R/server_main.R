# ============================================================================
# Server: Main server function with reactive values and sub-module calls
# ============================================================================

build_server <- function(start_server = start_datachat_server) {
  function(input, output, session) {
    password <- Sys.getenv("DATACHAT_APP_PASSWORD", "")

    if (!nzchar(password)) {
      if (identical(Sys.getenv("R_CONFIG_ACTIVE"), "shinyapps")) {
        # Fail closed: never serve a public deployment without a password.
        showModal(modalDialog(
          title = "Configuration error",
          "DATACHAT_APP_PASSWORD is not set in the deployed .env file.",
          footer = NULL,
          easyClose = FALSE
        ))
        return(invisible(NULL))
      }
      return(start_server(input, output, session))
    }

    started <- FALSE
    failures <- 0
    locked_until <- Sys.time()

    showModal(modalDialog(
      title = "DataChat",
      passwordInput("app_password", "Password"),
      footer = actionButton("app_login", "Enter"),
      easyClose = FALSE
    ))

    observeEvent(input$app_login, {
      if (started) return()
      # ponytail: per-session cooldown only; a scripted attacker can open new sessions.
      if (Sys.time() < locked_until) {
        showNotification("Too many attempts. Wait a moment and retry.", type = "warning")
        return()
      }
      if (identical(input$app_password, password)) {
        started <<- TRUE
        removeModal()
        start_server(input, output, session)
      } else {
        failures <<- failures + 1
        locked_until <<- Sys.time() + min(2^(failures - 1), 30)
        showNotification("Incorrect password.", type = "error")
      }
    })
  }
}

start_datachat_server <- function(input, output, session) {
  # Reactive values
  dataset <- reactiveVal(NULL)
  messages <- reactiveValues(list = list())
  artifacts <- reactiveValues(
    logs = "",
    generated_code = "",
    result_table = NULL,
    result_plot = NULL,
    hide_colnames = FALSE,
    selected_files = character(0)
  )

  # Dataset metadata for Sources section
  dataset_metadata <- reactiveValues(
    file_name = NULL,
    upload_time = NULL,
    row_count = NULL,
    col_count = NULL
  )

  # Run history tracking
  run_history <- reactiveValues(
    runs = list(),
    selected_run_id = NULL
  )

  # Multi-source data management
  data_sources <- reactiveValues(
    sources = list(),           # id -> source object map
    source_order = c()          # vector of IDs in insertion order
  )

  # Track which sources are "selected" for current analysis
  selected_sources <- reactiveValues(
    nodes_id = NULL,      # ID of active nodes source
    edges_id = NULL,      # ID of active edges source
    metadata_id = NULL    # ID of active metadata source
  )

  # Keep for backward compatibility with run_history and UI
  active_dataset <- reactiveVal(NULL)
  active_dataset_metadata <- reactiveVal(NULL)

  # Reactive value to store data load status
  data_load_msg <- reactiveVal("")

  # Knowledge Graph readiness check
  kg_ready <- reactive({
    has_nodes <- any(sapply(data_sources$sources, function(x) x$type == "nodes"))
    has_edges <- any(sapply(data_sources$sources, function(x) x$type == "edges"))
    list(
      nodes = has_nodes,
      edges = has_edges,
      ready = has_nodes && has_edges
    )
  })

  # Refresh trigger for file list
  files_refresh <- reactiveVal(0)

  # Call sub-modules
  server_data_loading(input, output, session,
                      data_sources, selected_sources,
                      active_dataset, active_dataset_metadata,
                      messages, artifacts, data_load_msg,
                      kg_ready, files_refresh)

  server_chat(input, output, session,
              messages, artifacts, data_sources,
              selected_sources, run_history,
              active_dataset, active_dataset_metadata)

  server_artifacts(input, output, session, artifacts)

  server_history(input, output, session, run_history, artifacts)
}
