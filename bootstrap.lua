-- BOOTSTRAP

--[[
for i,v in pairs(getfenv(1)) do
	print(i..": "..type(v))
end
--]]




print("System #"..(sys.id).." is booting!")
-- Load the APIs
os    = sys.loadApi("os")
fs    = sys.loadApi("fs")
term  = sys.loadApi("term")
peripheral = sys.loadApi("peripheral")
if sys.type == "drone" then
	drone = sys.loadApi("drone")
end
shell = sys.loadApi("shell")


-- Lock the doors!
_G = getfenv(1)
require = nil
load = nil
loadfile = nil
loadstring = nil
dofile = nil
collectgarbage = nil
getmetatable = nil
setmetatable = nil
getfenv = nil
setfenv = nil
package = nil
debug = nil
newproxy = nil
math.randomseed = nil
rawget = nil
rawset = nil
rawequal = nil

local id = getId()
sys.id = id

print("Finished booting, dropping to shell.")
-- Clear screen
term.clear()
if fs.isFile("startup") then
	shell.run("startup")
end
local event = nil
while true do
	event = sys:receiveEvent({"input"})
	if event ~= nil then
		if event.type == "input" then
		--	print(sys.id.." received input: "..dump(event.msg))
			shell.run(event.msg)
		else
			print(sys.id.." received unhandled event: "..dump(event))
		end
	end
	sys.yield()
end

return true
