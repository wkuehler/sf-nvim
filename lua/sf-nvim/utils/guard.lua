-- guard.lua
-- Preflight checks that turn "command not found" / "not in a project" into
-- one actionable message instead of a failure deep inside a call chain.
-- `:checkhealth sf-nvim` is the diagnostic counterpart (health.lua).

local M = {}

local HINT = " — run :checkhealth sf-nvim"

---Return true if `exe` is on PATH; otherwise notify and return false.
---@param exe string
---@return boolean
function M.executable(exe)
	if vim.fn.executable(exe) == 1 then
		return true
	end
	local what = ({
		sf = "Salesforce CLI `sf` not found on PATH",
		rg = "ripgrep `rg` not found on PATH (needed to locate Apex class files)",
	})[exe] or ("`" .. exe .. "` not found on PATH")
	vim.notify("sf-nvim: " .. what .. HINT, vim.log.levels.ERROR)
	return false
end

---Return true if cwd contains sfdx-project.json; otherwise notify and return false.
---@return boolean
function M.project()
	local cwd = vim.fn.getcwd()
	if vim.fn.filereadable(cwd .. "/sfdx-project.json") == 1 then
		return true
	end
	vim.notify(
		"sf-nvim: no sfdx-project.json in " .. cwd .. " (open Neovim from the project root)" .. HINT,
		vim.log.levels.ERROR
	)
	return false
end

return M
