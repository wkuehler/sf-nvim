local setconfig = require("sf-nvim.set-config")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"

local function load_fixture(name)
	local f = assert(io.open(fixtures .. "/" .. name, "r"))
	local content = f:read("*all")
	f:close()
	return vim.json.decode(content)
end

describe("set-config.build_org_items", function()
	it("lists non-scratch orgs first, then scratch orgs, with default markers", function()
		local items = setconfig.build_org_items(load_fixture("org_list.json"))
		assert.equals(3, #items)

		assert.same({
			label = "DevHub (devhub@example.com) [default hub]",
			alias = "DevHub",
			username = "devhub@example.com",
			scratch = false,
		}, items[1])
		assert.same(
			{ label = "noalias@example.com", alias = nil, username = "noalias@example.com", scratch = false },
			items[2]
		)
		assert.same({
			label = "issue123 (test-abc@example.com) [default org]",
			alias = "issue123",
			username = "test-abc@example.com",
			scratch = true,
		}, items[3])
	end)

	it("returns an empty list for empty or malformed payloads", function()
		assert.same({}, setconfig.build_org_items({ result = { nonScratchOrgs = {}, scratchOrgs = {} } }))
		assert.same({}, setconfig.build_org_items({ result = {} }))
		assert.same({}, setconfig.build_org_items({ name = "SomeError", message = "boom" }))
		assert.same({}, setconfig.build_org_items(nil))
	end)
end)

describe("set-config.set_default", function()
	local runner = require("sf-nvim.utils.runner")
	local orig = { json_async = runner.json_async, run = runner.run, select = vim.ui.select, notify = vim.notify }
	local calls, notes

	before_each(function()
		calls, notes = {}, {}
		runner.json_async = function(argv, cb)
			table.insert(calls, argv)
			cb(load_fixture("org_list.json"), nil)
		end
		runner.run = function(argv, opts)
			table.insert(calls, argv)
			opts.on_exit(0, "", "")
		end
		vim.ui.select = function(items, _, on_choice)
			on_choice(items[3])
		end
		vim.notify = function(m)
			table.insert(notes, m)
		end
	end)

	after_each(function()
		runner.json_async, runner.run, vim.ui.select, vim.notify = orig.json_async, orig.run, orig.select, orig.notify
	end)

	it("lists orgs, lets the user pick, then sets the config key (alias preferred)", function()
		setconfig.set_default("target-org")
		assert.same({ "sf", "org", "list", "--json" }, calls[1])
		assert.same({ "sf", "config", "set", "target-org", "issue123" }, calls[2])
		assert.same({ "Set target-org to issue123" }, notes)
	end)

	it("rejects unknown config keys without running anything", function()
		setconfig.set_default("target-nope")
		assert.same({}, calls)
		assert.equals(1, #notes)
	end)

	it("reports a fetch error and stops", function()
		runner.json_async = function(_, cb)
			cb(nil, "failed to parse JSON (exit 1): boom")
		end
		setconfig.set_default("target-org")
		assert.same({}, calls)
		assert.same({ "sf org list: failed to parse JSON (exit 1): boom" }, notes)
	end)
end)
