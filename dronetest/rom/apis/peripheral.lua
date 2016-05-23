-- PERI API

local peripheral = {}

function peripheral.wrap(channel,timeout)
	local pos = dronetest.active_systems[sys.id].pos
	-- use a unique message-id so we are able to identify the response to our request easily.
	local msg_id = sys:getUniqueId()
	-- this should be wrapped in sys:sendDigilineMessage
	digiline:receptor_send(pos, digiline.rules.default,channel, {action="GET_CAPABILITIES",msg_id=msg_id})
	
	-- wait for answer, this should be in a sys:function, with a timeout!
	--[[
	local e = nil
	while e == nil do
		sleep(0.05)
		e = sys:receiveDigilineMessage(channel,msg_id)
	end
	--]]
	e = sys:waitForDigilineMessage(channel,msg_id,timeout)
	if e == nil then
		print("could not reach peripheral on channel '"..channel.."'.")
		return nil
	end
	-- create functions to execute actions the peripheral offered
	local newp = {}
	for name,desc in pairs(e.msg) do
		print("wrap peripheral's method "..name..": "..dump(desc))
		newp[name] = function(a,b,c,d,e)
			local pos = dronetest.active_systems[sys.id].pos
			local msg_id = sys:getUniqueId() 
		--	dronetest.log("action: "..name.." @ "..channel)
			-- send action -- we attach a print() function, so the peripheral, when called from a computer, can print to its screen
			digiline:receptor_send(pos, digiline.rules.default,channel, {action=name,argv={a,b,c,d,e},msg_id=msg_id,print=function(msg) print(msg) end})

			-- receive answer, see above
			e = sys:waitForDigilineMessage(channel,msg_id,timeout)
			if e == nil then
				print("system "..sys.id.." could not reach peripheral on channel '"..channel.."' for action '"..name.."'.")
				return nil
			end
			
			
			return unpack(e.msg)
		end
		
	end
	
	
	return newp
end

function peripheral.wrap_digilines(channel)
	local newp = {
		channel = channel,
		sendAndReceive = function(msg,timeout)
			local pos = dronetest.active_systems[sys.id].pos
			local msg_id = sys:getUniqueId()
			digiline:receptor_send(pos, digiline.rules.default,channel, {action=msg,msg_id=msg_id})
			e = sys:waitForDigilineMessage(channel,msg_id,timeout)
			if e == nil then
				print("could not reach peripheral on channel '"..channel.."'.")
				return nil
			end
			return unpack(e.msg)
		end,
		send = function(msg)
			local pos = dronetest.active_systems[sys.id].pos
			digiline:receptor_send(pos, digiline.rules.default,channel, {action=msg,msg_id=msg_id})
		end,
		receive = function(timeout)
			return sys:waitForDigilineMessage(channel,"",timeout)
		end
	}
	return newp
	
end
return peripheral
