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

local struct = {}
type Struct = types.Struct & typeof(struct)

function struct.pack(self: Struct, definition: {any}): types.ByteBuffer
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

    for _, field in self.fields do
        local value = definition[field.name]
        if not value then error(`Field '{field.name}' is not defined in constructor`, 3) end
        local typename = field.type.typename
        
        if typename == "str" then
            pack:writeprefixstring(cursor, value)
            cursor += types.count_bytes_leb128(#value) + #value
            continue
        else
            local ext = self.symbols[typename]
            local encoded = ext * value
            if encoded then
                pack:writebytes(cursor, encoded:tostring())
                cursor += encoded:length()
                continue
            end
        end

        error(`Unsupported type for serialization '{typename}'`)
    end

    return pack
end

function struct.unpack(self: Struct, packed: types.ByteBuffer): {any}
    local pack = {}

    local cursor = 0

    for _, field in self.fields do
        local typename = field.type.typename
        
        if typename == "str" then
            local str = packed:readprefixstring(cursor)
            pack[field.name] = str
            cursor += types.count_bytes_leb128(#str) + #str
            continue
        elseif types.is_buildin_type(typename) then
            pack[field.name] = packed[`read{typename}`](packed, cursor)
            cursor += types.type_to_size_in_bytes(typename)
            continue
        else
            local ext = self.symbols[typename]
            local decoded = ext / packed:slice(cursor, ext.size_in_bytes)
            cursor += ext.size_in_bytes
            pack[field.name] = decoded
        end
    end

    return pack
end

local struct_meta = {}

function struct_meta.__index(self: types.Struct, key: any)
    return struct[key]
end

function struct_meta.__tostring(self: Struct)
    return `struct {self.name}({self.size_in_bytes} bytes)`
end

function struct_meta.__call(self: Struct, definition: {any})
    return self:pack(definition)
end

function struct_meta.__mul(self: Struct, definition: {any})
    return self:pack(definition)
end

function struct_meta.__div(self: Struct, packed: types.ByteBuffer)
    return self:unpack(packed)
end

return function(struct_: types.Struct): types.Struct
    setmetatable(struct_, struct_meta)
    return (struct_ :: any) :: types.Struct
end
