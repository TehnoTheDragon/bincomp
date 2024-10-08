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

local function assert_dirty(self)
    if self.dirty then error(`State is dirty, consider :validate first before using any get (if ignored will lead to the fatal errors)`, 4) end
end

local types = require("types")
local parser = require("parser")
local validator = require("validator")
local wrap_struct = require("wrap_struct")
local wrap_type = require("wrap_type")

local state = {}

local state_meta = {}
state_meta.__index = state

function state.new(): types.State
    return (setmetatable({
        definition = {
            tagged = {},
            symbols = {},
            data = {},
            sizes = {},
        },
        dirty = false,
    }, state_meta) :: any) :: types.State
end

function state.define(self: types.State, definition_: string)
    local definition = parser.new(definition_):parse({})
    for k,v in definition.data do
        if (v :: types.Struct).symbols ~= nil then
            for symbol, _ in (v :: types.Struct).symbols do
                local address = (self.definition.symbols[symbol] or definition.symbols[symbol]).address
                ;(v :: types.Struct).symbols[symbol] = self.definition.data[address] or definition.data[address]
            end
        end
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
        local object = self.definition.data[v.address]
        assert(object, `Undefined symbol '{v.symbol}'`)

        if v.kind == "struct" then
            wrap_struct(object)
        elseif v.kind == "enum" then

        elseif v.kind == "type" then
            wrap_type(object)
        end
    end
    (self :: any).dirty = true
end

function state.validate(self: types.State)
    validator.validate(self.definition, {})
    ;(self :: any).dirty = false
end

function state.get_symbol(self: types.State, name: string): types.Symbol
    assert_dirty(self)
    local symbol = self.definition.symbols[name]
    assert(symbol, `Symbol '{name}' is not defined!`)
    return symbol
end

function state.struct(self: types.State, name: string): types.Struct
    local symbol = self:get_symbol(name)
    assert(symbol.kind == "struct", `'{name}' is not struct`, 2)
    return self.definition.data[symbol.address] :: any
end

function state.enum(self: types.State, name: string): types.Enum
    local symbol = self:get_symbol(name)
    assert(symbol.kind == "enum", `'{name}' is not enum`, 2)
    return self.definition.data[symbol.address] :: any
end

function state.type(self: types.State, name: string): types.Type
    local symbol = self:get_symbol(name)
    assert(symbol.kind == "type", `'{name}' is not type`, 2)
    return self.definition.data[symbol.address] :: any
end

return state