-- runner.lua
-- Notification-based command runner with spinner

local M = {}

local frames = { "|", "/", "-", "\\" }

local function start_spinner(text, title, interval)
	local notify = require("notify")
	local uv = vim.uv or vim.loop

	local notif = notify(text, vim.log.levels.INFO, {
		title = title,
		icon = frames[1],
		timeout = false,
		hide_from_history = true,
	})

	local frame = 1
	local active = true
	local timer = uv.new_timer()
	timer:start(interval, interval, function()
		if not active then
			return
		end
		frame = (frame % #frames) + 1
		vim.schedule(function()
			if active then
				notif = notify(text, vim.log.levels.INFO, {
					title = title,
					icon = frames[frame],
					timeout = false,
					hide_from_history = true,
					replace = notif,
				})
			end
		end)
	end)

	local function stop()
		if not active then
			return
		end
		active = false
		timer:stop()
		timer:close()
	end

	local function current()
		return notif
	end

	return stop, current
end

local function collect_lines(accum, data)
	if not accum or not data then
		return
	end
	for _, line in ipairs(data) do
		if line ~= "" then
			table.insert(accum, line)
		end
	end
end

function M.run(opts)
	vim.validate({ opts = { opts, "table" }, cmd = { opts.cmd, { "string", "table" } } })

	local notify = require("notify")
	local title = opts.title or "Task"
	local running_text = opts.running or "Working..."
	local interval = opts.interval or 100
	local timeout = opts.timeout
	if timeout == nil then
		timeout = false
	end

	local stop_spinner, current_notif = start_spinner(running_text, title, interval)
	local stdout_accum = opts.collect_stdout == false and nil or {}
	local stderr_accum = opts.collect_stderr == false and nil or {}

	local function format_result(code)
		local stdout = stdout_accum and table.concat(stdout_accum, "\n") or ""
		local stderr = stderr_accum and table.concat(stderr_accum, "\n") or ""

		if opts.format_output then
			return opts.format_output(code, stdout, stderr)
		end

		if code == 0 then
			if stdout ~= "" then
				return stdout
			end
			return "Done."
		end

		if stderr ~= "" then
			return stderr
		end
		if stdout ~= "" then
			return stdout
		end
		return "Command failed."
	end

	local function finalize(code, message_override)
		stop_spinner()
		vim.schedule(function()
			local replace = current_notif()
			local message = message_override or format_result(code)
			local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
			notify(vim.trim(message), level, {
				title = title,
				timeout = timeout,
				replace = replace,
				hide_from_history = false,
			})
			if opts.on_done then
				opts.on_done(code, message)
			end
		end)
	end

	local job_opts = {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if opts.on_stdout then
				opts.on_stdout(data)
			end
			collect_lines(stdout_accum, data)
		end,
		on_stderr = function(_, data)
			if opts.on_stderr then
				opts.on_stderr(data)
			end
			collect_lines(stderr_accum, data)
		end,
		on_exit = function(_, code)
			if opts.on_exit then
				opts.on_exit(code)
			end
			finalize(code)
		end,
	}

	local job_id = vim.fn.jobstart(opts.cmd, job_opts)
	if job_id <= 0 then
		finalize(1, "Failed to start command.")
	end
end

return M
