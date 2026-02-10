# Preset Prompts System - Implementation Summary

## Overview

A deterministic, no-LLM preset prompts system has been added to DataLabChat. Users can now select datasets, choose a preset analysis template, and execute local R scripts without any external API calls.

## Files Created/Modified

### New Files

1. **`R/presets.R`** (Helper functions)
   - `list_presets()` - Returns all available preset metadata
   - `get_template_path()` - Resolves template file paths
   - `load_template()` - Loads template code as string
   - `execute_template()` - Safe execution with isolated environment

2. **`scripts/templates/node_type_distribution.R`**
   - Analyzes node datasets by `node_type` column
   - Outputs: count table (descending), bar plot (top 20), logs

3. **`scripts/templates/edge_type_count.R`**
   - Analyzes edge datasets by `edge_type` column
   - Outputs: count table, bar plot (top 20), logs

4. **`scripts/templates/node_edge_join_summary.R`**
   - Joins node and edge datasets on ID columns
   - Falls back to `node_type_pair` column if available
   - Outputs: type pair counts, bar plot, join details in logs

5. **`scripts/templates/schema_check.R`**
   - Inspects all selected datasets
   - Shows columns, types, missing rates
   - Outputs: unified schema table, missing-rate plot, warnings for data quality issues

### Modified Files

**`app.R`**
- Added `source("R/presets.R")` at top
- Added preset selector dropdown in UI (free text vs 4 presets)
- Conditional message input (hidden in preset mode)
- Extended send button handler to support preset mode:
  - Detects preset vs free text
  - Loads template for preset mode
  - Builds `datasets` list from selected sources
  - Executes template in safe environment
  - Stores results in history

## Architecture

### Template Interface Contract

Each template script receives in its execution environment:

```r
datasets          # Named list of data.frames (names = source_id)
selected          # Character vector of selected source_ids to use
params            # Optional list (e.g., params$top_n)
```

Each template must set these outputs:

```r
result_table      # data.frame or NULL
result_plot       # ggplot object or NULL
logs              # Character vector or string with analysis details
```

### Safe Execution

`execute_template()` creates an isolated environment with:
- Only `datasets`, `selected`, `params` available as inputs
- Explicit package imports (dplyr, ggplot2, tibble)
- No access to file system, network, or system calls
- Captured output and error handling

If template fails:
- Error is caught and logged
- `result_table` and `result_plot` remain NULL
- User sees descriptive error message in Logs tab
- App does not crash

## Presets (MVP)

### 1. Node: node_type distribution
- **Requirements:** Dataset with `node_type` column
- **Output:** Count table, bar plot (top 20 types), summary logs
- **Graceful Failure:** Clear message if no node_type column found

### 2. Edge: edge_type count
- **Requirements:** Dataset with `edge_type` column
- **Output:** Count table, bar plot (top 20 types), summary logs
- **Graceful Failure:** Clear message if no edge_type column found

### 3. Node–Edge: node_type_pair summary
- **Requirements:** At least edge dataset; optionally node dataset
- **Logic:**
  - If edges have `node_type_pair` column, use it directly
  - If both node + edge datasets present, attempts to join on ID columns
    - Node ID columns: `node_id` (preferred) or `id`
    - Edge ID columns: `source`/`from` and `target`/`to`
  - Counts pairs of node types across edges
- **Output:** Pair counts, bar plot, join details in logs
- **Graceful Failure:** Clear message with next steps

### 4. Schema check
- **Requirements:** At least one dataset selected
- **Analysis:**
  - Extracts column names, types, missing rates for all selected datasets
  - Checks for essential columns (id, type, from/to)
  - Detects and warns about missing data columns
- **Output:**
  - Unified schema table (dataset, column, type, n_missing, pct_missing)
  - Optional bar plot of missing rates (top 20 columns)
  - Warnings in logs about data quality issues
- **Graceful Failure:** Shows all available schema info or explains why

## User Experience

### Before (Free Text Mode)
1. Upload data
2. Type query (e.g., "summary")
3. Send → rule-based code generation → execute

### After (Preset Mode)
1. Upload data
2. Select datasets (checkboxes - already existed)
3. Select preset from dropdown
4. Click Send → load template → execute → see results
   - No API calls
   - Deterministic behavior
   - Instant execution

### UI Behavior

- **Preset Selector:** Dropdown at top of message panel (initially "Free Text")
- **Message Input:** Conditionally hidden when preset is selected
- **Backward Compatibility:** Free text mode unchanged (preset = "")
- **Results:** Same tabs (Table, Plot, Code, Logs, History)
- **History:** Tracks preset runs with "Preset" badge (instead of "LLM"/"Rule-based")

## Safety Guardrails

1. **Execution Environment Isolation**
   - New clean environment per execution
   - No parent environment access
   - Explicit imports only

2. **No File System Access**
   - Templates cannot call `file.remove()`, `unlink()`, `setwd()`, etc.
   - These functions not exposed in execution environment

3. **No Network Calls**
   - No `httr`, `curl`, `system()` available
   - Deterministic, offline execution

4. **Input Validation**
   - Preset ID checked against whitelist
   - Template file existence verified before loading
   - Selected datasets validated
   - Datasets parameter is controlled (from app state)

5. **Error Handling**
   - Template errors caught and logged
   - User sees friendly error message
   - Execution failure stored in history with status badge

## Testing Checklist

