# ============================================================================
# Utility: Load .env file into R environment variables
# ============================================================================

load_dotenv <- function() {
  env_file <- datachat_file(".env")
  if (!file.exists(env_file)) {
    cat("[.env] Not found at:", env_file, "\n")
    return(invisible(FALSE))
  }
  lines <- readLines(env_file, warn = FALSE)
  lines <- lines[nzchar(trimws(lines)) & !grepl("^#", trimws(lines))]
  for (line in lines) {
    parts <- strsplit(line, "=", fixed = TRUE)[[1]]
    if (length(parts) >= 2) {
      key <- trimws(parts[1])
      val <- trimws(paste(parts[-1], collapse = "="))
      do.call(Sys.setenv, setNames(list(val), key))
    }
  }
  cat("[.env] Loaded", length(lines), "vars\n")
  invisible(TRUE)
}
