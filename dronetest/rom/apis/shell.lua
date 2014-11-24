-- SHELL API
--[[
for i,v in pairs(getfenv(1)) do
	print("SHELL ENV "..i..": "..type(v))
end
--]]



local shell = {}
function shell.errorHandler(err,level)
	print("shell error: "..err)
end

shell.prompt = "# "

-- Shell main loop
function shell.main()
	local c,l,cmd
	while true do
		term.clear()
		term.write(shell.prompt)
		while c ~= '\n' do
			c = term.getChar()
			if c ~= '\n' then
				l = l..c
			end
		end
		cmd = l
		if cmd == "exit" then
			print("exiting shell")
			break
		end
		print("shell run: "..cmd)
		shell.run(cmd)
	end
end

function shell.run(cmd,argv)
	local env = getfenv(2)
	-- TODO: write real cli parser
	local f,err = loadfile(mod_dir.."/rom/bin/"..cmd)
	
	if f == nil then
		f,err = loadfile(mod_dir.."/"..sys.id.."/"..cmd)
		if f == nil then
			print("ERROR: no such file or buggy file '"..cmd.."': "..err)
			return false
		end
		print("shell.run from home: "..mod_dir.."/"..sys.id.."/"..cmd)
		-- Make sure we don't give API's environment to userspace function
		--env = getfenv(2)
	else
		print("shell.run from rom: "..mod_dir.."/rom/bin/"..cmd)
		
		local env_global = getfenv(1)
		for k,v in pairs(env_global) do 
			if env[k] == nil then env[k] = v end 
		end
	end
	
	env.argv = argv
	setfenv(f,env)
	jit.off(f,true)
	local r = xpcall(f,shell.errorHandler)
	if r == false then
		print("WARN: "..cmd.." failed!")
		return false
	end
	print("command returns: "..dump(r))
	return true
end

return shell
