local types = require("types")

local function create_token(lexer: types.Lexer, kind: types.TokenKind, value: any): types.Token
    return { 
        kind = kind,
        value = value,
        location = {
            column = lexer.column,
            row = lexer.row,
            index = lexer.current,
        }
    } :: types.Token
end

local SINGLE_SYMBOL_TOKENS = table.freeze({
    ["+"] = "plus",
    ["-"] = "dash",
    ["/"] = "slash",
    ["*"] = "star",
    ["&"] = "ampersand",
    ["$"] = "money",
    ["%"] = "percent",
    ["@"] = "tail",
    ["!"] = "warning",
    ["."] = "dot",
    [","] = "comma",
    [":"] = "colon",
    [";"] = "semicolon",
    ["="] = "equal",
    ["~"] = "tilda",
    ["#"] = "hashtag",
    ["("] = "open_paren",
    [")"] = "close_paren",
    ["["] = "open_square",
    ["]"] = "close_square",
    ["<"] = "open_arrow",
    [">"] = "close_arrow",
    ["{"] = "open_curly",
    ["}"] = "close_curly",
})

local lexer = {}
local lexer_meta = {}
lexer_meta.__index = lexer

function lexer.new(): types.Lexer
    local self = {}
    self.current = 1
    self.column = 1
    self.row = 1
    self.length = 0
    self.source = nil
    self.character = nil
    return (setmetatable(self, lexer_meta) :: any) :: types.Lexer
end

function lexer.begin(self: types.Lexer, source: string): types.Lexer
    self.current = 1
    self.column = 1
    self.row = 1
    self.length = #source
    self.source = source
    self.character = source:sub(1, 1)
    return self
end

function lexer.is_end(self: types.Lexer)
    return self.current >= self.length
end

function lexer.stream(self: types.Lexer): () -> types.Token
    return function(): types.Token
        self:skip_all_those(" \n\t\r")
        if self:is_end() then
            return create_token(self, "_end")
        end

        if self.character == '-' or self:lookup():match("[0-9]") then
            local num = if self.character == '-' then "-" else ""
            while self.character:match("[0-9]") do
                num ..= self:advance()
            end
            if (self.character :: string) == '.' then -- bruh check ._.
                num ..= self:advance()
                while self.character:match("[0-9]") do
                    num ..= self:advance()
                end
                return create_token(self, "number", tonumber(num))
            end
            return create_token(self, "integer", tonumber(num))
        end

        local single_symbol_token = SINGLE_SYMBOL_TOKENS[self.character]
        if single_symbol_token then
            self:advance()
            return create_token(self, single_symbol_token)
        end

        if self.character:match("[a-zA-Z_]") then
            local word = self:advance()
            while self.character:match("[a-zA-Z0-9_]") do
                word ..= self:advance()
            end
            return create_token(self, "word", word)
        elseif self.character == '"' then
            local str = ""
            self:advance()
            while self.character ~= '"' do
                str ..= self:advance()
            end
            self:advance()
            return create_token(self, "string", str)
        end

        return create_token(self, "_undefined", self:advance())
    end
end

function lexer.advance(self: types.Lexer): string
    if self.current <= self.length then
        local previous = self.character
        self.current += 1
        self.character = self.source:sub(self.current, self.current)
        if self.character == '\n' then
            self.row = 1
            self.column += 1
        else
            self.row += 1
        end
        return previous
    end
    return '\0'
end

function lexer.lookup(self: types.Lexer, count: number?): string
    return self.source:sub(self.current, if count then count + self.current else self.current)
end

