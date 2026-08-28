-- apex.lua
-- Apex test execution and script running utilities

local M = {}

local runner = require("sf-nvim.utils.runner")
local quickfix = require("sf-nvim.quickfix")
local guard = require("sf-nvim.utils.guard")

---@class SfApexConfig
---@field test_results_dir string  relative to cwd
---@field test_wait_time integer   minutes for `sf apex run test -w`
---@field auto_open_quickfix boolean open quickfix when a run has failures

-- Default configuration (overwritten by init.setup)
---@type SfApexConfig
M.config = {
	test_results_dir = "test-results",
	test_wait_time = 15,
	auto_open_quickfix = true,
}

-- -------------------------------------------------------------
-- Run tests (all, or a single class) in a terminal split and
-- load failures into quickfix when the run finishes.
-- -------------------------------------------------------------
---@param class_name? string  nil runs the whole suite
local function run_tests(class_name)
	if not (guard.project() and guard.executable("sf")) then
		return
	end
	local results_dir = vim.fn.getcwd() .. "/" .. M.config.test_results_dir
	vim.fn.mkdir(results_dir, "p")

	local logfile = string.format("%s/%s_%s.json", results_dir, class_name or "all-tests", os.date("%Y%m%d%H%M%S"))

	local base = { "sf", "apex", "run", "test", "-w", tostring(M.config.test_wait_time) }
	if class_name then
		vim.list_extend(base, { "--tests", class_name })
	end

	-- Run twice: once for machine-readable JSON, once for the human-readable stream.
	local json_cmd = runner.shell_join(vim.list_extend(vim.deepcopy(base), { "--json" }))
	local cmd = json_cmd .. " > " .. vim.fn.shellescape(logfile) .. "; " .. runner.shell_join(base)

	runner.term(cmd, {
		on_exit = function()
			if quickfix.load_from_file(logfile) and M.config.auto_open_quickfix then
				vim.cmd("copen")
			end
		end,
	})
end

-- -------------------------------------------------------------
-- Run Apex test for current class
-- -------------------------------------------------------------
---Run the tests in the current `.cls` buffer; failures are loaded into quickfix.
function M.run_test()
	if vim.fn.expand("%:e") ~= "cls" then
		vim.notify("Current file is not an Apex class (.cls)", vim.log.levels.WARN)
		return
	end
	local target = vim.fn.expand("%:t:r")
	if target == "" then
		vim.notify("No filename to test", vim.log.levels.WARN)
		return
	end
	run_tests(target)
end

-- -------------------------------------------------------------
-- Run all Apex tests
-- -------------------------------------------------------------
---Run every test in the org; failures are loaded into quickfix.
function M.run_all_tests()
	run_tests(nil)
end

-- -------------------------------------------------------------
-- Execute anonymous Apex script from current file
-- -------------------------------------------------------------
---Run the current buffer's file with `sf apex run -f`.
function M.execute_script()
	local target = vim.fn.expand("%:p")
	if target == "" then
		vim.notify("No file to execute", vim.log.levels.WARN)
		return
	end
	runner.term({ "sf", "apex", "run", "-f", target })
end

-- -------------------------------------------------------------
-- Clear test results directory
-- -------------------------------------------------------------
---Delete every file under `<cwd>/<test_results_dir>` after confirmation.
function M.clear_test_results()
	local results_dir = vim.fn.getcwd() .. "/" .. M.config.test_results_dir

	if vim.fn.isdirectory(results_dir) == 0 then
		vim.notify("Test results directory does not exist", vim.log.levels.INFO)
		return
	end

	local files = vim.fn.glob(results_dir .. "/*", false, true)
	local n = #files
	if n == 0 then
		vim.notify("Test results directory is already empty", vim.log.levels.INFO)
		return
	end

	local plural = n > 1 and "s" or ""
	local response = vim.fn.confirm(string.format("Delete %d test result file%s?", n, plural), "&Yes\n&No", 2)
	if response == 1 then
		vim.fn.delete(results_dir, "rf")
		vim.fn.mkdir(results_dir, "p")
		vim.notify(string.format("Cleared %d test result file%s", n, plural), vim.log.levels.INFO)
	end
end

return M
