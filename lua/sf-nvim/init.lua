-- init.lua
-- sf-nvim: Salesforce development utilities for Neovim

local M = {}

M.quickfix = require("sf-nvim.quickfix")
M.apex = require("sf-nvim.apex")
M.org = require("sf-nvim.org")
M.project = require("sf-nvim.project")
M.setconfig = require("sf-nvim.set-config")
M.logs = require("sf-nvim.logs")
M.soql = require("sf-nvim.soql")

---@class SfConfig
---@field test_results_dir string       directory for test result JSON, relative to cwd
---@field auto_open_quickfix boolean    open quickfix after loading test results
---@field test_wait_time integer        minutes to wait for `sf apex run test`
---@field enable_default_keybinds boolean
---@field leader_prefix string          prefix for default keybinds
---@field deploy_on_save boolean        deploy a source file to the target org on :write

---@type SfConfig
local default_config = {
	test_results_dir = "test-results",
	auto_open_quickfix = true,
	test_wait_time = 15,
	enable_default_keybinds = false,
	leader_prefix = "<leader>s",
	deploy_on_save = false,
}

---@type SfConfig
M.config = vim.deepcopy(default_config)

-- -------------------------------------------------------------
-- Action table: single source of truth for :Sf subcommands and keymaps
-- -------------------------------------------------------------
---@class SfAction
---@field fn fun(range?: {integer, integer})  range is passed when :Sf is given one
---@field desc string
---@field key string   suffix appended to leader_prefix
---@field mode? string keymap mode (default "n"; "x" for visual)

---@type table<string, table<string, SfAction>>
M.actions = {
	test = {
		current = {
			key = "tc",
			desc = "Run tests for current class",
			fn = function()
				M.apex.run_test()
			end,
		},
		all = {
			key = "ta",
			desc = "Run all Apex tests",
			fn = function()
				M.apex.run_all_tests()
			end,
		},
		clear = {
			key = "tx",
			desc = "Clear test results directory",
			fn = function()
				M.apex.clear_test_results()
			end,
		},
		method = {
			key = "tm",
			desc = "Run the test method under the cursor",
			fn = function()
				M.apex.run_test_method()
			end,
		},
		load = {
			key = "tl",
			desc = "Load latest test results into quickfix",
			fn = function()
				M.quickfix.load_and_open(M.config.test_results_dir)
			end,
		},
	},
	apex = {
		execute = {
			key = "e",
			desc = "Execute current file as anonymous Apex",
			fn = function()
				M.apex.execute_script()
			end,
		},
		selection = {
			key = "e",
			mode = "x",
			desc = "Execute selection as anonymous Apex",
			fn = function(range)
				M.apex.execute_selection(range)
			end,
		},
		debug = {
			key = "d",
			desc = "Run current file as anonymous Apex and show the log",
			fn = function()
				M.logs.debug()
			end,
		},
		debugselection = {
			key = "d",
			mode = "x",
			desc = "Run selection as anonymous Apex and show the log",
			fn = function(range)
				M.logs.debug_selection(range)
			end,
		},
	},
	log = {
		list = {
			key = "ll",
			desc = "Pick a debug log and open it",
			fn = function()
				M.logs.list()
			end,
		},
		latest = {
			key = "lr",
			desc = "Open the most recent debug log",
			fn = function()
				M.logs.latest()
			end,
		},
		tail = {
			key = "lt",
			desc = "Tail debug logs live (creates a trace flag)",
			fn = function()
				M.logs.tail()
			end,
		},
	},
	soql = {
		buffer = {
			key = "qb",
			desc = "Run buffer as SOQL",
			fn = function()
				M.soql.query_buffer()
			end,
		},
		selection = {
			key = "q",
			mode = "x",
			desc = "Run selection as SOQL",
			fn = function(range)
				M.soql.query_selection(range)
			end,
		},
		prompt = {
			key = "qq",
			desc = "Prompt for a SOQL query",
			fn = function()
				M.soql.query_prompt()
			end,
		},
	},
	org = {
		open = {
			key = "oo",
			desc = "Open org in browser",
			fn = function()
				M.org.open()
			end,
		},
		list = {
			key = "ol",
			desc = "List orgs",
			fn = function()
				M.org.list()
			end,
		},
		info = {
			key = "oi",
			desc = "Display org info",
			fn = function()
				M.org.display()
			end,
		},
		create = {
			key = "oc",
			desc = "Create scratch org",
			fn = function()
				M.org.create_scratch_org()
			end,
		},
	},
	config = {
		org = {
			key = "co",
			desc = "Set target-org",
			fn = function()
				M.setconfig.set_target_org()
			end,
		},
		hub = {
			key = "ch",
			desc = "Set target-dev-hub",
			fn = function()
				M.setconfig.set_target_dev_hub()
			end,
		},
	},
	project = {
		deploy = {
			key = "pd",
			desc = "Deploy project",
			fn = function()
				M.project.deploy()
			end,
		},
		retrieve = {
			key = "pr",
			desc = "Retrieve from org",
			fn = function()
				M.project.retrieve()
			end,
		},
		validate = {
			key = "pv",
			desc = "Validate deployment (dry run)",
			fn = function()
				M.project.validate()
			end,
		},
		file = {
			key = "pf",
			desc = "Deploy current file",
			fn = function()
				M.project.deploy_file()
			end,
		},
		fetch = {
			key = "pF",
			desc = "Retrieve current file",
			fn = function()
				M.project.retrieve_file()
			end,
		},
	},
}

