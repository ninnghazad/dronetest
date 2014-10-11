--[[
****
DroneTest
by ninnghazad
Licensed under NOTHING.
****
--]]



if minetest.setting_getbool("log_mods") then
	minetest.log("action", "[MOD] "..mod_name.." -- loading from "..mod_dir)
	minetest.register_on_shutdown(function() minetest.log("action", "[MOD] "..mod_name.." -- unloading ...") end)
end



--Global config and function table.
dronetest = {
	last_id = 0,
	last_drone_id = 0,
	globalstep_interval = 0.01,
	drones = {},
	events = {},
	console_histories = {},
	active_systems = {},
	max_userspace_instructions = 1000000,
	log = function(msg) minetest.log("action","dronetest: "..msg) end,
	mod_name = minetest.get_current_modname(),
	mod_dir = minetest.get_modpath(minetest.get_current_modname()),
	bootstrap = "",
}
-- include Lua File System, not sure if more versions are needed, this is linux64 and win32 i think
package.cpath = package.cpath
	.. ";" .. dronetest.mod_dir .. "/lfs.so"
	.. ";" .. dronetest.mod_dir .. "/lfs.dll"

lfs = require("lfs")

	
dofile(dronetest.mod_dir.."/util.lua")
dofile(dronetest.mod_dir.."/config.lua")
dofile(dronetest.mod_dir.."/command.lua")
dofile(dronetest.mod_dir.."/event.lua")
dofile(dronetest.mod_dir.."/sys.lua")
dofile(dronetest.mod_dir.."/userspace.lua")
dofile(dronetest.mod_dir.."/gui.lua")
dofile(dronetest.mod_dir.."/computer.lua")
dofile(dronetest.mod_dir.."/drone.lua")


-- Some message that the mod has loaded/unloaded
if minetest.setting_getbool("log_mods") then
	minetest.register_on_shutdown(function() minetest.log("action", "[MOD] "..mod_name.." -- unloaded!") end)
	minetest.log("action","[MOD] "..minetest.get_current_modname().." -- loaded!")
end

