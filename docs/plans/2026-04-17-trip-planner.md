# Trip Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Progress

**Branch:** `feature/trip-planner-subagent-driven-development`
**Resume at:** Phase 3 (frontend) — Tasks 18-22. Phases 1+2 complete, Tasks 15-17 complete (backend wrap-up). **Pause for user confirmation before starting Phase 3.**

| Task | Status | Commit | Notes |
|---|---|---|---|
| Pre-flight A+B | ✅ | — | workspace clean, spec re-read |
| 1. Migration `trips` | ✅ | `08733f7` | ships with 2+3 |
| 2. Migration `tasks.trip_id+scheduled_at` | ✅ | `08733f7` | |
| 3. `trip_repo.lua` + `trips_common.lua` + `_index.yaml` | ✅ | `08733f7` | 7/7 tests pass |
| 4. `GET /api/v1/trips` | ✅ | `0c44fd0` | |
| 5. `POST /api/v1/trips` (row only) | ✅ | `d6ba739` | workflow kickoff deferred to Task 15 |
| 6. `GET /api/v1/trips/:id` | ✅ | `0f2d913` | |
| 7. `normalize_input` func node | ✅ | `27608ac` | spec ✅ + quality ✅; also fixed 2 latent bugs in `trips_common.lua` |
| 8. `flights_linker` func node | ✅ | `1fdef92` | spec ✅ + quality ✅ (with known deferred url_encode finding — see observations) |
| 9. `build_task_payloads` | ✅ | `9bd6594` + `be07b3f` | spec ✅ + quality ✅ (findings plan-prescribed or stylistic; logged in observations) |
| 10. `validate_synthesizer_exit` | ✅ | `3b0fb30` | spec ✅ + quality ✅ (findings plan-prescribed or against "no defensive coding" rule; logged in observations) |
| 11. `save_attractions` + `save_packing` | ✅ | `dba418f` | spec ✅ + quality ✅ (no issues) |
| 12. `persist_tasks` + `task_repo.create_with_trip` | ✅ | `df1ff66` | spec ✅ + quality ✅ (minor observations logged) |
| 13. 4 workflow agents | ✅ | `b15963f` + `dd1c99d` | spec ✅ + quality ✅; `dd1c99d` adds explicit verbatim-name instruction to synthesizer prompt (validator does exact-match lookup) |
| 2C.5 race + url_encode | ✅ | `891b58a` + `cb7b401` | `json_patch`/`json_set` collapse 3 helpers to single UPDATE (race eliminated); space → `%20` for path-segment URLs |
| 14. `trip_flow.lua` DAG assembly | ✅ | `1c6ac1f` + `b9a34c1` + `6ea2b08` | spec ✅ + quality ✅ (2 bugs caught & fixed in review loop: fan-out dead nodes → `b9a34c1`; discriminator wrapping → `6ea2b08`) |
| 15. `trip_service` + wire HTTP POST | ✅ | `48ea74d` + `d4b883e` | spec ✅ + quality ✅; review caught latent canonicalization bug in the plan's snippet (`trip.destination or input.destination` always fell through to raw input because `trip_repo.create` returns only `{id,title,status}`) — fixed by canonicalizing once up front |
| 16. `plan_trip` tool + `trips_trait` | ✅ | `a38b3cf` | spec ✅ + quality ✅ (only caveat = `trips` missing from NavigateTo enum, which is literally Task 17) |
| 17. NavigateTo /trips wiring | ✅ | (next commit) | 3 trivial inline edits (PAGES map + enum + Wippy prompt); 21/21 tests still pass |
| 18-25 | ⬜ | | Phase 3 (frontend Vue pages) — **paused for user** |

**All trips tests:** 21/21 pass as of `be07b3f`.

**When you resume next session — do this first (literally the first thing before any new task):**

1. Read this Progress section to confirm state.
2. Phase 2 (backend + dataflow) is fully complete. Next up: Task 15 (HTTP kickoff that launches the workflow), then Task 16 (integration smoke test of the compiled DAG), then Phase 3 Tasks 17-22 (Vue pages for trip list / create / detail with hub-driven refresh).
3. **Integration test note:** no end-to-end run of the compiled DAG has happened yet. Task 16 should exercise the full flow once before Phase 3 UI work — this is where the `error_to("@fail")` scope observation (below) will surface if it matters in practice.

