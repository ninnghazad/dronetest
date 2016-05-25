

-- Load dronetest.bootstrap code once
dronetest.bootstrap = readFile(dronetest.mod_dir.."/bootstrap.lua")
local err = ""
if type(dronetest.bootstrap) ~= "string" then minetest.log("error","missing or unreadable bootstrap!") return false end

-- Userspace Environment, this is available from inside systems
-- TODO: do we need to copy all the tables so they wont be changed for everybody by one user?

local fenv_whitelist = setmetatable({}, {__mode="k"})
fenv_whitelist[1] = true;
local function whitelist_fenv(f)
	fenv_whitelist[f] = true
end

local metatable_whitelist = setmetatable({}, {__mode="k"})
local function whitelist_metatable(t)
	metatable_whitelist[t] = true
end

dronetest.userspace_environment = {
	sys = {id=-1},
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	pcall = pcall,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	--coroutine = { create = coroutine.create, resume = coroutine.resume, running = coroutine.running, status = coroutine.status, 	wrap = coroutine.wrap },
	string = { byte = string.byte, char = string.char, find = string.find, 
	format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
	len = string.len, lower = string.lower, match = string.match, 
	rep = string.rep, reverse = string.reverse, sub = string.sub, 
	upper = string.upper, split = string.split },
	table = { insert = table.insert, maxn = table.maxn, remove = table.remove, 
	sort = table.sort,concat = table.concat },
	math = { abs = math.abs, acos = math.acos, asin = math.asin, 
	atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos, 
	cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, 
	fmod = math.fmod, frexp = math.frexp, huge = math.huge, 
	ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, 
	min = math.min, modf = math.modf, pi = math.pi, pow = math.pow, 
	rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh, 
	sqrt = math.sqrt, tan = math.tan, tanh = math.tanh },
	os = { clock = os.clock, difftime = os.difftime, time = os.time }
}
dronetest.userspace_environment.mod_name = dronetest.mod_name
dronetest.userspace_environment.mod_dir = dronetest.mod_dir
dronetest.userspace_environment.dump = dump
dronetest.userspace_environment.pprint = pprint
--[[dronetest.userspace_environment.error_handler = function(err)
	dronetest.print(id,"ERROR: "..dump(err))
	print("USERSPACE ERROR: "..dump(err)..dump(debug.traceback()))
end--]]
---[[
-- sandboxed stuff can only getfenv things it setfenv'ed
dronetest.userspace_environment.getfenv = function(f)
	print("dronetest.userspace_environment.getfenv ")
	dump(fenv_whitelist[f])
	if not fenv_whitelist[f] then return {} end
	return getfenv(f)
end

-- this probably doesn't need to be sandboxed - if a system ruins one of its fenvs, that's its own loss
dronetest.userspace_environment.setfenv = function(f, env)
	print("dronetest.userspace_environment.setfenv ")
	local fout = setfenv(f, env)
	fenv_whitelist[f] = true
	return fout
end

-- sandboxed stuff can only getmetatable things it setmetatable'ed
dronetest.userspace_environment.getmetatable = function(t, mt)
	-- currently disabled with 'false and' because untested
	if not metatable_whitelist[t] then return nil end
	return getmetatable(t, mt)
end

-- this probably doesn't need to be sandboxed - if a system ruins one of its metatables, that's its own loss
dronetest.userspace_environment.setmetatable = function(t, mt)
	metatable_whitelist[t] = true
	return setmetatable(t, mt)
end

--dronetest.userspace_environment.loadfile = loadfile
dronetest.userspace_environment.pcall = pcall
dronetest.userspace_environment.xpcall = function(f,e)
	print("userspace.xpcall!")
	return xpcall(f,e)
end

--[[
-- coroutine for userspace
dronetest.userspace_environment.coroutine = table.copy(coroutine)
dronetest.userspace_environment.coroutine.create = function(f)
	jit.off(f,true)
	local e = getfenv(2)
	setfenv(f,e)
	local ff = function() xpcall(f,function(msg) if msg == "attempt to yield across C-call boundary" then msg = "too many instructions without yielding" end dronetest.print(e.dronetest.current_id,"Error in coroutine: '"..msg.."':"..dump(debug.traceback())) coroutine.yield() end) end
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
	print("nonono, not allowed atm!")
	function f() end
	return f,"access denied"
--[[
	local f,err = loadfile(s)	
	if f == nil then
		print(err)
		return nil,err
	end
	setfenv(f,getfenv(1))
	return f,""
--]]
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
