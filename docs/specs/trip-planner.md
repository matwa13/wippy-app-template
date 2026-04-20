# Trip Planner

A **Trip Planner** feature that turns a destination + dates into a drafted itinerary, packing list, flight search link, and a structured set of tasks. Built on top of `wippy/dataflow` as the first non-trivial workflow in this project.

The feature has two entry points — a chat tool and a web form — and a dedicated page that shows the workflow executing in real time.

---

## Goals

1. **User value.** A single prompt or form submission produces a rough travel plan and the tasks to execute it.
2. **Learning value.** Exercise the main `wippy/dataflow` primitives in one coherent feature: `func` nodes, `agent` nodes with `arena.exit_schema`, concurrent sibling DAG branches, `join` gates that merge upstream inputs, and durable resume.

---

## Key Decisions

- **Chat-first clarification (Option A).** The Wippy agent collects missing info conversationally; the workflow itself runs straight through without pausing. The `plan_trip` tool's required args enforce this contract.
- **Two entry points, one workflow.** Chat tool and form both POST to the same endpoint; same dataflow graph runs either way.
- **Trip is a first-class entity.** New `trips` table with its own pages. Tasks get a nullable `trip_id` FK.
- **Concurrent sibling DAG, not `parallel()`.** `parallel()` is strictly for array fan-out. Three heterogeneous research branches (attractions, packing, flights) are modelled as three sibling nodes with a shared upstream.
- **Join-gated "save-after-each-agent" pattern.** Agent outputs use `additionalProperties:false` exit schemas, which strip any trip context passed through them. To give each persistence step access to both the agent's output and `{trip_id, user_id}`, every persistence `func` is preceded by a `:join()` that merges the agent output (on the `default` discriminator) with a `context` edge fanned out directly from `normalize_input`. The same pattern guards the downstream `flights_linker`, `build_task_payloads`, and `persist_tasks` nodes.
- **Structured agent outputs.** All workflow agents use `arena.exit_schema`; prompt-level JSON instructions are kept as *complementary*, not sufficient.
- **`workflow_state` vs `plan_json` are strictly separate** (see §7). Technical execution state and user-facing plan content never mix columns.
- **Flights via deep-links only for MVP.** No external API. A small LLM node (`iata_resolver`) resolves origin/destination city names to IATA airport codes; `flights_linker` is a pure Lua func that turns those codes + dates into a Skyscanner deep-link. The resolver is non-critical — unresolved codes degrade to a warning instead of a link. Real API integration is future work.
- **Live UI via `trips:changed` hub events**, same pattern as the existing `tasks:changed` event from the task agent.

---

## Entry Points

### Chat

A `trips_trait` is attached to the existing Wippy agent (mirroring `tasks_trait`). It exposes a single tool:

- **`PlanTrip(destination: string, start_date: date, end_date: date, origin?: string)`** (registry id `app.trips:plan_trip`, LLM alias `PlanTrip`) — creates the trip row and starts the workflow. Required args enforced by the tool schema so the agent clarifies before calling.

On success the tool returns `{trip_id, url: "/app/trips/<id>"}` so the agent can reply with a link.

### Form

Page at `/trips/create` with fields: `destination`, `origin` (optional), `start_date`, `end_date`. Submits to `POST /api/v1/trips` and navigates to the detail page.

### Clarification behaviour (chat)

Clarification lives entirely in the chat agent. The workflow assumes its preconditions hold. If the agent detects trip intent without all required fields, it asks follow-ups conversationally and only invokes `PlanTrip` once it has destination + start_date + end_date. `origin` remains optional and gracefully degrades (see §5.3).

---

## Data Model

### `trips` table (new migration)

| Column           | Type        | Notes                                           |
|------------------|-------------|-------------------------------------------------|
| id               | TEXT PK     | UUIDv7                                          |
| user_id          | TEXT        | FK to user, indexed                             |
| title            | TEXT        | Derived: `"<Destination>, <start> – <end>"`     |
| destination      | TEXT        | Canonicalized by `normalize_input`              |
| origin           | TEXT        | Nullable                                        |
| start_date       | TEXT        | ISO date                                        |
| end_date         | TEXT        | ISO date                                        |
| status           | TEXT        | `planning` \| `ready` \| `partial` \| `failed`  |
| workflow_id      | TEXT        | Dataflow workflow ID, for debugging             |
| workflow_state   | TEXT (JSON) | Technical execution state — see §7              |
| plan_json        | TEXT (JSON) | User-facing plan content — see §7               |
| created_at       | INTEGER     | Unix epoch                                      |
| updated_at       | INTEGER     | Unix epoch                                      |

