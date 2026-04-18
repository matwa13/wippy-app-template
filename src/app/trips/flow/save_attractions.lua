local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local trip_id = input.trip_id
    local attractions = input.attractions or {}

    if #attractions == 0 then
        trip_repo.update_node_state(trip_id, "attractions_research",
            { status = "failed", ended_at = os.time(),
              error = "no attractions returned" })
        trips_common.notify(input.user_id, trip_id)
        return nil, "no attractions returned"
    end

    trip_repo.update_plan_section(trip_id, "attractions", attractions)
    trip_repo.update_node_state(trip_id, "attractions_research",
        { status = "done", ended_at = os.time() })
    trips_common.notify(input.user_id, trip_id)

    return { attractions = attractions, trip_id = trip_id, user_id = input.user_id }
end

return { handler = handler }
