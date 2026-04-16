local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

local PRIORITY_MAP = { low = 1, medium = 2, high = 3 }

local function handler(params)
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    local id = params and params.id
    local title = params and params.title

    if not id and (not title or title == "") then
        return { success = false, error = "provide either id or title to identify the task" }
    end

    if not id then
        local task, err, candidates = task_repo.find_by_title(user_id, title, false)
        if err == "ambiguous" then
            return {
                success = false,
                error = "multiple tasks match — ask the user which one",
                candidates = tools_common.candidate_titles(candidates),
            }
        elseif err == "not_found" then
            return { success = false, error = "no task matches: " .. title }
        elseif err then
            return { success = false, error = err }
        end
        id = task.id
    end

    local fields = {}
    if params.notes ~= nil then fields.notes = params.notes end
    if params.due_date ~= nil then fields.due_date = params.due_date end
    if params.priority ~= nil then
        local p = PRIORITY_MAP[params.priority]
        if not p then
            return { success = false, error = "priority must be low, medium, or high" }
        end
        fields.priority = p
    end

    if not next(fields) then
        return { success = false, error = "provide at least one field to update" }
    end

    local task, err = task_repo.update(user_id, id, fields)
    if err == "not_found" then
        return { success = false, error = "task not found" }
    elseif err then
        return { success = false, error = err }
    end

    tools_common.notify(user_id)
    return {
        success = true,
        message = "Updated: " .. task.title,
        task = task,
    }
end

return { handler = handler }
