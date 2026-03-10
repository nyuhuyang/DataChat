# ============================================================================
# Code generation: rule-based, LLM, and router
# ============================================================================

# LLM chat with conversation history
# conversation_history: list of list(role, content) pairs
llm_chat <- function(conversation_history, base_url, api_key, model) {
  if (is.null(base_url) || base_url == "" || is.null(api_key) || api_key == "") {
    return("Error: API not configured. Set DATACHAT_API_KEY in .env and select a provider.")
  }

  is_anthropic <- grepl("anthropic", base_url, ignore.case = TRUE)

  # Convert history to API message format (only user/assistant roles)
  api_messages <- lapply(conversation_history, function(msg) {
    list(role = msg$role, content = msg$content)
  })

  tryCatch({
    if (is_anthropic) {
      endpoint <- paste0(base_url, "/messages")
      body <- list(
        model = model,
        max_tokens = 1024,
        system = "You are a helpful data analysis assistant. You help users explore and understand their data.",
        messages = api_messages
      )
      response <- httr2::request(endpoint) %>%
        httr2::req_headers(
          "content-type" = "application/json",
          "x-api-key" = api_key,
          "anthropic-version" = "2023-06-01"
        ) %>%
        httr2::req_body_json(body) %>%
        httr2::req_timeout(60) %>%
        httr2::req_error(is_error = function(resp) FALSE) %>%
        httr2::req_perform()

      status <- httr2::resp_status(response)
      result <- httr2::resp_body_json(response, simplifyVector = FALSE)
      if (status != 200) {
        return(paste("API Error:", result$error$message %||% paste("HTTP", status)))
      }
      result$content[[1]]$text

    } else {
      endpoint <- paste0(base_url, "/chat/completions")
      # OpenAI format: prepend system message
      openai_messages <- c(
        list(list(role = "system", content = "You are a helpful data analysis assistant. You help users explore and understand their data.")),
        api_messages
      )
      body <- list(
        model = model,
        messages = openai_messages,
        max_tokens = 1024
      )
      response <- httr2::request(endpoint) %>%
        httr2::req_headers(
          "Content-Type" = "application/json",
          "Authorization" = paste("Bearer", api_key)
        ) %>%
        httr2::req_body_json(body) %>%
        httr2::req_timeout(60) %>%
        httr2::req_error(is_error = function(resp) FALSE) %>%
        httr2::req_perform()

      status <- httr2::resp_status(response)
      result <- httr2::resp_body_json(response, simplifyVector = FALSE)
      if (status != 200) {
        return(paste("API Error:", result$error$message %||% paste("HTTP", status)))
      }
      result$choices[[1]]$message$content
    }
  }, error = function(e) {
    paste("Error:", e$message)
  })
}

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

# LLM-based code generation function (supports Anthropic and OpenAI-compatible APIs)
llm_generate_r_code <- function(user_query, schema_text, base_url, api_key, model = "claude-sonnet-4-20250514") {
  # Validate inputs
  if (is.null(base_url) || base_url == "" || is.null(api_key) || api_key == "") {
    stop("API Base URL and API Key are required for LLM mode")
  }

  is_anthropic <- grepl("anthropic", base_url, ignore.case = TRUE)

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

  user_message <- paste0("Generate R code for: ", user_query)

  tryCatch({
    if (is_anthropic) {
      # Anthropic Messages API
      endpoint <- paste0(base_url, "/messages")
      request_body <- list(
        model = model,
        max_tokens = 1024,
        system = system_prompt,
        messages = list(
          list(role = "user", content = user_message)
        )
      )

      response <- httr2::request(endpoint) %>%
        httr2::req_headers(
          "content-type" = "application/json",
          "x-api-key" = api_key,
          "anthropic-version" = "2023-06-01"
        ) %>%
        httr2::req_body_json(request_body) %>%
        httr2::req_timeout(60) %>%
        httr2::req_retry(max_tries = 2) %>%
        httr2::req_error(is_error = function(resp) FALSE) %>%
        httr2::req_perform()

      status <- httr2::resp_status(response)
      result <- httr2::resp_body_json(response, simplifyVector = FALSE)

      if (status != 200) {
        error_msg <- if (!is.null(result$error$message)) result$error$message else paste("HTTP", status)
        stop(paste("Anthropic API Error:", error_msg))
      }

      # Anthropic returns content as a list of blocks
      if (!is.null(result$content) && length(result$content) > 0) {
        generated_code <- result$content[[1]]$text
      } else {
        stop("No content in Anthropic response")
      }

    } else {
      # OpenAI-compatible API
      endpoint <- paste0(base_url, "/chat/completions")
      request_body <- list(
        model = model,
        messages = list(
          list(role = "system", content = system_prompt),
          list(role = "user", content = user_message)
        ),
        temperature = 0.3,
        max_tokens = 1024
      )

      response <- httr2::request(endpoint) %>%
        httr2::req_headers(
          "Content-Type" = "application/json",
          "Authorization" = paste("Bearer", api_key)
        ) %>%
        httr2::req_body_json(request_body) %>%
        httr2::req_timeout(60) %>%
        httr2::req_retry(max_tries = 2) %>%
        httr2::req_error(is_error = function(resp) FALSE) %>%
        httr2::req_perform()

      status <- httr2::resp_status(response)
      result <- httr2::resp_body_json(response, simplifyVector = FALSE)

      if (status != 200) {
        error_msg <- if (!is.null(result$error$message)) result$error$message else paste("HTTP", status)
        stop(paste("API Error:", error_msg))
      }

      if (!is.null(result$choices) && length(result$choices) > 0) {
        generated_code <- result$choices[[1]]$message$content
      } else {
        stop("No code in API response")
      }
    }

    # Clean up markdown artifacts
    generated_code <- gsub("```r\\n?", "", generated_code)
    generated_code <- gsub("```\\n?", "", generated_code)
    generated_code <- trimws(generated_code)

    return(generated_code)

  }, error = function(e) {
    error_code <- paste0(
      "# LLM Error: ", e$message, "\n",
      "print('Code generation failed: ", gsub("'", "\\\\'", e$message), "')"
    )
    return(error_code)
  })
}

# Code generation router function
generate_code_with_mode <- function(user_query, schema_text, use_llm, base_url = NULL, api_key = NULL, model = "gpt-4") {
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
    return(llm_generate_r_code(user_query, schema_text, base_url, api_key, model))
  } else {
    # Use rule-based
    return(generate_r_code(user_query, schema_text))
  }
}
