library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(dplyr)
library(httr2)
library(readr)
library(readxl)
library(shinyjs)

# Source preset system helpers
source("R/presets.R")

# Optional: arrow for parquet support
if (!require("arrow", quietly = TRUE)) {
  arrow_available <- FALSE
} else {
  arrow_available <- TRUE
}

# ============================================================================
# Multi-format file reader function
# ============================================================================
read_any <- function(file_path) {
  tryCatch({
    # Get file extension
    ext <- tolower(tools::file_ext(file_path))

    # Read based on format
    if (ext %in% c("csv")) {
      readr::read_csv(file_path, show_col_types = FALSE)
    } else if (ext %in% c("tsv", "txt")) {
      readr::read_tsv(file_path, show_col_types = FALSE)
    } else if (ext %in% c("xlsx", "xls")) {
      as.data.frame(readxl::read_excel(file_path))
    } else if (ext %in% c("parquet", "parq")) {
      if (!arrow_available) {
        stop("Parquet format requires 'arrow' package. Install with: install.packages('arrow')")
      }
      as.data.frame(arrow::read_parquet(file_path))
    } else if (ext %in% c("rds")) {
      readRDS(file_path)
    } else {
      stop(sprintf("Unsupported file format: .%s. Supported: csv, tsv, txt, xlsx, rds", ext))
    }
  }, error = function(e) {
    list(error = TRUE, message = paste("Error reading file:", e$message))
  })
}

# ============================================================================
# Auto-detect file parameters (delimiter, encoding, etc.)
# ============================================================================
detect_file_params <- function(file_path, n_preview = 10) {
  ext <- tolower(tools::file_ext(file_path))

  result <- list(
    format = ext,
    delimiter = NULL,
    encoding = "UTF-8",
    has_header = TRUE,
    warnings = c()
  )

  # CSV/TSV auto-detection
  if (ext %in% c("csv", "tsv", "txt")) {
    tryCatch({
      # Read raw lines for analysis
      raw_lines <- readLines(file_path, n = min(5, 100), warn = FALSE)

      if (length(raw_lines) == 0) {
        result$warnings <- c(result$warnings, "File is empty")
        return(result)
      }

      # Auto-detect delimiter
      first_line <- raw_lines[1]
      comma_count <- length(gregexpr(",", first_line)[[1]]) - 1
      semicolon_count <- length(gregexpr(";", first_line)[[1]]) - 1
      tab_count <- length(gregexpr("\t", first_line)[[1]]) - 1
      pipe_count <- length(gregexpr("\\|", first_line)[[1]]) - 1

      # Handle case where pattern not found (returns -1)
      comma_count <- max(0, comma_count)
      semicolon_count <- max(0, semicolon_count)
      tab_count <- max(0, tab_count)
      pipe_count <- max(0, pipe_count)

      # Determine most likely delimiter
      counts <- c(
        comma = comma_count,
        semicolon = semicolon_count,
        tab = tab_count,
        pipe = pipe_count
      )

      if (ext == "tsv" || tab_count > 0) {
        result$delimiter <- "\t"
      } else if (max(counts) > 0) {
        delim_names <- c("comma", "semicolon", "tab", "pipe")
        result$delimiter <- switch(delim_names[which.max(counts)],
          comma = ",",
          semicolon = ";",
          tab = "\t",
          pipe = "|",
          ","
        )
      } else {
        result$delimiter <- ","
      }

    }, error = function(e) {
      result$warnings <<- c(result$warnings, paste("Detection error:", e$message))
    })
  }

  return(result)
}

