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

    local user_id: string = actor:id()
    local raw_filter = req:query("filter") or "all"
    local filter: "all" | "open" | "done" = "all"
    if raw_filter == "open" or raw_filter == "done" then
        filter = raw_filter
    end

    local tasks, err = task_repo.list(user_id, filter)
    if err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, tasks = tasks })
end

return { handler = handler }
