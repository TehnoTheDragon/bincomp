local function print_table(t, s)
    s = s or ""
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

type Token = {
    kind: string,
    value: any,
}

local function tokenize_definition(definition: string): {Token}
    local tokens = {}
    local function add_token(kind: string, value: any)
        table.insert(tokens, {kind = kind, value = value})
    end

    local current = 1
    local character = definition:sub(current, current)
    local function advance(expect: string?)
        local previous = character
        current += 1
        character = definition:sub(current, current)
        if expect and character ~= expect then
            add_token('error', `'{expect}' expected, got '{character}' at {current}`)
            current = #definition
        end
        return previous
    end
    local function skip_whitespaces()
        while character:match('%s') do
            advance()
        end
    end

    while current <= #definition do
        if character:match('%s') then
            skip_whitespaces(); continue
        end
        
        if character == '{' then
            add_token('meta_start', advance())
        elseif character == '}' then
            add_token('meta_end', advance())
        elseif character == '[' then
            add_token('array_start', advance())
        elseif character == ']' then
            add_token('array_end', advance())
        elseif character == ':' then
            add_token('colon', advance())
        elseif character == ',' then
            add_token('comma', advance())
        elseif character == '(' then
            add_token('list_start', advance())
        elseif character == ')' then
            add_token('list_end', advance())
        elseif character == '@' then
            add_token('external', advance())
        elseif character:match('[a-zA-Z_]') then
            local name = ''
            while character:match('[a-zA-Z0-9_]') do
                name ..= character
                advance()
            end
            add_token('name', name)
        elseif character:match('[\-0-9]') then
            local number = ''
            if character == '-' then
                advance()
                number = '-'
            end
            while character:match('[0-9]') do
                number ..= character
                advance()
            end
            if character == '.' then
                advance()
                number ..= '.'
                while character:match('[0-9]') do
                    number ..= character
                    advance()
                end
                add_token('number', tonumber(number))
            else
                add_token('integer', tonumber(number))
            end
        else
            add_token('error', `unexpected character '{character}' at {current}`)
            advance()
        end
    end
    add_token('eos', nil)

    return tokens
end

local function parse_definition(definition: string): types.Struct
    local tokens = tokenize_definition(definition)
    
    local current = 1
    local token = tokens[current]
    local function advance(expect: string?)
        local previous = token
        current += 1
        token = tokens[current]
        if expect and previous.kind ~= expect then
            error(`'{expect}' expected, got '{previous.kind}'`, 2)
        end
        return previous.value
    end
    local function isa(kind: string)
        return tokens[current].kind == kind
    end
    local function parse_list()
        local list = {}

        advance('list_start')
        while not isa('list_end') do
            table.insert(list, advance())
            if not isa('comma') then
                break
            end
            advance('comma')
        end
        advance('list_end')

        return list
    end
    local function parse_meta()
        local meta = {}

        advance('meta_start')
        while not isa('meta_end') do
            local key = advance('name')
            advance('colon')
            local value
            if isa('list_start') then
                value = parse_list()
            elseif isa('meta_start') then
                value = parse_meta()
            else
                value = advance()
            end
            meta[key] = value
        end
        advance('meta_end')
        
        return meta
    end
    local function parse_type()
        local array_lengths = {}
        if isa('array_start') then
            advance('array_start')
            local type, _array_length = parse_type()
            if _array_length then
                array_lengths = _array_length
            end
            if isa('comma') then
                advance('comma')
                local length = advance('integer')
                if length < 1 then
                    error(`array length must be greater than 0, got {length}`, 2)
                end
                table.insert(array_lengths, length)
            else
                error(`missing array length`, 2)
            end
            advance('array_end')
            local lengths = {}
            for i = #array_lengths, 1, -1 do
                table.insert(lengths, array_lengths[i])
            end
            return type, lengths
        else
            return advance('name')
        end
    end

    local struct: types.Struct = ({} :: any)

    local struct_field_counter = 0
    while current <= #tokens and not isa('eos') do
        local meta = {}
        local is_external_symbol = false
        local name = advance('name')

        advance('colon')

        if isa('external') then
            is_external_symbol = true
            advance('external')
        end

        local type, array_length = parse_type()

        if isa('meta_start') then
            meta = parse_meta()
        end

        local field: types.StructField = {
            name = name,
            type = type,
            external = is_external_symbol,
            array = array_length,
            meta = meta,
            index = struct_field_counter,
        }
        table.insert(struct, field)
        struct_field_counter += 1

        if isa('eos') then
            break
        end
        advance('comma')
    end

    return struct
