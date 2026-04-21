local test = require("test")
local flights_linker = require("flights_linker")

local function define_tests()
    test.describe("flights_linker", function()
        test.it("builds path-based Skyscanner URL from IATA codes", function()
            local out = flights_linker.handler({
                context = {
                    start_date = "2026-05-01",
                    end_date   = "2026-05-07",
                },
                default = {
                    origin_iata      = "LHR",
                    destination_iata = "HND",
                },
            })
            test.eq(out.skyscanner_url,
                "https://www.skyscanner.net/transport/flights/lhr/hnd/260501/260507/")
            test.is_nil(out.warning)
        end)

        test.it("omits link and emits warning when origin IATA is missing", function()
            local out = flights_linker.handler({
                context = { start_date = "2026-05-01", end_date = "2026-05-07" },
                default = { origin_iata = nil, destination_iata = "HND" },
            })
            test.is_nil(out.skyscanner_url)
            test.not_nil(out.warning)
            test.ok(out.warning:find("Origin", 1, true))
        end)

        test.it("omits link and emits warning when destination IATA is missing", function()
            local out = flights_linker.handler({
                context = { start_date = "2026-05-01", end_date = "2026-05-07" },
                default = { origin_iata = "LHR", destination_iata = nil },
            })
            test.is_nil(out.skyscanner_url)
            test.not_nil(out.warning)
            test.ok(out.warning:find("Destination", 1, true))
        end)

        test.it("treats empty strings as unresolved", function()
            local out = flights_linker.handler({
                context = { start_date = "2026-05-01", end_date = "2026-05-07" },
                default = { origin_iata = "", destination_iata = "" },
            })
            test.is_nil(out.skyscanner_url)
            test.not_nil(out.warning)
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