function lexer.lookup_for(self: types.Lexer, thing: string, jump_: number?): boolean
    local jump = jump_ or 0
    return self.source:sub(self.current + jump, self.current + jump + #thing) == thing
end

function lexer.skip_all_those(self: types.Lexer, those: string)
    while not self:is_end() and those:find(self.character, 1, true) ~= nil do
        self:advance()
    end
end

local parser = {}
local parser_meta = {}
parser_meta.__index = parser

function parser.new(source: string): types.Parser
    local self = {}
    self.token = nil
    self.token_stream = lexer.new():begin(source):stream()
    return (setmetatable(self, parser_meta) :: any) :: types.Parser
end

function parser.next(self: types.Parser): types.Token
    local token = self.token_stream()
    if token.kind == "_error" then
        error(token.value, -1)
    elseif token.kind == "_undefined" then
        error(`Undefined token type: '{token.value}'`, -1)
    end
    self.token = token
    return token
end

function parser.eat(self: types.Parser, expect_kind: types.TokenKind?): types.Token
    local previous = self.token
    if previous.kind ~= expect_kind and expect_kind ~= nil then
        error(`Unexpected token kind '{previous.kind}' expected '{expect_kind}' token kind`, 2)
    end
    self.token = self:next()
    return previous
end

function parser.isa(self: types.Parser, kind: types.TokenKind): boolean
    return self.token.kind == kind
end

function parser.parse(self: types.Parser, state): types.ParserResult
    local result: types.ParserResult = {
        symbols = {},
        data = {},
        tagged = {},
    }
    self:next()

    self:parse_state(result, state)
    while self.token.kind ~= "_end" do
        self:parse_state(result, state)
    end

    return result
end

function parser.parse_state(self: types.Parser, result: types.ParserResult, state)
    local token = self.token
    local processor: (self: types.Parser, result: types.ParserResult, state: {}) -> () = parser[`parse_kind_{token.kind}`]
    if processor then
        processor(self, result, state)
    else
        error(`No processor for token kind '{token.kind}' is found!`, 2)
    end
end

function parser.parse_type(self: types.Parser, result: types.ParserResult, state): types.Type
    local function get_type()
        if self:isa("open_paren") then
            local typeinfo: types.TypeTuple = {
                typename = "tuple",
                tags = {},
                meta = {},
                tuple = {},
            }
    
            self:eat()
            while true do
                table.insert(typeinfo.tuple, self:parse_type(result, state))
                if not self:isa("comma") then
                    break
                end
                self:eat("comma")
            end
            self:eat("close_paren")
    
            return typeinfo
        elseif self:isa("word") then
            return {
                typename = self:eat().value,
                tags = {},
                meta = {},
            } :: types.TypeInfo
        elseif self:isa("open_square") then
            self:eat("open_square")
    
            local typeinfo: types.TypeInfo = {
                typename = "array",
                tags = {},
                meta = {},
            }
    
            local holdtype = self:parse_type(result, state)
    
            if self:isa("comma") then
                self:eat("comma")
                local size = self:eat("integer").value
                local typeinfo_array: types.TypeArray = typeinfo :: types.TypeArray
                typeinfo_array.holdtype = holdtype
                typeinfo_array.size = size
    
                self:eat("close_square")
                return typeinfo_array
            else
                local typeinfo_vector: types.TypeVector = typeinfo :: types.TypeVector
                typeinfo_vector.typename = "vector"
                typeinfo_vector.holdtype = holdtype
    
                self:eat("close_square")
                return typeinfo_vector
            end
        else
            error(`Unsupported type for token(kind: '{self.token.kind}', value: '{self.token.value}')`)
        end
    end

    local type = get_type()
    state.item = type
    type.meta = self:parse_meta(result, state)
    type.tags = self:parse_tags(result, state)
    return type
end

function parser.parse_meta(self: types.Parser, result: types.ParserResult, state): {[any]: any}
    local meta = {}
    if self:isa("open_curly") then
        self:eat("open_curly")
        while not self:isa("close_curly") do
            local key = self:eat("word").value
            self:eat("colon")
            meta[key] = self:parse_value(result, state)

            if not self:isa("comma") then break end
            self:eat("comma")
        end
        self:eat("close_curly")
    end
    return meta
end

function parser.parse_tags(self: types.Parser, result: types.ParserResult, state): {string}
    local tags = {}
    while self:isa("hashtag") do
        self:eat()
        local tag = self:eat("word").value
        table.insert(tags, tag)

        local tagged = result.tagged[tag]
        if not tagged then
            result.tagged[tag] = {}
            tagged = result.tagged[tag]
        end
        table.insert(tagged, state.item)
    end
    return tags
end

function parser.parse_value(self: types.Parser, result: types.ParserResult, state): any
    if self:isa("string") then
        return self:eat().value
    elseif self:isa("word") then
        local value = self:eat().value
        if value == "true" then
            return true
        elseif value == "false" then
            return false
        end
        error(`Undefined value '{value}'`, 1)
    elseif self:isa("open_paren") then
        local list = {}
        self:eat("open_paren")
        while not self:isa("close_paren") do
            table.insert(list, self:parse_value(result, state))
            if not self:isa("comma") then break end
            self:eat("comma")
        end
        self:eat("close_paren")
        return list
    elseif self:isa("number") or self:isa("integer") then
        return self:eat().value
    end

    error(`Unsupported value type when parsed token(kind: '{self.token.kind}', value: '{self.token.value}')`, 1)
end

function parser.parse_kind_word(self: types.Parser, result: types.ParserResult, state)
    local identity = self:eat("word").value
    self:eat("colon")
    local type = self:eat("word").value
    
    local processor: (self: types.Parser, result: types.ParserResult, state: {}) -> () = parser[`parse_type_{type}`]
    if processor then
        state.identity = identity
        processor(self, result, state)
    else
        error(`No processor for type '{type}' is found!`, 2)
    end
end

function parser.parse_type_enum(self: types.Parser, result: types.ParserResult, state)
    local identity: string = state.identity
    
    local enum: types.Enum = { name = identity, items = {} }
    table.insert(result.data, enum)
    result.symbols[identity] = { symbol = identity, location = #result.data, kind = "enum" }

    self:eat("open_curly")

    local enum_item_index = 0
    while true do
        if self:isa("close_curly") then break end

        local identity = self:eat("word").value
        local field: types.EnumField = { name = identity, index = enum_item_index, type = nil }
        enum_item_index += 1

        if self:isa("colon") then
            self:eat("colon")
            field.type = self:parse_type(result, state)
        end

        enum.items[identity] = field
        
        if not self:isa("comma") then break end
        self:eat("comma")
    end

    self:eat("close_curly")
end

function parser.parse_type_struct(self: types.Parser, result: types.ParserResult, state)
    local identity: string = state.identity
    
    local struct: types.Struct = { name = identity, fields = {} }
    table.insert(result.data, struct)
    result.symbols[identity] = { symbol = identity, location = #result.data, kind = "struct" }

    self:eat("open_curly")

    while true do
        if self:isa("close_curly") then break end

        local identity = self:eat("word").value
        self:eat("colon")
        local type = self:parse_type(result, state)

        struct.fields[identity] = { name = identity, type = type }
        
        if not self:isa("comma") then break end
        self:eat("comma")
    end

    self:eat("close_curly")
end

return parser