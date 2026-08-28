local project = require("sf-nvim.project")

local fixtures = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures"
local function load_fixture(name)
	local f = assert(io.open(fixtures .. "/" .. name, "r"))
	local content = f:read("*all")
	f:close()
	return vim.json.decode(content)
end

describe("project.parse_deploy_result", function()
	it("turns failed files into quickfix items and summarises", function()
		local items, summary = project.parse_deploy_result(load_fixture("deploy_failed.json"))
		assert.is_false(summary.success)
		assert.equals("Failed", summary.status)
		assert.equals(4, summary.errors)
		assert.equals(4, #items) -- 3 Apex + 1 field; the Changed file is excluded
		assert.equals("/home/dev/my-project/force-app/main/default/classes/SfNvimProbe.cls", items[1].filename)
		assert.equals(4, items[1].lnum)
		assert.equals(9, items[1].col)
		assert.truthy(items[1].text:find("undefinedThing", 1, true))
		assert.equals("E", items[1].type)
		-- no line/col on the field error → defaults to 1/1
		assert.equals(1, items[4].lnum)
		assert.equals(1, items[4].col)
	end)

	it("reports success with counts", function()
		local items, summary = project.parse_deploy_result(load_fixture("deploy_succeeded.json"))
		assert.same({}, items)
		assert.is_true(summary.success)
		assert.equals(1, summary.deployed)
	end)

	it("returns no summary for payloads without a deploy result", function()
		local items, summary = project.parse_deploy_result({ status = 1, name = "NoOrg", message = "boom" })
		assert.same({}, items)
		assert.is_nil(summary)
		assert.is_nil(select(2, project.parse_deploy_result(nil)))
	end)
end)

describe("project.report_deploy", function()
	local notes, orig_notify
	before_each(function()
		notes = {}
		orig_notify = vim.notify
		vim.notify = function(m, level)
			table.insert(notes, { m = m, level = level })
		end
		vim.fn.setqflist({}, "r")
	end)
	after_each(function()
		vim.notify = orig_notify
		vim.cmd("cclose")
	end)

	it("fills quickfix on failure", function()
		assert.is_true(project.report_deploy(load_fixture("deploy_failed.json"), "Deploy X"))
		assert.equals(4, #vim.fn.getqflist())
		assert.equals("Deploy failures", vim.fn.getqflist({ title = 1 }).title)
		assert.equals(vim.log.levels.ERROR, notes[1].level)
		assert.truthy(notes[1].m:find("4 error", 1, true))
	end)

	it("notifies on success without touching quickfix", function()
		assert.is_false(project.report_deploy(load_fixture("deploy_succeeded.json"), "Deploy X"))
		assert.equals(0, #vim.fn.getqflist())
		assert.equals(vim.log.levels.INFO, notes[1].level)
	end)

	it("surfaces CLI error payloads", function()
		assert.is_false(project.report_deploy({ status = 1, message = "No default org" }, "Deploy X"))
		assert.truthy(notes[1].m:find("No default org", 1, true))
	end)
end)

describe("project source paths", function()
	local dir
	before_each(function()
		dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/force-app/main/default/classes", "p")
		vim.fn.mkdir(dir .. "/force-app/main/default/lwc/myCmp", "p")
		vim.fn.mkdir(dir .. "/pkg2/main/default/aura/myApp", "p")
		vim.fn.writefile(
			{ '{"packageDirectories":[{"path":"force-app","default":true},{"path":"pkg2"}]}' },
			dir .. "/sfdx-project.json"
		)
		vim.fn.writefile({ "public class A {}" }, dir .. "/force-app/main/default/classes/A.cls")
		vim.fn.writefile({ "<x/>" }, dir .. "/force-app/main/default/classes/A.cls-meta.xml")
	end)
	after_each(function()
		vim.fn.delete(dir, "rf")
	end)

	it("reads package directories from sfdx-project.json", function()
		assert.same({ dir .. "/force-app", dir .. "/pkg2" }, project.source_dirs(dir))
		assert.same({}, project.source_dirs(dir .. "/nope"))
	end)

	it("recognises files under a package directory", function()
		assert.is_true(project.is_source_file(dir .. "/force-app/main/default/classes/A.cls", dir))
		assert.is_true(project.is_source_file(dir .. "/pkg2/x.cls", dir))
		assert.is_false(project.is_source_file(dir .. "/scripts/x.apex", dir))
		assert.is_false(project.is_source_file(dir .. "/force-app-other/x.cls", dir))
	end)

	it("maps bundle members to the bundle and meta files to their companion", function()
		local cls = dir .. "/force-app/main/default/classes/A.cls"
		assert.equals(cls, project.source_path_for(cls))
		assert.equals(cls, project.source_path_for(cls .. "-meta.xml"))
		assert.equals(
			dir .. "/force-app/main/default/lwc/myCmp",
			project.source_path_for(dir .. "/force-app/main/default/lwc/myCmp/myCmp.js")
		)
		assert.equals(
			dir .. "/pkg2/main/default/aura/myApp",
			project.source_path_for(dir .. "/pkg2/main/default/aura/myApp/myApp.cmp")
		)
		-- a lone meta file with no companion is deployed as-is
		local field = dir .. "/force-app/main/default/objects/Account/fields/F__c.field-meta.xml"
		assert.equals(field, project.source_path_for(field))
	end)

	it("deploy_file refuses files outside the project and passes --source-dir otherwise", function()
		local runner = require("sf-nvim.utils.runner")
		local orig = { json_async = runner.json_async, notify = vim.notify, cwd = vim.fn.getcwd() }
		local argv, notes = nil, {}
		runner.json_async = function(a)
			argv = a
		end
		vim.notify = function(m)
			table.insert(notes, m)
		end
		vim.cmd("cd " .. vim.fn.fnameescape(dir))

		project.deploy_file(dir .. "/scripts/x.apex")
		assert.is_nil(argv)
		assert.truthy(notes[1]:find("Not under a package directory", 1, true))

		project.deploy_file(dir .. "/force-app/main/default/lwc/myCmp/myCmp.js")
		assert.same({
			"sf",
			"project",
			"deploy",
			"start",
			"--source-dir",
			dir .. "/force-app/main/default/lwc/myCmp",
			"--json",
		}, argv)

		vim.cmd("cd " .. vim.fn.fnameescape(orig.cwd))
		runner.json_async, vim.notify = orig.json_async, orig.notify
	end)

	it("deploy_on_save deploys only project source files on write", function()
		local deployed = {}
		local orig_deploy = project.deploy_file
		project.deploy_file = function(p)
			table.insert(deployed, p)
		end
		local orig_cwd = vim.fn.getcwd()
		vim.cmd("cd " .. vim.fn.fnameescape(dir))
		project.set_deploy_on_save(true)

		vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/force-app/main/default/classes/A.cls"))
		vim.cmd("write")
		vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/notes.txt"))
		vim.cmd("write")
		assert.same({ dir .. "/force-app/main/default/classes/A.cls" }, deployed)

		project.set_deploy_on_save(false)
		vim.cmd("write")
		assert.equals(1, #deployed)

		project.deploy_file = orig_deploy
		vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
	end)
end)