### Setup
- [ ] Run `shiny::runApp("app.R")`
- [ ] App launches without errors

### Data Preparation
- [ ] Create test files or use provided samples:
  ```r
  # nodes.csv
  write.csv(data.frame(
    node_id = 1:10,
    name = paste0("Node", 1:10),
    node_type = c("A", "A", "B", "B", "C", "C", "A", "A", "B", "C")
  ), "nodes.csv", row.names = FALSE)

  # edges.csv
  write.csv(data.frame(
    source = sample(1:10, 15, replace = TRUE),
    target = sample(1:10, 15, replace = TRUE),
    edge_type = sample(c("X", "Y", "Z"), 15, replace = TRUE)
  ), "edges.csv", row.names = FALSE)
  ```

### Test 1: Node Type Distribution
- [ ] Upload `nodes.csv`
- [ ] Select "Node: node_type distribution" from preset dropdown
- [ ] Click Send
- [ ] Verify Table tab shows counts by node_type (descending order)
- [ ] Verify Plot tab shows bar chart (max 20 bars)
- [ ] Verify Logs tab shows dataset info and column details
- [ ] Verify "Generated R Code" tab displays template script
- [ ] Verify History shows "Preset" badge and success status

### Test 2: Edge Type Count
- [ ] Upload `edges.csv`
- [ ] Select "Edge: edge_type count" preset
- [ ] Click Send
- [ ] Verify Table tab shows counts by edge_type
- [ ] Verify Plot tab shows bar chart
- [ ] Verify Logs include row/column counts
- [ ] Verify History entry exists

### Test 3: Node–Edge Join Summary
- [ ] Upload both `nodes.csv` and `edges.csv`
- [ ] Select both datasets (checkboxes)
- [ ] Select "Node–Edge: node_type_pair summary" preset
- [ ] Click Send
- [ ] Verify Table shows node type pairs (source_type → target_type)
- [ ] Verify Plot shows distribution of pairs
- [ ] Verify Logs explain join process
- [ ] Verify counts are non-zero (if edges exist)

### Test 4: Schema Check
- [ ] Upload both `nodes.csv` and `edges.csv`
- [ ] Select both datasets
- [ ] Select "Schema check" preset
- [ ] Click Send
- [ ] Verify Table shows all columns with types and missing rates
- [ ] Verify Plot shows missing data rate (if any columns have missing data)
- [ ] Verify Logs list all datasets and warn about missing essential columns
- [ ] Check warnings are accurate (e.g., if edges lack id columns)

### Test 5: Missing Columns Graceful Degradation
- [ ] Create a CSV without expected columns:
  ```r
  write.csv(data.frame(x = 1:5, y = 5:1), "test.csv", row.names = FALSE)
  ```
- [ ] Upload file
- [ ] Try "Node: node_type distribution" preset (no node_type column)
- [ ] Verify friendly error message in Logs: "No dataset with 'node_type' column found"
- [ ] Verify app does not crash
- [ ] Verify History shows "Failed" status badge

### Test 6: Multiple Datasets of Same Type
- [ ] Create two node CSVs with different columns
- [ ] Upload both
- [ ] Select first node CSV only
- [ ] Run "Node: node_type distribution"
- [ ] Verify template uses the selected dataset (not the other)

### Test 7: Free Text Mode Still Works
- [ ] Select "Free Text" from preset dropdown
- [ ] Type query: "summary"
- [ ] Click Send
- [ ] Verify rule-based mode executes (existing behavior)
- [ ] Verify message input is visible again
- [ ] Verify History shows "Rule-based" badge

### Test 8: History Navigation
- [ ] Run 2-3 presets
- [ ] Click on "History" tab
- [ ] Verify all runs display with timestamps, badges, and action buttons
- [ ] Click table icon on a past preset run
- [ ] Verify Table tab switches and displays that run's results
- [ ] Click "Code" button on a preset run
- [ ] Verify Code tab shows template script

### Test 9: Large Datasets
- [ ] Create node.csv with 10,000+ rows
- [ ] Run "Node: node_type distribution" preset
- [ ] Verify execution completes in reasonable time (< 5 seconds)
- [ ] Verify plot shows only top 20 (not all)
- [ ] Verify no UI freeze

### Test 10: Edge Cases
- [ ] Empty dataset upload → schema check should work
  ```r
  write.csv(data.frame(x = numeric(0)), "empty.csv", row.names = FALSE)
  ```
- [ ] Dataset with all missing values in a column → schema check warns
- [ ] Very long column names → verify plot labels render without overflow

## Code Quality Notes

- **No LLM Calls:** All presets are deterministic template scripts
- **No New Dependencies:** Uses existing packages (dplyr, ggplot2)
- **Minimal UI Changes:** Added 1 dropdown, 1 conditional input
- **Backward Compatible:** Free text mode untouched; history supports both modes
- **Readable Templates:** Clear variable names, comments, logical flow
- **Error Messages:** User-friendly, actionable (e.g., "Please upload a dataset with...")

## Future Enhancements (Not in MVP)

- [ ] Parameterized templates (e.g., user selects top_n before execution)
- [ ] Custom template upload (users add their own .R scripts)
- [ ] Template caching (compile templates on startup)
- [ ] Preset search/filtering
- [ ] LLM mode integration (generate code from natural language, then execute)
- [ ] Template composition (chain multiple presets)

---

**Last Updated:** 2026-02-09
**Status:** MVP Complete - Ready for Testing
