local http = require("http")
local security = require("security")
local sql = require("sql")
local trip_repo = require("trip_repo")

type TripTaskRow = {
    id: string,
    title: string,
    done: boolean,
    notes: string?,
    due_date: string?,
    scheduled_at: string?,
    priority: number,
    created_at: number,
    updated_at: number,
}

local function load_trip_tasks(user_id: string, trip_id: string): ({TripTaskRow}?, string?)
    local db, err = sql.get("app:db")
    if err then return nil, tostring(err) end
    local rows, q_err = db:query([[
        SELECT id, title, done, notes, due_date, scheduled_at, priority, created_at, updated_at
        FROM tasks WHERE user_id = ? AND trip_id = ?
        ORDER BY scheduled_at ASC, created_at ASC
    ]], { user_id, trip_id })
    db:release()
    if q_err then return nil, tostring(q_err) end

    local out: {TripTaskRow} = {}
    for _, r in ipairs(rows) do
        local row: TripTaskRow = {
            id           = tostring(r.id),
            title        = tostring(r.title),
            done         = tonumber(r.done) == 1,
            notes        = r.notes and tostring(r.notes) or nil,
            due_date     = r.due_date and tostring(r.due_date) or nil,
            scheduled_at = r.scheduled_at and tostring(r.scheduled_at) or nil,
            priority     = tonumber(r.priority) or 2,
            created_at   = tonumber(r.created_at) or 0,
            updated_at   = tonumber(r.updated_at) or 0,
        }
        table.insert(out, row)
    end
    return out
end

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

    local id = req:param("id")
    if not id or id == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "trip id is required" })
        return
    end

    local user_id: string = actor:id()
    local trip_id: string = tostring(id)
    local trip, err = trip_repo.get(user_id, trip_id)
    if err == "not_found" then
        res:set_status(http.STATUS.NOT_FOUND)
        res:write_json({ success = false, error = "trip not found" })
        return
    elseif err or not trip then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err or "get failed" })
        return
    end

    local tasks, t_err = load_trip_tasks(user_id, trip_id)
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
