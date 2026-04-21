local ctx = require("ctx")
local task_repo = require("task_repo")

type ListParams = {
    filter: string?,
}

type ListResult = {
    success: boolean,
    error: string?,
    count: number?,
    filter: string?,
    tasks: {task_repo.Task}?,
}

local function handler(params: ListParams?): ListResult
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    local raw_filter = params and params.filter or "all"
    local filter: "all" | "open" | "done" = "all"
    if raw_filter == "open" or raw_filter == "done" then
        filter = raw_filter
    end

    local tasks, err = task_repo.list(tostring(user_id), filter)
    if err or not tasks then
        return { success = false, error = err or "list failed" }
    end

    return {
        success = true,
        count = #tasks,
        filter = filter,
        tasks = tasks,
    }
end

return { handler = handler }