### `tasks` table — additions (new migration)

| Column         | Type    | Notes                                    |
|----------------|---------|------------------------------------------|
| trip_id        | TEXT    | Nullable FK → trips.id, indexed          |
| scheduled_at   | TEXT    | Nullable ISO date — distinct from existing `due_date` to keep semantics clean. `scheduled_at` = when the user should do the task; `due_date` = external deadline. For trip-generated tasks, only `scheduled_at` is set. |

Tasks without `trip_id` retain existing standalone behaviour.

---

## Workflow

### DAG

```
normalize_input ──┬── attractions_research ── save_attractions_gate ── save_attractions ──┐
  (func)          │   (agent)                 (join)                   (func)             │
                  │                                                                       │
                  ├── packing_research ────── save_packing_gate ────── save_packing ──────┤
                  │   (agent)                 (join)                   (func)             │
                  │                                                                       │
                  ├── iata_resolver ───────── save_iata_resolver_gate ─ save_iata_resolver─┤
                  │   (agent)                 (join)                    (func)            │
                  │                                                            │          │
                  │                                                            ▼          │
                  │                                                    flights_linker_gate│
                  │                                                            │          │
                  │                                                            ▼          │
                  │                                                     flights_linker ───┤
                  │                                                        (func)         │
                  │                                                                       │
                  │                                                                       ▼
                  │                                                                     join
                  │                                                                       │
                  │                                                                       ▼
                  │                                                              itinerary_synthesize
                  │                                                                  (agent)
                  │                                                                       │
                  │                                                                       ▼
                  │                                                              save_itinerary_gate
                  │                                                                       │
                  │                                                                       ▼
                  │                                                                save_itinerary
                  │                                                                    (func)
                  │                                                                       │
                  │                                                                       ▼
                  └───────────── context ─────────────────────────────► build_task_payloads_gate
                                                                                          │
                                                                                          ▼
                                                                                 build_task_payloads
                                                                                       (func)
                                                                                          │
                                                                                          ▼
                                                                                 persist_tasks_gate
                                                                                          │
                                                                                          ▼
                                                                                    persist_tasks
                                                                                       (func)
```

Defined in `src/app/trips/flow/trip_flow.lua` via `flow.create():with_input(trip_context):start()`. The returned workflow ID is written to `trips.workflow_id`.

The flow is strictly linear once synthesis begins: the three research branches fan out from `normalize_input`, each agent's output is merged with the trip context at a `save_*_gate` and persisted by the matching `save_*` func, then the shared `join` gates all three before the synthesizer runs. After the synthesizer, `save_itinerary` writes to `plan_json`, then `build_task_payloads` produces the task rows and `persist_tasks` writes them.

### Node roles

| Node                         | Type              | Role                                                                         | Critical? |
|------------------------------|-------------------|------------------------------------------------------------------------------|-----------|
| `normalize_input`            | func              | Canonicalize destination, resolve dates, compute `duration_days` + `season`, default origin. Deterministic, no LLM. Also fans out `{trip_id, user_id, ...}` as a `context` edge to every downstream persistence/join node so agent schemas can stay closed. | yes |
| `attractions_research`       | agent             | Research only. Returns bounded list (6–12) of places as `[{name, description, typical_duration_hours, constraints[]}]`. No scheduling. | yes |
| `save_attractions`           | func              | Writes agent output to `plan_json.attractions`, marks node done in `workflow_state`, notifies hub. Preceded by `save_attractions_gate` join. | yes |
| `packing_research`           | agent             | Climate/season-aware packing list as `[{category, items[]}]`.                | **no** (failure → warning) |
| `save_packing`               | func              | Writes agent output to `plan_json.packing`; on empty/failed output logs a warning instead. Preceded by `save_packing_gate` join. | no (tolerant) |
| `iata_resolver`              | agent             | Resolves origin + destination city names to IATA airport codes. Returns `null` for fields it can't confidently resolve. | **no** (failure or null → warning, no link) |
| `save_iata_resolver`         | func              | Persists IATA codes on `plan_json` and forwards them to `flights_linker`. Preceded by `save_iata_resolver_gate` join. | no (tolerant) |
| `flights_linker`             | func              | Builds a Skyscanner deep-link from IATA codes + dates. Emits warning if either code is missing. Always succeeds. Preceded by `flights_linker_gate` join. | yes (but tolerant) |
| `join`                       | join              | Gathers the three research branches (`attractions`, `packing`, `flights`) before synthesis. Fans output to both `itinerary_synthesize` and `build_task_payloads_gate` (as `support`). | — |
| `itinerary_synthesize`       | agent             | Planning decisions: selects attractions + schedules them by day/slot, respecting arrival/departure load rules. | yes |
| `save_itinerary`             | func              | Writes itinerary to `plan_json.itinerary`, marks node done; fails the workflow if the itinerary is empty. Preceded by `save_itinerary_gate` join. | yes |
| `build_task_payloads`        | func              | Pure plan→rows transformation. Unit-testable without DB. Preceded by `build_task_payloads_gate` join that collects: itinerary (`default`), research results (`support`), trip context (`context`). | yes |
| `persist_tasks`              | func              | Writes tasks via `task_repo` in one transaction; fires `tasks:changed`. Preceded by `persist_tasks_gate` join. | yes |

