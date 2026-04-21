local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

local PRIORITY_MAP: {[string]: number} = { low = 1, medium = 2, high = 3 }

type AddParams = {
    title: string?,
    notes: string?,
    due_date: string?,
    priority: string?,
}

type ToolResult = {
    success: boolean,
    error: string?,
    message: string?,
    task: task_repo.Task?,
}

local function handler(params: AddParams?): ToolResult
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    local title = params and params.title
    if not title or title == "" then
        return { success = false, error = "title is required" }
    end

    local opts: task_repo.CreateOpts = {
        notes    = params.notes,
        due_date = params.due_date,
        priority = params.priority and PRIORITY_MAP[params.priority] or nil,
    }
    local task, err = task_repo.create(tostring(user_id), title, opts)
    if err or not task then
        return { success = false, error = err or "create failed" }
    end

    tools_common.notify(tostring(user_id))
    return {
        success = true,
        message = "Added task: " .. task.title,
        task = task,
    }
end

return { handler = handler }
