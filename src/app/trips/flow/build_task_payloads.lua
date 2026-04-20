local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local DAY = 86400

local function minus_one_day(iso)
    local y, m, d = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d),
                        hour = 12, min = 0, sec = 0 }) - DAY
    return os.date("!%Y-%m-%d", t):sub(1, 10)
end

local function clamp_to_today(iso, today)
    if iso < today then return today end
    return iso
end

local function flights_title(destination, origin, start_date, end_date)
    if origin and origin ~= "" then
        return string.format("Book flights — %s → %s (%s – %s)",
            origin, destination, start_date, end_date)
    end
    return string.format("Book flights — %s (%s – %s)", destination, start_date, end_date)
end

local function flights_notes(sky_url, origin_missing)
    local lines = {}
    if origin_missing then
        table.insert(lines, "_Origin not provided — flight searches are destination-only._")
        table.insert(lines, "")
    end
    table.insert(lines, string.format("[Search on Skyscanner](%s)", sky_url))
    return table.concat(lines, "\n")
end

local function packing_notes(packing)
    local lines = {}
    for _, cat in ipairs(packing or {}) do
        table.insert(lines, "**" .. cat.category .. "**")
        for _, item in ipairs(cat.items or {}) do
            table.insert(lines, "- [ ] " .. item)
        end
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function attraction_notes(item)
    local lines = {}
    if item.description and item.description ~= "" then
        table.insert(lines, item.description)
        table.insert(lines, "")
    end
    if item.time_slot and item.time_slot ~= "" then
        table.insert(lines, "**Time slot:** " .. item.time_slot)
    end
    if item.estimated_duration_hours then
        table.insert(lines, string.format("**Estimated duration:** %s hours",
            tostring(item.estimated_duration_hours)))
    end
    if item.constraints and #item.constraints > 0 then
        table.insert(lines, "**Notes:** " .. table.concat(item.constraints, "; "))
    end
    return table.concat(lines, "\n")
end

local function build(ctx)
    local rows = {}
    local itinerary = ctx.itinerary or {}
    if #itinerary == 0 then return rows end

    -- Flights task (priority 3 = high)
    table.insert(rows, {
        title        = flights_title(ctx.destination, ctx.origin, ctx.start_date, ctx.end_date),
        scheduled_at = clamp_to_today(ctx.today, ctx.today),
        priority     = 3,
        notes        = flights_notes(ctx.skyscanner_url,
                                      not ctx.origin or ctx.origin == ""),
    })

    -- Packing task (priority 2), only if non-empty
    if ctx.packing and #ctx.packing > 0 then
        table.insert(rows, {
            title        = "Pack for " .. ctx.destination .. " trip",
            scheduled_at = clamp_to_today(minus_one_day(ctx.start_date), ctx.today),
            priority     = 2,
            notes        = packing_notes(ctx.packing),
        })
    end

    -- One per itinerary item (priority 1)
    for _, item in ipairs(itinerary) do
        table.insert(rows, {
            title        = "Visit " .. item.attraction_name,
            scheduled_at = clamp_to_today(item.date, ctx.today),
            priority     = 1,
            notes        = attraction_notes(item),
        })
    end

    return rows
end

local function today_iso() return os.date("!%Y-%m-%d"):sub(1, 10) end

local function handler(input)
    local ctx = trips_common.as_table(input.context)
    local itinerary_out = trips_common.as_table(input.default)
    local support = trips_common.as_table(input.support)
    local flights = trips_common.as_table(support.flights)

    local trip_id = ctx.trip_id
    local user_id = ctx.user_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "build_task_payloads",
            { status = "running", started_at = os.time() })
    end

    local rows = build({
        today              = ctx.today or today_iso(),
        trip_id            = trip_id,
        destination        = ctx.destination,
        origin             = ctx.origin,
        start_date         = ctx.start_date,
        end_date           = ctx.end_date,
        skyscanner_url     = flights.skyscanner_url,
        packing            = support.packing,
        itinerary          = itinerary_out.itinerary,
    })

    if trip_id then
        trip_repo.update_node_state(trip_id, "build_task_payloads",
            { status = "done", ended_at = os.time() })
        trips_common.notify(user_id, trip_id)
    end

    return { task_rows = rows }
end

return { build = build, handler = handler }
