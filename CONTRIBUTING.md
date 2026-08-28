# Contributing

Thanks for helping make sf-nvim better for Salesforce developers on Neovim.

## Ground rules

- **Neovim 0.10+** is the floor. It is enforced in `setup()`, `health.lua`, the
  README, `doc/sf-nvim.txt`, and the CI matrix — if you change it, change all five.
- **No UI dependencies.** Feedback goes through `vim.notify`, `vim.ui.select`,
  `vim.ui.input`. Don't add nvim-notify, telescope, etc. as requirements.
- **Never hand-build shell strings.** Pass argv lists to `runner.term` /
  `runner.run` / `runner.json_async`; use `runner.shell_join` only when shell
  syntax is genuinely needed (and say why in a comment).
- **Terminal split vs. background:** `runner.term` when the user should watch the
  output (tests, deploys); `runner.run` when the plugin consumes it.
- **One table drives commands and keymaps.** Add features as entries in
  `M.actions` in `lua/sf-nvim/init.lua`; don't register `:Sf` subcommands or
  keymaps anywhere else.

## Workflow

1. Fork and branch from `main`.
2. Make the change, with tests where behavior changes (see below).
3. `make fmt` (stylua), `make lint` (luacheck), `make test` — CI runs the same
   three on push and PR, against Neovim 0.10.0, stable, and nightly.
4. If you add or change a user-facing option, command, or keymap, update all of:
   README, `doc/sf-nvim.txt`, and (for options) the `SfConfig` annotation.
5. Add a line to `CHANGELOG.md` under *Unreleased*.
6. Open a PR. Describe what changed and how you tested it against a real
   SFDX project — CI can't run the `sf` CLI.

## Tests

Busted-style plenary specs in `tests/*_spec.lua`, bootstrapped by
`tests/minimal_init.lua` (looks for plenary.nvim under lazy.nvim's data dir, or
`$PLENARY_DIR`).

```sh
make test
make test-file FILE=tests/quickfix_spec.lua
```

- Fixtures in `tests/fixtures/` are hand-built copies of `sf ... --json`
  output. If the CLI's shape changes, update the fixture *and* the parser
  together.
- Anything that shells out to `sf` should be tested by stubbing the runner
  (see `set_config_spec.lua`) — never by calling the real CLI.
- `runner_spec.lua` uses `sh` for real subprocess behavior.

## Style

tabs, 120 columns, double quotes — all in `stylua.toml`; `.luacheckrc` for
lint. Public functions carry LuaCATS annotations (`---@param`, `---@return`).

## Reporting bugs

Include the output of `:checkhealth sf-nvim`, your Neovim version, the `sf`
CLI version, and the exact `:Sf` command or keymap you ran.
