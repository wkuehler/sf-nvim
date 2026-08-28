-- project.lua
-- Salesforce project deployment and retrieval utilities

local M = {}

local runner = require("sf-nvim.utils.runner")

-- -------------------------------------------------------------
-- Deploy project to org
-- -------------------------------------------------------------
function M.deploy()
	runner.term({ "sf", "project", "deploy", "start" })
end

-- -------------------------------------------------------------
-- Retrieve metadata from org
-- -------------------------------------------------------------
function M.retrieve()
	runner.term({ "sf", "project", "retrieve", "start" })
end

-- -------------------------------------------------------------
-- Validate deployment (dry run, nothing is deployed)
-- -------------------------------------------------------------
function M.validate()
	runner.term({ "sf", "project", "deploy", "start", "--dry-run" })
end

return M
