local id = function(in) return function() return in end end
local pa = function(pt) return function(in) return in:find(pt) end

local meta = {}
function meta:__call(p)
	if p == nil then return self.out end
	for k, v in pairs(p) do
		-- we accept: string | { patterns..., [drop = true|false|string|func] }
		-- we output: { '^' .. patterns, drop = func, name = string }
		if type(v) == 'string' then
			v = { v }
		end
		-- assume table
		if v.drop == nil then
			v.drop = id(false)
		elseif type(v.drop) == 'string' then
			v.drop = pa(v.drop)
		elseif type(v.drop) == 'boolean' then
			v.drop = id(v.drop)
		end
		v.name = k

		for ii in ipairs(v) do v[ii] = '^' .. v[ii] end

		table.insert(self.out.tokens, v)
	end
	return self
end

function new (p)
	local out = {
		tokens = {},
		reset  = function (self, input)
			self.index = 1
			self.input = input
		end,
		next   = function (self)
			for _, v in ipairs(self.tokens) do
				for _, vv in ipairs(v) do
					local out = {string.find(self.input, vv, self.index)}
					if out[1] == self.index and out[2] >= out[1] then
						self.index = out[2]+1
						local match = {
							type  = v.name,
							start = out[1],
							stop  = out[2],
							value = string.sub(self.input, out[1], out[2])
						}
						if v.drop(match.value) then return self.next() end -- skip this one
						return match
					end
				end
			end
			-- we didn't find anything
			return nil -- feed more data! or better data. either one
		end,
	}
	local constructor = {out=out}
	setmetatable(constructor, meta)
	return constructor(p)
end

return new
