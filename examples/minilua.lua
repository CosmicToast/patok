local patok = require 'patok'

local lexer = patok {
        keyword = {
                'local',
                'function',
                'return',
                'end',
        },
        equal = '=',
        left_paren = '%(',
        right_paren = '%)',
}{
        identifier = '[%w_][%w%d_]*',
        whitespace = { '%s+', drop = true },
        number = '%d+',
        op = '[+%-*/]',
}()

local source = [[
local function getSalary(hour)
        return hour * 60 + 12
end

local bills = 40
local savings = getSalary(4) - bills
]]

lexer:reset(source)
local token = lexer:next()

while token ~= nil do
        print(token.value)
        token = lexer:next()
end
