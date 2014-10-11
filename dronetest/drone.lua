


local drone_formspec = "size[12,4;]\nlist[current_name;main;0,9;4,4;]\nlist[current_player;main;0,0;8,4;]"

local function get_drone_formspec(id,channel)
	local formspec =
		"size[13,5]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"list[detached:dronetest_drone_"..id..";main;9,1.3;4,4;]"..
		"list[current_player;main;0,1.3;8,1;]"..
		"list[current_player;main;0,2.3;8,3;8]"..
		"label[0.3,0.0;DRONE_ID: "..id.."]"..
		"field[2.3,0.3;13,1;channel;channel;"..channel.."]"
	return formspec
end



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
	local drops = minetest.get_objects_inside_radius(target,0.5)
	if #drops > 0 then
		for i,item in ipairs(drops) do
			print("flooritem: "..i.." "..item:get_luaentity().name.." "..dump(item))
		end
	end
	
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
	dig = {desc="Digs in front of drone.",func=function(id,print) 
		local d = dronetest.drones[id]
		local target = drone_get_forward(d)
		local node = minetest.get_node(target)
		if node.name == "air" then
			return false
		end
		local def = ItemStack({name=node.name}):get_definition()
		
		if not def.diggable then
			print("That is not diggable.")
			return false
		end
		-- if we cannot dig something, we try to suck items out of it - maybe its a chest.
		-- cause currently only empty chests may be digged. not sure if it's the right way
		-- to just do this automatically, probably not.
		if def.can_dig and not def.can_dig(target,d) then
			while dronetest.drone_actions.suck.func(id,target) do
				-- print("Target could be container, trying to clear it before digging it.")
				-- take all items from container?!
			end
			if not def.can_dig(target,d) then
				print("Object seems to be undiggable!")
				return false
			end
		end
		
		minetest.dig_node(target)
		
		local function rand_pos(pos, radius)
			local target = pos
			target.x = target.x + math.random(-radius*100, radius*100)/100
			target.z = target.z + math.random(-radius*100, radius*100)/100
			return target
		end
		-- TODO: 
		local itemstacks = minetest.get_node_drops(node.name)
		local oinv = minetest.get_inventory({type="detached",name="dronetest_drone_"..id})
		for _, itemname in ipairs(itemstacks) do
			local stack = ItemStack(itemname)
			print("dropping "..stack:get_count().."x "..itemname.." "..dump(itemname))
			local item = minetest.add_item(rand_pos(target,.49), stack)
			
			if item ~= nil then
				item:get_luaentity().collect = true
				oinv:add_item("main",ItemStack(item:get_luaentity().itemstring))
				item:get_luaentity().itemstring = ""
				item:remove()
			end
		end
		
		
		return true
	end},
	digUp = {desc="Places stuff from inventory above drone.",func=function() end},
	digDown = {desc="Places stuff from inventory below drone.",func=function() end},
	
}

-- drones receive digiline messages only through transceivers, when responding to those messages,
-- they act as if the transceiver would respond, meaning transceivers are actually just transmitters,
-- but act like transceivers to the player.
function drone.on_digiline_receive_line(self, channel, msg, senderPos)
	if type(msg) ~= "table" or type(msg.action) ~= "string" then return end
--	print("DRONE "..self.id.." received digiline channel: "..channel.." action: "..msg.action)
	if channel ~= self.channel then return end
	
	if type(msg) == "table" and type(msg.action) == "string" then
		local pos = self.object:getpos()
		if msg.action == "GET_CAPABILITIES"  and type(msg.msg_id) == "string" then
			local cap = {}
			for n,v in pairs(dronetest.drone_actions) do
				cap[n] = v.desc
			end
	--		print("DRONE "..self.id.." responds channel: "..channel.." action: "..msg.action)
			-- act as if transceiver would send the message
			
			-- send capabilities -- act as if transceiver would send the message
			digiline:receptor_send(senderPos, digiline.rules.default,channel, {action = "CAPABILITIES",msg_id = msg.msg_id,msg = cap })
			return
		elseif dronetest.drone_actions[msg.action] ~= nil then
			if msg.argv == nil or type(msg.argv) ~= "table" then msg.argv = {} end
			if dronetest.drones[self.id] == nil then print("drone #"..self.id.." not reachable!") return end
--			print("drone #"..self.id.." will execute "..msg.action.." from "..channel..".")
		--	print("PRE: "..dump(dronetest.drones[self.id]).." "..type(self.id))
			-- execute function
			local response = {dronetest.drone_actions[msg.action].func(self.id,msg.print,msg.argv[1],msg.argv[2],msg.argv[3],msg.argv[4],msg.argv[5])}
			--local response = {true}
--			print("drone #"..self.id.." finished action '"..msg.action.."': "..dump(response))
--			print("drone #"..self.id.." will answer on "..channel..".")
			
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
	dronetest.save()
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
