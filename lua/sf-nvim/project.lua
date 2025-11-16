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
	runner.run({
		title = "Deploy Project",
		running = "Deploying...",
		cmd = { "sf", "project", "deploy", "start", "--concise" },
		format_output = format_apex_output,
	})
end

-- -------------------------------------------------------------
-- Retrieve metadata from org
-- -------------------------------------------------------------
function M.retrieve()
	runner.run({
		title = "Retrieve Project",
		running = "Retrieving...",
		cmd = { "sf", "project", "retrieve", "start", "--concise" },
		format_output = format_apex_output,
	})
end

-- -------------------------------------------------------------
-- Deploy with validation only (check only, no deploy)
-- -------------------------------------------------------------
function M.validate()
	runner.run({
		title = "Validate Deploy",
		running = "Validating...",
		cmd = { "sf", "project", "deploy", "start", "--concise", "--dry-run" },
		format_output = format_apex_output,
	})
end

-- -------------------------------------------------------------
-- Quick deploy a previously validated deployment
-- -------------------------------------------------------------
function M.quick_deploy(job_id)
	if not job_id or job_id == "" then
		vim.notify("Please provide a job ID", vim.log.levels.WARN, { title = "Quick Deploy" })
		return
	end

	runner.run({
		title = "Quick Deploy",
		running = "Quick deploying...",
		cmd = { "sf", "project", "deploy", "quick", "--job-id", job_id },
		format_output = format_apex_output,
	})
end

return M
