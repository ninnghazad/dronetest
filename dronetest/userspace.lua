

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

local safeglobals = 
{
	"dump",
	"count",

	"type",
	"tonumber",
	"tostring",

	"assert",
	"error",
	"pcall",
	"xpcall",

	"next",
	"ipairs",
	"pairs",

	"select",

	"table",
	"string",
	"math",
}

function dronetest.mkenv(id)
	local userspace_environment = {}

	local env_safe = {}

	userspace_environment._G = userspace_environment

	userspace_environment.mod_name = dronetest.mod_name	-- ok, in case of forks
	userspace_environment.mod_dir = dronetest.mod_dir	-- why?

	userspace_environment.id = id

	userspace_environment.getId = function() return id end	-- DEPRECATED

	for i,v in ipairs(safeglobals) do
		userspace_environment[v] = _G[v]
	end

	--userspace_environment.print=print

	-- sandboxed stuff can only getfenv things it setfenv'ed
	-- TODO: implement level in a safe way
	userspace_environment.getfenv = function(f)
		-- currently disabled with 'false and' because untested
		if not fenv_whitelist[f] then return nil end
		return getfenv(f)
	end

	-- this probably doesn't need to be sandboxed - if a system ruins one of its fenvs, that's its own loss
	userspace_environment.setfenv = function(f, env)
		fenv_whitelist[f] = true
		return setfenv(f, env)
	end

	-- sandboxed stuff can only getmetatable things it setmetatable'ed
	userspace_environment.getmetatable = function(t, mt)
		-- currently disabled with 'false and' because untested
		if false and not metatable_whitelist[t] then return nil end
		return getmetatable(t, mt)
	end

	-- this probably doesn't need to be sandboxed - if a system ruins one of its metatables, that's its own loss
	userspace_environment.setmetatable = function(t, mt)
		metatable_whitelist[t] = true
		return setmetatable(t, mt)
	end

	--userspace_environment.loadfile = loadfile
	--[[
	-- coroutine for userspace
	userspace_environment.coroutine = table.copy(coroutine)
	userspace_environment.coroutine.create = function(f)
		jit.off(f,true)
		local e = getfenv(2)
		setfenv(f,e)
		local ff = function() xpcall(f,function(msg) if msg == "attempt to yield across C-call boundary" then msg = "too many instructions without yielding" end dronetest.print(e.sys.id,"Error in coroutine: '"..msg.."':"..dump(debug.traceback())) coroutine.yield() end) end
		local co = coroutine.create(ff)
		return co
	end
	userspace_environment.coroutine.resume = function(co)
		debug.sethook(co,coroutine.yield,"",dronetest.max_userspace_instructions)
		coroutine.resume(co) 
		coroutine.yield()
	end
	--]]



	userspace_environment.loadfile = function(s)
		-- TODO: might be security hole, or was loadfile already overridden?
		local f,err = loadfile(s)
		if f == nil then
			print(err)
			return nil,err
		end
		setfenv(f,env_safe)
		return f,""
	end

	userspace_environment.loadstring = function(s)
		local f,err = loadstring(s)
		-- this is a userspace function - userspace functions can read its environment without writing it first
		fenv_whitelist[f] = true
		if f == nil then
			print(err)
			return nil,err
		end
		
		setfenv(f,env_safe)
		return f,""
	end

	-- overload print function to print to drone/computer's screen and not to servers stdout
	userspace_environment.print = function(msg) dronetest.print(id,msg) end

	-- for debugging purposes
	userspace_environment.rprint = print

	return sandboxfunc(userspace_environment, userspace_environment, nil, env_safe)	-- make everything safe for wrecking

end