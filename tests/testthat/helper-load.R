project_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE)
setwd(project_root)

r_files <- sort(list.files(file.path(project_root, "R"), pattern = "\\.R$", full.names = TRUE))
invisible(lapply(r_files, source))
