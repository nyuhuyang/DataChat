# DataLabChat

**Conversational Data Analysis Interface** – An interactive R Shiny app for exploratory data analysis via natural language chat.

![Status](https://img.shields.io/badge/status-prototype-orange) ![License](https://img.shields.io/badge/license-MIT-blue) ![R Version](https://img.shields.io/badge/R-%3E%3D%204.0-brightgreen)

## Overview

DataLabChat combines a chat interface with intelligent code generation to make data exploration accessible and interactive. Upload your data, ask questions in plain English, and get instant visualizations and insights—no coding required.

### Key Features

- 💬 **Chat-based querying** – Ask questions in natural language, get instant results
- 🤖 **Dual-mode code generation** – Rule-based (offline) or LLM-powered (Claude, GPT, etc.)
- 📊 **Multi-format data** – CSV, RDS, XLSX, and more
- 📈 **Instant visualizations** – Tables, plots, and network graphs
- 🔗 **Multi-source analysis** – Combine data from multiple files (nodes, edges, metadata)
- 📋 **Preset templates** – Pre-built analysis workflows (distribution, counts, summaries)
- 💾 **Run history** – Browse, compare, and re-run past analyses

## Quick Start

### 1. Install Dependencies

```r
install.packages(c(
  "shiny", "bslib", "DT", "ggplot2", "dplyr", "httr2",
  "readr", "readxl", "shinyjs", "networkD3"
))
```

### 2. Launch the App

```r
shiny::runApp("app.R")
```

The app opens at `http://127.0.0.1:XXXX` (URL shown in console).

### 3. Try It Out

- Click **"Load Sample Data (mtcars)"** to test without uploading
- Type `"summary"` to see basic statistics
- Type `"histogram"` to create a distribution plot
- Check the **History** tab to see past analyses

## Usage Examples

### Rule-Based Queries (Offline)

Works instantly without API keys:

```
"summary"                    → Overview of all columns
"histogram"                  → Distribution of first numeric column
"count by category"          → Group and count by column
"first 10 rows"              → Data preview
```

### LLM-Powered Queries (Optional)

Enable in sidebar with API credentials for natural language understanding:

```
"create a scatter plot of age vs income"
"show me the top 5 categories by count"
"calculate correlation between numeric columns"
"create a time series of monthly sales"
```

## Documentation

| Document | Purpose |
|----------|---------|
| [QUICKSTART.md](QUICKSTART.md) | Get started in 5 minutes |
| [CLAUDE.md](CLAUDE.md) | Complete technical reference (for developers) |
| [PRESETS.md](PRESETS.md) | Available analysis templates |
| [PRESET_TEMPLATE_GUIDE.md](PRESET_TEMPLATE_GUIDE.md) | How to create custom templates |

## Architecture

**Single-file design for simplicity:**

```
DataLabChat/
├── app.R                          # Main Shiny app (all logic in one file)
├── R/
│   ├── presets.R                  # Preset system
│   └── templates/                 # Pre-built analysis templates
│       ├── node_type_distribution.R
│       ├── edge_type_count.R
│       └── ...
├── README.md                      # This file
├── QUICKSTART.md                  # Quick reference for users
├── CLAUDE.md                      # Full developer docs
└── ...
```

### How It Works

1. **Upload data** → Automatically detect format (CSV, RDS, XLSX)
2. **Ask a question** → Route to rule-based or LLM code generator
3. **Execute safely** → Run code in isolated R environment
4. **Display results** → Show tables, plots, or network graphs
5. **Save to history** → Browse and re-run past analyses

## Configuration

### Enable LLM Mode

In the sidebar, check **"Use LLM for Code Generation"** and enter:

- **API Base URL**: `https://api.openai.com/v1` (OpenAI) or your endpoint
- **API Key**: Your API credentials

Supports OpenAI, Claude, and any OpenAI-compatible API.

### Supported Data Formats

- **CSV** (`*.csv`) – Comma-separated values
- **Excel** (`*.xlsx`) – Excel workbooks
- **RDS** (`*.rds`) – R serialized data
- **Parquet** (`*.parquet`) – Optional (requires `arrow` package)

## For Developers

### Adding a Code Generation Pattern

1. Edit `app.R` and find the `generate_r_code()` function
2. Add a new `else if` clause:
   ```r
   } else if (grepl("your_keyword", query_lower)) {
     return("r_code_that_sets_result_table_or_result_plot")
   }
   ```
3. Test with the sample data first

### Creating a Preset Template

1. Create `R/templates/my_analysis.R`:
   ```r
   # Your self-contained R analysis code
   result_table <- df %>% summarize(...)
   ```
2. Add entry to `list_presets()` in `R/presets.R`
3. Test by clicking the preset button

See [PRESET_TEMPLATE_GUIDE.md](PRESET_TEMPLATE_GUIDE.md) for detailed examples.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| App won't start | Run `install.packages("httr2")` and verify all packages installed |
| LLM falls back to rule-based | Check API key, base URL, and internet connection in sidebar |
| Data not appearing | Verify file format is supported; check **Schema** section in sidebar |
| Preset buttons missing | Ensure `R/presets.R` is sourced; run `list_presets()` to verify |

See [CLAUDE.md](CLAUDE.md#troubleshooting) for more help.

## Design Principles

This is a **prototype application** optimized for:

- ✅ **Functionality over perfection** – It works and demonstrates the concept
- ✅ **Simplicity** – Single-file app to avoid complexity
- ✅ **Safety** – Code executes in isolated environments
- ✅ **Extensibility** – Easy to add patterns and templates

## Future Enhancements

Possible additions (not currently implemented):

- Persistent storage of run history (currently in-memory only)
- More file format support (JSON, Parquet, SQL)
- Advanced visualizations (3D plots, interactive maps)
- Collaborative analysis features
- Dataset versioning and comparison

## License

This project is provided as-is for educational and research purposes.

## Contributing

Found a bug? Have a suggestion? Open an issue or pull request.

For significant changes, please read [CLAUDE.md](CLAUDE.md#for-future-developers) first to understand the project's constraints and approach.

---

**Questions?** Start with [QUICKSTART.md](QUICKSTART.md) → then explore [CLAUDE.md](CLAUDE.md) for full documentation.
