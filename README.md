# sf-nvim

Salesforce CLI (`sf`) integration for Neovim. Run Apex tests with failures in
quickfix, deploy and retrieve metadata, manage orgs and scratch orgs, and execute
anonymous Apex — without leaving the editor.

Long-running commands (tests, deploys, scratch org creation) run in a terminal
split at the bottom of the screen, so you see exactly what the CLI is doing.
The split opens in Normal mode following the output, so you can scroll back
with the usual keys at any time; when the command finishes, `Enter` or `q`
closes it.
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
    tail_notify = true,                  -- notify on each debug log captured by :Sf log tail
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
| `:Sf apex debug` | Run the current file as anonymous Apex in the background and open its debug log |
| `:'<,'>Sf apex debugselection` | Same, for the selected lines |
| `:Sf log list` | Pick a stored debug log and open it |
| `:Sf log latest` | Open the most recent debug log |
| `:Sf log tail` | Toggle a background tail of debug logs; creates a trace flag for your user if needed |
| `:Sf log show` | Open the captured logs (`sf://log/tail`) in a split |
| `:Sf soql buffer` | Run the buffer as a SOQL query; results as a table |
| `:'<,'>Sf soql selection` | Run the selected lines as a SOQL query |
| `:Sf soql prompt` | Prompt for a query and run it |
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
| `<leader>sd`  | `:Sf apex debug` (normal) / `:Sf apex debugselection` (visual) |
| `<leader>sll` | `:Sf log list` |
| `<leader>slr` | `:Sf log latest` |
| `<leader>slt` | `:Sf log tail` |
| `<leader>sls` | `:Sf log show` |
| `<leader>sqb` | `:Sf soql buffer` |
| `<leader>sqq` | `:Sf soql prompt` |
| `<leader>sq`  | `:Sf soql selection` (visual) |
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
split; press `Enter` or `q` when it finishes. Failures (including compile
failures) are loaded into quickfix with file, line, column and message — `:cn` /
`:cp` to jump between them. Results are also saved as JSON under
`test_results_dir`, so `:Sf test load` can reload the latest run later.

**Deploy.** `:Sf project validate` for a dry run, check the output, then
`:Sf project deploy`. If either fails, the failed components are loaded into
quickfix from `sf project deploy report`.

**Anonymous Apex.** `:Sf apex execute` runs the whole file in a terminal split;
select some lines and `:'<,'>Sf apex selection` (or `<leader>se` in visual mode)
runs just those. `:Sf apex debug` runs in the background instead and opens the
result in a `sf://apex-run` buffer: a one-line verdict (success, compile error
with line/column, or the runtime exception and stack) followed by the full
debug log with `apexlog` highlighting.

**Debug logs.** `:Sf log list` fetches the org's stored logs into a picker
(time, operation, status, size, duration, user) and opens the chosen one;
`:Sf log latest` skips the picker. Logs open in read-only `sf://log/<id>`
buffers — `q` closes them. Stored logs only exist while a trace flag is active
for your user; `:Sf log tail` creates one, after which `list`/`latest` start
returning logs.

**Tailing.** `:Sf log tail` toggles `sf apex tail log` running in the
background — no split is opened. Each captured log bumps a counter (and, with
`tail_notify`, a short notification); `:Sf log show` opens the accumulated
output in a split whenever you want to look, and `q` closes it while the tail
keeps running. The buffer keeps the last 5000 lines. If the CLI exits on its
own (expired token, org switch) you get an error notification rather than a
silent stop; the process is killed when Neovim exits.

**Statusline.** `require("sf-nvim").status()` returns the target org and, while
tailing, `⏺ N` (logs captured) — e.g. `dev ⏺ 3`. It's refreshed on `setup()`
and after `:Sf config org`. lualine example:

```lua
sections = { lualine_x = { function() return require("sf-nvim").status() end } },
```

The `User SfTargetChanged` and `User SfTailChanged` autocommand events fire
when either part changes, if your statusline needs a redraw trigger.

**SOQL.** Write a query in a `.soql` buffer (or anywhere) and run
`:Sf soql buffer`, or select the lines and `:'<,'>Sf soql selection`, or
`:Sf soql prompt` for a one-off. `//` and `--` comment lines are dropped.
Results render as an aligned table in `sf://query`, columns in the order you
selected them; relationship fields flatten to `Owner.Name`, subqueries show as
`[N rows]`. Query errors show the CLI's message with its caret in the same
buffer.

**Filetypes.** The plugin registers `soql`, `apex` (`.apex`, plus `.cls` and
`.trigger` inside an SFDX project), and `apexlog`, and ships syntax
highlighting for `apexlog`. Bring your own `apex`/`soql` syntax or Tree-sitter
grammars.

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
