# ============================================================================
# UI: CSS styles and JavaScript for command menu
# ============================================================================

ui_head_tags <- function() {
  tags$head(
    tags$style(HTML("
      .cmd-menu {
        position: absolute;
        z-index: 1000;
        background: #ffffff;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.08);
        max-height: 200px;
        overflow-y: auto;
        display: none;
      }
      .cmd-item {
        padding: 6px 10px;
        cursor: pointer;
        font-size: 12px;
      }
      .cmd-item:hover {
        background: #f2f2f2;
      }
      .chat-card {
        height: calc(100vh - 110px);
        min-height: 700px;
      }
      .chat-card > .card-body {
        height: 100%;
      }
      .chat-card-body {
        display: flex;
        flex-direction: column;
        height: 100%;
        min-height: 0;
      }
      .chat-scroll-container {
        flex: 1 1 auto;
        min-height: 0;
        border: 1px solid #dee2e6;
        border-radius: 6px;
        padding: 15px;
        overflow-y: auto;
        background-color: #f8f9fa;
        margin-bottom: 15px;
      }
      .chat-composer {
        flex: 0 0 auto;
        margin-top: auto;
      }
      .chat-composer .form-group {
        margin-bottom: 10px;
      }
      @media (max-width: 991.98px) {
        .chat-card {
          height: auto;
          min-height: 0;
        }
        .chat-card > .card-body,
        .chat-card-body {
          height: auto;
        }
        .chat-scroll-container {
          min-height: 320px;
        }
      }
    ")),
    tags$script(HTML(paste0("
      const PRESETS = [",
      paste(vapply(list_presets(), function(p) {
        label <- gsub("'", "\\\\'", p$label)
        id <- gsub("'", "\\\\'", p$id)
        sprintf("{id:'%s', label:'%s'}", id, label)
      }, character(1)), collapse = ","),
      "];

      function buildMenu(menu) {
        menu.innerHTML = '';
        PRESETS.forEach(p => {
          const item = document.createElement('div');
          item.className = 'cmd-item';
          item.textContent = p.label + '  /' + p.id;
          item.dataset.id = p.id;
          menu.appendChild(item);
        });
      }

      function showMenu(menu, show) {
        menu.style.display = show ? 'block' : 'none';
      }

      document.addEventListener('DOMContentLoaded', () => {
        // Auto-scroll chat to bottom on new messages
        const chatBox = document.getElementById('chat_scroll_container');
        if (chatBox) {
          const obs = new MutationObserver(() => {
            chatBox.scrollTop = chatBox.scrollHeight;
          });
          obs.observe(chatBox, { childList: true, subtree: true });
        }

        const ta = document.getElementById('user_input');
        const menu = document.getElementById('cmd_menu');
        if (!ta || !menu) return;
        buildMenu(menu);

        function shouldShowMenu(value, pos) {
          const upto = value.slice(0, pos);
          const lastToken = upto.split(/\\s+/).pop();
          return lastToken === '/';
        }

        ta.addEventListener('keyup', (e) => {
          const pos = ta.selectionStart || 0;
          showMenu(menu, shouldShowMenu(ta.value, pos));
        });

        ta.addEventListener('focus', () => {
          const pos = ta.selectionStart || 0;
          showMenu(menu, shouldShowMenu(ta.value, pos));
        });

        document.addEventListener('click', (e) => {
          if (e.target === ta || menu.contains(e.target)) return;
          showMenu(menu, false);
        });

        menu.addEventListener('mousedown', (e) => {
          e.preventDefault();
          const target = e.target;
          if (!target || !target.dataset.id) return;
          const insert = '/' + target.dataset.id + ' ';
          const start = ta.selectionStart || 0;
          const end = ta.selectionEnd || 0;
          const before = ta.value.slice(0, start);
          const after = ta.value.slice(end);
          if (/(^|\\s)\\/$/.test(before)) {
            const newBefore = before.replace(/(^|\\s)\\/$/, '$1' + insert);
            ta.value = newBefore + after;
          } else {
            ta.value = before + insert + after;
          }
          ta.focus();
          const newPos = (ta.value.slice(0, ta.value.length - after.length)).length;
          ta.selectionStart = ta.selectionEnd = newPos;
          showMenu(menu, false);
        });
      });
    ")))
  )
}
