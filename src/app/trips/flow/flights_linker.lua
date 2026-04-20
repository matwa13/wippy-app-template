local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function url_encode(s)
    if not s then return "" end
    return (s:gsub("([^%w_-])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function build_sky(origin, destination, start_date, end_date)
    -- Skyscanner doesn't have a stable deep-link format for city search; use a plain query URL.
    if origin and origin ~= "" then
        return string.format("https://www.skyscanner.net/transport/flights/%s/%s/?outboundDate=%s&inboundDate=%s",
            url_encode(origin), url_encode(destination), start_date, end_date)
    end
    return string.format("https://www.skyscanner.net/transport/flights/to/%s/?outboundDate=%s&inboundDate=%s",
        url_encode(destination), start_date, end_date)
end

local function handler(input)
    local trip_id = input.trip_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "flights_linker",
            { status = "running", started_at = os.time() })
    end

    local out = {
        skyscanner_url = build_sky(input.origin, input.destination,
                                   input.start_date, input.end_date),
    }
    if not input.origin or input.origin == "" then
        out.warning = "Origin not provided — flight links do not include a departure city."
    end

    if trip_id then
        trip_repo.update_plan_section(trip_id, "flights", {
            skyscanner_url = out.skyscanner_url,
        })
        if out.warning then
            trip_repo.append_warning(trip_id, out.warning)
        end
        trip_repo.update_node_state(trip_id, "flights_linker",
            { status = "done", ended_at = os.time() })
        trips_common.notify(input.user_id, trip_id)
    end

    return out
end

return { handler = handler }
