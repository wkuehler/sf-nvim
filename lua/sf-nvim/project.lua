-- project.lua
-- Salesforce project deployment and retrieval utilities

local M = {}

local runner = require("sf-nvim.utils.runner")

-- -------------------------------------------------------------
-- Deploy project to org
-- -------------------------------------------------------------
---`sf project deploy start` in a terminal split.
function M.deploy()
	runner.term({ "sf", "project", "deploy", "start" })
end

-- -------------------------------------------------------------
-- Retrieve metadata from org
-- -------------------------------------------------------------
---`sf project retrieve start` in a terminal split.
function M.retrieve()
	runner.term({ "sf", "project", "retrieve", "start" })
end

-- -------------------------------------------------------------
-- Validate deployment (dry run, nothing is deployed)
-- -------------------------------------------------------------
---`sf project deploy start --dry-run` in a terminal split.
function M.validate()
	runner.term({ "sf", "project", "deploy", "start", "--dry-run" })
end

return M
