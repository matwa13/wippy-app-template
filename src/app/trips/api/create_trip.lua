local http = require("http")
local json = require("json")
local security = require("security")
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local DATE_RE = "^%d%d%d%d%-%d%d%-%d%d$"

local function handler()
    local req = http.request()
    local res = http.response()
    res:set_content_type(http.CONTENT.JSON)

    local actor = security.actor()
    if not actor then
        res:set_status(http.STATUS.UNAUTHORIZED)
        res:write_json({ success = false, error = "unauthenticated" })
        return
    end

    local body = req:body()
    if not body or body == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "request body is required" })
        return
    end

    local data, err = json.decode(body)
    if err then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "invalid JSON: " .. err })
        return
    end

    if not data.destination or data.destination == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "destination is required" })
        return
    end
    if not data.start_date or not data.start_date:match(DATE_RE) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "start_date must be yyyy-mm-dd" })
        return
    end
    if not data.end_date or not data.end_date:match(DATE_RE) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "end_date must be yyyy-mm-dd" })
        return
    end
    if data.end_date < data.start_date then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "end_date must be >= start_date" })
        return
    end

    local trip, c_err = trip_repo.create(actor:id(), {
        destination = trips_common.canonicalize_destination(data.destination),
        origin      = data.origin and trips_common.canonicalize_destination(data.origin) or nil,
        start_date  = data.start_date,
        end_date    = data.end_date,
    })
    if c_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = c_err })
        return
    end

    res:set_status(http.STATUS.CREATED)
    res:write_json({ success = true, trip_id = trip.id, url = "/app/trips/" .. trip.id })
end

return { handler = handler }
