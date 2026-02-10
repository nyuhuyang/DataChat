# DataLabChat - A NotebookLM-Style Data Analysis Interface

## Project Overview

**Project Name:** DataLabChat

**Purpose:** Interactive R Shiny app for conversational data analysis with optional LLM-powered code generation. Combines the conversational interface of NotebookLM with the power of R's data analysis capabilities.

**Key Features:**
- Upload and analyze CSV/RDS datasets
- Chat-based interface for generating and executing R code
- Dual code generation modes: rule-based (default) and LLM-powered (optional)
- Safe, sandboxed code execution environment
- NotebookLM-style Sources section showing data context
- Run history with artifact tracking
- Clickable artifact browsing to revisit past analyses

---

## Architecture & File Structure

```
DataLabChat/
├── app.R              # Single-file Shiny application (~460 lines)
├── CLAUDE.md          # This documentation file
└── .claude/
    └── plans/         # Planning documents
```

### app.R Structure

The entire application is contained in a single `app.R` file with clear sections:

- **Lines 1-6:** Library imports (shiny, bslib, DT, ggplot2, dplyr, httr2)
- **Lines 8-21:** `generate_r_code()` - Rule-based code generation function
- **Lines 23-58:** `generate_schema_text()` - Format dataset schema for LLM context
- **Lines 60-147:** `llm_generate_r_code()` - LLM-powered code generation via OpenAI-compatible APIs
- **Lines 149-168:** `generate_code_with_mode()` - Router between rule-based and LLM modes
- **Lines 170-221:** `execute_user_code()` - Safe code execution in isolated environment
- **Lines 223-307:** UI definition (page_sidebar, chat panel, artifacts tabs)
- **Lines 309-464:** Server logic (reactive values, event handlers, outputs)

---

## Key Components

### Data Flow

```
User Query
    ↓
Code Generation (Rule-based OR LLM)
    ↓
Safe Execution (isolated environment)
    ↓
Artifacts Display (table, plot, code, logs)
    ↓
Run History Storage (preserves for browsing)
```

### Reactive Values

The application uses `reactiveValues()` to maintain state:

- **`dataset`** - Currently loaded data frame (tibble or data.frame)
- **`messages`** - Chat message history, list of `{role, content, timestamp}`
- **`artifacts`** - Current execution outputs: `result_table`, `result_plot`, `generated_code`, `logs`
- **`dataset_metadata`** - Source file metadata: `file_name`, `upload_time`, `row_count`, `col_count`
- **`run_history`** - Complete history of all runs with their artifacts and metadata

### UI Layout

**Sidebar (left, fixed 300px):**
- LLM Configuration section (toggle, API URL, API key inputs)
- Data Loader (file input for CSV/RDS)
- Schema Summary (column info table)
- Sources accordion (file metadata, 20-row preview, schema context)

**Main Area (two-column):**
- **Left column:** Chat panel with conversation history and message input
- **Right column:** Artifacts tabs for viewing results
  - Table tab (DT::dataTable output)
  - Plot tab (rendered ggplot)
  - Generated R Code tab (code display)
  - Logs tab (execution output and errors)
  - History tab (chronological run list with clickable artifacts)

---

## Code Generation Modes

### Rule-Based Mode (Default)

Keyword matching on user query to generate predefined R code patterns:

- **"summary"** → Creates `result_table` with variable information
  ```r
  result_table <- data.frame(
    Variable = names(df),
    Type = sapply(df, class),
    NonNA_Count = colSums(!is.na(df))
  )
  ```

- **"hist|distribution"** → Creates `result_plot` histogram
  ```r
  result_plot <- ggplot(df, aes_string(x = numeric_cols[1])) +
    geom_histogram(bins = 30, fill = '#6c5ce7', alpha = 0.7, color = 'white') +
    theme_minimal() +
    ggtitle(paste('Distribution of', numeric_cols[1]))
  ```

- **"count by"** → Creates `result_table` with grouped counts
  ```r
  result_table <- df %>%
    group_by(across(everything())) %>%
    summarise(count = n(), .groups = 'drop') %>%
    arrange(desc(count)) %>%
    head(20)
  ```

- **Default** → Shows first 10 rows with explanatory message

**Advantages:** Fast, deterministic, no API calls, works offline

### LLM Mode (Optional)

Calls OpenAI-compatible chat completion endpoint with context:

1. Sends system prompt enforcing R code conventions
2. Includes dataset schema for context awareness
3. Uses temperature 0.3 for deterministic code generation
4. Cleans markdown artifacts from response
5. Falls back to rule-based mode if credentials missing

