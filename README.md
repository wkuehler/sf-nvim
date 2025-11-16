# sf-nvim

A comprehensive Salesforce development toolkit for Neovim, providing seamless integration with the Salesforce CLI and enhanced developer productivity features.

## Features

### Apex Testing
- **Run Tests**: Execute Apex tests for current class or all tests with visual feedback
- **Quickfix Integration**: Automatically parse test results and load failures into Neovim's quickfix list
- **Smart Navigation**: Jump directly to failing test lines with file/line/column accuracy
- **Automatic File Discovery**: Finds the most recent test results file in a directory
- **Smart Class File Resolution**: Uses `ripgrep` to locate Apex class files anywhere in your project

### Apex Development
- **Anonymous Execution**: Run Apex scripts directly from Neovim with output logging
- **Test Result Parsing**: Parse JSON test results and populate quickfix with failures only

### Org Management
- **Org Operations**: Open, list, and display org information
- **Quick Access**: Fast org switching and browser launching

### Project Deployment
- **Deploy/Retrieve**: Deploy and retrieve metadata with progress notifications
- **Validation**: Validate deployments before pushing to production
- **Quick Deploy**: Fast deployment of previously validated changesets

## Requirements

- Neovim >= 0.7
- Salesforce CLI (`sf`) installed and configured
- `ripgrep` (for finding Apex class files)
- `find` command (standard on Linux/macOS)
- [nvim-notify](https://github.com/rcarriga/nvim-notify) (for visual feedback and spinners)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'wkuehler/sf-nvim',
    dependencies = {
        'rcarriga/nvim-notify',  -- Required for notifications
    },
    config = function()
        require('sf-nvim').setup({
            -- Optional: enable default keybindings
            enable_default_keybinds = true,
            leader_prefix = "<leader>s",

            -- Test configuration
            test_results_dir = "test-results",
            test_wait_time = 15,  -- minutes
        })
    end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'wkuehler/sf-nvim',
    requires = { 'rcarriga/nvim-notify' },
    config = function()
        require('sf-nvim').setup()
    end
}
```

## Configuration

```lua
require('sf-nvim').setup({
    -- Directory where test results are stored (relative to project root)
    test_results_dir = "test-results",

    -- Automatically open quickfix window when loading test results
    auto_open_quickfix = true,

    -- Test wait time in minutes
    test_wait_time = 15,

    -- Enable default keybindings (see Keybindings section)
    enable_default_keybinds = false,

    -- Key prefix for Salesforce commands (if using default keybinds)
    leader_prefix = "<leader>s",
})
```

## Usage

### API Functions

#### Apex Testing
```lua
local sf = require('sf-nvim')

-- Run test for current class (opens quickfix with results)
sf.apex.run_test()

-- Run all Apex tests (opens quickfix with results)
sf.apex.run_all_tests()

-- Execute anonymous Apex script from current file
sf.apex.execute_script()
```

#### Test Results / Quickfix
```lua
-- Load test results from a specific file
sf.quickfix.load_from_file('/path/to/test-results.json')

-- Load the most recent test results from a directory
sf.quickfix.load_latest('test-results')

-- Load latest results and open the quickfix window
sf.quickfix.load_and_open('test-results')
```

#### Org Management
```lua
-- Open default org in browser
sf.org.open()

-- List all orgs
sf.org.list()

-- Display org information
sf.org.display()

-- Login to org
sf.org.login_web()

-- Logout from org
sf.org.logout()
```

#### Project Deployment
```lua
-- Deploy project to org
sf.project.deploy()

-- Retrieve metadata from org
sf.project.retrieve()

-- Validate deployment (dry-run)
sf.project.validate()

-- Quick deploy a previously validated deployment
sf.project.quick_deploy("job_id")
```

### Keybindings

#### Option 1: Use Default Keybindings

Enable in setup:
```lua
require('sf-nvim').setup({
    enable_default_keybinds = true,
    leader_prefix = "<leader>s",  -- customize prefix
})
```

Default keybindings (with `<leader>s` prefix):
- `<leader>stc` - Run test for current class
- `<leader>sta` - Run all tests
- `<leader>se` - Execute Apex script
- `<leader>stl` - Load latest test results
- `<leader>so` - Open org in browser
- `<leader>sl` - List orgs
- `<leader>si` - Display org info
- `<leader>sd` - Deploy project
- `<leader>sr` - Retrieve from org
- `<leader>sv` - Validate deployment

#### Option 2: Custom Keybindings

Add your own keybindings:

```lua
local sf = require('sf-nvim')

