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
