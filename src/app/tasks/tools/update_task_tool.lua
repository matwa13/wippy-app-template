local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

local PRIORITY_MAP: {[string]: number} = { low = 1, medium = 2, high = 3 }

type UpdateParams = {
    id: string?,
    title: string?,
    notes: string?,
    due_date: string?,
    priority: string?,
}

type UpdateResult = {
    success: boolean,
    error: string?,
    message: string?,
    task: task_repo.Task?,
    candidates: {string}?,
}

local function handler(params: UpdateParams?): UpdateResult
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end
    local uid: string = tostring(user_id)

    local maybe_id: string? = params and params.id
    local title: string? = params and params.title

    if not maybe_id and (not title or title == "") then
        return { success = false, error = "provide either id or title to identify the task" }
    end

    local resolved_id: string
    if maybe_id then
        resolved_id = maybe_id
    else
        local found, err, candidates = task_repo.find_by_title(uid, title or "", false)
        if err == "ambiguous" then
            return {
                success = false,
                error = "multiple tasks match — ask the user which one",
                candidates = tools_common.candidate_titles(candidates),
            }
        elseif err == "not_found" then
            return { success = false, error = "no task matches: " .. (title or "") }
        elseif err or not found then
            return { success = false, error = err or "lookup failed" }
        end
        resolved_id = found.id
    end

    local fields: task_repo.UpdateFields = {}
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

    local task, err = task_repo.update(uid, resolved_id, fields)
    if err == "not_found" then
        return { success = false, error = "task not found" }
    elseif err or not task then
        return { success = false, error = err or "update failed" }
    end

    tools_common.notify(uid)
    return {
        success = true,
        message = "Updated: " .. task.title,
        task = task,
    }
end

return { handler = handler }
