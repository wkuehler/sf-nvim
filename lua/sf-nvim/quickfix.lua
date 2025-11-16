-- quickfix.lua
-- Salesforce Apex test result parser for Neovim quickfix

local M = {}

-- -------------------------------------------------------------
-- Helper function to find the actual file path for an Apex class
-- -------------------------------------------------------------
local function find_class_file(class_name)
	-- Use rg to search for files with the exact class name
	local handle = io.popen(string.format('rg --files --glob "**/%s.cls" 2>/dev/null', class_name))
	local result = handle:read("*a")
	handle:close()

	-- Return the first match, or nil if not found
	local filepath = result:match("^[^\n]+")
	if filepath and filepath ~= "" then
		return filepath
	else
		return nil
	end
end

-- -------------------------------------------------------------
-- Function to find the most recent test results file
-- -------------------------------------------------------------
local function find_latest_test_results(directory)
	directory = directory or "."

	-- Use find to get all JSON files with their modification times
	local handle = io.popen(
		string.format(
			'find "%s" -maxdepth 1 -name "*.json" -type f -printf "%%T@ %%p\\n" 2>/dev/null | sort -rn | head -1',
			directory
		)
	)
	local result = handle:read("*a")
	handle:close()

	-- Extract the file path (everything after the timestamp)
	local filepath = result:match("%S+%s+(.+)")
	if filepath then
		filepath = filepath:gsub("\n$", "") -- Remove trailing newline
		return filepath
	end

	return nil
end

-- -------------------------------------------------------------
-- Parse test results and build quickfix items
-- -------------------------------------------------------------
local function parse_test_results(data)
	local qf_items = {}
	local skipped_tests = {}

	for _, test in ipairs(data.result.tests) do
		if test.Outcome == "Fail" then
			local line, col = string.match(test.StackTrace or "", "line (%d+), column (%d+)")
			local filepath = find_class_file(test.ApexClass.Name)

			if filepath then
				table.insert(qf_items, {
					filename = filepath,
					lnum = tonumber(line) or 1,
					col = tonumber(col) or 1,
					text = test.MethodName .. ": " .. (test.Message or "Test failed"),
					type = "E",
				})
			else
				-- Log skipped test where class file was not found
				table.insert(skipped_tests, {
					class = test.ApexClass.Name,
					method = test.MethodName,
					message = test.Message or "Test failed",
				})
			end
		end
	end

	return qf_items, skipped_tests
end

-- -------------------------------------------------------------
-- Print parsing results summary
-- -------------------------------------------------------------
local function print_results_summary(qf_items, skipped_tests, test_file)
	print("\n=== Quickfix Parsing Results ===")
	if test_file then
		print("File: " .. test_file)
	end
	print("Successfully parsed " .. #qf_items .. " failure(s)\n")

	if #qf_items > 0 then
		for i, item in ipairs(qf_items) do
			print(string.format("%d. %s:%d:%d - %s", i, item.filename, item.lnum, item.col, item.text))
		end
	else
		print("No failures found!")
	end

	if #skipped_tests > 0 then
		print("\n--- Skipped (class file not found) ---")
		for i, skipped in ipairs(skipped_tests) do
			print(string.format("%d. %s.%s - %s", i, skipped.class, skipped.method, skipped.message))
		end
	end

	print("\n=================================\n")
end

-- -------------------------------------------------------------
-- Public API: Load test results from a specific file
-- -------------------------------------------------------------
function M.load_from_file(filepath)
	local f = io.open(filepath, "r")
	if not f then
		vim.notify("Error: Could not open file: " .. filepath, vim.log.levels.ERROR)
		return false
	end

	local content = f:read("*all")
	f:close()

	local ok, data = pcall(vim.fn.json_decode, content)
	if not ok then
		vim.notify("Error: Failed to parse JSON from " .. filepath, vim.log.levels.ERROR)
		return false
	end

	local qf_items, skipped_tests = parse_test_results(data)
	vim.fn.setqflist(qf_items, "r")
	-- print_results_summary(qf_items, skipped_tests, filepath)

	return true
end

-- -------------------------------------------------------------
-- Public API: Load latest test results from directory
-- -------------------------------------------------------------
function M.load_latest(directory)
	directory = directory or "."

	local test_file = find_latest_test_results(directory)
	if not test_file then
		vim.notify("Error: No test result JSON files found in " .. directory, vim.log.levels.ERROR)
		return false
	end

	return M.load_from_file(test_file)
end

-- -------------------------------------------------------------
-- Public API: Load latest and open quickfix window
-- -------------------------------------------------------------
function M.load_and_open(directory)
	if M.load_latest(directory) then
		vim.cmd("copen")
	end
end

return M
