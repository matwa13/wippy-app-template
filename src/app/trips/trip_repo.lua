local sql = require("sql")
local uuid = require("uuid")
local json = require("json")

local DB_RESOURCE = "app:db"

type TripStatus = "planning" | "ready" | "partial" | "failed"
type TripFilter = "all" | "planning" | "ready" | "partial" | "failed"

type NodeState = {
    status: string,
    started_at: number?,
    ended_at: number?,
    error: string?,
}

type WorkflowState = {
    nodes: {[string]: NodeState}?,
}

type PlanJson = {
    warnings: {string}?,
    attractions: {any}?,
    packing: {any}?,
    iata: {any}?,
    flights: {any}?,
    itinerary: {any}?,
}

type Trip = {
    id: string,
    user_id: string?,
    title: string,
    destination: string?,
    origin: string?,
    start_date: string?,
    end_date: string?,
    status: string,
    workflow_id: string?,
    workflow_state: any,
    plan_json: any,
    created_at: number?,
    updated_at: number?,
    tasks: {any}?,
}

type CreateFields = {
    destination: string,
    origin: string?,
    start_date: string,
    end_date: string,
}

type CreateResult = {
    id: string,
    title: string,
    status: string,
}

type DeleteResult = {
    tasks_deleted: number,
}

local function now(): number
    return os.time()
end

local function get_db(): (any, string?)
    return sql.get(DB_RESOURCE)
end

local function row_to_trip(row: any): Trip
    local trip: Trip = {
        id             = tostring(row.id),
        user_id        = row.user_id and tostring(row.user_id) or nil,
        title          = tostring(row.title),
        destination    = row.destination and tostring(row.destination) or nil,
        origin         = row.origin and tostring(row.origin) or nil,
        start_date     = row.start_date and tostring(row.start_date) or nil,
        end_date       = row.end_date and tostring(row.end_date) or nil,
        status         = tostring(row.status),
        workflow_id    = row.workflow_id and tostring(row.workflow_id) or nil,
        workflow_state = row.workflow_state and json.decode(row.workflow_state) or nil,
        plan_json      = row.plan_json and json.decode(row.plan_json) or nil,
        created_at     = row.created_at and tonumber(row.created_at) or nil,
        updated_at     = row.updated_at and tonumber(row.updated_at) or nil,
    }
    return trip
end

local INITIAL_WORKFLOW_STATE: WorkflowState = {
    nodes = {
        normalize_input      = { status = "pending" },
        attractions_research = { status = "pending" },
        packing_research     = { status = "pending" },
        iata_resolver        = { status = "pending" },
        flights_linker       = { status = "pending" },
        itinerary_synthesize = { status = "pending" },
        build_task_payloads  = { status = "pending" },
        persist_tasks        = { status = "pending" },
    }
}

local function initial_workflow_state_json(): string
    return json.encode(INITIAL_WORKFLOW_STATE)
end

local function create(user_id: string, fields: CreateFields): (CreateResult?, string?)
    local db, err = get_db()
    if err then return nil, err end

    local id: string = uuid.v7()
    local ts: number = now()
    local title: string = string.format("%s, %s – %s",
        fields.destination, fields.start_date, fields.end_date)
    local ws: string = initial_workflow_state_json()
    local plan: string = json.encode({ warnings = {} })

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

local function get(user_id: string, id: string): (Trip?, string?)
    local db, err = get_db()
    if err then return nil, err end
    local rows, q_err = db:query(
        "SELECT * FROM trips WHERE user_id = ? AND id = ?", { user_id, id })
    db:release()
    if q_err then return nil, q_err end
    if #rows == 0 then return nil, "not_found" end
    return row_to_trip(rows[1])
end

