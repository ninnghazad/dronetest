-- BOOTSTRAP
-- this is the entrypoint to userspace

function processInput(msg)
	if msg == nil or type(msg) ~= "string" then return false end
	local result = false
	
	-- TODO: this doesn't work with quotes, use a nice regex or something to make it better
	local argv = string.split(msg," ")
	if type(argv) ~= "table" or #argv < 1 then return false end
	local cmd = table.remove(argv,1)
	argv[0] = cmd -- i like it the C way
	print(cmd..": "..dump(argv))
	result = shell.run(cmd,argv)
	return result
end

print("System #"..(sys.id).." is booting!")
-- Load the APIs
coroutine    = sys.loadApi("coroutine")
os    = sys.loadApi("os")
fs    = sys.loadApi("fs")
term  = sys.loadApi("term")
peripheral = sys.loadApi("peripheral")
if sys.type == "drone" then
	drone = sys.loadApi("drone")
end
shell = sys.loadApi("shell")




-- print environment as it is right now.
-- lets leave this in for a while for debugging
for i,v in pairs(_G) do
	print("bootstrap env: "..i.." ("..type(v)..")")
end

local id = getId()
sys.id = id

if not fs.isDir("./") then fs.makeDir("./") end

print("Finished booting #"..sys.id..", dropping to shell.")

-- Clear screen
--term.clear()


if fs.isFile("startup") then
	shell.run("startup")
end

shell.main()
--shell.run("quarry",{1,1,1})
--[[
local event = nil
while true do
	event = sys:receiveEvent({"input"})
	if event ~= nil then
		if event.type == "input" then
		--	print(sys.id.." received input: "..dump(event.msg))
			if type(event.msg) ~= "string" or event.msg == "" then
				print("$")
			elseif not processInput(event.msg) then 
				print("Command '"..event.msg.."' failed.")
			end
		else
			print(sys.id.." received unhandled event: "..dump(event))
		end
	end
	sys.yield()
end
--]]

return true