### Naming convention: node keys vs agent IDs

Node keys used in `workflow_state` (`attractions_research`, `itinerary_synthesize`) differ from the agent IDs that implement them (`trip_attractions_researcher`, `trip_itinerary_synthesizer`). This is intentional, not drift:

- **Node keys** are short `<domain>_<verb>` forms scoped to this workflow. They read naturally as state-machine step names and keep `workflow_state` compact.
- **Agent IDs** carry the `trip_` prefix because agents sit in the global agents registry next to `Wippy` and others; the prefix prevents collisions and signals ownership.

Only the agent node keys (and `normalize_input` / `flights_linker` / `build_task_payloads` / `persist_tasks`) are tracked in `workflow_state.nodes`. The `save_*` funcs and `*_gate` joins are plumbing — they write to `workflow_state` only indirectly (via the node whose output they persist) and are omitted from the initial node map.

### Boundary rule: research vs planning

Research agents (`attractions_research`, `packing_research`) describe *the world* — stable facts about places and climates. The itinerary agent (`itinerary_synthesize`) makes *decisions* — selects which attractions to include, assigns them to days and time slots. Constraints like `"closed Mondays"` or `"best in daylight"` belong in research output; choosing which day to visit belongs in planning output.

### Agent arena configuration

All workflow agents use structured exit output. Prompt-level "output JSON" instructions remain as a complement. Schemas live in `trip_flow.lua` at the call site (not in the agent YAML) because the flow-builder reads arena config from the DSL, not the registry.

| Agent                         | `exit_schema` | `arena.max_iterations` |
|-------------------------------|---------------|------------------------|
| `trip_attractions_researcher` | yes           | 4                      |
| `trip_packing_researcher`     | yes           | 4                      |
| `trip_iata_resolver`          | yes           | 2                      |
| `trip_itinerary_synthesizer`  | yes           | 4                      |

`arena.max_iterations` is the agent's in-node self-repair budget when its output fails `exit_schema`; each retry feeds the validation error back as an observation.

### Files

```
src/app/trips/
  _index.yaml                    -- module registration
  migrations/
    01_init.lua                  -- trips table
    02_tasks_fields.lua          -- tasks.trip_id + tasks.scheduled_at
  trip_repo.lua                  -- CRUD + workflow_state / plan_json update helpers
  trip_service.lua               -- shared service layer: create_trip used by HTTP + tool
  trips_common.lua               -- hub notify + small helpers shared across flow nodes
  api/                           -- HTTP handlers
    create_trip.lua              -- POST   /api/v1/trips
    list_trips.lua               -- GET    /api/v1/trips
    get_trip.lua                 -- GET    /api/v1/trips/{id}
    delete_trip.lua              -- DELETE /api/v1/trips/{id}
  tools/
    plan_trip.lua                -- agent tool handler
  flow/
    trip_flow.lua                -- builds the DAG
    normalize_input.lua          -- func node (also fans out trip context)
    save_attractions.lua         -- func: agent output → plan_json.attractions
    save_packing.lua             -- func: agent output → plan_json.packing
    save_iata_resolver.lua       -- func: agent output → plan_json.flights (iata codes)
    flights_linker.lua           -- func: builds Skyscanner URL
    save_itinerary.lua           -- func: agent output → plan_json.itinerary
    build_task_payloads.lua      -- func: plan → task row payloads
    persist_tasks.lua            -- func: writes tasks, fires tasks:changed
```

Agents are defined in `src/app/agents/_index.yaml` following the project convention.

---

