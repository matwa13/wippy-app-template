local test = require("test")
local flights_linker = require("flights_linker")

local function define_tests()
    test.describe("flights_linker", function()
        test.it("builds the Skyscanner deep link when origin is present", function()
            local out = flights_linker.handler({
                destination = "Tokyo",
                origin = "Berlin",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.ok(out.skyscanner_url:find("Berlin", 1, true))
            test.ok(out.skyscanner_url:find("Tokyo", 1, true))
            test.is_nil(out.warning)
        end)

        test.it("emits warning and destination-only link without origin", function()
            local out = flights_linker.handler({
                destination = "Tokyo",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.not_nil(out.warning)
            test.ok(out.skyscanner_url:find("Tokyo", 1, true))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
