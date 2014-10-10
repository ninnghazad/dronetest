--[[
****
DroneTest
by ninnghazad
Licensed under NOTHING.
****
--]]


mod_name = minetest.get_current_modname()
mod_dir = minetest.get_modpath(mod_name)

if minetest.setting_getbool("log_mods") then
	minetest.log("action", "[MOD] "..mod_name.." -- loading from "..mod_dir)
	minetest.register_on_shutdown(function() minetest.log("action", "[MOD] "..mod_name.." -- unloading ...") end)
end
-- include Lua File System, not sure if more versions are needed, this is linux64 and win32 i think
package.cpath = package.cpath
	.. ";" .. mod_dir .. "/lfs.so"
	.. ";" .. mod_dir .. "/lfs.dll"

lfs = require("lfs")

-- convert a path into a table, ignoring ..
local function parse_filename(filename)
	local path = {}
	for s in filename:gmatch("[^/]*") do
		if s == ".." then
			if #path == 0 then
				return nil
			end
			table.remove(path)
		elseif s ~= "." then
			table.insert(path, s)
		end
	end
	return path
end

function is_filename_in_sandbox(filename, sandbox)
	if not sandbox then
		dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == true")
		return true
	end
	local path, base= parse_filename(filename), parse_filename(sandbox)
	if not path or not base then
		dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == false")
		return false
	end
	for i,v in ipairs(base) do
		if path[i] ~= v then
			dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == false")
			return false
		end
	end
	dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == true")
	return true
end
function readFile(file, sandbox)
	if not is_filename_in_sandbox(file, sandbox) then
		dronetest.log("readFile: "..dump(file).." is not a legal filename.")
		return
	end
	local f = io.open(file, "rb")
	if not f then
		dronetest.log("readFile: failed to open "..dump(file))
		return
	end
	local content = f:read("*all")
	f:close()
	return content
end

function writeFile(file,str)
	if not is_filename_in_sandbox(file, sandbox) then
		dronetest.log("writeFile: "..dump(file).." is not a legal filename.")
		return
	end
	local f,err = io.open(file,"wb") 
	if not f then minetest.log("error",err) return false end
	f:write(string)
	f:close()
	return true
end

function mkdir(dir)
	os.execute("mkdir -p '"..dir.."'")
end

local events = {}
console_histories = {}
active_systems = {}

--Global config and function table.
dronetest = {
	last_id = 0,
	last_drone_id = 0,
	globalstep_interval = 0.01,
	drones = {},
	max_userspace_instructions = 1000000,
	log = function(msg) minetest.log("action","dronetest: "..msg) end,

}


--Config documentation, items that have one get save in config and can be changed by menu
local doc = {
	last_id = "The last id given to a computer.",
	last_drone_id = "The last id given to a drone.",
	globalstep_interval = "Interval to run LUA-coroutines at.",
	max_userspace_instructions = "How many instructions may a player execute on a system without yielding?"
}

local function count(t)
	local n = 0
	for k,v in pairs(t) do
		n = n + 1
	end
	return n
end

local function sandbox(x, env)
	if type(x) == "table" then
		for k,v in pairs(x) do
			x[k] = sandbox(v, env)
		end
	elseif type(x) == "function" then
		return setfenv(function(...) return x(...) end, env)
	else
		return x
	end
end
function table.copy(t, deep, safeenv, seen)
    seen = seen or {}
    if t == nil then return nil end
    if seen[t] then return seen[t] end

    local nt = {}
    for k, v in pairs(t) do
        if deep and type(v) == 'table' then
            nt[k] = table.copy(v, deep, safeenv, seen)
        elseif safeenv and type(v) == 'function' then
        	nt[k] = setfenv(function(...) return v(...) end, safeenv)
        else
            nt[k] = v
        end
    end
    setmetatable(nt, table.copy(getmetatable(t), deep, safeenv, seen))
    seen[t] = nt
    return nt
end
function math.round(x)
	return math.floor(x+0.5)
end
round = math.round
--Manage config.
--Saves contents of config to file.
local function saveConfig(path, config, doc)
	local file = io.open(path,"w")
	if file then
		for i,v in pairs(config) do
			local t = type(v)
			if t == "string" or t == "number" or t == "boolean" then
				if doc and doc[i] then -- save only those with a description!
					file:write("# "..doc[i].."\n")
					file:write(i.." = "..tostring(v).."\n")
				end
				
			end
		end
	end
end
--Loads config and returns config values inside table.
local function loadConfig(path)
	local config = {}
	local file = io.open(path,"r")
  	if file then
  		io.close(file)
		for line in io.lines(path) do
			if line:sub(1,1) ~= "#" then
				i, v = line:match("^(%S*) = (%S*)")
				if i and v then
					if v == "true" then v = true end
					if v == "false" then v = false end
					if tonumber(v) then v = tonumber(v) end
					config[i] = v
				end
			end
		end
		return config
	else
		--Create config file.
		return nil
	end
end
local function save()
	saveConfig(mod_dir.."/config.txt", dronetest, doc)
end

minetest.register_on_shutdown(save)

local config = loadConfig(mod_dir.."/config.txt")
if config then
	for i,v in pairs(config) do
		if type(dronetest[i]) == type(v) then
			dronetest[i] = v
		end
	end
else
	save()
end

