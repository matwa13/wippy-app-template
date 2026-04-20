local test = require("test")
local normalize_input = require("normalize_input")

local function define_tests()
    test.describe("normalize_input", function()
        test.it("canonicalizes destination, computes duration_days + season", function()
            local out = normalize_input.handler({
                trip_id = "t1",
                destination = "  tOkYO  city ",
                origin = "berlin",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.eq(out.destination, "Tokyo City")
            test.eq(out.origin, "Berlin")
            test.eq(out.duration_days, 7)
            test.eq(out.season, "spring")
            test.eq(out.trip_id, "t1")
        end)

        test.it("origin defaults to nil and surfaces no value when missing", function()
            local out = normalize_input.handler({
                trip_id = "t2", destination = "Rome",
                start_date = "2026-12-20", end_date = "2026-12-26",
            })
            test.is_nil(out.origin)
            test.eq(out.season, "winter")
            test.eq(out.duration_days, 7)
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
