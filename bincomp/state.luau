local types = require("types")
local parser = require("parser")

local state = {}

local state_meta = {}
state_meta.__index = state

function state.new(): types.State
    return (setmetatable({}, state_meta) :: any) :: types.State
end

function state.define(definition_: string)
    local definition = parser.new(definition_)
end

return state