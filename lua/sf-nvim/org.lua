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
-- Pick an authenticated org (shared by open/delete)
-- -------------------------------------------------------------
---Fetch `sf org list --json` and let the user pick one.
---@param opts {prompt: string, scratch_only?: boolean}
---@param cb fun(item: SfOrgItem)
function M.pick(opts, cb)
	runner.json_async({ "sf", "org", "list", "--json" }, function(data, err)
		if not data then
			vim.notify("sf org list: " .. err, vim.log.levels.ERROR)
			return
		end
		local items = require("sf-nvim.set-config").build_org_items(data)
		if opts.scratch_only then
			items = vim.tbl_filter(function(i)
				return i.scratch
			end, items)
		end
		if #items == 0 then
			vim.notify(opts.scratch_only and "No scratch orgs found" or "No orgs found", vim.log.levels.WARN)
			return
		end
		vim.ui.select(items, {
			prompt = opts.prompt,
			format_item = function(item)
				return item.label
			end,
		}, function(choice)
			if choice then
				cb(choice)
			end
		end)
	end, { progress = "Loading orgs..." })
end

---Pick an org and open it in the browser (`sf org open --target-org`).
function M.open_pick()
	M.pick({ prompt = "Open org:" }, function(item)
		local id = item.alias or item.username
		runner.run({ "sf", "org", "open", "--target-org", id }, {
			progress = "Opening " .. id .. "...",
			on_exit = function(code, stdout, stderr)
				if code == 0 then
					vim.notify(vim.trim(stdout) ~= "" and vim.trim(stdout) or "Org opened", vim.log.levels.INFO)
				else
					vim.notify("sf org open failed: " .. vim.trim(stderr ~= "" and stderr or stdout), vim.log.levels.ERROR)
				end
			end,
		})
	end)
end

-- -------------------------------------------------------------
-- Log in to an org (web flow)
-- -------------------------------------------------------------
---Prompt for an alias, then `sf org login web` in a terminal split. Offers
---to make it the default target org. Refreshes the cached target on exit.
function M.login()
	if not guard.executable("sf") then
		return
	end
	vim.ui.input({ prompt = "Alias for the new org (optional): " }, function(alias)
		if alias == nil then
			return
		end
		local argv = { "sf", "org", "login", "web" }
		if alias ~= "" then
			vim.list_extend(argv, { "--alias", alias })
		end
		if vim.fn.confirm("Set it as the default target org?", "&Yes\n&No", 1) == 1 then
			table.insert(argv, "--set-default")
		end
		runner.term(argv, {
			on_exit = function(code)
				if code == 0 then
					M.refresh_target()
				end
			end,
		})
	end)
end

-- -------------------------------------------------------------
-- Delete a scratch org
-- -------------------------------------------------------------
---Pick a scratch org, confirm, then `sf org delete scratch --no-prompt`.
function M.delete_scratch()
	M.pick({ prompt = "Delete scratch org:", scratch_only = true }, function(item)
		local id = item.alias or item.username
		local q = string.format("Delete scratch org %s? This cannot be undone.", item.label)
		if vim.fn.confirm(q, "&Delete\n&Cancel", 2) ~= 1 then
			return
		end
		runner.run({ "sf", "org", "delete", "scratch", "--target-org", id, "--no-prompt" }, {
			progress = "Deleting " .. id .. "...",
			on_exit = function(code, stdout, stderr)
				if code == 0 then
					vim.notify("Deleted scratch org " .. id, vim.log.levels.INFO)
					M.refresh_target()
				else
					vim.notify("Delete failed: " .. vim.trim(stderr ~= "" and stderr or stdout), vim.log.levels.ERROR)
				end
			end,
		})
	end)
end

-- -------------------------------------------------------------
-- Org limits
-- -------------------------------------------------------------
---Render `sf org list limits --json` as aligned lines: name, used/max, remaining.
---@param data table
---@return string[]
function M.render_limits(data)
	local rows = type(data) == "table" and type(data.result) == "table" and data.result or {}
	local lines = { string.format("%-45s %14s %14s %8s", "LIMIT", "USED", "MAX", "USED%") }
	local seen = false
	for _, r in ipairs(rows) do
		if type(r) == "table" and type(r.name) == "string" and tonumber(r.max) then
			seen = true
			local max, rem = tonumber(r.max), tonumber(r.remaining) or 0
			local used = max - rem
			local pct = max > 0 and string.format("%.0f%%", used / max * 100) or "-"
			table.insert(lines, string.format("%-45s %14d %14d %8s", r.name, used, max, pct))
		end
	end
	if not seen then
		return { "No limits returned" }
	end
	return lines
end

---Show the target org's limits in the `sf://limits` scratch buffer.
function M.limits()
	runner.json_async({ "sf", "org", "list", "limits", "--json" }, function(data, err)
		if not data then
			vim.notify("sf org list limits: " .. err, vim.log.levels.ERROR)
			return
		end
		runner.scratch({ name = "sf://limits", lines = M.render_limits(data) })
	end, { progress = "Fetching org limits..." })
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