# ============================================================================
# Preview and summarize data with error handling
# ============================================================================
preview_and_summarize <- function(file_path, max_rows = 100) {
  result <- list(
    success = FALSE,
    preview_table = NULL,
    summary = NULL,
    schema = NULL,
    error = NULL,
    suggestions = c()
  )

  tryCatch({
    # Detect file parameters
    params <- detect_file_params(file_path)

    # Read file
    data <- read_any(file_path)

    # Check for read errors (read_any returns list(error=TRUE, message=...) on failure)
    if ("error" %in% names(data) && !is.null(data$error) && data$error) {
      result$error <- data$message

      # Suggest fixes based on error message
      if (grepl("encoding", data$message, ignore.case = TRUE)) {
        result$suggestions <- c(
          "Try specifying different encoding (UTF-8, Latin1, etc.)",
          "Check if file contains non-ASCII characters"
        )
      } else if (grepl("delimiter|separator", data$message, ignore.case = TRUE)) {
        result$suggestions <- c(
          paste("Detected delimiter likely is:", params$delimiter),
          "Check if file uses different delimiter than detected"
        )
      } else if (grepl("permission|access", data$message, ignore.case = TRUE)) {
        result$suggestions <- c("Check file permissions and ensure file is not locked")
      }

      return(result)
    }

    # Success: generate preview and summary
    result$success <- TRUE

    # Preview table (first N rows)
    result$preview_table <- head(data, min(max_rows, nrow(data)))

    # Summary statistics
    numeric_cols <- names(data)[sapply(data, is.numeric)]
    categorical_cols <- names(data)[sapply(data, function(x) is.character(x) || is.factor(x))]

    missing_per_col <- colSums(is.na(data))
    missing_rate <- round(sum(is.na(data)) / (nrow(data) * ncol(data)) * 100, 2)

    result$summary <- list(
      file_name = basename(file_path),
      detected_format = params$format,
      detected_delimiter = params$delimiter,
      rows = nrow(data),
      cols = ncol(data),
      numeric_columns = length(numeric_cols),
      categorical_columns = length(categorical_cols),
      missing_rate_pct = missing_rate,
      columns_with_missing = names(missing_per_col)[missing_per_col > 0],
      detection_warnings = params$warnings
    )

    # Schema (from existing function)
    result$schema <- generate_schema_text(data)

  }, error = function(e) {
    result$error <<- e$message
    result$suggestions <<- c(
      "Check file format and encoding",
      "Verify file is not corrupted",
      "Try uploading a smaller sample"
    )
  })

  return(result)
}

# ============================================================================
# Rule-based code generation function
# ============================================================================
generate_r_code <- function(user_query, schema_text) {
  query_lower <- tolower(user_query)

  if (grepl("summary", query_lower)) {
    return("print(summary(df))\nresult_table <- data.frame(\n  Variable = names(df),\n  Type = sapply(df, class),\n  NonNA_Count = colSums(!is.na(df))\n)")
  } else if (grepl("hist|distribution", query_lower)) {
    return("numeric_cols <- names(df)[sapply(df, is.numeric)]\nif (length(numeric_cols) > 0) {\n  result_plot <- ggplot(df, aes_string(x = numeric_cols[1])) + \n    geom_histogram(bins = 30, fill = '#6c757d', alpha = 0.7, color = 'white') + \n    theme_minimal() + \n    ggtitle(paste('Distribution of', numeric_cols[1]))\n} else {\n  print('No numeric columns to plot')\n}")
  } else if (grepl("count by", query_lower)) {
    return("result_table <- df %>%\n  group_by(across(everything())) %>%\n  summarise(count = n(), .groups = 'drop') %>%\n  arrange(desc(count)) %>%\n  head(20)")
  } else {
    return("result_table <- head(df, 10)\nprint('Showing first 10 rows')")
  }
}

# Generate formatted schema text for LLM
generate_schema_text <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    return("No data available")
  }

  schema_parts <- c()
  schema_parts <- c(schema_parts, paste0("Dataset: ", nrow(data), " rows, ", ncol(data), " columns\n"))
  schema_parts <- c(schema_parts, "Columns:")

  for (col_name in names(data)) {
    col_type <- class(data[[col_name]])[1]
    missing_count <- sum(is.na(data[[col_name]]))
    missing_pct <- round(100 * missing_count / nrow(data), 1)

    # Add range/sample info
    sample_info <- ""
    if (is.numeric(data[[col_name]])) {
      range_vals <- range(data[[col_name]], na.rm = TRUE)
      sample_info <- sprintf(" [range: %.2f to %.2f]", range_vals[1], range_vals[2])
    } else if (is.factor(data[[col_name]]) || is.character(data[[col_name]])) {
      unique_vals <- unique(data[[col_name]])
      if (length(unique_vals) <= 5) {
        sample_info <- paste0(" [values: ", paste(head(unique_vals, 5), collapse = ", "), "]")
      } else {
        sample_info <- paste0(" [", length(unique_vals), " unique values]")
      }
    }

    schema_parts <- c(schema_parts,
                     sprintf("  - %s: %s (%.1f%% missing)%s",
                             col_name, col_type, missing_pct, sample_info))
  }

  return(paste(schema_parts, collapse = "\n"))
}

