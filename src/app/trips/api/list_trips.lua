local http = require("http")
local security = require("security")
local trip_repo = require("trip_repo")

local function handler(): (nil, string?)
    local req = http.request()
    local res = http.response()
    res:set_content_type(http.CONTENT.JSON)

    local actor = security.actor()
    if not actor then
        res:set_status(http.STATUS.UNAUTHORIZED)
        res:write_json({ success = false, error = "unauthenticated" })
        return
    end

    local raw_filter = req:query("filter") or "all"
    local filter: trip_repo.TripFilter = "all"
    if raw_filter == "planning" or raw_filter == "ready"
        or raw_filter == "partial" or raw_filter == "failed" then
        filter = raw_filter
    end

    local user_id: string = actor:id()
    local trips, err = trip_repo.list(user_id, filter)
    if err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, trips = trips })
end

return { handler = handler }
