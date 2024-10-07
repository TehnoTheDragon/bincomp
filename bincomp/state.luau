local function print_table<T>(t: {T}, s_: string?)
    local s = s_ or ""
    for k, v in t do
        if typeof(v) == "table" then
            print(`{s}{k}:`)
            print_table(v, s .. " ")
        else
            print(`{s}{k}: {v}`)
        end
    end
end

local types = require("types")
local parser = require("parser")
local validator = require("validator")

local state = {}

local state_meta = {}
state_meta.__index = state

function state.new(): types.State
    return (setmetatable({}, state_meta) :: any) :: types.State
end

function state.define(definition_: string)
    local definition = parser.new(definition_):parse({})
    validator.validate(definition, {})
end

return state