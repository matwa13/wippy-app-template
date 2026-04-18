local test = require("test")
local validator = require("validate_synthesizer_exit")

local function define_tests()
    test.describe("validate_synthesizer_exit", function()
        test.it("accepts a valid itinerary", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" }, { name = "B" }, { name = "C" } },
                start_date  = "2026-05-01",
                end_date    = "2026-05-03",
            }, {
                itinerary = {
                    { date = "2026-05-01", attraction_name = "A" },
                    { date = "2026-05-02", attraction_name = "B" },
                    { date = "2026-05-03", attraction_name = "C" },
                },
            })
            test.is_true(ok)
            test.is_nil(err)
        end)

        test.it("rejects hallucinated attraction", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" } },
                start_date  = "2026-05-01", end_date = "2026-05-02",
            }, {
                itinerary = {
                    { date = "2026-05-01", attraction_name = "NotInList" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("NotInList", 1, true))
        end)

        test.it("rejects date outside trip range", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" } },
                start_date  = "2026-05-01", end_date = "2026-05-02",
            }, {
                itinerary = {
                    { date = "2026-05-04", attraction_name = "A" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("2026-05-04", 1, true))
        end)

        test.it("rejects > 2 items on arrival date", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" }, { name = "B" }, { name = "C" } },
                start_date  = "2026-05-01", end_date = "2026-05-03",
            }, {
                itinerary = {
                    { date = "2026-05-01", attraction_name = "A" },
                    { date = "2026-05-01", attraction_name = "B" },
                    { date = "2026-05-01", attraction_name = "C" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("arrival", 1, true))
        end)

        test.it("rejects > 2 items on departure date", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" }, { name = "B" }, { name = "C" } },
                start_date  = "2026-05-01", end_date = "2026-05-03",
            }, {
                itinerary = {
                    { date = "2026-05-03", attraction_name = "A" },
                    { date = "2026-05-03", attraction_name = "B" },
                    { date = "2026-05-03", attraction_name = "C" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("departure", 1, true))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
