-- SHELL API
--[[
for i,v in pairs(getfenv(1)) do
	print("SHELL ENV "..i..": "..type(v))
end
--]]

local shell = {}
function shell.errorHandler(err,level)
	print("shell error: '"..err.."'")
end

-- stolen from old lua-rocks
local function parse_flags(...)
   local args = {...}
   local flags = {}
   for i = #args, 1, -1 do
      local flag = args[i]:match("^%-%-(.*)")
      if flag then
         local var,val = flag:match("([a-z_%-]*)=(.*)")
         if val then
            flags[var] = val
         else
            flags[flag] = true
         end
         table.remove(args, i)
      end
   end
   return flags, unpack(args)
end

shell.prompt = "# "
shell.cursorPos = {1,1}

term  = sys:loadApi("term")

-- Shell main loop
function shell.main()
	print("main")
	term.clear()
	term.write("Welcome to dronetest shell.\n")
	term.write(shell.prompt)
	local loop = true
	local c,l,cmd
	l = ""
	c = ""
	cmd = ""
	local buffer = {}
	local env = nil
	local env_global = _G

	-- We register a listener that actually handles stuff, because that is instant, and does not have a 1-tic delay
	local func = function(event)
		if term.keyChars[event.msg.msg] then
			c = term.keyChars[event.msg.msg]
			if c ~= '\n' then
				if c == '\b' then
					l = string.sub(l,1,string.len(l)-1)
				else 
					l = l..c
				end
				term.write(c)
			else
				cmd = l
				if string.len(cmd) <= 0 then return
			end
				term.write("\nexecute '"..cmd.."':\n")
				if cmd == "exit" then
					print("exiting shell...")
					loop = false
					return
				end
				table.insert(buffer,l)
				l = ""
			end
		end
	end
	local listener = dronetest.events.register_listener(sys.id,{"key"},func)
	local lfunc = function(event) 
		table.insert(buffer,event.msg)
	end
	local line_listener = dronetest.events.register_listener(sys.id,{"input"},lfunc)
	
	-- We have to execute the actual command from here, otherwise we run into cross-yielding-issues
	-- This way the execution has a slight delay, but as the input does not, the user will not notice.
	while loop do
		dronetest.sleep(0.02)
		if #buffer > 0 then
			local cmd = table.remove(buffer,1)
			local argv = string.split(cmd," ")
			if type(argv) ~= "table" or #argv < 1 then return false end
			cmd = table.remove(argv,1)
			argv[0] = cmd -- i like it the C way
			shell.run(cmd,argv,env,env_global)
			cmd = ""
			l = ""
			c = ""
			term.write(shell.prompt)
		end
	end
	
	-- Remember to remove the listener
	dronetest.events.unregister_listener(listener)
	dronetest.events.unregister_listener(line_listener)
	term.write("shell has terminated\n")
end

function shell.run(cmd,argv,env,env_global)
	if env == nil then env = _G end
	argv = argv or {}
	-- TODO: write real cli parser
	local f,err = loadfile(mod_dir.."/"..sys.id.."/"..cmd)
	
	if f == nil then
		f,err = loadfile(mod_dir.."/rom/bin/"..cmd)
		if f == nil then
			print("ERROR: no such file or buggy file '"..cmd.."': "..err)
			return false
		end
		print("shell.run from rom: "..mod_dir.."/rom/bin/"..cmd)
		
		if env_global == nil then env_global = _G end
		for k,v in pairs(env_global) do 
			if env[k] == nil then env[k] = v end 
		end
	else
		print("shell.run from home for #"..sys.id..": "..mod_dir.."/"..sys.id.."/"..cmd)
	end
	
	env["argv"] = argv
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
