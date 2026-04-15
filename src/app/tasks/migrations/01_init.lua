return require("migration").define(function()
    migration("Create tasks table", function()
        database("sqlite", function()
            up(function(db)
                db:execute([[
                    CREATE TABLE IF NOT EXISTS tasks (
                        id         TEXT PRIMARY KEY,
                        user_id    TEXT NOT NULL,
                        title      TEXT NOT NULL,
                        done       INTEGER NOT NULL DEFAULT 0,
                        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
                    )
                ]])
                db:execute("CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks(user_id, created_at DESC)")
                return true
            end)

            down(function(db)
                db:execute("DROP TABLE IF EXISTS tasks")
                return true
            end)
        end)
    end)
end)
