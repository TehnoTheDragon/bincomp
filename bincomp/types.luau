export type ByteBuffer = {
    writeu8: (self: ByteBuffer, offset: number, value: number) -> (),
    writeu16: (self: ByteBuffer, offset: number, value: number) -> (),
    writeu32: (self: ByteBuffer, offset: number, value: number) -> (),
    writei8: (self: ByteBuffer, offset: number, value: number) -> (),
    writei16: (self: ByteBuffer, offset: number, value: number) -> (),
    writei32: (self: ByteBuffer, offset: number, value: number) -> (),
    writef32: (self: ByteBuffer, offset: number, value: number) -> (),
    writef64: (self: ByteBuffer, offset: number, value: number) -> (),
    writeleb128u32: (self: ByteBuffer, offset: number, value: number) -> (number),
    writeleb128i32: (self: ByteBuffer, offset: number, value: number) -> (number),
    writestring: (self: ByteBuffer, offset: number, value: string, count: number?) -> (),
    writeprefixstring: (self: ByteBuffer, offset: number, value: string) -> (),
    writebytes: (self: ByteBuffer, offset: number, value: string) -> (),
    
    readu8: (self: ByteBuffer, offset: number) -> number,
    readu16: (self: ByteBuffer, offset: number) -> number,
    readu32: (self: ByteBuffer, offset: number) -> number,
    readi8: (self: ByteBuffer, offset: number) -> number,
    readi16: (self: ByteBuffer, offset: number) -> number,
    readi32: (self: ByteBuffer, offset: number) -> number,
    readf32: (self: ByteBuffer, offset: number) -> number,
    readf64: (self: ByteBuffer, offset: number) -> number,
    readleb128u32: (self: ByteBuffer, offset: number) -> (number, number),
    readleb128i32: (self: ByteBuffer, offset: number) -> (number, number),
    readstring: (self: ByteBuffer, offset: number, count: number) -> string,
    readprefixstring: (self: ByteBuffer, offset: number) -> string,
    readbytes: (self: ByteBuffer, offset: number, count: number) -> string,

    tostring: (self: ByteBuffer) -> string,
    display: (self: ByteBuffer) -> (),
    length: (self: ByteBuffer) -> number,
    slice: (self: ByteBuffer, offset: number, count: number) -> ByteBuffer,

    -- Extra Types

    writeu64: (self: ByteBuffer, offset: number, low: number, high: number) -> ByteBuffer,
    writei64: (self: ByteBuffer, offset: number, low: number, high: number) -> ByteBuffer,
    writef16: (self: ByteBuffer, offset: number, value: number) -> ByteBuffer,
    writef128: (self: ByteBuffer, offset: number, low: number, high: number) -> ByteBuffer,
    writeleb128u64: (self: ByteBuffer, offset: number, low: number, high: number) -> (number),
    writeleb128i64: (self: ByteBuffer, offset: number, low: number, high: number) -> (number),
}

export type TokenKind = "_error"
                      | "_undefined"
                      | "_end"
                      | "number"
                      | "integer"
                      | "word"
                      | "string"
                      | "plus"
                      | "dash"
                      | "slash"
                      | "star"
                      | "ampersand"
                      | "money"
                      | "percent"
                      | "tail"
                      | "warning"
                      | "dot"
                      | "comma"
                      | "colon"
                      | "semicolon"
                      | "equal"
                      | "tilda"
                      | "hashtag"
                      | "open_paren"
                      | "close_paren"
                      | "open_square"
                      | "close_square"
                      | "open_arrow"
                      | "close_arrow"
                      | "open_curly"
                      | "close_curly"
export type Token = {
    kind: TokenKind,
    value: any,
    location: {
        column: number,
        row: number,
        index: number,
    }
}

