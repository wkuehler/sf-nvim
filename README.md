# sf-nvim

My personal Salesforce development toolkit for Neovim, built for working on Resource Hero. It's not fancy, but it gets the job done.

## What This Does

This plugin wraps the Salesforce CLI (`sf`) with some Neovim conveniences:
- Run Apex tests and see failures in quickfix
- Deploy/retrieve metadata without leaving Neovim
- Manage orgs and scratch orgs
- Execute anonymous Apex

Everything runs in terminal splits at the bottom of the screen, so you can see what's actually happening. No magic, just CLI commands in Neovim.

## Requirements

- Neovim >= 0.7
- Salesforce CLI (`sf`) installed and configured
- `ripgrep` (for finding Apex class files)

## Installation

Using lazy.nvim with local development:

```lua
{
    'wkuehler/sf-nvim',
    config = function()
        require('sf-nvim').setup({
            enable_default_keybinds = true,
            leader_prefix = "<leader>s",
            test_results_dir = "test-results",
            test_wait_time = 15,  -- minutes
        })
    end
}
```

## Features

### Apex Testing
- Run tests for current class or all tests
- Results open in terminal at bottom, press ENTER to close
- Test failures automatically populate quickfix list
- Jump directly to failing lines with `:cn` and `:cp`
- Clear old test results with one command

### Org Management
- List and display org info in terminal
- Set target-org and target-dev-hub with interactive selection
- Create scratch orgs (picks config file, asks for days/alias)
- Open org in browser

### Project Deployment
- Deploy, retrieve, and validate in terminal splits
- See real-time output (no background magic)
- Press ENTER to close when done

### Anonymous Apex
- Execute current file as anonymous Apex
- Output shown in terminal

## Default Keybindings

With `enable_default_keybinds = true` and `leader_prefix = "<leader>s"`:

**Apex Testing:**
- `<leader>stc` - Run test for current class (validates .cls extension)
- `<leader>sta` - Run all Apex tests
- `<leader>stx` - Clear test results directory
- `<leader>stl` - Load latest test results into quickfix
- `<leader>se` - Execute current file as anonymous Apex

**Org Management:**
- `<leader>soo` - Open org in browser
- `<leader>sol` - List all orgs
- `<leader>soi` - Display org info
- `<leader>soc` - Create scratch org (interactive)

**Config/Set Defaults:**
- `<leader>sco` - Set target-org (with selection menu)
- `<leader>sch` - Set target-dev-hub (with selection menu)

**Project Deployment:**
- `<leader>spd` - Deploy project
- `<leader>spr` - Retrieve from org
- `<leader>spv` - Validate deployment (dry-run)

## How I Use This

### Running Tests
1. Open a test class
2. `<leader>stc` to run tests for current class
3. Tests run in terminal at bottom, watch the output
4. Press ENTER when done
5. Quickfix opens with failures (if any)
6. `:cn` to jump through failures

### Creating Scratch Orgs
1. `<leader>soc`
2. Pick config file from menu
3. Enter duration in days (default 7)
4. Enter alias
5. Watch it create in terminal

### Deploying
1. `<leader>spv` to validate (dry-run)
2. Check output in terminal
3. Press ENTER to close
4. `<leader>spd` to actually deploy
5. Watch it deploy in terminal

### Switching Orgs
1. `<leader>sco` to set target-org
2. Pick from list of orgs
3. See confirmation message

## Security Note

I added some basic sanitization to prevent shell injection when parsing test results. It's not bulletproof, but it's good enough for my use case. Don't use this in untrusted environments.

## Known Limitations

- No async/background execution - everything blocks until complete
- Test results parsing assumes SF CLI JSON format (will gracefully fail if format changes)
- Class file finding uses ripgrep with glob patterns (requires standard project structure)
- No fancy UI - just terminal splits and plain notifications

## Why This Exists

I got tired of switching between Neovim and terminal to run SF CLI commands. This just wraps the CLI so I can stay in my editor. It's opinionated for my Resource Hero development workflow, not a comprehensive SF tool.

## License

MIT - do whatever you want with it.
