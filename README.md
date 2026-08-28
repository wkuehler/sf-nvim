# sf-nvim

Salesforce CLI (`sf`) integration for Neovim. Run Apex tests with failures in
quickfix, deploy and retrieve metadata, manage orgs and scratch orgs, and execute
anonymous Apex — without leaving the editor.

Long-running commands (tests, deploys, scratch org creation) run in a terminal
split at the bottom of the screen, so you see exactly what the CLI is doing.
Quick lookups (listing orgs for a picker, setting the target org, opening an org)
run in the background without blocking the editor. No custom UI: feedback and
pickers go through `vim.notify` / `vim.ui.select`, so it works with whatever UI
plugins you already have, or none.

## Requirements

- Neovim >= 0.10
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) installed and authenticated
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) — used to locate Apex class files for quickfix
- An SFDX project: open Neovim from the directory containing `sfdx-project.json`
  (the plugin uses the current working directory as the project root)

Run `:checkhealth sf-nvim` to verify all of the above.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "wkuehler/sf-nvim",
    version = "*",  -- latest tagged release; drop to track main
    opts = {
        enable_default_keybinds = true,
    },
}
```

Any plugin manager works — just call `require("sf-nvim").setup({ ... })` once.

## Configuration

Defaults:

```lua
require("sf-nvim").setup({
    test_results_dir = "test-results",   -- where test JSON is saved, relative to cwd
    auto_open_quickfix = true,           -- open quickfix when a test run has failures
    test_wait_time = 15,                 -- minutes passed to `sf apex run test -w`
    enable_default_keybinds = false,     -- install the keymaps listed below
    leader_prefix = "<leader>s",         -- prefix for those keymaps
    deploy_on_save = false,              -- deploy a source file to the target org on :w
})
```

Add `test-results/` (or whatever you set) to your `.gitignore`.

## Commands

Everything is available as `:Sf <group> <action>` with tab completion:

| Command | What it does |
|---|---|
| `:Sf test current` | Run tests for the current `.cls`; failures go to quickfix |
| `:Sf test method` | Run only the `@IsTest` method under the cursor |
| `:Sf test all` | Run the whole Apex test suite |
| `:Sf test load` | Load the most recent saved results into quickfix |
| `:Sf test clear` | Delete saved test results (asks first) |
| `:Sf apex execute` | Run the current file as anonymous Apex |
| `:'<,'>Sf apex selection` | Run the selected lines as anonymous Apex |
| `:Sf org open` | Open the target org in a browser |
| `:Sf org list` | `sf org list` |
| `:Sf org info` | `sf org display` |
| `:Sf org create` | Create a scratch org: pick a `*-scratch-def.json`, enter days and alias |
| `:Sf config org` | Set `target-org` from a picker of authenticated orgs |
| `:Sf config hub` | Set `target-dev-hub` from a picker of Dev Hubs |
| `:Sf project file` | Deploy the current file (or its LWC/Aura bundle); errors go to quickfix |
| `:Sf project fetch` | Retrieve the current file (or bundle) from the org |
| `:Sf project deploy` | `sf project deploy start`; on failure, errors go to quickfix |
| `:Sf project retrieve` | `sf project retrieve start` |
| `:Sf project validate` | `sf project deploy start --dry-run` |

Full reference: `:help sf-nvim`.

## Default keybindings

With `enable_default_keybinds = true` and the default `leader_prefix = "<leader>s"`:

| Key | Command |
|---|---|
| `<leader>stc` | `:Sf test current` |
| `<leader>stm` | `:Sf test method` |
| `<leader>sta` | `:Sf test all` |
| `<leader>stl` | `:Sf test load` |
| `<leader>stx` | `:Sf test clear` |
| `<leader>se`  | `:Sf apex execute` (normal) / `:Sf apex selection` (visual) |
| `<leader>soo` | `:Sf org open` |
| `<leader>sol` | `:Sf org list` |
| `<leader>soi` | `:Sf org info` |
| `<leader>soc` | `:Sf org create` |
| `<leader>sco` | `:Sf config org` |
| `<leader>sch` | `:Sf config hub` |
| `<leader>spf` | `:Sf project file` |
| `<leader>spF` | `:Sf project fetch` |
| `<leader>spd` | `:Sf project deploy` |
| `<leader>spr` | `:Sf project retrieve` |
| `<leader>spv` | `:Sf project validate` |

To define your own instead, leave `enable_default_keybinds` off and map to the
`:Sf` commands (or to the functions in `require("sf-nvim").actions`).

## Workflow

**Edit → deploy.** `:Sf project file` pushes just the file you're in (for LWC
and Aura, the whole bundle) in the background and reports the result. Compile
errors land in quickfix with line and column. Set `deploy_on_save = true` to do
this automatically on every `:w` of a file under a package directory.

**Tests.** Open a test class and run `:Sf test current`, or put the cursor in
one `@IsTest` method and run `:Sf test method`. The run streams in a terminal
split; press ENTER when it finishes. Failures (including compile
failures) are loaded into quickfix with file, line, column and message — `:cn` /
`:cp` to jump between them. Results are also saved as JSON under
`test_results_dir`, so `:Sf test load` can reload the latest run later.

**Deploy.** `:Sf project validate` for a dry run, check the output, then
`:Sf project deploy`. If either fails, the failed components are loaded into
quickfix from `sf project deploy report`.

**Anonymous Apex.** `:Sf apex execute` runs the whole file; select some lines
and `:'<,'>Sf apex selection` (or `<leader>se` in visual mode) runs just those.

**Scratch orgs.** `:Sf org create` finds every `config/**/*-scratch-def.json`
in the project and prompts for duration and alias. `:Sf config org` switches
the target org from a picker afterwards.

## Known limitations

- Long-running commands (tests, deploys, scratch org creation) run in a terminal
  split by design so you can watch them; only quick lookups run in the background.
- Quickfix parsing depends on the `sf apex run test --json` output shape.
- Class file lookup assumes the standard `<Name>.cls` file naming.

## Development

```sh
make test                                    # plenary.nvim test suite
make test-file FILE=tests/quickfix_spec.lua  # one spec
make lint / make fmt                         # luacheck / stylua
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
