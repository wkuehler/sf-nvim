local apex = require("sf-nvim.apex")

describe("apex.find_test_method", function()
	local src = {
		"@IsTest",
		"private class MyTest {",
		"    @TestSetup",
		"    static void setup() {",
		"        insert new Account(Name = 'x');",
		"    }",
		"",
		"    @IsTest",
		"    static void shouldDoThing() {",
		"        System.assert(true);",
		"    }",
		"",
		"    static testMethod void legacyStyle() {",
		"        System.assert(true);",
		"    }",
		"",
		"    @isTest(SeeAllData=true)",
		"    private static void lowerCaseAnnotation() {",
		"    }",
		"",
		"    private static void helper() {",
		"    }",
		"}",
	}

	it("finds the enclosing @IsTest method from inside its body", function()
		assert.equals("shouldDoThing", apex.find_test_method(src, 10))
		assert.equals("shouldDoThing", apex.find_test_method(src, 9))
	end)

	it("accepts the testMethod keyword and lower-case annotations", function()
		assert.equals("legacyStyle", apex.find_test_method(src, 14))
		assert.equals("lowerCaseAnnotation", apex.find_test_method(src, 18))
	end)

	it("returns nil for non-test methods and setup", function()
		assert.is_nil(apex.find_test_method(src, 5)) -- @TestSetup is not a test
		assert.is_nil(apex.find_test_method(src, 22)) -- helper
		assert.is_nil(apex.find_test_method(src, 2)) -- class header
	end)
end)

describe("apex.execute_selection", function()
	it("writes the range to a temp .apex file and runs it", function()
		local runner = require("sf-nvim.utils.runner")
		local orig = runner.term
		local argv, content
		runner.term = function(a)
			argv = a
			content = vim.fn.readfile(a[5])
		end
		vim.cmd("enew")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "System.debug('x');", "line3" })
		apex.execute_selection({ 2, 3 })
		runner.term = orig
		assert.same({ "sf", "apex", "run", "-f" }, vim.list_slice(argv, 1, 4))
		assert.truthy(argv[5]:match("%.apex$"))
		assert.same({ "System.debug('x');", "line3" }, content)
		vim.fn.delete(argv[5])
		vim.cmd("bwipeout!")
	end)
end)

describe("apex.run_failed_tests", function()
	local runner = require("sf-nvim.utils.runner")
	local guard = require("sf-nvim.utils.guard")
	local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"
	local orig_term, orig_project, orig_exec, orig_cwd, orig_dir
	local calls, notes

	before_each(function()
		orig_term, orig_project, orig_exec = runner.term, guard.project, guard.executable
		orig_dir = apex.config.test_results_dir
		orig_cwd = vim.fn.getcwd()
		calls, notes = {}, {}
		runner.term = function(cmd, opts)
			table.insert(calls, cmd)
		end
		guard.project = function()
			return true
		end
		guard.executable = function()
			return true
		end
		vim.notify = function(msg, level)
			table.insert(notes, msg)
		end
		local tmp = vim.fn.tempname()
		vim.fn.mkdir(tmp .. "/results", "p")
		vim.cmd.cd(tmp)
		apex.config.test_results_dir = "results"
	end)

	after_each(function()
		runner.term, guard.project, guard.executable = orig_term, orig_project, orig_exec
		apex.config.test_results_dir = orig_dir
		vim.cmd.cd(orig_cwd)
	end)

	it("warns when there are no results", function()
		apex.run_failed_tests()
		assert.same({}, calls)
		assert.truthy(notes[1]:find("No test results", 1, true))
	end)

	it("reports when the latest run had no failures", function()
		vim.fn.writefile(vim.fn.readfile(fixtures .. "/apex_test_all_pass.json"), "results/a.json")
		apex.run_failed_tests()
		assert.same({}, calls)
		assert.truthy(notes[1]:find("No failures", 1, true))
	end)

	it("reruns each failed method with --tests", function()
		vim.fn.writefile(vim.fn.readfile(fixtures .. "/apex_test_failures.json"), "results/a.json")
		apex.run_failed_tests()
		assert.equals(1, #calls)
		local cmd = calls[1]
		local _, n = cmd:gsub("'%-%-tests' ", "")
		assert.equals(6, n) -- 3 targets x 2 invocations (json + plain)
		assert.truthy(cmd:find("AccountServiceTest.testUpdateFails", 1, true))
		assert.truthy(cmd:find("AccountServiceTest.testNoStackLine", 1, true))
		assert.truthy(cmd:find("MissingClassTest.testSomething", 1, true))
		assert.truthy(cmd:find("/results/failed_", 1, true))
		assert.truthy(notes[1]:find("Rerunning 3 failed tests", 1, true))
	end)
end)
