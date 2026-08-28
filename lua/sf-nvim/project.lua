-- project.lua
-- Salesforce project deployment and retrieval utilities

local M = {}

local runner = require("sf-nvim.utils.runner")
local guard = require("sf-nvim.utils.guard")

-- -------------------------------------------------------------
-- Package directories from sfdx-project.json (absolute paths)
-- -------------------------------------------------------------
---@param cwd? string
---@return string[]
function M.source_dirs(cwd)
	cwd = cwd or vim.fn.getcwd()
	local f = io.open(cwd .. "/sfdx-project.json", "r")
	if not f then
		return {}
	end
	local ok, data = pcall(vim.json.decode, f:read("*all"))
	f:close()
	local dirs = {}
	if ok and type(data) == "table" and type(data.packageDirectories) == "table" then
		for _, pd in ipairs(data.packageDirectories) do
			if type(pd.path) == "string" then
				table.insert(dirs, vim.fs.normalize(cwd .. "/" .. pd.path))
			end
		end
	end
	return dirs
end

---True if `path` lives under one of the project's package directories.
---@param path string
---@param cwd? string
---@return boolean
function M.is_source_file(path, cwd)
	path = vim.fs.normalize(path)
	for _, dir in ipairs(M.source_dirs(cwd)) do
		if path:sub(1, #dir + 1) == dir .. "/" then
			return true
		end
	end
	return false
end

-- -------------------------------------------------------------
-- Resolve the path to hand to --source-dir for a buffer's file:
--   * inside an lwc/<name>/ or aura/<name>/ bundle → the bundle directory
--   * a -meta.xml companion → the file it describes (if present)
--   * otherwise the file itself
-- -------------------------------------------------------------
---@param path string absolute path
---@return string
function M.source_path_for(path)
	path = vim.fs.normalize(path)
	local bundle = path:match("^(.*/[la][wu][cr]a?/[^/]+)/[^/]+$")
	if bundle and (bundle:match("/lwc/[^/]+$") or bundle:match("/aura/[^/]+$")) then
		return bundle
	end
	local companion = path:match("^(.*)%-meta%.xml$")
	if companion and vim.fn.filereadable(companion) == 1 then
		return companion
	end
	return path
end

-- -------------------------------------------------------------
-- Parse `sf project deploy start --json` (or `deploy report --json`)
-- -------------------------------------------------------------
---@class SfDeploySummary
---@field success boolean
---@field status string
---@field errors integer
---@field deployed integer
---@field total integer

---@param data table decoded JSON
---@return table[] qf_items   quickfix entries for every failed file with a path
---@return SfDeploySummary|nil summary  nil when the payload has no deploy result
function M.parse_deploy_result(data)
	local result = type(data) == "table" and data.result or nil
	if type(result) ~= "table" or type(result.files) ~= "table" then
		return {}, nil
	end
	local items = {}
	for _, file in ipairs(result.files) do
		if file.state == "Failed" and file.filePath then
			table.insert(items, {
				filename = file.filePath,
				lnum = tonumber(file.lineNumber) or 1,
				col = tonumber(file.columnNumber) or 1,
				text = string.format("%s: %s", file.fullName or "?", file.error or "deploy failed"),
				type = "E",
			})
		end
	end
	return items,
		{
			success = result.success == true,
			status = tostring(result.status or (result.success and "Succeeded" or "Failed")),
			errors = tonumber(result.numberComponentErrors) or #items,
			deployed = tonumber(result.numberComponentsDeployed) or 0,
			total = tonumber(result.numberComponentsTotal) or 0,
		}
end

local function auto_open_quickfix()
	local ok, sf = pcall(require, "sf-nvim")
	return not ok or sf.config.auto_open_quickfix ~= false
end

---Load failures into quickfix and notify. Returns true if there were failures.
---@param data table
---@param what string  label for the notification
---@return boolean
function M.report_deploy(data, what)
	local items, summary = M.parse_deploy_result(data)
	if not summary then
		local msg = type(data) == "table" and (data.message or data.name) or nil
		vim.notify(string.format("%s: %s", what, msg or "no deploy result"), vim.log.levels.ERROR)
		return false
	end
	if summary.success then
		vim.notify(
			string.format("%s: %s (%d component(s))", what, summary.status, summary.deployed),
			vim.log.levels.INFO
		)
		return false
	end
	vim.fn.setqflist({}, "r", { title = "Deploy failures", items = items })
	vim.notify(
		string.format("%s: %s — %d error(s), %d in quickfix", what, summary.status, summary.errors, #items),
		vim.log.levels.ERROR
	)
	if #items > 0 and auto_open_quickfix() then
		vim.cmd("copen")
	end
	return true
end

-- -------------------------------------------------------------
-- Whole-project commands (terminal split). After a failed deploy,
-- `sf project deploy report` is fetched to fill quickfix.
-- -------------------------------------------------------------
local function term_deploy(argv, what)
	if not guard.project() then
		return
	end
	runner.term(argv, {
		on_exit = function(code)
			if code == 0 then
				return
			end
			runner.json_async({ "sf", "project", "deploy", "report", "--json" }, function(data)
				local items = data and M.parse_deploy_result(data) or {}
				if #items > 0 then
					M.report_deploy(data, what)
				end
			end)
		end,
	})
end

---`sf project deploy start` in a terminal split.
function M.deploy()
	term_deploy({ "sf", "project", "deploy", "start" }, "Deploy")
end

---`sf project retrieve start` in a terminal split.
function M.retrieve()
	if not guard.project() then
		return
	end
	runner.term({ "sf", "project", "retrieve", "start" })
end

---`sf project deploy start --dry-run` in a terminal split.
function M.validate()
	term_deploy({ "sf", "project", "deploy", "start", "--dry-run" }, "Validate")
end

-- -------------------------------------------------------------
-- Current-file commands (async; failures land in quickfix)
-- -------------------------------------------------------------
---@param path? string  defaults to the current buffer's file
---@return string|nil
local function current_source(path)
	path = path or vim.fn.expand("%:p")
	if path == "" then
		vim.notify("No file in the current buffer", vim.log.levels.WARN)
		return nil
	end
	if not M.is_source_file(path) then
		vim.notify("Not under a package directory of this project: " .. path, vim.log.levels.WARN)
		return nil
	end
	return M.source_path_for(path)
end

---Deploy the current file (or its lwc/aura bundle) with `--source-dir`.
---@param path? string
function M.deploy_file(path)
	if not guard.project() then
		return
	end
	local src = current_source(path)
	if not src then
		return
	end
	local label = vim.fn.fnamemodify(src, ":t")
	runner.json_async({ "sf", "project", "deploy", "start", "--source-dir", src, "--json" }, function(data, err)
		if not data then
			vim.notify("Deploy " .. label .. ": " .. err, vim.log.levels.ERROR)
			return
		end
		M.report_deploy(data, "Deploy " .. label)
	end, { progress = "Deploying " .. label .. "..." })
end

---Retrieve the current file (or its lwc/aura bundle) with `--source-dir`.
---@param path? string
function M.retrieve_file(path)
	if not guard.project() then
		return
	end
	local src = current_source(path)
	if not src then
		return
	end
	local label = vim.fn.fnamemodify(src, ":t")
	runner.json_async({ "sf", "project", "retrieve", "start", "--source-dir", src, "--json" }, function(data, err)
		if not data then
			vim.notify("Retrieve " .. label .. ": " .. err, vim.log.levels.ERROR)
			return
		end
		local result = data.result or {}
		if data.status == 0 then
			local n = type(result.files) == "table" and #result.files or 0
			vim.notify(string.format("Retrieved %s (%d file(s))", label, n), vim.log.levels.INFO)
			vim.cmd("checktime")
		else
			vim.notify("Retrieve " .. label .. ": " .. tostring(data.message or "failed"), vim.log.levels.ERROR)
		end
	end, { progress = "Retrieving " .. label .. "..." })
end

-- -------------------------------------------------------------
-- Deploy on save (opt-in via setup({ deploy_on_save = true }))
-- -------------------------------------------------------------
local augroup

---@param enable boolean
function M.set_deploy_on_save(enable)
	if augroup then
		vim.api.nvim_del_augroup_by_id(augroup)
		augroup = nil
	end
	if not enable then
		return
	end
	augroup = vim.api.nvim_create_augroup("SfDeployOnSave", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function(ev)
			local path = vim.api.nvim_buf_get_name(ev.buf)
			if path ~= "" and M.is_source_file(path) then
				M.deploy_file(path)
			end
		end,
	})
end

return M
