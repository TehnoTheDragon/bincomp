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
}

export type TokenKind = "_error"
                      | "_undefined"
                      | "_end"
                      | "word"
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

export type Parser = {
    token_stream: () -> Token
}

export type StructField = {
    name: string,
    type: string,
    external: boolean,
    array: {number}?,
    meta: {any},
    index: number,
}
export type Struct = {
    name: string,
    fields: {[string]: StructField},
    externals: {[string]: Struct},
    size_in_bytes: number,
}

export type State = {
    define: (definition: string) -> ()
}

export type Type = "u8" | "u16" | "u32" | "i8" | "i16" | "i32" | "f32" | "f64" | "str"
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

local types = {}

function types.type_to_size(type: Type)
    local bits = typeSizeMap[type]
    if not bits then
        if type == "str" then
            bits = typeSizeMap.u32
        end
    end
    return bits
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