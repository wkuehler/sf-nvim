-- runner.lua
-- Shared command execution helpers.
--
-- Three styles:
--   * M.term    -- interactive terminal split; user watches output, presses ENTER to close.
--                  For long or chatty commands (tests, deploys, scratch org creation).
--   * M.run     -- async via vim.system(); result delivered to a callback on the main loop.
--                  For commands whose output is consumed by the plugin, not the user.
--   * M.capture -- synchronous; only for fast local tools (ripgrep) inside a callback.

local M = {}

local guard = require("sf-nvim.utils.guard")

-- -------------------------------------------------------------
-- Build a shell command string from an argv list, escaping each arg
-- -------------------------------------------------------------
---@param args string[]
---@return string
function M.shell_join(args)
	local out = {}
	for _, a in ipairs(args) do
		table.insert(out, vim.fn.shellescape(a))
	end
	return table.concat(out, " ")
end

-- -------------------------------------------------------------
-- Run a command in a terminal split at the bottom of the screen.
-- The split opens in Normal mode with the cursor on the last line, so
-- output is followed as it streams and can be scrolled with ordinary
-- motions at any time. When the command finishes it waits at a prompt;
-- <CR> or q (buffer-local, Normal mode) closes the split.
-- -------------------------------------------------------------
M.PROMPT = "[sf-nvim] Done. Press ENTER or q to close."

---@class SfTermOpts
---@field on_exit? fun(code: integer)  called (scheduled) after the terminal closes
---@field no_wait? boolean             skip the "Press ENTER" pause
---@field position? string             window command prefix (default "botright")

---@param cmd string|string[]  shell string, or argv list (escaped for you)
---@param opts? SfTermOpts
---@return integer|nil bufnr   nil if the executable is missing (already notified)
function M.term(cmd, opts)
	opts = opts or {}
	if type(cmd) == "table" then
		if not guard.executable(cmd[1]) then
			return nil
		end
		cmd = M.shell_join(cmd)
	end
	if not opts.no_wait then
		cmd = cmd .. "; __sf_rc=$?; echo ''; read -p " .. vim.fn.shellescape(M.PROMPT .. " ") .. "; exit $__sf_rc"
	end

	local position = opts.position or "botright"
	vim.cmd(string.format("%s split | terminal bash -c %s", position, vim.fn.shellescape(cmd)))
	local bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_create_autocmd("TermClose", {
		buffer = bufnr,
		once = true,
		callback = function(ev)
			local code = vim.v.event and vim.v.event.status or 0
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(ev.buf) then
					vim.api.nvim_buf_delete(ev.buf, { force = true })
				end
				if opts.on_exit then
					opts.on_exit(code)
				end
			end)
		end,
	})

	-- Stay in Normal mode; with the cursor on the last line Neovim keeps the
	-- view scrolled to new output, and the user can scroll freely at any time.
	vim.cmd("normal! G")

	local function close()
		local chan = vim.bo[bufnr].channel
		if chan and chan > 0 then
			-- Answers the `read` prompt; harmless if the command is still running.
			pcall(vim.api.nvim_chan_send, chan, "\r")
		end
	end
	local map_opts = { buffer = bufnr, nowait = true, silent = true }
	vim.keymap.set("n", "<CR>", close, vim.tbl_extend("force", map_opts, { desc = "sf-nvim: close" }))
	vim.keymap.set("n", "q", close, vim.tbl_extend("force", map_opts, { desc = "sf-nvim: close" }))
	-- If the user does enter Terminal mode (i), let <Esc> bring them back out.
	vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", vim.tbl_extend("force", map_opts, { desc = "sf-nvim: normal mode" }))

	return bufnr
end

-- -------------------------------------------------------------
-- Run a command asynchronously (vim.system, no shell).
-- The callback is invoked on the main loop, so it may touch UI.
-- -------------------------------------------------------------
---@class SfRunOpts
---@field on_exit? fun(code: integer, stdout: string, stderr: string)
---@field cwd? string
---@field progress? string   message shown via vim.notify while the command runs

---@param argv string[]
---@param opts? SfRunOpts
---@return vim.SystemObj|nil   nil if the executable is missing (already notified)
function M.run(argv, opts)
	opts = opts or {}
	if not guard.executable(argv[1]) then
		return nil
	end
	if opts.progress then
		vim.notify(opts.progress, vim.log.levels.INFO)
	end
	return vim.system(argv, { text = true, cwd = opts.cwd }, function(res)
		if opts.on_exit then
			vim.schedule(function()
				opts.on_exit(res.code, res.stdout or "", res.stderr or "")
			end)
		end
	end)
end

-- -------------------------------------------------------------
-- Run a command asynchronously and JSON-decode its stdout.
-- `sf --json` writes the payload to stdout even on failure, so the
-- decoded data is passed through whenever it parses; `err` is set
-- only when the output is not JSON at all.
-- -------------------------------------------------------------
---@param argv string[]
---@param cb fun(data: table|nil, err: string|nil)
---@param opts? SfRunOpts
---@return vim.SystemObj|nil
function M.json_async(argv, cb, opts)
	opts = opts or {}
	opts.on_exit = function(code, stdout, stderr)
		local ok, data = pcall(vim.json.decode, stdout)
		if not ok then
			local detail = vim.trim(stderr ~= "" and stderr or stdout)
			cb(nil, string.format("failed to parse JSON (exit %d): %s", code, detail))
			return
		end
		cb(data, nil)
	end
	return M.run(argv, opts)
end

-- -------------------------------------------------------------
-- Run a command synchronously and capture its output.
-- Blocks the UI: reserve for fast local tools. Prefer an argv
-- list: it bypasses the shell entirely.
-- -------------------------------------------------------------
---@param cmd string|string[]
---@return string output
---@return integer code
function M.capture(cmd)
	local output = vim.fn.system(cmd)
	return output, vim.v.shell_error
end

-- -------------------------------------------------------------
-- Run a command that emits JSON and decode it.
-- -------------------------------------------------------------
---@param cmd string|string[]
---@return table|nil data
---@return string|nil err
function M.json(cmd)
	local output, code = M.capture(cmd)
	local ok, data = pcall(vim.json.decode, output)
	if not ok then
		return nil, string.format("failed to parse JSON (exit %d): %s", code, vim.trim(output))
	end
	return data, nil
end

return M
