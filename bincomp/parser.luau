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

local parser = {}
local parser_meta = {}
parser_meta.__index = parser

function parser.new(source: string): types.Parser
    local self = {}
    self.token_stream = lexer.new():begin(source):stream()
    return (setmetatable(self, parser_meta) :: any) :: types.Parser
end

return parser