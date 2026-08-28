.PHONY: test test-file lint fmt fmt-check

# Run the whole suite (plenary.nvim required; set PLENARY_DIR if not under lazy.nvim)
test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }"

# Run a single spec: make test-file FILE=tests/quickfix_spec.lua
test-file:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile $(FILE)"

lint:
	luacheck lua/ tests/

fmt:
	stylua lua/ tests/

fmt-check:
	stylua --check lua/ tests/
