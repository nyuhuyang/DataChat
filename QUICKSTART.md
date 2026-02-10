# DataChat Quick Start Guide

Get up and running with DataChat in 5 minutes.

## Installation (2 minutes)

### 1. Install R Packages

Open R or RStudio and run:

```r
install.packages(c(
  "shiny",
  "bslib",
  "DT",
  "ggplot2",
  "dplyr",
  "httr2",
  "bsicons"
))
```

### 2. Launch the App

From the project directory, run:

```r
shiny::runApp("app.R")
```

The app opens automatically at `http://127.0.0.1:XXXX`

---

## Basic Usage (3 minutes)

### Step 1: Load Your Data

1. Click **"Browse..."** under "Data Loader" in the sidebar
2. Select a CSV or RDS file
3. You'll see:
   - Schema summary showing column names and types
   - Sources section with file metadata and preview

### Step 2: Ask a Question

Type in the message box and press Enter:

**Try these example queries:**
- `"summary"` → Shows variable statistics
- `"histogram"` → Creates distribution plot
- `"count by [column_name]"` → Groups and counts

### Step 3: View Results

Results appear in tabs on the right:
- **Table**: Your data results
- **Plot**: Any visualizations
- **Generated R Code**: The code that ran
- **Logs**: Execution output
- **History**: All past analyses

---

## Using LLM Mode (Optional)

For more advanced queries using AI:

1. Check **"Use LLM for Code Generation"** in sidebar
2. Enter your API credentials:
   - **API Base URL**: `https://api.openai.com/v1` (or your endpoint)
   - **API Key**: Your API key (e.g., from OpenAI)
3. Type natural language queries like:
   - `"create a scatter plot of X vs Y"`
   - `"show me the top 5 categories by count"`
   - `"calculate correlation between columns"`

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Send message | Enter or Cmd/Ctrl+Enter |
| Clear input | (manually select all and delete) |

---

## Common Queries

### Data Exploration

```
"summary"                    → Overview of all variables
"histogram"                  → Distribution of first numeric column
"first 10 rows"              → Preview of data
"column names"               → List of columns
```

### Grouping & Counting

```
"count by category"          → Group by category and count
"group by type and count"    → Group by multiple columns
```

### With LLM (Advanced)

```
"scatter plot of age vs income"
"show correlations between numeric columns"
"create a time series of sales by month"
"compare statistics by group"
```

---

## Browsing History

All your past analyses are saved in the **History** tab:

1. Switch to the **History** tab
2. Click on any past run to see it again
3. Use buttons:
   - 📊 **Table icon** → View that table
   - 📈 **Plot icon** → View that plot
   - **Code** → View the generated R code

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| App won't start | Run `install.packages("httr2")` |
| LLM says "credentials missing" | Check your API key and base URL |
| "No numeric columns to plot" | Try with a different column or dataset |
| History buttons don't work | Refresh the page (F5) |

---

## Test It Out

Try this minimal example:

```r
# Save test data
write.csv(iris, "test_iris.csv", row.names = FALSE)
```

Then in the app:
1. Upload `test_iris.csv`
2. Query: `"summary"`
3. Check the History tab
4. Query: `"histogram"`
5. Click the plot icon in History to switch back

---

## Next Steps

- 📖 Read [CLAUDE.md](CLAUDE.md) for complete documentation
- 🛠️ Learn about [development](CLAUDE.md#development-guidelines) to extend the app
- 🧪 Check [testing](CLAUDE.md#testing--verification) section for validation

---

## Tips & Tricks

✨ **Pro Tips:**

- **Sources section** shows your data schema - expand it to understand your data before querying
- **Rule-based mode** (default) is fast and doesn't need API keys
- **LLM mode** understands natural language better for complex analysis requests
- **History tab** lets you revisit any analysis without re-running code
- **Logs tab** shows exactly what R code was generated and executed

💡 **Best Practices:**

- Start with simple queries to understand the app
- Check the Generated R Code tab to learn R patterns
- Use rule-based mode to prototype, then switch to LLM for polish
- Browse history to compare different analysis approaches

---

**Having issues?** Check the [Troubleshooting section](CLAUDE.md#troubleshooting-guide) in the full documentation.

**Want to customize?** See [Extending the App](CLAUDE.md#extending-the-app) in CLAUDE.md.
