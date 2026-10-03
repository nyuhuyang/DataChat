# Deploy DataChat to shinyapps.io with an explicit file whitelist.
#
#   Rscript deploy.R --dry-run                          # list files + size
#   SHINYAPPS_ACCOUNT=<account> Rscript deploy.R        # deploy
#
# Optional: DATACHAT_APP_NAME (default "DataChat").

demo_data <- c(
  "SPOKE_subset_edges.csv",
  "SPOKE_subset_node.csv",
  "SPOKE_nodes.csv",
  "CHDI_task_573_paper_x_data_availability.xlsx"
)

deploy_files <- function(root = ".") {
  rel <- function(...) list.files(file.path(root, ...), pattern = "\\.R$", full.names = FALSE)
  files <- c(
    "app.R", ".env", "DESCRIPTION", "NAMESPACE",
    file.path("R", rel("R")),
    file.path("R", "templates", rel("R", "templates")),
    file.path("data", "input", demo_data)
  )
  missing <- files[!file.exists(file.path(root, files))]
  if (length(missing) > 0) stop("Missing deploy files: ", paste(missing, collapse = ", "))
  files
}

# Mirrors load_dotenv(): skip comments, split on first "=", trim, last assignment wins.
env_has_password <- function(env_file = ".env") {
  lines <- trimws(readLines(env_file, warn = FALSE))
  lines <- lines[nzchar(lines) & !startsWith(lines, "#") & grepl("=", lines, fixed = TRUE)]
  keys <- trimws(sub("=.*$", "", lines))
  vals <- trimws(sub("^[^=]*=", "", lines))
  hits <- vals[keys == "DATACHAT_APP_PASSWORD"]
  length(hits) > 0 && nzchar(hits[length(hits)])
}

if (sys.nframe() == 0) {
  files <- deploy_files()
  if ("--dry-run" %in% commandArgs(trailingOnly = TRUE)) {
    writeLines(files)
    cat(sprintf("%d files, %.1f MB\n", length(files), sum(file.size(files)) / 1024^2))
    quit(save = "no")
  }
  if (!env_has_password()) stop("Set DATACHAT_APP_PASSWORD in .env before deploying.")
  account <- Sys.getenv("SHINYAPPS_ACCOUNT")
  if (!nzchar(account)) stop("Set SHINYAPPS_ACCOUNT (see rsconnect::accounts()).")
  rsconnect::deployApp(
    appDir = ".",
    appFiles = files,
    appName = Sys.getenv("DATACHAT_APP_NAME", "DataChat"),
    account = account,
    server = "shinyapps.io"
  )
}
