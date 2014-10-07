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

--debug
mt = minetest
function get_objects(pos,radius)
--	print("get_objects: "..dump(pos).." "..radius)
	print("time: "..minetest.get_gametime())
	
	--local objs = mt.env:get_objects_inside_radius(pos,radius)
	local objs = minetest.env:get_objects_inside_radius(pos,radius)
	print("get_objects returned: "..#objs.." objects")
	return objs
end

setfenv(get_objects,getfenv(0))
--enddebug

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
	last_drone_id = 0,
	globalstep_interval = 0.01,
	drones = {},
	max_userspace_instructions = 1000000,
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
		"size[13,9]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"textarea[0.3,0.0;13,9.7;output;;"..history_list(id).."]"..
		"field[0.3,8.7;7,1;input;;]"..
		"field[7.3,8.7;2,1;channel;channel;"..channel.."]"..
		"button[9,8.4;1,1;execute;EXE]"..
		"button[10,8.4;1,1;poweroff;OFF]"..
		"button[11,8.4;1,1;poweron;ON]"..
		--"button[13,7.6;1,1;clear;CLR]"..
		"button[12,8.4;1,1;redraw;DRW]"
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
		console_histories[id] = {}
	end
	table.insert(console_histories[id],minetest.formspec_escape(msg))
	
--	if active_systems[id] ~= nil then
--		digiline:receptor_send(active_systems[id].pos, digiline.rules.default,"dronetest:computer:"..id, console_histories[id])
--	end
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
	print("fetched digilines event for #"..dump(self.id)..": "..dump(e))
	if e == nil then return nil end
	return e.msg
end

function sys:getUniqueId(event)
	self.last_msg_id = self.last_msg_id + 1
	return minetest.get_gametime().."_"..self.id.."_"..self.last_msg_id
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
	--env_save.dronetest = getfenv(0).dronetest
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

local function activate_by_id(id,t,pos)
	if pos == nil then pos = {x=0,y=0,z=0} end
	if t == nil then t = "drone" end
	-- http://lua-users.org/wiki/SandBoxes
	local env = table.copy(userspace_environment)
	env.getId = function() return id end
	
	env.sys = table.copy(sys)
	env.sys.id = 1+id-1
	local meta = minetest.get_meta(pos)
	env.sys.channel = meta:get_string("channel")
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
	dronetest.print(id,"drone #"..id.." deactivating.")
	active_systems[id] = nil
	dronetest.log("Drone #"..id.." has been deactivated.")
	
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
			--dronetest.drones[id].menu = false
			return false
	--[[	elseif fields["clear"] ~= nil then
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
			--]]
		elseif fields["channel"] ~= nil then
			dronetest.drones[id].channel = fields.channel
		end
		--if dronetest.drones[id].menu ~= nil and dronetest.drones[id].menu == true then
		--	minetest.show_formspec(player:get_player_name(), "dronetest:drone:"..id, get_drone_formspec(id,dronetest.drones[id].channel))
		--end
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

--[[
local function printTable(t,filter,invertFilter,printfunc)
	if printfunc == nil then 
		printfunc = function(i,v) return print(i..": "..type(v)) end 
	end
	if invertFilter == nil then 
		invertFilter = false
	end
	local i
	local v
	print("printTable: ")
	for i,v in pairs(t) do
		local found = false
		if filter == nil or (type(filter) == "string" and type(v) == filter) then
			found = true
		elseif type(filter) == "table" then
			for _,f in ipairs(filter) do
				if type(v) == f then
					found = true
					break
				end
			end
		end
		if found ~= invertFilter then
			printfunc(i,v)
		end
	end
end

function test(f,t,a1,a2,a3)

	local function e(msg) print("TESTERROR: "..msg) end
	local r
	local function ff() 
		
	--	print("TEST 0: f: "..dump(type(f))..": "..dump(f)..", #1 "..dump(type(a1))..": "..dump(a1)..", #2 "..dump(type(a2))..": "..dump(a2)..", #3 "..dump(type(a3))..": "..dump(a3))
		r = f(a1,a2,a)
	--	print("TEST 1: returns: "..type(r).." expected: "..t) --..": "..dump(r))
	end
	
	local co = coroutine.create(function() xpcall(ff,e) end)
	while coroutine.status(co) == "suspended" do coroutine.resume(co) end
	if type(r) ~= t then
		return false
	end
	return true
end
minetest.register_globalstep(function(dtime)
	local player = minetest.get_player_by_name("singleplayer")
	if not player then return end
	local pos = player:getpos()
	
	
	print("string.split")
	print("### "..dump(test(string.split,"table","test test"," ")).."\n")
	
	print("minetest.chat_send_all")
	print("### "..dump(test(minetest.chat_send_all,"nil","test")).."\n")
	
	print("minetest.get_gametime")
	print("### "..dump(test(minetest.get_gametime,"number")).."\n")
	
	print("minetest.get_timeofday")
	print("### "..dump(test(minetest.get_timeofday,"number")).."\n")
	
	print("minetest.get_modnames")
	print("### "..dump(test(minetest.get_modnames,"table")).."\n")
	
	print("minetest.get_modpath")
	print("### "..dump(test(minetest.get_modpath,"string","dronetest")).."\n")
	
	print("minetest.get_current_modname")
	print("### "..dump(test(minetest.get_current_modname,"string")).."\n")
	
	print("minetest.get_worldpath")
	print("### "..dump(test(minetest.get_worldpath,"string")).."\n")
		
	print("minetest.pos_to_string")
	print("### "..dump(test(minetest.pos_to_string,"string",pos)).."\n")
	
	print("minetest.get_node")
	print("### "..dump(test(minetest.get_node,"table",pos)).."\n")
	
	print("minetest.get_meta")
	print("### "..dump(test(minetest.get_meta,"userdata",pos)).."\n")
	
	print("minetest.get_player_by_name")
	print("### "..dump(test(minetest.get_player_by_name,"userdata","singleplayer")).."\n")
	
	print("minetest.get_player_ip")
	print("### "..dump(test(minetest.get_player_ip,"string","singleplayer")).."\n")
	
	print("minetest.get_player_information")
	print("### "..dump(test(minetest.get_player_information,"table","singleplayer")).."\n")
	
	print("minetest.get_connected_players")
	print("### "..dump(test(minetest.get_connected_players,"table")).."\n")
	
	--print("minetest.find_node_near")
	--print("### "..dump(test(minetest.find_node_near,"table",pos,10,"group:crumbly")).."\n")
	
	print("minetest.get_craft_recipe")
	print("### "..dump(test(minetest.get_craft_recipe,"table","default:torch")).."\n")
	
	print("minetest.get_objects_inside_radius")
	print("### "..dump(test(minetest.get_objects_inside_radius,"table",pos,10)).."\n")
	error("done")
	return true
end)
--]]

