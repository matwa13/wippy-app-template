local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

local function handler(params)
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    local id = params and params.id
    local title = params and params.title

    if not id and (not title or title == "") then
        return { success = false, error = "provide either id or title" }
    end

    if not id then
        local task, err, candidates = task_repo.find_by_title(user_id, title, true)
        if err == "ambiguous" then
            return {
                success = false,
                error = "multiple open tasks match — ask the user which one",
                candidates = tools_common.candidate_titles(candidates),
            }
        elseif err == "not_found" then
            return { success = false, error = "no open task matches: " .. title }
        elseif err then
            return { success = false, error = err }
        end
        id = task.id
    end

    local task, err = task_repo.update(user_id, id, { done = true })
    if err == "not_found" then
        return { success = false, error = "task not found" }
    elseif err then
        return { success = false, error = err }
    end

    tools_common.notify(user_id)
    return {
        success = true,
        message = "Completed: " .. task.title,
        task = task,
    }
end

return { handler = handler }
