local guard = require("sf-nvim.utils.guard")
local runner = require("sf-nvim.utils.runner")

describe("guard", function()
	local notes, orig_notify
	before_each(function()
		notes = {}
		orig_notify = vim.notify
		vim.notify = function(m, level)
			table.insert(notes, { m = m, level = level })
		end
	end)
	after_each(function()
		vim.notify = orig_notify
	end)

	it("passes silently for an executable on PATH", function()
		assert.is_true(guard.executable("sh"))
		assert.same({}, notes)
	end)

	it("notifies with a checkhealth hint for a missing executable", function()
		assert.is_false(guard.executable("sf-nvim-definitely-not-installed"))
		assert.equals(1, #notes)
		assert.equals(vim.log.levels.ERROR, notes[1].level)
		assert.truthy(notes[1].m:find(":checkhealth sf-nvim", 1, true))
	end)

	it("uses a specific message for sf and rg", function()
		local orig = vim.fn.executable
		vim.fn.executable = function()
			return 0
		end
		guard.executable("sf")
		guard.executable("rg")
		vim.fn.executable = orig
		assert.truthy(notes[1].m:find("Salesforce CLI", 1, true))
		assert.truthy(notes[2].m:find("ripgrep", 1, true))
	end)

	it("project() requires sfdx-project.json in cwd", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		local orig_cwd = vim.fn.getcwd()
		vim.cmd("cd " .. vim.fn.fnameescape(dir))

		assert.is_false(guard.project())
		assert.truthy(notes[1].m:find("sfdx-project.json", 1, true))

		vim.fn.writefile({ "{}" }, dir .. "/sfdx-project.json")
		assert.is_true(guard.project())
		assert.equals(1, #notes)

		vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
		vim.fn.delete(dir, "rf")
	end)

	it("runner.run and runner.term bail out before executing a missing command", function()
		local called = false
		assert.is_nil(runner.run({ "sf-nvim-definitely-not-installed" }, {
			on_exit = function()
				called = true
			end,
		}))
		assert.is_nil(runner.term({ "sf-nvim-definitely-not-installed" }))
		vim.wait(100)
		assert.is_false(called)
		assert.equals(2, #notes)
	end)
end)
