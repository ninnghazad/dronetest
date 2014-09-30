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



--[[
local maxInst = 1000000
local function yield() print("yield") coroutine.yield() end
local function t() while true do end end
setfenv(t,getfenv(1))


for i = 1, 10, 1 do
print("cross-yield-hook test 1: coroutine yield per hook")
local co = coroutine.create(t)
while true do
	local status = coroutine.status(co)
	print("status "..status)
	if status == "suspended" then
		print("resume "..status)
		debug.sethook(co,yield,"",maxInst)
		coroutine.resume(co)
		debug.sethook(co)
	elseif status == "dead" then
		print("dead "..status)
		co = nil
		break
	end
end
end
print("ok")

for i = 1, 100, 1 do
print("cross-yield-hook test 2: coroutine yield per hook, through pcall")
local co = coroutine.create(function() pcall(t) end)
while true do
	local status = coroutine.status(co)
	print("status "..status)
	if status == "suspended" then
		print("resume "..status)
		debug.sethook(co,yield,"",maxInst)
		coroutine.resume(co)
		debug.sethook(co)
	elseif status == "dead" then
		print("dead "..status)
		co = nil
		break
	end
end
end
print("ok")
--jit.on()
--]]
function is_filename(filename)
	if string.find(filename,"..",1,true) ~= nil then
		return false
	end
	return true
end
function readFile(file)
	if not is_filename(file) then
		return ""
	end
	local f = io.open(file, "rb")
	if not f then
		return ""
	end
	local content = f:read("*all")
	f:close()
	return content
end

function writeFile(file,str)
	if not is_filename(file) then
		return false
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
	globalstep_interval = 0.01,
	drones = {},
	log = function(msg) minetest.log("action","dronetest: "..msg) end,
}

--Config documentation, items that have one get save in config and can be changed by menu
local doc = {
	last_id = "The last id given to a computer or drone.",
	globalstep_interval = "Interval to run LUA-coroutines at.",
}

local function count(t)
	local n = 0
	for k,v in pairs(t) do
		n = n + 1
	end
	return n
end
function table.copy(t, deep, seen)
    seen = seen or {}
    if t == nil then return nil end
    if seen[t] then return seen[t] end

    local nt = {}
    for k, v in pairs(t) do
        if deep and type(v) == 'table' then
            nt[k] = table.copy(v, deep, seen)
        else
            nt[k] = v
        end
    end
    setmetatable(nt, table.copy(getmetatable(t), deep, seen))
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



