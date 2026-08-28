-- org.lua
-- Salesforce org management utilities

local M = {}

local runner = require("sf-nvim.utils.runner")
local guard = require("sf-nvim.utils.guard")

-- -------------------------------------------------------------
-- Target org, cached for the statusline
-- -------------------------------------------------------------
---@type string|nil  alias or username of target-org, nil if unknown/unset
M.target = nil

---@param value string|nil
function M.set_target(value)
	M.target = value
	vim.api.nvim_exec_autocmds("User", { pattern = "SfTargetChanged", modeline = false })
end

---Refresh `M.target` from `sf config get target-org` in the background.
---@param cb? fun(target: string|nil)
function M.refresh_target(cb)
	runner.json_async({ "sf", "config", "get", "target-org", "--json" }, function(data)
		local value
		local r = data and data.result
		if type(r) == "table" and type(r[1]) == "table" and type(r[1].value) == "string" then
			value = r[1].value
		end
		M.set_target(value)
		if cb then
			cb(value)
		end
	end)
end

-- -------------------------------------------------------------
-- Open the default org in browser
-- -------------------------------------------------------------
---`sf org open` in the background; notifies with the URL or the error.
function M.open()
	runner.run({ "sf", "org", "open" }, {
		progress = "Opening org...",
		on_exit = function(code, stdout, stderr)
			if code == 0 then
				vim.notify(vim.trim(stdout) ~= "" and vim.trim(stdout) or "Org opened", vim.log.levels.INFO)
			else
				vim.notify("sf org open failed: " .. vim.trim(stderr ~= "" and stderr or stdout), vim.log.levels.ERROR)
			end
		end,
	})
end

-- -------------------------------------------------------------
-- List all orgs
-- -------------------------------------------------------------
---`sf org list` in a terminal split.
function M.list()
	runner.term({ "sf", "org", "list" })
end

-- -------------------------------------------------------------
-- Display org information
-- -------------------------------------------------------------
---`sf org display` in a terminal split.
function M.display()
	runner.term({ "sf", "org", "display" })
end

-- -------------------------------------------------------------
-- Find scratch org definition files under <cwd>/config
-- -------------------------------------------------------------
---@class SfScratchDef
---@field label string  path relative to cwd, for display
---@field path string   absolute path

---@return SfScratchDef[]
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
---Prompt for definition file, duration and alias, then `sf org create scratch`.
function M.create_scratch_org()
	if not guard.project() then
		return
	end
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
					"sf",
					"org",
					"create",
					"scratch",
					"--definition-file",
					config_choice.path,
					"--duration-days",
					duration,
					"--alias",
					alias,
				})
			end)
		end)
	end)
end

return M
