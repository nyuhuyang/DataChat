# ============================================================================
# Code generation: rule-based, LLM, and router
# ============================================================================

# Rule-based code generation function
generate_r_code <- function(user_query, schema_text) {
  query_lower <- tolower(user_query)

  if (grepl("network|graph|force", query_lower)) {
    return(
      "if (!exists('df_nodes') || !exists('df_edges')) {\n  stop('Network view requires df_nodes and df_edges. Select one nodes dataset and one edges dataset.')\n}\n\nresolve_col <- function(df, candidates) {\n  nms <- names(df)\n  lower <- tolower(nms)\n  idx <- match(candidates, lower)\n  idx <- idx[!is.na(idx)][1]\n  if (is.na(idx)) return(NA_character_)\n  nms[idx]\n}\n\nnodes <- df_nodes\nedges <- df_edges\n\nnode_id_col <- resolve_col(nodes, c('node_id', 'id'))\nnode_label_col <- resolve_col(nodes, c('node_symbol', 'name', 'label'))\nedge_from_col <- resolve_col(edges, c('node_from', 'from', 'source'))\nedge_to_col <- resolve_col(edges, c('node_to', 'to', 'target'))\nnode_type_col <- resolve_col(nodes, c('node_type', 'type', 'category', 'group'))\n\nif (is.na(node_id_col) || is.na(node_label_col) || is.na(edge_from_col) || is.na(edge_to_col)) {\n  stop(paste(\n    'Missing required columns.\\n',\n    'Nodes need one of: node_id/id and node_symbol/name/label.\\n',\n    'Edges need one of: node_from/from/source and node_to/to/target.\\n',\n    'Nodes columns:', paste(names(nodes), collapse = ', '), '\\n',\n    'Edges columns:', paste(names(edges), collapse = ', ')\n  ))\n}\n\nnodes$node_key <- as.character(nodes[[node_id_col]])\nnodes$label <- as.character(nodes[[node_label_col]])\n\nedges$from <- as.character(edges[[edge_from_col]])\nedges$to <- as.character(edges[[edge_to_col]])\n\nfrom_idx <- match(edges$from, nodes$node_key)\nto_idx <- match(edges$to, nodes$node_key)\nkeep <- !is.na(from_idx) & !is.na(to_idx)\n\nif (sum(!keep) > 0) {\n  print(paste('Dropped edges with missing nodes:', sum(!keep)))\n}\n\nif (sum(keep) == 0) {\n  stop('No edges matched nodes after ID alignment.')\n}\n\nlinks <- data.frame(\n  source = from_idx[keep] - 1,\n  target = to_idx[keep] - 1,\n  value = 1\n)\n\nnodes_plot <- data.frame(\n  label = nodes$label,\n  group = if (!is.na(node_type_col)) as.character(nodes[[node_type_col]]) else 'node'\n)\n\nresult_plot <- networkD3::forceNetwork(\n  Links = links,\n  Nodes = nodes_plot,\n  Source = 'source',\n  Target = 'target',\n  Value = 'value',\n  NodeID = 'label',\n  Group = 'group',\n  opacity = 0.9,\n  zoom = TRUE,\n  fontSize = 12\n)\n"
    )
  } else if (grepl("summary", query_lower)) {
    return("print(summary(df))\nresult_table <- data.frame(\n  Variable = names(df),\n  Type = sapply(df, class),\n  NonNA_Count = colSums(!is.na(df))\n)")
  } else if (grepl("hist|distribution", query_lower)) {
    return("numeric_cols <- names(df)[sapply(df, is.numeric)]\nif (length(numeric_cols) > 0) {\n  result_plot <- ggplot(df, aes_string(x = numeric_cols[1])) + \n    geom_histogram(bins = 30, fill = '#6c757d', alpha = 0.7, color = 'white') + \n    theme_minimal() + \n    ggtitle(paste('Distribution of', numeric_cols[1]))\n} else {\n  print('No numeric columns to plot')\n}")
  } else if (grepl("count by", query_lower)) {
    return("result_table <- df %>%\n  group_by(across(everything())) %>%\n  summarise(count = n(), .groups = 'drop') %>%\n  arrange(desc(count)) %>%\n  head(20)")
  } else {
    return("result_table <- head(df, 10)\nprint('Showing first 10 rows')")
  }
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
