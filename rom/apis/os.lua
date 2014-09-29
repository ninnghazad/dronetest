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


return os
