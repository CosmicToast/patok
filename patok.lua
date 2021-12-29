local meta = {}
function meta:__call(p)
	if p == nil then return self.out end
	for k, v in pairs(p) do
		table.insert(self.out.tokens, {name=k, pattern='^' .. v})
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
				local out = {string.find(self.input, v.pattern, self.index)}
				if out[1] == self.index and out[2] >= out[1] then
					self.index = out[2]+1
					return {
						type  = v.name,
						start = out[1],
						stop  = out[2],
						value = string.sub(self.input, out[1], out[2])
					}
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