# LLM-based code generation function
llm_generate_r_code <- function(user_query, schema_text, base_url, api_key) {
  # Validate inputs
  if (is.null(base_url) || base_url == "" || is.null(api_key) || api_key == "") {
    stop("API Base URL and API Key are required for LLM mode")
  }

  # Build endpoint URL
  endpoint <- paste0(base_url, "/chat/completions")

  # System prompt with strict instructions
  system_prompt <- paste0(
    "You are an expert R data analyst. ",
    "Generate ONLY executable R code without any markdown formatting, explanations, or backticks.\n\n",
    "Rules:\n",
    "- The dataset is available as 'df'\n",
    "- Libraries dplyr, ggplot2, and tibble are already loaded\n",
    "- Store data frame results in 'result_table'\n",
    "- Store ggplot objects in 'result_plot'\n",
    "- Use print() for text output\n",
    "- Output ONLY the R code, no explanations\n\n",
    "Data Schema:\n", schema_text
  )

  # User message
  user_message <- paste0("Generate R code for: ", user_query)

  # Request body
  request_body <- list(
    model = "gpt-4",
    messages = list(
      list(role = "system", content = system_prompt),
      list(role = "user", content = user_message)
    ),
    temperature = 0.3,
    max_tokens = 1000
  )

  # API call with error handling
  tryCatch({
    response <- httr2::request(endpoint) %>%
      httr2::req_headers(
        "Content-Type" = "application/json",
        "Authorization" = paste("Bearer", api_key)
      ) %>%
      httr2::req_body_json(request_body) %>%
      httr2::req_timeout(30) %>%
      httr2::req_retry(max_tries = 2) %>%
      httr2::req_error(is_error = function(resp) FALSE) %>%
      httr2::req_perform()

    # Check status
    status <- httr2::resp_status(response)
    if (status != 200) {
      error_body <- httr2::resp_body_json(response, simplifyVector = FALSE)
      error_msg <- if (!is.null(error_body$error$message)) {
        error_body$error$message
      } else {
        paste("HTTP", status, "error")
      }
      stop(paste("API Error:", error_msg))
    }

    # Parse response
    result <- httr2::resp_body_json(response, simplifyVector = FALSE)

    if (!is.null(result$choices) && length(result$choices) > 0) {
      generated_code <- result$choices[[1]]$message$content

      # Clean up markdown artifacts
      generated_code <- gsub("```r\\n?", "", generated_code)
      generated_code <- gsub("```\\n?", "", generated_code)
      generated_code <- trimws(generated_code)

      return(generated_code)
    } else {
      stop("No code in API response")
    }

  }, error = function(e) {
    # Return error as printable code
    error_code <- paste0(
      "# LLM Error: ", e$message, "\n",
      "print('Code generation failed: ", gsub("'", "\\\\'", e$message), "')"
    )
    return(error_code)
  })
}

# Code generation router function
generate_code_with_mode <- function(user_query, schema_text, use_llm, base_url = NULL, api_key = NULL) {
  if (use_llm) {
    # Validate LLM credentials
    if (is.null(base_url) || base_url == "" || is.null(api_key) || api_key == "") {
      # Fallback to rule-based
      warning_code <- paste0(
        "print('Warning: LLM enabled but credentials missing. Using rule-based mode.')\n\n",
        generate_r_code(user_query, schema_text)
      )
      return(warning_code)
    }

    # Use LLM
    return(llm_generate_r_code(user_query, schema_text, base_url, api_key))
  } else {
    # Use rule-based
    return(generate_r_code(user_query, schema_text))
  }
}

