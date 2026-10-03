# Review log — 2026-10-02-shinyapps-deploy-ready

- Host/coordinator: Claude Code (claude-opus-5-5). Builder: Claude (host). Plan reviewer + final inspector: Codex CLI (fresh sessions), model/effort = CLI defaults.
- Scope: make app.R run and the app deployable to shinyapps.io. Actual deployApp, account choice, password value, git commit/push left to user.
- Authorization: user asked to "fix until it can be pushed to shinyapps.io" → plan + build authorized.
- Limits: MAX_ROUNDS=20, MAX_FIX_ROUNDS=20, MAX_INSPECTION_ROUNDS=20. Fallback: same-provider-on-unavailable. Inspect: on.
- User decisions: ship .env in bundle; app password gate; subset demo data only; per-session uploads.
- Pre-build commit: 48fa05c (working tree had user's .Rbuildignore edit + untracked AGENTS.md, DataChat.Rproj — preserved).
- Env prep: installed r-dt r-networkd3 r-shinyjs r-testthat r-arrow into conda env r-4.5 via mamba (user's local toolchain).

## Plan review rounds

### Round 1 — Codex — REVISE
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/review-r1/claudex-gx3vpjs6/result.json (session 01a0fded-4fe3-75a0-bd06-90ae92d76eef, codex-cli 0.159.3, plan sha c72b884b…)
- Summary: uploads unavailable to analysis; autoload marker misplaced; unauthenticated blocking path; cache identity, resource lookup, package-test conflicts.
- R1 high (uploads not selectable) — accepted
- R2 medium (marker must be R/_disable_autoload.R) — accepted, verified shiny NEWS #3513
- R3 high (Sys.sleep blocks worker) — accepted, timestamp cooldown
- R4 medium (profile path collisions) — accepted scoped: session-dir profiles + rename on collision
- R5 medium (checkout-only tests break R CMD check) — accepted, skip_if_not
- R6 medium (installed pkg resources shadow checkout) — accepted, app-root option

### Round 2 — Codex — REVISE
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/review-r2/claudex-3e9zuy6s/result.json (resumed session 01a0fded…, plan sha 8a8c0e99…)
- Summary: prior issues resolved; repeated-upload identity, in-session profile collisions, filename HTML injection remain.
- R7 medium (repeat upload same basename) — accepted, unique_upload_name
- R8 medium (in-session profile path collisions) — accepted, per-upload profile dir
- R9 medium (filename HTML injection in file list) — accepted, tag helpers

### Round 3 — Codex — APPROVED
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/review-r3/claudex-rhkyyvd6/result.json (resumed session 01a0fded…, plan sha d4df361bee39fba07f92ed4af94bce0c9edea40a3a061469afb11f5682cd750e, assurance cross_provider)
- Summary: all nine prior findings addressed at plan level; no additional material defects found.

## Build
- Builder: Claude (host), pre-build commit 48fa05c.
- Implemented all plan steps. Deviation (additive): `build_server(start_server = start_datachat_server)` injection param so gate tests work under installed-package R CMD check (namespace bindings locked). Also added `^docs$`, `^AGENTS\.md$`, `^\.github$` to .Rbuildignore and `withr` to Suggests.
- Observed: user edited .env at 14:42 (now only a Claude provider, with an OpenAI `sk-proj` key) → Claude is correctly hidden until DATACHAT_ANTHROPIC_API_KEY is set.

## Host verification (Claude)
- V1 tests: FAIL 0 | PASS 82.
- V2 local launch: HTTP 200, no Error / package warning (re-run after final code change).
- V3 staged whitelist bundle with R_CONFIG_ACTIVE=shinyapps: no password → "Configuration error" modal, no file list; with password → login modal.
- V4 dry-run: 35 files, 3.6 MB.
- V5 appDependencies(staged): 88 packages, all CRAN.
- V6 R CMD check --no-manual: Status OK (78 pass, 2 checkout-only skips).
- V7 browser (staged, R_CONFIG_ACTIVE=shinyapps): wrong pw → "Incorrect password"; immediate retry with correct pw → "Too many attempts"; after wait → admitted, 4 bundled files. Upload SPOKE_subset_node.csv → SPOKE_subset_node_2.csv auto-checked, prior check kept; again → _3; `<img src=x onerror=alert(1)>.csv` listed literally, no alert, 0 <img>. /schema_check covered all 4 selected; /force_network caffeine rendered 8 nodes; GPT-4o LLM answer correct. Second isolated session saw only 4 bundled files. Per-upload profile dirs under session dir; shared profiles untouched. Session dir deleted after closing page.

## Inspection 1 — Codex (fresh) — REVISE
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-1/claudex-m6gx_lku/result.json (session 01a0fdff-a9a9-77f2-aadc-0d818f5523e3, assurance cross_provider, base 48fa05c)
- DC-01 medium hidden-name uploads omitted/overwritten — accepted: list.files(all.files=TRUE, no..=TRUE), file.copy(overwrite=FALSE) checked.
- DC-02 medium LLM mode on with no usable provider → uncaught observer error — accepted: checkbox defaults to has-provider; server falls back to rule-based with notification.
- DC-03 medium legacy load handlers write upload profiles to shared dir — accepted: profile_dir_for(path) chosen centrally as build_shared_profile_info default.
- DC-04 low deploy password check ≠ runtime parsing — accepted: mirror load_dotenv (last assignment wins, trimmed) + tests.
- Host re-verification: tests PASS 85; browser on re-staged bundle: LLM default off, notification + rule-based answer, no disconnect; .study.csv twice → .study.csv + .study_2.csv both checked; legacy load_file_1 trigger OK; upload profiles only in session dir. R CMD check rerun below.
- R CMD check after fixes: Status OK.

## Inspection 2 — Codex (fresh) — REVISE
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-2/claudex-7zfw68dt/result.json (session 01a0fe05-4d29-7170-8864-8d4b10c6643d, cross_provider)
- DC-05 medium clearing all checkboxes left stale selection (observeEvent ignoreNULL) — accepted: ignoreNULL = FALSE; testServer regression added; browser: empty selection → "Please select at least one dataset" alert.
- DC-06 medium one-slot-per-type source binding drops a second same-type upload in LLM/rule-based execution — REJECTED as out of scope: pre-existing execution-contract design (predates this work, same for bundled files), not a deployment blocker; reported to user as follow-up.
- DC-07 medium runtime load_dotenv dropped trailing '=' — accepted: loader now splits at first '=' and sets empty values (matches deploy.R env_has_password); tests for trailing/embedded '=' and empty last assignment.
- Note: one browser run hit a stale server on a reused port; re-run on a fresh port confirmed the fix. Tests PASS 91. R CMD check: see next line.
- R CMD check after inspection-2 fixes: Status OK.

## Inspection 3 — Codex (fresh) — REVISE
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-3/claudex-g5_rc_m8/result.json (session 01a0fe0d-c7f2-78e2-86b9-dcb40f075c3b, cross_provider)
- DC-08 medium '..' upload name copied outside session dir; profiles dir not reserved — accepted: empty/'.'/'..' → "upload"; taken includes all session entries + "profiles"; refuse existing destination. Tests PASS 95; browser: '..' → upload, 'profiles' → profiles_2, nothing outside session dir. R CMD check Status OK.

## Inspection 4 — Codex (fresh) — REVISE
- Result: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-4/claudex-mowlhcnu/result.json (session 01a0fe14-7c2e-7c70-bfa5-f55a72d316a7, cross_provider)
- DC-09 medium client could select another session's upload path — accepted: selection intersected with this session's list_input_files(); testServer regression for a foreign path.
- DC-10 low unbounded filename → profile path >255 bytes — accepted: stem capped at 100 bytes (ponytail note), test added.
- DC-11 medium (= DC-06) one dataset per type in execution — implementation still deferred (pre-existing); accepted the documentation half: README "Known limitation" bullet.
- Host: tests PASS 97; browser (fresh port 8770): upload mine.csv auto-checked, /schema_check sees it, no alert.
- R CMD check after inspection-4 fixes: Status OK. Plan Risks amended with the deferred one-dataset-per-type limitation (post-approval doc-only change).

## Inspection 5 — Codex FAILED (provider_unavailable: usage limit, resets 4:50 PM) → fallback Claude (fresh) — APPROVED, assurance degraded_same_provider
- Primary failure: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-5/claudex-zp7wa24o/result.json (failure_kind provider_unavailable, fallback_eligible true)
- Fallback: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-5fb/claudex-jt3z4uel/result.json (session 01759564-49fb-4beb-94b6-a9c6eb8e7b62)
- SR-01 low bundled-dir listing now shows .DS_Store locally — accepted: bundled dir lists without all.files.
- SR-02 low unvalidated llm_provider could send key to arbitrary URL — accepted: provider must be in get_llm_providers().
- SR-03 low pre-auth Shiny upload endpoint — accepted as documented risk (README).
- Inspector limitation "does rsconnect bundle .env with appFiles?" — host verified: rsconnect::listDeploymentFiles(".", appFiles = deploy_files()) includes .env, 35/35 files.
- Host: tests PASS 97; browser (8771): .DS_Store hidden; GPT-4o answer "2,529 rows"; spoofed provider → notification + rule-based, no request to attacker URL.
- R CMD check after inspection-5 fixes: Status OK.

## Inspection 6 — Codex FAILED (provider_unavailable) → fallback Claude (fresh) — APPROVED, degraded_same_provider
- Primary failure: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-6/ ; fallback: /private/tmp/claude-501/-Users-yanghu-Documents-AI-Workspace-prototypes-DataChat/4aa0ed0d-bb2e-4050-b39a-5ff615a9008d/scratchpad/inspect-6fb/claudex-dtcj0pn9/result.json (session 05b7910b-13a4-4d88-82a5-f6e9a24c3f3b)
- FB-01 low README overstated upload privacy — accepted (README wording).
- FB-02 low 100-byte stem cap trims by display width; exotic multibyte names can exceed 255 bytes and fail safely with "could not store upload" — left as residual.
- FB-03 low README should require a strong password (per-session cooldown) — accepted (README wording).
- Post-inspection edits: README.md wording only (FB-01, FB-03). Not re-inspected.

## Outcome
- Assurance: plan review cross_provider (Codex, 3 rounds). Final code inspection: Codex rounds 1–4 cross_provider (REVISE → fixed); rounds 5–6 degraded_same_provider (Claude fallback, APPROVED) because Codex usage limit was hit.
- Rejected/deferred: DC-06/DC-11 one dataset per type in execution (pre-existing; documented).
