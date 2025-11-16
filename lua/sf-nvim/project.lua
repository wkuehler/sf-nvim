-- project.lua
-- Salesforce project deployment and retrieval utilities

local M = {}

local runner = require("sf-nvim.utils.runner")

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
-- Deploy project to org
-- -------------------------------------------------------------
function M.deploy()
	vim.cmd("botright split | terminal bash -c \"sf project deploy start; echo ''; read -p 'Press ENTER to close...'\"")
	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Retrieve metadata from org
-- -------------------------------------------------------------
function M.retrieve()
	vim.cmd(
		"botright split | terminal bash -c \"sf project retrieve start; echo ''; read -p 'Press ENTER to close...'\""
	)
	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Deploy with validation only (check only, no deploy)
-- -------------------------------------------------------------
function M.validate()
	vim.cmd(
		"botright split | terminal bash -c \"sf project deploy start --dry-run; echo ''; read -p 'Press ENTER to close...'\""
	)
	vim.cmd("startinsert")
end

return M
