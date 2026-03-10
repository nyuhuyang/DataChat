# DataChat: Conversational Data Analysis Interface

**Purpose:** Interactive R Shiny app for exploratory data analysis via chat interface. Combines conversational UI with R code generation (rule-based or LLM-powered), multi-source data management, dataset profiling, and preset analysis templates.

---

## Quickstart

### Install dependencies

```r
install.packages(c(
  "shiny", "bslib", "DT", "ggplot2", "dplyr", "httr2",
  "readr", "readxl", "shinyjs", "networkD3"
))
# Optional: arrow for Parquet support (graceful fallback if missing)
```

### Configure LLM providers (optional)

Copy `.env.example` to `.env` and fill in your values:

```bash
# API key (required for LLM mode)
DATACHAT_API_KEY=your-api-key-here

# Define providers as: DATACHAT_LLM_<label>=<base_url>|<model>
DATACHAT_LLM_Claude=https://api.anthropic.com/v1|claude-sonnet-4-20250514
DATACHAT_LLM_OpenAI_GPT4o=https://api.openai.com/v1|gpt-4o
```

The `<label>` becomes the dropdown option in the UI. Both Anthropic and OpenAI-compatible APIs are auto-detected by base URL.

### Run the app

```r
shiny::runApp("app.R")  # From project directory
# Or in RStudio: Open app.R and click "Run App"
```

### Test with sample data

Place files in `data/input/` or use the file upload widget in the sidebar.

---

## Architecture Invariants

- **Modular structure:** `app.R` is a thin orchestrator (~38 lines) that sources all modules
- **UI modules:** `ui/` folder contains UI component functions
- **Server modules:** `server/` folder contains server logic functions
- **Helper utilities:** `R/` folder contains pure utility functions
- **Preset system:** `R/presets.R` provides preset/template system only; no business logic
- **Template scripts:** `R/templates/*.R` are pure analysis code, loaded dynamically at runtime
- **Safe execution:** User code runs in isolated environment (`new.env(parent = .BaseNamespaceEnv)`)
- **Multi-source design:** App binds data as `df_nodes`, `df_edges`, `df_metadata` (all sources available)
- **Backward compatibility:** Single source still binds as `df` for legacy code
- **Stateless templates:** Template scripts must be self-contained; they cannot rely on persistent state
- **Source order matters:** `R/utils_env.R` first, then `R/presets.R` and `R/utils_schema.R` before files that depend on them
- **Environment config:** API keys and providers loaded from `.env` via `load_dotenv()` at startup—never stored in UI or committed to git

---

## LLM Integration

### Provider Configuration

Providers are defined in `.env` as `DATACHAT_LLM_<label>=<base_url>|<model>`. At startup, `load_dotenv()` reads these into `Sys.getenv()`. The UI parses them into a dropdown with `base_url::model` values.

### Two LLM Modes

1. **LLM Chat (no data selected):** Pure conversation via `llm_chat()`. Maintains multi-turn history. Dataset context injected as system prompt. Selection changes trigger context refresh.

2. **LLM Data Analysis (data selected):** Three-step pipeline:
   - `llm_generate_r_code()` → generates executable R code from query + dataset profile context
   - `execute_user_code()` → runs code in sandboxed environment
   - `llm_finalize_analysis_answer()` → LLM summarizes execution results in plain English

### API Support

- **Anthropic:** `POST /messages` with `x-api-key` header, `anthropic-version: 2023-06-01`
- **OpenAI-compatible:** `POST /chat/completions` with `Authorization: Bearer` header
- Auto-detected by checking if `base_url` contains "anthropic"

### Key Functions (`R/utils_code_gen.R`)

- `llm_chat()` — multi-turn conversation, both Anthropic and OpenAI
- `llm_generate_r_code()` — single-shot code generation with schema context
- `llm_finalize_analysis_answer()` — post-execution result summarization
- `build_execution_summary_text()` — formats exec results for the finalizer
- `generate_r_code()` — rule-based code generation (keyword matching)
- `generate_code_with_mode()` — router between rule-based and LLM

---

## Dataset Profiling (`R/utils_profiles.R`)

When data is loaded, a rich profile is generated per dataset:

- Column-level stats: type, missing %, unique count, min/median/max (numeric), top values (categorical)
- Likely ID and join columns detected by naming patterns
- Profiles cached to `data/output/profiles/` as `.md` + `.rds` with file-signature-based invalidation
- `build_selected_profile_context()` assembles profile text for selected datasets → sent as LLM context

---

## Guardrails (Do NOT)

- Do NOT refactor the preset/template system—treat `R/presets.R` as a stable interface
- Do NOT add new required dependencies without justification
- Do NOT create new helper files in `R/` without describing them in CLAUDE.md
- Do NOT modify template script paths or loading mechanism without updating MEMORY.md
- Do NOT commit changes that alter the safe execution environment constraints
- Do NOT design features "for future scalability"—build only what is needed now
- Do NOT store API keys in UI or commit `.env` to git

