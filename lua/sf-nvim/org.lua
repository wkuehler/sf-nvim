-- org.lua
-- Salesforce org management utilities

local M = {}

-- -------------------------------------------------------------
-- Open the default org in browser
-- -------------------------------------------------------------
function M.open()
	vim.cmd("!sf org open")
end

-- -------------------------------------------------------------
-- List all orgs
-- -------------------------------------------------------------
function M.list()
	vim.cmd("!sf org list")
end

-- -------------------------------------------------------------
-- Display org information
-- -------------------------------------------------------------
function M.display()
	vim.cmd("!sf org display")
end

-- -------------------------------------------------------------
-- Login to an org (interactive)
-- -------------------------------------------------------------
function M.login_web()
	vim.cmd("!sf org login web")
end

-- -------------------------------------------------------------
-- Logout from an org (interactive)
-- -------------------------------------------------------------
function M.logout()
	vim.cmd("!sf org logout")
end

return M
