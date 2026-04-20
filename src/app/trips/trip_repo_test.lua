local test = require("test")
local trip_repo = require("trip_repo")

local TEST_USER = "trip_test_user_" .. tostring(os.time())
local state = {}

local function define_tests()
    test.describe("trip_repo", function()
        test.it("creates a trip with initial workflow_state and plan_json", function()
            local r, err = trip_repo.create(TEST_USER, {
                destination = "Tokyo",
                origin = "Berlin",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.is_nil(err)
            test.not_nil(r)
            test.eq(r.status, "planning")
            state.trip_id = r.id
        end)

        test.it("fetched trip has pending workflow_state.nodes", function()
            local t, err = trip_repo.get(TEST_USER, state.trip_id)
            test.is_nil(err)
            test.eq(t.workflow_state.nodes.normalize_input.status, "pending")
            test.eq(t.workflow_state.nodes.itinerary_synthesize.status, "pending")
            test.eq(#(t.plan_json.warnings or {}), 0)
        end)

        test.it("update_node_state merges fields", function()
            local ok, err = trip_repo.update_node_state(state.trip_id, "normalize_input",
                { status = "done", started_at = 100, ended_at = 200 })
            test.is_true(ok); test.is_nil(err)
            local t = trip_repo.get(TEST_USER, state.trip_id)
            test.eq(t.workflow_state.nodes.normalize_input.status, "done")
            test.eq(t.workflow_state.nodes.normalize_input.ended_at, 200)
        end)

        test.it("update_plan_section writes plan_json key without touching workflow_state", function()
            local ok = trip_repo.update_plan_section(state.trip_id, "attractions",
                { { name = "Senso-ji", description = "Old temple" } })
            test.is_true(ok)
            local t = trip_repo.get(TEST_USER, state.trip_id)
            test.eq(#t.plan_json.attractions, 1)
            test.eq(t.workflow_state.nodes.normalize_input.status, "done") -- unchanged
        end)

        test.it("append_warning appends to plan_json.warnings", function()
            trip_repo.append_warning(state.trip_id, "origin missing")
            local t = trip_repo.get(TEST_USER, state.trip_id)
            test.eq(t.plan_json.warnings[1], "origin missing")
        end)

        test.it("list filters by status", function()
            trip_repo.set_status(state.trip_id, "ready")
            local all, _ = trip_repo.list(TEST_USER, "all")
            local ready, _ = trip_repo.list(TEST_USER, "ready")
            test.ok(#all >= 1)
            test.ok(#ready >= 1)
        end)

        test.it("not_found for unknown id", function()
            local t, err = trip_repo.get(TEST_USER, "does_not_exist")
            test.is_nil(t); test.eq(err, "not_found")
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
local function run(options) return run_cases(options) end
return { run = run }
