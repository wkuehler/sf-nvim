-- init.lua
-- sf-nvim: Salesforce development utilities for Neovim

local M = {}

M.quickfix = require("sf-nvim.quickfix")
M.apex = require("sf-nvim.apex")
M.org = require("sf-nvim.org")
M.project = require("sf-nvim.project")
M.setconfig = require("sf-nvim.set-config")
M.generate = require("sf-nvim.generate")
M.logs = require("sf-nvim.logs")
M.soql = require("sf-nvim.soql")

---@class SfConfig
---@field test_results_dir string       directory for test result JSON, relative to cwd
---@field auto_open_quickfix boolean    open quickfix after loading test results
---@field test_wait_time integer        minutes to wait for `sf apex run test`
---@field enable_default_keybinds boolean
---@field leader_prefix string          prefix for default keybinds
---@field deploy_on_save boolean        deploy a source file to the target org on :write
---@field tail_notify boolean           notify on each debug log captured by :Sf log tail

---@type SfConfig
local default_config = {
	test_results_dir = "test-results",
	auto_open_quickfix = true,
	test_wait_time = 15,
	enable_default_keybinds = false,
	leader_prefix = "<leader>s",
	deploy_on_save = false,
	tail_notify = true,
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
			desc = "Run tests in current Apex class",
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
		failed = {
			key = "tf",
			desc = "Rerun tests that failed last run",
			fn = function()
				M.apex.run_failed_tests()
			end,
		},
		clear = {
			key = "tx",
			desc = "Delete saved test result files",
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
			key = "ae",
			desc = "Execute current file as anonymous Apex",
			fn = function()
				M.apex.execute_script()
			end,
		},
		selection = {
			key = "ae",
			mode = "x",
			desc = "Execute selection as anonymous Apex",
			fn = function(range)
				M.apex.execute_selection(range)
			end,
		},
		debug = {
			key = "ad",
			desc = "Run current file as anonymous Apex and show the log",
			fn = function()
				M.logs.debug()
			end,
		},
		debugselection = {
			key = "ad",
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
			key = "lL",
			desc = "Open the most recent debug log",
			fn = function()
				M.logs.latest()
			end,
		},
		tail = {
			key = "lt",
			desc = "Toggle debug log tail (background)",
			fn = function()
				M.logs.tail()
			end,
		},
		show = {
			key = "ls",
			desc = "Open the tail buffer",
			fn = function()
				M.logs.show()
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
			desc = "Run a SOQL query from a prompt",
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
			desc = "List authenticated orgs",
			fn = function()
				M.org.list()
			end,
		},
		info = {
			key = "oi",
			desc = "Show target org details",
			fn = function()
				M.org.display()
			end,
		},
		create = {
			key = "oc",
			desc = "Create scratch org from a definition file",
			fn = function()
				M.org.create_scratch_org()
			end,
		},
		login = {
			key = "oa",
			desc = "Log in to an org (web flow)",
			fn = function()
				M.org.login()
			end,
		},
		delete = {
			key = "ox",
			desc = "Delete a scratch org (asks first)",
			fn = function()
				M.org.delete_scratch()
			end,
		},
		pick = {
			key = "oO",
			desc = "Pick an org and open it in browser",
			fn = function()
				M.org.open_pick()
			end,
		},
		limits = {
			key = "oL",
			desc = "Show target org limits",
			fn = function()
				M.org.limits()
			end,
		},
	},
	config = {
		org = {
			key = "co",
			desc = "Pick target org",
			fn = function()
				M.setconfig.set_target_org()
			end,
		},
		hub = {
			key = "ch",
			desc = "Pick Dev Hub org",
			fn = function()
				M.setconfig.set_target_dev_hub()
			end,
		},
	},
	project = {
		deploy = {
			key = "pd",
			desc = "Deploy whole project to org",
			fn = function()
				M.project.deploy()
			end,
		},
		retrieve = {
			key = "pr",
			desc = "Retrieve whole project from org",
			fn = function()
				M.project.retrieve()
			end,
		},
		validate = {
			key = "pv",
			desc = "Validate project deploy (no changes)",
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
		preview = {
			key = "pp",
			desc = "Preview what a deploy would change",
			fn = function()
				M.project.preview_deploy()
			end,
		},
		previewretrieve = {
			key = "pP",
			desc = "Preview what a retrieve would change",
			fn = function()
				M.project.preview_retrieve()
			end,
		},
	},
	generate = {
		class = {
			key = "gc",
			desc = "Generate Apex class",
			fn = function()
				M.generate.generate("class")
			end,
		},
		trigger = {
			key = "gt",
			desc = "Generate Apex trigger",
			fn = function()
				M.generate.generate("trigger")
			end,
		},
		lwc = {
			key = "gl",
			desc = "Generate Lightning web component",
			fn = function()
				M.generate.generate("lwc")
			end,
		},
		aura = {
			key = "ga",
			desc = "Generate Aura component",
			fn = function()
				M.generate.generate("aura")
			end,
		},
	},
}

-- -------------------------------------------------------------
-- Statusline provider
-- -------------------------------------------------------------
---Short status for a statusline: target org, plus "⏺ N" while tailing logs.
---Empty string when nothing is known. Refreshes on User SfTargetChanged /
---SfTailChanged, so a statusline can redraw on those events.
---@return string
function M.status()
	local parts = {}
	if M.org.target then
		table.insert(parts, M.org.target)
	end
	if M.logs.tailing() then
		table.insert(parts, "⏺ " .. M.logs.tail_count())
	end
	return table.concat(parts, " ")
end

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

---`:Sf` handler and completion, exported so `plugin/sf-nvim.lua` can register
---the command before `setup()` has run.
M._command = sf_command
M._complete = sf_complete

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
---Keymap prefix letter and label for each group in `M.actions`. Every
---default keymap for a group starts with `leader_prefix .. prefix`; the label
---is registered with which-key (if installed) so `<leader>s` shows a menu of
---groups. Kept separate from `M.actions` so its entries stay pure actions.
---@type table<string, {prefix: string, label: string}>
M.groups = {
	test = { prefix = "t", label = "Tests" },
	apex = { prefix = "a", label = "Anonymous Apex" },
	log = { prefix = "l", label = "Debug logs" },
	soql = { prefix = "q", label = "SOQL" },
	org = { prefix = "o", label = "Org" },
	config = { prefix = "c", label = "Config" },
	project = { prefix = "p", label = "Project" },
	generate = { prefix = "g", label = "Generate" },
}

local function setup_keybinds()
	local prefix = M.config.leader_prefix
	for _, group in pairs(M.actions) do
		for _, action in pairs(group) do
			vim.keymap.set(action.mode or "n", prefix .. action.key, function()
				action.fn()
			end, { desc = "Sf: " .. action.desc })
		end
	end
	local ok, wk = pcall(require, "which-key")
	if ok and type(wk.add) == "function" then
		local specs = { { prefix, group = "Salesforce", mode = { "n", "x" } } }
		for _, g in pairs(M.groups) do
			table.insert(specs, { prefix .. g.prefix, group = g.label, mode = { "n", "x" } })
		end
		wk.add(specs)
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
	M.did_setup = true

	M.apex.config.test_results_dir = M.config.test_results_dir
	M.apex.config.test_wait_time = M.config.test_wait_time
	M.apex.config.auto_open_quickfix = M.config.auto_open_quickfix

	setup_commands()
	if M.config.enable_default_keybinds then
		setup_keybinds()
	end
	M.project.set_deploy_on_save(M.config.deploy_on_save)
	if vim.fn.executable("sf") == 1 then
		M.org.refresh_target()
	end
end

return M
