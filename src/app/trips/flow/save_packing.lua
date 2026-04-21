local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

type GateInput = {
    default: any?,
    context: any?,
}

local function handler(input: GateInput): any
    local ctx = trips_common.as_table(input.context)
    local agent_out = trips_common.as_table(input.default)
    local trip_id: string = tostring(ctx.trip_id)
    local user_id: string? = ctx.user_id and tostring(ctx.user_id) or nil
    local packing: any = agent_out.packing or {}

    if #packing == 0 then
        trip_repo.append_warning(trip_id, "Packing list unavailable — continuing without it.")
        trip_repo.update_node_state(trip_id, "packing_research",
            { status = "failed", ended_at = os.time(),
              error = "empty packing list" })
        trips_common.notify(user_id, trip_id)
        return {}
    end

    trip_repo.update_plan_section(trip_id, "packing", packing)
    trip_repo.update_node_state(trip_id, "packing_research",
        { status = "done", ended_at = os.time() })
    trips_common.notify(user_id, trip_id)

    return packing
end

return { handler = handler }