for i,v in pairs(dronetest) do
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" then
		local v = minetest.setting_get("snow_"..i)
		if v ~= nil then
			if v == "true" then v = true end
			if v == "false" then v = false end
			if tonumber(v) then v = tonumber(v) end
			dronetest[i] = v
		end
	end
end



local drone_formspec = "size[12,4;]\nlist[current_name;main;0,9;4,4;]\nlist[current_player;main;0,0;8,4;]"

local get_menu_formspec = function()
	local p = -0.5
	local formspec = "label[0,-0.3;Settings:]"
	for i,v in pairs(dronetest) do
		local t = type(v)
		if t == "string" or t == "number" then
			p = p + 1.5
			formspec = formspec.."field[0.3,"..p..";4,1;dronetest:"..i..";"..i.." ("..doc[i]..")"..";"..v.."]"
		elseif t == "boolean" then
			p = p + 0.5
			formspec = formspec.."checkbox[0,"..p..";dronetest:"..i..";"..i.." ("..doc[i]..")"..";"..tostring(v).."]"
		end
	end
	p = p + 1
	formspec = "size[4,"..p..";]\n"..formspec
	return formspec
end

minetest.register_chatcommand("dronetest", {
	description = "dronetest config menu",
	privs = {server=true},
	func = function(name, param)
		dronetest.log("dronetest cmd called")
		minetest.show_formspec(name, "dronetest:menu", get_menu_formspec())
	end,
})

minetest.register_chatcommand("dronetest:wipe",{
	description = "dronetest garbage collect",
	privs = {server=true},
	func = function(name, param)
		dronetest.log("dronetest cmd called")
		collectgarbage()
	end,
})

minetest.register_chatcommand("dronetest:info", {
	description = "dronetest infos",
	privs = {server=true},
	func = function(name, param)
		dronetest.log("dronetest:info cmd called")
		local info = ""
		info = info.."# active systems: "..count(active_systems).."\n# active drones: "..count(dronetest.drones).."\n"
		info = info.."# output buffers: "..count(console_histories).."\n"
		local num_events = 0
		for _,v in pairs(active_systems) do
			num_events = num_events + count(v.events)
		end
		info = info.."# total events in all queues: "..num_events.."\n"
		
		local num_buffsize = 0
		for _,v in pairs(console_histories) do
			num_buffsize = num_buffsize + string.len(v)
		end
		info = info.."# total size of all buffers: "..num_buffsize.."\n"
		info = info.."total # bytes lua-mem: "..collectgarbage("count").."\n"
		minetest.chat_send_player(name,info)
	end,
})


-- this is ugly and badly named
-- this is what formats text when sent to stdout
local function history_list(id)
	if console_histories[id] == nil then
		-- TODO: put some nifty ascii-art as default screen?!?
		return "###### P R E S S   O N   T O   S T A R T   S Y S T E M #####\n"
	end
	return console_histories[id] -- send complete buffer to display for now
	--[[
	local s = ""
	local n = count(console_histories[id])
	for i,v in ipairs(console_histories[id]) do
		if i > math.max(0,n - (40-6)) then -- hardcoded size of display
			s = s..""..v.." "..n.."\n"
		end
	end
	s = s.." "
	return s
	--]]
end

local function get_drone_formspec(id,channel)
	local formspec =
		"size[13,5]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"list[detached:dronetest_drone_"..id..";main;9,1.3;4,4;]"..
		"list[current_player;main;0,1.3;8,1;]"..
		"list[current_player;main;0,2.3;8,3;8]"..
		--"textarea[0.3,0.0;13,5;output;;"..history_list(id).."]"..
		"label[0.3,0.0;DRONE_ID: "..id.."]"..
		"field[2.3,0.3;13,1;channel;channel;"..channel.."]"
		--[["button[8,5.2;1,1;execute;EXE]"..
		"button[8,6.0;1,1;poweroff;OFF]"..
		"button[8,6.8;1,1;poweron;ON]"..
		"button_exit[8,7.6;1,1;exit;EXIT]"..
		"button[8,8.4;1,1;redraw;DRW]"--]]
	return formspec
end
local function get_computer_formspec(id,channel)
	local formspec =
		"size[12,1]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		--"textarea[0.3,0.0;13,9.7;output;;"..history_list(id).."]"..
		"field[0.3,0.7;7,1;input;;]"..
		"field[7.3,0.7;2,1;channel;channel;"..channel.."]"..
		"button[9,0.4;1,1;execute;EXE]"..
		"button[10,0.4;1,1;poweroff;OFF]"..
		"button[11,0.4;1,1;poweron;ON]"
		--"button[13,7.6;1,1;clear;CLR]"..
		--"button[12,0.4;1,1;redraw;DRW]"
	return formspec
end

local function redraw_computer_formspec(pos,player)
	local meta = minetest.get_meta(pos)
	
	local formspec = get_computer_formspec(meta:get_int("id"),meta:get_string("channel"))
	meta:set_string("formspec",formspec)
	
--	minetest.show_formspec(player:get_player_name(),"dronetest:computer",formspec)
end

function dronetest.print(id,msg)
	if msg == nil then
		return
	end
	if console_histories[id] == nil then
		console_histories[id] = ""
	end
	console_histories[id] = console_histories[id]..msg.."\n"
	
	if string.len(console_histories[id]) > 4096 then console_histories[id] = string.sub(console_histories[id],string.len(console_histories[id])-4096) end
	
	if active_systems[id] ~= nil then
		-- TODO: limit updates per second
		local channel = minetest.get_meta(active_systems[id].pos):get_string("channel")
		--print("send print to "..channel)
		digiline:receptor_send(active_systems[id].pos, digiline.rules.default, channel, history_list(id))
		--digiline:receptor_send(active_systems[id].pos, digiline.rules.default,"dronetest:computer:"..id, console_histories[id])
	end
	
	dronetest.log("system "..id.." generated output: "..msg)
