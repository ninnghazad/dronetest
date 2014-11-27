
local BLOCKSIZE = 16
local function get_blockpos(pos)
	return {
		x = math.floor(pos.x/BLOCKSIZE),
		y = math.floor(pos.y/BLOCKSIZE),
		z = math.floor(pos.z/BLOCKSIZE)}
end

local function get_nodefromblock(block)
	return {
		x = block.x*BLOCKSIZE,
		y = block.y*BLOCKSIZE,
		z = block.z*BLOCKSIZE}
end


local force_loader = {}
force_loader.tickets = {}
force_loader.loaded = {}
force_loader.save_file = minetest.get_worldpath().."/forceloader.txt"

force_loader.update = function()
print("force_loader: before now "..dronetest.count(force_loader.tickets).." tickets and "..dronetest.count(force_loader.loaded).." forced chunks.")
	local old_loaded = table.copy(force_loader.loaded)
	force_loader.loaded = {}
	local blocks = {}
	for i,t in ipairs(force_loader.tickets) do
		print("force_loader: show ticket "..t.id.." @ "..t.pos.x..", "..t.pos.y..", "..t.pos.z)
	end
	for i,t in ipairs(force_loader.tickets) do
		local pos = get_blockpos(t.pos)
		blocks[minetest.hash_node_position(pos)] = true
		print("force_loader: ticket "..t.id.." "..t.pos.x..", "..t.pos.y..", "..t.pos.z.." needs block "..pos.x..", "..pos.y..", "..pos.z)
	end
	
	--print(dump(blocks))
	for i,b in pairs(blocks) do
		local pos = get_nodefromblock(minetest.get_position_from_hash(i))
		local found = false
		print("force_loader: check block "..pos.x..", "..pos.y..", "..pos.z)
		for j,o in ipairs(old_loaded) do
			if o.x == pos.x and o.y == pos.y and o.z == pos.z then
				found = true
			end
		end
			
		if found or (minetest.forceload_block(pos) and force_loader.wait(pos)) then
			if found then
				print("force_loader: keep used block "..pos.x..", "..pos.y..", "..pos.z)
			else
				print("force_loader: add used block "..pos.x..", "..pos.y..", "..pos.z)
			end
			table.insert(force_loader.loaded,pos)
		else
			print("force_loader: could not forceload block, this probably mean that your max_forceloaded_blocks setting is not high enough.")
		end
	end
	for j,o in ipairs(old_loaded) do
		local found = false
		for i,b in pairs(blocks) do
			local pos = get_nodefromblock(minetest.get_position_from_hash(i))
			if o.x == pos.x and o.y == pos.y and o.z == pos.z then
				found = true
				break
			end
		end
		if not found then 
			print("force_loader: free unused block "..o.x..", "..o.y..", "..o.z)
			minetest.forceload_free_block(o)
		end
		
	end
		for i,t in ipairs(force_loader.tickets) do
		print("force_loader: show ticket after "..t.id.." @ "..t.pos.x..", "..t.pos.y..", "..t.pos.z)
	end
	--print("force_loader: now "..dronetest.count(force_loader.tickets).." tickets and "..dronetest.count(force_loader.loaded).." forced chunks.")
	force_loader.save()
end
force_loader.wait = function(pos)
	if minetest.get_node(pos).name == "ignore" then
		while minetest.get_node(pos).name == "ignore" do
			local bmin,bmax = {},{}
			bmin.x = math.min(pos.x,pos.x) - 1
			bmin.y = math.min(pos.y,pos.y) - 1
			bmin.z = math.min(pos.z,pos.z) - 1
			bmax.x = math.max(pos.x,pos.x) + 1
			bmax.y = math.max(pos.y,pos.y) + 1
			bmax.z = math.max(pos.z,pos.z) + 1
			local v=VoxelManip():read_from_map(bmin,bmax)
			print("waiting for block to load @ "..pos.x..","..pos.y..","..pos.z.." ("..minetest.hash_node_position(get_blockpos(pos)).."): "..dump(v).." "..dump({bmin,bmax}))
			coroutine.yield() -- give chance to load block
		end
		--print("ok, waited")
	end
	return true
end
force_loader.last_id = 0
force_loader.register_ticket = function(pos)
	local ticket = {}
	ticket.pos = pos
	force_loader.last_id = force_loader.last_id + 1
	ticket.id = 0+force_loader.last_id
	table.insert(force_loader.tickets,ticket)
	force_loader.update()
	force_loader.wait(pos)
	return ticket
end

force_loader.update_ticket = function(ticket,pos)
print("UPDATE?!")
	force_loader.register_ticket(pos)
	force_loader.unregister_ticket(ticket)
end

force_loader.unregister_ticket = function(ticket)
	print("removing ticket "..ticket.id)
	for i,t in ipairs(force_loader.tickets) do
		print("force_loader: show before remove ticket "..t.id.." @ "..t.pos.x..", "..t.pos.y..", "..t.pos.z)
	end
	
	for i,t in ipairs(force_loader.tickets) do
		if t.id == ticket.id then
			print("force_loader: found ticket "..t.id.." to be removed "..t.pos.x..", "..t.pos.y..", "..t.pos.z)
			table.remove(force_loader.tickets,i)
			break
		end
	end
	--for i,t in ipairs(force_loader.tickets) do
	--	print("force_loader: show after remove ticket "..t.id.." @ "..t.pos.x..", "..t.pos.y..", "..t.pos.z)
	--end
	force_loader.update()
end

force_loader.save = function()
	local file = io.open(force_loader.save_file, "w")
	if file then
		print("save force_loader: "..minetest.serialize(force_loader.loaded))
		file:write(minetest.serialize(force_loader.loaded))
		file:close()
	end
	
end

force_loader.load = function()
	local file = io.open(force_loader.save_file, "r")
	if file then
		--print("load force_loader: "..(file:read("*all")))
		local data = minetest.deserialize(file:read("*all"))
		print(dump(data))
		file:close()
		
		if type(data) == "table" then
			force_loader.loaded = data
			for i,v in pairs(force_loader.loaded) do
				if not minetest.forceload_block(v) then
					print("WARNING: could not restore loaded block for forceloading!")
				else 
					print("force_loader: Loaded block.")
				end
			end
		end
		
	else
		minetest.log("error", "No such file '"..force_loader.save_file.."'!")
	end
end



dronetest.force_loader = force_loader
