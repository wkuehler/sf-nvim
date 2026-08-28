describe("sf-nvim.setup", function()
	local sf = require("sf-nvim")
	local org = require("sf-nvim.org")
	local orig_refresh = org.refresh_target
	before_each(function()
		org.refresh_target = function() end
	end)
	after_each(function()
		org.refresh_target = orig_refresh
	end)

	it("merges user options over defaults and pushes them to apex", function()
		sf.setup({ test_results_dir = "out", test_wait_time = 3, auto_open_quickfix = false })
		assert.equals("out", sf.config.test_results_dir)
		assert.equals(3, sf.config.test_wait_time)
		assert.is_false(sf.config.auto_open_quickfix)
		assert.equals("out", sf.apex.config.test_results_dir)
		assert.equals(3, sf.apex.config.test_wait_time)
		assert.is_false(sf.apex.config.auto_open_quickfix)
		sf.setup()
		assert.is_true(sf.apex.config.auto_open_quickfix)
	end)

	it("registers the :Sf command with group/action completion", function()
		sf.setup()
		local cmds = vim.api.nvim_get_commands({})
		assert.is_not_nil(cmds.Sf)

		assert.same(
			{ "apex", "config", "log", "org", "project", "soql", "test" },
			vim.fn.getcompletion("Sf ", "cmdline")
		)
		assert.same({ "all", "clear", "current", "load", "method" }, vim.fn.getcompletion("Sf test ", "cmdline"))
		assert.same({ "test" }, vim.fn.getcompletion("Sf te", "cmdline"))
	end)

	it("dispatches :Sf to the matching action", function()
		sf.setup()
		local called = false
		local original = sf.actions.test.load.fn
		sf.actions.test.load.fn = function()
			called = true
		end
		vim.cmd("Sf test load")
		sf.actions.test.load.fn = original
		assert.is_true(called)
	end)

	it("only sets keymaps when asked", function()
		sf.setup({ enable_default_keybinds = true, leader_prefix = "<leader>z" })
		local found = false
		for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
			if m.desc == "Sf: Run tests for current class" then
				found = true
			end
		end
		assert.is_true(found)
	end)

	it("passes a range to the action when :Sf is given one, and visual actions map in x mode", function()
		sf.setup({ enable_default_keybinds = true })
		local got_range = "unset"
		local orig = sf.actions.apex.selection.fn
		sf.actions.apex.selection.fn = function(r)
			got_range = r
		end
		vim.cmd("enew")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c" })
		vim.cmd("2,3Sf apex selection")
		assert.same({ 2, 3 }, got_range)
		vim.cmd("Sf apex selection")
		assert.is_nil(got_range)
		sf.actions.apex.selection.fn = orig
		vim.cmd("bwipeout!")

		assert.equals("", vim.fn.maparg("<leader>se", "x", false, true).rhs or "")
		assert.truthy(vim.fn.maparg("<leader>se", "x", false, true).callback)
		assert.truthy(vim.fn.maparg("<leader>se", "n", false, true).callback)
	end)
end)
