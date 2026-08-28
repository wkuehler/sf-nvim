describe("health", function()
	it("exposes a check function", function()
		assert.is_function(require("sf-nvim.health").check)
	end)

	it(":checkhealth sf-nvim renders every section", function()
		-- Drive the real entry point: the health report_* shims in Neovim 0.9 only
		-- work inside an actual :checkhealth run.
		vim.cmd("checkhealth sf-nvim")
		local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		assert.truthy(text:find("Neovim", 1, true))
		assert.truthy(text:find("External tools", 1, true))
		assert.truthy(text:find("Project", 1, true))
		assert.falsy(text:find("E%d%d%d:")) -- no vim errors leaked into the report
	end)
end)
