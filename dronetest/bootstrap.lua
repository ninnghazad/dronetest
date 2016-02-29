-- BOOTSTRAP
-- this is the entrypoint to userspace

print("System #"..(sys.id).." is booting!")
-- Load the APIs
coroutine    = sys:loadApi("coroutine")
os    = sys:loadApi("os")
fs    = sys:loadApi("fs")
term  = sys:loadApi("term")
peripheral = sys:loadApi("peripheral")
if sys.type == "drone" then
	drone = sys:loadApi("drone")
end
shell = sys:loadApi("shell")
print("System #"..(sys.id).." APIs loaded!")

sys:init()

if not fs.isDir("./") then fs.makeDir("./") end

print("Finished booting #"..sys.id..", dropping to shell.")

-- Test 
--dump(_G)
--dump(getfenv(shell.run))

if fs.isFile("startup") then
	shell.run("startup",{sys.id},_G)
end

shell.main()

print("REBOOT")
return true
