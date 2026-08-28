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

- [ ] **Async execution.** Everything currently blocks in a terminal split
      until the command finishes (README calls this out as a known
      limitation). Consider `vim.system()` (Neovim ≥0.10) for jobs where the
      user doesn't need to babysit output live, reserving terminal splits
      for cases where watching output matters (e.g. long deploys).
      Trade-off: terminal splits are simple and transparent ("no magic");
      async needs a real progress/notification story to not feel worse.

## Discoverability / API surface

- [x] **User commands.** (2026-08-28) `:Sf <group> <action>` with completion,
      driven by the `M.actions` table in `init.lua` (keymaps derive from the
      same table).
- [ ] **`doc/sf-nvim.txt`.** No `:help sf-nvim`. Currently the only
      reference is the README and source. A real help file with tags is
      the standard expectation for any distributed Neovim plugin.
- [~] **LuaCATS annotations** — `SfConfig`, `SfAction`, runner, quickfix and
      set-config public functions are annotated (2026-08-28). Remaining:
      apex/org/project module functions.

## Generalization (Resource Hero → any SFDX project)

- [ ] **Reframe as general-purpose.** README and code comments currently
      describe this as "my personal toolkit... built for working on
      Resource Hero" / "opinionated for my Resource Hero development
      workflow." The actual logic (scratch org config glob under
      `config/**/*-scratch-def.json`, standard `force-app` layout
      assumptions) is already mostly generic SFDX convention — the
      remaining work is largely framing (README, package description),
      not a rewrite. Audit for any remaining assumptions specific to your
      project layout.
- [ ] **Config validation / setup guidance.** If `sf` CLI or `ripgrep`
      aren't installed, or the project isn't a recognized SFDX layout, fail
      with a clear, actionable message rather than a generic error deep in
      a call chain. `:checkhealth` now covers the diagnosis side; this item
      is about runtime guards at the call sites.

## Packaging / distribution polish

- [x] **`stylua.toml` + luacheck config** — added 2026-08-28 (`make fmt`,
      `make lint`); neither tool is installed locally yet, CI should run them.
- [x] **lazy.nvim spec convention** — README now uses `opts = {...}`
      (2026-08-28). packer/vim-plug examples still TODO if wanted.
- [ ] **CONTRIBUTING.md** — if this is meant to become a community
      standard, contributors need a stated process (style, test
      requirements, PR expectations).
- [ ] **Versioned releases / tags** — semantic versioning + GitHub releases
      so lazy.nvim users can pin versions instead of tracking `main`.

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
