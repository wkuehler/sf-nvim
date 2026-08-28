local gen = require("sf-nvim.generate")

describe("generate.build_argv", function()
	it("builds class / lwc / trigger commands", function()
		assert.same(
			{ "sf", "template", "generate", "apex", "class", "--name", "Foo", "--output-dir", "/x", "--json" },
			gen.build_argv(gen.kinds.class, "Foo", "/x")
		)
		assert.same({
			"sf", "template", "generate", "lightning", "component", "--type", "lwc",
			"--name", "myCmp", "--output-dir", "/x", "--json",
		}, gen.build_argv(gen.kinds.lwc, "myCmp", "/x"))
		assert.same({
			"sf", "template", "generate", "apex", "trigger",
			"--name", "AccTrg", "--output-dir", "/x", "--sobject", "Account", "--json",
		}, gen.build_argv(gen.kinds.trigger, "AccTrg", "/x", "Account"))
		-- sobject ignored for non-trigger kinds and when empty
		assert.equals(10, #gen.build_argv(gen.kinds.class, "Foo", "/x", "Account"))
		assert.equals(10, #gen.build_argv(gen.kinds.trigger, "Foo", "/x", ""))
	end)
end)

describe("generate.created_file", function()
	it("returns the primary created file, absolute", function()
		local data = { status = 0, result = { outputDir = "/p/classes", created = { "Foo.cls", "Foo.cls-meta.xml" } } }
		assert.equals("/p/classes/Foo.cls", gen.created_file(data, gen.kinds.class))
		local lwc = { status = 0, result = { outputDir = "/p/lwc", created = { "myCmp/myCmp.html", "myCmp/myCmp.js" } } }
		assert.equals("/p/lwc/myCmp/myCmp.js", gen.created_file(lwc, gen.kinds.lwc))
		assert.is_nil(gen.created_file({ status = 1 }, gen.kinds.class))
	end)
end)

describe("generate.default_dir", function()
	it("prefers an existing main/default/<subdir> under a package dir", function()
		local tmp = vim.fn.tempname()
		vim.fn.mkdir(tmp .. "/force-app/main/default/classes", "p")
		vim.fn.writefile({ '{"packageDirectories":[{"path":"force-app"}]}' }, tmp .. "/sfdx-project.json")
		assert.equals(tmp .. "/force-app/main/default/classes", gen.default_dir(gen.kinds.class, tmp))
		assert.equals(tmp .. "/force-app/main/default/lwc", gen.default_dir(gen.kinds.lwc, tmp))
		vim.fn.delete(tmp, "rf")
	end)
end)

describe("generate.generate", function()
	it("rejects non-identifier names before running anything", function()
		local guard = require("sf-nvim.utils.guard")
		local runner = require("sf-nvim.utils.runner")
		local op, oe, oi, on, oj = guard.project, guard.executable, vim.ui.input, vim.notify, runner.json_async
		guard.project = function()
			return true
		end
		guard.executable = function()
			return true
		end
		vim.ui.input = function(_, cb)
			cb("bad name")
		end
		local msgs = {}
		vim.notify = function(m)
			table.insert(msgs, m)
		end
		local ran = false
		runner.json_async = function()
			ran = true
		end
		gen.generate("class")
		assert.is_false(ran)
		assert.truthy(msgs[1]:find("identifier", 1, true))
		guard.project, guard.executable, vim.ui.input, vim.notify, runner.json_async = op, oe, oi, on, oj
	end)
end)
