local quickfix = require("sf-nvim.quickfix")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"

local function load_fixture(name)
	local f = assert(io.open(fixtures .. "/" .. name, "r"))
	local content = f:read("*all")
	f:close()
	return vim.json.decode(content)
end

-- Fake class-file resolver: everything except MissingClassTest resolves
local function fake_find(name)
	if name == "MissingClassTest" then
		return nil
	end
	return "force-app/main/default/classes/" .. name .. ".cls"
end

describe("quickfix.parse_test_results", function()
	it("builds quickfix items only for failures", function()
		local data = load_fixture("apex_test_failures.json")
		local items, skipped = quickfix.parse_test_results(data, fake_find)

		assert.equals(2, #items)
		assert.equals(1, #skipped)

		assert.same({
			filename = "force-app/main/default/classes/AccountServiceTest.cls",
			lnum = 42,
			col = 1,
			text = "testUpdateFails: System.AssertException: Assertion Failed: Expected: 1, Actual: 2",
			type = "E",
		}, items[1])
	end)

	it("uses the first line/column pair in a multi-frame stack trace", function()
		local data = load_fixture("apex_test_failures.json")
		local items = quickfix.parse_test_results(data, fake_find)
		-- second failure's stack trace has the callee frame first (line 17)
		assert.equals(17, items[2].lnum)
		assert.equals(9, items[2].col)
	end)

	it("reports failures whose class file cannot be found as skipped", function()
		local data = load_fixture("apex_test_failures.json")
		local _, skipped = quickfix.parse_test_results(data, fake_find)
		assert.same({ class = "MissingClassTest", method = "testSomething", message = "System.AssertException: nope" }, skipped[1])
	end)

	it("returns nothing for an all-pass run", function()
		local items, skipped = quickfix.parse_test_results(load_fixture("apex_test_all_pass.json"), fake_find)
		assert.equals(0, #items)
		assert.equals(0, #skipped)
	end)

	it("tolerates CLI error payloads and garbage", function()
		local items = quickfix.parse_test_results(load_fixture("apex_test_error.json"), fake_find)
		assert.equals(0, #items)
		assert.equals(0, #quickfix.parse_test_results(nil, fake_find))
		assert.equals(0, #quickfix.parse_test_results("nope", fake_find))
		assert.equals(0, #quickfix.parse_test_results({ result = { tests = "x" } }, fake_find))
	end)

	it("defaults line/col to 1 when the stack trace has none", function()
		local data = {
			result = {
				tests = {
					{ Outcome = "Fail", MethodName = "m", StackTrace = "", ApexClass = { Name = "AccountServiceTest" } },
				},
			},
		}
		local items = quickfix.parse_test_results(data, fake_find)
		assert.equals(1, items[1].lnum)
		assert.equals(1, items[1].col)
		assert.equals("m: Test failed", items[1].text)
	end)
end)

describe("quickfix.find_class_file", function()
	it("rejects names that are not Apex identifiers", function()
		assert.is_nil(quickfix.find_class_file("Foo; rm -rf /"))
		assert.is_nil(quickfix.find_class_file("Foo.Bar"))
		assert.is_nil(quickfix.find_class_file(""))
	end)
end)

describe("quickfix.load_from_file", function()
	local tmp

	before_each(function()
		tmp = vim.fn.tempname()
		vim.fn.mkdir(tmp, "p")
		vim.fn.setqflist({}, "r")
	end)

	after_each(function()
		vim.fn.delete(tmp, "rf")
	end)

	it("returns false for a missing file", function()
		assert.is_false(quickfix.load_from_file(tmp .. "/nope.json"))
	end)

	it("returns false for a CLI error payload", function()
		local path = tmp .. "/err.json"
		vim.fn.writefile(vim.fn.readfile(fixtures .. "/apex_test_error.json"), path)
		assert.is_false(quickfix.load_from_file(path))
	end)

	it("returns false for invalid JSON", function()
		local path = tmp .. "/bad.json"
		vim.fn.writefile({ "{ not json" }, path)
		assert.is_false(quickfix.load_from_file(path))
	end)

	it("populates the quickfix list from a results file", function()
		local original = quickfix.find_class_file
		quickfix.find_class_file = fake_find
		local path = tmp .. "/run.json"
		vim.fn.writefile(vim.fn.readfile(fixtures .. "/apex_test_failures.json"), path)

		local ok = quickfix.load_from_file(path)
		quickfix.find_class_file = original

		assert.is_true(ok)
		local qf = vim.fn.getqflist()
		assert.equals(2, #qf)
		assert.equals(42, qf[1].lnum)
	end)
end)

describe("quickfix.find_latest_test_results", function()
	it("returns the newest json file, or nil when there are none", function()
		local tmp = vim.fn.tempname()
		vim.fn.mkdir(tmp, "p")
		assert.is_nil(quickfix.find_latest_test_results(tmp))

		vim.fn.writefile({ "{}" }, tmp .. "/old.json")
		vim.fn.writefile({ "{}" }, tmp .. "/new.json")
		vim.fn.writefile({ "x" }, tmp .. "/ignored.txt")
		-- force distinct mtimes without sleeping
		vim.fn.system({ "touch", "-d", "2000-01-01", tmp .. "/old.json" })

		assert.equals(tmp .. "/new.json", quickfix.find_latest_test_results(tmp))
		vim.fn.delete(tmp, "rf")
	end)
end)
