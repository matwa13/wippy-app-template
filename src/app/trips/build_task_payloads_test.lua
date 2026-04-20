local test = require("test")
local builder = require("build_task_payloads")

local FIXED_TODAY = "2026-04-17"

local function define_tests()
    test.describe("build_task_payloads", function()
        test.it("creates flights + packing + per-attraction tasks", function()
            local rows = builder.build({
                today          = FIXED_TODAY,
                trip_id        = "t1",
                destination    = "Tokyo",
                origin         = "Berlin",
                start_date     = "2026-05-01",
                end_date       = "2026-05-07",
                skyscanner_url = "https://s",
                packing = { { category = "Clothing", items = { "shirt", "pants" } } },
                itinerary = {
                    { date = "2026-05-02", attraction_name = "Senso-ji",
                      description = "Old temple", time_slot = "morning",
                      estimated_duration_hours = 2, constraints = { "closed Mondays" } },
                },
            })
            test.eq(#rows, 3)
            test.eq(rows[1].title, "Book flights — Berlin → Tokyo (2026-05-01 – 2026-05-07)")
            test.eq(rows[1].scheduled_at, FIXED_TODAY)
            test.eq(rows[1].priority, 3)
            test.eq(rows[2].title, "Pack for Tokyo trip")
            test.eq(rows[2].scheduled_at, "2026-04-30")
            test.eq(rows[2].priority, 2)
            test.eq(rows[3].title, "Visit Senso-ji")
            test.eq(rows[3].scheduled_at, "2026-05-02")
            test.eq(rows[3].due_date, "2026-05-02")
            test.eq(rows[3].priority, 1)
            -- flights/packing intentionally do not set due_date
            test.eq(rows[1].due_date, nil)
            test.eq(rows[2].due_date, nil)
        end)

        test.it("omits packing task when packing is nil or empty", function()
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t2",
                destination = "Rome", origin = "Paris",
                start_date = "2026-06-01", end_date = "2026-06-05",
                skyscanner_url = "",
                packing = nil,
                itinerary = {
                    { date = "2026-06-02", attraction_name = "Colosseum",
                      description = "", time_slot = "morning",
                      estimated_duration_hours = 1, constraints = {} },
                },
            })
            -- flights + one attraction, no packing task
            test.eq(#rows, 2)
            test.eq(rows[1].title:sub(1, 5), "Book ")
            test.eq(rows[2].title, "Visit Colosseum")
        end)

        test.it("omits flights task when itinerary is empty (no itinerary → no tasks except flights?)", function()
            -- Per spec: flights task is always created when trip would be ready/partial.
            -- Spec also says: tasks are created only when synthesizer produced a valid itinerary.
            -- So if itinerary is empty, build() must return {} (no tasks).
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t3",
                destination = "Rome", origin = "Paris",
                start_date = "2026-06-01", end_date = "2026-06-05",
                skyscanner_url = "b",
                packing = { { category = "c", items = { "x" } } },
                itinerary = {},
            })
            test.eq(#rows, 0)
        end)

        test.it("clamps past scheduled_at to today", function()
            -- Packing would be scheduled start_date - 1 day; if that's before today, clamp.
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t4",
                destination = "Rome", origin = "Paris",
                start_date = "2026-04-17", end_date = "2026-04-20",
                skyscanner_url = "b",
                packing = { { category = "c", items = { "x" } } },
                itinerary = {
                    { date = "2026-04-17", attraction_name = "Colosseum",
                      description = "", time_slot = "morning",
                      estimated_duration_hours = 2, constraints = {} },
                },
            })
            -- flights (today), packing (clamped from 2026-04-16 → today), visit (already today)
            test.eq(rows[2].scheduled_at, FIXED_TODAY)
            test.eq(rows[3].scheduled_at, FIXED_TODAY)
        end)

        test.it("omits origin from flights title when missing", function()
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t5",
                destination = "Rome", origin = nil,
                start_date = "2026-05-01", end_date = "2026-05-05",
                skyscanner_url = "b",
                packing = nil,
                itinerary = { { date = "2026-05-01", attraction_name = "Colosseum",
                                description = "", time_slot = "morning",
                                estimated_duration_hours = 1, constraints = {} } },
            })
            test.eq(rows[1].title, "Book flights — Rome (2026-05-01 – 2026-05-05)")
            test.ok(rows[1].notes:find("Search on Skyscanner", 1, true))
        end)

        test.it("shows unavailable note when skyscanner_url is missing", function()
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t6",
                destination = "Rome", origin = "Paris",
                start_date = "2026-05-01", end_date = "2026-05-05",
                skyscanner_url = "",
                packing = nil,
                itinerary = { { date = "2026-05-01", attraction_name = "Colosseum",
                                description = "", time_slot = "morning",
                                estimated_duration_hours = 1, constraints = {} } },
            })
            test.ok(rows[1].notes:find("unavailable", 1, true))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
