-- set-config.lua
-- Salesforce config management (target-org, target-dev-hub)

local M = {}

local runner = require("sf-nvim.utils.runner")

local VALID_KEYS = { ["target-org"] = true, ["target-dev-hub"] = true }

-- -------------------------------------------------------------
-- Turn `sf org list --json` output into selectable items
-- -------------------------------------------------------------
---@class SfOrgItem
---@field label string
---@field alias string|nil
---@field username string
---@field scratch boolean

---@param data table decoded JSON from `sf org list --json`
---@return SfOrgItem[]
function M.build_org_items(data)
	local items = {}
	local result = type(data) == "table" and data.result or nil
	if type(result) ~= "table" then
		return items
	end

	for _, group in ipairs({ "nonScratchOrgs", "scratchOrgs" }) do
		for _, org in ipairs(result[group] or {}) do
			if org.username then
				local label = org.alias and string.format("%s (%s)", org.alias, org.username) or org.username
				if org.isDefaultUsername then
					label = label .. " [default org]"
				end
				if org.isDefaultDevHubUsername then
					label = label .. " [default hub]"
				end
				table.insert(items, {
					label = label,
					alias = org.alias,
					username = org.username,
					scratch = group == "scratchOrgs",
				})
			end
		end
	end
	return items
end

-- -------------------------------------------------------------
-- Set SF config (target-org or target-dev-hub)
-- -------------------------------------------------------------
---@param config_key "target-org"|"target-dev-hub"
function M.set_default(config_key)
	if not VALID_KEYS[config_key] then
		vim.notify("Invalid config key. Use 'target-org' or 'target-dev-hub'", vim.log.levels.ERROR)
		return
	end

	runner.json_async({ "sf", "org", "list", "--json" }, function(data, err)
		if not data then
			vim.notify("sf org list: " .. err, vim.log.levels.ERROR)
			return
		end

		local items = M.build_org_items(data)
		if #items == 0 then
			vim.notify("No orgs found", vim.log.levels.WARN)
			return
		end

		vim.ui.select(items, {
			prompt = string.format("Select %s:", config_key),
			format_item = function(item)
				return item.label
			end,
		}, function(choice)
			if not choice then
				return
			end
			M.apply(config_key, choice.alias or choice.username)
		end)
	end, { progress = "Loading orgs..." })
end

-- -------------------------------------------------------------
-- `sf config set <key> <value>` asynchronously, notifying on completion
-- -------------------------------------------------------------
---@param config_key "target-org"|"target-dev-hub"
---@param org_identifier string  alias or username
function M.apply(config_key, org_identifier)
	runner.run({ "sf", "config", "set", config_key, org_identifier }, {
		on_exit = function(code, stdout, stderr)
			if code == 0 then
				vim.notify(string.format("Set %s to %s", config_key, org_identifier), vim.log.levels.INFO)
				if config_key == "target-org" then
					require("sf-nvim.org").set_target(org_identifier)
				end
			else
				local detail = vim.trim(stderr ~= "" and stderr or stdout)
				vim.notify(string.format("Failed to set %s: %s", config_key, detail), vim.log.levels.ERROR)
			end
		end,
	})
end

function M.set_target_org()
	M.set_default("target-org")
end

function M.set_target_dev_hub()
	M.set_default("target-dev-hub")
end

return M