end

events.send_by_id = function(id,event)
	if active_systems[id] ~= nil then
		table.insert(active_systems[id].events,table.copy(event))
	else
		return false
	end
	return true
end

events.send = function(pos,event)
	local meta = minetest.get_meta(pos)
	local id = meta:get_int("id")
	return send_by_id(id,event)
end

events.send_all = function(event)
	local count = 0
	for id,s in pairs(active_systems) do
		if send_by_id(id,event) then
			count = count + 1
		end
	end
	return count
end

events.receive = function(id,filter,channel,msg_id)
	if active_systems[id] == nil or #active_systems[id].events == 0 then
		return nil
	end
	if #filter > 0 then
		for i,e in pairs(active_systems[id].events) do
			for j,f in pairs(filter) do
				if e.type ~= nil and e.type == f then
					if e.type == "digiline" and channel ~= nil and type(e.channel) == "string" and channel ~= e.channel 
					and (msg_id == nil or (type(e.msg)=="table" and type(e.msg.msg_id) == "string" and e.msg.msg_id ~= msg_id)) then
					else
						table.remove(active_systems[id].events,i)
						return e
					end
				end
			end
		end
		return nil
	end
	local event = active_systems[id].events[1]
	table.remove(active_systems[id].events,1)
	return event
end

function sleep(seconds)
	local start = minetest.get_gametime()
	while minetest.get_gametime() - start < seconds do
		coroutine.yield()
	end
end

-- Load bootstrap code once
local bootstrap = readFile(mod_dir.."/bootstrap.lua")
local err = ""
if type(bootstrap) ~= "string" then minetest.log("error","missing or unreadable bootstrap!") return false end

-- Sys userspace API
local sys = {}
sys = {}
sys.id = 0
sys.last_msg_id = 0
sys.yield = coroutine.yield
sys.getTime = function()
	return minetest.get_gametime()
end
function sys:receiveEvent(filter)
	if filter == nil then
		filter = {}
	end
	return events.receive(self.id,filter)
end
function sys:sendEvent(event)
	return events.send_by_id(self.id,event)
end
function sys:receiveDigilineMessage(channel,msg_id)
	local e = events.receive(self.id,{"digiline"},channel,msg_id)
	if e == nil then return nil end
	print("COMPUTER #"..dump(self.id).." received digilines event on channel: "..channel.." "..dump(e))
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
	local api = readFile(mod_dir.."/rom/apis/"..name..".lua", sandbox)
	local err = ""
	if type(api) ~= "string" or api == "" then minetest.log("error","missing, unreadable or empty api '"..name.."'!") error("missing, unreadable or empty api '"..name.."'!") return false end
	api,err = loadstring(api)
	if type(api) ~= "function" or err ~= nil then minetest.log("error","bad api '"..name.."': "..err)  error("bad api '"..name.."'!") return false end
	return api
end
--local function 
sys.loadApi = function(name)
	local api = getApi(name, sys.sandbox)
	local env_save = table.copy(userspace_environment)
	local env_global = getfenv(api)
	
	-- No! Use a metatable __index instead!
	for k,v in pairs(env_global) do 
		if env_save[k] == nil then env_save[k] = v end 
	--	print("API ENV for '"..name.."': "..k..": "..type(v))
	end
	
	-- Make drone/computer's env available to APIs, with id and stuff
	--env_save.dronetest = getfenv(0).dronetest
	env_save.sys = getfenv(2).sys
	env_save.print = function(msg) dronetest.print(env_save.sys.id,msg) end
	setfenv(api,env_save)
	return api()
end

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

userspace_environment = {ipairs=ipairs,pairs=pairs,print=print}
userspace_environment.mod_name = mod_name
userspace_environment.mod_dir = mod_dir
userspace_environment.dump = dump
userspace_environment.type = type
userspace_environment.count = count

userspace_environment.table = table
userspace_environment.string = string
userspace_environment.math = math

-- sandboxed stuff can only getfenv things it setfenv'ed
function userspace_environment.getfenv(f)
	-- currently disabled with 'false and' because untested
	if false and not fenv_whitelist[f] then return nil end
	return getfenv(f)
end

-- this probably doesn't need to be sandboxed - if a system ruins one of its fenvs, that's its own loss
function userspace_environment.setfenv(f, env)
	fenv_whitelist[f] = true
	return setfenv(f, env)
end

-- sandboxed stuff can only getmetatable things it setmetatable'ed
function userspace_environment.getmetatable(t, mt)
	-- currently disabled with 'false and' because untested
	if false and not metatable_whitelist[t] then return nil end
	return getmetatable(t, mt)
end

-- this probably doesn't need to be sandboxed - if a system ruins one of its metatables, that's its own loss
function userspace_environment.setmetatable(t, mt)
	metatable_whitelist[t] = true
	return setmetatable(t, mt)
end

--userspace_environment.loadfile = loadfile
userspace_environment.pcall = pcall
userspace_environment.xpcall = xpcall
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
	local f,err = loadfile(s)
	if f == nil then
		print(err)
		return nil,err
	end
	setfenv(f,getfenv(1))
	return f,""
