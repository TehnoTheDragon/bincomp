local types = require("types")

local validator = {}

function validator.validate(result: types.ParserResult, state)
    for _, symbol in result.symbols do
        validator.validate_symbol(result, symbol, state)
    end
end

function validator.validate_symbol(result: types.ParserResult, symbol: types.Symbol, state)
    
end

return validator