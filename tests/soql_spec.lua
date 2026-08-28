local soql = require("sf-nvim.soql")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"
local function load_fixture(name)
	local f = assert(io.open(fixtures .. "/" .. name, "r"))
	local content = f:read("*all")
	f:close()
	return vim.json.decode(content)
end

local QUERY = "SELECT Id, Name, Owner.Name, (SELECT Id FROM Contacts) FROM Account ORDER BY CreatedDate LIMIT 2"

describe("soql.normalize", function()
	it("joins lines, drops comment lines and a trailing semicolon", function()
		assert.equals(
			"SELECT Id FROM Account WHERE Name = 'x'",
			soql.normalize({ "// accounts", "SELECT Id", "  FROM Account", "-- filter", "WHERE Name = 'x';" })
		)
		assert.equals("", soql.normalize({ "", "// nothing" }))
	end)
end)

describe("soql.select_fields", function()
	it("lists fields in order, ignoring subqueries and handling aliases", function()
		assert.same({ "Id", "Name", "Owner.Name" }, soql.select_fields(QUERY))
		assert.same(
			{ "cnt", "StageName" },
			soql.select_fields("select COUNT(Id) cnt, StageName from Opportunity group by StageName")
		)
		assert.same({}, soql.select_fields("not a query"))
	end)
end)

describe("soql.flatten", function()
	it("flattens relationships, summarises subqueries, blanks nulls", function()
		local recs = load_fixture("query_accounts.json").result.records
		assert.same(
			{ Id = "001000000000000AAA", Name = "Account 0", ["Owner.Name"] = "Automated Process", Contacts = "" },
			soql.flatten(recs[1])
		)
		local r2 = soql.flatten(recs[2])
		assert.equals("[2 rows]", r2.Contacts)
		assert.equals("", r2["Owner.Name"])
	end)
end)

describe("soql.render", function()
	it("renders an aligned table in query column order", function()
		local lines = soql.render(load_fixture("query_accounts.json"), QUERY)
		assert.equals("-- " .. QUERY, lines[1])
		assert.equals("-- 2 of 2 row(s)", lines[2])
		assert.equals("Id                  Name       Owner.Name         Contacts", lines[3])
		assert.equals("------------------  ---------  -----------------  --------", lines[4])
		assert.equals("001000000000000AAA  Account 0  Automated Process          ", lines[5])
		assert.equals("001000000000001AAA  Account 1                     [2 rows]", lines[6])
		assert.equals(6, #lines)
	end)

	it("handles an empty result and error payloads", function()
		local lines = soql.render({ status = 0, result = { records = {}, totalSize = 0, done = true } })
		assert.same({ "-- 0 of 0 row(s)" }, lines)
		lines = soql.render(load_fixture("query_error.json"))
		assert.equals("== No result", lines[1])
	end)
end)

describe("soql.run", function()
	local runner = require("sf-nvim.utils.runner")
	local orig, argv, notes
	before_each(function()
		orig = { json_async = runner.json_async, notify = vim.notify }
		notes = {}
		vim.notify = function(m, l)
			table.insert(notes, { m = m, l = l })
		end
	end)
	after_each(function()
		runner.json_async, vim.notify = orig.json_async, orig.notify
		pcall(vim.cmd, "close")
	end)

	it("passes the query through --query and shows the table", function()
		runner.json_async = function(a, cb)
			argv = a
			cb(load_fixture("query_accounts.json"), nil)
		end
		soql.run("SELECT Id FROM Account;")
		assert.same({ "sf", "data", "query", "--query", "SELECT Id FROM Account", "--json" }, argv)
		local bufnr = vim.fn.bufnr("sf://query")
		assert.equals("soqlresult", vim.bo[bufnr].filetype)
		assert.equals("-- SELECT Id FROM Account", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
	end)

	it("shows the CLI error message in the result buffer", function()
		runner.json_async = function(_, cb)
			cb(load_fixture("query_error.json"), nil)
		end
		soql.run("SELECT Id FROM Nope__c")
		local bufnr = vim.fn.bufnr("sf://query")
		local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
		assert.truthy(text:find("== INVALID_TYPE", 1, true))
		assert.truthy(text:find("ERROR at Row:1:Column:16", 1, true))
		assert.equals(vim.log.levels.ERROR, notes[#notes].l)
	end)

	it("refuses an empty query", function()
		soql.run("  ;")
		assert.equals("Empty query", notes[1].m)
	end)
end)
