local USER_HUB_PREFIX = "user."

local M = {}

--- Broadcast a tasks:changed event to the user's hub so open UIs refresh.
function M.notify(user_id)
    local hub_pid = process.registry.lookup(USER_HUB_PREFIX .. user_id)
    if hub_pid then
        process.send(hub_pid, "tasks:changed", {})
    end
end

--- Extract plain title strings from a list of task rows (used for disambiguation payloads).
function M.candidate_titles(list)
    local out = {}
    for _, t in ipairs(list or {}) do
        table.insert(out, t.title)
    end
    return out
end

return M
