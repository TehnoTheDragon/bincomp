local types = require("types")

local validator = {}

function validator.validate(result: types.ParserResult, state)
    for _, symbol in result.symbols do
        state.symbol = symbol
        validator.validate_symbol(result, state)
    end
end

function validator.validate_symbol(result: types.ParserResult, state)
    local symbol: types.Symbol = state.symbol
    local object = result.data[symbol.location]
    state.object = object
    validator[`validate_{symbol.kind}`](result, state)
end

function validator.validate_enum(result: types.ParserResult, state)
    local enum: types.Enum = state.object
end

function validator.validate_struct(result: types.ParserResult, state)
    local struct: types.Struct = state.object
    for _, field in struct.fields do
        state.field = field
        validator.validate_field(result, state)
    end
end

function validator.validate_field(result: types.ParserResult, state)
    local field: types.Field = state.field
    state.type = field.type
    validator.validate_type(result, state)
end

function validator.validate_type(result: types.ParserResult, state)
    local type: types.Type = state.type
    local typename = type.typename
    if typename == "tuple" or typename == "vector" or typename == "array" then
        validator[`validate_type_{typename}`](result, state)
        return
    elseif not table.find(types.builtin_datatypes, typename) then
        if not result.symbols[typename] then
            error(`No symbol '{typename}' is found`, 6)
        end
    end
end

function validator.validate_type_tuple(result: types.ParserResult, state)
    local tuple: types.TypeTuple = state.type
    for _, type in tuple.tuple do
        state.type = type
        validator.validate_type(result, state)
    end
end

function validator.validate_type_vector(result: types.ParserResult, state)
    local vector: types.TypeVector = state.type
    state.type = vector.holdtype
    validator.validate_type(result, state)
end

function validator.validate_type_array(result: types.ParserResult, state)
    local array: types.TypeArray = state.type
    state.type = array.holdtype
    validator.validate_type(result, state)
end

return validator