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

-- -------------------------------------------------------------
-- Background tail: `sf apex tail log` runs under vim.system, its output
-- is appended to the hidden `sf://log/tail` buffer, and each new log is
-- counted (the CLI prints a `NN.N APEX_CODE,...` header per log).
-- -------------------------------------------------------------
M.TAIL_BUFFER = "sf://log/tail"
M.TAIL_MAX_LINES = 5000

---@class SfTailState
---@field proc vim.SystemObj
---@field count integer      logs captured since start
---@field stopping boolean   set when the user asked to stop

---@type SfTailState|nil
M.tail_state = nil

---@return boolean
function M.tailing()
	return M.tail_state ~= nil
end

---@return integer
function M.tail_count()
	return M.tail_state and M.tail_state.count or 0
end

local function tail_buffer()
	local bufnr = vim.fn.bufnr(M.TAIL_BUFFER)
	if bufnr ~= -1 then
		return bufnr
	end
	bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, M.TAIL_BUFFER)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "apexlog"
	vim.bo[bufnr].modifiable = false
	vim.keymap.set(
		"n",
		"q",
		"<Cmd>close<CR>",
		{ buffer = bufnr, nowait = true, silent = true, desc = "sf-nvim: close" }
	)
	return bufnr
end

local function is_log_header(line)
	return line:match("^%d+%.%d+ APEX_CODE") ~= nil
end

---Append lines to the tail buffer, trim to TAIL_MAX_LINES, follow in any
---window whose cursor was on the last line.
---@param lines string[]
local function append(lines)
	local bufnr = tail_buffer()
	local last = vim.api.nvim_buf_line_count(bufnr)
	local empty = last == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
	local following = {}
	for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
		if vim.api.nvim_win_get_cursor(win)[1] == last then
			table.insert(following, win)
		end
	end
	vim.bo[bufnr].modifiable = true
	if empty then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	else
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
	end
	local total = vim.api.nvim_buf_line_count(bufnr)
	if total > M.TAIL_MAX_LINES then
		vim.api.nvim_buf_set_lines(bufnr, 0, total - M.TAIL_MAX_LINES, false, {})
		total = M.TAIL_MAX_LINES
	end
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].modified = false
	for _, win in ipairs(following) do
		pcall(vim.api.nvim_win_set_cursor, win, { total, 0 })
	end
end

local function tail_notify()
	local ok, sf = pcall(require, "sf-nvim")
	return not ok or sf.config.tail_notify ~= false
end

---Start tailing (no-op if already running).
function M.tail_start()
	if M.tail_state then
		return
	end
	local state = { count = 0, stopping = false }
	local proc = runner.stream({ "sf", "apex", "tail", "log" }, {
		on_line = function(line)
			if M.tail_state ~= state then
				return
			end
			append({ line })
			if is_log_header(line) then
				state.count = state.count + 1
				if tail_notify() then
					vim.notify(string.format("Debug log captured (#%d)", state.count), vim.log.levels.INFO)
				end
				vim.api.nvim_exec_autocmds("User", { pattern = "SfTailChanged", modeline = false })
			end
		end,
		on_exit = function(code, stderr)
			if M.tail_state ~= state then
				return
			end
			M.tail_state = nil
			vim.api.nvim_exec_autocmds("User", { pattern = "SfTailChanged", modeline = false })
			if not state.stopping then
				local detail = vim.trim(stderr)
				vim.notify(
					"Debug log tail stopped (exit " .. code .. ")" .. (detail ~= "" and ": " .. detail or ""),
					vim.log.levels.ERROR
				)
			end
		end,
	})
	if not proc then
		return
	end
	state.proc = proc
	M.tail_state = state
	local org = require("sf-nvim.org").target
	vim.notify(
		"Tailing debug logs" .. (org and (" for " .. org) or "") .. " — :Sf log show to view",
		vim.log.levels.INFO
	)
	vim.api.nvim_exec_autocmds("User", { pattern = "SfTailChanged", modeline = false })
end

---Stop tailing (no-op if not running).
function M.tail_stop()
	local state = M.tail_state
	if not state then
		return
	end
	state.stopping = true
	M.tail_state = nil
	pcall(function()
		state.proc:kill(15)
	end)
	vim.notify(string.format("Stopped tailing debug logs (%d captured)", state.count), vim.log.levels.INFO)
	vim.api.nvim_exec_autocmds("User", { pattern = "SfTailChanged", modeline = false })
end

---Toggle the background tail. `sf apex tail log` creates a trace flag for
---the running user if none is active, which is also what makes
---`list`/`latest` start returning logs.
function M.tail()
	if M.tail_state then
		M.tail_stop()
	else
		M.tail_start()
	end
end

---Open the tail buffer in a split (cursor at the end so it follows).
function M.show()
	local bufnr = tail_buffer()
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		vim.cmd("botright split")
		vim.api.nvim_win_set_buf(0, bufnr)
	else
		vim.api.nvim_set_current_win(win)
	end
	vim.cmd("normal! G")
	if not M.tail_state then
		vim.notify("Not tailing — :Sf log tail to start", vim.log.levels.WARN)
	end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = vim.api.nvim_create_augroup("SfLogTail", { clear = true }),
	callback = function()
		if M.tail_state then
			pcall(function()
				M.tail_state.proc:kill(15)
			end)
		end
	end,
})

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
