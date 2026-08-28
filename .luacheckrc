std = "luajit"
globals = { "vim" }
max_line_length = 120

files["tests/**/*_spec.lua"] = {
	globals = { "describe", "it", "before_each", "after_each", "assert" },
}
