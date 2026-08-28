describe("sf-nvim.setup", function()
	local sf = require("sf-nvim")

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

		assert.same({ "apex", "config", "org", "project", "test" }, vim.fn.getcompletion("Sf ", "cmdline"))
		assert.same({ "all", "clear", "current", "load" }, vim.fn.getcompletion("Sf test ", "cmdline"))
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
end)
