local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local ctx = trips_common.as_table(input.context)
    local agent_out = trips_common.as_table(input.default)
    local trip_id = ctx.trip_id
    local user_id = ctx.user_id

    local origin_iata = agent_out.origin_iata
    local destination_iata = agent_out.destination_iata

    if trip_id then
        trip_repo.update_node_state(trip_id, "iata_resolver",
            { status = "done", ended_at = os.time() })
        trips_common.notify(user_id, trip_id)
    end

    return {
        origin_iata      = origin_iata,
        destination_iata = destination_iata,
    }
end

return { handler = handler }