**API Configuration:**
- Base URL: `https://api.openai.com/v1` (default) or local LLM endpoints
- Models: Tested with gpt-3.5-turbo, gpt-4, and OpenAI-compatible endpoints
- Timeout: 30 seconds per request with 2 automatic retries
- Error handling: Graceful fallback with warning message

**Advantages:** Natural language understanding, context-aware code, handles complex queries

---

## Development Guidelines

### Development Philosophy: Conversation-First, Scan-Before-Execute

When working on enhancements or modifications:

1. **Start with conversation** - Discuss what you want to change and why before touching code
2. **Scan the codebase** - Understand the current structure and patterns first
3. **Plan the approach** - Outline how changes fit with existing code
4. **Execute carefully** - Make minimal, focused changes with clear intent

This approach ensures changes are thoughtful, maintainable, and aligned with the existing architecture.

### Understanding the Codebase Structure

Before modifying anything, understand these key areas:

**Code Generation:**

- `generate_r_code()` (lines 8-21) - Rule-based patterns using keyword matching
- `llm_generate_r_code()` (lines 60-147) - LLM integration with fallback logic
- `generate_code_with_mode()` (lines 149-168) - Router between modes

**Code Execution:**

- `execute_user_code()` (lines 170-221) - Safe execution in isolated environment
- Uses `new.env(parent = emptyenv())` for safety

**UI Layout:**

- Sidebar (lines 80-115) - LLM config, data loader, sources
- Main area (lines 118-136) - Chat panel and artifacts tabs

**Server Logic:**

- Reactive values (lines 133-155) - State management
- File upload (lines 157-209) - Data loading and metadata
- Send handler (lines 251-349) - Query execution flow
- History system (lines 338-461) - Run tracking and artifact browsing

### Adding New Code Generation Patterns (Rule-Based)

**When to use:** Simple keyword-based analysis requests

**How to add:**

1. Locate `generate_r_code()` function (lines 8-21)
2. Add new `grepl()` condition for your keyword
3. Return R code that sets `result_table` or `result_plot`
4. Test with sample queries in both modes

**Example:**
```r
} else if (grepl("scatter", query_lower)) {
  return("if (length(numeric_cols) >= 2) {
    result_plot <- ggplot(df, aes(x = numeric_cols[1], y = numeric_cols[2])) +
      geom_point(alpha = 0.6) + theme_minimal()
  }")
```

**Considerations:**
- Keep patterns simple and deterministic
- Avoid complex branching logic
- Document what keywords trigger the pattern
- Test with actual data

### Adding New UI Elements

**Sidebar additions:**
- Locate sidebar definition (lines 80-115)
- Use bslib components: `card()`, `accordion()`, `input_file()`
- Follow existing spacing and organization

**New artifact tabs:**
- Add `nav_panel()` to `navset_tab()` call (lines 106-132)
- Create corresponding server output renderer
- Use consistent styling with existing tabs

**Server outputs:**
- Add `output$my_artifact <- renderText({...})` or appropriate renderer
- Use `req()` to validate dependencies
- Return HTML/Shiny compatible output
- Handle empty state gracefully

### Modifying Code Execution Environment

**Location:** `execute_user_code()` function (lines 170-221)

**Current allowed packages:** base, stats, utils, dplyr, ggplot2, tibble

**To add a new package:**
```r
eval(quote(library(tidyr, warn.conflicts = FALSE)), envir = exec_env)
```

**Important:** The execution environment is intentionally isolated:
- User code cannot access parent environment
- Only `df` (the dataset) is available by default
- Package access is explicitly controlled
- This prevents unintended side effects

### Coding Patterns to Follow

- **Input Validation:** Use `req()` in reactive expressions
- **History Tracking:** Store run records with `run_id`, `timestamp`, `user_query`, `generated_code`, `artifacts`
- **Timestamps:** Use `format(Sys.time(), "%H:%M:%S")` for consistency
- **UI Styling:** Match existing bslib components and CSS classes
- **Naming Convention:** snake_case for functions, camelCase for UI IDs

### Best Practices

1. **Conversation-first approach** - Discuss changes before implementing them
2. **Minimal changes** - Make focused edits, avoid refactoring unrelated code
3. **Single-file structure** - Keep everything in app.R unless complexity genuinely demands splitting
4. **Clear comments** - Add comment headers for new functions and major sections
5. **Test both modes** - Verify features work in both rule-based and LLM modes
6. **Backward compatibility** - Don't break existing artifact loading or history
7. **Error handling** - Wrap user inputs and external calls with `tryCatch()`
8. **Understand before modifying** - Scan the code to understand how pieces interact

