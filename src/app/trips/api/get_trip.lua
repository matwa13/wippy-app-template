local http = require("http")
local security = require("security")
local sql = require("sql")
local trip_repo = require("trip_repo")

local function load_trip_tasks(user_id, trip_id)
    local db, err = sql.get("app:db")
    if err then return nil, err end
    local rows, q_err = db:query([[
        SELECT id, title, done, notes, due_date, scheduled_at, priority, created_at, updated_at
        FROM tasks WHERE user_id = ? AND trip_id = ?
        ORDER BY scheduled_at ASC, created_at ASC
    ]], { user_id, trip_id })
    db:release()
    if q_err then return nil, q_err end
    for _, r in ipairs(rows) do
        r.done = tonumber(r.done) == 1
        r.priority = tonumber(r.priority) or 2
        r.created_at = tonumber(r.created_at)
        r.updated_at = tonumber(r.updated_at)
    end
    return rows
end

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

    local trip, err = trip_repo.get(actor:id(), id)
    if err == "not_found" then
        res:set_status(http.STATUS.NOT_FOUND)
        res:write_json({ success = false, error = "trip not found" })
        return
    elseif err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    local tasks, t_err = load_trip_tasks(actor:id(), id)
    if t_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = t_err })
        return
    end
    trip.tasks = tasks

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, trip = trip })
end

return { handler = handler }
