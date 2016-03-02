-- FS API
-- A save fs api, jailed to fsdir

-- This isn't the best spot for this, but make it so _makePath can see our current ID
-- needs to be before first use of the function!
function _makePath(path)
	local r = string.find(path,"%.%.")
	if r ~= nil then
		--print("Illegal path: "..path.." (error: "..r..")")
		return ""
	end
	--print("env: "..dump(sys))
	return mod_dir.."/"..sys.id.."/"..path
end
function _realPath(path)
	local old = lfs.currentdir()
	lfs.chdir(path)
	path = lfs.currentdir()
	lfs.chdir(old)
	return path
end
function _hidePath(path) 
	path = _realPath(path)
	base = _realPath(mod_dir.."/"..sys.id)
	path = string.gsub(path,base,"/")
	path = path:gsub("//","/")
	return path
end

local fs = {}
fs.getAbsolutePath = function(path)
	return _hidePath(path)
end

fs.isDir = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") == "directory" then
		return true
	end
	return false
end

fs.exists = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	local mode = lfs.attributes(p,"mode")
	if mode == "file" or mode == "directory" then
		return true
	end
	return false
end

fs.chDir = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	return lfs.chdir(p)
end

fs.currentDir = function()
	
	return _hidePath(lfs.currentdir())
end

fs.isFile = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") == "file" then
		return true
	end
	return false
end

fs.readFile = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") ~= "file" then
		return false
	end
	io.input(p)
	return io.read("*all")
end
fs.touch = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	return lfs.touch(p)
end
	
fs.list = function(path)
	if path == nil then path = "./" end
	local p = _makePath(path)
	if not fs.isDir(path) then return {} end
	print("LS: "..p.." || "..path)
	local list = {}
	local old = lfs.currentdir()
	lfs.chdir(mod_dir.."/"..sys.id)
	for filename in lfs.dir(p) do
		table.insert(list,filename)
	end
	lfs.chdir(old)
	return list
end

fs.makeDir = function(path)
	local p = _makePath(path)
	if p == "" then return false,"illegal path '"..path.."'" end
	local r,err = lfs.mkdir(p)
	if not r then print(sys.id.." Could not create directory '"..path.."': "..err) return false,err end
	return fs.isDir(p)
end

--[[
# fs.list
# fs.exists
# fs.isDir
fs.isReadOnly
fs.getName
fs.getDrive
fs.getSize
fs.getFreeSpace
# fs.makeDir
fs.move 2
fs.copy 2
fs.delete
fs.combine 2
fs.open
fs.find
fs.getDir
--]]
return fs
