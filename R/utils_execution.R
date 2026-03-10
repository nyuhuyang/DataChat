# ============================================================================
# Safe code execution in isolated environment
# ============================================================================

execute_user_code <- function(code, data = NULL, sources_list = NULL) {
  # Create isolated execution environment
  exec_env <- new.env(parent = .BaseNamespaceEnv)

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
    eval(quote(library(networkD3)), envir = exec_env)
    if (requireNamespace("stringr", quietly = TRUE)) {
      eval(quote(library(stringr)), envir = exec_env)
    }
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
