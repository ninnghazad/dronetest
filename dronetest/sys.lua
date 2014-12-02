
local isolation = {}	-- better name for this table please?

-- Sys userspace API
function dronetest.mksys(env, id, channel, t, sandbox)
	local sys = {}
	env.sys = sys
	isolation[env] = sys

	sys.channel = channel
	sys.type = t
	-- HORRIBLE PLACE TO STORE SANDBOX PATH
	sys.sandbox = sandbox
	-- HORRIBLE PLACE TO STORE ID
	sys.id = id
	sys.last_msg_id = 0
	sys.yield = coroutine.yield
	sys.getTime = function()
		return minetest.get_gametime()
	end
	sys.time = sys.getTime 

	function sys:receiveEvent(filter)
		if filter == nil then
			filter = {}
		end
		return dronetest.events.receive(self.id,filter)
	end
	function sys:sendEvent(event)
		return dronetest.events.send_by_id(self.id,event)
	end
	function sys:receiveDigilineMessage(channel,msg_id)
		local e = dronetest.events.receive(self.id,{"digiline"},channel,msg_id)
		if e == nil then return nil end
		return e.msg
	end

	function sys:waitForDigilineMessage(channel,msg_id,timeout)
		local e = dronetest.events.wait_for_receive(self.id,{"digiline"},channel,msg_id,timeout)
		if e == nil then return nil end
		return e.msg
	end

	function sys:getUniqueId(event)
		self.last_msg_id = self.last_msg_id + 1
		return minetest.get_gametime().."_"..self.id.."_"..self.last_msg_id
	end

	-- Gets an API as a string, used only wrapped in bootstrap.lua
	-- TODO: is it possible to overload this from userspace? make sure it isn't
	--  electrodude's comment: who cares if it is?  If they overload it, they just can't load APIs anymore.  Their loss.
	local function getApi(name, sandbox)
		print("getApi at "..dronetest.mod_dir.."/rom/apis/"..name..".lua")
		local api = readFile(dronetest.mod_dir.."/rom/apis/"..name..".lua", sandbox)
		local err = ""
		if type(api) ~= "string" or api == "" then minetest.log("error","missing, unreadable or empty api '"..name.."'!") error("missing, unreadable or empty api '"..name.."'!") return false end
		api,err = loadstring(api)
		if type(api) ~= "function" or err ~= nil then minetest.log("error","bad api '"..name.."': "..err)  error("bad api '"..name.."'!") return false end
		return api
	end
	---[[ old one that I (electrodude) can't understand:
	-- BAD - LEAKS GLOBAL MINETEST ENVIRONMENT!!!
	sys.loadApi = function(name)
		--local api = getApi(name, sys.sandbox)
		local api = getApi(name)
		--local env_save = table.copy(dronetest.userspace_environment)
		local env_save = setmetatable({}, {__index = _G})
		
		-- No! Use a metatable __index instead!
		for k,v in pairs(env) do 
			if env_save[k] == nil then env_save[k] = v end 
		--	print("API ENV for '"..name.."': "..k..": "..type(v))
		end

		env_save.dronetest = dronetest
		env_save._G = _G
		env_save.env = env
		
		-- Make drone/computer's env available to APIs, with id and stuff
		--env_save.dronetest = getfenv(0).dronetest
		env_save.sys = sys
		env_save.print = function(msg) dronetest.print(sys.id,msg) end
		setfenv(api,env_save)
		return sandboxfunc(api())
	end
	--]]
	--[[
	-- Not ready yet:
	sys.loadApi = function(name)
		local apifunc = getApi(name, sys.sandbox)
		
		local apienv = setmetatable({}, {__index=_G})

		apienv.dronetest = dronetest

		setfenv(apifunc, apienv)
		
		return apifunc()
	end
	--]]

	return sandboxfunc(sys, env)
end
