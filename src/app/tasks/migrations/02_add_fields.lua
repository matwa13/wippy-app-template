return require("migration").define(function()
    migration("Add notes, due_date, priority to tasks", function()
        database("sqlite", function()
            up(function(db)
                db:execute("ALTER TABLE tasks ADD COLUMN notes TEXT")
                db:execute("ALTER TABLE tasks ADD COLUMN due_date TEXT")
                db:execute("ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 2")
                return true
            end)

            down(function(db)
                -- SQLite < 3.35 cannot DROP COLUMN; no-op is acceptable
                return true
            end)
        end)
    end)
end)
