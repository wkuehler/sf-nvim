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

Nothing is loaded until `require("sf-nvim").setup()` is called — there is no `plugin/`
directory. `doc/sf-nvim.txt` is the help file — update it alongside README and
`M.actions` when commands/options change. `:checkhealth sf-nvim` (`health.lua`) works without `setup()`.
CI (`.github/workflows/ci.yml`) runs stylua, luacheck, and the tests on nvim 0.9.5/stable/nightly. Formatting is tabs, 120 columns (`stylua.toml`).

## Architecture

`init.lua` is the only entry point. `M.actions` is a `group → action → {fn, desc, key}`
table that is the **single source of truth** for both the `:Sf <group> <action>` user
command (with completion) and the optional default keymaps (`leader_prefix .. key`).
Add a feature by adding one entry there; don't register commands or keymaps elsewhere.
`setup()` merges opts over `default_config` and pushes `test_results_dir`/`test_wait_time`
into `apex.config` (the only module with its own config table).

All process execution goes through `utils/runner.lua`, which has two styles:

1. **`runner.term(cmd, {on_exit})`** — interactive terminal split at the bottom, ends
   with a `Press ENTER to close` pause, deletes its buffer on `TermClose`, then calls
   `on_exit(code)`. Used by `apex.lua`, `org.lua`, `project.lua`. Pass an argv list and
   it is shell-escaped for you; pass a string only when you need shell syntax (the test
   runner does, to redirect `--json` output). Test runs invoke `sf apex run test`
   **twice** — once `--json` to a timestamped file under `<cwd>/<test_results_dir>/`,
   once plain for a readable stream — and `on_exit` hands the file to
   `quickfix.load_from_file`.
2. **`runner.capture(argv)` / `runner.json(argv)`** — synchronous `vim.fn.system` with an
   argv list (no shell). Used by `set-config.lua` and `quickfix.find_class_file`. These
   block the UI; the async roadmap item is about replacing these and non-interactive
   `term` uses with `vim.system()`.

`quickfix.lua` parses `sf apex run test --json`: walks `result.tests[]`, keeps
`Outcome == "Fail"/"CompileFail"`, pulls the first `line N, column M` out of
`StackTrace`, and resolves `ApexClass.Name` to a path with ripgrep. `parse_test_results`
takes an injectable file resolver so it can be unit-tested; failures whose class file
isn't found are reported in the summary notification rather than dropped. This module
and `set-config.build_org_items` are the two places coupled to the CLI's JSON shape.

## Conventions and gotchas

- User-facing feedback goes through `vim.notify` / `vim.ui.select` / `vim.ui.input`
  only — no third-party UI dependencies (this was a deliberate removal; don't reintroduce).
- Never build shell strings by hand; use argv lists with `runner.term`/`capture`, or
  `runner.shell_join` when you genuinely need a string. Apex class names are validated
  against `^[%w_]+$` before reaching ripgrep.
- Scratch org definition files are discovered via `config/**/*-scratch-def.json` relative
  to `getcwd()`; the standard `force-app` layout is otherwise assumed but not verified.
- Stated Neovim floor is 0.7 (README). `vim.system()` (0.10+) is not used yet; if you
  raise the floor, update the README requirement too.
- `open-items.md` is the roadmap; check items off there as they land.
