local http = require("http")
local security = require("security")
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")
local tasks_common = require("tasks_common")

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

    local id = req:param("id")
    if not id or id == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "trip id is required" })
        return
    end

    local user_id = actor:id()
    local result, err = trip_repo.delete(user_id, id)
    if err == "not_found" then
        res:set_status(http.STATUS.NOT_FOUND)
        res:write_json({ success = false, error = "trip not found" })
        return
    elseif err == "trip_in_progress" then
        res:set_status(http.STATUS.CONFLICT)
        res:write_json({ success = false, error = "cannot delete a trip while it is still planning" })
        return
    elseif err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    trips_common.notify(user_id, id)
    if (result.tasks_deleted or 0) > 0 then
        tasks_common.notify(user_id)
    end

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, tasks_deleted = result.tasks_deleted })
end

return { handler = handler }
