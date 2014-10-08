-- OS API
-- APIs have minetest and so on available in scope

local os = {}

os.get_api_name = function()
	return "os"
end
os.get_api_version = function()
	return "0.0.1"
end

-- This is rather ugly - maybe send a timer-event of some sort to reduce busy-looping?
-- Should this be in sys?
os.sleep = function(seconds)
	local start = minetest.get_gametime()
	while minetest.get_gametime() - start < seconds do
		coroutine.yield()
	end
end

os.shutdown = function()
	--sys.shutdown()
end

--[[
function os.loadlib_string(string, initialenv, params...)
Works similarly to ComputerCraft's os.loadAPI except you pass it lua and not a path to a lua file.
os.loadlib actually reads the file at the given path
param 1: library-defining function as string
param 2: initial environment, for passing stuff, or nil
param 3: parameters to function
returns: table with the library

Note - param 2 and 3 are technically redundant, but some might prefer using param 3 while I prefer using param 2.
We can remove one if it ends up never being used or is deemed inferior.  

Inside a library definition:
env is the same as getfenv - it might not be a good idea for sandboxed programs to have access to
 setfenv and getfenv and force them to do things similarly to in lua 5.2
self is the table the library will be copied into (like in CoOmputerCraft) - only functions, tables, and userdata get copied (copytypes)
--]]
local copytypes = {['function']=true, table=true, userdata=true}
function os.loadlib_string(string, initialenv, ...)
	local libenv = setmetatable(initialenv or {}, {__index = _G})
	local libtbl = {}
	libenv.env = libenv
	linenv.self = libtbl
	local func, err = loadstring(string)	-- is this the right loadstring?
	if not func then
		error(err, 2)
	end
	setfenv(func, libenv)
	func(...)
	for k,v in pairs(libenv) do
		if copytypes[type[v]] then
			libtbl[k] = v
		end
	end
	return libtbl
end

function os.loadlib(path, initialenv, ...)
	local api = readFile(mod_dir.."/rom/lib/"..name..".lua")
	local err = ""
	if type(api) ~= "string" or api == "" then minetest.log("error","missing, unreadable or empty library '"..name.."'!") error("missing, unreadable or empty api '"..name.."'!") return false end
	api,err = os.loadlib_string(api, initialenv, ...)
	if type(api) ~= "function" or err ~= nil then minetest.log("error","bad api '"..name.."': "..err)  error("bad api '"..name.."'!") return false end
	return api
end

return os
