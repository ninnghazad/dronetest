--[[
****
DroneTest
by ninnghazad
Licensed under NOTHING.
****
--]]

--Global config and function table.
dronetest = {
	last_id = 0,
	last_drone_id = 0,
	globalstep_interval = 0.01,
	cycles_per_step = 4,
	drones = {},
	events = {},
	console_histories = {},
	active_systems = {},
	max_userspace_instructions = 1000000,
	log = function(msg) minetest.log("action","dronetest: "..msg) end,
	mod_name = minetest.get_current_modname(),
	mod_dir = minetest.get_modpath(minetest.get_current_modname()),
	bootstrap = "",
	--Config documentation, items that have one get save in config and can be changed by menu
	doc = {
		last_id = "The last id given to a computer.",
		last_drone_id = "The last id given to a drone.",
		globalstep_interval = "Interval to run LUA-coroutines at.",
		cycles_per_step = "Resume-cycles per global step. More makes computer seem faster to user.",
		max_userspace_instructions = "How many instructions may a player execute on a system without yielding?",
	},
}


if minetest.setting_getbool("log_mods") then
	minetest.log("[MOD] "..dronetest.mod_name.." -- loading from "..dronetest.mod_dir)
	minetest.register_on_shutdown(function() minetest.log("[MOD] "..dronetest.mod_name.." -- unloading ...") end)
end

-- include Lua File System, not sure if more versions are needed, this is linux64 and win32 i think
package.cpath = package.cpath
	.. ";" .. dronetest.mod_dir .. "/lfs.so"
	.. ";" .. dronetest.mod_dir .. "/lfs.dll"

lfs = require("lfs")

dofile(dronetest.mod_dir.."/util.lua")
dofile(dronetest.mod_dir.."/config.lua")
dofile(dronetest.mod_dir.."/sandbox/sandbox.lua")
dofile(dronetest.mod_dir.."/command.lua")
dofile(dronetest.mod_dir.."/event.lua")
dofile(dronetest.mod_dir.."/sys.lua")
dofile(dronetest.mod_dir.."/userspace.lua")
dofile(dronetest.mod_dir.."/gui.lua")
dofile(dronetest.mod_dir.."/forceloader.lua")
dofile(dronetest.mod_dir.."/computer.lua")
dofile(dronetest.mod_dir.."/drone.lua")
dofile(dronetest.mod_dir.."/craft.lua")

dronetest.force_loader.load()

minetest.log("[MOD] "..minetest.get_current_modname().." -- last_id: "..dronetest.last_id)

-- Some message that the mod has loaded/unloaded
if minetest.setting_getbool("log_mods") then
	minetest.register_on_shutdown(function() minetest.log("action", "[MOD] "..dronetest.mod_name.." -- unloaded!") end)
	minetest.log("[MOD] "..minetest.get_current_modname().." -- loaded!")
end

