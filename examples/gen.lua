local min = 1
local max = 100

if arg[1] then max = tonumber(arg[1]) end
if arg[2] then min = tonumber(arg[2]) end
-- this will get fixed in the next if

if max < min then
	min, max = max, min
elseif max == min then
	max = max + 1
end

for i=min,max-1 do
	io.write(i, '+')
end
print(max)
