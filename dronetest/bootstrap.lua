-- BOOTSTRAP
-- this is the entrypoint to userspace

print("System #"..(sys.getId()).." is booting!")
-- Load the APIs
coroutine    = sys:loadApi("coroutine")
os    = sys:loadApi("os")
fs    = sys:loadApi("fs")
term  = sys:loadApi("term")
peripheral = sys:loadApi("peripheral")
--[[if sys.type == "drone" then
	drone = sys:loadApi("drone")
end--]]
shell = sys:loadApi("shell")
print("System #"..(sys.getId()).." APIs loaded!")

sys:init()


if not fs.isDir("./") then fs.makeDir("./") end
fs.chDir("./")
print("Finished booting #"..sys.getId()..", dropping to shell.")

-- Test 
--dump(_G)
--dump(getfenv(shell.run))

if fs.isFile("startup") then
	shell.run("startup",{sys.getId()},_G)
end

shell.main(_G)

print("REBOOT")
return true