local function sorted_keys(t)
	local keys = vim.tbl_keys(t)
	table.sort(keys)
	return keys
end

-- -------------------------------------------------------------
-- :Sf <group> <action>
-- -------------------------------------------------------------
local function sf_command(opts)
	local group, action = opts.fargs[1], opts.fargs[2]
	local g = group and M.actions[group]
	if not g then
		vim.notify(
			"Sf: unknown group '" .. tostring(group) .. "'. Groups: " .. table.concat(sorted_keys(M.actions), ", "),
			vim.log.levels.ERROR
		)
		return
	end
	local a = action and g[action]
	if not a then
		vim.notify(
			string.format(
				"Sf %s: unknown action '%s'. Actions: %s",
				group,
				tostring(action),
				table.concat(sorted_keys(g), ", ")
			),
			vim.log.levels.ERROR
		)
		return
	end
	if opts.range and opts.range > 0 then
		a.fn({ opts.line1, opts.line2 })
	else
		a.fn()
	end
end

local function sf_complete(arglead, cmdline, _)
	local words = vim.split(cmdline, "%s+", { trimempty = true })
	local trailing = cmdline:sub(-1) == " "
	local candidates = {}
	-- words[1] is "Sf"
	if #words == 1 or (#words == 2 and not trailing) then
		candidates = sorted_keys(M.actions)
	else
		local g = M.actions[words[2]]
		if g and (#words == 2 or (#words == 3 and not trailing)) then
			candidates = sorted_keys(g)
		end
	end
	return vim.tbl_filter(function(c)
		return c:sub(1, #arglead) == arglead
	end, candidates)
end

local function setup_commands()
	vim.api.nvim_create_user_command("Sf", sf_command, {
		nargs = "+",
		range = true,
		complete = sf_complete,
		desc = "Salesforce CLI actions (:Sf <group> <action>)",
	})
end

-- -------------------------------------------------------------
-- Default keybindings
-- -------------------------------------------------------------
local function setup_keybinds()
	local prefix = M.config.leader_prefix
	for _, group in pairs(M.actions) do
		for _, action in pairs(group) do
			vim.keymap.set(action.mode or "n", prefix .. action.key, function()
				action.fn()
			end, { desc = "Sf: " .. action.desc })
		end
	end
end

-- -------------------------------------------------------------
-- Setup
-- -------------------------------------------------------------
---@param opts? SfConfig
function M.setup(opts)
	if vim.fn.has("nvim-0.10") == 0 then
		vim.notify("sf-nvim requires Neovim 0.10 or later (vim.system)", vim.log.levels.ERROR)
		return
	end
	M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})

	M.apex.config.test_results_dir = M.config.test_results_dir
	M.apex.config.test_wait_time = M.config.test_wait_time
	M.apex.config.auto_open_quickfix = M.config.auto_open_quickfix

	setup_commands()
	if M.config.enable_default_keybinds then
		setup_keybinds()
	end
	M.project.set_deploy_on_save(M.config.deploy_on_save)
end

return M