---

## Conventions

### Naming & Code Style

- **Functions:** snake_case
- **Reactive IDs:** camelCase (e.g., `input$presetSelect`, `output$resultTable`)
- **Variables:** Descriptive names; avoid abbreviations except `df` for datasets
- **Comments:** Add section headers for major functions; explain why, not what

### Data Flow

1. User uploads file → `read_any()` reads format → `build_file_entries()` expands sheets → profile generated and cached
2. User sends query → if LLM on + data selected: `llm_generate_r_code()` → execute → `llm_finalize_analysis_answer()`
3. User sends query → if LLM on + no data: `llm_chat()` for conversation
4. User sends query → if LLM off: `generate_r_code()` (rule-based) → execute
5. User types `/preset_id` → template loads from `R/templates/` → executes with selected sources
6. Code executes in isolated env → artifacts captured → stored in run history

### Key Functions to Know

- **`llm_chat()`** — Multi-turn LLM conversation with dataset context
- **`llm_generate_r_code()`** — LLM code generation with schema/profile context
- **`llm_finalize_analysis_answer()`** — Summarize execution results via LLM
- **`generate_r_code()`** — Rule-based code generation (keyword matching)
- **`execute_user_code()`** — Sandboxed execution with package control
- **`add_data_source()`** — Registers new dataset in multi-source pool
- **`build_selected_profile_context()`** — Assembles profile text for LLM context
- **`load_dotenv()`** — Reads `.env` into `Sys.getenv()` at startup

### Testing Both Modes

Every feature must work in:

1. **Rule-based mode** (default, offline, keyword-driven)
2. **LLM mode** (when API configured, natural language understanding)

Test with sample data first, then real data.

---

## Preset / Template System

### Slash Commands

Users type `/preset_id` in the chat input (e.g., `/force_network caffeine`). The command menu auto-completes on `/`.

### Available Presets

| ID | Description |
|----|-------------|
| `head` | Combined headers across all datasets (inline, no template file) |
| `node_type_distribution` | Count nodes by type with bar chart |
| `edge_type_count` | Count edges by type with bar chart |
| `node_edge_join_summary` | Analyze node type pairs across edges |
| `schema_check` | Inspect schemas and data quality |
| `force_network` | Force-directed network graph |
| `graph_explore` | Filterable graph exploration |

### Graph Command Parameters

```
/force_network caffeine                    # bare arg = node_symbol
/force_network "bone marrow"               # quoted names with spaces
/force_network node_type=Compound max_edges=300
/graph_explore node_type=Anatomy max_nodes=100
```

Parameters: `node_type`, `edge_type`, `node_symbol`, `max_nodes` (default 200), `max_edges` (default 500).

### Adding a Preset Template

1. Create `R/templates/my_analysis.R` — self-contained, uses `datasets`, `selected`, `params`, sets `result_table`, `result_plot`, `logs`
2. Add entry to `list_presets()` in `R/presets.R` with `id`, `label`, `file`, `description`
3. Test by typing `/my_analysis` in the chat

### Template Interface Contract

**Inputs** (available in execution environment):
```r
datasets   # Named list of data.frames (names = source_id)
selected   # Character vector of selected source_ids
params     # List of parsed parameters from slash command
```

**Outputs** (must be set):
```r
result_table   # data.frame or NULL
result_plot    # ggplot/htmlwidget or NULL
logs           # Character vector of log messages
```

---

## File Organization

```
DataChat/
├── app.R                          # Thin orchestrator (~38 lines)
├── CLAUDE.md                      # This file
├── .env                           # API keys + provider config (gitignored)
├── ui/
│   ├── ui_main.R                  # Top-level UI assembly (build_ui)
│   ├── ui_sidebar.R               # Sidebar: file upload, file list, LLM toggle
│   ├── ui_chat.R                  # Chat panel: display area, input, send button
│   ├── ui_artifacts.R             # Right panel: tabs (Table, Plot, Code, Logs, History)
│   └── ui_styles.R                # CSS + JavaScript (command menu, auto-scroll)
├── server/
│   ├── server_main.R              # Server entry point (build_server) + reactive values
│   ├── server_data_loading.R      # File upload, file list, checkbox handlers, profiling
│   ├── server_chat.R              # Chat display + send message handler (LLM/rule-based/preset routing)
│   ├── server_artifacts.R         # Table/plot/code/logs renderers
│   └── server_history.R           # Run history list + view buttons
├── R/
│   ├── utils_env.R                # load_dotenv() — reads .env into Sys.getenv()
│   ├── presets.R                  # Preset metadata + loading + safe template execution
│   ├── utils_schema.R             # generate_schema_text()
│   ├── utils_profiles.R           # Dataset profiling, caching, context building
│   ├── utils_file_io.R            # read_any, detect_file_params, preview_and_summarize, build_file_entries
│   ├── utils_code_gen.R           # generate_r_code, llm_generate_r_code, llm_chat, llm_finalize_analysis_answer
│   ├── utils_data_sources.R       # infer_source_type, generate_source_id, add_data_source, get_selected_sources
│   ├── utils_execution.R          # execute_user_code (sandboxed execution)
│   └── templates/
│       ├── node_type_distribution.R
│       ├── edge_type_count.R
│       ├── node_edge_join_summary.R
│       ├── schema_check.R
│       ├── force_network.R
│       └── graph_explore.R
├── data/
│   ├── input/                     # User-uploaded files (auto-created)
│   └── output/
│       └── profiles/              # Cached dataset profiles (.md + .rds)
└── README.md                      # Public-facing project overview
```

