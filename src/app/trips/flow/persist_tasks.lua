local trip_repo = require("trip_repo")
local trips_common = require("trips_common")
local task_repo = require("task_repo")
local tasks_common = require("tasks_common")

local function handler(input)
    local ctx = trips_common.as_table(input.context)
    local payload = trips_common.as_table(input.default)
    local trip_id: string = tostring(ctx.trip_id)
    local user_id: string = tostring(ctx.user_id)
    local rows = payload.task_rows or {}

    trip_repo.update_node_state(trip_id, "persist_tasks",
        { status = "running", started_at = os.time() })

    for _, r in ipairs(rows) do
        local opts: task_repo.CreateOpts = {
            notes = r.notes and tostring(r.notes) or nil,
            scheduled_at = r.scheduled_at and tostring(r.scheduled_at) or nil,
            due_date = r.due_date and tostring(r.due_date) or nil,
            priority = tonumber(r.priority),
        }
        local _, c_err = task_repo.create_with_trip(user_id, trip_id, tostring(r.title), opts)
        if c_err then
            trip_repo.update_node_state(trip_id, "persist_tasks",
                { status = "failed", ended_at = os.time(), error = c_err })
            trip_repo.set_status(trip_id, "failed")
            trips_common.notify(user_id, trip_id)
            return nil, c_err
        end
    end

    trip_repo.update_node_state(trip_id, "persist_tasks",
        { status = "done", ended_at = os.time() })

    -- Determine final status: ready or partial (partial = any non-critical branch failed).
    local trip = trip_repo.get(user_id, trip_id)
    local ws = trip and trip.workflow_state or {}
    local packing_failed = (ws.nodes and ws.nodes.packing_research
                            and ws.nodes.packing_research.status == "failed") or false
    trip_repo.set_status(trip_id, packing_failed and "partial" or "ready")

    trips_common.notify(user_id, trip_id)
    tasks_common.notify(user_id)

    return { trip_id = trip_id, task_count = #rows }
end

return { handler = handler }