## Column Responsibilities: `workflow_state` vs `plan_json`

These two JSON columns on `trips` serve **strictly separate purposes** and must not overlap. When deciding where a field belongs, apply this test: *would removing this field still leave a well-formed trip plan visible to the user?* If yes → `workflow_state`. If no → `plan_json`.

### `workflow_state` — technical execution state

Describes *how* the workflow is progressing. Internal/operational. Consumed by the workflow-status panel and backend monitoring.

- Per-node status: `pending` | `running` | `done` | `failed`
- Per-node error messages
- Per-node `started_at` / `ended_at` timestamps
- Never contains any of the plan content itself

Initial value on trip creation:

```json
{
  "nodes": {
    "normalize_input":      { "status": "pending" },
    "attractions_research": { "status": "pending" },
    "packing_research":     { "status": "pending" },
    "iata_resolver":        { "status": "pending" },
    "flights_linker":       { "status": "pending" },
    "itinerary_synthesize": { "status": "pending" },
    "build_task_payloads":  { "status": "pending" },
    "persist_tasks":        { "status": "pending" }
  }
}
```

### `plan_json` — user-facing trip content

Describes *what* the trip plan contains. The output of the workflow from the user's perspective.

- `attractions[]` — from `trip_attractions_researcher`
- `packing[]` — from `trip_packing_researcher` (empty if that branch failed)
- `flights{skyscanner_url, origin_iata, destination_iata}` — from `save_iata_resolver` + `flights_linker`
- `itinerary[]` — from `trip_itinerary_synthesizer`, written once by `save_itinerary`
- `warnings[]` — user-facing degradation messages ("Origin not provided", "Packing list unavailable"), because the user needs to see them alongside the content they qualify

### Invariants

- A node writing to `plan_json` MUST NOT write to `workflow_state` in the same call, and vice versa — each update path is separate.
- `plan_json` is append-only per section; each branch writes its own key once.
- `workflow_state` is the only place that references nodes by name.
- `trips.status` (the trip-level status driving list-page filtering) is its own column — not buried in either JSON.
- The UI renders from `plan_json` for content and from `workflow_state` for progress indicators. The two views are independent.

Edge-case placements:

| Field                   | Column           |
|-------------------------|------------------|
| `warnings`              | `plan_json`      |
| Per-node error message  | `workflow_state` |
| Trip-level `status`     | own column       |

---

## HTTP API

All routes under the authenticated `api` router (token required). Handlers in `src/app/trips/api/`. Ownership enforced in every handler (`trip.user_id == ctx.user_id` or 404).

### Endpoints

- `POST /api/v1/trips` — create trip + start workflow.
  ```json
  { "destination": "Tokyo", "origin": "Berlin", "start_date": "2026-05-01", "end_date": "2026-05-07" }
  ```
  Returns `{ "trip_id": "…", "url": "/app/trips/…" }`.

- `GET /api/v1/trips?filter=all|planning|ready|failed` — list current user's trips.
  Returns `[{ id, destination, start_date, end_date, status, updated_at }]`.

- `GET /api/v1/trips/:id` — full trip detail.
  Returns `{ id, destination, origin, start_date, end_date, status, workflow_state, plan_json, tasks }`.

- `DELETE /api/v1/trips/:id` — remove the trip and cascade-delete its tasks.
  Returns `{ "ok": true }`. The frontend detail page redirects back to `/trips` on success.

Both the HTTP create handler and the `PlanTrip` chat tool delegate to a single service function (`trip_service.create_trip(user_id, input)` in `src/app/trips/trip_service.lua`) that inserts the row, kicks off the workflow, and returns `{trip_id, url}`. Each caller adapts the service result to its own medium — the HTTP handler formats a JSON response, the tool formats a tool-result payload. No internal HTTP round-trip.

**Out of MVP:** `PATCH`, `POST /retry` — see §11.

---

## Hub Events

Single event name: **`trips:changed`** with payload `{trip_id}`.

Fired from the backend whenever any part of a trip row changes — workflow state transition, partial plan write, final status change, deletion. Consumers on the detail page and the list page react by invalidating the relevant vue-query key and refetching. Matches the existing `tasks:changed` pattern.

`persist_tasks` additionally fires `tasks:changed` so the `/tasks` page stays fresh.

---

## Frontend

Three new routes added to `frontend/applications/main/` (Vue Router, memory history).

