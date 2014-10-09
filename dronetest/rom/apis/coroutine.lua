-- coroutines for userspace
local cr = table.copy(coroutine)


cr.create = function(f)
	jit.off(f,true)
	local e = getfenv(2)
	setfenv(f,e)
	local ff = function() xpcall(f,function(msg) if msg == "attempt to yield across C-call boundary" then msg = "too many instructions without yielding" end dronetest.print(e.sys.id,"Error in coroutine: '"..msg.."':"..dump(debug.traceback())) coroutine.yield() end) end
	local co = coroutine.create(ff)
	return co
end
cr.resume = function(co)
	debug.sethook(co,coroutine.yield,"",dronetest.max_userspace_instructions)
	coroutine.resume(co) 
	coroutine.yield()
end

return cr