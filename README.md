# DataChat

**Conversational Data Analysis Interface** – An interactive R Shiny app for exploratory data analysis via natural language chat.

## Overview

DataChat combines a chat interface with intelligent code generation to make data exploration accessible and interactive. Upload your data, ask questions in plain English, and get instant visualizations and insights.

### Key Features

- **Chat-based querying** – Ask questions in natural language, get instant results
- **Dual-mode code generation** – Rule-based (offline) or LLM-powered (Claude, GPT, etc.)
- **Multi-format data** – CSV, RDS, XLSX, Parquet
- **Instant visualizations** – Tables, plots, and force-directed network graphs
- **Multi-source analysis** – Combine data from multiple files (nodes, edges, metadata)
- **Preset templates** – Pre-built analysis workflows via slash commands (`/force_network`, `/schema_check`, etc.)
- **Dataset profiling** – Automatic column-level stats, cached for performance
- **Run history** – Browse, compare, and re-run past analyses

## Quick Start

### 1. Install Dependencies

```r
install.packages(c(
  "shiny", "bslib", "DT", "ggplot2", "dplyr", "httr2",
  "readr", "readxl", "shinyjs", "networkD3"
))
```

### 2. Configure LLM (Optional)

Create a `.env` file in the project root:

```bash
DATACHAT_API_KEY=your-api-key-here
DATACHAT_LLM_Claude=https://api.anthropic.com/v1|claude-sonnet-4-20250514
DATACHAT_LLM_OpenAI_GPT4o=https://api.openai.com/v1|gpt-4o
```

### 3. Launch

```r
shiny::runApp("app.R")
```

### 4. Try It Out

- Upload a CSV or place files in `data/input/`
- Type `summary` for basic statistics
- Type `histogram` for a distribution plot
- Type `/schema_check` to inspect data quality
- Enable LLM mode in the sidebar for natural language queries

## Architecture

```
DataChat/
├── app.R                    # Thin orchestrator
├── .env                     # API keys + providers (gitignored)
├── ui/                      # UI component functions
├── server/                  # Server logic functions
├── R/
│   ├── utils_env.R          # .env loader
│   ├── utils_code_gen.R     # Rule-based + LLM code generation
│   ├── utils_profiles.R     # Dataset profiling + caching
│   ├── utils_execution.R    # Sandboxed code execution
│   ├── presets.R            # Preset/template system
│   └── templates/           # Analysis template scripts
└── data/
    ├── input/               # User data files
    └── output/profiles/     # Cached dataset profiles
```

## Documentation

See [CLAUDE.md](CLAUDE.md) for the complete technical reference including:
- LLM integration details (Anthropic + OpenAI-compatible APIs)
- Dataset profiling system
- Preset/template system and how to add new ones
- Code patterns, conventions, and troubleshooting

## License

This project is provided as-is for educational and research purposes.
