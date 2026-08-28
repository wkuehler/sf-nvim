# Changelog

Progress log for sf-nvim. One entry per milestone (a roadmap item from
`open-items.md` landing), newest first. Versioned release sections start once
tagging begins.

## Unreleased

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
