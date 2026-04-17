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
