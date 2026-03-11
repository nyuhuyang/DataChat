# ============================================================================
# UI: Chat panel (left column)
# ============================================================================

ui_chat_panel <- function() {
  card(
    class = "chat-card",
    full_screen = TRUE,
    card_header("Chat"),
    div(
      class = "chat-card-body",
      div(
        id = "chat_scroll_container",
        class = "chat-scroll-container",
        uiOutput("chat_display")
      ),
      div(
        class = "chat-composer",
        div(
          style = "position: relative;",
          textAreaInput("user_input", "Message:", placeholder = "Type / to see presets...", rows = 3),
          div(id = "cmd_menu", class = "cmd-menu", style = "top: 64px; left: 0; right: 0;")
        ),
        actionButton("send_btn", "Send", class = "btn-secondary", style = "width: 100%;")
      )
    )
  )
}
