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
		vim.notify("No filename to test", vim.log.levels.WARN, { title = "Apex Test" })
		return
	end

	-- Create test-results directory if it doesn't exist
	local test_results_dir = vim.fn.getcwd() .. "/" .. M.config.test_results_dir
	vim.fn.mkdir(test_results_dir, "p")

	-- Generate timestamped log file
	local timestamp = os.date("%Y%m%d%H%M%S")
	local logfile = string.format("%s/%s_%s.json", test_results_dir, target, timestamp)

	-- Redirect output to log file
	local cmd = string.format(
		"sf apex run test -w %d --concise --json --tests %s > %s 2>&1",
		M.config.test_wait_time,
		vim.fn.shellescape(target),
		vim.fn.shellescape(logfile)
	)

	runner.run({
		title = "Apex Test",
		running = "Running " .. target .. "...",
		cmd = { "bash", "-c", cmd },
		format_output = function(code)
			if code == 0 then
				return string.format("Tests passed. Results saved to %s", logfile)
			end
			return string.format("Tests failed. Review %s", logfile)
		end,
		on_exit = function()
			vim.schedule(function()
				-- Load test results into quickfix
				local quickfix = require("sf-nvim.quickfix")
				quickfix.load_from_file(logfile)
				vim.cmd("copen")
			end)
		end,
	})
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

	-- Redirect output to log file
	local cmd = string.format(
		"sf apex run test -w %d --concise --json > %s 2>&1",
		M.config.test_wait_time,
		vim.fn.shellescape(logfile)
	)

	runner.run({
		title = "Apex Tests",
		running = "Running all Apex tests...",
		cmd = { "bash", "-c", cmd },
		format_output = function(code)
			if code == 0 then
				return string.format("All tests passed. Results saved to %s", logfile)
			end
			return string.format("Tests failed. Review %s", logfile)
		end,
		on_exit = function()
			vim.schedule(function()
				-- Load test results into quickfix
				local quickfix = require("sf-nvim.quickfix")
				quickfix.load_from_file(logfile)
				vim.cmd("copen")
			end)
		end,
	})
end

-- -------------------------------------------------------------
-- Execute anonymous Apex script from current file
-- -------------------------------------------------------------
function M.execute_script()
	local target = vim.fn.expand("%:p")
	if target == "" then
		vim.notify("No file to execute", vim.log.levels.WARN, { title = "Execute Apex Script" })
		return
	end

	local timestamp = os.date("%Y%m%d%H%M%S")
	local logfile = string.format("%s/%s.log", vim.fn.expand("%:h"), timestamp)
	local cmd = string.format("sf apex run -f %s > %s 2>&1", vim.fn.shellescape(target), vim.fn.shellescape(logfile))

	runner.run({
		title = "Execute Apex Script",
		running = "Executing...",
		cmd = { "bash", "-c", cmd },
		format_output = function(code)
			if code == 0 then
				return string.format("Execution complete. Log saved to %s", logfile)
			end
			return string.format("Execution failed. Review %s", logfile)
		end,
		on_exit = function()
			vim.schedule(function()
				vim.cmd("edit " .. vim.fn.fnameescape(logfile))
			end)
		end,
	})
end

return M
