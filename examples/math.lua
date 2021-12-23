local patok   = require 'patok'
local inspect = require 'inspect'
local pm      = require 'piecemeal'

local lexer = patok {
	op    = '[+*]',
	digit = '%d+',
	space = '%s+',
}()

local lex = {
	-- plus  = pm.lexeme 'plus',
	plus  = pm.value '+',
	times = pm.value '*',
	digit = pm.postp(pm.lexeme 'digit', function(d) return tonumber(d.value) end),
	space = pm.opt(pm.lexeme 'space')
}

local function findnums(d, acc)
	local out = acc or {}
	for _, v in ipairs(d) do -- only ipairs to avoid triggering on tokens
		if type(v) == 'number' then
			table.insert(out, v)
		elseif type(v) == 'table' then
			findnums(v, out)
		end
	end
	return out
end

local mult = pm.postp(
	pm.all(lex.digit, pm.star(pm.all(lex.space, lex.times, lex.space, lex.digit))),
	function (d)
		local acc = 1
		for _, v in ipairs(findnums(d)) do
			acc = acc * v
		end
		return acc
	end)
	
local add = pm.postp(
	pm.all(mult, pm.star(pm.all(lex.space, lex.plus, lex.space, mult))),
	function (d)
		local acc = 0
		for _, v in ipairs(findnums(d)) do
			acc = acc + v
		end
		return acc
	end)

local expr = add

local test
if arg[1] then
	local f = io.open(arg[1], 'r')
	test = f:read '*a'
	f:close()
else
	test = [[10 + 5 * 2 + 10]]
end

local eind, out = pm.parse(test, lexer, expr)
print(eind, out)
