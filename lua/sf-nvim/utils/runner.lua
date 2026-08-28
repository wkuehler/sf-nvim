-- runner.lua
-- Shared command execution helpers.
--
-- Two styles:
--   * M.term    -- interactive terminal split; user watches output, presses ENTER to close
--   * M.capture -- synchronous capture (no shell involved when given an argv list)

local M = {}

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
-- The split stays open until the user presses ENTER.
-- -------------------------------------------------------------
---@class SfTermOpts
---@field on_exit? fun(code: integer)  called (scheduled) after the terminal closes
---@field no_wait? boolean             skip the "Press ENTER" pause
---@field position? string             window command prefix (default "botright")

---@param cmd string|string[]  shell string, or argv list (escaped for you)
---@param opts? SfTermOpts
---@return integer bufnr
function M.term(cmd, opts)
	opts = opts or {}
	if type(cmd) == "table" then
		cmd = M.shell_join(cmd)
	end
	if not opts.no_wait then
		cmd = cmd .. "; __sf_rc=$?; echo ''; read -p 'Press ENTER to close...'; exit $__sf_rc"
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

	vim.cmd("startinsert")
	return bufnr
end

-- -------------------------------------------------------------
-- Run a command synchronously and capture its output.
-- Prefer an argv list: it bypasses the shell entirely.
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
