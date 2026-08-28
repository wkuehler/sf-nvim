local logs = require("sf-nvim.logs")
local runner = require("sf-nvim.utils.runner")
local sf = require("sf-nvim")

describe("runner.stream", function()
	it("delivers lines across chunk boundaries and reports exit", function()
		local lines, code = {}, nil
		runner.stream({ "sh", "-c", "printf 'a\\nb'; sleep 0.05; printf 'c\\nd\\n'; exit 2" }, {
			on_line = function(l)
				table.insert(lines, l)
			end,
			on_exit = function(c)
				code = c
			end,
		})
		assert.is_true(vim.wait(5000, function()
			return code ~= nil
		end, 10))
		assert.same({ "a", "bc", "d" }, lines)
		assert.equals(2, code)
	end)

	it("can be killed", function()
		local code
		local p = runner.stream({ "sh", "-c", "sleep 30" }, {
			on_line = function() end,
			on_exit = function(c)
				code = c
			end,
		})
		p:kill(15)
		assert.is_true(vim.wait(5000, function()
			return code ~= nil
		end, 10))
	end)
end)

describe("logs tail", function()
	local orig, notes, stream_opts, killed

	before_each(function()
		local org = require("sf-nvim.org")
		orig = { stream = runner.stream, notify = vim.notify, target = org.target, refresh = org.refresh_target }
		org.refresh_target = function() end
		notes, killed = {}, false
		vim.notify = function(m, l)
			table.insert(notes, { m = m, l = l })
		end
		runner.stream = function(argv, opts)
			assert.same({ "sf", "apex", "tail", "log" }, argv)
			stream_opts = opts
			return {
				kill = function()
					killed = true
				end,
			}
		end
		require("sf-nvim.org").target = "dev"
		local b = vim.fn.bufnr(logs.TAIL_BUFFER)
		if b ~= -1 then
			vim.api.nvim_buf_delete(b, { force = true })
		end
	end)
	after_each(function()
		logs.tail_state = nil
		runner.stream, vim.notify = orig.stream, orig.notify
		require("sf-nvim.org").target = orig.target
		require("sf-nvim.org").refresh_target = orig.refresh
	end)

	it("toggles, counts logs by header line, appends to the hidden buffer, and kills on stop", function()
		sf.setup()
		assert.equals("dev", sf.status())

		logs.tail()
		assert.is_true(logs.tailing())
		assert.truthy(notes[#notes].m:find("Tailing debug logs for dev", 1, true))
		assert.equals("dev ⏺ 0", sf.status())
		assert.equals(-1, vim.fn.bufwinid(vim.fn.bufnr(logs.TAIL_BUFFER))) -- hidden

		stream_opts.on_line("67.0 APEX_CODE,DEBUG;APEX_PROFILING,INFO")
		stream_opts.on_line("12:00:00.0 (1)|EXECUTION_STARTED")
		stream_opts.on_line("67.0 APEX_CODE,DEBUG;APEX_PROFILING,INFO")
		assert.equals(2, logs.tail_count())
		assert.equals("dev ⏺ 2", sf.status())
		assert.equals("Debug log captured (#2)", notes[#notes].m)
		local bufnr = vim.fn.bufnr(logs.TAIL_BUFFER)
		assert.equals(3, vim.api.nvim_buf_line_count(bufnr))
		assert.equals("apexlog", vim.bo[bufnr].filetype)
		assert.is_false(vim.bo[bufnr].modifiable)

		logs.tail()
		assert.is_true(killed)
		assert.is_false(logs.tailing())
		assert.truthy(notes[#notes].m:find("Stopped tailing debug logs (2 captured)", 1, true))
		assert.equals("dev", sf.status())
	end)

	it("respects tail_notify = false", function()
		sf.setup({ tail_notify = false })
		logs.tail()
		local n = #notes
		stream_opts.on_line("67.0 APEX_CODE,DEBUG")
		assert.equals(n, #notes)
		assert.equals(1, logs.tail_count())
	end)

	it("reports an unexpected exit as an error", function()
		sf.setup()
		logs.tail()
		stream_opts.on_exit(1, "ERROR running apex:tail:log: expired access/refresh token\n")
		assert.is_false(logs.tailing())
		assert.equals(vim.log.levels.ERROR, notes[#notes].l)
		assert.truthy(notes[#notes].m:find("expired access", 1, true))
	end)

	it("show opens the buffer in a split at the end and follows appends", function()
		sf.setup()
		logs.tail()
		for i = 1, 20 do
			stream_opts.on_line("line " .. i)
		end
		logs.show()
		local bufnr = vim.fn.bufnr(logs.TAIL_BUFFER)
		assert.equals(bufnr, vim.api.nvim_get_current_buf())
		assert.equals(20, vim.api.nvim_win_get_cursor(0)[1])
		stream_opts.on_line("line 21")
		assert.equals(21, vim.api.nvim_win_get_cursor(0)[1])
		vim.cmd("normal! gg")
		stream_opts.on_line("line 22")
		assert.equals(1, vim.api.nvim_win_get_cursor(0)[1]) -- not following once scrolled up
		vim.cmd("close")
	end)

	it("caps the buffer at TAIL_MAX_LINES", function()
		sf.setup({ tail_notify = false })
		local orig_max = logs.TAIL_MAX_LINES
		logs.TAIL_MAX_LINES = 5
		logs.tail()
		for i = 1, 8 do
			stream_opts.on_line("l" .. i)
		end
		assert.same(
			{ "l4", "l5", "l6", "l7", "l8" },
			vim.api.nvim_buf_get_lines(vim.fn.bufnr(logs.TAIL_BUFFER), 0, -1, false)
		)
		logs.TAIL_MAX_LINES = orig_max
	end)
end)

describe("org.refresh_target", function()
	it("caches the alias from sf config get and fires SfTargetChanged", function()
		local org = require("sf-nvim.org")
		local orig = runner.json_async
		runner.json_async = function(argv, cb)
			assert.same({ "sf", "config", "get", "target-org", "--json" }, argv)
			cb({
				status = 0,
				result = { { name = "target-org", key = "target-org", value = "issue123", success = true } },
			})
		end
		local fired = false
		vim.api.nvim_create_autocmd("User", {
			pattern = "SfTargetChanged",
			once = true,
			callback = function()
				fired = true
			end,
		})
		org.refresh_target()
		runner.json_async = orig
		assert.equals("issue123", org.target)
		assert.is_true(fired)

		runner.json_async = function(_, cb)
			cb({ status = 0, result = { { name = "target-org", key = "target-org", success = true } } })
		end
		org.refresh_target()
		runner.json_async = orig
		assert.is_nil(org.target)
	end)
end)
