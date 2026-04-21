local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

type GateInput = {
    default: any?,
    context: any?,
}

type ItineraryOutput = {
    itinerary: any,
}

local function handler(input: GateInput): (ItineraryOutput?, string?)
    local ctx = trips_common.as_table(input.context)
    local agent_out = trips_common.as_table(input.default)
    local trip_id: string = tostring(ctx.trip_id)
    local user_id: string? = ctx.user_id and tostring(ctx.user_id) or nil
    local itinerary: any = agent_out.itinerary or {}

    if #itinerary == 0 then
        trip_repo.update_node_state(trip_id, "itinerary_synthesize",
            { status = "failed", ended_at = os.time(),
              error = "synthesizer returned empty itinerary" })
        trip_repo.set_status(trip_id, "failed")
        trips_common.notify(user_id, trip_id)
        return nil, "empty itinerary"
    end

    trip_repo.update_plan_section(trip_id, "itinerary", itinerary)
    trip_repo.update_node_state(trip_id, "itinerary_synthesize",
        { status = "done", ended_at = os.time() })
    trips_common.notify(user_id, trip_id)

    return { itinerary = itinerary }
end

return { handler = handler }
