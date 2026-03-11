r_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(r_files, source))

run_app()
