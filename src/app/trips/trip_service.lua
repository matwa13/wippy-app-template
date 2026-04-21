local trip_repo = require("trip_repo")
local trip_flow = require("trip_flow")
local trips_common = require("trips_common")

type CreateTripInput = {
    destination: string,
    origin: string?,
    start_date: string,
    end_date: string,
}

type CreateTripResult = {
    trip_id: string,
    url: string,
}

local function create_trip(user_id: string, input: CreateTripInput): (CreateTripResult?, string?)
    local destination: string = trips_common.canonicalize_destination(input.destination)
    local origin: string? = input.origin and trips_common.canonicalize_destination(input.origin) or nil

    local trip, err = trip_repo.create(user_id, {
        destination = destination,
        origin      = origin,
        start_date  = input.start_date,
        end_date    = input.end_date,
    })
    if err or not trip then return nil, err or "failed to create trip" end

    local workflow_id, f_err = trip_flow.build_and_start({
        trip_id     = trip.id,
        user_id     = user_id,
        destination = destination,
        origin      = origin,
        start_date  = input.start_date,
        end_date    = input.end_date,
    })
    if f_err or not workflow_id then
        trip_repo.set_status(trip.id, "failed")
        return nil, "failed to start workflow: " .. tostring(f_err or "unknown error")
    end

    trip_repo.set_workflow_id(trip.id, tostring(workflow_id))
    trips_common.notify(user_id, trip.id)

    return { trip_id = trip.id, url = "/app/trips/" .. trip.id }
end

return { create_trip = create_trip }
