local http = require("http")
local json = require("json")
local security = require("security")
local task_repo = require("task_repo")

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

    if not data.title or data.title == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "title is required" })
        return
    end

    local task, c_err = task_repo.create(actor:id(), data.title, {
        notes    = data.notes,
        due_date = data.due_date,
        priority = data.priority,
    })
    if c_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = c_err })
        return
    end

    res:set_status(http.STATUS.CREATED)
    res:write_json({ success = true, task = task })
end

return { handler = handler }
