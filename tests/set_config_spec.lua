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

		assert.same(
			{ label = "DevHub (devhub@example.com) [default hub]", alias = "DevHub", username = "devhub@example.com" },
			items[1]
		)
		assert.same({ label = "noalias@example.com", alias = nil, username = "noalias@example.com" }, items[2])
		assert.same({
			label = "issue123 (test-abc@example.com) [default org]",
			alias = "issue123",
			username = "test-abc@example.com",
		}, items[3])
	end)

	it("returns an empty list for empty or malformed payloads", function()
		assert.same({}, setconfig.build_org_items({ result = { nonScratchOrgs = {}, scratchOrgs = {} } }))
		assert.same({}, setconfig.build_org_items({ result = {} }))
		assert.same({}, setconfig.build_org_items({ name = "SomeError", message = "boom" }))
		assert.same({}, setconfig.build_org_items(nil))
	end)
end)
