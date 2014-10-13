minetest.register_craft({
	output = "dronetest:computer",
	recipe = {
		{"group:wood","group:wood","group:wood"},
		{"group:wood","default:glass","group:wood"},
		{"group:wood","group:wood","group:wood"},
	},
})
minetest.register_craft({
	output = "dronetest:drone",
	recipe = {
		{"group:wood","group:wood","group:wood"},
		{"group:wood","default:pick_diamond","group:wood"},
		{"group:wood","group:wood","group:wood"},
	},
})

