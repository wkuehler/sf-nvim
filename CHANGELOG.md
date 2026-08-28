# Changelog

Progress log for sf-nvim. One entry per milestone (a roadmap item from
`open-items.md` landing), newest first, grouped under the release that shipped
it. Versions follow semver; lazy.nvim users can pin with `version = "*"` or a
tag.

## v0.5.0 — 2026-08-28

**Breaking:** anonymous Apex keys moved to `<leader>sae`/`sad`, `:Sf log latest` to `<leader>slL`. Adds `:Sf test failed`, a `plugin/` startup stub, and which-key group labels.

### 2026-08-28 — Rerun failed tests, `plugin/` stub
- `:Sf test failed` (`<leader>stf`): reads the newest results file, collects
  Fail/CompileFail methods (`quickfix.failed_tests`) and reruns them with
  `--tests Class.method ...`. `apex.run_tests` now takes a target list.
- `plugin/sf-nvim.lua`: `:Sf` (with completion) exists at startup; the first
  invocation without a prior `setup()` runs `setup({})`. `M.did_setup` flag,
  `M._command`/`M._complete` exported for the stub. `plugin_spec` sources
  the file in isolation.
- Tests: 85 total.

### 2026-08-28 — Keymap review (breaking)
- Anonymous Apex keys moved under an `a` prefix so every group is a two-key
  prefix: `<leader>se` → `<leader>sae`, `<leader>sd` → `<leader>sad` (normal
  and visual). `:Sf log latest` moved `<leader>slr` → `<leader>slL` (shift =
  "the latest one", matching `spf`/`spF`).
- `require("sf-nvim").groups`: `name -> {prefix, label}`; registered with
  which-key.nvim when present so `<leader>s` shows a labelled menu. Test
  asserts every action key starts with its group prefix and has a desc.