export type Lexer = {
    current: number,
    column: number,
    row: number,
    length: number,
    source: string,
    character: string,

    begin: (Lexer, source: string) -> Lexer, -- all begins here, yes
    is_end: (Lexer) -> boolean, -- it's true whenever .current is >= than .length
    stream: (Lexer) -> () -> Token, -- a function that return a token, I think it will be more memory efficient to not store list of tokens but rather use lazy way
    advance: (Lexer) -> string, -- returns previous character
    lookup: (Lexer, count: number?) -> string, -- returns next character but not advance the cursor
    lookup_for: (Lexer, thing: string, jump: number?) -> boolean, -- looks up for the thing, can be useful for stuff like: (== or owo, lol)
    skip_all_those: (Lexer, those: string) -> (), -- skips all those, you know... those <.<
}

export type SymbolKind = "struct" | "enum" | "type"
export type Symbol = {
    symbol: string,
    address: any,
    kind: SymbolKind,
}
export type ParserResult = {
    symbols: {[string]: Symbol},
    data: {[any]: Struct | Enum | Type},
    tagged: {[string]: {Type}}
}

export type Parser = {
    token: Token, -- current token
    token_stream: () -> Token, -- token stream

    next: (Parser) -> Token, -- returns what token_stream gives but preprocess it before to handle _undefined and _error token kinds
    eat: (Parser, expect_kind: TokenKind?) -> Token, -- eats token and returns previous one, if expect kind is not equal the previous token kind will throw and error
    isa: (Parser, kind: TokenKind) -> boolean,
    parse: (Parser, state: {}) -> ParserResult,
    parse_state: (Parser, result: ParserResult, state: {}) -> (),
    parse_type: (Parser, result: ParserResult, state: {}) -> Type,
    parse_meta: (Parser, result: ParserResult, state: {}) -> {[any]: any},
    parse_tags: (Parser, result: ParserResult, state: {}) -> {string},
    parse_value: (Parser, result: ParserResult, state: {}) -> any,
}

export type TypeInfo = {
    typename: string,
    tags: {string},
    meta: {[any]: any},
    size_in_bytes: number,
}
export type TypeTuple = TypeInfo & {
    tuple: {Type}
}
export type TypeArray = TypeInfo & {
    holdtype: Type,
    size: number,
}
export type TypeVector = TypeInfo & {
    holdtype: Type,
}
export type Type = TypeInfo | TypeTuple | TypeArray | TypeVector

export type Field = {
    name: string,
    type: Type
}
export type StructField = Field & {}
export type Struct = {
    name: string,
    fields: {[string]: StructField},
    size_in_bytes: number,
}
export type EnumField = Field & {
    index: number,
}
export type Enum = {
    name: string,
    items: {[string]: EnumField},
    size_in_bytes: number,
}

export type StateDefinition = ParserResult & {
    sizes: {[string]: number}
}
export type State = {
    definition: StateDefinition,

    define: (State, definition: string) -> (),
    validate: (State) -> (),

    get_symbol: (State, name: string) -> Symbol,
    struct: (State, name: string) -> Struct,
}

local typeSizeMap = table.freeze({
    u8 = 8,
    u16 = 16,
    u32 = 32,
    i8 = 8,
    i16 = 16,
    i32 = 32,
    f32 = 32,
    f64 = 64,
})

local types = {
    builtin_datatypes = table.freeze {
        "u8", "u16", "u32", "u64",
        "i8", "i16", "i32", "i64",
        "f16", "f32", "f64", "f128",
        "leb128u32", "leb128u64",
        "leb128i32", "leb128i64",
        "cstr", "str", "bool"
    }
}

function types.type_to_size_in_bytes(type: string): number
    if table.find(types.builtin_datatypes, type) ~= nil then
        if type == "cstr" or type == "str" or type == "bool" then
            return 1
        elseif type:find("leb128") ~= nil then
            return 2
        end
        return (tonumber(type:sub(2, -1)) or 0) / 8
    end
    return 0
end

function types.count_bytes_leb128(value: number): number
    local count = 0
    repeat
        count += 1
        value = math.floor(value / 128)
    until value == 0
    return count
end

return if not table.isfrozen(types) then table.freeze(types) else types