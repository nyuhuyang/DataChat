`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

datachat_project_root <- function() {
  pkg_path <- system.file(package = "DataChat")
  if (nzchar(pkg_path)) {
    return(normalizePath(pkg_path, winslash = "/", mustWork = TRUE))
  }

  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

datachat_file <- function(..., package_subdir = NULL, must_work = FALSE) {
  if (!is.null(package_subdir)) {
    pkg_path <- system.file(package_subdir, ..., package = "DataChat")
    if (nzchar(pkg_path)) {
      return(pkg_path)
    }
  }

  normalizePath(file.path(datachat_project_root(), ...), winslash = "/", mustWork = must_work)
}

datachat_app_data_dir <- function() {
  installed_pkg_path <- system.file(package = "DataChat")
  project_data_dir <- file.path(datachat_project_root(), "data")

  if (!nzchar(installed_pkg_path) && dir.exists(project_data_dir)) {
    return(normalizePath(project_data_dir, winslash = "/", mustWork = TRUE))
  }

  runtime_dir <- tools::R_user_dir("DataChat", which = "data")
  dir.create(runtime_dir, recursive = TRUE, showWarnings = FALSE)
  normalizePath(runtime_dir, winslash = "/", mustWork = TRUE)
}

datachat_input_dir <- function() {
  path <- file.path(datachat_app_data_dir(), "input")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

datachat_profiles_dir <- function() {
  path <- file.path(datachat_app_data_dir(), "output", "profiles")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}
