-- quickfix.lua
-- Salesforce Apex test result parser for Neovim quickfix

local M = {}

-- -------------------------------------------------------------
-- Find the file path for an Apex class (via ripgrep, no shell)
-- -------------------------------------------------------------
---@param class_name string
---@return string|nil
function M.find_class_file(class_name)
	-- Apex identifiers are [A-Za-z0-9_]; refuse anything else outright
	if not class_name:match("^[%w_]+$") then
		return nil
	end
	if vim.fn.executable("rg") == 0 then
		return nil
	end
	local output = vim.fn.system({ "rg", "--files", "--glob", "**/" .. class_name .. ".cls" })
	if vim.v.shell_error ~= 0 then
		return nil
	end
	local filepath = output:match("^[^\n]+")
	if filepath and filepath ~= "" then
		return filepath
	end
	return nil
end

-- -------------------------------------------------------------
-- Find the most recent test results JSON in a directory
-- -------------------------------------------------------------
---@param directory string
---@return string|nil
function M.find_latest_test_results(directory)
	local files = vim.fn.glob(directory .. "/*.json", false, true)
	local latest, latest_time = nil, -1
	for _, f in ipairs(files) do
		local t = vim.fn.getftime(f)
		if t > latest_time then
			latest, latest_time = f, t
		end
	end
	return latest
end

-- -------------------------------------------------------------
-- Parse `sf apex run test --json` output into quickfix items
-- -------------------------------------------------------------
---@class SfSkippedTest
---@field class string
---@field method string
---@field message string

---@param data table                       decoded JSON from `sf apex run test --json`
---@param find_file? fun(name: string): string|nil   override class-file resolver (tests)
---@return table[] qf_items
---@return SfSkippedTest[] skipped_tests
function M.parse_test_results(data, find_file)
	find_file = find_file or M.find_class_file
	local qf_items = {}
	local skipped_tests = {}

	if type(data) ~= "table" or type(data.result) ~= "table" or type(data.result.tests) ~= "table" then
		return qf_items, skipped_tests
	end

	for _, test in ipairs(data.result.tests) do
		if test.Outcome == "Fail" or test.Outcome == "CompileFail" then
			local class_name = test.ApexClass and test.ApexClass.Name or "?"
			local method = test.MethodName or "?"
			local message = test.Message or "Test failed"
			local line, col = string.match(test.StackTrace or "", "line (%d+), column (%d+)")
			local filepath = find_file(class_name)

			if filepath then
				table.insert(qf_items, {
					filename = filepath,
					lnum = tonumber(line) or 1,
					col = tonumber(col) or 1,
					text = method .. ": " .. message,
					type = "E",
				})
			else
				table.insert(skipped_tests, { class = class_name, method = method, message = message })
			end
		end
	end

	return qf_items, skipped_tests
end

-- -------------------------------------------------------------
-- Summarise a parsed run for the user
-- -------------------------------------------------------------
local function notify_summary(data, qf_items, skipped_tests)
	local summary = data.result and data.result.summary or {}
	local level = #qf_items + #skipped_tests > 0 and vim.log.levels.WARN or vim.log.levels.INFO
	local msg = string.format(
		"Tests: %s passed, %s failed",
		tostring(summary.passing or "?"),
		tostring(summary.failing or (#qf_items + #skipped_tests))
	)
	if #skipped_tests > 0 then
		local names = {}
		for _, s in ipairs(skipped_tests) do
			table.insert(names, s.class .. "." .. s.method)
		end
		msg = msg
			.. string.format(
				"\n%d failure(s) not in quickfix (class file not found): %s",
				#skipped_tests,
				table.concat(names, ", ")
			)
	end
	vim.notify(msg, level)
end

-- -------------------------------------------------------------
-- Public API: Load test results from a specific file
-- -------------------------------------------------------------
---@param filepath string
---@return boolean ok
function M.load_from_file(filepath)
	local f = io.open(filepath, "r")
	if not f then
		vim.notify("Could not open test results: " .. filepath, vim.log.levels.ERROR)
		return false
	end
	local content = f:read("*all")
	f:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok or type(data) ~= "table" then
		vim.notify("Failed to parse JSON from " .. filepath, vim.log.levels.ERROR)
		return false
	end
	if not (data.result and data.result.tests) then
		local reason = data.message or "no tests in result"
		vim.notify("Test run produced no results: " .. tostring(reason), vim.log.levels.WARN)
		return false
	end

	-- Missing ripgrep is reported once here; find_class_file then returns nil
	-- and every failure ends up in the "not in quickfix" summary line.
	require("sf-nvim.utils.guard").executable("rg")
	local qf_items, skipped_tests = M.parse_test_results(data)
	vim.fn.setqflist({}, "r", { title = "Apex test failures", items = qf_items })
	notify_summary(data, qf_items, skipped_tests)
	return true
end

-- -------------------------------------------------------------
-- Public API: Load latest test results from directory
-- -------------------------------------------------------------
---@param directory? string
---@return boolean ok
function M.load_latest(directory)
	directory = directory or "."
	local test_file = M.find_latest_test_results(directory)
	if not test_file then
		vim.notify("No test result JSON files found in " .. directory, vim.log.levels.ERROR)
		return false
	end
	return M.load_from_file(test_file)
end

-- -------------------------------------------------------------
-- Public API: Load latest and open quickfix window
-- -------------------------------------------------------------
---@param directory? string
function M.load_and_open(directory)
	if M.load_latest(directory) then
		vim.cmd("copen")
	end
end

return M