**Review observations to revisit (non-blocking, plan-prescribed code):**
- ~~`trip_repo.lua` — `update_node_state` / `update_plan_section` / `append_warning` do SELECT+UPDATE as two statements.~~ **Resolved in `891b58a` (Batch 2C.5):** all three helpers now use a single UPDATE via `json_patch` / `json_set`, which acquires an atomic write lock. Concurrent writes from Task 14's DAG branches serialize correctly.
- `list_trips.lua` — filter value passes to SQL as a bound param without an allow-list. Typos like `?filter=Planning` produce empty results silently. Low severity.
- `get_trip.lua` — `scheduled_at` is not type-coerced in `load_trip_tasks` (stays TEXT). Harmless today; watch if column type ever unifies with `created_at`.
- ~~`flights_linker.lua` — `url_encode` converts space to `+` instead of `%20`.~~ **Resolved in `cb7b401` (Batch 2C.5):** space is now percent-encoded in path components. Multi-word cities produce correct URLs.
- **Task 9 test 2 contradiction (resolved in `be07b3f`):** The plan as written had `test 2 = omits packing when packing is nil` with `itinerary = {}` expecting 1 row, which directly contradicted `test 3 = omits flights when itinerary is empty` with `itinerary = {}` expecting 0 rows. The plan's own implementation code (`if #itinerary == 0 then return rows end`) failed test 2. We corrected test 2's fixture to have a non-empty itinerary (the test's stated purpose is packing omission, which requires *some* rows to assert against) and reverted the implementation to the plan's intended single early-return. If you rebuild from the plan doc, remember this correction.
- `build_task_payloads.lua:76` — `clamp_to_today(ctx.today, ctx.today)` is a no-op (always returns `ctx.today`). Plan-prescribed verbatim. Harmless redundancy; could simplify to `scheduled_at = ctx.today` if we ever revise the plan.
- `validate_synthesizer_exit.lua:18` + `build_task_payloads.lua:13` — use lexicographic ISO-8601 string comparison for dates. Assumes upstream (`normalize_input` / LLM system prompts) always emits zero-padded `YYYY-MM-DD`. Malformed input (e.g. `"2026-5-1"`) would silently mis-order. Consistent with project rule "don't program defensively"; noted for future hardening only.
- `validate_synthesizer_exit.lua:25-29` — density cap (≤2 items/day) only checked for `start_date` and `end_date`, not mid-trip dates. Plan-prescribed; the intent is that capacity constraints only apply to arrival/departure days (partial travel days).
- Test 3 description in `build_task_payloads_test.lua:55` ("omits flights when itinerary is empty (no itinerary → no tasks except flights?)") is confusing — the `?` makes it read as a question. The assertion (`#rows == 0`) is correct and matches the implementation. Plan-prescribed wording; cosmetic only.
- `task_repo.create_with_trip` returns a row shape that includes `trip_id` + `scheduled_at`, but `row_to_task` (used by `get`/`list`) does not expose these fields. `persist_tasks` discards the return value so no live breakage, but any future caller expecting `get()`/`list()` to include trip-linked fields will get stale data. Revisit when the frontend needs to surface `scheduled_at`/`trip_id` on task rows.
- `persist_tasks.lua:32` has a plan-prescribed `-- Determine final status: ready or partial...` comment that explains WHAT, not WHY — against project style. Harmless; leave unless we touch that function.
- `persist_tasks.lua:33-34` does a full `trip_repo.get` round-trip only to read one node's status. Could be replaced by passing `packing_failed` as a field on `input` from the DAG join. Plan-prescribed; revisit when Task 14 wires the DAG.
- **Task 14 review loop — two bugs caught + fixed:** (a) fan-out from `normalize_input` initially relied on auto-chain, which only fires when a node has *no* explicit edges; the first `:to("attractions_research")` silenced auto-chain and left `packing_research` + `flights_linker` as dead nodes. Fixed in `b9a34c1` with three explicit `:to(sibling)` calls. (b) `:to(target)` without an `input_key` sets the edge discriminator to the *source node's name*, and the func-node runtime only unwraps `"default"`/empty discriminators — named ones deliver `{<source_name> = content}` to the handler. This would have broken 5 of the data-flow edges (fan-out × 3 + agent→persister × 2). Fixed in `6ea2b08` by adding explicit `"default"` input_key to those 5 edges. Join edges intentionally keep their named discriminators (`"attractions"`, `"packing"`, `"flights"`) because the join collects inputs keyed by name.
- **Task 15 — `set_workflow_id` return value unchecked (deferred, plan-prescribed):** `trip_service.create_trip` at `src/app/trips/trip_service.lua:30` calls `trip_repo.set_workflow_id(trip.id, workflow_id)` without checking the `(ok, err)` return. If the DB write fails (e.g. transient SQLite write-contention with the workflow already emitting), the trip row has no `workflow_id` but the handler still returns 201. Consistent with project rule "don't program defensively"; revisit if we see operational issues.
- **Task 15 — destination canonicalization bug in plan's snippet (caught + fixed):** the plan's `trip_service.lua` snippet had `destination = trip.destination or input.destination` in the workflow payload, but `trip_repo.create` returns `{id, title, status}` with no `destination` field — so the fallback always fired and the raw uncanonicalized input string was passed to the workflow (while the canonicalized version reached the DB). Fix (`d4b883e`) computes `destination` and `origin` once via `trips_common.canonicalize_destination` at the top of `create_trip` and passes the same values to both `trip_repo.create` and `trip_flow.build_and_start`. `normalize_input` still canonicalizes defensively inside the workflow; `canonicalize_destination` is idempotent so the double application is a no-op.
- **Task 14 — `error_to("@fail")` scope (deferred; verify at Task 16 integration):** the single `:error_to("@fail")` at the end of the flow attaches only to `persist_tasks` (the node that was `last_node_id` at that point). Upstream node failures (e.g. `normalize_input`, agents, `flights_linker`, `save_*`, `build_task_payloads`) do not route explicitly; the scheduler terminates via a generic deadlock path rather than surfacing the node's actual error. Workflow still terminates — this is an observability gap, not a crash. If Task 16 shows misleading error payloads in the dashboard, add per-branch `:error_to("@fail")` calls.

**Agreed batching (re-confirm with user on resume):**
- Batch 2B = Tasks 11+12 (func nodes `save_attractions` + `save_packing` + `persist_tasks` — all touch `trip_repo` update helpers)
- Batch 2C = Task 13 (4 workflow agents in `agents/_index.yaml`)
- Batch 2C.5 = dedicated commit fixing the race condition + url_encode finding (prerequisite before Task 14's concurrent DAG)
- Batch 2D = Task 14 (`trip_flow.lua` DAG assembly) ✅ — **paused for user** before Phase 3
- Next: Tasks 15 (HTTP kickoff) + 16 (integration test) before Phase 3 frontend work
- User prefers: implementer on Sonnet, spec reviewer on Sonnet, code quality via `feature-dev:code-reviewer` agent. Pause after each phase.

**Goal:** Ship the Trip Planner feature from `docs/specs/trip-planner.md` — a dataflow workflow that turns destination + dates into an itinerary, packing list, flight links, and a structured set of tasks, exposed via both chat tool and web form.

**Architecture:** Backend is `src/app/trips/` (migrations + repo + service + HTTP + workflow funcs + 4 agents). Workflow uses `userspace.dataflow.flow:flow` builder: `normalize_input` (func) → 3 concurrent branches (attractions agent + packing agent + flights func) → join → cycle template {synthesizer agent → critic agent} (≤2 iter) → `build_task_payloads` (func) → `persist_tasks` (func). Two JSON columns on `trips` (`workflow_state` for execution state, `plan_json` for content) are kept strictly separate. Frontend is three new Vue pages with hub-driven refresh via `trips:changed`.

**Tech Stack:** Wippy Lua (func/agent registry entries, `wippy/dataflow`, `sql`, `uuid`, `process` hub), Vue 3 + Vite + TypeScript + PrimeVue + Tailwind + TanStack Query + Pinia.

**Conventions in this plan:**
- **Node key** = short name used in `workflow_state.nodes` keyed to UI (e.g. `attractions_research`). Set via `:as("attractions_research")` on the node.
- **Agent id** = full registry id for the agent entry (e.g. `app.agents:trip_attractions_researcher`). Passed to `:agent(...)`.
- When editing `*_index.yaml` files, keep them sorted alphabetically-ish within their section blocks and re-read with `Read` before each Edit.

---

## File Structure

### New files

```
src/app/trips/
  _index.yaml                              -- registry: migrations, repo, funcs, http, tool
  migrations/
    01_init.lua                            -- trips table
    02_tasks_fields.lua                    -- tasks.trip_id + tasks.scheduled_at
  trip_repo.lua                            -- CRUD + column-scoped update helpers
  trip_service.lua                         -- create_trip: insert row, start workflow, return {trip_id, url}
  trips_common.lua                         -- shared helpers: notify hub, date math
  api/
    create_trip.lua                        -- POST /api/v1/trips
    list_trips.lua                         -- GET  /api/v1/trips
    get_trip.lua                           -- GET  /api/v1/trips/{id}
  flow/
    trip_flow.lua                          -- builds and starts the DAG
    normalize_input.lua                    -- func node
    flights_linker.lua                     -- func node
    build_task_payloads.lua                -- func node
    persist_tasks.lua                      -- func node
    save_attractions.lua                   -- func: agent output → plan_json.attractions
    save_packing.lua                       -- func: agent output → plan_json.packing (non-critical)
    validate_synthesizer_exit.lua          -- exit_func_id validator for synthesizer
  tools/
    plan_trip.lua                          -- agent tool: plan_trip
  trip_repo_test.lua
  normalize_input_test.lua
  flights_linker_test.lua
  build_task_payloads_test.lua
  validate_synthesizer_exit_test.lua

frontend/applications/main/src/
  stores/trips.ts                          -- Pinia store for trip list / current trip
  pages/trips-list.vue                     -- /trips
  pages/trips-create.vue                   -- /trips/create
  pages/trip-detail.vue                    -- /trips/:id
```

### Modified files

```
src/app/agents/_index.yaml                 -- add 4 workflow agents; add trip plan tool & trait
src/app/agents/navigate_to.lua             -- add "trips" to PAGES map
frontend/applications/main/src/router/index.ts -- add /trips, /trips/create, /trips/:id
frontend/applications/main/src/app/app.vue -- add "Trips" entry to navItems
docs/catalog.json                          -- mark trip planner as implemented
docs/specs/trip-planner.md                 -- append "Implemented" badge (optional)
CLAUDE.md                                  -- append row to "Implemented Features" table
```

---

## Pre-flight

- [ ] **Step A: Verify workspace is clean apart from this spec**

Run:
```bash
cd /Users/matwa/w/wippy/wippy-app-template
git status --short
```
Expected: only `docs/PLAN.md`, `docs/specs/trip-planner.md`, `docs/plans/` untracked/staged. No unrelated modifications.

- [ ] **Step B: Re-read the spec and this plan's File Structure table end-to-end before starting**

Read: `docs/specs/trip-planner.md` and the "File Structure" section above. When a task says "see spec §N", look it up.

---

## Task 1: Migration — `trips` table

**Files:**
- Create: `src/app/trips/migrations/01_init.lua`

- [ ] **Step 1: Write the migration**

```lua
return require("migration").define(function()
    migration("Create trips table", function()
        database("sqlite", function()
            up(function(db)
                db:execute([[
                    CREATE TABLE IF NOT EXISTS trips (
                        id             TEXT PRIMARY KEY,
                        user_id        TEXT NOT NULL,
                        title          TEXT NOT NULL,
                        destination    TEXT NOT NULL,
                        origin         TEXT,
                        start_date     TEXT NOT NULL,
                        end_date       TEXT NOT NULL,
                        status         TEXT NOT NULL DEFAULT 'planning',
                        workflow_id    TEXT,
                        workflow_state TEXT,
                        plan_json      TEXT,
                        created_at     INTEGER NOT NULL DEFAULT (unixepoch()),
                        updated_at     INTEGER NOT NULL DEFAULT (unixepoch())
                    )
                ]])
                db:execute("CREATE INDEX IF NOT EXISTS idx_trips_user ON trips(user_id, created_at DESC)")
                return true
            end)

            down(function(db)
                db:execute("DROP TABLE IF EXISTS trips")
                return true
            end)
        end)
    end)
end)
```

- [ ] **Step 2: Stage the file** — will be registered in `_index.yaml` in Task 3.

No commit yet — Tasks 1+2+3 ship together.

---

## Task 2: Migration — `tasks.trip_id` + `tasks.scheduled_at`

**Files:**
- Create: `src/app/trips/migrations/02_tasks_fields.lua`

- [ ] **Step 1: Write the migration**

```lua
return require("migration").define(function()
    migration("Add trip_id and scheduled_at to tasks", function()
        database("sqlite", function()
            up(function(db)
                db:execute("ALTER TABLE tasks ADD COLUMN trip_id TEXT")
                db:execute("ALTER TABLE tasks ADD COLUMN scheduled_at TEXT")
                db:execute("CREATE INDEX IF NOT EXISTS idx_tasks_trip ON tasks(trip_id)")
                return true
            end)

            down(function(db)
                -- SQLite < 3.35 cannot DROP COLUMN; no-op is acceptable
                return true
            end)
        end)
    end)
end)
```

---

## Task 3: Repository — `trip_repo.lua`

**Files:**
- Create: `src/app/trips/trip_repo.lua`
- Create: `src/app/trips/trip_repo_test.lua`
- Create: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write `trip_repo.lua`**

```lua
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
    local rows, q_err = db:query("SELECT workflow_state FROM trips WHERE id = ?", { id })
    if q_err then db:release(); return nil, q_err end
    if #rows == 0 then db:release(); return nil, "not_found" end

    local ws = rows[1].workflow_state and json.decode(rows[1].workflow_state) or { nodes = {} }
    ws.nodes = ws.nodes or {}
    ws.nodes[node_key] = ws.nodes[node_key] or {}
    for k, v in pairs(patch) do ws.nodes[node_key][k] = v end

    local _, e_err = db:execute(
        "UPDATE trips SET workflow_state = ?, updated_at = ? WHERE id = ?",
        { json.encode(ws), now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Write one top-level key on plan_json. Never touches workflow_state.
local function update_plan_section(id, key, value)
    local db, err = get_db()
    if err then return nil, err end
    local rows, q_err = db:query("SELECT plan_json FROM trips WHERE id = ?", { id })
    if q_err then db:release(); return nil, q_err end
    if #rows == 0 then db:release(); return nil, "not_found" end

    local plan = rows[1].plan_json and json.decode(rows[1].plan_json) or {}
    plan[key] = value

    local _, e_err = db:execute(
        "UPDATE trips SET plan_json = ?, updated_at = ? WHERE id = ?",
        { json.encode(plan), now(), id })
    db:release()
    return e_err == nil, e_err
end

--- Append a warning to plan_json.warnings (string).
local function append_warning(id, message)
    local db, err = get_db()
    if err then return nil, err end
    local rows, q_err = db:query("SELECT plan_json FROM trips WHERE id = ?", { id })
    if q_err then db:release(); return nil, q_err end
    if #rows == 0 then db:release(); return nil, "not_found" end

    local plan = rows[1].plan_json and json.decode(rows[1].plan_json) or {}
    plan.warnings = plan.warnings or {}
    table.insert(plan.warnings, message)

    local _, e_err = db:execute(
        "UPDATE trips SET plan_json = ?, updated_at = ? WHERE id = ?",
        { json.encode(plan), now(), id })
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
```

- [ ] **Step 2: Write `trips_common.lua`**

Create `src/app/trips/trips_common.lua`:

```lua
local USER_HUB_PREFIX = "user."

local M = {}

--- Broadcast a trips:changed event to the given user hub.
function M.notify(user_id, trip_id)
    local hub_pid = process.registry.lookup(USER_HUB_PREFIX .. user_id)
    if hub_pid then
        process.send(hub_pid, "trips:changed", { trip_id = trip_id })
    end
end

--- Canonicalize destination: trim + title-case words, squeeze spaces.
function M.canonicalize_destination(s)
    if not s then return "" end
    s = (s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
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
```

- [ ] **Step 3: Write `trip_repo_test.lua`**

```lua
local test = require("test")
local trip_repo = require("trip_repo")

local TEST_USER = "trip_test_user_" .. tostring(os.time())
local state = {}

local function define_tests()
    test.describe("trip_repo", function()
        test.it("creates a trip with initial workflow_state and plan_json", function()
            local r, err = trip_repo.create(TEST_USER, {
                destination = "Tokyo",
                origin = "Berlin",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.is_nil(err)
            test.not_nil(r)
            test.eq(r.status, "planning")
            state.trip_id = r.id
        end)

        test.it("fetched trip has pending workflow_state.nodes", function()
            local t, err = trip_repo.get(TEST_USER, state.trip_id)
            test.is_nil(err)
            test.eq(t.workflow_state.nodes.normalize_input.status, "pending")
            test.eq(t.workflow_state.nodes.itinerary_critic.iterations, 0)
            test.eq(#(t.plan_json.warnings or {}), 0)
        end)

        test.it("update_node_state merges fields", function()
            local ok, err = trip_repo.update_node_state(state.trip_id, "normalize_input",
                { status = "done", started_at = 100, ended_at = 200 })
            test.is_true(ok); test.is_nil(err)
            local t = trip_repo.get(TEST_USER, state.trip_id)
            test.eq(t.workflow_state.nodes.normalize_input.status, "done")
            test.eq(t.workflow_state.nodes.normalize_input.ended_at, 200)
        end)

        test.it("update_plan_section writes plan_json key without touching workflow_state", function()
            local ok = trip_repo.update_plan_section(state.trip_id, "attractions",
                { { name = "Senso-ji", description = "Old temple" } })
            test.is_true(ok)
            local t = trip_repo.get(TEST_USER, state.trip_id)
            test.eq(#t.plan_json.attractions, 1)
            test.eq(t.workflow_state.nodes.normalize_input.status, "done") -- unchanged
        end)

        test.it("append_warning appends to plan_json.warnings", function()
            trip_repo.append_warning(state.trip_id, "origin missing")
            local t = trip_repo.get(TEST_USER, state.trip_id)
            test.eq(t.plan_json.warnings[1], "origin missing")
        end)

        test.it("list filters by status", function()
            trip_repo.set_status(state.trip_id, "ready")
            local all, _ = trip_repo.list(TEST_USER, "all")
            local ready, _ = trip_repo.list(TEST_USER, "ready")
            test.ok(#all >= 1)
            test.ok(#ready >= 1)
        end)

        test.it("not_found for unknown id", function()
            local t, err = trip_repo.get(TEST_USER, "does_not_exist")
            test.is_nil(t); test.eq(err, "not_found")
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
local function run(options) return run_cases(options) end
return { run = run }
```

- [ ] **Step 4: Write `_index.yaml` (migrations + repo + common + tests)**

Create `src/app/trips/_index.yaml`:

```yaml
version: "1.0"
namespace: app.trips

entries:
  # --- Migrations ---
  - name: 01_init
    kind: function.lua
    meta:
      type: migration
      target_db: app:db
      description: Create trips table
      depends_on:
        - ns:wippy.migration
      timestamp: "2026-04-17T00:00:00Z"
    source: file://migrations/01_init.lua
    imports:
      migration: wippy.migration:migration
    method: migrate

  - name: 02_tasks_fields
    kind: function.lua
    meta:
      type: migration
      target_db: app:db
      description: Add trip_id and scheduled_at to tasks
      depends_on:
        - ns:wippy.migration
        - ns:app.tasks
      timestamp: "2026-04-17T00:00:01Z"
    source: file://migrations/02_tasks_fields.lua
    imports:
      migration: wippy.migration:migration
    method: migrate

  # --- Shared libs ---
  - name: trip_repo
    kind: library.lua
    source: file://trip_repo.lua
    modules:
      - sql
      - uuid
      - json

  - name: trips_common
    kind: library.lua
    source: file://trips_common.lua

  # --- Tests ---
  - name: trips_test
    kind: function.lua
    meta:
      type: test
      suite: trips
    source: file://trip_repo_test.lua
    method: run
    imports:
      test: wippy.test:test
      trip_repo: app.trips:trip_repo
```

- [ ] **Step 5: Run migrations and tests**

Run:
```bash
cd /Users/matwa/w/wippy/wippy-app-template && ./wippy run -c -- migrate
```
Expected: migrations from `app.trips` (01_init, 02_tasks_fields) execute successfully alongside existing ones.

Then:
```bash
./wippy run test trips
```
Expected: 7 PASS (all `trip_repo` tests).

If the migrate command shape differs, start the server once (`./wippy run -c`) and let auto-migrations run; watch logs for "migration applied" entries for both new migrations. Either approach is fine.

- [ ] **Step 6: Commit**

```bash
git add src/app/trips/
git commit -m "trips: migrations + repo with column-scoped JSON helpers"
```

---

## Task 4: HTTP endpoint — `GET /api/v1/trips`

**Files:**
- Create: `src/app/trips/api/list_trips.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the handler**

`src/app/trips/api/list_trips.lua`:

```lua
local http = require("http")
local security = require("security")
local trip_repo = require("trip_repo")

local function handler()
    local req = http.request()
    local res = http.response()
    res:set_content_type(http.CONTENT.JSON)

    local actor = security.actor()
    if not actor then
        res:set_status(http.STATUS.UNAUTHORIZED)
        res:write_json({ success = false, error = "unauthenticated" })
        return
    end

    local filter = req:query("filter") or "all"
    local trips, err = trip_repo.list(actor:id(), filter)
    if err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, trips = trips })
