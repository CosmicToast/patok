local lpeg = require 'lpeg'

-- Lexical Elements
local Space = lpeg.S(" \n\t")^0
local Number = lpeg.C(lpeg.P"-"^-1 * lpeg.R("09")^1) * Space
local TermOp = lpeg.C(lpeg.S("+-")) * Space
local FactorOp = lpeg.C(lpeg.S("*/")) * Space
local Open = "(" * Space
local Close = ")" * Space

-- Auxiliary function
function eval (v1, op, v2)
  if (op == "+") then return v1 + v2
  elseif (op == "-") then return v1 - v2
  elseif (op == "*") then return v1 * v2
  elseif (op == "/") then return v1 / v2
  end
end

-- Grammar
local V = lpeg.V
G = lpeg.P{ "Exp",
  Exp = lpeg.Cf(V"Term" * lpeg.Cg(TermOp * V"Term")^0, eval);
  Term = lpeg.Cf(V"Factor" * lpeg.Cg(FactorOp * V"Factor")^0, eval);
  Factor = Number / tonumber + Open * V"Exp" * Close;
}

local test
if arg[1] then
	local f = io.open(arg[1], 'r')
	test = f:read '*a'
	f:close()
else
	test = [[10 + 5 * 2 + 10]]
end
print(lpeg.match(G, test))
