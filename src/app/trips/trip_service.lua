local trip_repo = require("trip_repo")
local trip_flow = require("trip_flow")
local trips_common = require("trips_common")

--- Create a trip row and start its workflow. Returns {trip_id, url}.
local function create_trip(user_id, input)
    local trip, err = trip_repo.create(user_id, {
        destination = trips_common.canonicalize_destination(input.destination),
        origin      = input.origin and trips_common.canonicalize_destination(input.origin) or nil,
        start_date  = input.start_date,
        end_date    = input.end_date,
    })
    if err then return nil, err end

    local workflow_id, f_err = trip_flow.build_and_start({
        trip_id     = trip.id,
        user_id     = user_id,
        destination = trip.destination or input.destination,
        origin      = input.origin,
        start_date  = input.start_date,
        end_date    = input.end_date,
    })
    if f_err then
        trip_repo.set_status(trip.id, "failed")
        return nil, "failed to start workflow: " .. f_err
    end

    trip_repo.set_workflow_id(trip.id, workflow_id)
    trips_common.notify(user_id, trip.id)

    return { trip_id = trip.id, url = "/app/trips/" .. trip.id }
end

return { create_trip = create_trip }
