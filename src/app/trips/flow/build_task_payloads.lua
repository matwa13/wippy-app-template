local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local DAY = 86400

type BuildContext = {
    today: string,
    trip_id: string?,
    destination: string,
    origin: string?,
    start_date: string,
    end_date: string,
    skyscanner_url: any,
    packing: any,
    itinerary: any,
}

type TaskRow = {
    title: string,
    scheduled_at: string,
    due_date: string?,
    priority: number,
    notes: string,
}

type GateInput = {
    default: any?,
    context: any?,
    support: any?,
}

type BuildOutput = {
    task_rows: {TaskRow},
}

local function minus_one_day(iso: string): string
    local y, m, d = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    local t: number = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d),
                        hour = 12, min = 0, sec = 0 }) - DAY
    return tostring(os.date("!%Y-%m-%d", t)):sub(1, 10)
end

local function clamp_to_today(iso: string, today: string): string
    if iso < today then return today end
    return iso
end

local function flights_title(destination: string, origin: string?,
                            start_date: string, end_date: string): string
    if origin and origin ~= "" then
        return string.format("Book flights — %s → %s (%s – %s)",
            origin, destination, start_date, end_date)
    end
    return string.format("Book flights — %s (%s – %s)", destination, start_date, end_date)
end

local function flights_notes(sky_url: string?): string
    if sky_url and sky_url ~= "" then
        return string.format("[Search on Skyscanner](%s)", sky_url)
    end
    return "_Flight search link unavailable — see trip warnings for details._"
end

local function packing_notes(packing: {any}?): string
    local lines: {string} = {}
    for _, cat in ipairs(packing or {}) do
        table.insert(lines, "**" .. tostring(cat.category) .. "**")
        for _, item in ipairs(cat.items or {}) do
            table.insert(lines, "- [ ] " .. tostring(item))
        end
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function attraction_notes(item: any): string
    local lines: {string} = {}
    if item.description and item.description ~= "" then
        table.insert(lines, tostring(item.description))
        table.insert(lines, "")
    end
    if item.time_slot and item.time_slot ~= "" then
        table.insert(lines, "**Time slot:** " .. tostring(item.time_slot))
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

local function build(ctx: BuildContext): {TaskRow}
    local rows: {TaskRow} = {}
    local itinerary: any = ctx.itinerary or {}
    if #itinerary == 0 then return rows end

    -- Flights task (priority 3 = high)
    table.insert(rows, {
        title        = flights_title(ctx.destination, ctx.origin, ctx.start_date, ctx.end_date),
        scheduled_at = clamp_to_today(ctx.today, ctx.today),
        priority     = 3,
        notes        = flights_notes(ctx.skyscanner_url),
    })

    -- Packing task (priority 3), only if non-empty
    if ctx.packing and #ctx.packing > 0 then
        local date: string = clamp_to_today(minus_one_day(ctx.start_date), ctx.today)
        table.insert(rows, {
            title        = "Pack for " .. ctx.destination .. " trip",
            scheduled_at = date,
            due_date     = date,
            priority     = 3,
            notes        = packing_notes(ctx.packing),
        })
    end

    -- One per itinerary item (priority 1). The itinerary date is effectively
    -- a hard deadline (the trip ends), so mirror it into due_date so it shows
    -- up on the /tasks page alongside other dated tasks.
    for _, item in ipairs(itinerary) do
        local date: string = clamp_to_today(tostring(item.date), ctx.today)
        table.insert(rows, {
            title        = "Visit " .. tostring(item.attraction_name),
            scheduled_at = date,
            due_date     = date,
            priority     = 1,
            notes        = attraction_notes(item),
        })
    end

    return rows
end

local function today_iso(): string return tostring(os.date("!%Y-%m-%d")):sub(1, 10) end

local function handler(input: GateInput): BuildOutput
    local ctx = trips_common.as_table(input.context)
    local itinerary_out = trips_common.as_table(input.default)
    local support = trips_common.as_table(input.support)
    local flights = trips_common.as_table(support.flights)

    local trip_id: string? = ctx.trip_id and tostring(ctx.trip_id) or nil
    local user_id: string? = ctx.user_id and tostring(ctx.user_id) or nil

    if trip_id then
        trip_repo.update_node_state(trip_id, "build_task_payloads",
            { status = "running", started_at = os.time() })
    end

    local today: string = ctx.today and tostring(ctx.today) or today_iso()
    local rows: {TaskRow} = build({
        today              = today,
        trip_id            = trip_id,
        destination        = tostring(ctx.destination),
        origin             = ctx.origin and tostring(ctx.origin) or nil,
        start_date         = tostring(ctx.start_date),
        end_date           = tostring(ctx.end_date),
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
