-- SHELL API
--[[
for i,v in pairs(getfenv(1)) do
	print("SHELL ENV "..i..": "..type(v))
end
--]]
local shell = {}
function shell.errorHandler(err,level)
	print("ERROR @ "..err)
end
function shell.run(cmd)
	-- TODO: write real cli parser
	local f = loadfile(mod_dir.."/rom/bin/"..cmd)
	print("shell.run: "..mod_dir.."/rom/bin/"..cmd)
	if f == nil then
		print("ERROR: no such file or buggy file '"..cmd.."'.")
		return false
	end
	-- Make sure we don't give API's environment to userspace function
	setfenv(f,getfenv(2))
	local r = xpcall(f,shell.errorHandler)
	if r == false then
		print("WARN: "..cmd.." failed!")
		return false
	end
	print("command returns: "..dump(r))
	return true
end

return shell
