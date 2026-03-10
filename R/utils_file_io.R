# ============================================================================
# File I/O utilities: reading, detection, preview
# ============================================================================

# Optional: arrow for parquet support
if (!require("arrow", quietly = TRUE)) {
  arrow_available <- FALSE
} else {
  arrow_available <- TRUE
}

# ============================================================================
# Multi-format file reader function
# ============================================================================
read_any <- function(file_path, sheet = NULL) {
  tryCatch({
    # Get file extension
    ext <- tolower(tools::file_ext(file_path))

    # Read based on format
    if (ext %in% c("csv")) {
      readr::read_csv(file_path, show_col_types = FALSE)
    } else if (ext %in% c("tsv", "txt")) {
      readr::read_tsv(file_path, show_col_types = FALSE)
    } else if (ext %in% c("xlsx", "xls")) {
      if (is.null(sheet)) {
        as.data.frame(readxl::read_excel(file_path))
      } else {
        as.data.frame(readxl::read_excel(file_path, sheet = sheet))
      }
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
      count_matches <- function(pattern, text) {
        matches <- gregexpr(pattern, text, fixed = TRUE)[[1]]
        if (length(matches) == 1 && isTRUE(matches[1] == -1L)) 0 else length(matches)
      }

      comma_count <- count_matches(",", first_line)
      semicolon_count <- count_matches(";", first_line)
      tab_count <- count_matches("\t", first_line)
      pipe_count <- count_matches("\\|", first_line)

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
preview_and_summarize <- function(file_path, max_rows = 100, sheet = NULL) {
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
    data <- read_any(file_path, sheet = sheet)

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
      sheet_name = sheet,
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
# Expand a file into one or more logical dataset entries
# ============================================================================
build_file_entries <- function(file_path, max_rows = 100) {
  ext <- tolower(tools::file_ext(file_path))
  base_name <- basename(file_path)

  if (!(ext %in% c("xlsx", "xls"))) {
    preview_result <- preview_and_summarize(file_path, max_rows = max_rows)
    data <- read_any(file_path)

    return(list(list(
      display_name = base_name,
      source_file_name = base_name,
      source_file_path = file_path,
      sheet_name = NULL,
      preview_result = preview_result,
      data = data
    )))
  }

  sheets <- tryCatch(readxl::excel_sheets(file_path), error = function(e) character(0))
  if (length(sheets) == 0) {
    return(list(list(
      display_name = base_name,
      source_file_name = base_name,
      source_file_path = file_path,
      sheet_name = NULL,
      preview_result = list(success = FALSE, error = "No readable sheets found in workbook."),
      data = list(error = TRUE, message = "No readable sheets found in workbook.")
    )))
  }

  lapply(sheets, function(sheet_name) {
    preview_result <- preview_and_summarize(file_path, max_rows = max_rows, sheet = sheet_name)
    data <- read_any(file_path, sheet = sheet_name)

    list(
      display_name = paste0(base_name, "::", sheet_name),
      source_file_name = base_name,
      source_file_path = file_path,
      sheet_name = sheet_name,
      preview_result = preview_result,
      data = data
    )
  })
}
