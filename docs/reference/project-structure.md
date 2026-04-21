# Project Structure Convention

How `src/app/` is organized and where new code goes. Applies to all features
added after 2026-04-21.

## Layout

```
src/app/
├── _index.yaml                 # gateway, routers, db, cache, process host, fs
├── deps/, env/, models/, security/, views/, agents/   # infra/config
│
├── api/                        # Cross-cutting / platform endpoints only.
│   ├── _index.yaml             #   (hello demo lives here)
│   ├── auth/                   ← login_page
│   ├── discovery/              ← list_agents, list_models, *_by_name
│   └── websocket/              ← ws_endpoint
│
└── <feature>/                  # Feature folder (users, tasks, trips, ...)
    ├── _index.yaml             #   all feature entries (handlers, libs, tools, tests)
    ├── api/                    #   HTTP handlers + endpoint wiring
    ├── tools/                  #   agent tools (if any)
    ├── flow/                   #   dataflow nodes (if any — see trips)
    ├── migrations/             #   schema migrations (if any)
    ├── tests/                  #   test files (when more than one)
    ├── <feature>_repo.lua      #   libraries at feature root
    ├── <feature>_service.lua
    └── <feature>_common.lua
```

## The four rules

1. **Every feature owns its HTTP.** Handlers go in `<feature>/api/`. Never at
   feature root.
2. **`app/api/` is for cross-cutting only** — auth, registry discovery,
   websocket, demo endpoints. It is **not** "the API folder"; feature APIs
   live under the feature.
3. **Libraries stay at feature root** (`*_repo.lua`, `*_service.lua`,
   `*_common.lua`) until a feature has 5+ lib files. Only then introduce a
   `lib/` subfolder.
4. **Tests go in `<feature>/tests/`** once there's more than one.

## Wippy context

Wippy is permissive — the registry uses child→parent references
(`meta.router`), so source files can live anywhere. This document picks one
layout for *this* project to keep new features consistent.

Two idioms are equally valid per Wippy docs:
- entry-type (`src/api/`, `src/lib/`, `src/workers/`) — from the official
  `start/structure` page
- concern/feature — from the `APP-TEMPLATE` KB pattern this repo uses

We use the second, with entry-type subfolders *inside* each feature (`api/`,
`tools/`, `migrations/`, `tests/`). Proven in `trips/`; normalized to
`users/` and `tasks/` on 2026-04-21.

## Migrating drift

If you find a feature not following this layout, the migration is mechanical:
- move files under the right subfolder (use `git mv` to preserve history)
- update `source: file://...` lines in `_index.yaml`
- registry entry names and namespaces don't change → no caller impact
- verify with `wippy run test <suite>` or a brief `wippy run -c` boot
