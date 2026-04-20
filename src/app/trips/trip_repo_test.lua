local test = require("test")
local sql = require("sql")
local trip_repo = require("trip_repo")

local TEST_USER = "trip_test_user_" .. tostring(os.time())
local state = {}

local function insert_task(user_id, id, trip_id)
    local db = sql.get("app:db")
    db:execute([[
        INSERT INTO tasks (id, user_id, title, done, priority, trip_id, created_at, updated_at)
        VALUES (?, ?, ?, 0, 2, ?, ?, ?)
    ]], { id, user_id, "task-" .. id, trip_id, os.time(), os.time() })
    db:release()
end

local function count_tasks_for_trip(user_id, trip_id)
    local db = sql.get("app:db")
    local rows = db:query(
        "SELECT COUNT(*) AS c FROM tasks WHERE user_id = ? AND trip_id = ?",
        { user_id, trip_id })
    db:release()
    return tonumber(rows[1].c) or 0
end

local function task_exists(user_id, id)
    local db = sql.get("app:db")
    local rows = db:query(
        "SELECT 1 FROM tasks WHERE user_id = ? AND id = ?", { user_id, id })
    db:release()
    return #rows > 0
end

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

        test.it("refuses to delete a trip while status is planning", function()
            local t = trip_repo.create(TEST_USER, {
                destination = "Oslo", start_date = "2026-06-01", end_date = "2026-06-05" })
            local res, err = trip_repo.delete(TEST_USER, t.id)
            test.is_nil(res); test.eq(err, "trip_in_progress")
            -- trip still exists
            local after, g_err = trip_repo.get(TEST_USER, t.id)
            test.is_nil(g_err); test.not_nil(after)
            -- cleanup for downstream tests
            trip_repo.set_status(t.id, "failed")
            trip_repo.delete(TEST_USER, t.id)
        end)

        test.it("deletes trip and cascades its tasks, sparing others", function()
            -- trip A with two tasks; trip B with one task; standalone task with no trip
            local a = trip_repo.create(TEST_USER, {
                destination = "Rome", start_date = "2026-07-01", end_date = "2026-07-05" })
            local b = trip_repo.create(TEST_USER, {
                destination = "Paris", start_date = "2026-08-01", end_date = "2026-08-05" })
            trip_repo.set_status(a.id, "ready")
            trip_repo.set_status(b.id, "ready")

            local a1 = "task_a1_" .. tostring(os.time())
            local a2 = "task_a2_" .. tostring(os.time())
            local b1 = "task_b1_" .. tostring(os.time())
            local standalone = "task_solo_" .. tostring(os.time())
            insert_task(TEST_USER, a1, a.id)
            insert_task(TEST_USER, a2, a.id)
            insert_task(TEST_USER, b1, b.id)
            insert_task(TEST_USER, standalone, nil)

            local res, err = trip_repo.delete(TEST_USER, a.id)
            test.is_nil(err)
            test.eq(res.tasks_deleted, 2)

            -- trip A gone, tasks gone
            local _, g_err = trip_repo.get(TEST_USER, a.id)
            test.eq(g_err, "not_found")
            test.eq(count_tasks_for_trip(TEST_USER, a.id), 0)
            -- trip B and its task untouched
            local b_after = trip_repo.get(TEST_USER, b.id)
            test.not_nil(b_after)
            test.is_true(task_exists(TEST_USER, b1))
            -- standalone task survives
            test.is_true(task_exists(TEST_USER, standalone))

            -- cleanup
            trip_repo.delete(TEST_USER, b.id)
        end)

        test.it("delete returns not_found for unknown id", function()
            local res, err = trip_repo.delete(TEST_USER, "missing")
            test.is_nil(res); test.eq(err, "not_found")
        end)

        test.it("delete is user-scoped", function()
            local a = trip_repo.create(TEST_USER, {
                destination = "Lisbon", start_date = "2026-09-01", end_date = "2026-09-05" })
            trip_repo.set_status(a.id, "ready")
            local res, err = trip_repo.delete("other_user_totally_not_me", a.id)
            test.is_nil(res); test.eq(err, "not_found")
            test.not_nil(trip_repo.get(TEST_USER, a.id))
            trip_repo.delete(TEST_USER, a.id)
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
local function run(options) return run_cases(options) end
return { run = run }
