-- health.lua
-- :checkhealth sf-nvim
--
-- Verifies the external pieces the plugin depends on: the `sf` CLI,
-- ripgrep, the Neovim version floor, and whether cwd looks like an SFDX project.

local M = {}

local health = vim.health

---@type { major: integer, minor: integer }
M.min_nvim = { major = 0, minor = 10 }

---@return string|nil version  first line of `<exe> --version`, or nil if it failed
local function version_of(argv)
	local out = vim.fn.system(argv)
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return vim.trim((out:gsub("\n.*", "")))
end

local function check_nvim()
	health.start("Neovim")
	local v = vim.version()
	local ver = string.format("%d.%d.%d", v.major, v.minor, v.patch)
	if v.major > M.min_nvim.major or (v.major == M.min_nvim.major and v.minor >= M.min_nvim.minor) then
		health.ok("Neovim " .. ver)
	else
		health.error(
			string.format("Neovim %s is below the supported floor (%d.%d)", ver, M.min_nvim.major, M.min_nvim.minor)
		)
	end
end

local function check_executable(name, purpose, install_hint)
	if vim.fn.executable(name) == 1 then
		local ver = version_of({ name, "--version" })
		health.ok(string.format("`%s` found: %s", name, ver or vim.fn.exepath(name)))
	else
		health.error(string.format("`%s` not found on PATH (%s)", name, purpose), { install_hint })
	end
end

local function check_tools()
	health.start("External tools")
	check_executable(
		"sf",
		"every command runs through the Salesforce CLI",
		"Install the Salesforce CLI: https://developer.salesforce.com/tools/salesforcecli"
	)
	check_executable(
		"rg",
		"used to locate Apex class files for the quickfix list",
		"Install ripgrep: https://github.com/BurntSushi/ripgrep#installation"
	)
end

local function check_project()
	health.start("Project")
	local cwd = vim.fn.getcwd()
	if vim.fn.filereadable(cwd .. "/sfdx-project.json") == 1 then
		health.ok("sfdx-project.json found in " .. cwd)
	else
		health.warn("No sfdx-project.json in " .. cwd, {
			"sf-nvim uses the current working directory as the project root",
			"Open Neovim from the root of an SFDX project",
		})
	end

	local defs = vim.fn.glob(cwd .. "/config/**/*-scratch-def.json", false, true)
	if #defs > 0 then
		health.ok(string.format("%d scratch org definition file(s) under config/", #defs))
	else
		health.warn("No config/**/*-scratch-def.json found (needed for `:Sf org create`)")
	end

	local ok, sf = pcall(require, "sf-nvim")
	if ok and sf.config then
		health.ok("Configured: test_results_dir=" .. tostring(sf.config.test_results_dir))
	end
end

function M.check()
	check_nvim()
	check_tools()
	check_project()
end

return M
