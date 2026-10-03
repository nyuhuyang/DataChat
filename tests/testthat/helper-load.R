project_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE)
setwd(project_root)

# Same packages app.R attaches (NAMESPACE imports)
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(dplyr)
  library(ggplot2)
  library(tibble)
})

r_files <- sort(list.files(file.path(project_root, "R"), pattern = "\\.R$", full.names = TRUE))
r_files <- r_files[basename(r_files) != "_disable_autoload.R"]
invisible(lapply(r_files, source))
