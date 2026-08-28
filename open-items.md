# Open Items

Goal: evolve sf-nvim from a personal Resource Hero tool into a plugin other
Salesforce developers using Neovim would reasonably adopt as their default.
Current state (as of 2026-08-28): 842 lines, 7 modules, clean and working,
but built and documented as a single-user tool.

## Reliability (do first — these protect correctness)

- [x] **Test suite.** (2026-08-28) plenary specs in `tests/`, `make test`.
      Covers `quickfix.parse_test_results`, `load_from_file`,
      `find_latest_test_results`, `set-config.build_org_items`, `setup()`,
      and `:Sf` dispatch/completion. Shell construction is now argv-based via
      `utils/runner.lua` (no string interpolation to test).
- [x] **CI.** (2026-08-28) `.github/workflows/ci.yml`: stylua check,
      luacheck, and `make test` on nvim 0.9.5 / stable / nightly, on push
      to main and on PRs.
- [x] **`:checkhealth` integration.** (2026-08-28) `lua/sf-nvim/health.lua`:
      Neovim floor, `sf` + `rg` presence/version, `sfdx-project.json` and
      scratch-def files in cwd. Mentioned in README Requirements.

## Execution model

- [x] **Async execution.** (2026-08-28) Floor raised to Neovim 0.10.
      `runner.run` / `runner.json_async` wrap `vim.system()`; used for the
      org-list picker, `sf config set`, and `sf org open`. Terminal splits
      kept for tests, deploys, scratch-org creation, `org list/display`,
      anonymous Apex — anywhere the user should watch the stream. Progress
      goes through `vim.notify` (`opts.progress`). Only remaining sync call
      is ripgrep in `quickfix.find_class_file`.

## Discoverability / API surface

- [x] **User commands.** (2026-08-28) `:Sf <group> <action>` with completion,
      driven by the `M.actions` table in `init.lua` (keymaps derive from the
      same table).
- [x] **`doc/sf-nvim.txt`.** (2026-08-28) `:help sf-nvim` with tags for
      every option, `:Sf` action, keymap, and public Lua function.
- [x] **LuaCATS annotations** — all public functions annotated (2026-08-28).

## Generalization (Resource Hero → any SFDX project)

- [x] **Reframe as general-purpose.** (2026-08-28) README rewritten with
      no Resource Hero references; documents config, commands, keymaps and
      workflow for any SFDX project. Code had no project-specific
      assumptions beyond standard SFDX conventions.
- [x] **Config validation / setup guidance.** (2026-08-28)
      `utils/guard.lua`: `runner.term`/`run` refuse to launch a missing
      executable; tests/deploy/retrieve/validate/scratch-create require
      `sfdx-project.json` in cwd; missing ripgrep is reported once when
      loading results. Every message points at `:checkhealth sf-nvim`.

## Packaging / distribution polish

- [x] **`stylua.toml` + luacheck config** — added 2026-08-28 (`make fmt`,
      `make lint`); neither tool is installed locally yet, CI should run them.
- [x] **lazy.nvim spec convention** — README now uses `opts = {...}`
      (2026-08-28). packer/vim-plug examples still TODO if wanted.
- [x] **CONTRIBUTING.md** (2026-08-28) — ground rules, workflow, tests,
      style, bug-report checklist.
- [x] **Versioned releases / tags** (2026-08-28) — `v0.1.0` (last 0.7-floor
      commit) and `v0.2.0` (0.10 floor, async) tagged with GitHub releases.
      Process: move CHANGELOG *Unreleased* under a version heading, tag,
      `gh release create` with that section as notes.

## Notes

- 2026-08-28: `utils/runner.lua` rewritten as the single execution seam
  (`term` for interactive splits, `capture`/`json` for sync argv calls).
  Async work should plug in there, not at call sites. Fixed unescaped alias
  in scratch-org creation and `.gitignore` not matching `test-results/`.

- LICENSE (MIT) is already in good shape for open adoption — no action
  needed.
- `vim.notify` / `vim.ui.select` / `vim.ui.input` usage is already modern
  (no dependency on `nvim-notify` or similar, matches current Neovim
  conventions).
