-- logs.lua
-- Apex debug logs: list/open stored logs, and run anonymous Apex with its log

local M = {}

local runner = require("sf-nvim.utils.runner")

M.NO_LOGS = "No stored debug logs. :Sf log tail creates a trace flag."

-- -------------------------------------------------------------
-- Log list
-- -------------------------------------------------------------
---@class SfLogItem
---@field Id string
---@field StartTime string
---@field Operation string
---@field Status string
---@field LogLength integer
---@field DurationMilliseconds integer
---@field LogUser { Name: string }|nil

---@param item SfLogItem
---@return string
function M.format_log_item(item)
	local when = (item.StartTime or ""):gsub("%.%d+[+-]%d+$", ""):gsub("T", " ")
	local kb = math.floor(((tonumber(item.LogLength) or 0) / 1024) + 0.5)
	local user = item.LogUser and item.LogUser.Name or "?"
	return string.format(
		"%s  %-24s  %-8s  %4dKB %6dms  %s",
		when,
		(item.Operation or ""):sub(1, 24),
		(item.Status or ""):sub(1, 8),
		kb,
		tonumber(item.DurationMilliseconds) or 0,
		user
	)
end

---Pick a stored debug log and open it.
function M.list()
	runner.json_async({ "sf", "apex", "list", "log", "--json" }, function(data, err)
		if not data then
			vim.notify("sf apex list log: " .. err, vim.log.levels.ERROR)
			return
		end
		local items = type(data.result) == "table" and data.result or {}
		if #items == 0 then
			vim.notify(data.message or M.NO_LOGS, vim.log.levels.WARN)
			return
		end
		vim.ui.select(items, { prompt = "Debug log:", format_item = M.format_log_item }, function(choice)
			if choice then
				M.open(choice.Id)
			end
		end)
	end, { progress = "Listing debug logs..." })
end

local function show_log(name, stdout, stderr, code)
	if code ~= 0 then
		vim.notify("sf apex get log: " .. vim.trim(stderr ~= "" and stderr or stdout), vim.log.levels.ERROR)
		return
	end
	-- `sf apex get log` exits 0 with this text when nothing matches
	if vim.trim(stdout) == "No results found" then
		vim.notify(M.NO_LOGS, vim.log.levels.WARN)
		return
	end
	runner.scratch({ name = name, filetype = "apexlog", lines = vim.split(stdout, "\n", { trimempty = true }) })
end

---Open one stored log by Id in a scratch buffer.
---@param id string
function M.open(id)
	if not id:match("^[%w]+$") then
		vim.notify("Invalid log id: " .. tostring(id), vim.log.levels.ERROR)
		return
	end
	runner.run({ "sf", "apex", "get", "log", "--log-id", id }, {
		progress = "Fetching log " .. id .. "...",
		on_exit = function(code, stdout, stderr)
			show_log("sf://log/" .. id, stdout, stderr, code)
		end,
	})
end

---Open the most recent stored log.
function M.latest()
	runner.run({ "sf", "apex", "get", "log", "--number", "1" }, {
		progress = "Fetching latest log...",
		on_exit = function(code, stdout, stderr)
			show_log("sf://log/latest", stdout, stderr, code)
		end,
	})
end

---Stream logs live in a terminal split. `sf apex tail log` creates a
---trace flag for the running user if none is active, which is also what
---makes `list`/`latest` start returning logs.
function M.tail()
	runner.term({ "sf", "apex", "tail", "log", "--color" })
end

-- -------------------------------------------------------------
-- Anonymous Apex with its log
-- -------------------------------------------------------------
---@class SfApexRun
---@field success boolean
---@field compiled boolean
---@field problem string|nil        compile problem
---@field exception string|nil      runtime exception message
---@field stack string|nil
---@field line integer|nil
---@field column integer|nil
---@field logs string

---Normalise `sf apex run --json`: success lives in `result`, failures in `data`.
---@param data table
---@return SfApexRun|nil run   nil when the payload has neither
function M.parse_run_result(data)
	local r = type(data) == "table" and (data.result or data.data) or nil
	if type(r) ~= "table" or r.compiled == nil then
		return nil
	end
	local function nonempty(v)
		return (type(v) == "string" and v ~= "") and v or nil
	end
	local line, col = tonumber(r.line), tonumber(r.column)
	return {
		success = r.success == true,
		compiled = r.compiled == true,
		problem = nonempty(r.compileProblem),
		exception = nonempty(r.exceptionMessage),
		stack = nonempty(r.exceptionStackTrace),
		line = line and line > 0 and line or nil,
		column = col and col > 0 and col or nil,
		logs = type(r.logs) == "string" and r.logs or "",
	}
end

---Lines for the scratch buffer: a short header, then the log.
---@param run SfApexRun
---@return string[]
function M.render_run(run)
	local lines = {}
	if run.success then
		table.insert(lines, "== Anonymous Apex: success")
	elseif not run.compiled then
		table.insert(lines, string.format("== Compile error at line %s, column %s", run.line or "?", run.column or "?"))
		table.insert(lines, run.problem or "")
	else
		table.insert(lines, "== Runtime exception: " .. (run.exception or "?"))
		for _, l in ipairs(vim.split(run.stack or "", "\n", { trimempty = true })) do
			table.insert(lines, "   " .. l)
		end
	end
	table.insert(lines, "")
	vim.list_extend(lines, vim.split(run.logs, "\n", { trimempty = true }))
	return lines
end

---Run a file as anonymous Apex in the background and show the log.
---@param path string
---@param on_done? fun()
function M.debug_file(path, on_done)
	runner.json_async({ "sf", "apex", "run", "-f", path, "--json" }, function(data, err)
		if on_done then
			on_done()
		end
		if not data then
			vim.notify("sf apex run: " .. err, vim.log.levels.ERROR)
			return
		end
		local run = M.parse_run_result(data)
		if not run then
			vim.notify("sf apex run: " .. tostring(data.message or "no result"), vim.log.levels.ERROR)
			return
		end
		runner.scratch({ name = "sf://apex-run", filetype = "apexlog", lines = M.render_run(run) })
		if run.success then
			vim.notify("Anonymous Apex: success", vim.log.levels.INFO)
		elseif not run.compiled then
			vim.notify("Anonymous Apex: compile error — " .. (run.problem or ""), vim.log.levels.ERROR)
		else
			vim.notify("Anonymous Apex: " .. (run.exception or "runtime exception"), vim.log.levels.ERROR)
		end
	end, { progress = "Running anonymous Apex..." })
end

---Run the current file as anonymous Apex and show the log.
function M.debug()
	local path = vim.fn.expand("%:p")
	if path == "" then
		vim.notify("No file to execute", vim.log.levels.WARN)
		return
	end
	if vim.bo.modified then
		vim.notify("Buffer has unsaved changes; running the saved file", vim.log.levels.WARN)
	end
	M.debug_file(path)
end

---Run a line range as anonymous Apex and show the log.
---@param range? {integer, integer}
function M.debug_selection(range)
	local first, last
	if range then
		first, last = range[1], range[2]
	else
		first, last = vim.fn.line("'<"), vim.fn.line("'>")
	end
	if first == 0 or last == 0 or last < first then
		vim.notify("No selection to execute", vim.log.levels.WARN)
		return
	end
	local tmp = vim.fn.tempname() .. ".apex"
	vim.fn.writefile(vim.api.nvim_buf_get_lines(0, first - 1, last, false), tmp)
	M.debug_file(tmp, function()
		vim.fn.delete(tmp)
	end)
end

return M
