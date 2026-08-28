# Changelog

Progress log for sf-nvim. One entry per milestone (a roadmap item from
`open-items.md` landing), newest first, grouped under the release that shipped
it. Versions follow semver; lazy.nvim users can pin with `version = "*"` or a
tag.

## Unreleased

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
