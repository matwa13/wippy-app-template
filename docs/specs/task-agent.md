# Task Agent

A per-user **Task Agent** feature that allows users to manage tasks either through:

- the `/tasks` page UI (create with full fields, toggle done, delete, view notes)
- or by chatting with the existing Wippy agent

All chat-driven changes are reflected live in the UI via a hub event.

---

## Key Decisions

- Extended the existing Wippy agent with a `tasks_trait` (single-agent approach)
- Implemented fuzzy title matching:
    - exact match
    - unique substring
    - disambiguation candidates
- Used SQLite with `wippy/migration` (`01_init.lua`, `02_add_fields.lua`)
- Introduced:
    - `task_repo.lua` — DB access layer
    - `tools_common.lua` — shared helpers (`notify`, `candidate_titles`)
- Agent returns plain markdown (no artifact) for `ListTasks`
- Implemented live UI updates via:
  process.send(hub, "tasks:changed", {})
  → frontend wippy.on('tasks:changed', …)
  → vue-query invalidate

---

## Data Model

### Schema (`tasks` table)

| Column        | Type    | Notes                                                       |
|---------------|---------|-------------------------------------------------------------|
| id            | TEXT PK | UUIDv7                                                      |
| user_id       | TEXT    | FK to user, indexed                                         |
| title         | TEXT    | Required                                                    |
| done          | INTEGER | 0/1                                                         |
| notes         | TEXT    | Nullable. Markdown — rendered with `MarkdownNotes` in the UI. |
| due_date      | TEXT    | Nullable, ISO date (e.g. `2026-04-20`)                      |
| priority      | INTEGER | 1=low, 2=medium (default), 3=high                           |
| trip_id       | TEXT    | Nullable FK → `trips.id`, indexed. Set by Trip Planner; standalone tasks leave it null. |
| scheduled_at  | TEXT    | Nullable ISO date — when the user should *do* the task. Distinct from `due_date` (external deadline). For trip-generated tasks, `scheduled_at` is always set; `due_date` is mirrored to the same value for packing/per-attraction tasks so they appear on the dated-task list. |
| created_at    | INTEGER | Unix epoch                                                  |
| updated_at    | INTEGER | Unix epoch                                                  |

### Migrations

- `src/app/tasks/migrations/01_init.lua` — creates `tasks` table with id, user_id, title, done, timestamps
- `src/app/tasks/migrations/02_add_fields.lua` — adds notes, due_date, priority columns
- `src/app/trips/migrations/02_tasks_fields.lua` — owned by the Trip Planner feature; adds `trip_id` and `scheduled_at` columns plus the `idx_tasks_trip` index. See [`trip-planner.md`](trip-planner.md) for how those columns are populated.

---

## HTTP API

### Endpoints

- `GET /api/v1/tasks?filter=all|open|done`
- `POST /api/v1/tasks`
  ```json
  { "title": "...", "notes"?: "...", "due_date"?: "2026-04-20", "priority"?: 1|2|3 }
  ```
- `PATCH /api/v1/tasks/{id}`
  ```json
  { "title"?: "...", "done"?: boolean, "notes"?: "...", "due_date"?: "...", "priority"?: 1|2|3 }
  ```
- `DELETE /api/v1/tasks/{id}`

---

## Agent Tools

Five tools bundled in `tasks_trait`:

| Tool         | LLM Alias    | Description                                      |
|--------------|--------------|--------------------------------------------------|
| add_task     | AddTask      | Create task with optional notes, due_date, priority (string labels: "low"/"medium"/"high") |
| list_tasks   | ListTasks    | List tasks with optional filter                  |
| update_task  | UpdateTask   | Update notes, due_date, priority by id or title  |
| complete_task| CompleteTask | Mark a task done by id or title                  |
| delete_task  | DeleteTask   | Delete a task by id or title                     |

Agent tools use string priority labels (`"low"`, `"medium"`, `"high"`) mapped to integers internally. HTTP API uses integers directly.

---

## Sort Order

Tasks are sorted into three groups:

1. **Overdue** — not done, has due_date, due_date < today
2. **Active** — not done, not overdue
3. **Completed** — done (sorted by updated_at DESC, most recently completed first)

Within overdue and active groups:
- Priority: high → medium → low
- Dated tasks first (ascending by due_date), dateless tasks last
- Tiebreaker: created_at DESC

Sort is implemented SQL-side in `task_repo.lua` so both the HTTP API and agent tools return consistently ordered results.

---

## Frontend

### Task List (`tasks.vue`)
- Priority badge: shown for high (red) and low (gray), hidden for medium (default)
- Due date badge: shown for open tasks, turns red when overdue
- Overdue row: subtle red background tint
- Notes: toggle button expands an inline text area below the task row

### Create Form
- Title input (always visible)
- Collapsible "more fields" section with:
  - Priority: PrimeVue Select (Low/Medium/High)
  - Due date: PrimeVue DatePicker
  - Notes: PrimeVue Textarea

---

## Authorization

All endpoints are scoped per user:

  ```lua
  security.actor():id()
  ```

→ strictly per-user task isolation

---

## Suggested Next Steps

- Tests: add a tasks_test.lua mirroring users_test.lua (repo + endpoint coverage).
- Inline editing: allow editing priority, due_date, notes on existing tasks from the task list UI.
- SQL-side matching: if users accumulate hundreds of tasks, push find_by_title into LIKE queries.
- Fix per-user persist leak (#4): namespace the Pinia persist key by user_id, or clear the store on logout —
  worthwhile when addressed alongside the same issue in users.ts.
- Agent UX: if "show my tasks" feels visually underwhelming as markdown, swap ListTasks to return a
  CreateArtifact-style card.
