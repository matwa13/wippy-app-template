local ctx = require("ctx")
local trip_service = require("trip_service")

local DATE_RE = "^%d%d%d%d%-%d%d%-%d%d$"

local function handler(params)
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    if not params or not params.destination or params.destination == "" then
        return { success = false, error = "destination is required" }
    end
    if not params.start_date or not params.start_date:match(DATE_RE) then
        return { success = false, error = "start_date must be yyyy-mm-dd" }
    end
    if not params.end_date or not params.end_date:match(DATE_RE) then
        return { success = false, error = "end_date must be yyyy-mm-dd" }
    end
    if params.end_date < params.start_date then
        return { success = false, error = "end_date must be >= start_date" }
    end

    local result, err = trip_service.create_trip(user_id, {
        destination = params.destination,
        origin      = params.origin,
        start_date  = params.start_date,
        end_date    = params.end_date,
    })
    if err then return { success = false, error = err } end

    return {
        success = true,
        message = "Started planning trip to " .. params.destination,
        trip_id = result.trip_id,
        url     = result.url,
    }
end

return { handler = handler }
