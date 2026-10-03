# Source launcher (local runApp and shinyapps.io). Attach the packages the
# NAMESPACE imports, since sourcing R/ bypasses package loading.
library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(tibble)

options(datachat.app_root = normalizePath(".", winslash = "/"))

r_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
r_files <- r_files[basename(r_files) != "_disable_autoload.R"]
invisible(lapply(r_files, source))

run_app()
