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

local validator = {}

function validator.set_size(result: types.StateDefinition, name: string, size: number, state)
    if result.sizes[name] == nil then
        result.sizes[name] = size
    end
end

function validator.get_size(result: types.StateDefinition, name: string, state)
    local v = result.sizes[name]
    if not v then
        state.symbol = result.symbols[name]
        validator.validate_symbol(result, state)
        v = result.sizes[name]
        if not v then
            error(`Size is not mapped for '{name}'`)
        end
    end
    return v
end

function validator.validate(result: types.StateDefinition, state)
    for _, symbol in result.symbols do
        state.symbol = symbol
        validator.validate_symbol(result, state)
    end
end

function validator.validate_symbol(result: types.StateDefinition, state)
    local symbol: types.Symbol = state.symbol
    local object = result.data[symbol.address]
    state.object = object
    validator.set_size(result, symbol.symbol, object.size_in_bytes, state)
    validator[`validate_kind_{symbol.kind}`](result, state)
end

function validator.validate_kind_enum(result: types.StateDefinition, state)
    local enum: types.Enum = state.object
end

function validator.validate_kind_struct(result: types.StateDefinition, state)
    local struct: types.Struct = state.object
    for _, field in struct.fields do
        state.field = field
        validator.validate_field(result, state)
        struct.size_in_bytes += validator.get_size(result, field.type.typename, state)
    end
end

function validator.validate_kind_type(result: types.StateDefinition, state)
    local type: types.Type = state.object
    state.type = type
    validator.validate_type(result, state)
end

function validator.validate_field(result: types.StateDefinition, state)
    local field: types.Field = state.field
    state.type = field.type
    validator.validate_type(result, state)
end

function validator.validate_type(result: types.StateDefinition, state)
    local type: types.Type = state.type
    local typename = type.typename
    if typename == "tuple" or typename == "vector" or typename == "array" then
        validator[`validate_type_{typename}`](result, state)
    elseif not table.find(types.builtin_datatypes, typename) then
        if not result.symbols[typename] then
            error(`symbol '{typename}' is not defined!`, 6)
        end
    else
        result.sizes[typename] = type.size_in_bytes
    end
end

function validator.validate_type_tuple(result: types.StateDefinition, state)
    local tuple: types.TypeTuple = state.type
    for _, type in tuple.tuple do
        state.type = type
        validator.validate_type(result, state)
    end
end

function validator.validate_type_vector(result: types.StateDefinition, state)
    local vector: types.TypeVector = state.type
    state.type = vector.holdtype
    validator.validate_type(result, state)
end

function validator.validate_type_array(result: types.StateDefinition, state)
    local array: types.TypeArray = state.type
    state.type = array.holdtype
    validator.validate_type(result, state)
    
    -- calculates total size and gets datatype size in bytes
    local function get_type_size(x: types.TypeInfo): number
        local y: types.TypeArray = x :: types.TypeArray
        if y.holdtype then
            return get_type_size(y.holdtype)
        else
            return x.size_in_bytes
        end
    end
    if array.holdtype.typename == "array" then
        array.size *= (array.holdtype :: types.TypeArray).size
    end
    array.size_in_bytes = array.size * get_type_size(array)
end

return validator