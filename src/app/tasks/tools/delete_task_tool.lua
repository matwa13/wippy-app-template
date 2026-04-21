local ctx = require("ctx")
local task_repo = require("task_repo")
local tools_common = require("tools_common")

type DeleteParams = {
    id: string?,
    title: string?,
}

type DeleteResult = {
    success: boolean,
    error: string?,
    message: string?,
    candidates: {string}?,
}

local function handler(params: DeleteParams?): DeleteResult
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
    local matched_title: string? = title
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
        matched_title = found.title
    end

    local _, err = task_repo.delete(uid, resolved_id)
    if err == "not_found" then
        return { success = false, error = "task not found" }
    elseif err then
        return { success = false, error = err }
    end

    tools_common.notify(uid)
    return {
        success = true,
        message = "Deleted: " .. (matched_title or resolved_id),
    }
end

return { handler = handler }
