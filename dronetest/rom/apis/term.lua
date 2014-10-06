-- TERM API
-- APIs have minetest and so on available in scope

local term = {}

function term.clear()
	console_histories[sys.id] = {}
	-- TODO: redraw
end

return term
