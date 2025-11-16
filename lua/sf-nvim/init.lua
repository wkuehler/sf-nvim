-- init.lua
-- sf-nvim: Salesforce development utilities for Neovim

local M = {}

-- Load submodules
M.quickfix = require("sf-nvim.quickfix")
M.apex = require("sf-nvim.apex")
M.org = require("sf-nvim.org")
M.project = require("sf-nvim.project")
M.setconfig = require("sf-nvim.set-config")

-- Default configuration
local default_config = {
	-- Directory where test results are stored (relative to project root)
	test_results_dir = "test-results",
	-- Automatically open quickfix window when loading test results
	auto_open_quickfix = true,
	-- Test wait time in minutes
	test_wait_time = 15,
	-- Enable default keybindings
	enable_default_keybinds = false,
	-- Key prefix for Salesforce commands (if using default keybinds)
	leader_prefix = "<leader>s",
}

-- Plugin configuration
M.config = {}

-- -------------------------------------------------------------
-- Setup default keybindings
-- -------------------------------------------------------------
local function setup_keybinds()
	local prefix = M.config.leader_prefix

	-- Apex test keybinds
	vim.keymap.set("n", prefix .. "tc", M.apex.run_test, { desc = "Tests - Current" })
	vim.keymap.set("n", prefix .. "ta", M.apex.run_all_tests, { desc = "Tests - All" })
	vim.keymap.set("n", prefix .. "tx", M.apex.clear_test_results, { desc = "Tests - Clear results directory" })
	vim.keymap.set("n", prefix .. "e", M.apex.execute_script, { desc = "Execute current class" })

	-- Quickfix keybinds
	vim.keymap.set("n", prefix .. "tl", function()
		M.quickfix.load_and_open(M.config.test_results_dir)
	end, { desc = "Load latest test results" })

	-- Org keybinds
	vim.keymap.set("n", prefix .. "oo", M.org.open, { desc = "Open" })
	vim.keymap.set("n", prefix .. "ol", M.org.list, { desc = "List" })
	vim.keymap.set("n", prefix .. "oi", M.org.display, { desc = "Info" })
	vim.keymap.set("n", prefix .. "oc", M.org.create_scratch_org, { desc = "Create scratch org" })

	-- Project keybinds
	vim.keymap.set("n", prefix .. "pd", M.project.deploy, { desc = "Deploy" })
	vim.keymap.set("n", prefix .. "pr", M.project.retrieve, { desc = "Retrieve" })
	vim.keymap.set("n", prefix .. "pv", M.project.validate, { desc = "Validate" })

	-- Set Config keybinds
	vim.keymap.set("n", prefix .. "co", M.setconfig.set_target_org, { desc = "Set target-org" })
	vim.keymap.set("n", prefix .. "ch", M.setconfig.set_target_dev_hub, { desc = "Set target-dev-hub" })
end

-- -------------------------------------------------------------
-- Setup function to configure the plugin
-- -------------------------------------------------------------
function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", default_config, opts)

	-- Pass config to submodules
	M.apex.config.test_results_dir = M.config.test_results_dir
	M.apex.config.test_wait_time = M.config.test_wait_time

	-- Setup keybinds if enabled
	if M.config.enable_default_keybinds then
		setup_keybinds()
	end
end

return M