end

local function has_field(self: types.Struct, name: string): boolean
    return self.fields[name] ~= nil
end

local function constructor(self: types.Struct, definition: {any}): types.ByteBuffer
    local object = {}
    local size = 0
    
    for _, field in self.fields do
        local name = field.name
        assert(definition[field.name], `Field '{field.name}' is not defined in '{self.name}'`)
        
        local def = definition[field.name]
        local item = {}
        item._id = field.index
        if field.external then
            item.external = true
            item.offset = size
            item.size = def:length()
            size += item.size
        else
            local field_size = 0
            if field.type == "str" then
                field_size = types.count_bytes_leb128(#def) + #def
            else
                field_size = types.type_to_size(field.type) / 8
            end
            item.offset = size
            if field.array then
                local total_length = 1
                for _, length in field.array do
                    total_length *= length
                end
                size += total_length * field_size
            else
                size += field_size
            end
            item.size = field_size
        end
        item.value = def
        item.type = field.type
        item.array = field.array
        item.meta = field.meta
        item.name = name
        table.insert(object, item)
    end
    table.sort(object, function(a, b) return a._id < b._id end)

    local instance = bytebuffer.new(size)

    local function write(item, offset, value)
        if item.external then
            instance:writebytes(offset, value:tostring())
        else
            if item.type == "str" then
                instance:writeprefixstring(offset, value)
            else
                instance[`write{item.type}`](instance, offset, value)
            end
        end
    end

    local function iterate_ndim_array(array, dimensions: {number}, fn: (index: number, value: any) -> ())
        local offset = 0
        local function iter(array, n, ...: number)
            if #{...} == 0 then
                for index, value in array do
                    fn(offset + index, value)
                end
                offset += #array
            else
                for i = 1, n do
                    iter(array[i], ...)
                end
            end
        end
        iter(array, table.unpack(dimensions))
    end

    for _, item in object do
        if item.array then
            local offset = item.offset
            local array = item.value
            local dimensions = item.array
            iterate_ndim_array(array, dimensions, function(index: number, value: any)
                write(item, offset + index - 1, value)
                offset += types.type_to_size(item.type) / 8 - 1
            end)
        else
            write(item, item.offset, item.value)
        end
    end

    return instance
end

local function construct_from_binary(self: types.Struct, binary: types.ByteBuffer)
    local object = {}
    local cursor = 0

    local function read(field)
        local data
        local type = field.type

        if field.external then
            local external = self.externals[type]
            data = external * binary:slice(cursor, external.size_in_bytes)
            cursor += external.size_in_bytes
        else
            if type == "str" then
                data = binary:readprefixstring(cursor)
                cursor += types.count_bytes_leb128(#data) + #data
            else
                local size = types.type_to_size(type) / 8
                data = binary[`read{type}`](binary, cursor)
                cursor += size
            end
        end

        return data
    end

    local function read_array(field)
        local dimensions = field.array

        local function read_dimension(index: number)
            if index > #dimensions then
                return read(field)
            else
                local sub_array = {}
                local dim_size = dimensions[index]

                for i = 1, dim_size do
                    sub_array[i] = read_dimension(index + 1)
                end

                return sub_array
            end
        end

        return read_dimension(1)
    end

    for _, field in self.fields do
        local name = field.name
        local array = field.array
        
        if array then
            object[name] = read_array(field)
        else
            object[name] = read(field)
        end
    end
    return object
end

return function(definition: {})
    local fields = parse_definition(definition[1])
    local self = {
        name = definition[2],
        fields = fields,
        externals = {},
        size_in_bytes = 0,
    }
    for _, external in definition[3] or {} do
        self.externals[external.name] = external
    end
    for _, field in fields do
        if field.external then
            local external = self.externals[field.type]
            if not external then
                error(`External type '{field.type}' is not defined in '{self.name}'`, 2)
            end
            self.size_in_bytes += external.size_in_bytes
        else
            local bits = types.type_to_size(field.type)
            if not bits then
                error(`Type '{field.type}' has undefined size`, 2)
            end
            local bytes = bits / 8
            if field.array then
                local total_length = 1
                for _, length in field.array do
                    total_length *= length
                end
                self.size_in_bytes += total_length * bytes
            else
                self.size_in_bytes += bytes
            end
        end
    end
    setmetatable(self, {
        __call = constructor,
        __mul = construct_from_binary,
        __tostring = function(self: types.Struct)
            return `{self.name}: {self.size_in_bytes} bytes`
        end,
    })
    return self
end
