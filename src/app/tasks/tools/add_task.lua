local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

local function handler(params)
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    local title = params and params.title
    if not title or title == "" then
        return { success = false, error = "title is required" }
    end

    local task, err = task_repo.create(user_id, title)
    if err then
        return { success = false, error = err }
    end

    tools_common.notify(user_id)
    return {
        success = true,
        message = "Added task: " .. task.title,
        task = task,
    }
end

return { handler = handler }
