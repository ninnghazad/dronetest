
-- Sys userspace API
dronetest.sys = {}
dronetest.sys.id = 0
dronetest.sys.last_msg_id = 0
dronetest.sys.yield = coroutine.yield
dronetest.sys.getTime = function()
	return minetest.get_gametime()
end
dronetest.sys.time = dronetest.sys.getTime 
function dronetest.sys:receiveEvent(filter)
	if filter == nil then
		filter = {}
	end
	return dronetest.events.receive(self.id,filter)
end
function dronetest.sys:sendEvent(event)
	return dronetest.events.send_by_id(self.id,event)
end
function dronetest.sys:receiveDigilineMessage(channel,msg_id)
	local e = dronetest.events.receive(self.id,{"digiline"},channel,msg_id)
	if e == nil then return nil end
	return e.msg
end

function dronetest.sys:waitForDigilineMessage(channel,msg_id,timeout)
	local e = dronetest.events.wait_for_receive(self.id,{"digiline"},channel,msg_id,timeout)
	if e == nil then return nil end
	return e.msg
end
function dronetest.sys:init()
	-- make sure there are no old listeners left after a crash/restart
	dronetest.events.unregister_listeners(self.id)
	return true
end

function dronetest.sys:getUniqueId(event)
	self.last_msg_id = self.last_msg_id + 1
	return minetest.get_gametime().."_"..self.id.."_"..self.last_msg_id
end

-- Gets an API as a string, used only wrapped in bootstrap.lua
local function getApi(name, sandbox)
	local api = readFile(dronetest.mod_dir.."/rom/apis/"..name..".lua", sandbox)
	local err = ""
	if type(api) ~= "string" or api == "" then minetest.log("error","missing, unreadable or empty api '"..name.."'!") error("missing, unreadable or empty api '"..name.."'!") return false end
	api,err = loadstring(api)
	if type(api) ~= "function" or err ~= nil then minetest.log("error","bad api '"..name.."': "..err)  error("bad api '"..name.."'!") return false end
	return api
end

function dronetest.sys:loadApi(name)
	print(self.id.." loads api '"..name.."'")
	local api = getApi(name, dronetest.sys.sandbox)
	local env_save = table.copy(dronetest.userspace_environment)
	local env_global = getfenv(api)
	
	-- No! Use a metatable __index instead!
	for k,v in pairs(env_global) do 
		if env_save[k] == nil then env_save[k] = v end 
	--	print("API ENV for '"..name.."': "..k..": "..type(v))
	end
	
	-- Make drone/computer's env available to APIs, with id and stuff
	env_save.sys = getfenv(2).sys
	env_save.print = function(msg) dronetest.print(env_save.sys.id,msg) end
	env_save.dronetest = dronetest
	setfenv(api,env_save)
	return api()
end
