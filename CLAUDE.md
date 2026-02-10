# DataChat: Conversational Data Analysis Interface

**Purpose:** Interactive R Shiny app for exploratory data analysis via chat interface. Combines NotebookLM-style conversation with R code generation (rule-based or LLM-powered), multi-source data management, and preset analysis templates.

---

## Quickstart

### Run the app

```r
shiny::runApp("app.R")  # From project directory
# Or in RStudio: Open app.R and click "Run App"
```

### Install dependencies

```r
# Core packages (required)
install.packages(c(
  "shiny", "bslib", "DT", "ggplot2", "dplyr", "httr2",
  "readr", "readxl", "shinyjs", "networkD3"
))

# Optional: For LLM mode, set API key in app UI
# Optional: arrow for Parquet support (graceful fallback if missing)
```

### Test with sample data

Click "Load Sample Data (mtcars)" button in sidebar to test without file upload.

---

## Architecture Invariants

- **Single-file primary structure:** App logic lives in `app.R` (avoid splitting unless unavoidable)
- **Helper isolation:** `R/presets.R` provides preset/template system only; no business logic
- **Template scripts:** `R/templates/*.R` are pure analysis code, loaded dynamically at runtime
- **Safe execution:** User code runs in isolated environment (`new.env(parent = emptyenv())`)
- **Multi-source design:** App binds data as `df_nodes`, `df_edges`, `df_metadata` (all sources available)
- **Backward compatibility:** Single source still binds as `df` for legacy code
- **Stateless templates:** Template scripts must be self-contained; they cannot rely on persistent state

---

## Guardrails (Do NOT)

- ❌ Do NOT split `app.R` into modules/subfiles unless you have explicit permission
- ❌ Do NOT refactor the preset/template system—treat `R/presets.R` as a stable interface
- ❌ Do NOT add new required dependencies without justification (app must run with base + listed packages)
- ❌ Do NOT create new helper files in `R/` without describing them in CLAUDE.md
- ❌ Do NOT modify template script paths or loading mechanism without updating MEMORY.md
- ❌ Do NOT commit changes that alter the safe execution environment constraints
- ❌ Do NOT design features "for future scalability"—build only what is needed now

---

## Conventions

### Naming & Code Style

- **Functions:** snake_case
- **Reactive IDs:** camelCase (e.g., `input$presetSelect`, `output$resultTable`)
- **Variables:** Descriptive names; avoid abbreviations except `df` for datasets
- **Comments:** Add section headers for major functions; explain why, not what

### Data Flow

1. User uploads file → `read_any()` reads format automatically → metadata stored
2. User sends query → `generate_code_with_mode()` routes to rule-based or LLM → code executes
3. Code executes in isolated env → artifacts captured → stored in run history
4. User clicks preset → template loads from `R/templates/` → executes with selected sources

### Key Functions to Know

- **`generate_code_with_mode()`** - Routes between rule-based and LLM code generation
- **`execute_user_code()`** - Sandboxed execution with package control
- **`add_data_source()`** - Registers new dataset in multi-source pool
- **`get_selected_sources()`** - Retrieves active datasets for analysis
- **`load_preset_template()`** - Loads and executes template scripts

### Testing Both Modes

Every feature must work in:

1. **Rule-based mode** (default, offline, keyword-driven)
2. **LLM mode** (when API configured, natural language understanding)

Test with sample data first, then real data.

---

## Definition of Done

A feature/fix is complete when:

- [ ] Code change is minimal and focused (no refactoring of unrelated code)
- [ ] App launches without errors (`shiny::runApp("app.R")`)
- [ ] Feature works in both rule-based and LLM modes
- [ ] No new required dependencies added
- [ ] Manual testing checklist passes (see below)
- [ ] No breaking changes to existing artifact/history loading
- [ ] Error messages are user-friendly (shown in Logs tab)

### Manual Testing Checklist