end

return { handler = handler }
```

- [ ] **Step 2: Register handler and endpoint in `_index.yaml`**

Append under the `entries:` list in `src/app/trips/_index.yaml`:

```yaml
  # --- HTTP handlers ---
  - name: list_trips
    kind: function.lua
    source: file://api/list_trips.lua
    modules:
      - http
      - security
    imports:
      trip_repo: app.trips:trip_repo
    method: handler
    pool:
      size: 2

  - name: list_trips.endpoint
    kind: http.endpoint
    meta:
      router: app:api
    method: GET
    func: list_trips
    path: /trips
```

- [ ] **Step 3: Smoke-test**

Start server in one terminal: `./wippy run -c`. In another:

```bash
TOKEN=$(curl -s -X POST http://localhost:8085/api/public/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@test.local","password":"admin"}' | jq -r .token)
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8085/api/v1/trips | jq
```
Expected: `{"success":true,"trips":[]}`. (Use any seeded user credentials in your `.env`.)

- [ ] **Step 4: Commit**

```bash
git add src/app/trips/api/list_trips.lua src/app/trips/_index.yaml
git commit -m "trips: GET /api/v1/trips"
```

---

## Task 5: HTTP endpoint — `POST /api/v1/trips` (row only, no workflow yet)

The workflow kickoff is added in Task 16; this step only lands the row.

**Files:**
- Create: `src/app/trips/api/create_trip.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the handler**

`src/app/trips/api/create_trip.lua`:

```lua
local http = require("http")
local json = require("json")
local security = require("security")
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local DATE_RE = "^%d%d%d%d%-%d%d%-%d%d$"

local function handler()
    local req = http.request()
    local res = http.response()
    res:set_content_type(http.CONTENT.JSON)

    local actor = security.actor()
    if not actor then
        res:set_status(http.STATUS.UNAUTHORIZED)
        res:write_json({ success = false, error = "unauthenticated" })
        return
    end

    local body = req:body()
    if not body or body == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "request body is required" })
        return
    end

    local data, err = json.decode(body)
    if err then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "invalid JSON: " .. err })
        return
    end

    if not data.destination or data.destination == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "destination is required" })
        return
    end
    if not data.start_date or not data.start_date:match(DATE_RE) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "start_date must be yyyy-mm-dd" })
        return
    end
    if not data.end_date or not data.end_date:match(DATE_RE) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "end_date must be yyyy-mm-dd" })
        return
    end
    if data.end_date < data.start_date then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "end_date must be >= start_date" })
        return
    end

    local trip, c_err = trip_repo.create(actor:id(), {
        destination = trips_common.canonicalize_destination(data.destination),
        origin      = data.origin and trips_common.canonicalize_destination(data.origin) or nil,
        start_date  = data.start_date,
        end_date    = data.end_date,
    })
    if c_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = c_err })
        return
    end

    res:set_status(http.STATUS.CREATED)
    res:write_json({ success = true, trip_id = trip.id, url = "/app/trips/" .. trip.id })
end

return { handler = handler }
```

- [ ] **Step 2: Register in `_index.yaml`**

Append to `entries:` in `src/app/trips/_index.yaml`:

```yaml
  - name: create_trip
    kind: function.lua
    source: file://api/create_trip.lua
    modules:
      - http
      - json
      - security
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
    method: handler
    pool:
      size: 2

  - name: create_trip.endpoint
    kind: http.endpoint
    meta:
      router: app:api
    method: POST
    func: create_trip
    path: /trips
```

- [ ] **Step 3: Smoke-test**

With `./wippy run -c` running and `$TOKEN` from Task 4:

```bash
curl -s -X POST http://localhost:8085/api/v1/trips \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"destination":"tokyo","origin":"berlin","start_date":"2026-05-01","end_date":"2026-05-07"}' | jq
```
Expected: `{"success":true,"trip_id":"...","url":"/app/trips/..."}`. Then `GET /api/v1/trips` returns that one row with `status:"planning"`.

- [ ] **Step 4: Commit**

```bash
git add src/app/trips/api/create_trip.lua src/app/trips/_index.yaml
git commit -m "trips: POST /api/v1/trips (row only, no workflow yet)"
```

---

## Task 6: HTTP endpoint — `GET /api/v1/trips/{id}`

**Files:**
- Create: `src/app/trips/api/get_trip.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the handler**

`src/app/trips/api/get_trip.lua`:

```lua
local http = require("http")
local security = require("security")
local sql = require("sql")
local trip_repo = require("trip_repo")

local function load_trip_tasks(user_id, trip_id)
    local db, err = sql.get("app:db")
    if err then return nil, err end
    local rows, q_err = db:query([[
        SELECT id, title, done, notes, due_date, scheduled_at, priority, created_at, updated_at
        FROM tasks WHERE user_id = ? AND trip_id = ?
        ORDER BY scheduled_at ASC, created_at ASC
    ]], { user_id, trip_id })
    db:release()
    if q_err then return nil, q_err end
    for _, r in ipairs(rows) do
        r.done = tonumber(r.done) == 1
        r.priority = tonumber(r.priority) or 2
        r.created_at = tonumber(r.created_at)
        r.updated_at = tonumber(r.updated_at)
    end
    return rows
end

local function handler()
    local req = http.request()
    local res = http.response()
    res:set_content_type(http.CONTENT.JSON)

    local actor = security.actor()
    if not actor then
        res:set_status(http.STATUS.UNAUTHORIZED)
        res:write_json({ success = false, error = "unauthenticated" })
        return
    end

    local id = req:param("id")
    if not id or id == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "trip id is required" })
        return
    end

    local trip, err = trip_repo.get(actor:id(), id)
    if err == "not_found" then
        res:set_status(http.STATUS.NOT_FOUND)
        res:write_json({ success = false, error = "trip not found" })
        return
    elseif err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = err })
        return
    end

    local tasks, t_err = load_trip_tasks(actor:id(), id)
    if t_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = t_err })
        return
    end
    trip.tasks = tasks

    res:set_status(http.STATUS.OK)
    res:write_json({ success = true, trip = trip })
end

return { handler = handler }
```

- [ ] **Step 2: Register in `_index.yaml`**

```yaml
  - name: get_trip
    kind: function.lua
    source: file://api/get_trip.lua
    modules:
      - http
      - security
      - sql
    imports:
      trip_repo: app.trips:trip_repo
    method: handler
    pool:
      size: 2

  - name: get_trip.endpoint
    kind: http.endpoint
    meta:
      router: app:api
    method: GET
    func: get_trip
    path: /trips/{id}