- Descriptions tightened across the board (e.g. "Pick target org", "Deploy
  whole project to org", "Toggle debug log tail (background)").
- Reviewed against `sf commands`; reserved prefixes for roadmap items:
  `g` generators, `oa`/`ox`/`oO`/`oL` org login/delete/open-picker/limits.

## v0.4.1 — 2026-08-28

Background debug log tail, `:Sf log show`, and a statusline provider.

### 2026-08-28 — Background log tail and statusline
- `:Sf log tail` (`<leader>slt`) now toggles `sf apex tail log` in the
  background (`runner.stream` over `vim.system` with line callbacks) instead
  of opening a terminal split. Output accumulates in the hidden
  `sf://log/tail` buffer (last 5000 lines); each log header bumps a counter
  and, with the new `tail_notify` option (default true), posts a
  notification. Unexpected exits are reported as errors; the process is
  killed on `VimLeavePre`.
- `:Sf log show` (`<leader>sls`): open the tail buffer in a split, following
  new output while the cursor is on the last line; `q` closes it, the tail
  keeps running.
- `require("sf-nvim").status()` for statuslines: target org (cached via
  `org.refresh_target` at setup and updated by `:Sf config org`) plus
  `⏺ N` while tailing. `User SfTargetChanged` / `SfTailChanged` events.
- Tests: `tail_spec` (stream chunking/kill, toggle, counting, hidden buffer,
  follow-on-append, cap, unexpected exit, target refresh) — 77 total.
- (Earlier today) `:Sf log tail` first landed as a terminal split; that
  variant never shipped in a release.
- `:Sf log latest` no longer opens a buffer containing "No results found"
  (the CLI exits 0 with that text); both it and `list` now warn with
  "No stored debug logs. :Sf log tail creates a trace flag."

## v0.4.0 — 2026-08-28

Debug logs, anonymous Apex with inline log, SOQL runner, filetype detection.

### 2026-08-28 — Debug logs and SOQL
- `runner.scratch({name, lines, filetype})`: read-only result buffers in a
  bottom split, reused by name, `q` to close. Used by everything below.
- `:Sf apex debug` / `debugselection` (`<leader>sd`, normal/visual): run
  anonymous Apex via `sf apex run --json` in the background; the
  `sf://apex-run` buffer shows a verdict line (success / compile error with
  line:col / runtime exception + stack) then the full log. Handles the CLI's
  three payload shapes (`result` on success, `data` under
  `executeCompileFailure` / `executeRuntimeFailure`).
- `:Sf log list` (`<leader>sll`): `sf apex list log --json` → picker
  (time, operation, status, KB, ms, user) → `sf://log/<id>`.
  `:Sf log latest` (`<leader>slr`): `sf apex get log --number 1`.
- `:Sf soql buffer` / `selection` / `prompt` (`<leader>sqb` / `sq` visual /
  `sqq`): `sf data query --json` rendered as an aligned table in
  `sf://query`. Columns follow the SELECT clause; relationships flatten to
  `Owner.Name`; subqueries show `[N rows]`; nulls blank; truncation flagged.
  Errors show the CLI message with its caret line in the buffer.
- `ftdetect/sf-nvim.lua`: `soql`, `apex` (`.apex`; `.cls`/`.trigger` only
  under an `sfdx-project.json`), `apexlog`. `syntax/apexlog.vim` ships.
- Fixtures captured from the real CLI: `apex_run_{success,compile_error,
  runtime_error}.json`, `query_accounts.json`, `query_error.json`;
  `apex_log_list.json` hand-built from the documented shape (the dev org had
  no stored logs). Live-verified: query table, exception verdict + log,
  latest-log fetch.
- Tests: `logs_spec`, `soql_spec`, `ftdetect_spec`, scratch spec (67 total).

## v0.3.1 — 2026-08-28

### 2026-08-28 — Scrollable terminal split
- The terminal split now opens in Normal mode with the cursor on the last
  line, so output is followed as it streams and can be scrolled with ordinary
  motions at any time (previously it started in Terminal mode and needed
  `<C-\><C-n>` to scroll).
- Buffer-local `<CR>` and `q` (Normal mode) close the split once the command
  has finished; `<Esc>` in Terminal mode returns to Normal mode.
- Prompt is now `[sf-nvim] Done. Press ENTER or q to close.`
- Documented in `:help sf-nvim-terminal` and the README.

## v0.3.0 — 2026-08-28

The edit/deploy loop: current-file deploy and retrieve, deploy errors in
quickfix, deploy-on-save, single test method, anonymous Apex from a selection.

### 2026-08-28 — Edit/deploy loop
- `:Sf project file` / `:Sf project fetch` (`<leader>spf` / `spF`): deploy or
  retrieve the current file with `--source-dir`, async. Files inside an
  `lwc/<name>/` or `aura/<name>/` bundle resolve to the bundle; a `-meta.xml`
  resolves to the file it describes. Refuses files outside the
  `packageDirectories` of `sfdx-project.json`.
- Deploy failures → quickfix ("Deploy failures"): `project.parse_deploy_result`
  reads `result.files[]` entries with `state == "Failed"` (absolute path,
  line, column, message — no ripgrep needed). File deploys use the `--json`
  result directly; terminal `deploy`/`validate` fetch
  `sf project deploy report --json` after a non-zero exit (best-effort; the
  CLI does not track dry-runs).
- `deploy_on_save` option: `BufWritePost` under any package directory runs
  the file deploy.
- `:Sf test method` (`<leader>stm`): runs `--tests Class.method` for the
  `@IsTest`/`testMethod` method enclosing the cursor. Lookback only walks
  contiguous annotation lines so a class-level `@IsTest` is never matched;
  `@TestSetup` is rejected.
- `:'<,'>Sf apex selection` (`<leader>se` in visual mode): runs the selected
  lines as anonymous Apex via a temp `.apex` file. `:Sf` now accepts a range,
  and actions may declare `mode = "x"` for visual keymaps.
- Fixtures `deploy_failed.json` / `deploy_succeeded.json` captured from a
  real `sf project deploy start --dry-run --json` against a broken class.
  Live-verified: 5 compile errors → 5 quickfix entries with line:col.
- Tests: `project_spec`, `apex_spec`, range/visual spec in `init_spec`
  (48 specs total).

## v0.2.0 — 2026-08-28

**Breaking:** Neovim 0.10+ required. Async execution for quick lookups,
runtime preflight guards, CONTRIBUTING.md.

### 2026-08-28 — Runtime guards and CONTRIBUTING.md
- `lua/sf-nvim/utils/guard.lua`: `executable(exe)` and `project()` preflight
  checks with one actionable `vim.notify` each, all pointing at
  `:checkhealth sf-nvim`.
- `runner.term` (argv form) and `runner.run` return `nil` without launching
  when the executable is missing. Tests, deploy/retrieve/validate, and
  scratch-org creation require `sfdx-project.json` in cwd. Missing ripgrep is
  reported once per results load instead of silently dropping every failure.
- `CONTRIBUTING.md`: ground rules (floor, no UI deps, argv only, term vs run,
  `M.actions`), workflow, test guidance, style, bug-report checklist.
- Tests: `tests/guard_spec.lua` (32 specs total).

### 2026-08-28 — Async execution, Neovim floor raised to 0.10
- **Breaking:** requires Neovim 0.10+ (`vim.system()`). Enforced in `setup()`
  (clear error and bail), `:checkhealth`, README, help, and the CI matrix
  (now 0.10.0 / stable / nightly).
- `runner.run(argv, {on_exit, progress, cwd})` and
  `runner.json_async(argv, cb)`: async, no shell, callback scheduled on the
  main loop, optional progress notification.
- Converted the UI-blocking call sites: `:Sf config org/hub` fetch the org
  list in the background then open the picker; `sf config set` and
  `:Sf org open` run async and report via `vim.notify`. Terminal splits are
  kept wherever watching output matters (tests, deploy/retrieve/validate,
  scratch org creation, `org list/display`, anonymous Apex).
- `health.lua` drops the 0.7–0.9 `vim.health` shim.
- Tests: `tests/runner_spec.lua` (real subprocesses via `sh`), and
  `set_default` driven end-to-end with stubbed runner/`vim.ui.select`.
  Suite is 27 specs.

## v0.1.0 — 2026-08-28

Last release supporting Neovim 0.7–0.9. Test suite, `:Sf` command, CI,
`:checkhealth`, `:help sf-nvim`, general-purpose README.

### 2026-08-28 — Docs, generalization, `auto_open_quickfix` fix (`93f9802`)
- `doc/sf-nvim.txt`: `:help sf-nvim` with tags for every option, `:Sf` action,
  keymap, and public Lua function.
- README rewritten for any SFDX project (no Resource Hero framing); documents
  config, commands, keymaps, workflow, limitations.
- LuaCATS annotations completed across apex/org/project.
- **Fix:** `auto_open_quickfix` was declared and documented but never read;
  now pushed into `apex.config` and honored before `copen`.
- CI follow-up (`Fix CI...`): stylua formatting applied and pinned to 2.5.2;
  health spec drives `:checkhealth` directly because Neovim 0.9's
  `vim.health.report_*` shims only work inside a real checkhealth run.
  First green CI run: all 5 jobs.

### 2026-08-28 — CI and `:checkhealth` (`ab0ebe7`)
- `.github/workflows/ci.yml`: stylua check, luacheck, and `make test` on
  Neovim 0.9.5 / stable / nightly, on push to `main` and on PRs.
- `lua/sf-nvim/health.lua`: Neovim floor, `sf` and `rg` presence + version,
  `sfdx-project.json` and `config/**/*-scratch-def.json` discovery. Works
  before `setup()` and on 0.7+ via a `vim.health` / `require("health")` shim.

### 2026-08-28 — Test suite, `:Sf` command, argv runner (`87294eb`)
- plenary specs in `tests/` (`make test`) covering quickfix parsing,
  set-config org items, `setup()`, and `:Sf` dispatch/completion.
- `:Sf <group> <action>` with completion, driven by `M.actions` in `init.lua`;
  default keymaps derive from the same table.
- `utils/runner.lua` as the single execution seam (`term` / `capture` / `json`)
  with argv lists shell-escaped instead of hand-built strings. Fixed an
  unescaped scratch-org alias and `.gitignore` not matching `test-results/`.
- `stylua.toml`, `.luacheckrc`, `Makefile`; README uses lazy.nvim `opts`.

### Earlier
- `3009952` Removed nvim-notify dependency; deduplicated org/set-config.
- `3c31738` Security fixes, error handling, terminal-based execution, org
  management.
