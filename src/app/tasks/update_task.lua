local http = require("http")
local json = require("json")
local security = require("security")
local task_repo = require("task_repo")

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
        res:write_json({ success = false, error = "task id is required" })
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

    local fields: task_repo.UpdateFields = {}
    if data.title ~= nil then fields.title = tostring(data.title) end
    if data.done ~= nil then fields.done = data.done and true or false end
    if data.notes ~= nil then fields.notes = tostring(data.notes) end
    if data.due_date ~= nil then fields.due_date = tostring(data.due_date) end
    if data.priority ~= nil then fields.priority = tonumber(data.priority) end

    if not next(fields) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "no fields to update" })
        return
    end

    local user_id: string = actor:id()
    local task, u_err = task_repo.update(user_id, tostring(id), fields)
    if u_err == "not_found" then
        res:set_status(http.STATUS.NOT_FOUND)
        res:write_json({ success = false, error = "task not found" })
        return
    elseif u_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = u_err })
        return
    end

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, task = task })
end

return { handler = handler }
