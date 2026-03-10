# ============================================================================
# UI: Chat panel (left column)
# ============================================================================

ui_chat_panel <- function() {
  card(
    full_screen = TRUE,
    card_header("Chat"),
    div(
      id = "chat_scroll_container",
      style = "border: 1px solid #dee2e6; border-radius: 6px; padding: 15px; height: 500px; overflow-y: auto; background-color: #f8f9fa; margin-bottom: 15px;",
      uiOutput("chat_display")
    ),
    div(
      style = "position: relative; margin-bottom: 10px;",
      textAreaInput("user_input", "Message:", placeholder = "Type / to see presets...", rows = 3),
      div(id = "cmd_menu", class = "cmd-menu", style = "top: 64px; left: 0; right: 0;")
    ),
    actionButton("send_btn", "Send", class = "btn-secondary", style = "width: 100%;")
  )
}
