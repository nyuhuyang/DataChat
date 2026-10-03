---
status: completed
completed: 2026-10-02
created: 2026-10-02
---

# Make DataChat deployable to shinyapps.io

## Goal

`app.R` runs locally and the app can be deployed to shinyapps.io with a small, explicit bundle, working LLM providers, and access control appropriate for a public URL. The actual `rsconnect::deployApp()` call, choosing the account, setting the password value, and git commit/push are left to the user.

## Acceptance criteria

1. `Rscript -e 'shiny::runApp("app.R")'` (with the project R toolchain below) starts without error, serves HTTP 200, and logs no `loadSupport` package warning. When launched via `app.R`, `.env`, bundled data and templates resolve from the checkout even if a `DataChat` package is installed.
2. Each LLM provider gets the key that belongs to its vendor: Anthropic base URLs use `DATACHAT_ANTHROPIC_API_KEY`; all other (OpenAI-compatible) base URLs use `DATACHAT_API_KEY`. Providers whose key is missing are omitted from the dropdown instead of failing at request time with "API key is invalid".
3. Password gate: when `DATACHAT_APP_PASSWORD` is set, no server module (data loading, chat, artifacts, history) is initialised until the correct password is submitted. Failed attempts trigger a per-session cooldown enforced by timestamp (attempts during cooldown are rejected immediately; no `Sys.sleep`, nothing blocks the worker). When running on shinyapps.io (`R_CONFIG_ACTIVE == "shinyapps"`) and no password is set, the app fails closed with a configuration message. Locally with no password, the app starts without a gate (dev convenience).
4. Uploads are per-session: an uploaded file is stored under a session-specific temp dir using `basename()` of the client-supplied name, made unique against bundled names and this session's existing uploads (`stem.ext`, then `stem_2.ext`, `stem_3.ext`, …), so every checkbox maps to exactly one source, is loaded only into that session, and the session dir is deleted on session end. The session's file list = its own uploads + bundled `data/input/` files; other sessions never see it. A fresh upload is auto-checked so it is immediately usable by chat/presets/LLM analysis (which resolve inputs from the checked list). Each upload's profile is written to its own dir `<session_dir>/profiles/<unique name>/`, never the shared profiles dir, so no two files share a profile path. Filenames in the list render as escaped text (a markup-like name displays literally).
5. `deploy.R` deploys an explicit whitelist: `app.R`, `R/_disable_autoload.R`, `.env`, `DESCRIPTION`, `NAMESPACE`, `R/*.R`, `R/templates/*.R`, and demo data `data/input/{SPOKE_subset_edges.csv, SPOKE_subset_node.csv, SPOKE_nodes.csv, CHDI_task_573_paper_x_data_availability.xlsx}`. It never includes `SPOKE_edges.csv`, `data/output/`, `.local/`, `.claude/`, `.config/`, `.cache/`, `.git/`, `ui/`, `server/`, `tests/`. Bundle < 10 MB. It refuses to deploy if `.env` lacks `DATACHAT_APP_PASSWORD`. A dry-run mode prints the file list and total size without deploying.
6. `rsconnect::appDependencies()` on a staged copy of exactly the whitelisted files resolves every package to CRAN.
7. Full test suite passes; `R CMD check --no-manual` has 0 errors and 0 warnings.
8. README documents the R toolchain, env vars (placeholders only), and deploy steps.

## Root causes found in recon (verified 2026-10-02)

| # | Problem | Evidence |
|---|---|---|
| 1 | `app.R` sources `R/*.R` without attaching NAMESPACE imports (`shiny`, `bslib`, `dplyr`, `ggplot2`, `tibble`) | `Error: could not find function "page_sidebar"` from `build_ui` (`R/ui_main.R:6`). With packages attached the UI, `/schema_check`, `/force_network caffeine` and OpenAI LLM analysis all worked in the browser |
| 2 | Shiny autoloads `R/` before `app.R` and warns the dir is a package; files are sourced twice | `Warning in warn_if_app_dir_is_package(appDir)` |
| 3 | Top-level `require("arrow")` attaches arrow as a side effect | `R/utils_file_io.R:6` |
| 4 | Single `DATACHAT_API_KEY` (an OpenAI key) is sent to every provider | Claude provider returns `API Error: API key is invalid.`; GPT-4o succeeds. `R/server_chat.R:198,234,253` |
| 5 | Default rsconnect bundle is 274 MB and contains `.env`, `.local/`, `.claude/`, `.config/`, `.cache/`, 250 MB `SPOKE_edges.csv` | `rsconnect::listDeploymentFiles(".")` |
| 6 | Uploads copied into shared `data/input/` under the raw client name (`overwrite = TRUE`) — visible to all visitors, name unsanitised | `R/server_data_loading.R:300-306` |
| 7 | LLM-generated code runs in an env whose parent is `.BaseNamespaceEnv`, so it can call `Sys.getenv()`/`system()` | `R/utils_execution.R:7`, `R/presets.R` `execute_template` |
| 8 | PATH `Rscript` is Homebrew R 4.6.1 without `shiny`; conda `r-4.5` env has all deps and `rsconnect` 1.10 | `which -a Rscript`; package probe |