---

## Definition of Done

A feature/fix is complete when:

- [ ] Code change is minimal and focused
- [ ] App launches without errors (`shiny::runApp("app.R")`)
- [ ] Feature works in both rule-based and LLM modes
- [ ] No new required dependencies added
- [ ] No breaking changes to existing artifact/history loading
- [ ] Error messages are user-friendly (shown in Logs tab)

### Manual Testing Checklist

- [ ] Upload CSV/RDS/XLSX file → profile generated and cached in `data/output/profiles/`
- [ ] Schema displays correctly with column names and types
- [ ] Send "summary" query → rule-based mode generates correct code
- [ ] Enable LLM mode → select provider → send natural language query → LLM response appears
- [ ] LLM mode with data selected → code generated, executed, results summarized
- [ ] LLM mode with no data → conversational chat works
- [ ] Code executes without errors; results appear in tabs
- [ ] Run history shows all past runs with correct metadata
- [ ] Type `/force_network` → template loads and executes
- [ ] Multi-source: Upload 2+ files → both bind correctly as `df_nodes`/`df_edges`/`df_metadata`

---

## Key Patterns in Code

### Safe Code Execution

```r
exec_env <- new.env(parent = .BaseNamespaceEnv)
assign("df_nodes", nodes_data, envir = exec_env)
assign("df_edges", edges_data, envir = exec_env)
eval(parse(text = user_code), envir = exec_env)
result_table <- get("result_table", envir = exec_env, ifnotfound = NULL)
```

### LLM Provider Selection

```r
# .env defines: DATACHAT_LLM_Claude=https://api.anthropic.com/v1|claude-sonnet-4-20250514
# UI parses to: provider_val = "https://api.anthropic.com/v1::claude-sonnet-4-20250514"
provider_parts <- strsplit(provider_val, "::", fixed = TRUE)[[1]]
# provider_parts[1] = base_url, provider_parts[2] = model
```

### Adding a Rule-Based Pattern

```r
# In generate_r_code():
} else if (grepl("pattern_keyword", query_lower)) {
  return("code_that_sets_result_table_or_result_plot")
}
```

---

## Common Workflows

### Debugging Code Execution

1. Check Logs tab in app for error messages
2. Verify dataset has expected columns (see Schema in Sources section)
3. Try "summary" query to test basic execution
4. Look at generated code to understand what was attempted

### Debugging LLM Integration

1. Check `.env` has `DATACHAT_API_KEY` set correctly
2. Verify provider format: `DATACHAT_LLM_<label>=<base_url>|<model>`
3. Check Logs tab for API error messages
4. Console shows `[.env] Loaded N vars` on startup

### Supporting a New File Format

1. Add case to `read_any()` in `R/utils_file_io.R`
2. Test with sample file
3. Verify schema and profile display correctly

---

## FAQ / Troubleshooting

| Problem | Solution |
| --- | --- |
| App won't start | Check syntax errors in app.R; verify all packages installed |
| LLM mode not available | Check `.env` exists with `DATACHAT_API_KEY` and `DATACHAT_LLM_*` entries |
| LLM returns API error | Verify API key is valid; check base_url format; see Logs tab |
| Preset button doesn't appear | Check `R/presets.R` is sourced; verify `list_presets()` returns non-empty |
| Multi-source data missing | Verify both files uploaded; check Sources section shows all loaded datasets |
| Template execution fails | Check template references correct data object names (`datasets`, `selected`) |
| Profile not generated | Check `data/output/profiles/` directory exists and is writable |
| History lost after restart | Expected: history stored in memory only (in-app persistence only) |

---

## For Future Developers

- **When uncertain about requirements:** Ask before implementing
- **When adding features:** Keep scope minimal; don't invent future needs
- **When refactoring:** Get explicit permission first (this is a prototype)
- **When extending:** Update MEMORY.md with new patterns or architectural changes
- **When debugging:** Read error messages carefully; they're user-visible

---

**Last Updated:** March 2026
**Scope:** Prototype R Shiny application; prioritize functionality over perfection