end

userspace_environment.loadstring = function(s)
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


function timeout()
	print("SUCH TIMEOUT! VERY WAIT! MUCH SLOW!")
	coroutine.yield()
end

local function activate_by_id(id,t,pos)
	if pos == nil then pos = {x=0,y=0,z=0} end
	if t == nil then t = "drone" end
	-- http://lua-users.org/wiki/SandBoxes
	local env = table.copy(userspace_environment)
	env.getId = function() return id end
	
	env.sys = table.copy(sys)
	-- HORRIBLE PLACE TO PUT ID
	env.sys.id = 1+id-1
	-- HORRIBLE PLACE TO PUT SANDBOX PATH
	env.sys.sandbox = env.mod_dir.."/"..id
	local meta = minetest.get_meta(pos)
	env.sys.channel = meta:get_string("channel")
	env.sys.type = t
	
	-- overload print function to print to drone/computer's screen and not to servers stdout
	env.print = function(msg) dronetest.print(id,msg) end

	local bootstrap,err = loadstring(bootstrap)
	if type(bootstrap) ~= "function" then minetest.log("error","bad bootstrap: "..err) error("bad bootstrap: "..err) end
	
	env._G = env
	jit.off(bootstrap,true)
	setfenv(bootstrap,env)
	function error_handler(err)
		dronetest.print(id,"ERROR: "..dump(err))
		print("INTERNALERROR: "..dump(err)..dump(debug.traceback()))
	end
	--local cr = coroutine.create(function() xpcall(function() debug.sethook(timeout,"",100) bootstrap() end,error_handler) end)
	local cr = coroutine.create(function() xpcall(bootstrap,error_handler) end)
	--debug.sethook(cr,function () coroutine.yield() end,"",100)
	
	active_systems[id] = {coroutine_handle = cr,events = {},type=t,id=id,pos=pos,last_update = minetest.get_gametime()}
	
	dronetest.log("STATUS: "..coroutine.status(active_systems[id].coroutine_handle))
	dronetest.log("TYPE: "..type(active_systems[id]))

	dronetest.log("System #"..id.." has been activated, now "..count(active_systems).." systems active.")
	dronetest.print(id,"System #"..id.." has been activated.")
	return true
end
local function activate(pos)
	local meta = minetest.get_meta(pos)
	local id = meta:get_int("id")
	meta:set_int("status",1)
	return activate_by_id(id,"computer",pos)
end

local function deactivate_by_id(id)
	
	dronetest.print(id,"System #"..id.." deactivating.")
	active_systems[id] = nil
	dronetest.log("System #"..id.." has been deactivated.")
	
	return true
end
local function deactivate(pos)
	
	local meta = minetest.get_meta(pos)
	local id = meta:get_int("id")
	meta:set_int("status",0)
	return deactivate_by_id(id)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	dronetest.log("minetest.register_on_player_receive_fields received '"..formname.."'")
	local key = {formname:match("([^:]+):([^:]+):([^:]+)")}
		
	-- Handle a drone's menu
	if #key==3 and key[1] == "dronetest" and key[2] == "drone" then --
		local id = tonumber(key[3])
		if (fields["quit"] == true and fields["input"] == "") or fields["exit"] ~= nil then
			return false
		elseif fields["channel"] ~= nil then
			dronetest.drones[id].channel = fields.channel
		end
		return true
	-- handle computer's menu in node's handler
	elseif formname == "dronetest:computer" then -- apply config changes from menu
		dronetest.log("skipping handler for computer")
		return false -- return false to allow next handler to take this
		
	-- apply config changes from config-menu
	elseif formname == "dronetest:menu" then 
		for i,v in pairs(dronetest) do
			local t = type(v)
			if t == "string" or t == "number" or t == "boolean" then
				if fields["dronetest:"..i] then
					if t == "string" then 
						dronetest[i] = fields["dronetest:"..i] 
					elseif t == "number" then 
						dronetest[i] = tonumber(fields["dronetest:"..i]) 
					elseif t == "boolean" then 
						if fields["dronetest:"..i] == "true" then dronetest[i] = true end
						if fields["dronetest:"..i] == "false" then dronetest[i] = false end
					end
				end	
			end
		end
		save()
	end
	return false
end)


-- TODO: i don't think this is needed in lua...
minetest.register_on_shutdown(function() active_systems = {} end)

local timer = 0
minetest.register_globalstep(function(dtime)
	local co
	local id
	local s
	timer = timer + dtime;
	if timer >= dronetest.globalstep_interval then
		--minetest.chat_send_all("dronetest globalstep @"..timer.." with "..count(active_systems).." systems.")
		for id,s in pairs(active_systems) do
			co = s.coroutine_handle
			--dronetest.log("Tic drone #"..id..". "..coroutine.status(co))
			-- TODO: some kind of timeout?!
			if coroutine.status(co) == "suspended" then
				debug.sethook(co,coroutine.yield,"",dronetest.max_userspace_instructions)
				local ret = {coroutine.resume(co)}
			--	dronetest.log("Computer "..id.." result:"..dump(ret))
				s.last_update = minetest.get_gametime()
				
			else
				-- System ended
				--dronetest.log("System # "..id.." coroutine status: "..coroutine.status(co))
				dronetest.log("System #"..id.."'s main process has ended! Restarting soon...")
				active_systems[id] = nil
			end
		end
		timer = 0
	end
end)