# Infer data source type from column names and structure
infer_source_type <- function(data) {
  cols <- tolower(names(data))

  # Check for edge indicators (from-to relationships)
  if (("from" %in% cols || "source" %in% cols) && ("to" %in% cols || "target" %in% cols)) {
    return("edges")
  }

  # Check for node indicators (IDs with names/labels)
  if ("id" %in% cols && ("name" %in% cols || "label" %in% cols)) {
    return("nodes")
  }

  # Default to metadata/other
  return("metadata")
}

# Generate unique source ID from filename and timestamp
generate_source_id <- function(filename, timestamp = Sys.time()) {
  base_name <- tools::file_path_sans_ext(filename)
  sprintf("%s_%s", base_name, format(timestamp, "%Y%m%d_%H%M%S_%OS3"))
}

# Add a new data source to the pool
add_data_source <- function(data, filename, source_type, data_sources) {
  source_id <- generate_source_id(filename)

  source_obj <- list(
    id = source_id,
    name = filename,
    type = source_type,
    data = data,
    schema_text = generate_schema_text(data),
    row_count = nrow(data),
    col_count = ncol(data),
    upload_time = Sys.time()
  )

  # Add to pool
  data_sources$sources[[source_id]] <- source_obj
  data_sources$source_order <- c(unlist(data_sources$source_order), source_id)

  return(source_id)
}

# Get currently selected sources
get_selected_sources <- function(data_sources, selected_sources) {
  sources_list <- list()

  if (!is.null(selected_sources$nodes_id)) {
    sources_list$nodes <- data_sources$sources[[selected_sources$nodes_id]]
  }
  if (!is.null(selected_sources$edges_id)) {
    sources_list$edges <- data_sources$sources[[selected_sources$edges_id]]
  }
  if (!is.null(selected_sources$metadata_id)) {
    sources_list$metadata <- data_sources$sources[[selected_sources$metadata_id]]
  }

  return(sources_list)
}

# Safe code execution function
execute_user_code <- function(code, data = NULL, sources_list = NULL) {
  # Create isolated execution environment
  exec_env <- new.env(parent = emptyenv())

  # Handle backward compatibility: if sources_list provided, use it; otherwise use single data
  if (!is.null(sources_list) && length(sources_list) > 0) {
    # Bind multiple sources by type
    if (!is.null(sources_list$nodes)) {
      assign("df_nodes", sources_list$nodes$data, envir = exec_env)
    }
    if (!is.null(sources_list$edges)) {
      assign("df_edges", sources_list$edges$data, envir = exec_env)
    }
    if (!is.null(sources_list$metadata)) {
      assign("df_metadata", sources_list$metadata$data, envir = exec_env)
    }

    # For backward compatibility: if only one source, also bind as 'df'
    if (length(sources_list) == 1) {
      assign("df", sources_list[[1]]$data, envir = exec_env)
    }
  } else if (!is.null(data)) {
    # Backward compatibility: single data parameter
    assign("df", data, envir = exec_env)
  }

  # Load required packages into the execution environment
  tryCatch({
    eval(quote(library(dplyr, warn.conflicts = FALSE)), envir = exec_env)
    eval(quote(library(ggplot2)), envir = exec_env)
    eval(quote(library(tibble)), envir = exec_env)
  }, error = function(e) {
    cat("Warning: Error loading packages:", e$message, "\n")
  })

  # Capture output and execute code
  output_capture <- capture.output({
    execution_result <- tryCatch({
      eval(parse(text = code), envir = exec_env)
      list(success = TRUE, error = NULL)
    }, error = function(e) {
      list(success = FALSE, error = e$message)
    })
  })

  # Extract results if they exist
  result_table <- NULL
  result_plot <- NULL

  tryCatch({
    result_table <- get("result_table", envir = exec_env)
  }, error = function(e) {})

  tryCatch({
    result_plot <- get("result_plot", envir = exec_env)
  }, error = function(e) {})

  # Combine output
  final_output <- paste(output_capture, collapse = "\n")
  if (!execution_result$success) {
    final_output <- paste(final_output, paste0("\n[ERROR] ", execution_result$error), sep = "")
  }

  return(list(
    output = final_output,
    result_table = result_table,
    result_plot = result_plot,
    success = execution_result$success
  ))
}

