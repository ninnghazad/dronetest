-- DRONE API

local drone = {}
local steps = 10
--local moveSleep = 0.05
local rad2unit = 1 / (2*3.14159265359)
local function yaw2dir(yaw)
	local dir = yaw * rad2unit
	print("yaw2dir: "..yaw.." > "..dir)
	if dir > 0.875 or dir <= 0.125 then return 0 
	elseif dir > 0.125 and dir <= 0.375 then return 1 
	elseif dir > 0.375 and dir <= 0.625 then return 2
	else return 3 end
end
local function checkTarget(pos)
	local node = minetest.get_node(pos)
	if node ~= nil and node.name ~= "air" then
		return false,"node"
	end
	--print(dump(minetest.env))
	--local objs = get_objects(pos, 0.2)
	
	return true
	--[[
	for i,o in ipairs(objs) do
		if o.physical then
			return false,"object"
		end
	end
	return true
	--]]
end
local function snapRotation(r)
	while r < 0 do r = r + (1/rad2unit) end
	while r > 1/rad2unit do r = r - (1/rad2unit) end
	print("snap 0: "..r)
	r = r * rad2unit
	print("snap 1: "..r)
	r = math.round(r * 4) / 4
	--print("snap 1: "..r)
	--if r > 3 then r = 0 end
	print("snap 2: "..r)
	r = r / rad2unit
	print("snap 3: "..r)
	return r
end
function drone.wield()
	local d = dronetest.drones[sys.id]
	local inv = minetest.env:get_inventory({type="detached",name="dronetest_drone_"..sys.id})
	if inv == nil then
		error("Drone without inventory!")
		return false
	end
	local item = inv:get_lists().main[1]:take_item()
	if item == nil then
		print("no item")
		return false
	end
	--???????????
	print("trying to wield "..item:get_name())
	if not d.object:set_wielded_item(item) then
		print("cannot wield")
		return false
	end
	return true
end

function drone.suck()
	local d = dronetest.drones[sys.id]
	local pos = d.object:getpos()
	
	
	local r = d.object:getyaw() * rad2unit --north is 0?!
	while r < 0 do r = r + 1 end
	local dir = math.round(r*3)
	if dir > 3 then dir = 0 end
	
	local npos = minetest.facedir_to_dir(dir)
	
	npos.x = npos.x + pos.x
	npos.y = npos.y + pos.y
	npos.z = npos.z + pos.z
	-- TODO: enable sucking items out of other drones too
	-- this is for chests and the like
	local ninv = minetest.get_inventory({type="node",pos=npos})
	if ninv == nil then
		print("No inventory in front of drone to suck from!")
		return false
	end
	local lists = ninv:get_lists()
	local item = nil
	-- Just take the first item in the list, if any
	for il,l in pairs(lists) do
		for ii,i in pairs(l) do
			if i:get_count() > 0 then
				item = i:take_item()
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
		print("GOT "..item:get_name())
		local inv = minetest.get_inventory({type="detached",name="dronetest_drone_"..sys.id})
		inv:add_item("main",item)
		return true
	end
	return false
end

-- Movement functions
function drone.forward()
	local d = dronetest.drones[sys.id]
	local pos = d.object:getpos()
	local yaw = d.object:getyaw()
	local dir = yaw2dir(snapRotation(yaw))
	if dir == 0 then dir = 2 
	elseif dir == 2 then dir = 0 end
	
	local opos = minetest.facedir_to_dir(dir)
	local npos = table.copy(pos) 
	npos.x = npos.x + opos.x
	npos.y = npos.y + opos.y
	npos.z = npos.z + opos.z
	local result,reason = checkTarget(npos)
	if not result then return result,reason end
	print("FORWARD: "..dump(pos).." "..dump(opos).." "..dump(npos).." "..dir.." "..yaw)
	npos = table.copy(pos)
	for i=1,steps,1 do
		npos.x = npos.x + opos.x/steps
		npos.y = npos.y + opos.y/steps
		npos.z = npos.z + opos.z/steps
		d.object:moveto(npos,true)
		sys.yield()
	end
	return true
end
function drone.back()
	local d = dronetest.drones[sys.id]
	local pos = d.object:getpos()
	local yaw = d.object:getyaw()
	local dir = yaw2dir(snapRotation(yaw))
	local opos = minetest.facedir_to_dir(dir)
	dir = dir + 2
	if dir > 3 then dir = dir - 4 end
	
	if dir == 0 then dir = 2 
	elseif dir == 2 then dir = 0 end
	local opos = minetest.facedir_to_dir(dir)
	
	local npos = table.copy(pos) 
	npos.x = npos.x + opos.x
	npos.y = npos.y + opos.y
	npos.z = npos.z + opos.z
	local result,reason = checkTarget(npos)
	if not result then return result,reason end
	print("BACK: "..dump(pos).." "..dump(opos).." "..dump(npos).." "..dir.." "..yaw)
	npos = table.copy(pos)
	for i=1,steps,1 do
		npos.x = npos.x + opos.x/steps
		npos.y = npos.y + opos.y/steps
		npos.z = npos.z + opos.z/steps
		d.object:moveto(npos,true)
		sys.yield()
	end
	return true
end
function drone.up()
	local d = dronetest.drones[sys.id]
	local pos = d.object:getpos()
	local npos = table.copy(pos)
	npos.y = npos.y + 1
	local result,reason = checkTarget(npos)
	if not result then return result,reason end
	npos = table.copy(pos)
	for i=1,steps,1 do
		npos.y = npos.y + 1/steps
		d.object:moveto(npos,true)
		sys.yield()
	end
	return true
end
function drone.down()
	local d = dronetest.drones[sys.id]
	local pos = d.object:getpos()
	local npos = table.copy(pos)
	npos.y = npos.y - 1
	local result,reason = checkTarget(npos)
	if not result then return result,reason end
	npos = table.copy(pos)
	for i=1,steps,1 do
		npos.y = npos.y - 1/steps
		d.object:moveto(npos,true)
		sys.yield()
	end
	return true
end
function drone.turnLeft()
	local d = dronetest.drones[sys.id]
	local r = d.object:getyaw() 
	print("left: "..r)
	local rot = (0.25 / rad2unit) / steps
	r = snapRotation(r)
	for i=1,steps,1 do
		r = r + rot
	
		d.object:setyaw(r)
		sys.yield()
	end
end
function drone.turnRight()
	local d = dronetest.drones[sys.id]
	local r = d.object:getyaw() 
	local rot = (-0.25 / rad2unit) / steps
	r = snapRotation(r)
	for i=1,steps,1 do
		r = r + rot
		while r < 0 do r = r + 2*3.14159265359 end
		d.object:setyaw(r)
		sys.yield()
	end
end



return drone

