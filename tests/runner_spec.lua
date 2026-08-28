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
