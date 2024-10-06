local types = require("types")

local bytebuffer = {}
local bytebuffer_meta = {}
bytebuffer_meta.__index = bytebuffer

function bytebuffer.new(size_in_bytes: number): types.ByteBuffer
    return bytebuffer.from_buffer(buffer.create(size_in_bytes))
end

function bytebuffer.from_buffer(buffer: buffer): types.ByteBuffer
    return (setmetatable({[0] = buffer}, bytebuffer_meta) :: any) :: types.ByteBuffer
end

function bytebuffer.from_bytes(bytes: string): types.ByteBuffer
    return bytebuffer.from_buffer(buffer.fromstring(bytes))
end

function bytebuffer.writeleb128u32(self: types.ByteBuffer, offset: number, value: number)
    local dt = offset
    while value ~= 0 do
        local byte = bit32.band(value, 0x7f)
        value = bit32.rshift(value, 7)
        if value ~= 0 then
            byte = bit32.bor(byte, 0x80)
        end
        buffer.writeu8(self[0], offset, byte)
        offset += 1
    end
    return offset - dt
end

function bytebuffer.writeleb128i32(self: types.ByteBuffer, offset: number, value: number)
    local more = true
    local negative = value < 0
    local size = 64
    local dt = offset
    while more do
        local byte = bit32.band(value, 0x7f)
        value = bit32.rshift(value, 7)
        if negative then
            value = bit32.bor(value, bit32.lshift(bit32.bnot(0), size - 7))
        end
        if (value == 0 and bit32.band(byte, 0x40) == 0) or (value == -1 and bit32.band(byte, 0x40) ~= 0) then
            more = false
        else
            byte = bit32.bor(byte, 0x80)
        end
        buffer.writeu8(self[0], offset, byte)
        offset += 1
    end
    return offset - dt
end

function bytebuffer.writestring(self: types.ByteBuffer, offset: number, value: string, count: number?)
    buffer.writestring(self[0], offset, value, count)
end

function bytebuffer.writeprefixstring(self: types.ByteBuffer, offset: number, value: string)
    local size = self:writeleb128u32(offset, #value)
    self:writebytes(offset + size, value)
end

function bytebuffer.writebytes(self: types.ByteBuffer, offset: number, value: string)
    buffer.writestring(self[0], offset, value)
end

function bytebuffer.readleb128u32(self: types.ByteBuffer, offset: number)
    local result = 0
    local shift = 0
    local count = 0
    while true do
        local byte = buffer.readu8(self[0], offset)
        result = bit32.bor(result, bit32.lshift(bit32.band(byte, 0x7f), shift))
        count += 1
        if bit32.band(byte, 0x80) == 0 then
            break
        end
        shift += 7
        offset += 1
    end
    return result, count
end

function bytebuffer.readleb128i32(self: types.ByteBuffer, offset: number)
    local result = 0
    local shift = 0
    local count = 1
    while true do
        local byte = buffer.readu8(self[0], offset)
        result = bit32.bor(result, bit32.lshift(bit32.band(byte, 0x7f), shift))
        shift += 7
        offset += 1
        count += 1
        if bit32.band(byte, 0x80) == 0 then
            if shift < 32 and bit32.band(byte, 0x40) ~= 0 then
                return bit32.bor(result, bit32.lshift(bit32.bnot(0), shift)), count
            end
            if result >= 0x80000000 then
                result -= 0x100000000
            end
            return result, count
        end
    end
end

function bytebuffer.readstring(self: types.ByteBuffer, offset: number, count: number)
    return buffer.readstring(self[0], offset, count)
end

function bytebuffer.readprefixstring(self: types.ByteBuffer, offset: number)
    local length, size = self:readleb128u32(offset)
    return buffer.readstring(self[0], offset + size, length)
end

function bytebuffer.readbytes(self: types.ByteBuffer, offset: number, count: number)
    return buffer.readstring(self[0], offset, count)
end

function bytebuffer.tostring(self: types.ByteBuffer)
    return buffer.tostring(self[0])
end

function bytebuffer.display(self: types.ByteBuffer)
    local bytes = self:tostring()
    local m = ""
    for i = 1, #bytes do
        m ..= string.format(`%02x `, bytes:sub(i, i):byte())
        local c = math.min(#bytes, 8)
        if i % c == 0 then
            m ..= "| "
            for j = i - c + 1, i do
                local x = bytes:sub(j, j)
                if x:byte() > 32 and x:byte() < 127 then
                    m ..= x
                else
                    m ..= "."
                end
            end
            if i < #bytes then
                m ..= "\n"
            end
        end
    end
    print(m)
end

function bytebuffer.length(self: types.ByteBuffer)
    return buffer.len(self[0])
end

function bytebuffer.slice(self: types.ByteBuffer, offset: number, length: number)
    return bytebuffer.from_bytes(self:readbytes(offset, length))
end

for _, datatype in {"u8", "u16", "u32", "i8", "i16", "i32", "f32", "f64"} do
    bytebuffer[`write{datatype}`] = function(self: types.ByteBuffer, offset: number, value: any)
        buffer[`write{datatype}`](self[0], offset, value)
    end

    bytebuffer[`read{datatype}`] = function(self: types.ByteBuffer, offset: number)
        return buffer[`read{datatype}`](self[0], offset)
    end
end

return bytebuffer