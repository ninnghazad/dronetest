
local function get_computer_formspec(id,channel)
	local formspec =
		"size[11,1]"..
--		default.gui_bg..
--		default.gui_bg_img..
--		default.gui_slots..
		"keyeventbox[0.3,0.4;1,1;proxy;keyboard.png;keyboardActive.png]"..
		"field[1.3,0.7;6,1;input;;]"..
		"field[7.3,0.7;2,1;channel;channel;"..channel.."]"..
		"button[9,0.4;1,1;execute;EXE]"..
		"label[1.3,0.0;COMPUTER_ID: "..id.."]"
		if dronetest.active_systems[id] ~= nil then formspec = formspec.."button[10,0.4;1,1;poweroff;OFF]" 
		else formspec = formspec.."button[10,0.4;1,1;poweron;ON]" end
	return formspec
end

local function redraw_computer_formspec(pos,player)
	local meta = minetest.get_meta(pos)
	
	local formspec = get_computer_formspec(meta:get_int("id"),meta:get_string("channel"))
	meta:set_string("formspec",formspec)
	
--	minetest.show_formspec(player:get_player_name(),"dronetest:computer",formspec)
end

function dronetest.print(id,msg,nonewline)
	if nonewline == nil then nonewline = false end
	if msg == nil then
		return
	end
	if dronetest.console_histories[id] == nil then
		dronetest.console_histories[id] = ""
	end
	if nonewline then
		dronetest.console_histories[id] = dronetest.console_histories[id]..msg
	else
		dronetest.console_histories[id] = dronetest.console_histories[id]..msg.."\n"
	end
	
	-- apply eventual '\b's before sending to display ?!
	dronetest.console_histories[id] = string.format("%s",dronetest.console_histories[id])
	if string.find(dronetest.console_histories[id],"\b") then
		print("found backspace in '"..dronetest.console_histories[id].."'")
		dronetest.console_histories[id] = dronetest.console_histories[id]:gsub("(.\b)","")
		print("replaced backspace in '"..dronetest.console_histories[id].."'")
	end 
	
	if string.len(dronetest.console_histories[id]) > 4096 then dronetest.console_histories[id] = string.sub(dronetest.console_histories[id],string.len(dronetest.console_histories[id])-4096) end
	
	-- update display, not quite as it should be
	if dronetest.active_systems[id] ~= nil then
		-- TODO: limit updates per second
		local channel = minetest.get_meta(dronetest.active_systems[id].pos):get_string("channel")
		--print("send print to "..channel)
		digiline:receptor_send(dronetest.active_systems[id].pos, digiline.rules.default, channel, dronetest.history_list(id))
		--digiline:receptor_send(dronetest.active_systems[id].pos, digiline.rules.default,"dronetest:computer:"..id, dronetest.console_histories[id])
	end
	
	dronetest.log("system "..id.." generated output: "..msg)
end


-- this is ugly and badly named
-- this is what formats text when sent to stdout
dronetest.history_list = function(id)
	if dronetest.console_histories[id] == nil then
		-- TODO: put some nifty ascii-art as default screen?!?
		return "###### P R E S S   O N   T O   S T A R T   S Y S T E M #####\n"
	end
	return dronetest.console_histories[id] -- send complete buffer to display for now
	--[[
	local s = ""
	local n = count(dronetest.console_histories[id])
	for i,v in ipairs(dronetest.console_histories[id]) do
		if i > math.max(0,n - (40-6)) then -- hardcoded size of display
			s = s..""..v.." "..n.."\n"
		end
	end
	s = s.." "
	return s
	--]]
end


function timeout()
	print("SUCH TIMEOUT! VERY WAIT! MUCH SLOW!")
	coroutine.yield()
end

local function activate_by_id(id,t,pos)
	if pos == nil then pos = {x=0,y=0,z=0} end
	if t == nil then t = "drone" end
	-- http://lua-users.org/wiki/SandBoxes
	local env = table.copy(dronetest.userspace_environment)
	env.getId = function() return id end
	
	env.sys = table.copy(dronetest.sys)
	-- HORRIBLE PLACE TO PUT ID
	env.sys.id = 1+id-1
	-- HORRIBLE PLACE TO PUT SANDBOX PATH
	env.sys.sandbox = env.mod_dir.."/"..id
	local meta = minetest.get_meta(pos)
	env.sys.channel = meta:get_string("channel")
	env.sys.type = t
	
	-- overload print function to print to drone/computer's screen and not to servers stdout
	env.print = function(msg) dronetest.print(id,msg) end

	local bootstrap,err = loadstring(dronetest.bootstrap)
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
	
	dronetest.active_systems[id] = {coroutine_handle = cr,events = {},type=t,id=id,pos=pos,last_update = minetest.get_gametime()}
	
	dronetest.log("STATUS: "..coroutine.status(dronetest.active_systems[id].coroutine_handle))
	dronetest.log("TYPE: "..type(dronetest.active_systems[id]))

	dronetest.log("System #"..id.." has been activated, now "..dronetest.count(dronetest.active_systems).." systems active.")
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
	dronetest.active_systems[id] = nil
	dronetest.log("System #"..id.." has been deactivated.")
	
	return true
