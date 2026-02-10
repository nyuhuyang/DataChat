io_read_any <- function(file_path) {
  ext <- tolower(tools::file_ext(file_path))

  if (ext == "csv") {
    readr::read_csv(file_path, show_col_types = FALSE)
  } else if (ext %in% c("tsv", "txt")) {
    readr::read_tsv(file_path, show_col_types = FALSE)
  } else if (ext %in% c("xlsx", "xls")) {
    as.data.frame(readxl::read_excel(file_path))
  } else if (ext %in% c("parquet", "parq")) {
    as.data.frame(arrow::read_parquet(file_path))
  } else if (ext == "rds") {
    readRDS(file_path)
  } else {
    stop(paste("Unsupported file format:", ext))
  }
}
