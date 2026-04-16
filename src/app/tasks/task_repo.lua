local sql = require("sql")
local uuid = require("uuid")

local DB_RESOURCE = "app:db"

local function now()
    return os.time()
end

local function get_db()
    return sql.get(DB_RESOURCE)
end

local function row_to_task(row)
    return {
        id         = row.id,
        title      = row.title,
        done       = tonumber(row.done) == 1,
        notes      = row.notes,
        due_date   = row.due_date,
        priority   = tonumber(row.priority) or 2,
        created_at = tonumber(row.created_at),
        updated_at = tonumber(row.updated_at),
    }
end

local function list(user_id, filter)
    local db, err = get_db()
    if err then return nil, err end

    local query = "SELECT id, title, done, notes, due_date, priority, created_at, updated_at FROM tasks WHERE user_id = ?"
    local args = { user_id }

    if filter == "open" then
        query = query .. " AND done = 0"
    elseif filter == "done" then
        query = query .. " AND done = 1"
    end
    query = query .. " ORDER BY "
        .. "CASE WHEN done = 0 AND due_date IS NOT NULL AND due_date < date('now') THEN 0 "
        ..      "WHEN done = 0 THEN 1 ELSE 2 END ASC, "
        .. "CASE WHEN done = 1 THEN 0 ELSE priority END DESC, "
        .. "CASE WHEN done = 1 THEN 0 WHEN due_date IS NULL THEN 1 ELSE 0 END ASC, "
        .. "due_date ASC, "
        .. "CASE WHEN done = 1 THEN updated_at ELSE 0 END DESC, "
        .. "created_at DESC"

    local rows, q_err = db:query(query, args)
    db:release()
    if q_err then return nil, q_err end

    local tasks = {}
    for _, r in ipairs(rows) do
        table.insert(tasks, row_to_task(r))
    end
    return tasks
end

local function get(user_id, id)
    local db, err = get_db()
    if err then return nil, err end

    local rows, q_err = db:query(
        "SELECT id, title, done, notes, due_date, priority, created_at, updated_at FROM tasks WHERE user_id = ? AND id = ?",
        { user_id, id }
    )
    db:release()
    if q_err then return nil, q_err end
    if #rows == 0 then return nil, "not_found" end
    return row_to_task(rows[1])
end

local function create(user_id, title, opts)
    if not title or title == "" then return nil, "title is required" end
    opts = opts or {}

    local db, err = get_db()
    if err then return nil, err end

    local id = uuid.v7()
    local ts = now()
    local priority = opts.priority or 2
    local _, e_err = db:execute(
        "INSERT INTO tasks (id, user_id, title, done, notes, due_date, priority, created_at, updated_at) VALUES (?, ?, ?, 0, ?, ?, ?, ?, ?)",
        { id, user_id, title, opts.notes, opts.due_date, priority, ts, ts }
    )
    db:release()
    if e_err then return nil, e_err end

    return { id = id, title = title, done = false, notes = opts.notes, due_date = opts.due_date, priority = priority, created_at = ts, updated_at = ts }
end

local function update(user_id, id, fields)
    local sets, args = {}, {}
    if fields.title ~= nil then
        table.insert(sets, "title = ?")
        table.insert(args, fields.title)
    end
    if fields.done ~= nil then
        table.insert(sets, "done = ?")
        table.insert(args, fields.done and 1 or 0)
    end
    if fields.notes ~= nil then
        table.insert(sets, "notes = ?")
        table.insert(args, fields.notes ~= "" and fields.notes or nil)
    end
    if fields.due_date ~= nil then
        table.insert(sets, "due_date = ?")
        table.insert(args, fields.due_date ~= "" and fields.due_date or nil)
    end
    if fields.priority ~= nil then
        table.insert(sets, "priority = ?")
        table.insert(args, fields.priority)
    end
    if #sets == 0 then return nil, "no fields to update" end

    table.insert(sets, "updated_at = ?")
    table.insert(args, now())
    table.insert(args, user_id)
    table.insert(args, id)

    local db, err = get_db()
    if err then return nil, err end

    local res, e_err = db:execute(
        "UPDATE tasks SET " .. table.concat(sets, ", ") .. " WHERE user_id = ? AND id = ?",
        args
    )
    db:release()
    if e_err then return nil, e_err end
    if res.rows_affected == 0 then return nil, "not_found" end

    return get(user_id, id)
end

local function delete(user_id, id)
    local db, err = get_db()
    if err then return nil, err end

    local res, e_err = db:execute(
        "DELETE FROM tasks WHERE user_id = ? AND id = ?",
        { user_id, id }
    )
    db:release()
    if e_err then return nil, e_err end
    if res.rows_affected == 0 then return nil, "not_found" end
    return true
end

--- Fuzzy-match a task by title for a user.
-- Rule: exact (case-insensitive) → unique substring → ambiguous.
-- @return task, err, candidates
local function find_by_title(user_id, query, only_open)
    if not query or query == "" then return nil, "title is required" end

    local tasks, err = list(user_id, only_open and "open" or "all")
    if err then return nil, err end

    local q = query:lower()
    local exact, substr = {}, {}
    for _, t in ipairs(tasks) do
        local title_l = t.title:lower()
        if title_l == q then
            table.insert(exact, t)
        elseif title_l:find(q, 1, true) then
            table.insert(substr, t)
        end
    end

    if #exact == 1 then return exact[1] end
    if #exact > 1 then return nil, "ambiguous", exact end
    if #substr == 1 then return substr[1] end
    if #substr > 1 then return nil, "ambiguous", substr end
    return nil, "not_found"
end

return {
    list = list,
    get = get,
    create = create,
    update = update,
    delete = delete,
    find_by_title = find_by_title,
}
