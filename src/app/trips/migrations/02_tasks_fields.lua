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
