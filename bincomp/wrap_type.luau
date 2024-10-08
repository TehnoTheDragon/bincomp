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
local bytebuffer = require("bytebuffer")

local Type = {}
type Type = types.Type & typeof(Type)

function Type.pack(self: Type, definition: {any}): types.ByteBuffer
    local size = self.size_in_bytes
    local function calculate(def: {any})
        for k,v in def do
            if typeof(v) == "table" then
                calculate(v)
            elseif typeof(v) == "string" then
                size += #v
            end
        end
    end
    calculate(definition)
    
    local pack = bytebuffer.new(size)
    local cursor = 0

    local tuple: types.TypeTuple = self :: any
    local array: types.TypeArray = self :: any
    local vector: types.TypeVector = self :: any

    if tuple.tuple ~= nil then
        for index, type in tuple.tuple do
            local value = definition[index]
            if not value then error(`Tuple value by index {index} is not defined in constructor`, 3) end
            local typename = type.typename

            if typename == "str" then
                pack:writeprefixstring(cursor, value)
                cursor += types.count_bytes_leb128(#value) + #value
                continue
            elseif types.is_buildin_type(typename) then
                pack[`write{typename}`](pack, cursor, value)
                cursor += types.type_to_size_in_bytes(typename)
                continue
            end
    
            error(`Unsupported type for serialization '{typename}'`)
        end
    elseif array.size ~= nil then

    elseif array.holdtype ~= nil then

    else

    end

    return pack
end

function Type.unpack(self: Type, packed: types.ByteBuffer): {any}
    local pack = {}

    local tuple: types.TypeTuple = self :: any
    local array: types.TypeArray = self :: any
    local vector: types.TypeVector = self :: any

    local cursor = 0

    if tuple.tuple ~= nil then
        for index, type in tuple.tuple do
            local typename = type.typename

            if typename == "str" then
                local str = packed:readprefixstring(cursor)
                pack[index] = str
                cursor += types.count_bytes_leb128(#str) + #str
                continue
            elseif types.is_buildin_type(typename) then
                pack[index] = packed[`read{typename}`](packed, cursor)
                cursor += types.type_to_size_in_bytes(typename)
                continue
            end
    
            error(`Unsupported type for serialization '{typename}'`)
        end
    elseif array.size ~= nil then

    elseif array.holdtype ~= nil then

    else

    end

    return pack
end

local type_meta = {}

function type_meta.__index(self: types.Type, key: any)
    return Type[key]
end

function type_meta.__tostring(self: Type)
    return `Type {self.typename}({self.size_in_bytes} bytes)`
end

function type_meta.__call(self: Type, definition: {any})
    return self:pack(definition)
end

function type_meta.__mul(self: Type, definition: {any})
    return self:pack(definition)
end

function type_meta.__div(self: Type, packed: types.ByteBuffer)
    return self:unpack(packed)
end

return function(type_: types.TypeTuple): types.Type
    setmetatable(type_, type_meta)
    return (type_ :: any) :: types.Type
end
