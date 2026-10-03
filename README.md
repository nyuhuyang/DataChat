# DataChat

[![R package](https://img.shields.io/badge/R%20package-v0.0.0.9000-276DC3)](https://github.com/nyuhuyang/DataChat)
[![R](https://img.shields.io/badge/R-%3E%3D%204.1-brightgreen)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://github.com/nyuhuyang/DataChat/actions/workflows/R-CMD-check.yaml/badge.svg?branch=master)](https://github.com/nyuhuyang/DataChat/actions/workflows/R-CMD-check.yaml)

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
  "shiny", "bslib", "DT", "ggplot2", "dplyr", "httr2", "tibble",
  "readr", "readxl", "shinyjs", "networkD3", "rsconnect"
))
```

Use an R installation that actually has these packages. On this machine the
`Rscript` first on `PATH` (Homebrew R) does not; the conda env does:

```bash
RS="env -u R_HOME $HOME/miniforge3/envs/r-4.5/bin/Rscript"
```

### 2. Configure LLM (Optional)

Create a `.env` file in the project root:

```bash
# OpenAI-compatible providers use DATACHAT_API_KEY
DATACHAT_API_KEY=your-openai-key
# Anthropic providers use DATACHAT_ANTHROPIC_API_KEY
DATACHAT_ANTHROPIC_API_KEY=your-anthropic-key
# Provider list: DATACHAT_LLM_<label>=<base_url>|<model>
DATACHAT_LLM_Claude=https://api.anthropic.com/v1|claude-sonnet-4-5
DATACHAT_LLM_OpenAI_GPT4o=https://api.openai.com/v1|gpt-4o
# Password gate (required on shinyapps.io; optional locally)
DATACHAT_APP_PASSWORD=choose-a-password
```

Providers without a matching key are hidden from the dropdown.

### 3. Launch

```bash
$RS -e 'shiny::runApp("app.R")'
```

### 4. Try It Out

- Upload a CSV or place files in `data/input/`
- Type `summary` for basic statistics
- Type `histogram` for a distribution plot
- Type `/schema_check` to inspect data quality
- Enable LLM mode in the sidebar for natural language queries

## Deploy to shinyapps.io

`deploy.R` uploads an explicit whitelist: `app.R`, `.env`, `DESCRIPTION`,
`NAMESPACE`, `R/`, `R/templates/`, and the small demo files in `data/input/`
(the 250 MB `SPOKE_edges.csv`, cached outputs, and local tool folders are excluded).

```bash
$RS deploy.R --dry-run                                  # review files + size
SHINYAPPS_ACCOUNT=<your-account> $RS deploy.R           # deploy
```

- shinyapps.io has no environment-variable settings, so `.env` ships with the
  bundle. Use dedicated, spend-capped API keys.
- `deploy.R` refuses to run unless `.env` sets `DATACHAT_APP_PASSWORD`; on
  shinyapps.io the app also refuses to start without it. Use a long random
  value (e.g. `openssl rand -base64 24`): the login cooldown is per session, so
  password strength is the real protection against guessing.
- Uploaded files are listed only in the uploading session and deleted when it
  ends (generated code runs in the shared app process, so it is not a hard
  isolation boundary between logged-in users).
- The password gate stops the app's own logic, but Shiny's built-in upload
  endpoint still accepts files (up to `shiny.maxRequestSize`, default 5 MB)
  into its temp dir before login; they are discarded when the session ends.
- Known limitation: analysis binds at most one dataset per type (`df_nodes`,
  `df_edges`, `df_metadata`). Checking two files of the same type (e.g. two
  plain CSVs) shows both profiles to the LLM, but generated code only sees the
  last one. Presets (`/schema_check`, `/head`) do see every checked file.
- **Security:** LLM-generated R code runs inside the app process and can read
  environment variables (including API keys). Only share the password with
  people you trust with those keys.

## Architecture

```
DataChat/
├── app.R                    # Source launcher (local + shinyapps.io)
├── deploy.R                 # shinyapps.io deploy with file whitelist
├── .env                     # API keys + providers (gitignored)
├── R/
│   ├── ui_*.R / server_*.R  # Shiny UI and server modules
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

Internal developer notes cover the following implementation areas:
- LLM integration details (Anthropic + OpenAI-compatible APIs)
- Dataset profiling system
- Preset/template system and how to add new ones
- Code patterns, conventions, and troubleshooting

## License

This project is provided as-is for educational and research purposes.