- [ ] Upload CSV/RDS/XLSX file successfully
- [ ] Schema displays correctly with column names and types
- [ ] Send "summary" query → rule-based mode generates correct code
- [ ] Send natural language query (if LLM configured) → LLM mode works
- [ ] Code executes without errors; results appear in tabs
- [ ] Run history shows all past runs with correct metadata
- [ ] Click preset button → template loads and executes
- [ ] Multi-source: Upload 2+ files → both bind correctly as `df_nodes`/`df_edges`/`df_metadata`

---

## Key Patterns in Code

### Safe Code Execution

```r
# Isolated environment, only df/df_nodes/df_edges/df_metadata available
exec_env <- new.env(parent = emptyenv())
assign("df_nodes", nodes_data, envir = exec_env)
assign("df_edges", edges_data, envir = exec_env)
eval(parse(text = user_code), envir = exec_env)
result_table <- get("result_table", envir = exec_env, ifnotfound = NULL)
```

### Multi-Source Binding

```r
# In message handler: get selected sources and bind all
sources_list <- get_selected_sources(data_sources(), selected_sources)
# Pass sources_list to execute_user_code()
# Function auto-binds df_nodes, df_edges, df_metadata in exec_env
```

### Adding a Rule-Based Pattern

```r
# In generate_r_code():
} else if (grepl("pattern_keyword", query_lower)) {
  return("code_that_sets_result_table_or_result_plot")
}
```

### Adding a Preset Template

1. Create `R/templates/my_analysis.R` (self-contained, references `df_nodes`/`df_edges`/`df_metadata`)
2. Add entry to `list_presets()` in `R/presets.R` with `id`, `label`, `file`, `description`
3. Test by clicking preset button in app

---

## File Organization

```
DataChat/
├── app.R                          # Main Shiny app (~1650 lines)
├── CLAUDE.md                      # This file
├── R/
│   ├── presets.R                  # Preset metadata + loading functions
│   └── templates/
│       ├── node_type_distribution.R
│       ├── edge_type_count.R
│       ├── node_edge_join_summary.R
│       └── schema_check.R
├── QUICKSTART.md                  # Quick reference (user-facing)
├── PRESETS.md                     # Preset system documentation
├── PRESET_TEMPLATE_GUIDE.md       # Developer guide for templates
├── MEMORY.md                      # Project memory across sessions
└── ...other docs...
```

---

## Common Workflows

### Debugging Code Execution

1. Check Logs tab in app for error messages
2. Verify dataset has expected columns (see Schema in Sources section)
3. Try "summary" query to test basic execution
4. Look at generated code to understand what was attempted

### Adding a New Code Generation Pattern

1. Identify keyword(s) to trigger the pattern
2. Write R code that sets `result_table` or `result_plot`
3. Add `else if (grepl("keyword", ...))` clause to `generate_r_code()`
4. Test with rule-based mode first, then verify LLM mode doesn't break it

### Supporting a New File Format

1. Add case to `read_any()` function
2. Test with sample file
3. Verify schema displays correctly

---

## FAQ / Troubleshooting

| Problem | Solution |
| --- | --- |
| App won't start | Check syntax errors in app.R; verify all packages installed |
| LLM mode falls back to rule-based | Check API key, URL, and internet connection in sidebar |
| Preset button doesn't appear | Check `R/presets.R` is sourced; verify `list_presets()` returns non-empty list |
| Multi-source data missing | Verify both files uploaded; check Sources section shows all loaded datasets |
| Template execution fails | Check template script references correct data object names (`df_nodes`, `df_edges`, etc.) |
| History lost after restart | Expected: history stored in memory only (in-app persistence only) |

---

## For Future Developers

- **When uncertain about requirements:** Ask before implementing
- **When adding features:** Keep scope minimal; don't invent future needs
- **When refactoring:** Get explicit permission first (this is a prototype)
- **When extending:** Update MEMORY.md with new patterns or architectural changes
- **When debugging:** Read error messages carefully; they're user-visible

---

**Last Updated:** February 2026
**Scope:** Prototype R Shiny application; prioritize functionality over perfection