---

## Setup & Installation

### Prerequisites

- **R:** Version 4.0 or higher
- **RStudio:** Recommended (not required)
- **Internet:** For LLM mode only (OpenAI API or compatible service)

### Required Packages

Install all required packages:

```r
install.packages(c(
  "shiny",      # Interactive web framework
  "bslib",      # Bootstrap styling and components
  "DT",         # DataTables for interactive tables
  "ggplot2",    # Data visualization
  "dplyr",      # Data manipulation
  "httr2",      # HTTP requests for API calls
  "bsicons"     # Icons for UI elements (optional, used in Sources)
))
```

### Optional: For LLM Mode

You'll need access to an OpenAI-compatible API:

- **OpenAI API:** Requires API key from https://platform.openai.com/api-keys
- **Azure OpenAI:** Use Azure-specific endpoint and credentials
- **Local LLM:** Set up Ollama, LMStudio, or other OpenAI-compatible service on localhost
- **Other providers:** Any service with OpenAI-compatible `/v1/chat/completions` endpoint

---

## Running the App

### Launch in RStudio

1. Open `app.R` in RStudio
2. Click "Run App" button (or press Ctrl/Cmd+Shift+Enter)
3. App opens in RStudio viewer or browser

Alternative:
```r
shiny::runApp("app.R")
```

### Launch from Terminal

```bash
# From project directory
R -e "shiny::runApp('app.R')"

# Or with specific host/port
R -e "shiny::runApp('app.R', host='127.0.0.1', port=3838)"
```

### Access

- App opens automatically at `http://127.0.0.1:XXXX` (port varies)
- In RStudio, click "Open in Browser" to open in default browser
- Access from other machines by using server's hostname/IP instead of localhost

---

## Usage Guide

### Basic Workflow

#### 1. Upload Data

1. In sidebar under "Data Loader", click "Browse..."
2. Select CSV or RDS file from your computer
3. Dataset loads and schema summary appears automatically
4. File metadata (name, time, dimensions) displays in Sources section

#### 2. Explore Sources

1. Click on Sources accordion in sidebar to expand
2. View uploaded file name with timestamp
3. Check dimensions (rows × columns)
4. Browse first 20 rows in preview table
5. Review schema context showing column types and statistics

#### 3. Send Queries

1. Click in message input box at bottom of chat panel
2. Type analysis query (e.g., "summary", "histogram", "show first 10 rows")
3. Press Enter or click "Send" button
4. Code generates automatically (rule-based or LLM mode)
5. Code executes against dataset
6. Results appear in appropriate artifact tabs

#### 4. View Artifacts

Each run produces artifacts displayed in tabs:

- **Table tab:** View `result_table` data in interactive DataTable
  - Sortable, searchable, paginated
  - Export-friendly format

- **Plot tab:** View `result_plot` ggplot2 visualizations
  - Full size rendering
  - Interactive zoom/export

- **Generated R Code tab:** See exact code executed
  - Useful for learning R patterns
  - Can copy for offline use

- **Logs tab:** Check execution output and errors
  - Shows `print()` output
  - Displays error messages if execution failed

- **History tab:** Browse all past runs
  - Chronological list (most recent first)
  - Badges showing mode (LLM/Rule-based) and status (success/failure)
  - Click table/plot icons to reload artifacts
  - Click "Code" to view that run's generated code

#### 5. Browse Run History

1. Switch to History tab in artifacts panel
2. Scroll through list of past runs (most recent first)
3. Each run shows:
   - Timestamp
   - User query
   - Mode badge (LLM or Rule-based)
   - Status badge (✓ Success or ✗ Failed)
   - Action buttons (table icon, plot icon, "Code" button)
4. Click any action button to reload that run's artifacts
5. Selected run highlights with blue border

### Using LLM Mode

#### Setup

1. Check "Use LLM for Code Generation" checkbox in sidebar
2. Enter API Base URL (e.g., `https://api.openai.com/v1`)
3. Enter API Key (masked input for security)
4. Click outside input to save

#### Usage

1. Send natural language queries (e.g., "create a scatter plot of column A vs B", "group by category and count")
2. LLM analyzes dataset schema and generates context-aware code
3. Code executes and results appear
4. History shows badge indicating "LLM" mode

#### Troubleshooting

