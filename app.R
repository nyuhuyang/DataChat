library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(dplyr)
library(httr2)
library(readr)
library(readxl)
library(shinyjs)
library(networkD3)

# Source helpers (order matters: env first, then schema before file_io and data_sources)
source("R/utils_env.R")
load_dotenv()
source("R/presets.R")
source("R/utils_schema.R")
source("R/utils_file_io.R")
source("R/utils_code_gen.R")
source("R/utils_data_sources.R")
source("R/utils_execution.R")

# Source UI components
source("ui/ui_styles.R")
source("ui/ui_sidebar.R")
source("ui/ui_chat.R")
source("ui/ui_artifacts.R")
source("ui/ui_main.R")

# Source server components
source("server/server_data_loading.R")
source("server/server_chat.R")
source("server/server_artifacts.R")
source("server/server_history.R")
source("server/server_main.R")

# Launch
shinyApp(ui = build_ui(), server = build_server())