minetest.register_abm({
	nodenames = {"dronetest:computer"},
	interval = 1,
	chance = 1,
	action = function(pos)
		--for id,drone in pairs(dronetest.drones) do
		--	print("active drone: "..id.." "..dump(drone))
		--end
	
		-- this is now in dronetest.print, where it should be
		--[[
		local meta = minetest.get_meta(pos)
		if meta:get_int("status") == 1 then	
			print("SEND")
			digiline:receptor_send(pos, digiline.rules.default,meta:get_string("channel"),history_list(meta:get_int("id")))
		end
		--]]
		-- Activate systems that were active when the game was closed last time.
		-- or that may have crashed strangely
		local meta = minetest.get_meta(pos)
		if meta:get_int("status") == 1 and active_systems[meta:get_int("id")] == nil then
			console_histories[meta:get_int("id")] = ""
			activate(pos)
		end
	end,
})




local drone = {
	hp_max = 1,
	weight = 5,
	is_visible = true,
	makes_footstep_sound = false,
        physical = true,
        collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	visual_size = {x=0.9, y=0.9},
	textures = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png",  "turtle.png", "computerSide.png",},
	automatic_rotate = false,
        driver = nil,
	channel = "dronetest:drone:"..0,
	menu = false,
	id = 0,
	status = 0,
        removed = false,
}

function drone.on_rightclick(self, clicker)
        if not clicker or not clicker:is_player() then
                return
        end
	--self.menu = true
	minetest.show_formspec(clicker:get_player_name(), "dronetest:drone:"..self.id, get_drone_formspec(self.id,self.channel))
end



local steps = 10
local rad2unit = 1 / (2*3.14159265359)
local function yaw2dir(yaw)
	local dir = yaw * rad2unit
	if dir > 0.875 or dir <= 0.125 then return 0 
	elseif dir > 0.125 and dir <= 0.375 then return 1 
	elseif dir > 0.375 and dir <= 0.625 then return 2
	else return 3 end
end

local function snapRotation(r)
	while r < 0 do r = r + (1/rad2unit) end
	while r > 1/rad2unit do r = r - (1/rad2unit) end
	r = r * rad2unit
	r = math.round(r * 4) / 4
	r = r / rad2unit
	return r
end

local function drone_check_target(pos)
	local node = minetest.get_node(pos)
	if node ~= nil and node.name ~= "air" then
		print("CHECK TARGET: node")
		return false,"node"
	end
	--print(dump(minetest.env))
	local objs = minetest.get_objects_inside_radius(pos, 0.5)
	--print(dump(objs))
	--return true
	---[[
	for i,o in ipairs(objs) do
		print("CHECK TARGET: object: "..o:get_luaentity().name.." "..dump(o).." "..dump(o:get_luaentity().physical))
		if o:get_luaentity().physical then
			print("CHECK TARGET: object")
			return false,"object"
		end
		
	end
	print("CHECK TARGET: clear @ "..dump(pos))
	return true
	--]]
end

local BLOCKSIZE = 16
local function get_blockpos(pos)
	return {
		x = math.floor(pos.x/BLOCKSIZE),
		y = math.floor(pos.y/BLOCKSIZE),
		z = math.floor(pos.z/BLOCKSIZE)}
end

function drone_move_to_pos(drone,target)
	local result,reason = drone_check_target(target)
	if not result then return result,reason end
	
	local pos = drone.object:getpos()
	
	local dir = target
	dir.x = dir.x - pos.x
	dir.y = dir.y - pos.y
	dir.z = dir.z - pos.z
	local old = pos
	for i=1,steps,1 do
		pos.x = pos.x + dir.x/steps
		pos.y = pos.y + dir.y/steps
		pos.z = pos.z + dir.z/steps
		drone.object:moveto(pos,true)
		coroutine.yield()
	end
	if get_blockpos(old) ~= get_blockpos(pos) then
		minetest.forceload_block(pos)
		minetest.forceload_free_block(old)
	end
	return true
end
function drone_suck(drone,target,inv)
	-- TODO: enable sucking items out of other drones too
	-- search detached inventories for that? target if drone first
	print("drone will try to suck from "..dump(target).." ("..dump(drone.object:getpos())..")")
	-- this is for chests and the like
	local ninv = minetest.get_inventory({type="node",pos=target})
	if ninv == nil then
		print("No inventory in that spot to suck from!")
		return false
	end
	
	local lists = ninv:get_lists()
	local item = nil
	
	if inv ~= nil then
		if lists[inv] ~= nil then 
			lists = {inv=lists[inv]} 
		else
			print("No such list in that inventory!")
			return false
		end
	end
	-- Just take the first item in the list, if any
	for il,l in pairs(lists) do
		for ii,i in pairs(l) do
			if i:get_count() > 0 then
				item = i:take_item()
				ninv:set_stack(il,ii,i)
			end
			if item ~= nil then
				break
			end
		end
		if item ~= nil then
			break
		end
	end
	
	if item ~= nil then
		--print("GOT "..item:get_name())
		local oinv = minetest.get_inventory({type="detached",name="dronetest_drone_"..drone.id})
		oinv:add_item("main",item)
		return true,item:get_name()
	end
	return false
end
function drone_get_forward(drone)
	local pos = drone.object:getpos()
	local yaw = drone.object:getyaw()
	local dir = yaw2dir(snapRotation(yaw))
	if dir == 0 then dir = 2 
	elseif dir == 2 then dir = 0 end
	local target = minetest.facedir_to_dir(dir)
	target.x = pos.x - target.x 
	target.y = pos.y - target.y 
	target.z = pos.z - target.z 
	return target
