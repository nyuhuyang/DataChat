# How to Add a New Preset Template

## Quick Start

### Step 1: Create Template Script

Create a new file in `scripts/templates/my_preset.R`:

```r
# ============================================================================
# Template: My Preset Name
# ============================================================================
# Inputs: datasets (list), selected (vector of source_ids), params (list)
# Outputs: result_table, result_plot, logs

logs <- c()

# Your analysis code here...

# Build result_table (data.frame or NULL)
result_table <- data.frame(...)

# Build result_plot (ggplot or NULL)
result_plot <- ggplot(...) + ...

# Append to logs (character vector)
logs <- c(logs, "Analysis complete")
```

### Step 2: Register Preset

Edit `R/presets.R` and add to `list_presets()`:

```r
list(
  id = "my_preset",
  label = "My Preset: descriptive name",
  file = "my_preset.R",
  description = "Brief description for UI"
)
```

### Step 3: Add UI Option

Edit `app.R` line ~541 in the selectInput choices:

```r
selectInput(
  "preset_select",
  "Preset:",
  choices = c(
    "Free Text" = "",
    ...existing presets...,
    "My Preset: descriptive name" = "my_preset"  # ADD HERE
  ),
  ...
)
```

That's it! The system handles loading and execution automatically.

## Template Script API

### Input Variables (automatically available)

```r
datasets          # Named list: list(source_id = dataframe, ...)
selected          # Character vector: which source_ids to use
params            # List: parameters (e.g., params$top_n)
```

**Example: Access selected datasets**
```r
for (source_id in selected) {
  ds <- datasets[[source_id]]
  # Use ds...
}
```

### Output Variables (must be set)

```r
result_table      # data.frame, tibble, or NULL
result_plot       # ggplot object or NULL
logs              # Character vector (joined with \n) or single string
```

**Example: Set outputs**
```r
result_table <- mydata %>% group_by(x) %>% summarise(n = n())
result_plot <- ggplot(mydata, aes(x)) + geom_histogram()
logs <- c("Analysis of", nrow(mydata), "rows")
```

### Available Packages

Templates automatically have access to:
- **dplyr:** `group_by()`, `summarise()`, `mutate()`, `filter()`, `select()`, `left_join()`, etc.
- **ggplot2:** `ggplot()`, `geom_*()`, `theme_*()`, etc.
- **tibble:** `as_tibble()`, `tribble()`, etc.
- **base R:** All standard functions

### What NOT to Do

❌ Don't call:
```r
file.remove()       # File system access blocked
setwd()             # Directory access blocked
system()            # System commands blocked
library()           # Packages already loaded
```

❌ Don't return:
```r
list_of_things      # Must return data.frame, not list
invisible()         # Plotting won't work
```

❌ Don't assume:
```r
df                  # Use `datasets[[selected[1]]]` instead
results             # Use `result_table`, `result_plot`, `logs`
```

## Common Patterns

### Pattern: Single Dataset Analysis

```r
logs <- c()
target_dataset <- NULL
target_id <- NULL

for (source_id in selected) {
  ds <- datasets[[source_id]]
  if (!is.null(ds) && "my_column" %in% colnames(ds)) {
    target_dataset <- ds
    target_id <- source_id
    break
  }
}

if (is.null(target_dataset)) {
  result_table <- NULL
  result_plot <- NULL
  logs <- "Error: No dataset with 'my_column' found"
} else {
  logs <- c(logs, paste0("Dataset: ", target_id, " (", nrow(target_dataset), " rows)"))

  # Your analysis...
  result_table <- ...
  result_plot <- ...

  logs <- c(logs, "Analysis complete")
}
```

### Pattern: Join Two Datasets

```r
node_ds <- NULL
edge_ds <- NULL

for (source_id in selected) {
  ds <- datasets[[source_id]]
  if (has_node_columns(ds)) node_ds <- ds
  if (has_edge_columns(ds)) edge_ds <- ds
}

if (is.null(node_ds) || is.null(edge_ds)) {
  logs <- "Error: Need both node and edge datasets"
} else {
  joined <- node_ds %>%
    left_join(edge_ds, by = c("id" = "node_id"))

  result_table <- joined %>% group_by(...) %>% summarise(...)
  result_plot <- ...
}
```

### Pattern: Error Handling

```r
tryCatch({
  # Your code
  result_table <- dangerous_operation()
}, error = function(e) {
  logs <<- c(logs, paste("Error:", e$message))
  result_table <<- NULL
})
```

### Pattern: Parameterized Template

```r
top_n <- if (!is.null(params$top_n)) params$top_n else 20

result_table <- mydata %>%
  group_by(category) %>%
  summarise(count = n()) %>%
  slice_max(count, n = top_n)
```

## Example: Simple Counter Preset

**File: `scripts/templates/simple_counter.R`**

```r
# Template: Simple Counter
logs <- c()

if (length(selected) == 0) {
  result_table <- NULL
  result_plot <- NULL
  logs <- "No datasets selected"
} else {
  # Count rows in each dataset
  counts <- list()
  for (source_id in selected) {
    counts[[source_id]] <- nrow(datasets[[source_id]])
  }

  result_table <- data.frame(
    dataset = names(counts),
    rows = unlist(counts),
    stringsAsFactors = FALSE
  )

  result_plot <- ggplot(result_table, aes(x = dataset, y = rows)) +
    geom_bar(stat = "identity", fill = "#3498db", alpha = 0.7) +
    theme_minimal() +
    labs(title = "Dataset Row Counts", x = "Dataset", y = "Rows")

  logs <- c(logs, paste0("Analyzed ", length(selected), " dataset(s)"))
}
```

**Register in `R/presets.R`:**
```r
list(
  id = "simple_counter",
  label = "Counter: row counts",
  file = "simple_counter.R",
  description = "Count rows in each dataset"
)
```

**Add to UI in `app.R`:**
```r
"Counter: row counts" = "simple_counter"
```

Done! Test by selecting datasets and running the preset.

## Debugging Tips

### View logs in console
Template code is executed and captured. Check RStudio console for print output.

### Add print() statements
```r
print("Debug point reached")
print(str(mydata))  # Show structure
```

### Check variable names
```r
logs <- c(logs, paste("Available columns:", paste(colnames(ds), collapse = ", ")))
```

### Test locally first
Before adding to presets:
```r
# In RStudio console:
source("R/presets.R")

# Manually prepare inputs
datasets <- list(data1 = mydata)
selected <- "data1"
params <- list()

# Run your script
source("scripts/templates/my_preset.R")

# Check outputs
result_table
result_plot
logs
```

---

**Last Updated:** 2026-02-09
