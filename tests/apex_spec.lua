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