end
local function deactivate(pos)
	
	local meta = minetest.get_meta(pos)
	local id = meta:get_int("id")
	meta:set_int("status",0)
	return deactivate_by_id(id)
end

minetest.register_abm({
	nodenames = {"dronetest:computer"},
	interval = 1,
	chance = 1,
	action = function(pos)
		-- Activate systems that were active when the game was closed last time.
		-- or that may have crashed strangely
		local meta = minetest.get_meta(pos)
		if meta:get_int("status") == 1 and dronetest.active_systems[meta:get_int("id")] == nil then
			dronetest.console_histories[meta:get_int("id")] = ""
			activate(pos)
		end
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
			--	print("COMPUTER "..id.." received on "..channel.." "..dump(msg))
				dronetest.events.send_by_id(id,{type="digiline",channel=channel,msg=msg})
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
		mkdir(dronetest.mod_dir.."/"..dronetest.last_id)
		dronetest.log("Computer #"..dronetest.last_id.." constructed at "..minetest.pos_to_string(pos))		
		if not minetest.forceload_block(pos) then
			dronetest.log("WARNING: Could not forceload block at "..dump(pos)..".")
		end
		dronetest.save() -- so we remember the changed last_id in case of crashes
	end,
	on_destruct = function(pos, oldnode)
		deactivate(pos)
		minetest.forceload_free_block(pos)
	end,
	on_event_receive = function(event)
		
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		dronetest.log("on_receive_fields received '"..formname.."': "..dump(fields))
		local id = meta:get_int("id")
		if fields["channel"] ~= nil then
			meta:set_string("channel",fields.channel)
		end
		if fields["clear"] ~= nil then
			dronetest.console_histories[id] = ""
			minetest.chat_send_player(sender:get_player_name(),"system #"..id..": screen cleared and redrawn.")
		elseif fields["redraw"] ~= nil then
			minetest.chat_send_player(sender:get_player_name(),"system #"..id..": screen redrawn.")
		elseif fields["poweron"] ~= nil then
			if meta:get_int("status") ~= 1 then
				activate(pos)
			end
			minetest.chat_send_player(sender:get_player_name(),"system #"..id.." activated, now "..count(dronetest.active_systems).." systems online.")
		elseif fields["poweroff"] ~= nil then
			if meta:get_int("status") ~= 0 then
				deactivate(pos)
			end
			minetest.chat_send_player(sender:get_player_name(),"system #"..id.." deactivated, now "..count(dronetest.active_systems).." systems online.")
		elseif fields["input"] ~= nil and fields["execute"] ~= nil and fields["input"] ~= "" then
			dronetest.log("command: "..fields["input"])
			local id = meta:get_int("id")
			if dronetest.active_systems[id] ~= nil then
				if not dronetest.events.send_by_id(id,{type="input",msg=fields["input"]}) then
					minetest.log("error","could not queue event")
				end
				dronetest.log("system "..id.." now has "..#dronetest.active_systems[id].events.." events.")
			else
				minetest.chat_send_player(sender:get_player_name(),"Cannot exec, activate system first.")
			end
		elseif fields["quit"] == true then
			return true
		elseif fields["proxy"] ~= nil and fields["proxy"] ~= "" then
			print("received keyboard event through proxy: "..fields["proxy"])
			dronetest.events.send_by_id(id,{type="key",msg={msg=fields["proxy"],msg_id=0}})
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
		if dronetest.active_systems[id] ~= nil then return false end
		return true;
	end,
})

local timer = 0
minetest.register_globalstep(function(dtime)
	local co
	local id
	local s
	timer = timer + dtime;
	while timer >= dronetest.globalstep_interval do
		for i = 1,dronetest.cycles_per_step,1 do
		--minetest.chat_send_all("dronetest globalstep @"..timer.." with "..count(dronetest.active_systems).." systems.")
		for id,s in pairs(dronetest.active_systems) do
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
				dronetest.active_systems[id] = nil
			end
		end
		end
		timer = timer - dronetest.globalstep_interval
	end
end)
