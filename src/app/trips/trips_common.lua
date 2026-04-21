local json = require("json")

local USER_HUB_PREFIX = "user."

local M = {}

--- Defensive coerce: flow nodes sometimes deliver an upstream JSON payload as
--- a string rather than a decoded table (observed for agent exit_schema
--- outputs). This coerces either shape into a table.
function M.as_table(v: any): any
    if type(v) == "table" then return v end
    if type(v) == "string" then
        local ok, decoded = pcall(json.decode, v)
        if ok and type(decoded) == "table" then return decoded end
    end
    return {}
end

--- Broadcast a trips:changed event to the given user hub.
function M.notify(user_id: string?, trip_id: string?)
    if not user_id then return end
    local hub_pid = process.registry.lookup(USER_HUB_PREFIX .. user_id)
    if hub_pid then
        process.send(hub_pid, "trips:changed", { trip_id = trip_id })
    end
end

--- Canonicalize destination: trim + title-case words, squeeze spaces.
function M.canonicalize_destination(s: string?): string
    if not s then return "" end
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    s = s:gsub("%s+", " ")
    return (s:gsub("(%a)([%w']*)", function(first: string, rest: string): string
        return first:upper() .. rest:lower()
    end))
end

--- Compute duration_days from two ISO dates (inclusive).
function M.duration_days(start_date: string, end_date: string): number
    local function parse(d: string): number
        local y, m, day = d:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(day),
                         hour = 12, min = 0, sec = 0 })
    end
    local s: number, e: number = parse(start_date), parse(end_date)
    return math.floor((e - s) / 86400) + 1
end

--- Rough hemisphere-agnostic season from a yyyy-mm-dd start date (northern hemisphere).
function M.season(start_date: string): string
    local m: number = tonumber(start_date:sub(6, 7)) or 0
    if m == 12 or m <= 2 then return "winter"
    elseif m <= 5 then return "spring"
    elseif m <= 8 then return "summer"
    else return "autumn" end
end

return M
