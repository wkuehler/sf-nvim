-- apex.lua
-- Apex test execution and script running utilities

local M = {}

local runner = require("sf-nvim.utils.runner")

-- Default configuration
M.config = {
	test_results_dir = "test-results",
	test_wait_time = 15,
	test_format = "json",
}

-- -------------------------------------------------------------
-- Helper function to format Apex output
-- -------------------------------------------------------------
local function format_apex_output(code, stdout, stderr)
	if code == 0 then
		return stdout ~= "" and stdout or "Command succeeded."
	end
	if stderr ~= "" then
		return stderr
	end
	if stdout ~= "" then
		return stdout
	end
	return "Command failed."
end

-- -------------------------------------------------------------
-- Run Apex test for current class
-- -------------------------------------------------------------
function M.run_test()
	local target = vim.fn.expand("%:t:r")
	if target == "" then
		vim.notify("No filename to test", vim.log.levels.WARN)
		return
	end

	-- Validate that current file is an Apex class
	local extension = vim.fn.expand("%:e")
	if extension ~= "cls" then
		vim.notify("Current file is not an Apex class (.cls)", vim.log.levels.WARN)
		return
	end

	-- Create test-results directory if it doesn't exist
	local test_results_dir = vim.fn.getcwd() .. "/" .. M.config.test_results_dir
	vim.fn.mkdir(test_results_dir, "p")

	-- Generate timestamped log file
	local timestamp = os.date("%Y%m%d%H%M%S")
	local logfile = string.format("%s/%s_%s.json", test_results_dir, target, timestamp)

	-- Build command to run tests and save JSON output
	local cmd = string.format(
		"sf apex run test -w %d --tests %s --json > %s; sf apex run test -w %d --tests %s; echo ''; read -p 'Press ENTER to close...'",
		M.config.test_wait_time,
		target,
		vim.fn.shellescape(logfile),
		M.config.test_wait_time,
		target
	)

	-- Open in terminal for better output visibility
	vim.cmd(string.format("botright split | terminal bash -c %s", vim.fn.shellescape(cmd)))

	-- Set up autocmd to load quickfix when terminal closes
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_create_autocmd("TermClose", {
		buffer = bufnr,
		once = true,
		callback = function()
			vim.schedule(function()
				-- Close the terminal buffer (check validity first)
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_delete(bufnr, { force = true })
				end
				-- Load quickfix
				local quickfix = require("sf-nvim.quickfix")
				quickfix.load_from_file(logfile)
				vim.cmd("copen")
			end)
		end,
	})

	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Run all Apex tests
-- -------------------------------------------------------------
function M.run_all_tests()
	-- Create test-results directory if it doesn't exist
	local test_results_dir = vim.fn.getcwd() .. "/" .. M.config.test_results_dir
	vim.fn.mkdir(test_results_dir, "p")

	-- Generate timestamped log file
	local timestamp = os.date("%Y%m%d%H%M%S")
	local logfile = string.format("%s/all-tests_%s.json", test_results_dir, timestamp)

	-- Build command to run tests and save JSON output
	local cmd = string.format(
		"sf apex run test -w %d --json > %s; sf apex run test -w %d; echo ''; read -p 'Press ENTER to close...'",
		M.config.test_wait_time,
		vim.fn.shellescape(logfile),
		M.config.test_wait_time
	)

	-- Open in terminal for better output visibility
	vim.cmd(string.format("botright split | terminal bash -c %s", vim.fn.shellescape(cmd)))

	-- Set up autocmd to load quickfix when terminal closes
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_create_autocmd("TermClose", {
		buffer = bufnr,
		once = true,
		callback = function()
			vim.schedule(function()
				-- Close the terminal buffer (check validity first)
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_delete(bufnr, { force = true })
				end
				-- Load quickfix
				local quickfix = require("sf-nvim.quickfix")
				quickfix.load_from_file(logfile)
				vim.cmd("copen")
			end)
		end,
	})

	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Execute anonymous Apex script from current file
-- -------------------------------------------------------------
function M.execute_script()
	local target = vim.fn.expand("%:p")
	if target == "" then
		vim.notify("No file to execute", vim.log.levels.WARN)
		return
	end

	-- Open in terminal for better output visibility
	vim.cmd(string.format("split | terminal sf apex run -f %s", vim.fn.shellescape(target)))
	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Clear test results directory
-- -------------------------------------------------------------
function M.clear_test_results()
	local test_results_dir = vim.fn.getcwd() .. "/" .. M.config.test_results_dir

	-- Check if directory exists
	if vim.fn.isdirectory(test_results_dir) == 0 then
		vim.notify("Test results directory does not exist", vim.log.levels.INFO)
		return
	end

	-- Count files before deletion
	local files = vim.fn.glob(test_results_dir .. "/*", false, true)
	local file_count = #files

	if file_count == 0 then
		vim.notify("Test results directory is already empty", vim.log.levels.INFO)
		return
	end

	-- Ask for confirmation
	local response = vim.fn.confirm(
		string.format("Delete %d test result file%s?", file_count, file_count > 1 and "s" or ""),
		"&Yes\n&No",
		2
	)

	if response == 1 then
		-- Delete all files in the directory
		vim.fn.delete(test_results_dir, "rf")
		vim.fn.mkdir(test_results_dir, "p")
		vim.notify(string.format("Cleared %d test result file%s", file_count, file_count > 1 and "s" or ""), vim.log.levels.INFO)
	end
end

return M
