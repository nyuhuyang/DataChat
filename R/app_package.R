run_app <- function() {
  load_dotenv()
  shiny::shinyApp(ui = build_ui(), server = build_server())
}
