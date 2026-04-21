local http = require("http")
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

    local user_id: string = actor:id()
    local _, err = task_repo.delete(user_id, tostring(id))
    if err == "not_found" then
        res:set_status(http.STATUS.NOT_FOUND)
        res:write_json({ success = false, error = "task not found" })
        return
    elseif err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true })
end

return { handler = handler }
