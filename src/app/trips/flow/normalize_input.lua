local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

type NormalizeInput = {
    trip_id: string?,
    user_id: string?,
    destination: string?,
    origin: string?,
    start_date: string,
    end_date: string,
}

type NormalizedTrip = {
    trip_id: string?,
    destination: string,
    origin: string?,
    start_date: string,
    end_date: string,
    duration_days: number,
    season: string,
    user_id: string?,
}

local function handler(input: NormalizeInput): NormalizedTrip
    local trip_id: string? = input.trip_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "normalize_input",
            { status = "running", started_at = os.time() })
    end

    local out: NormalizedTrip = {
        trip_id       = trip_id,
        destination   = trips_common.canonicalize_destination(input.destination),
        origin        = input.origin and trips_common.canonicalize_destination(input.origin) or nil,
        start_date    = input.start_date,
        end_date      = input.end_date,
        duration_days = trips_common.duration_days(input.start_date, input.end_date),
        season        = trips_common.season(input.start_date),
        user_id       = input.user_id,
    }

    if trip_id then
        trip_repo.update_node_state(trip_id, "normalize_input",
            { status = "done", ended_at = os.time() })
        trips_common.notify(input.user_id, trip_id)
    end

    return out
end

return { handler = handler }