-- TODO: rather expensive just for waking up the systems, find other way
minetest.register_abm({
	nodenames = {"dronetest:computer"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local meta = minetest.get_meta(pos)
		-- make sure nodes that where active are reactivated on server start and after crashes
		if meta:get_int("status") == 1 and active_systems[meta:get_int("id")] == nil then
			activate(pos)
		elseif meta:get_int("status") == 1 then	
			print("SEND")
			digiline:receptor_send(pos, digiline.rules.default,meta:get_string("channel"),history_list(meta:get_int("id")))
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
dronetest.drone_actions = {
	test = {desc="a test",func=function() print("TEST") end},
	turnLeft = {desc="Rotates the turtle to the left.",func=function() print("TURNLEFT") end}
}
function drone.on_digiline_receive_line(self, channel, msg)
	print("DRONE "..self.id.." received digiline on "..channel..": "..dump(msg))
	if channel ~= self.channel then return end
	
	if type(msg) == "table" and type(msg.action) == "string" then
		local pos = self.object:getpos()
		if msg.action == "GET_CAPABILITIES"  and type(msg.msg_id) == "string" then
			local cap = {}
			for n,v in pairs(dronetest.drone_actions) do
				cap[n] = v.desc
			end
			print("drone responds to GET_CAPABILITIES")
			-- send capabilities
			digiline:receptor_send(pos, digiline.rules.default,channel, {action = "CAPABILITIES",msg_id = msg.msg_id,msg = cap })
			return
		elseif dronetest.drone_actions[msg.action] ~= nil then
			-- execute function
			local response = {dronetest.drone_actions[msg.action].func(msg.argv[1],msg.argv[2],msg.argv[3],msg.argv[4],msg.argv[5])}
			
			-- send response
			digiline:receptor_send(pos, digiline.rules.default,channel, {action = msg.action ,msg_id = msg.msg_id,msg = response })
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
	self.object:setyaw(self.yaw)
	print("Add drone "..self.id.." to list.")
	
	
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
--minetest.registered_entities["dronetest:drone"].

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
		table.insert(dronetest.drones,d.id,d)
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
				events.send_by_id(meta:get_int("id"),{type="digiline",channel=channel,msg=msg})
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
		save()
	end,
	on_destruct = function(pos, oldnode)
		deactivate(pos)
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
--[[	
minetest.register_entity("dronetest:display", {
	collisionbox = { 0, 0, 0, 0, 0, 0 },
	visual = "upright_sprite",
	textures = {},
	id = -2,
	on_activate = function(self, staticdata, dtime_s)
		if type(staticdata) == "string" and #staticdata > 0 then
			local data = minetest.deserialize(staticdata)
			self.id = data.id
		else 
			self.id = dronetest.last_id
		end
		print("on_activate: "..self.id)
		local text = history_list(id)
		self.object:set_properties({textures={dronetest.generate_texture(dronetest.create_lines(text))}})
	end,
	get_staticdata= function(self)
		local data = {}
		data.id = self.id
		return minetest.serialize(data)
	end,

	on_step = function(self, dtime)
		
		if active_systems[self.id] == nil then return false end
		local text = history_list(self.id)
		self.object:set_properties({textures={dronetest.generate_texture(dronetest.create_lines(text))}})
	end
})--]]

-- Some message that the mod has loaded/unloaded
if minetest.setting_getbool("log_mods") then
	minetest.register_on_shutdown(function() minetest.log("action", "[MOD] "..mod_name.." -- unloaded!") end)
	minetest.log("action","[MOD] "..minetest.get_current_modname().." -- loaded!")
end