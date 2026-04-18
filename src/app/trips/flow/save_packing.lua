local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local trip_id = input.trip_id
    local packing = input.packing or {}

    if #packing == 0 then
        trip_repo.append_warning(trip_id, "Packing list unavailable — continuing without it.")
        trip_repo.update_node_state(trip_id, "packing_research",
            { status = "failed", ended_at = os.time(),
              error = "empty packing list" })
        trips_common.notify(input.user_id, trip_id)
        return { packing = {}, trip_id = trip_id, user_id = input.user_id }
    end

    trip_repo.update_plan_section(trip_id, "packing", packing)
    trip_repo.update_node_state(trip_id, "packing_research",
        { status = "done", ended_at = os.time() })
    trips_common.notify(input.user_id, trip_id)

    return { packing = packing, trip_id = trip_id, user_id = input.user_id }
end

return { handler = handler }
