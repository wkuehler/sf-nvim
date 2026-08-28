-- soql.lua
-- Run SOQL queries and render the records as a table

local M = {}

local runner = require("sf-nvim.utils.runner")

-- -------------------------------------------------------------
-- Query text helpers
-- -------------------------------------------------------------
---Join buffer lines into one query: drop `//` and `--` comment lines, trailing `;`.
---@param lines string[]
---@return string
function M.normalize(lines)
	local kept = {}
	for _, l in ipairs(lines) do
		if not l:match("^%s*//") and not l:match("^%s*%-%-") then
			table.insert(kept, l)
		end
	end
	local q = table.concat(kept, " "):gsub("%s+", " ")
	q = vim.trim(q):gsub(";%s*$", "")
	return q
end

---Field list from the SELECT clause, subqueries removed, in query order.
---@param query string
---@return string[]
function M.select_fields(query)
	local q = query:gsub("%b()", "")
	local sel = q:match("^%s*[sS][eE][lL][eE][cC][tT]%s+(.-)%s+[fF][rR][oO][mM]%s")
	if not sel then
		return {}
	end
	local fields = {}
	for f in sel:gmatch("[^,]+") do
		f = vim.trim(f)
		-- "expr alias" → alias; "COUNT" (parens were stripped) → expr0-style key is unknown, keep token
		local alias = f:match("^%S+%s+([%w_]+)$")
		table.insert(fields, alias or f)
	end
	return fields
end

-- -------------------------------------------------------------
-- Records → columns/rows
-- -------------------------------------------------------------
local function is_subquery(v)
	return type(v) == "table" and v.records ~= nil and v.totalSize ~= nil
end

local function is_relationship(v)
	return type(v) == "table" and v.attributes ~= nil and v.records == nil
end

---Flatten one record: `Owner = { Name = x }` → `["Owner.Name"] = x`;
---subquery results → "[N rows]"; nil/null → "".
---@param record table
---@param prefix? string
---@param out? table<string, string>
---@return table<string, string>
function M.flatten(record, prefix, out)
	out = out or {}
	prefix = prefix or ""
	for k, v in pairs(record) do
		if k ~= "attributes" then
			local key = prefix .. k
			if v == vim.NIL or v == nil then
				out[key] = ""
			elseif is_subquery(v) then
				out[key] = string.format("[%d rows]", tonumber(v.totalSize) or #v.records)
			elseif is_relationship(v) then
				M.flatten(v, key .. ".", out)
			elseif type(v) == "table" then
				out[key] = vim.json.encode(v)
			else
				out[key] = tostring(v)
			end
		end
	end
	return out
end

---Column order: fields as written in the query first, then anything else alphabetically.
---@param rows table<string, string>[]
---@param query? string
---@return string[]
function M.columns(rows, query)
	local seen, cols = {}, {}
	local present = {}
	for _, row in ipairs(rows) do
		for k in pairs(row) do
			present[k] = true
		end
	end
	for _, f in ipairs(query and M.select_fields(query) or {}) do
		-- match case-insensitively against what the API returned
		for k in pairs(present) do
			if not seen[k] and k:lower() == f:lower() then
				seen[k] = true
				table.insert(cols, k)
			end
		end
	end
	local rest = {}
	for k in pairs(present) do
		if not seen[k] then
			table.insert(rest, k)
		end
	end
	table.sort(rest)
	vim.list_extend(cols, rest)
	return cols
end

---Render a query result as an aligned text table.
---@param data table   decoded `sf data query --json`
---@param query? string
---@return string[] lines
function M.render(data, query)
	local result = type(data) == "table" and data.result or nil
	if type(result) ~= "table" or type(result.records) ~= "table" then
		return { "== No result", tostring(type(data) == "table" and data.message or "") }
	end
	local rows = {}
	for _, rec in ipairs(result.records) do
		table.insert(rows, M.flatten(rec))
	end
	local cols = M.columns(rows, query)
	local width = {}
	for _, c in ipairs(cols) do
		width[c] = vim.fn.strdisplaywidth(c)
		for _, row in ipairs(rows) do
			width[c] = math.max(width[c], vim.fn.strdisplaywidth(row[c] or ""))
		end
	end
	local function line(cells)
		local parts = {}
		for _, c in ipairs(cols) do
			local v = cells[c] or ""
			table.insert(parts, v .. string.rep(" ", width[c] - vim.fn.strdisplaywidth(v)))
		end
		return table.concat(parts, "  ")
	end
	local sep = {}
	for _, c in ipairs(cols) do
		table.insert(sep, string.rep("-", width[c]))
	end

	local lines = {}
	if query then
		table.insert(lines, "-- " .. query)
	end
	table.insert(
		lines,
		string.format(
			"-- %d of %d row(s)%s",
			#rows,
			tonumber(result.totalSize) or #rows,
			result.done == false and " (more available)" or ""
		)
	)
	if #cols > 0 then
		local header = {}
		for _, c in ipairs(cols) do
			header[c] = c
		end
		table.insert(lines, line(header))
		table.insert(lines, table.concat(sep, "  "))
		for _, row in ipairs(rows) do
			table.insert(lines, line(row))
		end
	end
	return lines
end

-- -------------------------------------------------------------
-- Running
-- -------------------------------------------------------------
---Run a query in the background and show the result in `sf://query`.
---@param query string
function M.run(query)
	query = M.normalize({ query })
	if query == "" then
		vim.notify("Empty query", vim.log.levels.WARN)
		return
	end
	runner.json_async({ "sf", "data", "query", "--query", query, "--json" }, function(data, err)
		if not data then
			vim.notify("sf data query: " .. err, vim.log.levels.ERROR)
			return
		end
		if data.status ~= 0 or not (data.result and data.result.records) then
			local msg = tostring(data.message or data.name or "query failed")
			runner.scratch({
				name = "sf://query",
				filetype = "soqlresult",
				lines = vim.list_extend(
					{ "-- " .. query, "== " .. tostring(data.name or "Error") },
					vim.split(msg, "\n")
				),
			})
			vim.notify("SOQL: " .. (msg:match("[^\n]+$") or msg), vim.log.levels.ERROR)
			return
		end
		runner.scratch({ name = "sf://query", filetype = "soqlresult", lines = M.render(data, query) })
	end, { progress = "Running query..." })
end

---Run the whole buffer as a query.
function M.query_buffer()
	M.run(M.normalize(vim.api.nvim_buf_get_lines(0, 0, -1, false)))
end

---Run a line range (default: last visual selection) as a query.
---@param range? {integer, integer}
function M.query_selection(range)
	local first, last
	if range then
		first, last = range[1], range[2]
	else
		first, last = vim.fn.line("'<"), vim.fn.line("'>")
	end
	if first == 0 or last == 0 or last < first then
		vim.notify("No selection to run", vim.log.levels.WARN)
		return
	end
	M.run(M.normalize(vim.api.nvim_buf_get_lines(0, first - 1, last, false)))
end

---Prompt for a query and run it.
function M.query_prompt()
	vim.ui.input({ prompt = "SOQL: ", default = "SELECT Id, Name FROM " }, function(q)
		if q and q ~= "" then
			M.run(q)
		end
	end)
end

return M
