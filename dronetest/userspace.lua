

-- Load dronetest.bootstrap code once
dronetest.bootstrap = readFile(dronetest.mod_dir.."/bootstrap.lua")
local err = ""
if type(dronetest.bootstrap) ~= "string" then minetest.log("error","missing or unreadable bootstrap!") return false end

-- Userspace Environment, this is available from inside systems
-- TODO: do we need to copy all the tables so they wont be changed for everybody by one user?

local fenv_whitelist = setmetatable({}, {__mode="k"})
local function whitelist_fenv(f)
	fenv_whitelist[f] = true
end

local metatable_whitelist = setmetatable({}, {__mode="k"})
local function whitelist_metatable(t)
	metatable_whitelist[t] = true
end

dronetest.userspace_environment = {ipairs=ipairs,pairs=pairs,print=print}
dronetest.userspace_environment.mod_name = dronetest.mod_name
dronetest.userspace_environment.mod_dir = dronetest.mod_dir
dronetest.userspace_environment.dump = dump
dronetest.userspace_environment.type = type
dronetest.userspace_environment.count = count

dronetest.userspace_environment.table = table
dronetest.userspace_environment.string = string
dronetest.userspace_environment.math = math

-- sandboxed stuff can only getfenv things it setfenv'ed
dronetest.userspace_environment.getfenv = function(f)
	-- currently disabled with 'false and' because untested
	if false and not fenv_whitelist[f] then return nil end
	return getfenv(f)
end

-- this probably doesn't need to be sandboxed - if a system ruins one of its fenvs, that's its own loss
dronetest.userspace_environment.setfenv = function(f, env)
	fenv_whitelist[f] = true
	return setfenv(f, env)
end

-- sandboxed stuff can only getmetatable things it setmetatable'ed
dronetest.userspace_environment.getmetatable = function(t, mt)
	-- currently disabled with 'false and' because untested
	if false and not metatable_whitelist[t] then return nil end
	return getmetatable(t, mt)
end

-- this probably doesn't need to be sandboxed - if a system ruins one of its metatables, that's its own loss
dronetest.userspace_environment.setmetatable = function(t, mt)
	metatable_whitelist[t] = true
	return setmetatable(t, mt)
end

--dronetest.userspace_environment.loadfile = loadfile
dronetest.userspace_environment.pcall = pcall
dronetest.userspace_environment.xpcall = xpcall
--[[
-- coroutine for userspace
dronetest.userspace_environment.coroutine = table.copy(coroutine)
dronetest.userspace_environment.coroutine.create = function(f)
	jit.off(f,true)
	local e = getfenv(2)
	setfenv(f,e)
	local ff = function() xpcall(f,function(msg) if msg == "attempt to yield across C-call boundary" then msg = "too many instructions without yielding" end dronetest.print(e.sys.id,"Error in coroutine: '"..msg.."':"..dump(debug.traceback())) coroutine.yield() end) end
	local co = coroutine.create(ff)
	return co
end
dronetest.userspace_environment.coroutine.resume = function(co)
	debug.sethook(co,coroutine.yield,"",dronetest.max_userspace_instructions)
	coroutine.resume(co) 
	coroutine.yield()
end
--]]



dronetest.userspace_environment.loadfile = function(s)
	local f,err = loadfile(s)
	if f == nil then
		print(err)
		return nil,err
	end
	setfenv(f,getfenv(1))
	return f,""
end

dronetest.userspace_environment.loadstring = function(s)
	local f,err = loadstring(s)
	-- this is a userspace function - userspace functions can read its environment without reading it first
	fenv_whitelist[f] = true
	if f == nil then
		print(err)
		return nil,err
	end
	
	setfenv(f,getfenv(1))
	return f,""
end