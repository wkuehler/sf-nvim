-- plugin/sf-nvim.lua: `:Sf` exists before setup() and triggers a default setup.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

describe("plugin/sf-nvim.lua", function()
	it("registers :Sf without setup() and runs setup on first use", function()
		pcall(vim.api.nvim_del_user_command, "Sf")
		package.loaded["sf-nvim"] = nil
		vim.g.loaded_sf_nvim = nil
		vim.cmd.source(root .. "/plugin/sf-nvim.lua")

		assert.truthy(vim.api.nvim_get_commands({})["Sf"])
		assert.is_nil(package.loaded["sf-nvim"])

		local completions = vim.fn.getcompletion("Sf te", "cmdline")
		assert.same({ "test" }, completions)

		local sf = require("sf-nvim")
		assert.falsy(sf.did_setup)
		local called = false
		sf.actions.test.all.fn = function()
			called = true
		end
		vim.cmd("Sf test all")
		assert.is_true(called)
		assert.is_true(sf.did_setup)
		assert.equals("test-results", sf.config.test_results_dir)
	end)

	it("is idempotent under a second source", function()
		vim.cmd.source(root .. "/plugin/sf-nvim.lua")
		assert.truthy(vim.api.nvim_get_commands({})["Sf"])
	end)
end)
