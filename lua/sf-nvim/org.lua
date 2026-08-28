-- org.lua
-- Salesforce org management utilities

local M = {}

local runner = require("sf-nvim.utils.runner")

-- -------------------------------------------------------------
-- Open the default org in browser
-- -------------------------------------------------------------
function M.open()
	runner.term({ "sf", "org", "open" })
end

-- -------------------------------------------------------------
-- List all orgs
-- -------------------------------------------------------------
function M.list()
	runner.term({ "sf", "org", "list" })
end

-- -------------------------------------------------------------
-- Display org information
-- -------------------------------------------------------------
function M.display()
	runner.term({ "sf", "org", "display" })
end

-- -------------------------------------------------------------
-- Find scratch org definition files under <cwd>/config
-- -------------------------------------------------------------
---@return {label: string, path: string}[]
function M.find_scratch_defs()
	local cwd = vim.fn.getcwd()
	local config_dir = cwd .. "/config"
	if vim.fn.isdirectory(config_dir) == 0 then
		return {}
	end
	local items = {}
	for _, file in ipairs(vim.fn.glob(config_dir .. "/**/*-scratch-def.json", false, true)) do
		table.insert(items, { label = file:sub(#cwd + 2), path = file })
	end
	return items
end

-- -------------------------------------------------------------
-- Create scratch org
-- -------------------------------------------------------------
function M.create_scratch_org()
	local items = M.find_scratch_defs()
	if #items == 0 then
		vim.notify("No config/**/*-scratch-def.json files found in " .. vim.fn.getcwd(), vim.log.levels.ERROR)
		return
	end

	vim.ui.select(items, {
		prompt = "Select scratch org config file:",
		format_item = function(item)
			return item.label
		end,
	}, function(config_choice)
		if not config_choice then
			return
		end

		vim.ui.input({ prompt = "Duration (days, default 7): ", default = "7" }, function(duration)
			if not duration then
				return
			end
			if duration == "" then
				duration = "7"
			end
			if not tonumber(duration) then
				vim.notify("Duration must be a number", vim.log.levels.ERROR)
				return
			end

			vim.ui.input({ prompt = "Org alias: " }, function(alias)
				if not alias or alias == "" then
					vim.notify("Alias is required", vim.log.levels.ERROR)
					return
				end

				runner.term({
					"sf", "org", "create", "scratch",
					"--definition-file", config_choice.path,
					"--duration-days", duration,
					"--alias", alias,
				})
			end)
		end)
	end)
end

return M
