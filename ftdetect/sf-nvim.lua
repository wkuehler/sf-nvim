-- Salesforce filetypes. `.cls` and `.trigger` are only claimed inside an SFDX
-- project (an sfdx-project.json above the file) so other languages' .cls
-- files are left alone.
local function in_sfdx_project(path)
	return #vim.fs.find("sfdx-project.json", { upward = true, path = vim.fs.dirname(path) }) > 0
end

vim.filetype.add({
	extension = {
		soql = "soql",
		apex = "apex",
		apexlog = "apexlog",
		trigger = function(path)
			return in_sfdx_project(path) and "apex" or nil
		end,
		cls = function(path)
			return in_sfdx_project(path) and "apex" or nil
		end,
	},
})