- **Invalid API Key:** Error appears in Logs tab
- **Network Error:** Check internet connection and API endpoint
- **Timeout:** Retry query (30-second timeout with 2 automatic retries)
- **Fallback:** If credentials missing/invalid, app uses rule-based mode automatically

---

## Testing & Verification

### Manual Testing Checklist

Use this checklist to verify functionality after changes:

**Core Features:**
- [ ] App launches without errors
- [ ] Can upload CSV file successfully
- [ ] Can upload RDS file successfully
- [ ] Schema summary displays correctly with column names and types

**Sources Section:**
- [ ] Sources accordion appears in sidebar after upload
- [ ] File name and upload timestamp display
- [ ] Dimensions shown correctly (rows × columns)
- [ ] Preview table shows first 20 rows
- [ ] Schema text block shows column information

**Chat & Code Generation:**
- [ ] Chat accepts input and displays messages
- [ ] Message timestamps appear
- [ ] Rule-based mode generates correct code for "summary" query
- [ ] Rule-based mode generates correct code for "histogram" query
- [ ] Code executes without errors
- [ ] Results appear in appropriate tabs

**Artifacts & History:**
- [ ] Table tab displays result_table correctly
- [ ] Plot tab renders result_plot visualization
- [ ] Generated R Code tab shows executed code
- [ ] Logs tab shows execution output
- [ ] History tab shows all past runs
- [ ] Run cards show timestamps, query, mode badge, status badge
- [ ] Clicking table icon loads table in main view
- [ ] Clicking plot icon loads plot in main view
- [ ] Clicking "Code" button shows code in main view
- [ ] Selected run highlights with blue border

**LLM Mode (if configured):**
- [ ] LLM toggle checkbox controls mode switching
- [ ] LLM mode generates sensible code for natural language queries
- [ ] API errors handled gracefully
- [ ] Falls back to rule-based if credentials missing

