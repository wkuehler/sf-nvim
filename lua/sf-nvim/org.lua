-- org.lua
-- Salesforce org management utilities

local M = {}

-- -------------------------------------------------------------
-- Open the default org in browser
-- -------------------------------------------------------------
function M.open()
	vim.cmd("botright split | terminal bash -c \"sf org open; echo ''; read -p 'Press ENTER to close...'\"")
	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- List all orgs
-- -------------------------------------------------------------
function M.list()
	-- Open in terminal for better output visibility
	vim.cmd("botright split | terminal bash -c \"sf org list; echo ''; read -p 'Press ENTER to close...'\"")
	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Display org information
-- -------------------------------------------------------------
function M.display()
	vim.cmd("botright split | terminal bash -c \"sf org display; echo ''; read -p 'Press ENTER to close...'\"")
	vim.cmd("startinsert")
end

-- -------------------------------------------------------------
-- Create scratch org
-- -------------------------------------------------------------
function M.create_scratch_org()
	-- Find config directory
	local config_dir = vim.fn.getcwd() .. "/config"
	if vim.fn.isdirectory(config_dir) == 0 then
		vim.notify("No config directory found in project root", vim.log.levels.ERROR)
		return
	end

	-- Get list of config files
	local config_files = vim.fn.glob(config_dir .. "/**/*-scratch-def.json", false, true)
	if #config_files == 0 then
		vim.notify("No scratch org config files found in config directory", vim.log.levels.WARN)
		return
	end

	-- Make paths relative for display
	local items = {}
	for _, file in ipairs(config_files) do
		local relative = file:gsub(vim.fn.getcwd() .. "/", "")
		table.insert(items, {
			label = relative,
			path = file,
		})
	end

	-- Step 1: Select config file
	vim.ui.select(items, {
		prompt = "Select scratch org config file:",
		format_item = function(item)
			return item.label
		end,
	}, function(config_choice)
		if not config_choice then
			return
		end

		-- Step 2: Ask for duration in days
		vim.ui.input({
			prompt = "Duration (days, default 7): ",
			default = "7",
		}, function(duration)
			if not duration or duration == "" then
				duration = "7"
			end

			-- Validate duration is a number
			if not tonumber(duration) then
				vim.notify("Duration must be a number", vim.log.levels.ERROR)
				return
			end

			-- Step 3: Ask for alias
			vim.ui.input({
				prompt = "Org alias: ",
			}, function(alias)
				if not alias or alias == "" then
					vim.notify("Alias is required", vim.log.levels.ERROR)
					return
				end

				-- Build and execute command
				local cmd = string.format(
					'sf org create scratch --definition-file "%s" --duration-days %s --alias "%s"; echo ""; read -p "Press ENTER to close..."',
					config_choice.path,
					duration,
					alias
				)

				vim.cmd("botright split | terminal bash -c " .. vim.fn.shellescape(cmd))
				vim.cmd("startinsert")
			end)
		end)
	end)
end

return M