local function history_list(id)
	if console_histories[id] == nil then
		-- TODO: put some nifty ascii-art as default screen?!?
		return "###### P R E S S   O N   T O   S T A R T   S Y S T E M #####\n"
	end
	local s = ""
	for i,v in pairs(console_histories[id]) do
		if i >= math.max(0,#console_histories[id] - 22) then
			
			s = s..""..v.."\n"
		end
	end
	s = s.." "
	return s
end

local function get_drone_formspec(id)
	local formspec =
		"size[13,9]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"list[detached:dronetest_drone_"..id..";main;9,5.3;4,4;]"..
		"list[current_player;main;0,5.3;8,1;]"..
		"list[current_player;main;0,6.3;8,3;8]"..
		"textarea[0.3,0.0;13,5;output;;"..history_list(id).."]"..
		"field[0.3,4.6;13,1;input;;]"..
		"button[8,5.2;1,1;execute;EXE]"..
		"button[8,6.0;1,1;poweroff;OFF]"..
		"button[8,6.8;1,1;poweron;ON]"..
		"button_exit[8,7.6;1,1;exit;EXIT]"..
		"button[8,8.4;1,1;redraw;DRW]"
	return formspec
end
local function get_computer_formspec(id)
	local formspec =
		"size[13,9]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"textarea[0.3,0.0;13,9.7;output;;"..history_list(id).."]"..
		"field[0.3,8.7;9,1;input;;]"..
		"button[9,8.4;1,1;execute;EXE]"..
		"button[10,8.4;1,1;poweroff;OFF]"..
		"button[11,8.4;1,1;poweron;ON]"..
		--"button[13,7.6;1,1;clear;CLR]"..
		"button[12,8.4;1,1;redraw;DRW]"
	return formspec
end

local function redraw_computer_formspec(pos,player)
	local meta = minetest.get_meta(pos)
	local formspec = get_computer_formspec(meta:get_int("id"))
	meta:set_string("formspec",formspec)
	
--	minetest.show_formspec(player:get_player_name(),"dronetest:computer",formspec)
end

function dronetest.print(id,msg)
	if msg == nil then
		return
	end
	if console_histories[id] == nil then
		console_histories[id] = {}
	end
	table.insert(console_histories[id],minetest.formspec_escape(msg))
	dronetest.log("system "..id.." generated output: "..msg)
end

-- TODO: maybe events need to be deep-copied with table.copy ?!
-- not sure if the way it is allows users to change an event and have it change for other users also
-- however, users should never-ever change the events they receive...
events.send_by_id = function(id,event)
	if active_systems[id] ~= nil then
		table.insert(active_systems[id].events,event)
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

events.receive = function(id,filter)
	if active_systems[id] == nil or #active_systems[id].events == 0 then
		return nil
	end
	if #filter > 0 then
		for i,e in pairs(active_systems[id].events) do
			for j,f in pairs(filter) do
				if e.type ~= nil and e.type == f then
					table.remove(active_systems[id].events,i)
					return e
				end
			end
		end
		return nil
	end
	local event = active_systems[id].events[1]
	table.remove(active_systems[id].events,1)
	return event
end


-- Load bootstrap code once
local bootstrap = readFile(mod_dir.."/bootstrap.lua")
local err = ""
if type(bootstrap) ~= "string" then minetest.log("error","missing or unreadable bootstrap!") return false end
bootstrap,err = loadstring(bootstrap)
if type(bootstrap) ~= "function" then minetest.log("error","bad bootstrap: "..err) return false end

-- Sys userspace API
local sys = {}
sys = {}
sys.id = 0
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

function _makePath(path)
	if string.find(path,"..") then
		return ""
	end
	
	return mod_dir.."/"..sys.id.."/"..path
end

-- Gets an API as a string, used only wrapped in bootstrap.lua
-- TODO: is it possible to overload this from userspace? make sure it isn't
local function getApi(name)
	local api = readFile(mod_dir.."/rom/apis/"..name..".lua")
	local err = ""
	if type(api) ~= "string" or api == "" then minetest.log("error","missing, unreadable or empty api '"..name.."'!") error("missing, unreadable or empty api '"..name.."'!") return false end
	api,err = loadstring(api)
	if type(api) ~= "function" or err ~= nil then minetest.log("error","bad api '"..name.."': "..err)  error("bad api '"..name.."'!") return false end
	return api
end
--local function 
sys.loadApi = function(name)
	local api = getApi(name)
	local env_save = table.copy(userspace_environment)
	local env_global = getfenv(api)
	
	for k,v in pairs(env_global) do 
		if env_save[k] == nil then env_save[k] = v end 
	--	print("API ENV for '"..name.."': "..k..": "..type(v))
	end
	-- Make drone/computer's env available to APIs, with id and stuff
	env_save.sys = getfenv(2).sys
	env_save.print = function(msg) dronetest.print(env_save.sys.id,msg) end
	setfenv(api,env_save)
	return api()
end

-- Userspace Environment, this is available from inside systems
userspace_environment = {ipairs=ipairs,pairs=pairs,print=print}
userspace_environment.mod_name = mod_name
userspace_environment.mod_dir = mod_dir
userspace_environment.dump = dump
userspace_environment.type = type
userspace_environment.count = count

userspace_environment.table = table
userspace_environment.string = string
userspace_environment.math = math

userspace_environment.getfenv = getfenv
userspace_environment.setfenv = setfenv
--userspace_environment.loadfile = loadfile
userspace_environment.pcall = pcall
userspace_environment.xpcall = xpcall

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

local function activate_by_id(id,t)
	if t == nil then t = "drone" end
	-- http://lua-users.org/wiki/SandBoxes
	local env = table.copy(userspace_environment)
	env.getId = function() return id end
	
	env.sys = table.copy(sys)
	env.sys.id = 1+id-1
	env.sys.type = t
	
	-- overload print function to print to drone/computer's screen and not to servers stdout
	env.print = function(msg) dronetest.print(id,msg) end
	
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
	
	active_systems[id] = {coroutine_handle = cr,events = {},id=id,pos=pos,last_update = minetest.get_gametime()}
	
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
	return activate_by_id(id,"computer")
end

local function deactivate_by_id(id)
	active_systems[id] = nil
	dronetest.log("Drone #"..id.." has been deactivated.")
	dronetest.print(id,"drone #"..id.." has been deactivated.")
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
			dronetest.drones[id].menu = false
			return false
		elseif fields["clear"] ~= nil then
			console_histories[id] = {}
			minetest.chat_send_player(player:get_player_name(),"Screen cleared and redrawn.")
		elseif fields["redraw"] ~= nil then
			--console_histories[id] = {}
			minetest.chat_send_player(player:get_player_name(),"Screen redrawn.")
		elseif fields["poweron"] ~= nil then
			if dronetest.drones[id].status ~= 1 then
				activate_by_id(id)
				dronetest.drones[id].status = 1
			end
			minetest.chat_send_player(player:get_player_name(),"system #"..id.." activated, now "..count(active_systems).." systems online.")
		elseif fields["poweroff"] ~= nil then
			if dronetest.drones[id].status ~= 0 then
				deactivate_by_id(id)
				dronetest.drones[id].status = 0
			end
			minetest.chat_send_player(player:get_player_name(),"system #"..id.." deactivated, now "..count(active_systems).." systems online.")
		elseif fields["input"] ~= nil and fields["input"] ~= "" then
			dronetest.log("command: "..fields["input"])
			local id = id
			if active_systems[id] ~= nil then
				if not events.send_by_id(id,{type="input",msg=fields["input"]}) then
					minetest.log("error","could not queue event")
				end
				dronetest.log("system "..id.." now has "..#active_systems[id].events.." events.")
			else
				minetest.chat_send_player(player:get_player_name(),"Cannot exec, activate system first.")
			end
		end
		if dronetest.drones[id].menu then
			minetest.show_formspec(player:get_player_name(), "dronetest:drone:"..id, get_drone_formspec(id))
		end
		return true
		
	-- handle computer's menu in node's handler
	elseif formname == "dronetest:computer" then -- apply config changes from menu
		dronetest.log("skipping handler for computer")
		return false
		
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
	end
	return true
end)


-- TODO: i don't think this is needed in lua...
minetest.register_on_shutdown(function() active_systems = {} end)

local timer = 0
minetest.register_globalstep(function(dtime)
	local co
	timer = timer + dtime;
	if timer >= dronetest.globalstep_interval then
		minetest.chat_send_all("dronetest globalstep @"..timer.." with "..count(active_systems).." systems.")
		for id,s in pairs(active_systems) do
			co = s.coroutine_handle
			--dronetest.log("Tic drone #"..id..". "..coroutine.status(co))
			-- TODO: some kind of timeout?!
			if coroutine.status(co) == "suspended" then
				debug.sethook(co,coroutine.yield,"",1000000)
				coroutine.resume(co)
				s.last_update = minetest.get_gametime()
			else
				-- System ended
				dronetest.log("System #"..id.."'s main process has endet! Restarting soon...")
				active_systems[id] = nil
			end
		end
		timer = 0
	end
end)

minetest.register_abm({
	nodenames = {"dronetest:drone"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local meta = minetest.get_meta(pos)
		-- make sure nodes that where active are reactivated on server start
		if meta:get_int("status") == 1 and active_systems[meta:get_int("id")] == nil then
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
	--tiles = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", "computerSide.png", "turtle.png"},
	textures = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", "computerSide.png", "turtle.png"},
	
        --visual = "mesh",
	--visual_size = {x=0.5, y=0.5},
        --mesh = "boat.x",
        --textures = {"computerTop.png"},
	automatic_rotate = false,
        driver = nil,
	menu = false,
	id = 0,
	status = 0,
        removed = false,
}

function drone.on_rightclick(self, clicker)
        if not clicker or not clicker:is_player() then
                return
        end
	self.menu = true
	minetest.show_formspec(clicker:get_player_name(), "dronetest:drone:"..self.id, get_drone_formspec(self.id))
end
local rad2unit = 1 / (2*3.14159265359)
function drone.on_activate(self, staticdata, dtime_s)
        self.object:set_armor_groups({immortal=1})
        if type(staticdata) == "string" and #staticdata > 0 then
		
		local data = minetest.deserialize(staticdata)
		if type(data) == "table" then
			self.id = data.id
			self.status = data.status
			self.yaw = data.yaw
			self.inv = data.inv
			print("re-activate drone "..self.id.." ..")
			
			-- Snap rotation, drone may have been shut down while rotating
			local r = self.object:getyaw()
			r = math.round(r * rad2unit * 4) / 4
			if r > 3 then r = 0 end
			r = r / rad2unit
			self.object:setyaw(r)
		else
			self.yaw = 0
			self.id = -1
			self.status = -1
			error("corrupted drone!")
		end
	else
		dronetest.last_id = dronetest.last_id + 1
		self.id = dronetest.last_id
		self.status = 0
		self.yaw = 0
		print("activate drone "..self.id.." ..")
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
	local pos = self.object:getpos()
	pos.x = math.floor(pos.x)
	pos.y = math.floor(pos.y)
	pos.z = math.floor(pos.z)
	self.object:setpos(pos)
	self.object:setyaw(self.yaw)
	print("Add drone "..self.id.." to list.")
	
	-- TODO: we need to somehow remove these when drones get removed, but there is no on_deactivate handler yet i think
	table.insert(dronetest.drones,self.id,self)
end

function drone.get_staticdata(self)
	local data = {}
	data.id = self.id
	data.status = self.status
	data.yaw = self.object:getyaw()
	-- TODO: save inventory data for drones?!
--[[
	local inv = minetest.get_inventory({type="detached",name="dronetest_drone_"..self.id})
	if inv ~= nil then
		data.inv = inv:get_lists()
		
	end
	print("SAVESAVESAVE "..inv:serialize())
--]]
        return minetest.serialize(data)
end

function drone.on_punch(self, puncher, time_from_last_punch, tool_capabilities, direction)
        if not puncher or not puncher:is_player() or self.removed then
                return
        end
end

function drone.on_step(self, dtime)

end

minetest.register_entity("dronetest:drone", drone)

-- Helper-node which does nothing but spawn a drone entity, so drones can be crafted?!?
minetest.register_node("dronetest:drone", {
	description = "Spawns a drone.",
	tiles = {"computerTop.png"},
	paramtype2 = "facedir",
	groups = {choppy=2,oddly_breakable_by_hand=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		dronetest.log("Drone spawner placed at "..minetest.pos_to_string(pos))
		minetest.add_entity(pos,"dronetest:drone")
		minetest.remove_node(pos)
	end,
	can_dig = function(pos,player)
		return false
	end,
})
	

minetest.register_node("dronetest:computer", {
	description = "A computer.",
	tiles = {"computerTop.png", "computerTop.png", "computerSide.png", "computerSide.png", "computerSide.png", "computerFront.png"},
	paramtype2 = "facedir",
	groups = {choppy=2,oddly_breakable_by_hand=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)
		dronetest.last_id = dronetest.last_id + 1
		local meta = minetest.get_meta(pos)
		meta:set_int("id",dronetest.last_id )
		meta:set_string("formspec",get_computer_formspec(dronetest.last_id))
		meta:set_string("infotext", "Computer #"..dronetest.last_id )
		meta:set_int("status",0)
		mkdir(mod_dir.."/"..dronetest.last_id)
		dronetest.log("Computer #"..dronetest.last_id.." constructed at "..minetest.pos_to_string(pos))		
	end,
	on_destruct = function(pos, oldnode)
		deactivate(pos)
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		dronetest.log("on_receive_fields received '"..formname.."'")
		local id = meta:get_int("id")
		if fields["clear"] ~= nil then
			console_histories[id] = {}
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
		dronetest.log("Computer #"..dronetest.last_id.." has been punched at "..minetest.pos_to_string(pos))
	end,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		dronetest.log("Computer #"..dronetest.last_id.." placed at "..minetest.pos_to_string(pos))
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