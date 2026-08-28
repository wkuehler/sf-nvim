-- Minimal init for running the test suite headlessly.
-- Usage: make test   (or see Makefile)
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

-- plenary.nvim: honour $PLENARY_DIR, else look in the usual lazy.nvim spot
local plenary = os.getenv("PLENARY_DIR") or (vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
if vim.fn.isdirectory(plenary) == 0 then
	error("plenary.nvim not found at " .. plenary .. " (set PLENARY_DIR)")
end
vim.opt.runtimepath:prepend(plenary)

vim.opt.swapfile = false
