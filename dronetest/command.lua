
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
