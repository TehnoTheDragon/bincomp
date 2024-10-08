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
    return (setmetatable({
        definition = {
            tagged = {},
            symbols = {},
            data = {},
        }
    }, state_meta) :: any) :: types.State
end

function state.define(self: types.State, definition_: string)
    local definition = parser.new(definition_):parse({})
    for k,v in definition.data do
        self.definition.data[k]=v
    end
    for k,v in definition.tagged do
        if self.definition.tagged[k] then
            table.move(definition.tagged[k], 1, #definition.tagged[k], #self.definition.tagged[k] + 1, self.definition.tagged[k])
        else
            self.definition.tagged[k] = v
        end
    end
    for k,v in definition.symbols do
        if self.definition.symbols[k] then
            error(`Redefined symbol '{k}'`)
        end
        self.definition.symbols[k]=v
    end
end

function state.validate(self: types.State)
    validator.validate(self.definition, {})
end

return state