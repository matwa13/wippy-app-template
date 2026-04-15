# Task Agent

A per-user **Task Agent** feature that allows users to manage tasks either through:

- the `/tasks` page UI
- or by chatting with the existing Wippy agent

All chat-driven changes are reflected live in the UI via a hub event.

---

## Key Decisions

- Extended the existing Wippy agent with a `tasks_trait` (single-agent approach)
- Implemented fuzzy title matching:
    - exact match
    - unique substring
    - disambiguation candidates
- Used SQLite with `wippy/migration` (`01_init.lua`)
- Introduced:
    - `task_repo.lua` — DB access layer
    - `tools_common.lua` — shared helpers (`notify`, `candidate_titles`)
- Agent returns plain markdown (no artifact) for `ListTasks`
- Implemented live UI updates via:
  process.send(hub, "tasks:changed", {})
  → frontend wippy.on('tasks:changed', …)
  → vue-query invalidate

---

## HTTP API

### Endpoints

- `GET /api/v1/tasks?filter=all|open|done`
- `POST /api/v1/tasks`
  ```json
  { "title": "..." }
  ```
- `PATCH /api/v1/tasks/{id}`
  ```json
  { "title"?: "...", "done"?: boolean }
  ```
- `DELETE /api/v1/tasks/{id}`

## Authorization

All endpoints are scoped per user:

  ```lua
  security.actor():id()
  ```

→ strictly per-user task isolation

## Suggested Next Steps

- Tests: add a tasks_test.lua mirroring users_test.lua (repo + endpoint coverage).
- Richer fields: notes, due_date, priority if product needs them.
- SQL-side matching: if users accumulate hundreds of tasks, push find_by_title into LIKE queries.
- Fix per-user persist leak (#4): namespace the Pinia persist key by user_id, or clear the store on logout —
  worthwhile when addressed alongside the same issue in users.ts.
- Agent UX: if "show my tasks" feels visually underwhelming as markdown, swap ListTasks to return a
  CreateArtifact-style card.