## Approach and decisions

User decisions (2026-10-02):
- **Secrets:** ship `.env` in the bundle (shinyapps.io has no env-var UI). Use a dedicated, spend-capped key.
- **Access:** app-level password gate via `DATACHAT_APP_PASSWORD` in `.env`.
- **Data:** bundle subset/demo files only.
- **Uploads:** per-session.

Implementation:
1. **`app.R`**: `library()` the five NAMESPACE imports, then source `R/*.R`, then `run_app()`. Explicit `library()` calls also make rsconnect dependency detection obvious.
2. **`R/_disable_autoload.R`**: marker file (one comment line; Shiny checks for it inside `R/`, per shiny NEWS #3513) disables `R/` autoload. `app.R`'s source glob uses `\.R$` so it would source this harmless comment-only file — exclude it explicitly by name. Add `^R/_disable_autoload\.R$` to `.Rbuildignore`.
   Also in `app.R`: `options(datachat.app_root = normalizePath("."))` before sourcing; `datachat_project_root()` / `datachat_file()` / `datachat_app_data_dir()` in `R/aaa-package-utils.R` prefer this option over the installed-package path, so a checkout launch never picks up an installed copy's resources.
3. **`R/utils_file_io.R`**: `arrow_available <- requireNamespace("arrow", quietly = TRUE)`.
4. **Provider keys** (`R/utils_code_gen.R` or `R/ui_sidebar.R`): add `llm_api_key(base_url)` returning `DATACHAT_ANTHROPIC_API_KEY` for Anthropic URLs, `DATACHAT_API_KEY` otherwise. `get_llm_providers()` drops providers with an empty key (console note). Replace the three `Sys.getenv("DATACHAT_API_KEY")` calls in `server_chat.R` with `llm_api_key(provider_parts[1])`. Sidebar help text reflects whether any provider is usable.
5. **Password gate** (`R/server_main.R`): wrap current module wiring in `start_app()`. Logic: password set → modal (`passwordInput` + button, `easyClose = FALSE`); correct → `removeModal()` + `start_app()` once; wrong → notification and set `locked_until <- Sys.time() + cooldown` (cooldown doubles per failure, capped at 30 s); attempts before `locked_until` are rejected immediately without comparing. No password and `R_CONFIG_ACTIVE == "shinyapps"` → non-dismissable error modal, modules never start. No password locally → `start_app()` directly. Compare with `identical()`.
6. **Per-session uploads** (`R/server_data_loading.R`): helper `unique_upload_name(client_name, taken)` → `basename(client_name)` if not in `taken`, else first free `stem_<n>.ext` (n = 2, 3, …); `taken` = bundled basenames ∪ basenames already in the session dir. Upload path = `file.path(session_dir, unique_name)`. Session dir `file.path(tempdir(), "datachat-uploads", session$token)`. `list_input_files()` returns session uploads + bundled files (so selection flow in `server_chat.R:79-88`, which matches checked basenames, works unchanged). After upload: `files_refresh()` bump and `updateCheckboxGroupInput(..., selected = union(current, input_path))` so the upload is selected. `build_shared_profile_info()` gains an `output_dir` arg; uploads pass `file.path(session_dir, "profiles", unique_name)` so each upload has a distinct profile path (no collision with bundled files or other uploads, e.g. `study.csv` vs `study.xlsx`) (avoids `build_selected_profile_context` dedupe-by-path dropping a source). `session$onSessionEnded()` unlinks the session dir. In `existing_files_ui`, build labels with tag helpers (`tagList(file_name, tags$br(), tags$small(...))`) instead of `HTML(sprintf(...))`, so names are escaped.
7. **`deploy.R`**: `deploy_files()` builds the whitelist; `Rscript deploy.R --dry-run` prints files + MB; otherwise checks `.env` has a non-empty `DATACHAT_APP_PASSWORD`, then `rsconnect::deployApp(appFiles = deploy_files(), appName = Sys.getenv("DATACHAT_APP_NAME", "DataChat"), account = Sys.getenv("SHINYAPPS_ACCOUNT"))` (account required since two shinyapps.io accounts are configured). Add `^deploy\.R$` and `^R/_disable_autoload\.R$` to `.Rbuildignore`; add `^rsconnect$` too.
8. **Tests** (`tests/testthat/`): helper attaches the same imports as `app.R` (works in both checkout and R CMD check, since `R/` ships in the tarball). Tests touching checkout-only assets (`app.R`, `deploy.R`, `data/`) call `skip_if_not(file.exists(...))` so installed-package `R CMD check` skips them; deploy-file logic is tested against the checkout when present. New focused tests: provider key routing + provider filtering; password gate via `shiny::testServer(build_server(), ...)` (wrong password → modules not started, right → started, shinyapps without password → not started); `deploy_files()` includes `.env`/templates/subset data and excludes `SPOKE_edges.csv`, `ui/`, `server/`, `data/output`; `source("app.R")` returns a `shiny.appobj`.
9. **README**: toolchain, env vars (placeholders), password gate, deploy steps, security note on generated-code execution.

Non-goals:
- Real sandboxing of generated R code (out of scope; mitigated by the password gate — any authenticated user is trusted with the key).
- Removing legacy `ui/`/`server/` copies, refactoring the dead `load_file_` observer, updating model IDs inside the user's `.env`.
- Running `deployApp` or committing/pushing.

## Risks

- Authenticated users can still read the key via generated code. Accepted with the password gate; recommend a dedicated spend-capped key.
- `R_CONFIG_ACTIVE == "shinyapps"` as the shinyapps.io detector: documented behaviour of shinyapps.io; if it ever changes, the gate still works whenever a password is set, and `deploy.R` refuses to deploy without one.
- Free tier memory (1 GB) with arrow loaded: arrow is only loaded via `requireNamespace` when present; acceptable.
- Pre-existing (deferred, found in inspection): LLM/rule-based execution binds at most one dataset per type (`df_nodes`/`df_edges`/`df_metadata`), so two checked same-type files are both profiled but only the last is executable. Documented in README; presets see all checked files.
- `.env` currently has no `DATACHAT_ANTHROPIC_API_KEY` or `DATACHAT_APP_PASSWORD`; the user must add them (Claude provider will be hidden until then).

## Toolchain

- R: `/Users/yanghu/miniforge3/envs/r-4.5/bin/Rscript`, invoked with `env -u R_HOME` (shell exports a conflicting `R_HOME`). Referred to below as `RS`.
- Packages present there: shiny 1.14.0, bslib, dplyr, DT, ggplot2, httr2, networkD3, readr, readxl, shinyjs, tibble, arrow, testthat 3.3.1, rsconnect 1.10.0.
- Codex reviewer/inspector: read-only; the host runs all proof commands.

## Verification

Run from repo root; `RS="env -u R_HOME /Users/yanghu/miniforge3/envs/r-4.5/bin/Rscript"`.

1. `$RS -e 'testthat::test_dir("tests/testthat")'` → `FAIL 0`.
2. Launch smoke: `$RS -e 'shiny::runApp("app.R", port = 8765, launch.browser = FALSE)'` in background → `curl` returns 200; log has no `Error` and no `warn_if_app_dir_is_package`.
3. Staged-bundle smoke (also proves `R/_disable_autoload.R` placement — no package warning in log): copy `deploy_files()` into a temp dir; run there with `R_CONFIG_ACTIVE=shinyapps` and a temp `.env` without password → HTTP 200 and page shows the configuration-error modal; with password → login modal.
4. `$RS deploy.R --dry-run` → file list matches criterion 5, total < 10 MB.
5. `$RS -e 'd <- rsconnect::appDependencies("<staged dir>"); stopifnot(all(d$Source == "CRAN"))'`.
6. `R CMD build .` + `R CMD check --no-manual` (output dir in scratchpad) → 0 errors, 0 warnings.
7. Manual browser check (chrome-devtools): password gate blocks then admits; select subset node+edge files → `/schema_check` and `/force_network caffeine` render; upload a CSV → appears checked in that session and `/schema_check` includes it; upload the same file again → listed as `name_2.csv`, both selectable independently; a second session's file list does not show it; wrong password twice → second attempt rejected during cooldown; LLM (GPT-4o) query returns an answer.

## Progress Checklist

- [x] Fix `app.R` (attach imports, app-root option) and add `R/_disable_autoload.R`; make resource helpers prefer the app-root option
- [x] Replace top-level `require("arrow")` with `requireNamespace`
- [x] Add `llm_api_key()`, provider filtering, and use it in `server_chat.R` + sidebar text
- [x] Add password gate in `build_server()`
- [x] Per-session uploads with `basename()` sanitisation and cleanup
- [x] Add `deploy.R` (whitelist, dry-run, password precheck)
- [x] Update `.Rbuildignore` (keep user's existing edits)
- [x] Update test helper and add focused tests
- [x] Update README (toolchain, env vars, deploy, security note)
- [x] Verification 1: test suite passes
- [x] Verification 2: local launch smoke
- [x] Verification 3: staged-bundle smoke (fail-closed + login modal)
- [x] Verification 4: deploy dry-run file list/size
- [x] Verification 5: staged appDependencies all CRAN
- [x] Verification 6: R CMD check clean (0 errors/warnings)
- [x] Verification 7: manual browser check
- [x] Fresh Codex inspection of final diff; fix and reinspect as needed — Codex inspections 1–4 (REVISE, all fixed or dispositioned); Codex hit usage limit for 5–6, fresh Claude fallback APPROVED (degraded_same_provider)
- [x] Hand off (instructions delivered; actions remain the user's): user adds `DATACHAT_APP_PASSWORD` (+ optional `DATACHAT_ANTHROPIC_API_KEY`) to `.env`, runs `SHINYAPPS_ACCOUNT=<account> Rscript deploy.R`
