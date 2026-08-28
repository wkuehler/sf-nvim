-- generate.lua
-- Metadata generators: `sf template generate ...`, then open the new file.

local M = {}

local runner = require("sf-nvim.utils.runner")
local guard = require("sf-nvim.utils.guard")

---@class SfGenKind
---@field label string
---@field argv string[]        command after `sf`, before --name/--output-dir
---@field subdir string        default output dir under <package>/main/default
---@field open string          pattern of the created file to open (Lua pattern on the basename)
---@field sobject? boolean     prompt for an sObject (triggers)

---@type table<string, SfGenKind>
M.kinds = {
	class = {
		label = "Apex class",
		argv = { "template", "generate", "apex", "class" },
		subdir = "classes",
		open = "%.cls$",
	},
	trigger = {
		label = "Apex trigger",
		argv = { "template", "generate", "apex", "trigger" },
		subdir = "triggers",
		open = "%.trigger$",
		sobject = true,
	},
	lwc = {
		label = "Lightning web component",
		argv = { "template", "generate", "lightning", "component", "--type", "lwc" },
		subdir = "lwc",
		open = "%.js$",
	},
	aura = {
		label = "Aura component",
		argv = { "template", "generate", "lightning", "component", "--type", "aura" },
		subdir = "aura",
		open = "%.cmp$",
	},
}

---Default output directory: `<first package dir>/main/default/<subdir>` if it
---exists, else the first one that does under any package dir, else the first
---package dir's `main/default/<subdir>`.
---@param kind SfGenKind
---@param cwd? string
---@return string
function M.default_dir(kind, cwd)
	local dirs = require("sf-nvim.project").source_dirs(cwd)
	if #dirs == 0 then
		return (cwd or vim.fn.getcwd()) .. "/" .. kind.subdir
	end
	for _, d in ipairs(dirs) do
		local candidate = d .. "/main/default/" .. kind.subdir
		if vim.fn.isdirectory(candidate) == 1 then
			return candidate
		end
	end
	return dirs[1] .. "/main/default/" .. kind.subdir
end

---Build the `sf` argv for a generator.
---@param kind SfGenKind
---@param name string
---@param dir string
---@param sobject? string
---@return string[]
function M.build_argv(kind, name, dir, sobject)
	local argv = { "sf" }
	vim.list_extend(argv, kind.argv)
	vim.list_extend(argv, { "--name", name, "--output-dir", dir })
	if kind.sobject and sobject and sobject ~= "" then
		vim.list_extend(argv, { "--sobject", sobject })
	end
	table.insert(argv, "--json")
	return argv
end

---From `sf template generate ... --json`, the absolute path of the file to open.
---@param data table
---@param kind SfGenKind
---@return string|nil
function M.created_file(data, kind)
	local r = type(data) == "table" and data.result or nil
	if type(r) ~= "table" or type(r.created) ~= "table" then
		return nil
	end
	local base = r.outputDir or "."
	for _, rel in ipairs(r.created) do
		if type(rel) == "string" and rel:match(kind.open) then
			return vim.fs.normalize(base .. "/" .. rel)
		end
	end
	return nil
end

---Prompt for a name (and sObject for triggers) and output dir, run the
---generator in the background, then edit the created file.
---@param kind_name "class"|"trigger"|"lwc"|"aura"
function M.generate(kind_name)
	local kind = M.kinds[kind_name]
	if not kind then
		vim.notify("Unknown generator: " .. tostring(kind_name), vim.log.levels.ERROR)
		return
	end
	if not (guard.project() and guard.executable("sf")) then
		return
	end
	vim.ui.input({ prompt = kind.label .. " name: " }, function(name)
		if not name or name == "" then
			return
		end
		if not name:match("^[%a_][%w_]*$") then
			vim.notify("Name must be an identifier (letters, digits, underscore)", vim.log.levels.ERROR)
			return
		end
		local function with_dir(sobject)
			vim.ui.input({ prompt = "Output directory: ", default = M.default_dir(kind), completion = "dir" }, function(dir)
				if not dir or dir == "" then
					return
				end
				vim.fn.mkdir(dir, "p")
				local argv = M.build_argv(kind, name, dir, sobject)
				runner.json_async(argv, function(data, err)
					if not data then
						vim.notify("Generate " .. name .. ": " .. err, vim.log.levels.ERROR)
						return
					end
					if data.status ~= 0 then
						vim.notify("Generate " .. name .. ": " .. tostring(data.message or "failed"), vim.log.levels.ERROR)
						return
					end
					local file = M.created_file(data, kind)
					local n = type(data.result.created) == "table" and #data.result.created or 0
					vim.notify(string.format("Created %s (%d file(s))", name, n), vim.log.levels.INFO)
					if file then
						vim.cmd.edit(vim.fn.fnameescape(file))
					end
				end, { progress = "Generating " .. kind.label .. " " .. name .. "..." })
			end)
		end
		if kind.sobject then
			vim.ui.input({ prompt = "sObject (e.g. Account): " }, function(sobject)
				if sobject == nil then
					return
				end
				with_dir(sobject)
			end)
		else
			with_dir(nil)
		end
	end)
end

return M
