local USER_HUB_PREFIX = "user."

local M = {}

--- Broadcast a trips:changed event to the given user hub.
function M.notify(user_id, trip_id)
    if not user_id then return end
    local hub_pid = process.registry.lookup(USER_HUB_PREFIX .. user_id)
    if hub_pid then
        process.send(hub_pid, "trips:changed", { trip_id = trip_id })
    end
end

--- Canonicalize destination: trim + title-case words, squeeze spaces.
function M.canonicalize_destination(s)
    if not s then return "" end
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    s = s:gsub("%s+", " ")
    return (s:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

--- Compute duration_days from two ISO dates (inclusive).
function M.duration_days(start_date, end_date)
    local function parse(d)
        local y, m, day = d:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(day),
                         hour = 12, min = 0, sec = 0 })
    end
    local s, e = parse(start_date), parse(end_date)
    return math.floor((e - s) / 86400) + 1
end

--- Rough hemisphere-agnostic season from a yyyy-mm-dd start date (northern hemisphere).
function M.season(start_date)
    local m = tonumber(start_date:sub(6, 7))
    if m == 12 or m <= 2 then return "winter"
    elseif m <= 5 then return "spring"
    elseif m <= 8 then return "summer"
    else return "autumn" end
end

return M