```

- [ ] **Step 3: Smoke-test**

```bash
TRIP_ID=$(curl -s -X POST http://localhost:8085/api/v1/trips \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"destination":"rome","start_date":"2026-06-01","end_date":"2026-06-05"}' | jq -r .trip_id)
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8085/api/v1/trips/$TRIP_ID | jq
```
Expected: `success:true, trip.workflow_state.nodes.normalize_input.status=="pending", trip.tasks==[]`.

- [ ] **Step 4: Commit**

```bash
git add src/app/trips/api/get_trip.lua src/app/trips/_index.yaml
git commit -m "trips: GET /api/v1/trips/{id} returning trip + tasks"
```

---

## Task 7: Func node — `normalize_input` (TDD)

**Files:**
- Create: `src/app/trips/flow/normalize_input.lua`
- Create: `src/app/trips/normalize_input_test.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the failing test**

`src/app/trips/normalize_input_test.lua`:

```lua
local test = require("test")
local normalize_input = require("normalize_input")

local function define_tests()
    test.describe("normalize_input", function()
        test.it("canonicalizes destination, computes duration_days + season", function()
            local out = normalize_input.handler({
                trip_id = "t1",
                destination = "  tOkYO  city ",
                origin = "berlin",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.eq(out.destination, "Tokyo City")
            test.eq(out.origin, "Berlin")
            test.eq(out.duration_days, 7)
            test.eq(out.season, "spring")
            test.eq(out.trip_id, "t1")
        end)

        test.it("origin defaults to nil and surfaces no value when missing", function()
            local out = normalize_input.handler({
                trip_id = "t2", destination = "Rome",
                start_date = "2026-12-20", end_date = "2026-12-26",
            })
            test.is_nil(out.origin)
            test.eq(out.season, "winter")
            test.eq(out.duration_days, 7)
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
```

- [ ] **Step 2: Register test in `_index.yaml`**

Replace the existing `trips_test` entry with one that also loads `normalize_input`:

```yaml
  - name: trips_test
    kind: function.lua
    meta:
      type: test
      suite: trips
    source: file://trip_repo_test.lua
    method: run
    imports:
      test: wippy.test:test
      trip_repo: app.trips:trip_repo

  - name: normalize_input_test
    kind: function.lua
    meta:
      type: test
      suite: trips
    source: file://normalize_input_test.lua
    method: run
    imports:
      test: wippy.test:test
      normalize_input: app.trips:normalize_input
```

The `normalize_input` import target is added below in Step 4.

- [ ] **Step 3: Run test, verify it fails**

```bash
./wippy run test trips
```
Expected: failure — `normalize_input` target not registered yet.

- [ ] **Step 4: Write `normalize_input.lua` and register it**

`src/app/trips/flow/normalize_input.lua`:

```lua
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local trip_id = input.trip_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "normalize_input",
            { status = "running", started_at = os.time() })
    end

    local out = {
        trip_id       = trip_id,
        destination   = trips_common.canonicalize_destination(input.destination),
        origin        = input.origin and trips_common.canonicalize_destination(input.origin) or nil,
        start_date    = input.start_date,
        end_date      = input.end_date,
        duration_days = trips_common.duration_days(input.start_date, input.end_date),
        season        = trips_common.season(input.start_date),
        user_id       = input.user_id,
    }

    if trip_id then
        trip_repo.update_node_state(trip_id, "normalize_input",
            { status = "done", ended_at = os.time() })
        trips_common.notify(input.user_id, trip_id)
    end

    return out
end

return { handler = handler }
```

Register in `src/app/trips/_index.yaml` under a new `# --- Flow func nodes ---` section:

```yaml
  # --- Flow func nodes ---
  - name: normalize_input
    kind: function.lua
    source: file://flow/normalize_input.lua
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
    method: handler
    pool:
      size: 2
```

- [ ] **Step 5: Run test, verify it passes**

```bash
./wippy run test trips
```
Expected: all `normalize_input` tests PASS alongside existing repo tests.

- [ ] **Step 6: Commit**

```bash
git add src/app/trips/flow/normalize_input.lua src/app/trips/normalize_input_test.lua src/app/trips/_index.yaml
git commit -m "trips: normalize_input func node"
```

---

## Task 8: Func node — `flights_linker` (TDD)

**Files:**
- Create: `src/app/trips/flow/flights_linker.lua`
- Create: `src/app/trips/flights_linker_test.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the failing test**

`src/app/trips/flights_linker_test.lua`:

```lua
local test = require("test")
local flights_linker = require("flights_linker")

local function define_tests()
    test.describe("flights_linker", function()
        test.it("builds both deep links when origin is present", function()
            local out = flights_linker.handler({
                destination = "Tokyo",
                origin = "Berlin",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.ok(out.google_flights_url:find("Berlin", 1, true))
            test.ok(out.google_flights_url:find("Tokyo", 1, true))
            test.ok(out.skyscanner_url:find("Berlin", 1, true))
            test.ok(out.skyscanner_url:find("Tokyo", 1, true))
            test.is_nil(out.warning)
        end)

        test.it("emits warning and links without origin", function()
            local out = flights_linker.handler({
                destination = "Tokyo",
                start_date = "2026-05-01",
                end_date = "2026-05-07",
            })
            test.not_nil(out.warning)
            test.ok(out.google_flights_url:find("Tokyo", 1, true))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
```

- [ ] **Step 2: Register in `_index.yaml`**

Append the matching test entry and a `flights_linker` node entry. Test entry:

```yaml
  - name: flights_linker_test
    kind: function.lua
    meta:
      type: test
      suite: trips
    source: file://flights_linker_test.lua
    method: run
    imports:
      test: wippy.test:test
      flights_linker: app.trips:flights_linker
```

Node entry (under `# --- Flow func nodes ---`):

```yaml
  - name: flights_linker
    kind: function.lua
    source: file://flow/flights_linker.lua
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
    method: handler
    pool:
      size: 2
```

- [ ] **Step 3: Run test, verify failure**

```bash
./wippy run test trips
```
Expected: `flights_linker` import missing — fail.

- [ ] **Step 4: Write `flights_linker.lua`**

`src/app/trips/flow/flights_linker.lua`:

```lua
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function url_encode(s)
    if not s then return "" end
    return (s:gsub("([^%w _-])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+"))
end

local function build_google(origin, destination, start_date, end_date)
    if origin and origin ~= "" then
        return string.format(
            "https://www.google.com/travel/flights?q=Flights%%20from%%20%s%%20to%%20%s%%20on%%20%s%%20returning%%20%s",
            url_encode(origin), url_encode(destination), start_date, end_date)
    end
    return string.format(
        "https://www.google.com/travel/flights?q=Flights%%20to%%20%s%%20on%%20%s%%20returning%%20%s",
        url_encode(destination), start_date, end_date)
end

local function build_sky(origin, destination, start_date, end_date)
    -- Skyscanner doesn't have a stable deep-link format for city search; use a plain query URL.
    if origin and origin ~= "" then
        return string.format("https://www.skyscanner.net/transport/flights/%s/%s/?outboundDate=%s&inboundDate=%s",
            url_encode(origin), url_encode(destination), start_date, end_date)
    end
    return string.format("https://www.skyscanner.net/transport/flights/to/%s/?outboundDate=%s&inboundDate=%s",
        url_encode(destination), start_date, end_date)
end

local function handler(input)
    local trip_id = input.trip_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "flights_linker",
            { status = "running", started_at = os.time() })
    end

    local out = {
        google_flights_url = build_google(input.origin, input.destination,
                                          input.start_date, input.end_date),
        skyscanner_url     = build_sky(input.origin, input.destination,
                                       input.start_date, input.end_date),
    }
    if not input.origin or input.origin == "" then
        out.warning = "Origin not provided — flight links do not include a departure city."
    end

    if trip_id then
        trip_repo.update_plan_section(trip_id, "flights", {
            google_flights_url = out.google_flights_url,
            skyscanner_url     = out.skyscanner_url,
        })
        if out.warning then
            trip_repo.append_warning(trip_id, out.warning)
        end
        trip_repo.update_node_state(trip_id, "flights_linker",
            { status = "done", ended_at = os.time() })
        trips_common.notify(input.user_id, trip_id)
    end

    return out
end

return { handler = handler }
```

- [ ] **Step 5: Run test, verify pass**

```bash
./wippy run test trips
```
Expected: all flights_linker tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/app/trips/flow/flights_linker.lua src/app/trips/flights_linker_test.lua src/app/trips/_index.yaml
git commit -m "trips: flights_linker func node"
```

---

## Task 9: Func node — `build_task_payloads` (TDD)

Pure plan→rows transformation. No DB, no hub. Unit-testable.

**Files:**
- Create: `src/app/trips/flow/build_task_payloads.lua`
- Create: `src/app/trips/build_task_payloads_test.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the failing test**

`src/app/trips/build_task_payloads_test.lua`:

```lua
local test = require("test")
local builder = require("build_task_payloads")

local FIXED_TODAY = "2026-04-17"

local function define_tests()
    test.describe("build_task_payloads", function()
        test.it("creates flights + packing + per-attraction tasks", function()
            local rows = builder.build({
                today          = FIXED_TODAY,
                trip_id        = "t1",
                destination    = "Tokyo",
                origin         = "Berlin",
                start_date     = "2026-05-01",
                end_date       = "2026-05-07",
                google_flights_url = "https://g", skyscanner_url = "https://s",
                packing = { { category = "Clothing", items = { "shirt", "pants" } } },
                itinerary = {
                    { date = "2026-05-02", attraction_name = "Senso-ji",
                      description = "Old temple", time_slot = "morning",
                      estimated_duration_hours = 2, constraints = { "closed Mondays" } },
                },
            })
            test.eq(#rows, 3)
            test.eq(rows[1].title, "Book flights — Berlin → Tokyo (2026-05-01 – 2026-05-07)")
            test.eq(rows[1].scheduled_at, FIXED_TODAY)
            test.eq(rows[1].priority, 3)
            test.eq(rows[2].title, "Pack for Tokyo trip")
            test.eq(rows[2].scheduled_at, "2026-04-30")
            test.eq(rows[2].priority, 2)
            test.eq(rows[3].title, "Visit Senso-ji")
            test.eq(rows[3].scheduled_at, "2026-05-02")
            test.eq(rows[3].priority, 1)
        end)

        test.it("omits packing task when packing is nil or empty", function()
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t2",
                destination = "Rome", origin = "Paris",
                start_date = "2026-06-01", end_date = "2026-06-05",
                google_flights_url = "", skyscanner_url = "",
                packing = nil,
                itinerary = {},
            })
            -- flights only (no packing, no attractions)
            test.eq(#rows, 1)
            test.eq(rows[1].title:sub(1, 5), "Book ")
        end)

        test.it("omits flights task when itinerary is empty (no itinerary → no tasks except flights?)", function()
            -- Per spec: flights task is always created when trip would be ready/partial.
            -- Spec also says: tasks are created only when synthesizer produced a valid itinerary.
            -- So if itinerary is empty, build() must return {} (no tasks).
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t3",
                destination = "Rome", origin = "Paris",
                start_date = "2026-06-01", end_date = "2026-06-05",
                google_flights_url = "a", skyscanner_url = "b",
                packing = { { category = "c", items = { "x" } } },
                itinerary = {},
            })
            test.eq(#rows, 0)
        end)

        test.it("clamps past scheduled_at to today", function()
            -- Packing would be scheduled start_date - 1 day; if that's before today, clamp.
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t4",
                destination = "Rome", origin = "Paris",
                start_date = "2026-04-17", end_date = "2026-04-20",
                google_flights_url = "a", skyscanner_url = "b",
                packing = { { category = "c", items = { "x" } } },
                itinerary = {
                    { date = "2026-04-17", attraction_name = "Colosseum",
                      description = "", time_slot = "morning",
                      estimated_duration_hours = 2, constraints = {} },
                },
            })
            -- flights (today), packing (clamped from 2026-04-16 → today), visit (already today)
            test.eq(rows[2].scheduled_at, FIXED_TODAY)
            test.eq(rows[3].scheduled_at, FIXED_TODAY)
        end)

        test.it("omits origin from flights title when missing", function()
            local rows = builder.build({
                today = FIXED_TODAY, trip_id = "t5",
                destination = "Rome", origin = nil,
                start_date = "2026-05-01", end_date = "2026-05-05",
                google_flights_url = "a", skyscanner_url = "b",
                packing = nil,
                itinerary = { { date = "2026-05-01", attraction_name = "Colosseum",
                                description = "", time_slot = "morning",
                                estimated_duration_hours = 1, constraints = {} } },
            })
            test.eq(rows[1].title, "Book flights — Rome (2026-05-01 – 2026-05-05)")
            test.ok(rows[1].notes:find("Origin not provided", 1, true))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
```

- [ ] **Step 2: Register test + node in `_index.yaml`**

```yaml
  - name: build_task_payloads_test
    kind: function.lua
    meta:
      type: test
      suite: trips
    source: file://build_task_payloads_test.lua
    method: run
    imports:
      test: wippy.test:test
      build_task_payloads: app.trips:build_task_payloads

  # under Flow func nodes:
  - name: build_task_payloads
    kind: function.lua
    source: file://flow/build_task_payloads.lua
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
    method: handler
    pool:
      size: 2
```

- [ ] **Step 3: Run test, verify failure**

```bash
./wippy run test trips
```
Expected: fail because `build_task_payloads` isn't registered / file missing.

- [ ] **Step 4: Write `build_task_payloads.lua`**

`src/app/trips/flow/build_task_payloads.lua`:

```lua
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

local function flights_notes(google_url, sky_url, origin_missing)
    local lines = {}
    if origin_missing then
        table.insert(lines, "_Origin not provided — flight searches are destination-only._")
        table.insert(lines, "")
    end
    table.insert(lines, string.format("[Search on Google Flights](%s)", google_url))
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
        notes        = flights_notes(ctx.google_flights_url, ctx.skyscanner_url,
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
    local trip_id = input.trip_id

    if trip_id then
        trip_repo.update_node_state(trip_id, "build_task_payloads",
            { status = "running", started_at = os.time() })
    end

    local rows = build({
        today              = input.today or today_iso(),
        trip_id            = trip_id,
        destination        = input.destination,
        origin             = input.origin,
        start_date         = input.start_date,
        end_date           = input.end_date,
        google_flights_url = input.google_flights_url,
        skyscanner_url     = input.skyscanner_url,
        packing            = input.packing,
        itinerary          = input.itinerary,
    })

    if trip_id then
        trip_repo.update_node_state(trip_id, "build_task_payloads",
            { status = "done", ended_at = os.time() })
        trips_common.notify(input.user_id, trip_id)
    end

    return { task_rows = rows, user_id = input.user_id, trip_id = trip_id }
end

return { build = build, handler = handler }
```

- [ ] **Step 5: Run test, verify pass**

```bash
./wippy run test trips
```
Expected: all build_task_payloads tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/app/trips/flow/build_task_payloads.lua src/app/trips/build_task_payloads_test.lua src/app/trips/_index.yaml
git commit -m "trips: build_task_payloads pure func + tests"
```

---

## Task 10: Func node — `validate_synthesizer_exit` (TDD)

Used as `arena.exit_func_id` on the itinerary synthesizer agent.

**Files:**
- Create: `src/app/trips/flow/validate_synthesizer_exit.lua`
- Create: `src/app/trips/validate_synthesizer_exit_test.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the failing test**

`src/app/trips/validate_synthesizer_exit_test.lua`:

```lua
local test = require("test")
local validator = require("validate_synthesizer_exit")

local function define_tests()
    test.describe("validate_synthesizer_exit", function()
        test.it("accepts a valid itinerary", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" }, { name = "B" }, { name = "C" } },
                start_date  = "2026-05-01",
                end_date    = "2026-05-03",
            }, {
                itinerary = {
                    { date = "2026-05-01", attraction_name = "A" },
                    { date = "2026-05-02", attraction_name = "B" },
                    { date = "2026-05-03", attraction_name = "C" },
                },
            })
            test.is_true(ok)
            test.is_nil(err)
        end)

        test.it("rejects hallucinated attraction", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" } },
                start_date  = "2026-05-01", end_date = "2026-05-02",
            }, {
                itinerary = {
                    { date = "2026-05-01", attraction_name = "NotInList" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("NotInList", 1, true))
        end)

        test.it("rejects date outside trip range", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" } },
                start_date  = "2026-05-01", end_date = "2026-05-02",
            }, {
                itinerary = {
                    { date = "2026-05-04", attraction_name = "A" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("2026-05-04", 1, true))
        end)

        test.it("rejects > 2 items on arrival date", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" }, { name = "B" }, { name = "C" } },
                start_date  = "2026-05-01", end_date = "2026-05-03",
            }, {
                itinerary = {
                    { date = "2026-05-01", attraction_name = "A" },
                    { date = "2026-05-01", attraction_name = "B" },
                    { date = "2026-05-01", attraction_name = "C" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("arrival", 1, true))
        end)

        test.it("rejects > 2 items on departure date", function()
            local ok, err = validator.validate({
                attractions = { { name = "A" }, { name = "B" }, { name = "C" } },
                start_date  = "2026-05-01", end_date = "2026-05-03",
            }, {
                itinerary = {
                    { date = "2026-05-03", attraction_name = "A" },
                    { date = "2026-05-03", attraction_name = "B" },
                    { date = "2026-05-03", attraction_name = "C" },
                },
            })
            test.is_false(ok)
            test.ok(err:find("departure", 1, true))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return { run = function(o) return run_cases(o) end }
```

- [ ] **Step 2: Register test and node**

```yaml
  - name: validate_synthesizer_exit_test
    kind: function.lua
    meta:
      type: test
      suite: trips
    source: file://validate_synthesizer_exit_test.lua
    method: run
    imports:
      test: wippy.test:test
      validate_synthesizer_exit: app.trips:validate_synthesizer_exit

  # under Flow func nodes:
  - name: validate_synthesizer_exit
    kind: function.lua
    source: file://flow/validate_synthesizer_exit.lua
    method: handler
    pool:
      size: 2
```

- [ ] **Step 3: Run test, verify failure**

```bash
./wippy run test trips
```
Expected: fail (target missing).

- [ ] **Step 4: Write the validator**

`src/app/trips/flow/validate_synthesizer_exit.lua`:

```lua
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
```

- [ ] **Step 5: Run test, verify pass**

```bash
./wippy run test trips
```
Expected: all validator tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/app/trips/flow/validate_synthesizer_exit.lua src/app/trips/validate_synthesizer_exit_test.lua src/app/trips/_index.yaml
git commit -m "trips: validate_synthesizer_exit (exit_func_id hook)"
```

---

## Task 11: Func nodes — `save_attractions` + `save_packing`

Each agent branch has a small persister func that writes the agent's structured output into `plan_json`. `save_attractions` is critical (failure = trip fails). `save_packing` is non-critical (failure → warning).

**Files:**
- Create: `src/app/trips/flow/save_attractions.lua`
- Create: `src/app/trips/flow/save_packing.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write `save_attractions.lua`**

```lua
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local trip_id = input.trip_id
    local attractions = input.attractions or {}

    if #attractions == 0 then
        trip_repo.update_node_state(trip_id, "attractions_research",
            { status = "failed", ended_at = os.time(),
              error = "no attractions returned" })
        trips_common.notify(input.user_id, trip_id)
        return nil, "no attractions returned"
    end

    trip_repo.update_plan_section(trip_id, "attractions", attractions)
    trip_repo.update_node_state(trip_id, "attractions_research",
        { status = "done", ended_at = os.time() })
    trips_common.notify(input.user_id, trip_id)

    return { attractions = attractions, trip_id = trip_id, user_id = input.user_id }
end

return { handler = handler }
```

- [ ] **Step 2: Write `save_packing.lua`**

```lua
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")

local function handler(input)
    local trip_id = input.trip_id
    local packing = input.packing or {}

    if #packing == 0 then
        trip_repo.append_warning(trip_id, "Packing list unavailable — continuing without it.")
        trip_repo.update_node_state(trip_id, "packing_research",
            { status = "failed", ended_at = os.time(),
              error = "empty packing list" })
        trips_common.notify(input.user_id, trip_id)
        return { packing = {}, trip_id = trip_id, user_id = input.user_id }
    end

    trip_repo.update_plan_section(trip_id, "packing", packing)
    trip_repo.update_node_state(trip_id, "packing_research",
        { status = "done", ended_at = os.time() })
    trips_common.notify(input.user_id, trip_id)

    return { packing = packing, trip_id = trip_id, user_id = input.user_id }
end

return { handler = handler }
```

- [ ] **Step 3: Register both in `_index.yaml`**

Under `# --- Flow func nodes ---`:

```yaml
  - name: save_attractions
    kind: function.lua
    source: file://flow/save_attractions.lua
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
    method: handler
    pool:
      size: 2

  - name: save_packing
    kind: function.lua
    source: file://flow/save_packing.lua
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
    method: handler
    pool:
      size: 2
```

- [ ] **Step 4: Commit**

```bash
git add src/app/trips/flow/save_attractions.lua src/app/trips/flow/save_packing.lua src/app/trips/_index.yaml
git commit -m "trips: save_attractions + save_packing persister funcs"
```

---

## Task 12: Func node — `persist_tasks`

Writes task rows through `task_repo`, sets `trip_id` and `scheduled_at`, fires both `trips:changed` and `tasks:changed`, then updates trip `status` and `workflow_state`.

**Files:**
- Create: `src/app/trips/flow/persist_tasks.lua`
- Modify: `src/app/trips/_index.yaml`
- Modify: `src/app/tasks/task_repo.lua` (add `create_with_trip`)

- [ ] **Step 1: Extend `task_repo.lua` with trip-aware insert**

Read `src/app/tasks/task_repo.lua` and add a function `create_with_trip(user_id, trip_id, title, opts)` before the `return { ... }` block. The function mirrors `create` but also sets `trip_id` and `scheduled_at`:

```lua
local function create_with_trip(user_id, trip_id, title, opts)
    if not title or title == "" then return nil, "title is required" end
    opts = opts or {}

    local db, err = get_db()
    if err then return nil, err end

    local id = uuid.v7()
    local ts = now()
    local priority = opts.priority or 2
    local _, e_err = db:execute([[
        INSERT INTO tasks (id, user_id, title, done, notes, due_date, scheduled_at,
                           priority, trip_id, created_at, updated_at)
        VALUES (?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?)
    ]], { id, user_id, title, opts.notes, opts.due_date, opts.scheduled_at,
          priority, trip_id, ts, ts })
    db:release()
    if e_err then return nil, e_err end

    return {
        id = id, title = title, done = false,
        notes = opts.notes, due_date = opts.due_date,
        scheduled_at = opts.scheduled_at, priority = priority,
        trip_id = trip_id, created_at = ts, updated_at = ts,
    }
end
```

Add `create_with_trip = create_with_trip,` to the returned table.

- [ ] **Step 2: Write `persist_tasks.lua`**

`src/app/trips/flow/persist_tasks.lua`:

```lua
local trip_repo = require("trip_repo")
local trips_common = require("trips_common")
local task_repo = require("task_repo")
local tasks_common = require("tasks_common")

local function handler(input)
    local trip_id = input.trip_id
    local user_id = input.user_id
    local rows = input.task_rows or {}

    trip_repo.update_node_state(trip_id, "persist_tasks",
        { status = "running", started_at = os.time() })

    for _, r in ipairs(rows) do
        local _, c_err = task_repo.create_with_trip(user_id, trip_id, r.title, {
            notes = r.notes,
            scheduled_at = r.scheduled_at,
            priority = r.priority,
        })
        if c_err then
            trip_repo.update_node_state(trip_id, "persist_tasks",
                { status = "failed", ended_at = os.time(), error = c_err })
            trip_repo.set_status(trip_id, "failed")
            trips_common.notify(user_id, trip_id)
            return nil, c_err
        end
    end

    trip_repo.update_node_state(trip_id, "persist_tasks",
        { status = "done", ended_at = os.time() })

    -- Determine final status: ready or partial (partial = any non-critical branch failed).
    local trip = trip_repo.get(user_id, trip_id)
    local ws = trip and trip.workflow_state or {}
    local packing_failed = (ws.nodes and ws.nodes.packing_research
                            and ws.nodes.packing_research.status == "failed") or false
    trip_repo.set_status(trip_id, packing_failed and "partial" or "ready")

    trips_common.notify(user_id, trip_id)
    tasks_common.notify(user_id)

    return { trip_id = trip_id, task_count = #rows }
end

return { handler = handler }
```

- [ ] **Step 3: Register in `_index.yaml`**

```yaml
  - name: persist_tasks
    kind: function.lua
    source: file://flow/persist_tasks.lua
    imports:
      trip_repo: app.trips:trip_repo
      trips_common: app.trips:trips_common
      task_repo: app.tasks:task_repo
      tasks_common: app.tasks:tools_common
    method: handler
    pool:
      size: 2
```

- [ ] **Step 4: Commit**

```bash
git add src/app/trips/flow/persist_tasks.lua src/app/trips/_index.yaml src/app/tasks/task_repo.lua
git commit -m "trips: persist_tasks func; task_repo.create_with_trip"
```

---

## Task 13: Workflow agents — 4 trip agents

Register four agents in `src/app/agents/_index.yaml`. Each uses `arena.exit_schema`; the synthesizer adds `arena.exit_func_id`.

**Files:**
- Modify: `src/app/agents/_index.yaml`

- [ ] **Step 1: Read `src/app/agents/_index.yaml`** so you know where to append.

- [ ] **Step 2: Append four new agent entries at the bottom of the `entries:` list**

```yaml
  - name: trip_attractions_researcher
    kind: registry.entry
    meta:
      type: agent.gen1
      title: Trip Attractions Researcher
      comment: Returns up to 12 candidate attractions for a destination
    prompt: |
      You are a travel research agent. Given a destination and trip dates, return up to 12
      notable attractions as stable facts about that place. Do NOT schedule them — another
      agent handles planning. Prefer well-known sights; include a short description, a typical
      visit duration in hours, and any constraints that would affect scheduling (e.g. closed
      on certain days, best at sunset). Your reply MUST match the exit_schema.
    model: claude-4-5-sonnet
    temperature: 0.3
    max_tokens: 4000
    arena:
      max_iterations: 3
      exit_schema:
        type: object
        required: [attractions]
        additionalProperties: false
        properties:
          attractions:
            type: array
            maxItems: 12
            items:
              type: object
              required: [name, description, typical_duration_hours, constraints]
              additionalProperties: false
              properties:
                name: { type: string }
                description: { type: string }
                typical_duration_hours: { type: number }
                constraints:
                  type: array
                  items: { type: string }

  - name: trip_packing_researcher
    kind: registry.entry
    meta:
      type: agent.gen1
      title: Trip Packing Researcher
      comment: Climate/season-aware packing list
    prompt: |
      You are a travel packing advisor. Given a destination, dates, and inferred season,
      produce a concise, practical packing list grouped by category. Focus on what the climate
      and likely activities require. Your reply MUST match the exit_schema.
    model: claude-4-5-haiku
    temperature: 0.3
    max_tokens: 2000
    arena:
      max_iterations: 3
      exit_schema:
        type: object
        required: [packing]
        additionalProperties: false
        properties:
          packing:
            type: array
            items:
              type: object
              required: [category, items]
              additionalProperties: false
              properties:
                category: { type: string }
                items:
                  type: array
                  items: { type: string }

  - name: trip_itinerary_synthesizer
    kind: registry.entry
    meta:
      type: agent.gen1
      title: Trip Itinerary Synthesizer
      comment: Assigns attractions to days and time slots
    prompt: |
      You plan daily itineraries. Select from the provided attractions list only (do NOT invent
      new ones) and schedule each selection on a specific date within the trip range. The first
      date is arrival day (<= 2 items) and the last date is departure day (<= 2 items). Prefer
      morning/afternoon/evening slots. When a critic_feedback is present in your input, address
      each issue in your next output. Your reply MUST match the exit_schema.
    model: claude-4-5-sonnet
    temperature: 0.4
    max_tokens: 4000
    arena:
      max_iterations: 4
      exit_func_id: app.trips:validate_synthesizer_exit
      exit_schema:
        type: object
        required: [itinerary]
        additionalProperties: false
        properties:
          itinerary:
            type: array
            items:
              type: object
              required: [date, attraction_name, time_slot, estimated_duration_hours, description, constraints]
              additionalProperties: false
              properties:
                date: { type: string }
                attraction_name: { type: string }
                time_slot: { type: string, enum: [morning, afternoon, evening] }
                estimated_duration_hours: { type: number }
                description: { type: string }
                constraints:
                  type: array
                  items: { type: string }

  - name: trip_itinerary_critic
    kind: registry.entry
    meta:
      type: agent.gen1
      title: Trip Itinerary Critic
      comment: Reviews itineraries and reports issues
    prompt: |
      You are an experienced travel planner reviewing the itinerary produced by the synthesizer.
      Check for: arrival/departure over-scheduling, pacing (too many long visits in one day),
      geographic thrash (consecutive items on opposite sides of the city), ignored constraints
      (e.g. "closed Mondays"). Emit status="ok" only if the plan is acceptable. Otherwise return
      concrete issues the synthesizer can fix. Your reply MUST match the exit_schema.
    model: claude-4-5-haiku
    temperature: 0.3
    max_tokens: 2000
    arena:
      max_iterations: 3
      exit_schema:
        type: object
        required: [status, issues]
        additionalProperties: false
        properties:
          status: { type: string, enum: [ok, revise] }
          issues:
            type: array
            items: { type: string }
```

- [ ] **Step 3: Verify registration**

```bash
./wippy run -c &
SERVER_PID=$!
sleep 3
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8085/api/v1/agents/list | jq '.agents[].name' | grep trip_
kill $SERVER_PID
```
Expected: four `trip_*` agent names printed.

- [ ] **Step 4: Commit**

```bash
git add src/app/agents/_index.yaml
git commit -m "trips: register 4 workflow agents with exit_schema/exit_func_id"
```

---

## Task 14: Flow — `trip_flow.lua`

Builds the DAG and kicks it off asynchronously. Returns `dataflow_id`.

**Files:**
- Create: `src/app/trips/flow/trip_flow.lua`
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write `trip_flow.lua`**

`src/app/trips/flow/trip_flow.lua`:

```lua
local flow = require("flow")

local function build_and_start(input)
    -- input: { trip_id, user_id, destination, origin, start_date, end_date }
    --
    -- Cycle template: synthesizer → critic, running sequentially per iteration.
    -- The cycle exits when the critic returns status="ok" or max_iterations is reached.
    local critic_cycle_template = flow.template()
        :agent("app.agents:trip_itinerary_synthesizer", {
            arena = { prompt = "Plan the itinerary using the provided attractions." },
        }):as("itinerary_synthesize")
        :agent("app.agents:trip_itinerary_critic", {
            arena = { prompt = "Review the itinerary and return status+issues." },
        }):as("itinerary_critic")

    return flow.create()
        :with_title("Trip plan: " .. input.destination)
        :with_metadata({ trip_id = input.trip_id, user_id = input.user_id })
        :with_input(input)

        :func("app.trips:normalize_input"):as("normalize_input")

        -- Three concurrent siblings off normalize_input.
        :agent("app.agents:trip_attractions_researcher", {
            arena = { prompt = "Research attractions for the destination." },
        }):as("attractions_research")
        :to("save_attractions")
        :func("app.trips:save_attractions"):as("save_attractions")
        :to("join", "attractions")

        :agent("app.agents:trip_packing_researcher", {
            arena = { prompt = "Produce a season-aware packing list." },
        }):as("packing_research")
        :to("save_packing")
        :func("app.trips:save_packing"):as("save_packing")
        :to("join", "packing")

        :func("app.trips:flights_linker"):as("flights_linker")
        :to("join", "flights")

        :join({
            inputs = { required = { "attractions", "packing", "flights" } },
            output_mode = "object",
        }):as("join")

        :cycle({
            template = critic_cycle_template,
            max_iterations = 2,
            continue_condition = "output.status ~= 'ok'",
        }):as("critic_cycle")

        :func("app.trips:build_task_payloads"):as("build_task_payloads")
        :func("app.trips:persist_tasks"):as("persist_tasks")
        :to("@success")

        :error_to("@fail")
        :start()
end

return { build_and_start = build_and_start }
```

**Note on edges:** the default flow builder chains operations sequentially when no `:to(...)` is given. Explicit `:to("save_attractions")` after each agent node breaks that default chain so we get three independent branches that all converge on `join`. If this pattern doesn't match how your build compiles (test in Task 16), refactor to use `:use(flow.template()...)` per branch — the compiler rules in `.wippy/vendor/wippy/dataflow/flow/compiler.lua` are the source of truth.

- [ ] **Step 2: Register `trip_flow` as a library**

In `src/app/trips/_index.yaml` under shared libs:

```yaml
  - name: trip_flow
    kind: library.lua
    source: file://flow/trip_flow.lua
    imports:
      flow: userspace.dataflow.flow:flow
```

- [ ] **Step 3: Commit**

```bash
git add src/app/trips/flow/trip_flow.lua src/app/trips/_index.yaml
git commit -m "trips: trip_flow DAG with siblings + critic cycle"
```

---

## Task 15: Service — `trip_service.create_trip` + wire to HTTP `POST /trips`

**Files:**
- Create: `src/app/trips/trip_service.lua`
- Modify: `src/app/trips/api/create_trip.lua` (call service)
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write `trip_service.lua`**

```lua
local trip_repo = require("trip_repo")
local trip_flow = require("trip_flow")
local trips_common = require("trips_common")

--- Create a trip row and start its workflow. Returns {trip_id, url}.
local function create_trip(user_id, input)
    local trip, err = trip_repo.create(user_id, {
        destination = trips_common.canonicalize_destination(input.destination),
        origin      = input.origin and trips_common.canonicalize_destination(input.origin) or nil,
        start_date  = input.start_date,
        end_date    = input.end_date,
    })
    if err then return nil, err end

    local workflow_id, f_err = trip_flow.build_and_start({
        trip_id     = trip.id,
        user_id     = user_id,
        destination = trip.destination or input.destination,
        origin      = input.origin,
        start_date  = input.start_date,
        end_date    = input.end_date,
    })
    if f_err then
        trip_repo.set_status(trip.id, "failed")
        return nil, "failed to start workflow: " .. f_err
    end

    trip_repo.set_workflow_id(trip.id, workflow_id)
    trips_common.notify(user_id, trip.id)

    return { trip_id = trip.id, url = "/app/trips/" .. trip.id }
end

return { create_trip = create_trip }
```

- [ ] **Step 2: Register `trip_service` in `_index.yaml`**

```yaml
  - name: trip_service
    kind: library.lua
    source: file://trip_service.lua
    imports:
      trip_repo: app.trips:trip_repo
      trip_flow: app.trips:trip_flow
      trips_common: app.trips:trips_common
```

- [ ] **Step 3: Modify `create_trip.lua` to delegate to the service**

Replace the `trip_repo.create` block in `src/app/trips/api/create_trip.lua` with a call to `trip_service.create_trip`. The validation stays. Full replacement:

```lua
local http = require("http")
local json = require("json")
local security = require("security")
local trip_service = require("trip_service")

local DATE_RE = "^%d%d%d%d%-%d%d%-%d%d$"

local function handler()
    local req = http.request()
    local res = http.response()
    res:set_content_type(http.CONTENT.JSON)

    local actor = security.actor()
    if not actor then
        res:set_status(http.STATUS.UNAUTHORIZED)
        res:write_json({ success = false, error = "unauthenticated" })
        return
    end

    local body = req:body()
    if not body or body == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "request body is required" })
        return
    end

    local data, err = json.decode(body)
    if err then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "invalid JSON: " .. err })
        return
    end

    if not data.destination or data.destination == "" then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "destination is required" })
        return
    end
    if not data.start_date or not data.start_date:match(DATE_RE) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "start_date must be yyyy-mm-dd" })
        return
    end
    if not data.end_date or not data.end_date:match(DATE_RE) then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "end_date must be yyyy-mm-dd" })
        return
    end
    if data.end_date < data.start_date then
        res:set_status(http.STATUS.BAD_REQUEST)
        res:write_json({ success = false, error = "end_date must be >= start_date" })
        return
    end

    local result, s_err = trip_service.create_trip(actor:id(), data)
    if s_err then
        res:set_status(http.STATUS.INTERNAL_ERROR)
        res:write_json({ success = false, error = s_err })
        return
    end

    res:set_status(http.STATUS.CREATED)
    res:write_json({ success = true, trip_id = result.trip_id, url = result.url })
end

return { handler = handler }
```

Update the `create_trip` registration in `_index.yaml` — replace `trip_repo` and `trips_common` imports with:

```yaml
    imports:
      trip_service: app.trips:trip_service
```

- [ ] **Step 4: First end-to-end smoke test**

```bash
./wippy run -c &
sleep 3
TRIP_ID=$(curl -s -X POST http://localhost:8085/api/v1/trips \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"destination":"lisbon","origin":"london","start_date":"2026-06-10","end_date":"2026-06-14"}' | jq -r .trip_id)
echo "trip_id=$TRIP_ID"
sleep 30
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8085/api/v1/trips/$TRIP_ID | jq '.trip.status, .trip.workflow_state.nodes'
```
Expected: after ~30s, `status` is `"ready"` (or `"partial"`), `workflow_state.nodes.persist_tasks.status == "done"`, `plan_json.attractions[]` and `plan_json.itinerary[]` populated, `tasks` array non-empty. Kill the server when done. If something errors, inspect server logs for the failing node; the per-node `error` field in `workflow_state.nodes` is the other place to look.

- [ ] **Step 5: Commit**

```bash
git add src/app/trips/trip_service.lua src/app/trips/api/create_trip.lua src/app/trips/_index.yaml
git commit -m "trips: trip_service kicks off workflow on create"
```

---

## Task 16: Chat tool — `plan_trip` + `trips_trait`

**Files:**
- Create: `src/app/trips/tools/plan_trip.lua`
- Modify: `src/app/agents/_index.yaml` (add tool + trait + attach to Wippy)
- Modify: `src/app/trips/_index.yaml`

- [ ] **Step 1: Write the tool handler**

`src/app/trips/tools/plan_trip.lua`:

```lua
local ctx = require("ctx")
local trip_service = require("trip_service")

local DATE_RE = "^%d%d%d%d%-%d%d%-%d%d$"

local function handler(params)
    local user_id = ctx.get("user_id")
    if not user_id then
        return { success = false, error = "user context not available" }
    end

    if not params or not params.destination or params.destination == "" then
        return { success = false, error = "destination is required" }
    end
    if not params.start_date or not params.start_date:match(DATE_RE) then
        return { success = false, error = "start_date must be yyyy-mm-dd" }
    end
    if not params.end_date or not params.end_date:match(DATE_RE) then
        return { success = false, error = "end_date must be yyyy-mm-dd" }
    end
    if params.end_date < params.start_date then
        return { success = false, error = "end_date must be >= start_date" }
    end

    local result, err = trip_service.create_trip(user_id, {
        destination = params.destination,
        origin      = params.origin,
        start_date  = params.start_date,
        end_date    = params.end_date,
    })
    if err then return { success = false, error = err } end

    return {
        success = true,
        message = "Started planning trip to " .. params.destination,
        trip_id = result.trip_id,
        url     = result.url,
    }
end

return { handler = handler }
```

- [ ] **Step 2: Register the tool in `src/app/trips/_index.yaml`**

Under a new `# --- Agent tools ---` section:

```yaml
  - name: plan_trip
    kind: function.lua
    meta:
      type: tool
      title: Plan Trip
      input_schema: |
        {
          "type": "object",
          "properties": {
            "destination": { "type": "string", "description": "City/region name" },
            "origin":      { "type": "string", "description": "Departure city (optional)" },
            "start_date":  { "type": "string", "description": "yyyy-mm-dd" },
            "end_date":    { "type": "string", "description": "yyyy-mm-dd" }
          },
          "required": ["destination", "start_date", "end_date"],
          "additionalProperties": false
        }
      llm_alias: PlanTrip
      llm_description: |
        Kick off a trip-planning workflow. Creates a trip row, starts the research/itinerary
        workflow, and returns {trip_id, url}. Require destination, start_date, end_date. Ask the
        user for any missing field before calling — never guess dates.
    source: file://tools/plan_trip.lua
    modules:
      - ctx
    imports:
      trip_service: app.trips:trip_service
    method: handler
    pool:
      size: 2
```

- [ ] **Step 3: Add the `trips_trait` and attach it to the Wippy agent**

In `src/app/agents/_index.yaml`, append a new trait entry after the existing traits:

```yaml
  - name: trips_trait
    kind: registry.entry
    meta:
      type: agent.trait
      title: Trip Planning
      tags:
        - trips
    prompt: |
      You can plan trips for the user.
      - PlanTrip(destination, start_date, end_date, origin?) — start a trip planning workflow.
      If any required field is missing, ask the user conversationally before calling. Dates must
      be full ISO dates with year (yyyy-mm-dd). When the user mentions a date without a year,
      use the current year — never guess a past year.
      After calling PlanTrip successfully, reply with a short confirmation that includes the
      returned url so the user can click through to the live trip page.
    tools:
      - app.trips:plan_trip
```

Attach the trait to the Wippy agent by adding `- id: app.trips:trips_trait` to the `wippy` agent's `traits:` list.

- [ ] **Step 4: Smoke-test via chat UI** (manual)

Start the server, open the chat, type *"plan me a 4-day trip to Kyoto starting May 3"*. Agent should ask for the year / clarify, then call `PlanTrip`, then return a `/app/trips/<id>` link. Open that URL in a new tab to verify the workflow runs.

- [ ] **Step 5: Commit**

```bash
git add src/app/trips/tools/plan_trip.lua src/app/trips/_index.yaml src/app/agents/_index.yaml
git commit -m "trips: plan_trip tool + trips_trait on Wippy agent"
```

---

## Task 17: Wire `/trips` into `NavigateTo`

**Files:**
- Modify: `src/app/agents/navigate_to.lua`

- [ ] **Step 1: Add `trips = "/trips"` to the `PAGES` map**

Also update the enum in `src/app/agents/_index.yaml` for the `navigate_to` tool — add `"trips"` to the `input_schema.properties.page.enum`.

And update the Wippy agent's system prompt to list `trips` alongside the other pages.

- [ ] **Step 2: Commit**

```bash
git add src/app/agents/navigate_to.lua src/app/agents/_index.yaml
git commit -m "trips: NavigateTo supports /trips"
```

---

## Task 18: Frontend — Pinia store + types

**Files:**
- Create: `frontend/applications/main/src/stores/trips.ts`

- [ ] **Step 1: Write the store and types**

```ts
import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface TripSummary {
  id: string
  title: string
  destination: string
  start_date: string
  end_date: string
  status: 'planning' | 'ready' | 'partial' | 'failed'
  updated_at: number
}

export interface NodeState {
  status: 'pending' | 'running' | 'done' | 'failed'
  started_at?: number
  ended_at?: number
  iterations?: number
  error?: string
}

export interface WorkflowState {
  nodes: Record<string, NodeState>
}

export interface PlanJson {
  attractions?: Array<{
    name: string
    description: string
    typical_duration_hours: number
    constraints: string[]
  }>
  packing?: Array<{ category: string, items: string[] }>
  flights?: { google_flights_url: string, skyscanner_url: string }
  itinerary?: Array<{
    date: string
    attraction_name: string
    time_slot: string
    estimated_duration_hours: number
    description: string
    constraints: string[]
  }>
  warnings?: string[]
}

export interface TripDetail extends TripSummary {
  origin: string | null
  workflow_id: string | null
  workflow_state: WorkflowState | null
  plan_json: PlanJson | null
  tasks: Array<{
    id: string
    title: string
    done: boolean
    scheduled_at: string | null
    priority: number
  }>
}

export const useTripsStore = defineStore('trips', () => {
  const list = ref<TripSummary[]>([])
  return { list }
}, {
  wippyPersist: {
    pick: ['list'],
  },
})
```

- [ ] **Step 2: Commit**

```bash
git add frontend/applications/main/src/stores/trips.ts
git commit -m "trips: frontend Pinia store + TS types"
```

---

## Task 19: Frontend — `/trips` list page

**Files:**
- Create: `frontend/applications/main/src/pages/trips-list.vue`

- [ ] **Step 1: Write the list page**

```vue
<script setup lang="ts">
import { ref, computed, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon } from '@iconify/vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Button from 'primevue/button'
import SelectButton from 'primevue/selectbutton'
import { useApi, useWippy } from '../composables/useWippy'
import { useTripsStore, type TripSummary } from '../stores/trips'

const api = useApi()
const wippy = useWippy()
const router = useRouter()
const queryClient = useQueryClient()
const tripsStore = useTripsStore()

const TRIPS_KEY = ['trips'] as const

const filter = ref<'all' | 'planning' | 'ready' | 'partial' | 'failed'>('all')
const FILTER_OPTIONS = [
  { label: 'All', value: 'all' },
  { label: 'Planning', value: 'planning' },
  { label: 'Ready', value: 'ready' },
  { label: 'Partial', value: 'partial' },
  { label: 'Failed', value: 'failed' },
]

const { data: trips, isPending } = useQuery({
  queryKey: TRIPS_KEY,
  queryFn: async () => {
    const { data } = await api.get('/api/v1/trips')
    return data.success ? (data.trips || []) as TripSummary[] : []
  },
  placeholderData: () => (tripsStore.list.length > 0 ? tripsStore.list : undefined),
})

const visible = computed(() => {
  const all = trips.value ?? []
  if (filter.value === 'all') return all
  return all.filter(t => t.status === filter.value)
})

const unbind = wippy.on('trips:changed', () => {
  queryClient.invalidateQueries({ queryKey: TRIPS_KEY })
})
onUnmounted(() => unbind?.())

function statusClass(s: string) {
  return s === 'ready'
    ? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300'
    : s === 'failed'
      ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
      : s === 'partial'
        ? 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300'
        : 'bg-surface-100 text-surface-600 dark:bg-surface-700 dark:text-surface-300'
}
</script>

<template>
  <div class="h-full flex flex-col">
    <div class="px-5 py-4 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-primary">
          <Icon icon="tabler:plane" class="w-5 h-5 text-primary-contrast" aria-hidden="true" />
        </div>
        <div>
          <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0">Trips</h1>
          <p class="text-[11px] text-surface-400">{{ (trips ?? []).length }} total</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <SelectButton v-model="filter" :options="FILTER_OPTIONS" option-label="label" option-value="value" size="small" :allow-empty="false" />
        <Button label="New Trip" size="small" @click="router.push('/trips/create')">
          <template #icon><Icon icon="tabler:plus" class="w-4 h-4" /></template>
        </Button>
      </div>
    </div>
    <div class="flex-1 overflow-y-auto">
      <ul v-if="visible.length > 0" class="divide-y divide-surface-200 dark:divide-surface-700">
        <li v-for="t in visible" :key="t.id" class="px-5 py-3 hover:bg-surface-50 dark:hover:bg-surface-900/50 cursor-pointer" @click="router.push('/trips/' + t.id)">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <div class="text-sm font-medium text-surface-900 dark:text-surface-0 truncate">{{ t.title }}</div>
              <div class="text-[11px] text-surface-400">{{ t.start_date }} – {{ t.end_date }}</div>
            </div>
            <span class="text-[10px] font-medium px-1.5 py-0.5 rounded shrink-0" :class="statusClass(t.status)">{{ t.status }}</span>
          </div>
        </li>
      </ul>
      <div v-else-if="!isPending" class="h-full flex items-center justify-center">
        <div class="text-center">
          <Icon icon="tabler:plane" class="w-10 h-10 text-surface-300 dark:text-surface-600 mx-auto mb-2" aria-hidden="true" />
          <p class="text-sm text-surface-400">No trips yet — create one or ask the assistant.</p>
        </div>
      </div>
    </div>
  </div>
</template>
```

- [ ] **Step 2: Commit**

```bash
git add frontend/applications/main/src/pages/trips-list.vue
git commit -m "trips: frontend list page"
```

---

## Task 20: Frontend — `/trips/create` page

**Files:**
- Create: `frontend/applications/main/src/pages/trips-create.vue`

- [ ] **Step 1: Write the create page**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Icon } from '@iconify/vue'
import { useMutation } from '@tanstack/vue-query'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import DatePicker from 'primevue/datepicker'
import { useApi, useHost } from '../composables/useWippy'

const api = useApi()
const host = useHost()
const router = useRouter()

const destination = ref('')
const origin = ref('')
const startDate = ref<Date | null>(null)
const endDate = ref<Date | null>(null)

function format(d: Date | null): string | undefined {
  if (!d) return undefined
  const y = d.getFullYear(), m = String(d.getMonth() + 1).padStart(2, '0'), day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const mutation = useMutation({
  mutationFn: async () => {
    const body: Record<string, unknown> = {
      destination: destination.value.trim(),
      start_date: format(startDate.value),
      end_date: format(endDate.value),
    }
    const o = origin.value.trim()
    if (o) body.origin = o
    const { data } = await api.post('/api/v1/trips', body)
    if (!data.success) throw new Error(data.error || 'failed to create trip')
    return data as { trip_id: string, url: string }
  },
  onSuccess: (res) => router.push('/trips/' + res.trip_id),
  onError: (e: Error) => host.toast({ severity: 'error', summary: e.message }),
})

function submit() {
  if (!destination.value.trim() || !startDate.value || !endDate.value) return
  mutation.mutate()
}
</script>

<template>
  <div class="h-full flex flex-col">
    <div class="px-5 py-4 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0 flex items-center gap-3">
      <Button text rounded size="small" @click="router.push('/trips')" aria-label="Back">
        <template #icon><Icon icon="tabler:arrow-left" class="w-4 h-4" /></template>
      </Button>
      <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0">New Trip</h1>
    </div>
    <form class="px-5 py-5 grid grid-cols-2 gap-4 max-w-lg" @submit.prevent="submit">
      <div class="col-span-2">
        <label class="block mb-1 text-xs font-medium text-muted-color">Destination</label>
        <InputText v-model="destination" fluid placeholder="Tokyo" :disabled="mutation.isPending.value" />
      </div>
      <div class="col-span-2">
        <label class="block mb-1 text-xs font-medium text-muted-color">Origin (optional)</label>
        <InputText v-model="origin" fluid placeholder="Berlin" :disabled="mutation.isPending.value" />
      </div>
      <div>
        <label class="block mb-1 text-xs font-medium text-muted-color">Start date</label>
        <DatePicker v-model="startDate" date-format="yy-mm-dd" :min-date="new Date()" fluid show-icon />
      </div>
      <div>
        <label class="block mb-1 text-xs font-medium text-muted-color">End date</label>
        <DatePicker v-model="endDate" date-format="yy-mm-dd" :min-date="startDate ?? new Date()" fluid show-icon />
      </div>
      <div class="col-span-2 flex justify-end">
        <Button type="submit" label="Plan Trip" :disabled="!destination.trim() || !startDate || !endDate || mutation.isPending.value" :loading="mutation.isPending.value" />
      </div>
    </form>
  </div>
</template>
```

- [ ] **Step 2: Commit**

```bash
git add frontend/applications/main/src/pages/trips-create.vue
git commit -m "trips: frontend create page"
```

---

## Task 21: Frontend — `/trips/:id` detail page

**Files:**
- Create: `frontend/applications/main/src/pages/trip-detail.vue`

- [ ] **Step 1: Write the detail page**

```vue
<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon } from '@iconify/vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import Button from 'primevue/button'
import { useApi, useWippy } from '../composables/useWippy'
import type { TripDetail, NodeState } from '../stores/trips'

const api = useApi()
const wippy = useWippy()
const route = useRoute()
const router = useRouter()
const queryClient = useQueryClient()

const tripId = computed(() => route.params.id as string)
const TRIP_KEY = computed(() => ['trip', tripId.value])

const { data: trip, isPending } = useQuery({
  queryKey: TRIP_KEY,
  queryFn: async () => {
    const { data } = await api.get('/api/v1/trips/' + tripId.value)
    if (!data.success) throw new Error(data.error || 'not found')
    return data.trip as TripDetail
  },
  refetchInterval: (q) => {
    const s = (q.state.data as TripDetail | undefined)?.status
    return s === 'planning' ? 2000 : false
  },
})

const unbind = wippy.on('trips:changed', (ev: any) => {
  if (ev?.data?.trip_id === tripId.value) {
    queryClient.invalidateQueries({ queryKey: TRIP_KEY.value })
  }
})
onUnmounted(() => unbind?.())

const NODE_ORDER: Array<{ key: string, label: string }> = [
  { key: 'normalize_input',      label: 'Normalize input' },
  { key: 'attractions_research', label: 'Attractions research' },
  { key: 'packing_research',     label: 'Packing research' },
  { key: 'flights_linker',       label: 'Flights' },
  { key: 'itinerary_synthesize', label: 'Itinerary synthesize' },
  { key: 'itinerary_critic',     label: 'Itinerary critic' },
  { key: 'build_task_payloads',  label: 'Build task payloads' },
  { key: 'persist_tasks',        label: 'Persist tasks' },
]

function nodeIcon(s: NodeState | undefined) {
  if (!s) return 'tabler:circle'
  if (s.status === 'done') return 'tabler:check'
  if (s.status === 'failed') return 'tabler:x'
  if (s.status === 'running') return 'tabler:loader-2'
  return 'tabler:circle'
}
function nodeIconClass(s: NodeState | undefined) {
  if (!s) return 'text-surface-400'
  if (s.status === 'done') return 'text-green-500'
  if (s.status === 'failed') return 'text-red-500'
  if (s.status === 'running') return 'text-primary animate-spin'
  return 'text-surface-400'
}

const panelOpen = ref(true)
</script>

<template>
  <div v-if="trip" class="h-full flex flex-col">
    <div class="px-5 py-4 border-b border-surface-200 dark:border-surface-700 bg-surface-card shrink-0 flex items-center gap-3">
      <Button text rounded size="small" @click="router.push('/trips')" aria-label="Back">
        <template #icon><Icon icon="tabler:arrow-left" class="w-4 h-4" /></template>
      </Button>
      <div class="min-w-0 flex-1">
        <h1 class="text-sm font-semibold text-surface-900 dark:text-surface-0 truncate">{{ trip.title }}</h1>
        <p class="text-[11px] text-surface-400">{{ trip.start_date }} – {{ trip.end_date }}</p>
      </div>
      <span class="text-[10px] font-medium px-1.5 py-0.5 rounded" :class="{
        'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300': trip.status === 'ready',
        'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300': trip.status === 'failed',
        'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/40 dark:text-yellow-300': trip.status === 'partial',
        'bg-surface-100 text-surface-600 dark:bg-surface-700 dark:text-surface-300': trip.status === 'planning',
      }">{{ trip.status }}</span>
    </div>

    <div class="flex-1 overflow-y-auto px-5 py-4 space-y-4">
      <section class="border border-surface-200 dark:border-surface-700 rounded-lg">
        <button class="w-full flex items-center justify-between px-4 py-2 text-sm font-medium" @click="panelOpen = !panelOpen">
          <span>Workflow</span>
          <Icon :icon="panelOpen ? 'tabler:chevron-up' : 'tabler:chevron-down'" class="w-4 h-4" />
        </button>
        <div v-if="panelOpen" class="px-4 pb-3 space-y-1">
          <div v-for="node in NODE_ORDER" :key="node.key" class="flex items-center gap-2 text-xs">
            <Icon :icon="nodeIcon(trip.workflow_state?.nodes[node.key])" :class="nodeIconClass(trip.workflow_state?.nodes[node.key])" class="w-4 h-4" />
            <span class="flex-1">{{ node.label }}</span>
            <span v-if="node.key === 'itinerary_critic' && trip.workflow_state?.nodes[node.key]?.iterations" class="text-[10px] text-surface-400">×{{ trip.workflow_state.nodes[node.key].iterations }}</span>
            <span v-if="trip.workflow_state?.nodes[node.key]?.error" class="text-[10px] text-red-500 truncate max-w-xs" :title="trip.workflow_state.nodes[node.key].error">{{ trip.workflow_state.nodes[node.key].error }}</span>
          </div>
        </div>
      </section>

      <section v-if="trip.plan_json?.warnings?.length" class="border border-yellow-300 dark:border-yellow-700 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg p-3">
        <h2 class="text-xs font-semibold text-yellow-800 dark:text-yellow-200 mb-1">Warnings</h2>
        <ul class="text-xs text-yellow-700 dark:text-yellow-300 list-disc ml-4">
          <li v-for="(w, i) in trip.plan_json.warnings" :key="i">{{ w }}</li>
        </ul>
      </section>

      <section v-if="trip.plan_json?.attractions?.length">
        <h2 class="text-sm font-semibold mb-2">Attractions</h2>
        <ul class="grid grid-cols-1 md:grid-cols-2 gap-2">
          <li v-for="a in trip.plan_json.attractions" :key="a.name" class="border border-surface-200 dark:border-surface-700 rounded p-3">
            <div class="text-sm font-medium">{{ a.name }}</div>
            <div class="text-xs text-surface-500 mt-1">{{ a.description }}</div>
            <div class="text-[10px] text-surface-400 mt-1">~{{ a.typical_duration_hours }}h</div>
          </li>
        </ul>
      </section>

      <section v-if="trip.plan_json?.packing?.length">
        <h2 class="text-sm font-semibold mb-2">Packing</h2>
        <div v-for="cat in trip.plan_json.packing" :key="cat.category" class="mb-2">
          <div class="text-xs font-medium">{{ cat.category }}</div>
          <ul class="text-xs text-surface-600 dark:text-surface-400 ml-4 list-disc">
            <li v-for="i in cat.items" :key="i">{{ i }}</li>
          </ul>
        </div>
      </section>

      <section v-if="trip.plan_json?.flights" class="flex gap-2">
        <a :href="trip.plan_json.flights.google_flights_url" target="_blank" rel="noopener">
          <Button label="Google Flights" size="small" severity="secondary">
            <template #icon><Icon icon="tabler:plane" class="w-4 h-4" /></template>
          </Button>
        </a>
        <a :href="trip.plan_json.flights.skyscanner_url" target="_blank" rel="noopener">
          <Button label="Skyscanner" size="small" severity="secondary">
            <template #icon><Icon icon="tabler:plane" class="w-4 h-4" /></template>
          </Button>
        </a>
      </section>

      <section v-if="trip.plan_json?.itinerary?.length">
        <h2 class="text-sm font-semibold mb-2">Itinerary</h2>
        <ol class="space-y-2">
          <li v-for="(item, i) in trip.plan_json.itinerary" :key="i" class="border border-surface-200 dark:border-surface-700 rounded p-3">
            <div class="flex items-center justify-between">
              <div class="text-sm font-medium">{{ item.attraction_name }}</div>
              <div class="text-[10px] text-surface-400">{{ item.date }} · {{ item.time_slot }} · {{ item.estimated_duration_hours }}h</div>
            </div>
            <div class="text-xs text-surface-500 mt-1">{{ item.description }}</div>
          </li>
        </ol>
      </section>

      <section v-if="trip.tasks?.length">
        <h2 class="text-sm font-semibold mb-2">Generated tasks</h2>
        <ul class="text-xs space-y-1">
          <li v-for="t in trip.tasks" :key="t.id" class="flex items-center gap-2">
            <Icon :icon="t.done ? 'tabler:check' : 'tabler:square'" class="w-3 h-3" />
            <span :class="t.done ? 'line-through text-surface-400' : ''">{{ t.title }}</span>
            <span v-if="t.scheduled_at" class="text-[10px] text-surface-400">{{ t.scheduled_at }}</span>
          </li>
        </ul>
        <Button label="Open tasks" size="small" severity="secondary" class="mt-2" @click="router.push('/tasks')">
          <template #icon><Icon icon="tabler:external-link" class="w-3 h-3" /></template>
        </Button>
      </section>
    </div>
  </div>
  <div v-else-if="isPending" class="h-full flex items-center justify-center">
    <Icon icon="tabler:loader-2" class="w-6 h-6 text-primary animate-spin" />
  </div>
</template>
```

- [ ] **Step 2: Commit**

```bash
git add frontend/applications/main/src/pages/trip-detail.vue
git commit -m "trips: frontend detail page with workflow panel + live refresh"
```

---

## Task 22: Frontend — router + sidebar entry

**Files:**
- Modify: `frontend/applications/main/src/router/index.ts`
- Modify: `frontend/applications/main/src/app/app.vue`

- [ ] **Step 1: Add routes**

In `router/index.ts`, add three entries to the `routes` array before `:pathMatch`:

```ts
  { path: '/trips',         name: 'trips',        component: () => import('../pages/trips-list.vue') },
  { path: '/trips/create',  name: 'trips-create', component: () => import('../pages/trips-create.vue') },
  { path: '/trips/:id',     name: 'trip-detail',  component: () => import('../pages/trip-detail.vue') },
```

- [ ] **Step 2: Add sidebar entry**

In `app/app.vue`, insert this object into `navItems` between `tasks` and `users`:

```ts
  { path: '/trips', name: 'trips', label: 'Trips', icon: 'tabler:plane' },
```

Also update the `currentName` match behaviour to highlight the item when on `/trips/:id` — route name for that is `trip-detail`, not `trips`. The simplest change is to wrap the `aria-current` / active check like:

```ts
function isActive(name: string, prefix?: string) {
  if (currentName.value === name) return true
  if (prefix) return String(currentName.value || '').startsWith(prefix)
  return false
}
```

Then change the `:class` expression on the button to call `isActive(item.name, item.name === 'trips' ? 'trip' : undefined)`.

- [ ] **Step 3: Run the frontend dev server and manually verify nav**

```bash
make dev
# then open http://localhost:5173/ and verify:
# - Trips entry appears in the sidebar with the plane icon
# - Clicking it lands on /trips
# - Create button navigates to /trips/create
```

- [ ] **Step 4: Commit**

```bash
git add frontend/applications/main/src/router/index.ts frontend/applications/main/src/app/app.vue
git commit -m "trips: router + sidebar entry"
```

---

## Task 23: End-to-end smoke test in browser

- [ ] **Step 1: Build + run with the backend**

```bash
make run
```

- [ ] **Step 2: Manual test — form path**

Open `http://localhost:8085/app/`. Navigate to Trips → New Trip. Enter destination "Tokyo", origin "Berlin", start_date two weeks out, end_date +5 days. Submit. Verify:

- You land on `/trips/<id>`
- Workflow panel shows `normalize_input` → `done` within ~1s, then the three sibling branches flip to `running` / `done`
- Attractions section renders (from agent output)
- Packing section renders (or warning surfaces)
- Flights buttons appear
- Itinerary renders; if critic revises, the itinerary re-renders
- Generated tasks list appears with links to `/tasks`
- Status badge flips from `planning` → `ready` (or `partial`)

- [ ] **Step 3: Manual test — chat path**

Open Ask Wippy. Type *"plan a 5-day trip to Barcelona from Paris starting June 15"*. The agent should infer the year, call `PlanTrip`, and reply with a link. Click it and verify the workflow runs through to `ready`.

- [ ] **Step 4: Verify live refresh across tabs**

Open `/trips/<id>` in tab A. In tab B, open Ask Wippy and ask it to re-plan the same destination (creates a new trip). On tab A, the list page invalidates on `trips:changed` events — confirm by flipping back to `/trips` during tab B's workflow and watching the new trip appear. On tab A's existing detail page, no refetch should happen since the `trip_id` in the event won't match.

If any of these fail, check the server logs for the failing node and the `workflow_state.nodes.*.error` field.

- [ ] **Step 5: Commit anything the smoke test surfaced** (only if fixes were needed).

---

## Task 24: Durable-resume test (the learning demo)

- [ ] **Step 1: Start a planning run and kill the server mid-flight**

In one terminal: `./wippy run -c`. In a browser, kick off a new trip. On the detail page, wait until a couple of nodes show `running`/`done`, then:

```bash
pkill -f 'wippy run'
```

Wait 2s, then `./wippy run -c` again.

- [ ] **Step 2: Verify the workflow picks up**

Refresh `/trips/<id>`. The workflow panel should continue from where it left off. Subsequent nodes flip to `done`. Status resolves to `ready` (or `partial`). Tasks appear.

- [ ] **Step 3: Commit no-op if nothing to change**

If the resume behaves correctly, there is nothing to commit. If it does not, diagnose whether the blocker is in the dataflow framework (dataflow_id must be loadable from `trips.workflow_id` after restart) or in our funcs (any state being kept in Lua-local variables across calls). Workflow IDs are persisted in `trips.workflow_id` by `trip_service.create_trip`; that should be enough for the dataflow runner to resume.

---

## Task 25: Update catalog.json + CLAUDE.md + docs/PLAN.md

**Files:**
- Modify: `docs/catalog.json`
- Modify: `CLAUDE.md`
- Modify: `docs/PLAN.md`

- [ ] **Step 1: Update `docs/catalog.json`**

Change the `trip-planner.md` entry summary to reflect that it is implemented:

```json
{
  "path": "docs/specs/trip-planner.md",
  "title": "Trip Planner feature (implemented)",
  "category": "spec",
  "summary": "Dataflow-driven trip planner (SHIPPED): chat/form entry, concurrent research (attractions/packing/flights), critic cycle, task generation, live UI via trips:changed hub events."
}
```

Validate:
```bash
make lint-docs
```

- [ ] **Step 2: Update `CLAUDE.md` Implemented Features table**

Append a row under the existing Task Agent row:

```
| Trip Planner (dataflow workflow, chat/form entry, live UI) | `src/app/trips/` + `trips_trait` | `/trips`, `/trips/create`, `/trips/:id` | [`docs/specs/trip-planner.md`](docs/specs/trip-planner.md) |
```

- [ ] **Step 3: Mention in `docs/PLAN.md` how the feature is shipped** if that file tracks cross-feature state.

- [ ] **Step 4: Commit**

```bash
git add docs/catalog.json CLAUDE.md docs/PLAN.md
git commit -m "docs: trip planner shipped"
```

---

## Appendix: Debugging tips

- **Migrations didn't run:** check that both `app.trips:01_init` and `app.trips:02_tasks_fields` are picked up. `02_tasks_fields` depends on `ns:app.tasks` — if that dependency is missing, the tasks namespace may not register the migration dependency correctly; confirm via `./wippy` logs at startup.
- **Flow compiles but edges are wrong:** read `.wippy/vendor/wippy/dataflow/flow/compiler.lua` to see how `:to(...)` edges compose. The default chain policy is the crux of the sibling pattern in Task 14.
- **Agent output fails exit_schema:** the agent retries up to `arena.max_iterations` and then propagates a failure to the node. The error appears in `workflow_state.nodes.<key>.error` once `save_*` persists it. Lower-level errors show up in the server log with the node id as context.
- **`trips:changed` not reaching the frontend:** confirm `process.registry.lookup("user." .. user_id)` actually returns a pid in a simple Lua REPL script; if it doesn't, the relay session isn't mapped for that user. The tasks feature's `tasks:changed` uses the exact same prefix, so if tasks works and trips doesn't, the diff is in your call site.
- **Critic cycle never exits:** `continue_condition = "output.status ~= 'ok'"` reads the critic agent's structured output. If the expression evaluator in this build uses a different dialect (`!=` vs `~=`, or `neq`), check `compiler.lua` / the `expr` module for the expected syntax.

---

## Self-review

1. **Spec coverage:** every spec section maps to tasks — migrations (T1/T2), repo (T3), HTTP (T4-T6), funcs (T7-T12), agents (T13), flow (T14), service (T15), chat (T16), NavigateTo (T17), frontend (T18-T22), smoke (T23), durable resume (T24), docs (T25). §7 column-responsibility rule is enforced by `trip_repo.update_node_state` / `update_plan_section` being the only write paths. §6 boundary "research vs planning" is enforced by the agent prompts + exit schemas. §9 task generation rules are covered by T9 (`build_task_payloads` tests include flights/packing/per-attraction, past-date clamp, origin-missing notes, and the "no itinerary → no tasks" product rule).
2. **Placeholders:** none — every code step has actual code.
3. **Type consistency:** node keys (`normalize_input`, `attractions_research`, `packing_research`, `flights_linker`, `itinerary_synthesize`, `itinerary_critic`, `build_task_payloads`, `persist_tasks`) are identical in `trip_repo.INITIAL_WORKFLOW_STATE`, in `trip_flow.lua` `:as(...)` labels, and in the frontend `NODE_ORDER` array. Agent ids (`app.agents:trip_attractions_researcher` etc.) are consistent between `_index.yaml` registration and `trip_flow.lua`. `plan_json` keys (`attractions`, `packing`, `flights`, `itinerary`, `warnings`) are identical across `save_*` funcs, `build_task_payloads` input shape, and `TripDetail.plan_json` in the TS types.