-- Apex testing
vim.keymap.set('n', '<leader>stc', sf.apex.run_test, { desc = 'Run Apex test for current class' })
vim.keymap.set('n', '<leader>sta', sf.apex.run_all_tests, { desc = 'Run all Apex tests' })
vim.keymap.set('n', '<leader>se', sf.apex.execute_script, { desc = 'Execute Apex script' })

-- Test results
vim.keymap.set('n', '<leader>tl', function()
    sf.quickfix.load_and_open('test-results')
end, { desc = 'Load latest test results' })

-- Org management
vim.keymap.set('n', '<leader>so', sf.org.open, { desc = 'Open org in browser' })
vim.keymap.set('n', '<leader>sl', sf.org.list, { desc = 'List orgs' })

-- Project deployment
vim.keymap.set('n', '<leader>sd', sf.project.deploy, { desc = 'Deploy project' })
vim.keymap.set('n', '<leader>sr', sf.project.retrieve, { desc = 'Retrieve from org' })
```

### Workflows

#### Running Tests

**Method 1: From Neovim (Recommended)**
1. Open an Apex test class in Neovim
2. Press `<leader>stc` to run tests for current class (or `<leader>sta` for all tests)
3. Wait for the notification spinner to complete
4. Quickfix window opens automatically with any failures
5. Navigate through failures using quickfix commands

**Method 2: Manual CLI + Load Results**
1. Run tests manually: `sf apex run test --result-format json > test-results/mytest.json`
2. In Neovim, press `<leader>tl` to load latest results into quickfix
3. Navigate through failures

#### Quickfix Navigation

Standard Neovim quickfix commands:
- `:cn` or `<C-M-j>` - Next failure
- `:cp` or `<C-M-k>` - Previous failure
- `:cc` - Jump to current failure
- `:copen` - Open quickfix window
- `:cclose` - Close quickfix window

#### Deployment Workflow

1. Make changes to your Salesforce metadata
2. Press `<leader>sv` to validate deployment (dry-run)
3. Review notification for validation results
4. If validation passes, press `<leader>sd` to deploy
5. Watch the spinner notification for deployment status

## How It Works

### Test Execution
1. Plugin runs `sf apex run test` with JSON output format
2. Results are saved to timestamped files in the `test-results` directory
3. Notification spinner shows progress during test execution
4. On completion, results are automatically parsed and loaded into quickfix

### Quickfix Population
1. Scans for JSON test result files in the specified directory
2. Parses the Salesforce test results JSON format
3. For each failed test, uses `ripgrep` to locate the Apex class file
4. Builds quickfix entries with file path, line number, column, and error message
5. Populates Neovim's quickfix list with the failures
6. Tests where the class file cannot be found are logged but not added to quickfix

### Notifications
- Uses `nvim-notify` for visual feedback
- Animated spinner during command execution
- Success/error notifications on completion
- Non-blocking async execution for all CLI commands

## Example Output

### Quickfix Parsing
```
=== Quickfix Parsing Results ===
File: test-results/MyTestClass_20251115143022.json
Successfully parsed 2 failure(s)

1. force-app/main/default/classes/MyTestClass.cls:15:1 - testExample: System.AssertException: Assertion Failed
2. force-app/main/default/classes/MyTestClass.cls:23:5 - testAnotherMethod: System.NullPointerException

--- Skipped (class file not found) ---
1. NonExistentClass.testMethod - Test failed

=================================
```

### Notification Examples
- ⏳ "Running MyTestClass..." (with spinner)
- ✓ "Tests passed. Results saved to test-results/MyTestClass_20251115143022.json"
- ✗ "Tests failed. Review test-results/MyTestClass_20251115143022.json"
- ⏳ "Deploying..." (with spinner)
- ✓ "Deployment succeeded"

## Contributing

Contributions welcome! Feel free to open issues or submit pull requests.

## License

MIT

## Roadmap

Future features planned:
- ✅ Run tests directly from Neovim
- ✅ Org management utilities
- ✅ Deploy/retrieve integration
- Test coverage integration and visualization
- SOQL query execution and result display
- Metadata search and navigation
- Debug log viewing and filtering
- Scratch org creation and management
- Package development support
- Conflict resolution helpers
