local ctx = require("ctx")
local task_repo = require("task_repo")

local function handler(params)
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    local filter = (params and params.filter) or "all"
    local tasks, err = task_repo.list(user_id, filter)
    if err then
        return { success = false, error = err }
    end

    return {
        success = true,
        count = #tasks,
        filter = filter,
        tasks = tasks,
    }
end

return { handler = handler }