end
function drone_get_back(drone)
	local pos = drone.object:getpos()
	local yaw = drone.object:getyaw()
	local dir = yaw2dir(snapRotation(yaw))
	dir = dir + 2
	if dir > 3 then dir = dir - 4 end
	if dir == 0 then dir = 2 
	elseif dir == 2 then dir = 0 end
	local target = minetest.facedir_to_dir(dir)
	target.x = pos.x - target.x 
	target.y = pos.y - target.y 
	target.z = pos.z - target.z 
	return target
end
function drone_get_up(drone)
	local pos = drone.object:getpos()
	local target = table.copy(pos)
	target.y = target.y + 1
	return target
end
function drone_get_down(drone)
	local pos = drone.object:getpos()
	local target = table.copy(pos)
	target.y = target.y - 1
	return target
end
-- the drone's actions are different in that they all take the drone's id as first parameter, and a print-callback as the second.
dronetest.drone_actions = {
	test = {desc="a test",func=function(id,print) print("TEST") end},
	turnLeft = {desc="Rotates the drone to the left.",
		func=function(id,print)
			local d = dronetest.drones[id]
			local r = d.object:getyaw() 
			local rot = (0.25 / rad2unit) / steps
			r = snapRotation(r)
			for i=1,steps,1 do
				r = r + rot
				d.object:setyaw(r)
				coroutine.yield()
			end
		end},
	turnRight = {desc="Rotates the drone to the right.",
		func = function(id,print)
			local d = dronetest.drones[id]
			local r = d.object:getyaw() 
			local rot = (-0.25 / rad2unit) / steps
			r = snapRotation(r)
			for i=1,steps,1 do
				r = r + rot
				while r < 0 do r = r + 2*3.14159265359 end
				d.object:setyaw(r)
				coroutine.yield()
			end
		end},
	up = {desc="Moves the drone up.",
		func = function(id,print)
			local d = dronetest.drones[id]
			local target = drone_get_up(d)
			return drone_move_to_pos(d,target)
		end},
	down = {desc="Moves the drone down.",
		func = function(id,print)
			local d = dronetest.drones[id]
			local target = drone_get_down(d)
			return drone_move_to_pos(d,target)
		end},
	forward = {desc="Moves the drone forward.",
		func = function(id,print)
			local d = dronetest.drones[id]
			local target = drone_get_forward(d)
			return drone_move_to_pos(d,target)
		end},
	back = {desc="Moves the drone back.",
		func = function(id,print)
			local d = dronetest.drones[id]
			local target = drone_get_back(d)
			return drone_move_to_pos(d,target)
		end},
	suck = {desc="Sucks an item out of an inventory in front of the drone.",
		func = function(id,print,inv)
			local d = dronetest.drones[id]
			local target = drone_get_forward(d)
			return drone_suck(d,target,inv)
		end},
	suckUp = {desc="Sucks an item out of an inventory above the drone.",
		func = function(id,print,inv)
			local d = dronetest.drones[id]
			local target = drone_get_up(d)
			return drone_suck(d,target,inv)
		end},
	suckDown = {desc="Sucks an item out of an inventory below the drone.",
		func = function(id,print,inv)
			local d = dronetest.drones[id]
			local target = drone_get_down(d)
			return drone_suck(d,target,inv)
		end},
	place = {desc="Places stuff from inventory in front of drone.",func=function() end},
	placeUp = {desc="Places stuff from inventory above drone.",func=function() end},
	placeDown = {desc="Places stuff from inventory below drone.",func=function() end},
	drop = {desc="Places stuff from inventory in front of drone.",func=function() end},
	dropUp = {desc="Places stuff from inventory above drone.",func=function() end},
	dropDown = {desc="Places stuff from inventory below drone.",func=function() end},
	detect = {desc="Places stuff from inventory in front of drone.",func=function() end},
	detectUp = {desc="Places stuff from inventory in front of drone.",func=function() end},
	detectDown = {desc="Places stuff from inventory in front of drone.",func=function() end},
	
}

-- drones receive digiline messages only through transceivers, when responding to those messages,
-- they act as if the transceiver would respond, meaning transceivers are actually just transmitters,
-- but act like transceivers to the player.
function drone.on_digiline_receive_line(self, channel, msg, senderPos)
	if type(msg) ~= "table" or type(msg.action) ~= "string" then return end
	print("DRONE "..self.id.." received digiline channel: "..channel.." action: "..msg.action)
	if channel ~= self.channel then return end
	
	if type(msg) == "table" and type(msg.action) == "string" then
		local pos = self.object:getpos()
		if msg.action == "GET_CAPABILITIES"  and type(msg.msg_id) == "string" then
			local cap = {}
			for n,v in pairs(dronetest.drone_actions) do
				cap[n] = v.desc
			end
			print("DRONE "..self.id.." responds channel: "..channel.." action: "..msg.action)
			-- act as if transceiver would send the message
			
			-- send capabilities -- act as if transceiver would send the message
			digiline:receptor_send(senderPos, digiline.rules.default,channel, {action = "CAPABILITIES",msg_id = msg.msg_id,msg = cap })
			return
		elseif dronetest.drone_actions[msg.action] ~= nil then
			if msg.argv == nil or type(msg.argv) ~= "table" then msg.argv = {} end
			if dronetest.drones[self.id] == nil then print("drone #"..self.id.." not reachable!") return end
			print("drone #"..self.id.." will execute "..msg.action.." from "..channel..".")
		--	print("PRE: "..dump(dronetest.drones[self.id]).." "..type(self.id))
			-- execute function
			local response = {dronetest.drone_actions[msg.action].func(self.id,msg.print,msg.argv[1],msg.argv[2],msg.argv[3],msg.argv[4],msg.argv[5])}
			--local response = {true}
			print("drone #"..self.id.." finished action '"..msg.action.."': "..dump(response))
			print("drone #"..self.id.." will answer on "..channel..".")
			
			-- send response -- act as if transceiver would send the message
			digiline:receptor_send(senderPos, digiline.rules.default,channel, {action = msg.action ,msg_id = msg.msg_id,msg = response })
			return
		end
	end