| Route             | Component              | Purpose                                                         |
|-------------------|------------------------|-----------------------------------------------------------------|
| `/trips`          | `TripsListPage.vue`    | Paginated list, status filter, "+ New Trip" button              |
| `/trips/create`   | `TripCreatePage.vue`   | Form; submit → POST → navigate to detail                        |
| `/trips/:id`      | `TripDetailPage.vue`   | Live view (see below)                                           |

`views/_index.yaml` gets a new `view.page` entry to register the feature with the host so "Trips" appears in the sidebar nav.

### `TripDetailPage.vue` layout (top to bottom)

1. **Header** — destination + dates + status badge (`planning` / `ready` / `partial` / `failed`), link back to `/trips`, delete button.
2. **Workflow panel** — compact list of the 8 tracked nodes with live status dots (pending ⚪ / running ⏳ / done ✅ / failed ❌). Collapsible; pinned open while `status=planning`, collapsed by default once `ready`.
3. **Warnings banner** — rendered when `plan_json.warnings[]` is non-empty.
4. **Attractions** — card list; appears once `attractions_research` done.
5. **Packing** — category accordion; appears once `packing_research` done, or a "Packing list unavailable" placeholder if it failed.
6. **Flights** — a Skyscanner button opening in new tab; appears once `flights_linker` done. If IATA resolution failed (for either endpoint), a "Flight search unavailable" placeholder with the warning is shown instead.
7. **Itinerary** — day-by-day timeline; appears once `itinerary_synthesize` done.
8. **Generated tasks** — simple list linking to `/tasks`; appears once `persist_tasks` done.

Subscription:

```ts
wippy.on('trips:changed', ({ trip_id }) => {
  if (trip_id === route.params.id) queryClient.invalidateQueries(['trip', trip_id])
})
```

---

## Task Generation Rules

`build_task_payloads` produces task rows from `plan_json` + trip metadata. `persist_tasks` writes them in one transaction with `trip_id` set on each.

### Categories

**1. Flights task** (always created when status would be `ready` or `partial`)

- Title: `"Book flights — <origin?> → <destination> (<start> – <end>)"` (origin omitted when missing)
- `scheduled_at`: **today**. MVP assumption: booking should happen as soon as possible after trip creation. A date-aware rule (e.g., "schedule booking reminder for N weeks before departure") is future work.
- Notes (markdown):
  ```
  [Search on Skyscanner](<skyscanner_url>)
  ```
  If origin is missing or IATA resolution failed, the corresponding warning is prepended and the Skyscanner link is omitted.

**2. Packing task** (created only if `packing_research` succeeded)

- Title: `"Pack for <destination> trip"`
- `scheduled_at`: `start_date - 1 day`
- Notes: markdown checklist (`- [ ] item`) grouped by category.
- If `packing_research` failed, the task is **skipped** and a warning surfaces on the trip page.

**3. Per-attraction tasks** (one per itinerary item)

- Title: `"Visit <attraction_name>"`
- `scheduled_at`: the `date` from that itinerary item.
- Notes: description, time_slot, estimated duration, relevant `constraints`.
- If the same attraction appears on multiple days, each occurrence becomes a separate task.

### Scheduling rules

- **Past-date clamp.** If any computed `scheduled_at` falls before today (e.g., a packing task for a trip starting tomorrow or a per-attraction task for a trip starting today), the value is clamped to **today**. This keeps the tasks list actionable and avoids creating pre-overdue rows.
- **Priority is advisory only.** Flights task gets high priority, packing gets medium, attractions get low. These are hints for the task list UI; the workflow does not enforce ordering or gate task visibility on priority. Users may reorder freely in the task UI.

### Product decision: tasks require an itinerary

Tasks are created only when the synthesizer produced a valid itinerary. This is a **product decision, not a technical constraint** — flights and packing data exist independently on `plan_json` and could in principle be materialized as standalone tasks. The rationale: a trip without a plan isn't worth cluttering the user's task list. Flights and packing remain visible on the trip detail page as context regardless. If user research later shows demand for "partial task creation," this rule is trivial to relax.

---

## Status Semantics

- **`planning`** — workflow has started, not yet reached `persist_tasks`.
- **`ready`** — itinerary synthesized AND tasks persisted. Core purpose achieved.
- **`partial`** — itinerary + tasks present, but one or more auxiliary branches (packing, flights) failed. Trip is usable; warnings surface in UI.
- **`failed`** — attractions empty, synthesizer failed, or `persist_tasks` failed. No tasks created.

The per-node `workflow_state` stays available for all statuses — failures leave the node in `failed` state with an error message.