local function list(user_id: string, filter: TripFilter?): ({Trip}?, string?)
    local db, err = get_db()
    if err then return nil, err end
    local query: string = [[SELECT id, user_id, title, destination, origin, start_date, end_date,
                           status, workflow_id, created_at, updated_at
                    FROM trips WHERE user_id = ?]]
    local args: {any} = { user_id }
    if filter and filter ~= "all" then
        query = query .. " AND status = ?"
        table.insert(args, filter)
    end
    query = query .. " ORDER BY created_at DESC"
    local rows, q_err = db:query(query, args)
    db:release()
    if q_err then return nil, q_err end
    local out: {Trip} = {}
    for _, r in ipairs(rows) do table.insert(out, row_to_trip(r)) end
    return out
end

local function set_workflow_id(id: string, workflow_id: string): (boolean, string?)
    local db, err = get_db()
    if err then return false, err end
    local _, e_err = db:execute(
        "UPDATE trips SET workflow_id = ?, updated_at = ? WHERE id = ?",
        { workflow_id, now(), id })
    db:release()
    return e_err == nil, e_err
end

local function set_status(id: string, status: string): (boolean, string?)
    local db, err = get_db()
    if err then return false, err end
    local _, e_err = db:execute(
        "UPDATE trips SET status = ?, updated_at = ? WHERE id = ?",
        { status, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Merge patch into workflow_state.nodes[node_key]. Never touches plan_json.
local function update_node_state(id: string, node_key: string, patch: NodeState): (boolean, string?)
    local db, err = get_db()
    if err then return false, err end
    local payload: string = json.encode({ nodes = { [node_key] = patch } })
    local _, e_err = db:execute(
        "UPDATE trips SET workflow_state = json_patch(COALESCE(workflow_state, '{}'), ?), updated_at = ? WHERE id = ?",
        { payload, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Write one top-level key on plan_json. Never touches workflow_state.
local function update_plan_section(id: string, key: string, value: any): (boolean, string?)
    local db, err = get_db()
    if err then return false, err end
    local payload: string = json.encode({ [key] = value })
    local _, e_err = db:execute(
        "UPDATE trips SET plan_json = json_patch(COALESCE(plan_json, '{}'), ?), updated_at = ? WHERE id = ?",
        { payload, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Append a warning string to plan_json.warnings.
local function append_warning(id: string, message: string): (boolean, string?)
    local db, err = get_db()
    if err then return false, err end
    local _, e_err = db:execute(
        [[UPDATE trips SET plan_json = json_set(COALESCE(plan_json, '{"warnings":[]}'), '$.warnings[#]', ?), updated_at = ? WHERE id = ?]],
        { message, now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Hard-delete a trip and every task attached to it (transactional).
-- Refuses to delete while the trip is still planning (workflow in flight).
local function delete(user_id: string, id: string): (DeleteResult?, string?)
    local db, err = get_db()
    if err then return nil, err end

    -- Load under the same connection before opening the transaction so we can
    -- give a clean "not_found" / "planning" error without a stray tx rollback.
    local rows, q_err = db:query(
        "SELECT status FROM trips WHERE user_id = ? AND id = ?", { user_id, id })
    if q_err then db:release(); return nil, q_err end
    if #rows == 0 then db:release(); return nil, "not_found" end
    if rows[1].status == "planning" then
        db:release()
        return nil, "trip_in_progress"
    end

    local tx, t_err = db:begin()
    if t_err then db:release(); return nil, t_err end

    local del_tasks, dt_err = tx:execute(
        "DELETE FROM tasks WHERE user_id = ? AND trip_id = ?", { user_id, id })
    if dt_err then tx:rollback(); db:release(); return nil, dt_err end

    local del_trip, dp_err = tx:execute(
        "DELETE FROM trips WHERE user_id = ? AND id = ?", { user_id, id })
    if dp_err then tx:rollback(); db:release(); return nil, dp_err end
    if del_trip.rows_affected == 0 then
        tx:rollback(); db:release(); return nil, "not_found"
    end

    local ok, c_err = tx:commit()
    db:release()
    if not ok then return nil, c_err end

    return { tasks_deleted = del_tasks.rows_affected or 0 }
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
    delete = delete,
}