**Error Handling:**
- [ ] Invalid queries handled gracefully (don't crash app)
- [ ] Failed code execution shows error in Logs tab
- [ ] History shows "Failed" badge for failed runs
- [ ] Can still browse history after failed run

### Test Data

Use R's built-in datasets for testing:

```r
# Save iris dataset as CSV
write.csv(iris, "test_iris.csv", row.names = FALSE)

# Save mtcars dataset as CSV
write.csv(mtcars, "test_mtcars.csv", row.names = FALSE)

# Save as RDS for compression
saveRDS(iris, "test_iris.rds")
saveRDS(mtcars, "test_mtcars.rds")
```

**Test queries:**
- "summary" - Tests rule-based summary generation
- "histogram" - Tests plot generation
- "count by cyl" (for mtcars) - Tests grouped counting
- "show me the data" - Tests default behavior

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "bsicons not found" | Missing package | `install.packages("bsicons")` |
| LLM gives errors | Invalid API key or URL | Check credentials in sidebar |
| Code execution fails | Dataset missing expected columns | Check column names in schema |
| History buttons don't work | JavaScript issue | Check browser console (F12) for errors |
| Sources section doesn't appear | No dataset loaded | Upload a CSV/RDS file first |
| Plots don't render | Incompatible data types | Verify numeric columns exist |

---

## Extending the App

### Adding New Artifact Types

To add a new type of output (e.g., summary statistics, model output):

1. **Add to reactive values** (line 309):
   ```r
   artifacts$my_artifact <- NULL
   ```

2. **Create UI tab** (lines 279-307):
   ```r
   nav_panel(
     "My Artifact",
     uiOutput("my_artifact_display")
   )
   ```

3. **Add server renderer** (in server function):
   ```r
   output$my_artifact_display <- renderText({
     req(artifacts$my_artifact)
     toString(artifacts$my_artifact)
   })
   ```

4. **Populate in code generation** (lines 463-492):
   ```r
   artifacts$my_artifact <- some_result_from_execution
   ```

### Adding New Data Sources

To support additional file formats (e.g., Excel, JSON):

1. **Modify file upload handler** (lines 332-350)
2. **Add new file extension support**:
   ```r
   file_ext <- tolower(tools::file_ext(input$file_input$name))
   if (file_ext == "xlsx") {
     # Use readxl::read_excel() or similar
   }
   ```
3. **Update schema generation** if format has special considerations

### Customizing LLM Prompts

To improve LLM code generation for specific use cases:

1. **Edit system prompt** (lines 71-82 in `llm_generate_r_code()`):
   ```r
   system_prompt <- paste0(
     "You are an expert R data analyst specialized in business intelligence...",
     # ... rest of prompt ...
   )
   ```

2. **Adjust temperature** (line 88):
   ```r
   "temperature" = 0.3  # Lower = more deterministic, Higher = more creative
   ```

3. **Add few-shot examples** to system prompt:
   ```r
   "Example: User: 'show me growth by month'
    Assistant: df %>% group_by(month) %>% summarise(total = sum(revenue)) %>%
               ggplot(aes(x = month, y = total)) + geom_line() + geom_point()"
   ```

---

## Technical Details

### Safe Code Execution Implementation

The `execute_user_code()` function (lines 170-221) implements sandboxed execution:

```r
exec_env <- new.env(parent = emptyenv())  # Isolated environment
assign("df", data, envir = exec_env)      # Only df accessible
eval(parse(text = code), envir = exec_env) # Execute in sandbox
```

**Security properties:**
- User code cannot access global environment variables
- User code cannot access loaded packages unless explicitly loaded
- Controlled package list prevents access to dangerous functions
- `df` is the only data object available to user code

**Extraction pattern:**
```r
result_table <- get("result_table", envir = exec_env)  # Safe extraction
result_plot <- get("result_plot", envir = exec_env)
```

### LLM API Integration

Uses `httr2` package for HTTP requests:

```r
response <- request(endpoint) %>%
  req_headers(`Content-Type` = "application/json") %>%
  req_body_json(request_body) %>%
  req_timeout(30) %>%
  req_retry(max_tries = 2) %>%
  req_perform()
```

**Error handling:**
- Timeout after 30 seconds
- Automatic 2 retries on transient failures
- Fallback to rule-based mode on permanent failure
- User-visible error messages in Logs tab

---

## Glossary

- **Artifact** - Output from code execution (table, plot, code, logs)
- **Run** - Single execution of generated code with all associated artifacts
- **Run ID** - Unique identifier for historical tracking (format: `run_YYYYMMDD_HHMMSS_SSS`)
- **Run Record** - Complete metadata for a run (query, code, artifacts, status)
- **Exec Env** - Isolated R environment for safe code execution
- **Schema** - Column names, types, and statistics for dataset context

---

## Resources

### R & Shiny Documentation
- [R Documentation](https://www.r-project.org/help.html)
- [Shiny Cookbook](https://rstudio.github.io/bslib/)
- [bslib Documentation](https://rstudio.github.io/bslib/)
- [DT (DataTables) Guide](https://rstudio.github.io/DT/)

### API Integration
- [OpenAI API Docs](https://platform.openai.com/docs/api-reference)
- [httr2 Package Documentation](https://httr2.r-lib.org/)

### R Data Analysis
- [dplyr Documentation](https://dplyr.tidyverse.org/)
- [ggplot2 Documentation](https://ggplot2.tidyverse.org/)

---

## Troubleshooting Guide

### App Won't Start

**Symptoms:** Error when running `shiny::runApp("app.R")`

**Solutions:**
1. Check for syntax errors: Open app.R and look for red error markers
2. Install missing packages: `install.packages(c("shiny", "bslib", "DT", "ggplot2", "dplyr", "httr2"))`
3. Check R version: Requires R 4.0+. Check with `R --version`
4. Look at error message in console - it will indicate specific issue

### Data Upload Fails

**Symptoms:** File browser opens but upload fails

**Solutions:**
1. Verify file exists and is readable
2. Check file format - only CSV and RDS supported
3. For CSV: Ensure proper delimiters (comma or semicolon)
4. For large files: Try uploading smaller sample first

### Code Execution Errors

**Symptoms:** Generated code fails to execute, error in Logs tab

**Solutions:**
1. Check dataset schema - verify column names in error
2. Review generated code - may reference non-existent columns
3. Try simpler query first - "summary" is good baseline
4. Check Logs tab for detailed error message

### LLM Mode Not Working

**Symptoms:** LLM queries fail, or falls back to rule-based

**Solutions:**
1. Verify API key is correct (no extra spaces)
2. Check API base URL format (should end with `/v1`)
3. Verify internet connectivity
4. Try disabling LLM and re-enabling to refresh UI
5. Check Logs tab for specific API error

### History Lost After Restart

**Expected behavior:** Run history is stored in memory only (cleared on app restart)

**To preserve history:** Future enhancement could save to file. For now, take screenshots or export artifacts before restarting.

---

## Version History

- **Current:** DataLabChat with NotebookLM features, dual code generation modes, run history

---

**Last Updated:** February 2025

**Maintained by:** Claude Code Development
