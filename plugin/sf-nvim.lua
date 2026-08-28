-- plugin/sf-nvim.lua
-- Registers `:Sf` at startup so it exists before (or without) an explicit
-- require("sf-nvim").setup() call. The first invocation runs setup({}) with
-- defaults if the user has not called it; setup() then re-registers the
-- command with the same handler. Nothing else is loaded until then.
if vim.g.loaded_sf_nvim then
	return
end
vim.g.loaded_sf_nvim = true

vim.api.nvim_create_user_command("Sf", function(opts)
	local sf = require("sf-nvim")
	if not sf.did_setup then
		sf.setup({})
	end
	sf._command(opts)
end, {
	nargs = "+",
	range = true,
	complete = function(...)
		return require("sf-nvim")._complete(...)
	end,
	desc = "Salesforce CLI actions (:Sf <group> <action>)",
})
