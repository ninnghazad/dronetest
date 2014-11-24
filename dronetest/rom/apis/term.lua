-- TERM API
-- APIs have minetest and so on available in scope

local term = {}

function term.clear()
	console_histories[sys.id] = {}
	-- TODO: redraw
end

function term.write(msg)
	console_histories[sys.id] = console_histories[sys.id]..msg
	return string.len(msg)
end

function term.getChar()
	
	local e = dronetest.events.receive(sys.id,{"key"})
	return e.msg
end

return term
