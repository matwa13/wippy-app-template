local flow = require("flow")

-- Exit schemas are defined here (not in the agent YAML arena block) because the
-- flow agent node reads arena config from the DSL call site, not the registry.
local attractions_exit_schema = {
    type = "object",
    required = { "attractions" },
    additionalProperties = false,
    properties = {
        attractions = {
            type = "array",
            minItems = 6,
            maxItems = 12,
            items = {
                type = "object",
                required = { "name", "description", "typical_duration_hours", "constraints" },
                additionalProperties = false,
                properties = {
                    name = { type = "string" },
                    description = { type = "string" },
                    typical_duration_hours = { type = "number" },
                    constraints = { type = "array", items = { type = "string" } },
                },
            },
        },
    },
}

local packing_exit_schema = {
    type = "object",
    required = { "packing" },
    additionalProperties = false,
    properties = {
        packing = {
            type = "array",
            items = {
                type = "object",
                required = { "category", "items" },
                additionalProperties = false,
                properties = {
                    category = { type = "string" },
                    items = { type = "array", items = { type = "string" } },
                },
            },
        },
    },
}

local iata_exit_schema = {
    type = "object",
    required = { "origin_iata", "destination_iata" },
    additionalProperties = false,
    properties = {
        origin_iata      = { type = { "string", "null" }, pattern = "^$|^[A-Za-z]{3}$" },
        destination_iata = { type = { "string", "null" }, pattern = "^$|^[A-Za-z]{3}$" },
    },
}

local itinerary_exit_schema = {
    type = "object",
    required = { "itinerary" },
    additionalProperties = false,
    properties = {
        itinerary = {
            type = "array",
            items = {
                type = "object",
                required = { "date", "attraction_name", "time_slot",
                             "estimated_duration_hours", "description", "constraints" },
                additionalProperties = false,
                properties = {
                    date = { type = "string" },
                    attraction_name = { type = "string" },
                    time_slot = { type = "string", enum = { "morning", "afternoon", "evening" } },
                    estimated_duration_hours = { type = "number" },
                    description = { type = "string" },
                    constraints = { type = "array", items = { type = "string" } },
                },
            },
        },
    },
}

local function build_and_start(input)
    -- input: { trip_id, user_id, destination, origin, start_date, end_date }
    --
    -- NOTE on join gates: :func() nodes fire *per edge arrival* — they don't
    -- wait for all inbound edges before executing. Any :func() that needs
    -- multiple discriminators (e.g. agent output + trip context) must be
    -- preceded by a :join() that blocks until every required input has arrived.
    -- Join with output_mode="object" emits { default=..., context=... } which
    -- becomes the func's unwrapped single-edge input — keeping the same shape
    -- the handler already reads.

    return flow.create()
        :with_title("Trip plan: " .. input.destination)
        :with_metadata({ trip_id = input.trip_id, user_id = input.user_id })
        :with_input(input)

        :func("app.trips:normalize_input"):as("normalize_input")
        -- fan out: each research/linker branch gets the normalized trip details.
        :to("attractions_research", "default")
        :to("packing_research", "default")
        :to("iata_resolver", "default")
        -- context fan out: trip_id/user_id never pass through agents because the
        -- agents' exit_schema uses additionalProperties:false, so deliver them
        -- to the join-gates that guard each persist/notify func.
        :to("save_attractions_gate", "context")
        :to("save_packing_gate", "context")
        :to("save_iata_resolver_gate", "context")
        :to("flights_linker_gate", "context")
        :to("save_itinerary_gate", "context")
        :to("build_task_payloads_gate", "context")
        :to("persist_tasks_gate", "context")
        -- Synthesizer needs trip dates to schedule attractions; the central join
        -- only carries agent outputs, so feed the normalized context directly.
        :to("join", "context")

        :agent("app.agents:trip_attractions_researcher", {
            arena = {
                max_iterations = 4,
                exit_schema = attractions_exit_schema,
            },
        }):as("attractions_research")
        :to("save_attractions_gate", "default")

        :join({
            inputs = { required = { "default", "context" } },
            output_mode = "object",
        }):as("save_attractions_gate")
        :to("save_attractions", "default")

        :func("app.trips:save_attractions"):as("save_attractions")
        :to("join", "attractions")

        :agent("app.agents:trip_packing_researcher", {
            arena = {
                max_iterations = 4,
                exit_schema = packing_exit_schema,
            },
        }):as("packing_research")
        :to("save_packing_gate", "default")

        :join({
            inputs = { required = { "default", "context" } },
            output_mode = "object",
        }):as("save_packing_gate")
        :to("save_packing", "default")

        :func("app.trips:save_packing"):as("save_packing")
        :to("join", "packing")

        :agent("app.agents:trip_iata_resolver", {
            arena = {
                max_iterations = 2,
                exit_schema = iata_exit_schema,
            },
        }):as("iata_resolver")
        :to("save_iata_resolver_gate", "default")

        :join({
            inputs = { required = { "default", "context" } },
            output_mode = "object",
        }):as("save_iata_resolver_gate")
        :to("save_iata_resolver", "default")

        :func("app.trips:save_iata_resolver"):as("save_iata_resolver")
        :to("flights_linker_gate", "default")

        :join({
            inputs = { required = { "default", "context" } },
            output_mode = "object",
        }):as("flights_linker_gate")
        :to("flights_linker", "default")

        :func("app.trips:flights_linker"):as("flights_linker")
        :to("join", "flights")

        :join({
            inputs = { required = { "attractions", "packing", "flights", "context" } },
            output_mode = "object",
        }):as("join")
        :to("itinerary_synthesize", "default")
        :to("build_task_payloads_gate", "support")

        :agent("app.agents:trip_itinerary_synthesizer", {
            arena = {
                max_iterations = 4,
                exit_schema = itinerary_exit_schema,
            },
        }):as("itinerary_synthesize")
        :to("save_itinerary_gate", "default")

        :join({
            inputs = { required = { "default", "context" } },
            output_mode = "object",
        }):as("save_itinerary_gate")
        :to("save_itinerary", "default")

        :func("app.trips:save_itinerary"):as("save_itinerary")
        :to("build_task_payloads_gate", "default")

        :join({
            inputs = { required = { "default", "context", "support" } },
            output_mode = "object",
        }):as("build_task_payloads_gate")
        :to("build_task_payloads", "default")

        :func("app.trips:build_task_payloads"):as("build_task_payloads")
        :to("persist_tasks_gate", "default")

        :join({
            inputs = { required = { "default", "context" } },
            output_mode = "object",
        }):as("persist_tasks_gate")
        :to("persist_tasks", "default")

        :func("app.trips:persist_tasks"):as("persist_tasks")
        :to("@success")

        :error_to("@fail")
        :start()
end

return { build_and_start = build_and_start }
