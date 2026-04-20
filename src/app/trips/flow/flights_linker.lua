local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function yymmdd(iso)
    local y, m, d = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    return y:sub(3, 4) .. m .. d
end

--- Path-based Skyscanner deep-link: /transport/flights/<orig>/<dest>/<YYMMDD>/<YYMMDD>/
local function build_sky(origin_iata, destination_iata, start_date, end_date)
    return string.format("https://www.skyscanner.net/transport/flights/%s/%s/%s/%s/",
        origin_iata:lower(), destination_iata:lower(),
        yymmdd(start_date), yymmdd(end_date))
end

local function handler(input)
    local ctx = trips_common.as_table(input.context)
    local resolved = trips_common.as_table(input.default)
    local trip_id = ctx.trip_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "flights_linker",
            { status = "running", started_at = os.time() })
    end

    local origin_iata = resolved.origin_iata
    local destination_iata = resolved.destination_iata

    local out = {}
    if origin_iata and origin_iata ~= "" and destination_iata and destination_iata ~= "" then
        out.skyscanner_url = build_sky(origin_iata, destination_iata,
                                       ctx.start_date, ctx.end_date)
    else
        if not origin_iata or origin_iata == "" then
            out.warning = "Origin airport could not be resolved — flight search link unavailable."
        else
            out.warning = "Destination airport could not be resolved — flight search link unavailable."
        end
    end

    if trip_id then
        -- Always write the flights section so the UI can distinguish
        -- "linker hasn't run yet" (no section) from "linker ran, no link".
        trip_repo.update_plan_section(trip_id, "flights",
            { skyscanner_url = out.skyscanner_url })
        if out.warning then
            trip_repo.append_warning(trip_id, out.warning)
        end
        trip_repo.update_node_state(trip_id, "flights_linker",
            { status = "done", ended_at = os.time() })
        trips_common.notify(ctx.user_id, trip_id)
    end

    return out
end

return { handler = handler }
