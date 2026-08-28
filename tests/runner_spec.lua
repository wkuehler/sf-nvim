local runner = require("sf-nvim.utils.runner")

local function wait_for(pred)
	assert.is_true(vim.wait(5000, pred, 10), "timed out waiting for async callback")
end

describe("runner.run", function()
	it("runs an argv list asynchronously and delivers code/stdout/stderr on the main loop", function()
		local got
		runner.run({ "sh", "-c", "echo out; echo err >&2; exit 3" }, {
			on_exit = function(code, stdout, stderr)
				got = { code = code, stdout = stdout, stderr = stderr, fast = vim.in_fast_event() }
			end,
		})
		assert.is_nil(got) -- has not blocked
		wait_for(function()
			return got ~= nil
		end)
		assert.equals(3, got.code)
		assert.equals("out\n", got.stdout)
		assert.equals("err\n", got.stderr)
		assert.is_false(got.fast)
	end)

	it("shows the progress message via vim.notify", function()
		local msgs = {}
		local orig = vim.notify
		vim.notify = function(m)
			table.insert(msgs, m)
		end
		local done = false
		runner.run({ "true" }, {
			progress = "Working...",
			on_exit = function()
				done = true
			end,
		})
		wait_for(function()
			return done
		end)
		vim.notify = orig
		assert.same({ "Working..." }, msgs)
	end)
end)

describe("runner.json_async", function()
	it("decodes JSON stdout", function()
		local data, err
		local done = false
		runner.json_async({ "sh", "-c", [[echo '{"result":{"ok":true}}']] }, function(d, e)
			data, err, done = d, e, true
		end)
		wait_for(function()
			return done
		end)
		assert.is_nil(err)
		assert.same({ result = { ok = true } }, data)
	end)

	it("reports non-JSON output with the exit code and stderr", function()
		local data, err
		local done = false
		runner.json_async({ "sh", "-c", "echo not json; echo boom >&2; exit 1" }, function(d, e)
			data, err, done = d, e, true
		end)
		wait_for(function()
			return done
		end)
		assert.is_nil(data)
		assert.equals("failed to parse JSON (exit 1): boom", err)
	end)
end)

describe("runner.term", function()
	it("opens in Normal mode at the last line, and <CR> / q close it once finished", function()
		local code
		local bufnr = runner.term({ "sh", "-c", "echo hello; exit 4" }, {
			on_exit = function(c)
				code = c
			end,
		})
		assert.equals(bufnr, vim.api.nvim_get_current_buf())
		assert.equals("terminal", vim.bo[bufnr].buftype)
		assert.equals("n", vim.fn.mode())
		assert.equals(vim.api.nvim_buf_line_count(bufnr), vim.api.nvim_win_get_cursor(0)[1])
		assert.truthy(vim.fn.maparg("<CR>", "n", false, true).buffer == 1)
		assert.truthy(vim.fn.maparg("q", "n", false, true).buffer == 1)
		assert.truthy(vim.fn.maparg("<Esc>", "t", false, true).buffer == 1)

		-- wait for the command to reach the prompt
		assert.is_true(vim.wait(5000, function()
			local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
			return text:find(runner.PROMPT, 1, true) ~= nil
		end, 20))

		vim.api.nvim_feedkeys("q", "x", false)
		assert.is_true(vim.wait(5000, function()
			return code ~= nil
		end, 20))
		assert.equals(4, code)
		assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
	end)
end)
