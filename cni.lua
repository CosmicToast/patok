local patok   = require 'patok'
local inspect = require 'inspect'
local pm      = require 'piecemeal'

local lexer = patok {
	WS = '[ \t]+',
	NL = '\r?\n',
	equals = '=',
	lbrack = '%[',
	rbrack = '%]',
	comment = '[#;][^\r\n]*',
	raw = '`[^`]-`', -- handle ``s in post as adjacent raws
}{
	word = '[^ \t\r\n=%[%]#;`]+',
}()

local lex = {
	WS = pm.lexeme 'WS',
	NL = pm.lexeme 'NL',
	equals = pm.lexeme 'equals',
	lbrack = pm.lexeme 'lbrack',
	rbrack = pm.lexeme 'rbrack',
	comment = pm.lexeme 'comment',
	raw = pm.lexeme 'raw',
	word = pm.lexeme 'word',
}

local opt = {}
for k, v in pairs(lex) do
	opt[k] = pm.opt(v)
end

local function findtype (d, tp)
	for _, v in pairs(d) do
		if v and type(v) == 'table' and v.type == tp then return v end
	end
	return nil
end

local function flattenvalue (d)
	local out = ''
	for _, v in ipairs(d) do
		if type(v) == 'table' then
			if v.value then out = out .. v.value
			else v = flattenvalue(v) end -- try to recurse
		elseif type(v) == 'string' then
			out = out .. v
		else
			out = out .. tostring(v)
		end
	end
	return out
end

local el = pm.postp(
	pm.all(opt.WS, opt.comment, lex.NL),
	function () return {type='el'} end)

local section = pm.postp(
	pm.all(opt.WS,
		lex.lbrack, opt.WS, opt.word, opt.WS, lex.rbrack,
		opt.WS, opt.comment, lex.NL),
	function (d)
		local out = ''
		local word = findtype(d, 'word')
		if word then out = word.value end
		return {type='section', name=out}
	end)

local kv_v = pm.postp(
	pm.all(lex.word, pm.star(pm.all(lex.WS, lex.word))),
	function (d)
		-- return {type='kv_v', value=(d)}
		return {type='kv_v', value=flattenvalue(d)}
	end)

local kv = pm.postp(
	pm.all(opt.WS, lex.word, opt.WS, lex.equals,
		opt.WS, kv_v, opt.WS, opt.comment, lex.NL),
	function (d)
		local key = findtype(d, 'word')
		local kv_v = findtype(d, 'kv_v')
		return {
			type = 'kv',
			key = key.value,
			value = kv_v.value,
		}
	end)

local rkv_v = pm.postp(
	pm.plus(lex.raw),
	function (d)
		local out = {}
		for _, v in ipairs(d) do
			table.insert(out, v.value:sub(2,-2)) -- terribly inefficient
		end
		return {
			type = 'rkv_v',
			value = table.concat(out, '`'), -- ditto
		}
	end)

local rkv = pm.postp(
	pm.all(opt.WS, lex.word, opt.WS, lex.equals,
		opt.WS, rkv_v, opt.WS, opt.comment, lex.NL),
	function (d)
		local key = findtype(d, 'word')
		local rkv_v = findtype(d, 'rkv_v')
		return {
			type = 'kv',
			key = key.value,
			value = rkv_v.value,
		}
	end)

local part = pm.alt(section, kv, rkv, el)
local cni = pm.postp(pm.star(part),
	function (d)
		for i, v in ipairs(d) do
			if v.type == 'el' then table.remove(d, i) end
		end
		return d
	end)

local test = [[
	[cni]
	is = cool
	and = `has raw values`
	with = `special `` handling`
	even = `with
	newlines`
]]

local eind, out = pm.parse(test, lexer, cni)
print(inspect(out))
