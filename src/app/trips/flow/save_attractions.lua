local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local ctx = trips_common.as_table(input.context)
    local agent_out = trips_common.as_table(input.default)
    local trip_id = ctx.trip_id
    local user_id = ctx.user_id
    local attractions = agent_out.attractions or {}

    if #attractions == 0 then
        trip_repo.update_node_state(trip_id, "attractions_research",
            { status = "failed", ended_at = os.time(),
              error = "no attractions returned" })
        trip_repo.set_status(trip_id, "failed")
        trips_common.notify(user_id, trip_id)
        return nil, "no attractions returned"
    end

    trip_repo.update_plan_section(trip_id, "attractions", attractions)
    trip_repo.update_node_state(trip_id, "attractions_research",
        { status = "done", ended_at = os.time() })
    trips_common.notify(user_id, trip_id)

    return attractions
end

return { handler = handler }
