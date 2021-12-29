--[[
	A parser has the signature: (list, sindex) -> eindex [, output]
	If the parser "fails", it must return exactly nil.
	If the parser "succeeds", it must return at least the eindex, and may also return some output.
]]--

return {
	lexeme = function (type)
		return function (l, i)
			if l[i] and l[i].type == type then
				return i+1, l[i]
			end
			return nil
		end
	end,
	value = function (value)
		return function (l, i)
			if l[i] and l[i].value == value then
				return i+1, l[i]
			end
			return nil
		end
	end,
	all = function (...)
		local args = {...}
		return function (l, i)
			local res = {}
			local eind, out
			for _, v in ipairs(args) do
				eind, out = v(l, i)
				if not eind then return nil end
				i = eind
				table.insert(res, out)
			end
			return i, res
		end
	end,
	alt = function (...)
		local args = {...}
		return function (l, i)
			local eind, out
			for _, v in ipairs(args) do
				eind, out = v(l, i)
				if eind then
					return eind, out
				end
			end
			return nil
		end
	end,
	opt = function (p)
		return function (l, i)
			local eind, out = p(l, i)
			if eind
				then return eind, out
				else return i
			end
		end
	end,
	plus = function (p)
		return function (l, i)
			local res = {}
			local eind, out = p(l, i)
			if not eind then return nil end
			repeat
				i = eind
				table.insert(res, out)
				eind, out = p(l, i)
			until not eind
			return i, res
		end
	end,
	star = function (p)
		return function (l, i)
			local res = {}
			local eind, out
			repeat
				eind, out = p(l, i)
				if eind then
					table.insert(res, out)
					i = eind
				end
			until not eind
			return i, res
		end
	end,

	postp = function (p, f)
		return function (l, i)
			local eind, out = p(l, i)
			if out then out = f(out) end
			return eind, out
		end
	end,

	parse = function (text, lexer, parser)
		local tokens = {}
		lexer:reset(text)
		local next
		repeat
			next = lexer:next()
			if next then table.insert(tokens, next) end
		until next == nil
		local eind, out = parser(tokens, 1)
		-- a successful parse means eind is >1 the length of tokens
		if tokens[eind] then -- so this is unsuccessful
			return out, tokens[eind-1].stop, tokens[eind].start
		else -- and this is
			return out, tokens[eind-1].stop, nil
		end
	end,
}
