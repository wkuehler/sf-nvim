local logs = require("sf-nvim.logs")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"
local function load_fixture(name)
	local f = assert(io.open(fixtures .. "/" .. name, "r"))
	local content = f:read("*all")
	f:close()
	return vim.json.decode(content)
end

describe("logs.format_log_item", function()
	it("formats a list entry compactly", function()
		local item = load_fixture("apex_log_list.json").result[1]
		assert.equals(
			"2026-08-28 16:11:58  Api/ExecuteAnonymous      Success     12KB     34ms  Dev User",
			logs.format_log_item(item)
		)
	end)
end)

describe("logs.parse_run_result", function()
	it("reads a successful run from result", function()
		local run = logs.parse_run_result(load_fixture("apex_run_success.json"))
		assert.is_true(run.success)
		assert.is_true(run.compiled)
		assert.is_nil(run.problem)
		assert.is_nil(run.line)
		assert.truthy(run.logs:find("EXECUTION_STARTED", 1, true))
	end)

	it("reads a compile failure from data", function()
		local run = logs.parse_run_result(load_fixture("apex_run_compile_error.json"))
		assert.is_false(run.success)
		assert.is_false(run.compiled)
		assert.equals("Unexpected token '('.", run.problem)
		assert.equals(1, run.line)
		assert.equals(13, run.column)
		assert.equals("", run.logs)
	end)

	it("reads a runtime failure from data", function()
		local run = logs.parse_run_result(load_fixture("apex_run_runtime_error.json"))
		assert.is_false(run.success)
		assert.is_true(run.compiled)
		assert.equals("System.MathException: Divide by 0", run.exception)
		assert.equals("AnonymousBlock: line 1, column 1", run.stack)
		assert.truthy(run.logs:find("FATAL_ERROR", 1, true))
	end)

	it("returns nil for unrelated payloads", function()
		assert.is_nil(logs.parse_run_result({ status = 1, message = "No org" }))
		assert.is_nil(logs.parse_run_result(nil))
	end)
end)

describe("logs.render_run", function()
	it("puts a header before the log", function()
		local lines = logs.render_run(logs.parse_run_result(load_fixture("apex_run_runtime_error.json")))
		assert.equals("== Runtime exception: System.MathException: Divide by 0", lines[1])
		assert.equals("   AnonymousBlock: line 1, column 1", lines[2])
		assert.equals("", lines[3])
		assert.truthy(lines[4]:find("APEX_CODE", 1, true))

		lines = logs.render_run(logs.parse_run_result(load_fixture("apex_run_compile_error.json")))
		assert.equals("== Compile error at line 1, column 13", lines[1])
		assert.equals("Unexpected token '('.", lines[2])
	end)
end)

describe("logs.latest / logs.list with no stored logs", function()
	local runner = require("sf-nvim.utils.runner")
	local orig, notes
	before_each(function()
		orig = { run = runner.run, json_async = runner.json_async, notify = vim.notify }
		notes = {}
		vim.notify = function(m, l)
			table.insert(notes, { m = m, l = l })
		end
	end)
	after_each(function()
		runner.run, runner.json_async, vim.notify = orig.run, orig.json_async, orig.notify
	end)

	it("latest warns instead of opening a buffer on 'No results found'", function()
		runner.run = function(_, opts)
			opts.on_exit(0, "No results found\n", "")
		end
		logs.latest()
		assert.equals(-1, vim.fn.bufnr("sf://log/latest"))
		assert.equals(logs.NO_LOGS, notes[#notes].m)
		assert.equals(vim.log.levels.WARN, notes[#notes].l)
	end)

	it("list warns on an empty result", function()
		runner.json_async = function(_, cb)
			cb({ status = 0, result = {}, warnings = {} }, nil)
		end
		logs.list()
		assert.equals(logs.NO_LOGS, notes[#notes].m)
	end)
end)

describe("logs.debug_file", function()
	it("shows the log in sf://apex-run and notifies", function()
		local runner = require("sf-nvim.utils.runner")
		local orig = { json_async = runner.json_async, notify = vim.notify }
		local notes = {}
		vim.notify = function(m, l)
			table.insert(notes, { m = m, l = l })
		end
		runner.json_async = function(argv, cb)
			assert.same({ "sf", "apex", "run", "-f", "/tmp/x.apex", "--json" }, argv)
			cb(load_fixture("apex_run_success.json"), nil)
		end
		local done = false
		logs.debug_file("/tmp/x.apex", function()
			done = true
		end)
		runner.json_async, vim.notify = orig.json_async, orig.notify

		assert.is_true(done)
		local bufnr = vim.fn.bufnr("sf://apex-run")
		assert.is_true(bufnr > 0)
		assert.equals("apexlog", vim.bo[bufnr].filetype)
		assert.equals("== Anonymous Apex: success", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
		assert.equals(vim.log.levels.INFO, notes[#notes].l)
		vim.cmd("close")
	end)
end)
