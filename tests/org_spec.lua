local org = require("sf-nvim.org")
local setconfig = require("sf-nvim.set-config")
local runner = require("sf-nvim.utils.runner")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"
local function load_fixture(name)
	local f = assert(io.open(fixtures .. "/" .. name, "r"))
	local c = f:read("*all")
	f:close()
	return vim.json.decode(c)
end

describe("org.render_limits", function()
	it("renders used/max/percent per limit and skips malformed rows", function()
		local lines = org.render_limits(load_fixture("org_limits.json"))
		assert.equals(4, #lines) -- header + 3 valid rows
		assert.truthy(lines[1]:match("^LIMIT"))
		assert.truthy(lines[2]:match("^DailyApiRequests%s+150%s+15000%s+1%%$"))
		assert.truthy(lines[3]:match("^DataStorageMB%s+5%s+5%s+100%%$"))
		assert.truthy(lines[4]:match("^MassEmail%s+0%s+0%s+%-$"))
	end)

	it("reports an empty result", function()
		assert.same({ "No limits returned" }, org.render_limits({ status = 0, result = {} }))
		assert.same({ "No limits returned" }, org.render_limits(nil))
	end)
end)

describe("set-config.build_org_items scratch flag", function()
	it("marks scratch orgs", function()
		local items = setconfig.build_org_items(load_fixture("org_list.json"))
		local by = {}
		for _, i in ipairs(items) do
			by[i.username] = i.scratch
		end
		assert.is_false(by["devhub@example.com"])
		assert.is_true(by["test-abc@example.com"])
	end)
end)

describe("org.pick / delete_scratch / open_pick", function()
	local orig_json, orig_run, orig_select, orig_confirm, orig_notify
	local runs, selected_prompt
	before_each(function()
		orig_json, orig_run, orig_select, orig_confirm, orig_notify =
			runner.json_async, runner.run, vim.ui.select, vim.fn.confirm, vim.notify
		runs = {}
		runner.json_async = function(_, cb)
			cb(load_fixture("org_list.json"))
		end
		runner.run = function(argv)
			table.insert(runs, argv)
		end
		vim.notify = function() end
	end)
	after_each(function()
		runner.json_async, runner.run, vim.ui.select, vim.fn.confirm, vim.notify =
			orig_json, orig_run, orig_select, orig_confirm, orig_notify
	end)

	it("delete_scratch offers only scratch orgs and needs confirmation", function()
		local offered
		vim.ui.select = function(items, opts, cb)
			offered = items
			selected_prompt = opts.prompt
			cb(items[1])
		end
		vim.fn.confirm = function()
			return 2
		end
		org.delete_scratch()
		assert.equals(1, #offered)
		assert.equals("issue123", offered[1].alias)
		assert.same({}, runs)

		vim.fn.confirm = function()
			return 1
		end
		org.delete_scratch()
		assert.same({ "sf", "org", "delete", "scratch", "--target-org", "issue123", "--no-prompt" }, runs[1])
	end)

	it("open_pick opens the chosen org by alias or username", function()
		vim.ui.select = function(items, _, cb)
			cb(items[2]) -- noalias@example.com
		end
		org.open_pick()
		assert.same({ "sf", "org", "open", "--target-org", "noalias@example.com" }, runs[1])
	end)
end)
