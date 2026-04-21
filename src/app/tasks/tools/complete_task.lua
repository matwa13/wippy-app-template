local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

type CompleteParams = {
    id: string?,
    title: string?,
}

type CompleteResult = {
    success: boolean,
    error: string?,
    message: string?,
    task: task_repo.Task?,
    candidates: {string}?,
}

local function handler(params: CompleteParams?): CompleteResult
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end
    local uid: string = tostring(user_id)

    local maybe_id: string? = params and params.id
    local title: string? = params and params.title

    if not maybe_id and (not title or title == "") then
        return { success = false, error = "provide either id or title" }
    end

    local resolved_id: string
    if maybe_id then
        resolved_id = maybe_id
    else
        local found, err, candidates = task_repo.find_by_title(uid, title or "", true)
        if err == "ambiguous" then
            return {
                success = false,
                error = "multiple open tasks match — ask the user which one",
                candidates = tools_common.candidate_titles(candidates),
            }
        elseif err == "not_found" then
            return { success = false, error = "no open task matches: " .. (title or "") }
        elseif err or not found then
            return { success = false, error = err or "lookup failed" }
        end
        resolved_id = found.id
    end

    local task, err = task_repo.update(uid, resolved_id, { done = true })
    if err == "not_found" then
        return { success = false, error = "task not found" }
    elseif err or not task then
        return { success = false, error = err or "update failed" }
    end

    tools_common.notify(uid)
    return {
        success = true,
        message = "Completed: " .. task.title,
        task = task,
    }
end

return { handler = handler }
