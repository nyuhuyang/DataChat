You are working in an R Shiny project.

Global working rules (must follow strictly):

* This is a demo / prototype project.
* The primary goal is: make the app run and demonstrate functionality.
* Do NOT over-engineer.
* Do NOT redesign architecture unless explicitly asked.
* Do NOT introduce abstractions “for future scalability” unless requested.

Current focus scope:

* Focus on the core application files:
  - **`app.R`** - Main Shiny application (single-file, ~1650 lines)
  - **`R/presets.R`** - Preset/template system (sourced by app.R)
  - **`R/templates/`** - Preset template scripts (loaded dynamically)
* Treat these three as the single source of truth for app logic and functionality.
* Other files (docs, data, config) may exist, but ignore unless explicitly mentioned.

Current task constraints:

* Do NOT refactor project structure.
* Do NOT create new files.
* Do NOT write documentation.
* Do NOT add new dependencies unless the app cannot run without them.

Workflow:

1. First, read the current focus scope completely.
2. Identify the minimal change needed to complete the task.
3. Apply the smallest possible modification.
4. Explain exactly:

   * what changed
   * where (file + line range)
   * why it was necessary

If changes beyond the current focus scope are required:

* STOP
* Ask for explicit permission before proceeding.