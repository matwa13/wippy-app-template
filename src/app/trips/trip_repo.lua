local sql = require("sql")
local uuid = require("uuid")
local json = require("json")

local DB_RESOURCE = "app:db"

local function now() return os.time() end
local function get_db() return sql.get(DB_RESOURCE) end

local function row_to_trip(row)
    return {
        id             = row.id,
        user_id        = row.user_id,
        title          = row.title,
        destination    = row.destination,
        origin         = row.origin,
        start_date     = row.start_date,
        end_date       = row.end_date,
        status         = row.status,
        workflow_id    = row.workflow_id,
        workflow_state = row.workflow_state and json.decode(row.workflow_state) or nil,
        plan_json      = row.plan_json and json.decode(row.plan_json) or nil,
        created_at     = tonumber(row.created_at),
        updated_at     = tonumber(row.updated_at),
    }
end

local INITIAL_WORKFLOW_STATE = {
    nodes = {
        normalize_input      = { status = "pending" },
        attractions_research = { status = "pending" },
        packing_research     = { status = "pending" },
        flights_linker       = { status = "pending" },
        itinerary_synthesize = { status = "pending" },
        itinerary_critic     = { status = "pending", iterations = 0 },
        build_task_payloads  = { status = "pending" },
        persist_tasks        = { status = "pending" },
    }
}

local function initial_workflow_state_json()
    return json.encode(INITIAL_WORKFLOW_STATE)
end

local function create(user_id, fields)
    local db, err = get_db()
    if err then return nil, err end

    local id = uuid.v7()
    local ts = now()
    local title = string.format("%s, %s – %s", fields.destination, fields.start_date, fields.end_date)
    local ws = initial_workflow_state_json()
    local plan = json.encode({ warnings = {} })

    local _, e_err = db:execute([[
        INSERT INTO trips (id, user_id, title, destination, origin, start_date, end_date,
                           status, workflow_state, plan_json, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'planning', ?, ?, ?, ?)
    ]], { id, user_id, title, fields.destination, fields.origin,
          fields.start_date, fields.end_date, ws, plan, ts, ts })
    db:release()
    if e_err then return nil, e_err end
    return { id = id, title = title, status = "planning" }
end

local function get(user_id, id)
    local db, err = get_db()
    if err then return nil, err end
    local rows, q_err = db:query(
        "SELECT * FROM trips WHERE user_id = ? AND id = ?", { user_id, id })
    db:release()
    if q_err then return nil, q_err end
    if #rows == 0 then return nil, "not_found" end
    return row_to_trip(rows[1])
end

local function list(user_id, filter)
    local db, err = get_db()
    if err then return nil, err end
    local query = [[SELECT id, user_id, title, destination, origin, start_date, end_date,
                           status, workflow_id, created_at, updated_at
                    FROM trips WHERE user_id = ?]]
    local args = { user_id }
    if filter and filter ~= "all" then
        query = query .. " AND status = ?"
        table.insert(args, filter)
    end
    query = query .. " ORDER BY created_at DESC"
    local rows, q_err = db:query(query, args)
    db:release()
    if q_err then return nil, q_err end
    local out = {}
    for _, r in ipairs(rows) do table.insert(out, row_to_trip(r)) end
    return out
end

local function set_workflow_id(id, workflow_id)
    local db, err = get_db()
    if err then return nil, err end
    local _, e_err = db:execute(
        "UPDATE trips SET workflow_id = ?, updated_at = ? WHERE id = ?",
        { workflow_id, now(), id })
    db:release()
    return e_err == nil, e_err
end

local function set_status(id, status)
    local db, err = get_db()
    if err then return nil, err end
    local _, e_err = db:execute(
        "UPDATE trips SET status = ?, updated_at = ? WHERE id = ?",
        { status, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Merge patch into workflow_state.nodes[node_key]. Never touches plan_json.
local function update_node_state(id, node_key, patch)
    local db, err = get_db()
    if err then return nil, err end
    local payload = json.encode({ nodes = { [node_key] = patch } })
    local _, e_err = db:execute(
        "UPDATE trips SET workflow_state = json_patch(COALESCE(workflow_state, '{}'), ?), updated_at = ? WHERE id = ?",
        { payload, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Write one top-level key on plan_json. Never touches workflow_state.
local function update_plan_section(id, key, value)
    local db, err = get_db()
    if err then return nil, err end
    local payload = json.encode({ [key] = value })
    local _, e_err = db:execute(
        "UPDATE trips SET plan_json = json_patch(COALESCE(plan_json, '{}'), ?), updated_at = ? WHERE id = ?",
        { payload, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Append a warning to plan_json.warnings (string).
local function append_warning(id, message)
    local db, err = get_db()
    if err then return nil, err end
    local _, e_err = db:execute(
        [[UPDATE trips SET plan_json = json_set(COALESCE(plan_json, '{"warnings":[]}'), '$.warnings[#]', ?), updated_at = ? WHERE id = ?]],
        { message, now(), id })
    db:release()
    return e_err == nil, e_err
end

return {
    create = create,
    get = get,
    list = list,
    set_workflow_id = set_workflow_id,
    set_status = set_status,
    update_node_state = update_node_state,
    update_plan_section = update_plan_section,
    append_warning = append_warning,
}
