local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

type GateInput = {
    default: any?,
    context: any?,
}

type IataOutput = {
    origin_iata: string?,
    destination_iata: string?,
}

local function handler(input: GateInput): IataOutput
    local ctx = trips_common.as_table(input.context)
    local agent_out = trips_common.as_table(input.default)
    local trip_id: string? = ctx.trip_id and tostring(ctx.trip_id) or nil
    local user_id: string? = ctx.user_id and tostring(ctx.user_id) or nil

    local origin_iata: string? = agent_out.origin_iata and tostring(agent_out.origin_iata) or nil
    local destination_iata: string? = agent_out.destination_iata and tostring(agent_out.destination_iata) or nil

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
