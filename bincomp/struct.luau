local types = require("types")
local bytebuffer = require("bytebuffer")

local struct = {}
type Struct = types.Struct & typeof(struct)

function struct.pack(self: Struct, definition: {any}): types.ByteBuffer
    local pack = bytebuffer.new(1)

    return pack
end

function struct.unpack(self: Struct, packed: types.ByteBuffer): {any}
    return {}
end

local struct_meta = {}

function struct_meta.__index(self: types.Struct, key: any)
    return struct[key]
end

function struct_meta.__tostring(self: Struct)
    return `struct {self.name}`
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
