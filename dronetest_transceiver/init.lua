-- needed to connect drones and digilines


local reset_meta = function(pos)
	minetest.get_meta(pos):set_string("formspec", "field[channel;Channel;${channel}]")
end

dronetest_transceiver = {}
dronetest_transceiver.actions = {
	test = { desc= "tests the device", func = function() return true end }
}

local on_digiline_receive = function(pos, node, channel, msg)
	local meta = minetest.get_meta(pos)
	local setchan = meta:get_string("channel")
	
	-- not our channel - forward data to all drones?!
	if setchan ~= channel then 
--		print("TRANSCEIVER GOT DATA: "..dump(dronetest.drones))
		for id,drone in pairs(dronetest.drones) do
			print("transceiver is forwarding data to drone #"..id)
			drone:on_digiline_receive_line(channel,msg)
		end
		return 
	end
	
	if type(msg) == "table" and type(msg.action) == "string" then
		if msg.action == "GET_CAPABILITIES"  and type(msg.msg_id) == "string" then
			local cap = {}
			for n,v in pairs(dronetest_transceiver.actions) do
				cap[n] = v.desc
			end
			-- send capabilities
			digiline:receptor_send(pos, digiline.rules.default,channel, {action = "CAPABILITIES",msg_id = msg.msg_id,msg = cap })
			return
		elseif dronetest_transceiver.actions[msg.action] ~= nil then
			-- execute function
			local response = {dronetest_transceiver.actions[msg.action].func(msg.argv[1],msg.argv[2],msg.argv[3],msg.argv[4],msg.argv[5])}
			
			-- send response
			digiline:receptor_send(pos, digiline.rules.default,channel, {action = msg.action ,msg_id = msg.msg_id,msg = response })
			return
		end
	end

end

local transceiver_box = {
	type = "wallmounted",
	wall_top = {-8/16, 7/16, -8/16, 8/16, 8/16, 8/16}
}

minetest.register_node("dronetest_transceiver:transceiver", {
	drawtype = "nodebox",
	description = "Dronetest Digiline Transceiver",
	inventory_image = "computerFront.png",
	wield_image = "computerFront.png",
	tiles = {"computerFront.png"},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "wallmounted",
	node_box = transceiver_box,
	selection_box = transceiver_box,
	groups = {choppy = 3, dig_immediate = 2},

	after_place_node = function (pos, placer, itemstack)
		--[[local param2 = minetest.get_node(pos).param2
		if param2 == 0 or param2 == 1 then
			minetest.add_node(pos, {name = "dronetest_transceiver:transceiver", param2 = 3})
		end
		prepare_writing(pos)--]]
	end,

	on_construct = function(pos)
		reset_meta(pos)
	end,

	on_destruct = function(pos)
		--clearscreen(pos)
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		if (fields.channel) then
			minetest.get_meta(pos):set_string("channel", fields.channel)
		end
	end,

	digiline = 
	{
		receptor = {},
		effector = {
			action = on_digiline_receive
		},
	},

	light_source = 6,
})