end

local rad2unit = 1 / (2*3.14159265359)
function drone.on_activate(self, staticdata, dtime_s)
        self.object:set_armor_groups({immortal=1})
	local pos = self.object:getpos()
        if type(staticdata) == "string" and #staticdata > 0 then
		
		local data = minetest.deserialize(staticdata)
		if type(data) == "table" then
			self.id = data.id
			self.status = data.status
			self.channel = data.channel
			self.yaw = data.yaw
			self.inv = data.inv
			print("re-activate drone "..self.id.." ..")
			
			-- Snap rotation, drone may have been shut down while rotating
			local r = self.object:getyaw()
			r = math.round(r * rad2unit * 4) / 4
			if r > 3 then r = 0 end
			r = r / rad2unit
			self.object:setyaw(r)
			
			print("add drone "..self.id.." to list. "..type(self.id))
			dronetest.drones[self.id] = self.object:get_luaentity()
		else
			self.yaw = 0
			self.id = -1
			self.channel = "dronetest_error"
			self.status = -1
			error("corrupted drone!")
		end
	else
		dronetest.last_drone_id = dronetest.last_drone_id + 1
		self.id = dronetest.last_drone_id
		self.status = 0
		self.yaw = 0
		self.channel = "dronetest:drone:"..self.id
		print("activate drone "..self.id.." ..")
		
	--	minetest.add_node(pos,"dronetest:drone_virtual")
        end
	if type(self.yaw) ~= "number" then self.yaw = 0 end
	
	-- it seems Lua SAOs do not have an inventory... [https://forum.minetest.net/viewtopic.php?p=71994&sid=c4fe3123d7370bdc1ebe56785fa85905#p71994]
		-- maybe use a detached inventory for each drone and store it as staticdata?

	-- TODO: do detached invs get removed automatically? do they get saved?
	local inv = minetest.create_detached_inventory("dronetest_drone_"..self.id,{})
	if inv == nil or inv == false then
		error("Could not spawn inventory for drone.")
	end
	inv:set_size("main", 4*4)
	if self.inv ~= nil then
		inv.set_lists(self.inv)
	end
	self.inv = inv
	
	-- align position with grid
	
	pos.x = math.round(pos.x)
	pos.y = math.round(pos.y)
	pos.z = math.round(pos.z)
	self.object:setpos(pos)
	self.object:setyaw(snapRotation(self.yaw))
	--print("Add drone "..self.id.." to list.")
	
	
	-- TODO: we need to somehow remove these when drones get removed, but there is no on_deactivate handler yet i think
	--table.insert(dronetest.drones,self.id,self)
	save()
end

function drone.get_staticdata(self)
	local data = {}
	data.id = self.id
	data.status = self.status
	data.channel = self.channel
	data.yaw = self.object:getyaw()
        return minetest.serialize(data)
end

function drone.on_punch(self, puncher, time_from_last_punch, tool_capabilities, direction)
        if not puncher or not puncher:is_player() or self.removed then
                return
        end
end
--[[
function drone.on_step(self, dtime)
	local text = history_list(self.id)
	local tmp = table.copy(drone)
	tmp.textures = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", dronetest.generate_texture(dronetest.create_lines(text)), "turtle.png"}
	self.object:set_properties(tmp)

end
--]]

minetest.register_entity("dronetest:drone", drone)

-- Helper-node which does nothing but spawn a drone entity, 
-- this is what the player crafts in order to get a drone.
minetest.register_node("dronetest:drone", {
	description = "Spawns a drone.",
	tiles = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", "computerSide.png", "turtle.png"},
	paramtype2 = "facedir",
	groups = {choppy=2,oddly_breakable_by_hand=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		dronetest.log("Drone spawner placed at "..minetest.pos_to_string(pos))
		local d = minetest.add_entity(pos,"dronetest:drone")
		d = d:get_luaentity()
		print("add drone "..d.id.." to list.")
		dronetest.drones[d.id]=d
		--print("SPAWNED DRONE "..dronetest.last_drone_id.." "..dump())
		minetest.remove_node(pos)
	end,
	can_dig = function(pos,player)
		return false
	end,
})



minetest.register_node("dronetest:computer", {
	description = "A computer.",
	--tiles = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", "computerSide.png", dronetest.generate_texture(dronetest.create_lines(testScreen))},
	tiles = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", "computerTop.png","computerTop.png",},
	
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 6,
	paramtype2 = "facedir",
	groups = {choppy=2,oddly_breakable_by_hand=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	
	
	digiline = {
		receptor = {},
		effector = {
			action = function(pos, node, channel, msg) -- add incoming digiline-msgs to event-queue
				local meta = minetest.get_meta(pos)
				--local setchan = meta:get_string("channel")
				--if setchan ~= channel then return end
				local id = meta:get_int("id")
				print("COMPUTER "..id.." received on "..channel.." "..dump(msg))
				events.send_by_id(id,{type="digiline",channel=channel,msg=msg})
			end
		},
	},
	mesecons = {effector = {
	--	rules = mesecon.rules,
		-- make mesecons.rule so we can use some sides of the node as input, and some as output?
		-- or should we make a special peripheral for that an the computers/drones can just be switched on with meseconsian energy?
		action_on = function (pos, node) print("mesecons on signal") end,
		action_off = function (pos, node) print("mesecons off signal") end,
		action_change = function (pos, node) print("mesecons toggle signal") end,
	}},
	on_construct = function(pos)
		dronetest.last_id = dronetest.last_id + 1
		local meta = minetest.get_meta(pos)
		local channel = "dronetest:computer:"..dronetest.last_id
		meta:set_int("id",dronetest.last_id )
		meta:set_string("formspec",get_computer_formspec(dronetest.last_id,channel))
		meta:set_string("infotext", "Computer #"..dronetest.last_id )
		meta:set_int("status",0)
		meta:set_string("channel",channel)
		mkdir(mod_dir.."/"..dronetest.last_id)
		dronetest.log("Computer #"..dronetest.last_id.." constructed at "..minetest.pos_to_string(pos))		
		if not minetest.forceload_block(pos) then
			dronetest.log("WARNING: Could not forceload block at "..dump(pos)..".")
		end
		save() -- so we remember the changed last_id in case of crashes
	end,
	on_destruct = function(pos, oldnode)
		deactivate(pos)
		minetest.forceload_free_block(pos)
	end,
	on_event_receive = function(event)
		
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		dronetest.log("on_receive_fields received '"..formname.."'")
		local id = meta:get_int("id")
		if fields["channel"] ~= nil then
			meta:set_string("channel",fields.channel)
		end
		if fields["clear"] ~= nil then
			console_histories[id] = ""
			minetest.chat_send_player(sender:get_player_name(),"system #"..id..": screen cleared and redrawn.")
		elseif fields["redraw"] ~= nil then
			minetest.chat_send_player(sender:get_player_name(),"system #"..id..": screen redrawn.")
		elseif fields["poweron"] ~= nil then
			if meta:get_int("status") ~= 1 then
				activate(pos)
			end
			minetest.chat_send_player(sender:get_player_name(),"system #"..id.." activated, now "..count(active_systems).." systems online.")
		elseif fields["poweroff"] ~= nil then
			if meta:get_int("status") ~= 0 then
				deactivate(pos)
			end
			minetest.chat_send_player(sender:get_player_name(),"system #"..id.." deactivated, now "..count(active_systems).." systems online.")
		elseif fields["input"] ~= nil and fields["input"] ~= "" then
			dronetest.log("command: "..fields["input"])
			local id = meta:get_int("id")
			if active_systems[id] ~= nil then
				if not events.send_by_id(id,{type="input",msg=fields["input"]}) then
					minetest.log("error","could not queue event")
				end
				dronetest.log("system "..id.." now has "..#active_systems[id].events.." events.")
			else
				minetest.chat_send_player(sender:get_player_name(),"Cannot exec, activate system first.")
			end
		elseif fields["quit"] == true then
			return true
		end
		
		redraw_computer_formspec(pos,sender)
		return true
	end,
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		dronetest.log("Computer #"..meta:get_int("id").." has been rightclicked at "..minetest.pos_to_string(pos)..", status: "..meta:get_int("status"))
		minetest.show_formspec(player:get_player_name(), "dronetest:computer", meta:get_string("formspec"))

	end,
	on_punch = function(pos, node, puncher, pointed_thing)
		dronetest.log("Computer has been punched at "..minetest.pos_to_string(pos))
	end,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		dronetest.log("Computer placed at "..minetest.pos_to_string(pos))
		
	end,
	can_dig = function(pos,player)
		-- Diggable only if deactivated
		local meta = minetest.get_meta(pos);
		local id = meta:get_int("id")
		if active_systems[id] ~= nil then return false end
		return true;
	end,
})

-- Some message that the mod has loaded/unloaded
if minetest.setting_getbool("log_mods") then
	minetest.register_on_shutdown(function() minetest.log("action", "[MOD] "..mod_name.." -- unloaded!") end)
	minetest.log("action","[MOD] "..minetest.get_current_modname().." -- loaded!")
end


--[[

local f = function() 

	local f = function() 
		local i
		for i = 1,1000000,1 do
			print("AHA! "..i)
		--	coroutine.yield()
		end
	end
	--jit.off(f,true)
	local co = coroutine.create(function() xpcall(f,print) end)

	while coroutine.status(co) == "suspended" do 
	--	debug.sethook(co,coroutine.yield,"",dronetest.max_userspace_instructions)
		coroutine.resume(co) 
	end

end
jit.off(f,true)
setfenv(f,getfenv(1))

local co = coroutine.create(function() xpcall(f,print) end)

while coroutine.status(co) == "suspended" do 
	debug.sethook(co,coroutine.yield,"",dronetest.max_userspace_instructions)
	coroutine.resume(co) 
end
--]]
