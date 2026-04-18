local function set_of_attractions(attractions)
    local s = {}
    for _, a in ipairs(attractions or {}) do s[a.name] = true end
    return s
end

local function validate(agent_input, exit_output)
    local attractions = set_of_attractions(agent_input.attractions)
    local start_date = agent_input.start_date
    local end_date = agent_input.end_date
    local itinerary = (exit_output or {}).itinerary or {}

    local counts = {}
    for _, item in ipairs(itinerary) do
        if not attractions[item.attraction_name] then
            return false, "unknown attraction: " .. tostring(item.attraction_name)
        end
        if item.date < start_date or item.date > end_date then
            return false, string.format(
                "date %s outside trip range (%s – %s)", item.date, start_date, end_date)
        end
        counts[item.date] = (counts[item.date] or 0) + 1
    end

    if (counts[start_date] or 0) > 2 then
        return false, "arrival date has > 2 items"
    end
    if (counts[end_date] or 0) > 2 then
        return false, "departure date has > 2 items"
    end

    return true
end

--- Called by the dataflow arena as arena.exit_func_id. Receives the agent's
-- structured exit output and its input payload (as params.input).
local function handler(params)
    local ok, err = validate(params.input or {}, params.output or {})
    if ok then return { ok = true } end
    return { ok = false, error = err }
end

return { validate = validate, handler = handler }