---

## Durable Resume (Learning Demo)

Because execution state is persisted via `wippy/dataflow` plus our own `trips.workflow_state` + `plan_json`, the workflow survives server restarts.

**To observe this:** start a trip planning run, kill `./wippy run` mid-execution, restart with `./wippy run -c`. The workflow picks up from the last completed node, remaining nodes execute, `trips:changed` fires, and the `/trips/:id` page updates live through the resume without any frontend action.

This is the most direct way to internalize why dataflow is worth using over ad-hoc async chains.

---

## Educational Payoffs

Each part of this feature exists in part to expose a specific dataflow primitive:

| Learning target                           | Where it shows up                                                              |
|-------------------------------------------|--------------------------------------------------------------------------------|
| `func` nodes                              | `normalize_input`, `save_*`, `flights_linker`, `build_task_payloads`, `persist_tasks` |
| `agent` nodes with `arena.exit_schema`    | All four workflow agents                                                       |
| Concurrent sibling DAG (not `parallel()`) | The three research branches after `normalize_input`                            |
| `join` gates for multi-input funcs        | `save_*_gate`, `flights_linker_gate`, `build_task_payloads_gate`, `persist_tasks_gate` — merge agent output with trip context so downstream funcs see both |
| Explicit context-fanout edges             | `normalize_input` fans `context` to every gate that needs `trip_id` + `user_id`, keeping agent exit schemas closed (`additionalProperties:false`) |
| Durable resume                            | `trips.workflow_state` + dataflow durability + hub-driven UI                   |

---

## Authorization

All endpoints and the `PlanTrip` tool are scoped per user via `security.actor():id()`. Tasks created by the workflow inherit the trip's `user_id`. The DELETE handler verifies `trip.user_id == ctx.user_id` before removing any rows.

---

## MVP Scope

### In scope

- `trips` table migration; `tasks.trip_id` + `tasks.scheduled_at` migration
- Chat entry point (`trips_trait` + `PlanTrip` tool) and form entry point (`/trips/create`)
- Full workflow: `normalize_input` → 3 concurrent research siblings (each with its own `save_*_gate` + `save_*` persistence func) → shared `join` → `itinerary_synthesize` → `save_itinerary` → `build_task_payloads` → `persist_tasks`
- Four workflow agents with `arena.exit_schema`
- Four HTTP endpoints (create, list, get, delete)
- Three frontend pages (`/trips`, `/trips/create`, `/trips/:id`) with a delete control on the detail page
- Sidebar nav entry "Trips"
- Live workflow panel + hub-driven refresh on detail page
- Task generation with past-date clamp and advisory priorities
- Warnings surfaced on trip detail page and in flights task notes

### Out of scope (future work)

**Near-term (same feature, deferred for scope):**

- Additional trip fields: `travelers`, `interests`, `budget_tier` (explicitly deferred during brainstorming). When added, they wire into the form, the agent prompts, and the `PlanTrip` tool schema.
- `PATCH /api/v1/trips/:id` — manual edits after creation
- `POST /api/v1/trips/:id/retry` — restart a failed workflow with the same input
- Regenerate a single branch (e.g., "more attraction ideas") leveraging dataflow's partial re-run semantics
- "Preview tasks" step between `build_task_payloads` and `persist_tasks` (leverages the existing split)
- Filter `/tasks` page by `trip_id`
- Smarter flights-task scheduling (e.g., "book 4 weeks before departure") replacing the MVP "today" rule

**Medium-term:**

- Real flight API integration (Amadeus test tier or similar)
- Budget estimate agent as a 4th concurrent research branch
- Hotel suggestions branch
- Per-day weather forecast integration (turns packing from generic-climate to date-specific)
- Map view on trip detail page (geocoding + Leaflet)
- Reintroduce an itinerary-quality pass — either as a cycle (synthesizer ↔ critic) or as a single post-synthesis review node — once the "straight-through" flow proves too lossy in practice

**Longer-term:**

- Multi-destination trips (DAG extends to per-leg research)
- Trip sharing / collaboration (depends on multi-user primitives we don't have yet)
- Booking execution, not just search links — financial action, requires explicit user confirmation UX

---

## Suggested Next Step

After this spec is approved, the implementation plan should sequence the increments so each one is independently verifiable: migrations first, then `trip_repo` + API shell, then each workflow node in isolation (funcs before agents), then the full wired DAG, then the frontend. The learning-demo "kill the server mid-run" test is a good acceptance gate for the durability story.
