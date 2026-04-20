local http = require("http")
local json = require("json")
local models = require("models")

local function handler()
    local res = http.response()
    local req = http.request()
    if not res or not req then
        return nil, "Failed to get HTTP context"
    end

    local all_models = models.get_all()

    local formatted_models = {}
    for _, model in ipairs(all_models) do
        local is_embedding = (model.type == "llm.embedding")
        local can_generate = false

        if model.capabilities then
            for _, capability in ipairs(model.capabilities) do
                if capability == "generate" or capability == "tool_use" then
                    can_generate = true
                    break
                end
            end
        end

        if model.handlers and model.handlers.generate then
            can_generate = true
        end

        if is_embedding or not can_generate then
            goto continue
        end

        local provider = "unknown"
        if model.providers and #model.providers > 0 then
            local provider_match = model.providers[1].id:match("wippy%.llm%.([^:]+):")
            if provider_match then
                provider = provider_match
            end
        elseif model.handlers and model.handlers.embeddings then
            local provider_match = model.handlers.embeddings:match("wippy%.llm%.([^:]+):")
            if provider_match then
                provider = provider_match
            end
        end

        table.insert(formatted_models, {
            name = model.name,
            title = model.title or model.name,
            description = model.description or "",
            provider = provider,
        })

        ::continue::
    end

    res:set_content_type(http.CONTENT.JSON)
    res:set_status(http.STATUS.OK)
    res:write_json({
        success = true,
        count = #formatted_models,
        models = formatted_models,
    })
end

return { handler = handler }
