-- PERI API

local peripheral = {}

function peripheral.open(side)
	-- TODO: check for attached peripherals first
	
	print("try to open peripheral on side "..side)
	
	local npos = {x=0,y=0,z=0}
	-- TODO: rotate by drone/computer rotation
	npos = minetest.facedir_to_dir(side)
	print("npos: "..dump(npos))
	local pos = active_systems[sys.id].pos
	print("pos: "..dump(pos))
	npos.x = npos.x + pos.x
	npos.y = npos.y + pos.y
	npos.z = npos.z + pos.z
	print("npos final: "..dump(npos))
	local meta = minetest.get_meta(npos)
	print(dump(meta:get_string("infotext")))
	local node = minetest.get_node(npos)
	print(dump(node))
end

return peripheral
