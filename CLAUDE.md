# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Neovim plugin (pure Lua, `lua/sf-nvim/`) that wraps the Salesforce CLI (`sf`). It is
being evolved from a personal tool into a general-purpose plugin for SFDX projects — the
roadmap is in `open-items.md`; consult it before proposing new work and check items off
as they land.

## Commands

```sh
make test                                   # whole suite (plenary.nvim, headless)
make test-file FILE=tests/quickfix_spec.lua # one spec file
make lint / make fmt / make fmt-check       # luacheck / stylua (not installed locally yet)
```

Tests are busted-style plenary specs in `tests/*_spec.lua`, bootstrapped by
`tests/minimal_init.lua` (finds plenary under lazy.nvim's data dir, or `$PLENARY_DIR`).
Fixtures in `tests/fixtures/` are hand-built copies of the `sf ... --json` shapes; when
the CLI's output changes, update the fixture *and* the parser together.

To exercise the plugin manually, load it from this checkout inside an SFDX project
(it uses `getcwd()` as the project root):

```sh
cd /path/to/some-sfdx-project
nvim --cmd 'set rtp+=/home/bill/projects/sf-nvim' \
     -c 'lua require("sf-nvim").setup({ enable_default_keybinds = true })'
```

`plugin/sf-nvim.lua` registers `:Sf` at startup (completion and handler are
`M._complete`/`M._command` from `init.lua`); its first use calls `setup({})` if the
user has not. Nothing else loads until then. `doc/sf-nvim.txt` is the help file — update it alongside README and
`M.actions` when commands/options change. `:checkhealth sf-nvim` (`health.lua`) works without `setup()`.
CI (`.github/workflows/ci.yml`) runs stylua, luacheck, and the tests on nvim 0.10.0/stable/nightly. Formatting is tabs, 120 columns (`stylua.toml`).

## Architecture

`init.lua` is the only entry point. `M.actions` is a `group → action → {fn, desc, key}`
table that is the **single source of truth** for both the `:Sf <group> <action>` user
command (with completion) and the optional default keymaps (`leader_prefix .. key`).
Add a feature by adding one entry there; don't register commands or keymaps elsewhere.
`setup()` merges opts over `default_config` and pushes `test_results_dir`/`test_wait_time`
into `apex.config` (the only module with its own config table).

`utils/guard.lua` holds the preflight checks (`executable(exe)`, `project()`); `runner.term`
(argv form) and `runner.run` call `guard.executable` themselves, so a missing `sf` is one
notification, never a shell error. Call `guard.project()` in actions that need an SFDX root.

All process execution goes through `utils/runner.lua`, which has three styles:

1. **`runner.term(cmd, {on_exit})`** — terminal split at the bottom, opened in Normal
   mode at the last line (so it follows output and is scrollable); ends with a
   `read` prompt answered by buffer-local `<CR>`/`q`, deletes its buffer on `TermClose`,
   then calls `on_exit(code)`. Used by `apex.lua`, `org.lua` (except `open`), `project.lua`. Pass an argv list and
   it is shell-escaped for you; pass a string only when you need shell syntax (the test
   runner does, to redirect `--json` output). Test runs invoke `sf apex run test`
   **twice** — once `--json` to a timestamped file under `<cwd>/<test_results_dir>/`,
   once plain for a readable stream — and `on_exit` hands the file to
   `quickfix.load_from_file`.
2. **`runner.run(argv, {on_exit, progress})` / `runner.json_async(argv, cb)`** — async
   `vim.system()`, callback scheduled on the main loop. Used by `set-config.lua`
   (org list → picker → `sf config set`) and `org.open`. Rule of thumb: `term` when the
   user should watch the output, `run` when the plugin consumes it.
   Results that the user reads (logs, query tables) go into `runner.scratch` buffers
   (`sf://...`, read-only, reused by name). `runner.stream` is the long-lived variant
   (line callbacks + `:kill()`), used only by the background log tail in `logs.lua`.
3. **`runner.capture(argv)` / `runner.json(argv)`** — synchronous `vim.fn.system`. Only
   `quickfix.find_class_file` (ripgrep) still uses this; keep it for fast local tools.

`quickfix.lua` parses `sf apex run test --json`: walks `result.tests[]`, keeps
`Outcome == "Fail"/"CompileFail"`, pulls the first `line N, column M` out of
`StackTrace`, and resolves `ApexClass.Name` to a path with ripgrep. `parse_test_results`
takes an injectable file resolver so it can be unit-tested; failures whose class file
isn't found are reported in the summary notification rather than dropped. This module,
`project.parse_deploy_result` (`result.files[]`, `state == "Failed"`),
`logs.parse_run_result` (`result` vs `data`), `soql.render` (`result.records[]`), and
`set-config.build_org_items` are the places coupled to the CLI's JSON shape.

## Conventions and gotchas

- User-facing feedback goes through `vim.notify` / `vim.ui.select` / `vim.ui.input`
  only — no third-party UI dependencies (this was a deliberate removal; don't reintroduce).
- Never build shell strings by hand; use argv lists with `runner.term`/`capture`, or
  `runner.shell_join` when you genuinely need a string. Apex class names are validated
  against `^[%w_]+$` before reaching ripgrep.
- Scratch org definition files are discovered via `config/**/*-scratch-def.json` relative
  to `getcwd()`; the standard `force-app` layout is otherwise assumed but not verified.
- Neovim floor is 0.10 (`vim.system()`); enforced in `setup()`, `health.lua`, README,
  `doc/sf-nvim.txt`, and the CI matrix — change all five together.
- `open-items.md` is the roadmap; check items off there as they land.
- After each milestone (a roadmap item landing), add an entry to `CHANGELOG.md`
  (date, commit, what changed, any bugs found along the way) in the same commit.
