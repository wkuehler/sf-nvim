-- set-config.lua
-- Salesforce config management (target-org, target-dev-hub)

local M = {}

-- -------------------------------------------------------------
-- Set SF config (target-org or target-dev-hub)
-- -------------------------------------------------------------
function M.set_default(config_key)
	-- Validate config_key
	if config_key ~= "target-org" and config_key ~= "target-dev-hub" then
		vim.notify("Invalid config key. Use 'target-org' or 'target-dev-hub'", vim.log.levels.ERROR)
		return
	end

	-- Get org list as JSON
	local handle = io.popen("sf org list --json 2>&1")
	if not handle then
		vim.notify("Failed to execute sf org list command", vim.log.levels.ERROR)
		return
	end

	local result = handle:read("*a")
	handle:close()

	-- Parse JSON
	local ok, data = pcall(vim.json.decode, result)
	if not ok then
		vim.notify("Failed to parse org list JSON: " .. tostring(data), vim.log.levels.ERROR)
		return
	end

	-- Check if we have orgs
	if not data.result or not data.result.nonScratchOrgs or #data.result.nonScratchOrgs == 0 then
		if not data.result or not data.result.scratchOrgs or #data.result.scratchOrgs == 0 then
			vim.notify("No orgs found", vim.log.levels.WARN)
			return
		end
	end

	-- Combine scratch and non-scratch orgs
	local orgs = {}
	if data.result.nonScratchOrgs then
		for _, org in ipairs(data.result.nonScratchOrgs) do
			table.insert(orgs, org)
		end
	end
	if data.result.scratchOrgs then
		for _, org in ipairs(data.result.scratchOrgs) do
			table.insert(orgs, org)
		end
	end

	if #orgs == 0 then
		vim.notify("No orgs found", vim.log.levels.WARN)
		return
	end

	-- Build options for vim.ui.select
	local items = {}
	for _, org in ipairs(orgs) do
		local label = org.alias or org.username
		if org.alias and org.username then
			label = string.format("%s (%s)", org.alias, org.username)
		end
		-- Add indicator for default orgs
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
		})
	end

	-- Show selection UI
	vim.ui.select(items, {
		prompt = string.format("Select %s:", config_key),
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if not choice then
			return
		end

		-- Use alias if available, otherwise username
		local org_identifier = choice.alias or choice.username

		-- Set the config
		local cmd = string.format("sf config set %s %s", config_key, vim.fn.shellescape(org_identifier))
		local set_handle = io.popen(cmd .. " 2>&1")
		if not set_handle then
			vim.notify("Failed to set " .. config_key, vim.log.levels.ERROR)
			return
		end

		local output = set_handle:read("*a")
		local exit_code = set_handle:close()

		if exit_code then
			vim.notify(string.format("Set %s to %s", config_key, org_identifier), vim.log.levels.INFO)
		else
			vim.notify(string.format("Failed to set %s: %s", config_key, output), vim.log.levels.ERROR)
		end
	end)
end

-- Convenience functions
function M.set_target_org()
	M.set_default("target-org")
end

function M.set_target_dev_hub()
	M.set_default("target-dev-hub")
end

return M
