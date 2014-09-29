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
	local f,err = loadfile(mod_dir.."/rom/bin/"..cmd)
	print("shell.run: "..mod_dir.."/rom/bin/"..cmd)
	if f == nil then
		print("ERROR: no such file or buggy file '"..cmd.."': "..err)
		return false
	end
	-- Make sure we don't give API's environment to userspace function
	setfenv(f,getfenv(2))
	jit.off(f,true)
--[[	
	f = function() 
		debug.sethook(function ()
			
			if minetest.get_gametime() > active_systems[sys.id].last_update + 10 then
				print("TOO LONG WITHOUT YIELD!")
			else 
				print("HOOK "..sys.getTime().. " > "..active_systems[sys.id].last_update)
				print(os.execute("date +%s"))
			end
			coroutine.yield()
	--		active_systems[sys.id].cr = nil
	--		error("OMG!")
			return false
		end,"",5) 
		
		return f() 
	end
--]]
	--debug.sethook(function () print("INNER TIMEOUT") end,"",99)
	local r = xpcall(f,shell.errorHandler)
	if r == false then
		print("WARN: "..cmd.." failed!")
		return false
	end
	print("command returns: "..dump(r))
	return true
end

return shell
