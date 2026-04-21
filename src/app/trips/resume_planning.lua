local sql = require("sql")
local logger = require("logger")
local df_client = require("df_client")

local DB_RESOURCE = "app:db"
local INIT_FUNC_ID = "userspace.dataflow.session:artifact"

local log = logger:named("trip_resume")

type ResumeResult = {
    resumed: number,
    skipped: number?,
    failed: number?,
    error: string?,
}

--- Respawn the dataflow orchestrator for every trip still in `planning`.
-- Commands and node state are durable; the orchestrator process is not,
-- so we re-spawn it after server restart. Idempotent: skips workflows
-- whose orchestrator is already registered.
local function run(): ResumeResult
    local db, err = sql.get(DB_RESOURCE)
    if err then
        log:error("failed to acquire db", { error = err })
        return { resumed = 0, error = tostring(err) }
    end

    local rows, q_err = db:query(
        "SELECT id, workflow_id FROM trips WHERE status = 'planning' AND workflow_id IS NOT NULL",
        {}
    )
    db:release()
    if q_err then
        log:error("failed to query planning trips", { error = q_err })
        return { resumed = 0, error = tostring(q_err) }
    end

    if #rows == 0 then
        return { resumed = 0 }
    end

    local client, c_err = df_client.new()
    if c_err then
        log:error("failed to create dataflow client", { error = c_err })
        return { resumed = 0, error = c_err }
    end

    local resumed: number = 0
    local skipped: number = 0
    local failed: number = 0
    for _, row in ipairs(rows) do
        local wid: string = tostring(row.workflow_id)
        local existing = process.registry.lookup("dataflow." .. wid)
        if existing then
            skipped = skipped + 1
        else
            local _, s_err = client:start(wid, { init_func_id = INIT_FUNC_ID })
            if s_err then
                failed = failed + 1
                log:error("failed to resume workflow", {
                    trip_id = row.id,
                    workflow_id = wid,
                    error = s_err,
                })
            else
                resumed = resumed + 1
            end
        end
    end

    log:info("trip workflow recovery", {
        resumed = resumed,
        skipped = skipped,
        failed = failed,
        total = #rows,
    })

    return { resumed = resumed, skipped = skipped, failed = failed }
end

return { run = run }