ui <- page_sidebar(
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
  tags$head(
    tags$style(HTML("
      .cmd-menu {
        position: absolute;
        z-index: 1000;
        background: #ffffff;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.08);
        max-height: 200px;
        overflow-y: auto;
        display: none;
      }
      .cmd-item {
        padding: 6px 10px;
        cursor: pointer;
        font-size: 12px;
      }
      .cmd-item:hover {
        background: #f2f2f2;
      }
    ")),
    tags$script(HTML(paste0("
      const PRESETS = [",
      paste(vapply(list_presets(), function(p) {
        label <- gsub("'", "\\\\'", p$label)
        id <- gsub("'", "\\\\'", p$id)
        sprintf("{id:'%s', label:'%s'}", id, label)
      }, character(1)), collapse = ","),
      "];

      function buildMenu(menu) {
        menu.innerHTML = '';
        PRESETS.forEach(p => {
          const item = document.createElement('div');
          item.className = 'cmd-item';
          item.textContent = p.label + '  /' + p.id;
          item.dataset.id = p.id;
          menu.appendChild(item);
        });
      }

      function showMenu(menu, show) {
        menu.style.display = show ? 'block' : 'none';
      }

      document.addEventListener('DOMContentLoaded', () => {
        const ta = document.getElementById('user_input');
        const menu = document.getElementById('cmd_menu');
        if (!ta || !menu) return;
        buildMenu(menu);

        function shouldShowMenu(value, pos) {
          const upto = value.slice(0, pos);
          const lastToken = upto.split(/\\s+/).pop();
          return lastToken === '/';
        }

        ta.addEventListener('keyup', (e) => {
          const pos = ta.selectionStart || 0;
          showMenu(menu, shouldShowMenu(ta.value, pos));
        });

        ta.addEventListener('focus', () => {
          const pos = ta.selectionStart || 0;
          showMenu(menu, shouldShowMenu(ta.value, pos));
        });

        document.addEventListener('click', (e) => {
          if (e.target === ta || menu.contains(e.target)) return;
          showMenu(menu, false);
        });

        menu.addEventListener('mousedown', (e) => {
          e.preventDefault();
          const target = e.target;
          if (!target || !target.dataset.id) return;
          const insert = '/' + target.dataset.id + ' ';
          const start = ta.selectionStart || 0;
          const end = ta.selectionEnd || 0;
          const before = ta.value.slice(0, start);
          const after = ta.value.slice(end);
          if (/(^|\\s)\\/$/.test(before)) {
            const newBefore = before.replace(/(^|\\s)\\/$/, '$1' + insert);
            ta.value = newBefore + after;
          } else {
            ta.value = before + insert + after;
          }
          ta.focus();
          const newPos = (ta.value.slice(0, ta.value.length - after.length)).length;
          ta.selectionStart = ta.selectionEnd = newPos;
          showMenu(menu, false);
        });
      });
    ")))
  ),

  # Sidebar
  sidebar = sidebar(
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
  ),

  # Main content - two columns
  layout_columns(
    # Left column: Chat
    card(
      full_screen = TRUE,
      card_header("Chat"),
      div(
        style = "border: 1px solid #dee2e6; border-radius: 6px; padding: 15px; height: 500px; overflow-y: auto; background-color: #f8f9fa; margin-bottom: 15px;",
        uiOutput("chat_display")
      ),
      div(
        style = "position: relative; margin-bottom: 10px;",
        textAreaInput("user_input", "Message:", placeholder = "Type / to see presets...", rows = 3),
        div(id = "cmd_menu", class = "cmd-menu", style = "top: 64px; left: 0; right: 0;")
      ),
      actionButton("send_btn", "Send", class = "btn-secondary", style = "width: 100%;")
    ),

    # Right column: Artifacts with tabs
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
          plotOutput("artifact_plot", height = "500px")
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
    ),
    col_widths = c(6, 6)
  )
)

server <- function(input, output, session) {
  # Reactive values
  dataset <- reactiveVal(NULL)
  messages <- reactiveValues(list = list())
  artifacts <- reactiveValues(
    logs = "",
    generated_code = "",
    result_table = NULL,
    result_plot = NULL
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
  # This will reference the currently active nodes source
  active_dataset <- reactiveVal(NULL)
  active_dataset_metadata <- reactiveVal(NULL)

  # File upload handler
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

  # List existing files in data/input folder
  files_refresh <- reactiveVal(0)
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
              data_load_msg(paste("❌ Error:", error_msg))
              return()
            }

            data <- read_any(file_path)

            if ("error" %in% names(data) && !is.null(data$error) && data$error) {
              data_load_msg(paste("❌ Error:", data$message))
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
                "✓ Loaded %s: %d rows × %d cols [%s]",
                file_name, nrow(data), ncol(data), toupper(source_type)
              ))

              summary_info <- preview_result$summary
              summary_text <- sprintf(
                "📊 Data Summary:\n• Format: %s\n• Dimensions: %d rows × %d cols\n• Numeric cols: %d | Categorical cols: %d\n• Missing rate: %.2f%%",
                summary_info$detected_format,
                summary_info$rows,
                summary_info$cols,
                summary_info$numeric_columns,
                summary_info$categorical_columns,
                summary_info$missing_rate_pct
              )

              messages$list[[length(messages$list) + 1]] <- list(
                role = "system",
                content = paste0("✓ Dataset loaded: ", file_name, "\n\n", summary_text),
                timestamp = Sys.time()
              )

              artifacts$logs <- paste(
                artifacts$logs,
                paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset auto-loaded: ", file_name),
                paste0("  Format: ", summary_info$detected_format),
                paste0("  Dimensions: ", summary_info$rows, " rows × ", summary_info$cols, " cols"),
                paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
                paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
                sep = "\n"
              )

              artifacts$result_table <- NULL
              artifacts$result_plot <- NULL

            }, error = function(e) {
              data_load_msg(paste("❌ Error:", e$message))
            })
          }, error = function(e) {
            data_load_msg(paste("❌ Error:", e$message))
          })
        })
      })
    }
  })

  # Load selected files from data/input list (auto-detect node/edge)
  observeEvent(input$input_files_list, {
    selected_files <- input$input_files_list
    if (is.null(selected_files) || length(selected_files) == 0) {
      return()
    }

    for (file_path in selected_files) {
      file_name <- basename(file_path)

      # Skip if already loaded
      already_loaded <- any(vapply(data_sources$sources, function(s) s$name == file_name, logical(1)))
      if (already_loaded) next

      tryCatch({
        preview_result <- preview_and_summarize(file_path)
        if (!preview_result$success) {
          data_load_msg(paste("❌ Error:", preview_result$error))
          next
        }

        data <- read_any(file_path)
        if ("error" %in% names(data) && !is.null(data$error) && data$error) {
          data_load_msg(paste("❌ Error:", data$message))
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
          "✓ Loaded %s: %d rows × %d cols [%s]",
          file_name, nrow(data), ncol(data), toupper(source_type)
        ))

        summary_info <- preview_result$summary
        summary_text <- sprintf(
          "📊 Data Summary:\n• Format: %s\n• Dimensions: %d rows × %d cols\n• Numeric cols: %d | Categorical cols: %d\n• Missing rate: %.2f%%",
          summary_info$detected_format,
          summary_info$rows,
          summary_info$cols,
          summary_info$numeric_columns,
          summary_info$categorical_columns,
          summary_info$missing_rate_pct
        )

        messages$list[[length(messages$list) + 1]] <- list(
          role = "system",
          content = paste0("✓ Dataset loaded: ", file_name, "\n\n", summary_text),
          timestamp = Sys.time()
        )

        artifacts$logs <- paste(
          artifacts$logs,
          paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset loaded from list: ", file_name),
          paste0("  Format: ", summary_info$detected_format),
          paste0("  Dimensions: ", summary_info$rows, " rows × ", summary_info$cols, " cols"),
          paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
          paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
          sep = "\n"
        )

      }, error = function(e) {
        data_load_msg(paste("❌ Error:", e$message))
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
        paste("Suggestions:", paste("• ", preview_result$suggestions, collapse = "\n"))
      } else {
        ""
      }

      data_load_msg(paste("❌ Error:", error_msg))
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
          "⚠️ Failed to load ", file_name, ": ", error_msg,
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
      data_load_msg(paste("❌ Error:", data$message))
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
        "✓ Loaded %s: %d rows × %d cols [%s]",
        file_name, nrow(data), ncol(data), toupper(source_type)
      ))

      # Build detailed summary message with preview info
      summary_info <- preview_result$summary
      summary_text <- sprintf(
        "📊 Data Summary:\n• Format: %s\n• Dimensions: %d rows × %d cols\n• Numeric cols: %d | Categorical cols: %d\n• Missing rate: %.2f%%",
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
          "\n• Cols with missing: ",
          paste(summary_info$columns_with_missing, collapse = ", ")
        )
      }

      # Add system message with summary
      messages$list[[length(messages$list) + 1]] <- list(
        role = "system",
        content = paste0(
          "✓ Dataset loaded: ", file_name, "\n\n", summary_text
        ),
        timestamp = Sys.time()
      )

      # Log detailed preview info to artifacts
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[", format(Sys.time(), "%H:%M:%S"), "] Dataset auto-loaded: ", file_name),
        paste0("  Format: ", summary_info$detected_format),
        paste0("  Dimensions: ", summary_info$rows, " rows × ", summary_info$cols, " cols"),
        paste0("  Numeric: ", summary_info$numeric_columns, " | Categorical: ", summary_info$categorical_columns),
        paste0("  Missing rate: ", summary_info$missing_rate_pct, "%"),
        sep = "\n"
      )

      # Add detection warnings if any
      if (length(summary_info$detection_warnings) > 0) {
        warning_msg <- paste0(
          "⚠️ Detection notes:\n• ",
          paste(summary_info$detection_warnings, collapse = "\n• ")
        )
        artifacts$logs <- paste(artifacts$logs, warning_msg, sep = "\n")
      }

      # Clear previous results when new data added
      artifacts$result_table <- NULL
      artifacts$result_plot <- NULL

    }, error = function(e) {
      data_load_msg(paste("❌ Error:", e$message))
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[ERROR] ", e$message),
        sep = "\n"
      )
    })
  })

  # Chat display
  output$chat_display <- renderUI({
    if (length(messages$list) == 0) {
      return(div(
        class = "alert alert-secondary",
        "No messages yet. Upload data and start chatting!",
        style = "margin: 0;"
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
    # Determine mode from slash command in message (e.g., /node_type_distribution)
    preset_id <- NULL
    if (!is.null(input$user_input) && nzchar(trimws(input$user_input))) {
      cmd <- trimws(input$user_input)
      cmd <- sub("^/+", "/", cmd)
      if (startsWith(cmd, "/")) {
        token <- strsplit(cmd, "\\s+")[[1]][1]
        token <- substring(token, 2)
        preset_ids <- vapply(list_presets(), function(p) p$id, character(1))
        if (token %in% preset_ids) {
          preset_id <- token
        }
      }
    }
    is_preset_mode <- !is.null(preset_id)

    if (!is_preset_mode) {
      # Free text mode
      req(input$user_input)
      req(active_dataset())

      user_msg <- input$user_input
      if (user_msg == "") return()

      # Progress indicator
      progress <- Progress$new(session, min = 0, max = 3)
      on.exit(progress$close())

      progress$set(message = "Processing query", value = 1)

      # Add user message
      messages$list[[length(messages$list) + 1]] <- list(
        role = "user",
        content = user_msg,
        timestamp = Sys.time()
      )

      progress$set(message = "Generating code", value = 2)

      # Get selected sources
      sources_list <- get_selected_sources(data_sources, selected_sources)

      # Generate schema text for LLM context - from all available sources
      schema_text <- if (length(data_sources$source_order) > 0) {
        schema_parts <- c()
        for (source_id in data_sources$source_order) {
          source <- data_sources$sources[[source_id]]
          schema_parts <- c(schema_parts, paste0(
            "[", toupper(source$type), "] ", source$name, " (", source$row_count, "x", source$col_count, ")\n",
            source$schema_text
          ))
        }
        paste(schema_parts, collapse = "\n\n")
      } else {
        generate_schema_text(active_dataset())
      }

      # Generate R code (rule-based mode)
      generated_code <- generate_code_with_mode(
        user_query = user_msg,
        schema_text = schema_text,
        use_llm = FALSE
      )

      artifacts$generated_code <- generated_code

      progress$set(message = "Executing code", value = 3)

      # Execute the code safely with selected sources
      exec_result <- execute_user_code(generated_code, sources_list = sources_list)

      # Store results
      artifacts$result_table <- exec_result$result_table
      artifacts$result_plot <- exec_result$result_plot

      # Create run record with source tracking
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

      # Store in history
      run_history$runs[[length(run_history$runs) + 1]] <- run_record

      # Generate assistant response with code reference
      assistant_response <- paste0(
        "Generated R code for your query:\n\n",
        "```r\n", generated_code, "\n```\n\n",
        "(See 'Generated R Code' and 'Logs' tabs for execution details)"
      )

      # Add assistant message
      messages$list[[length(messages$list) + 1]] <- list(
        role = "assistant",
        content = assistant_response,
        timestamp = Sys.time()
      )

      # Update logs with code and execution output
      artifacts$logs <- paste(
        artifacts$logs,
        paste0("[", format(Sys.time(), "%H:%M:%S"), "] User: ", user_msg),
        paste0("[", format(Sys.time(), "%H:%M:%S"), "] Code executed"),
        paste0("Output:\n", exec_result$output),
        sep = "\n"
      )

      # Clear input
      updateTextAreaInput(session, "user_input", value = "")

    } else {
      # Preset mode
      # Use all loaded sources for presets
      selected_ids <- data_sources$source_order
      if (length(selected_ids) == 0) {
        shinyjs::runjs("alert('Please load at least one dataset to run a preset.')")
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
        content = paste0("📋 Run preset: ", preset_label),
        timestamp = Sys.time()
      )

      progress$set(message = "Executing template", value = 3)

      # Execute template with selected datasets
      template_result <- execute_template(
        code = template_code,
        datasets = datasets_for_template,
        selected = selected_ids,
        params = list()
      )

      # Store results
      artifacts$result_table <- template_result$result_table
      artifacts$result_plot <- template_result$result_plot
      artifacts$generated_code <- template_code
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

      # Add assistant message
      assistant_response <- paste0(
        "✅ Preset executed: ", preset_label, "\n\n",
        "See tabs for results (Table, Plot, Logs, Generated R Code)"
      )
      messages$list[[length(messages$list) + 1]] <- list(
        role = "assistant",
        content = assistant_response,
        timestamp = Sys.time()
      )

      # Reset preset selector
      updateTextAreaInput(session, "user_input", value = "")
    }
  })

  # Artifact table output
  output$artifact_table <- DT::renderDataTable({
    if (is.null(artifacts$result_table)) {
      return(data.frame(Message = "No table result yet. Execute code that creates 'result_table'."))
    }
    artifacts$result_table
  }, options = list(pageLength = 10, scrollX = TRUE))

  # Artifact plot output
  output$artifact_plot <- renderPlot({
    if (is.null(artifacts$result_plot)) {
      return(ggplot() + geom_blank() + theme_void() +
             ggtitle("No plot result yet. Execute code that creates 'result_plot'."))
    }
    artifacts$result_plot
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
        span("✓ Success", class = "badge bg-secondary", style = "font-size: 10px;")
      } else {
        span("✗ Failed", class = "badge bg-dark", style = "font-size: 10px;")
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

shinyApp(ui, server)
