local health = require("sf-nvim.health")

describe("health", function()
	it("exposes a check function", function()
		assert.is_function(health.check)
	end)

	it("runs without error", function()
		assert.has_no.errors(function()
			health.check()
		end)
	end)
end)
