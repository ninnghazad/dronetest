DRONETEST
=========

A computer-themed mod for the game minetest, heavily inspired by ComputerCraft.

This is not ready for use.

<img src="http://dunkelraum.net/share/screen4.png"/>

###How to use:
Install in mods/ as "dronetest".  
Type '/giveme dronetest:computer' to get a computer,  
'/giveme dronetest:drone' to get a drone-spawner,  
'/giveme dronetest_display:display' to get a display.  
Place it and rightclick it.   
A GUI opens up.   
Type 'id' and click 'EXE', don't press enter, it closes the dialog (yeah ...).  
Click 'DRW' to update the display and see results.  
Also try 'time' or 'ls'. There are more commands, like 'dance' for drones.

###Infos:
Commands and APIs have access to global and sandboxed environment,  
global gets overwritten with sandboxed.  
Sandboxed environment is what user can access through the virtual systems, 
functions, files, variables and so on. 
That sandboxed env. is called userspace and is accessible for the user through the "sys" object. 

/rom is read-only  
/rom/apis contains all APIs  
/rom/bin contains all commands  
/ contains system's data  

Each virtual system is assigned a real folder on the server, within the mods folder, named by its id (sys.id).  
Systems must not ever have access to anything outside that directory.  
The /rom directory does not physically lie withing the virtual systems' directories,   
but rather shall be included then commands are parsed and directories are listed,   
so that APIs can be read from userspace, commands executed from userspace, but neither changed.  
Each API and each command goes in its own file.

Userspace cannot and must not ever access the minetest object, if that is possible, something is wrong.
APIs and commands are allowed to do so, because they have to be installed by the server's admin,  
and are thusly deemed safe.

Take note of:
https://github.com/minetest/minetest/pull/1606
http://mesecons.net/developers.php

###Current problems:
- Bug with calling minetest.* functions from coroutines hinders use of minetest.get_objects_inside_radius() in userspace.
This means you cannot get entities in user and api-space, so drones will drive through each other. minor annoyance.
- Right now systems do not get automatically booted when server starts, somewhat on purpose to deal with nasty bugs.
because of that you may have to click 'OFF' and then 'ON' after a server restart to continue using that system.


##Roadmap:
Look around the source for examples on how to get stuff done.  
- Core:
  - Making sure minetest.* function can be savely called through coroutines (see current problems): https://github.com/minetest/minetest/issues/1709
  ~~- Drones need to spawn an invisible node when standing still, so we can interface them with other nodes, like mesecons stuff.~~
  - Peripheral API
  - Turn drones into peripherals and still have something like the drone.* api
  - Make recipes and crafting-hooks for computer and drone nodes.
  - Make drone diggable.
  - Make drone inventories persist restarts: https://github.com/minetest/minetest/issues/1696
  - Integrate (wireless)networking in event-queue (just where digilines is not enough)
  - Better command-parser, with autocomplete.
  - Real GUI with charbased input in good refresh-rate.
  - Better shell, based on a better GUI. with color, and settable cursor-position, redraws...
  - Wrapping more important functions like load* and do*
- APIs:
See http://computercraft.info/wiki/Category:APIs
The most important ones are:
  - sys is not really an api-file, but is created on the fly by the mod, and contains stuff like system's id and mod_name
  - io/os/fs - the should use lfs.* and _makePath to provide save, sandboxed access to files and filesystem
    - for lfs.* api check https://keplerproject.github.io/luafilesystem/manual.html#introduction
    - _makePath is supposed to catch all illegal paths, and must be used whenever a path is used with lfs or some input/output
  - testnet - a rednet-like api, will have to be mostly done in core
    mostly replaced with digilines
  - parallel/coroutine - this will be tricky to get sandboxed right, need to make sure no privilege escalation is possible
  - drone - this contains the drone-specific functions like movement, inventory access.
  - math/vector/string/bit... 
  - any other usefull api you can think of
- CMDs:
  - A set of basic fs commands, like ls,cp,rm,mv ...
  - Other commands one expects from a OS like beep,reboot,shutdown,time...
  - Cool stuff
- Misc:
  - A drone-model with "wield-points" for tools and peripherals.
  ~~- Textures~~
  - Sounds (like, beeep)
  - Some good examples
  - Some good tutorials

This list is constantly changing, so don't rely on it and communicate what you work on.
  
  
  
##Pictures:
Closeup of a display:  
<img src="http://dunkelraum.net/share/screen5.png"/>  

Drone's front:  
<img src="http://dunkelraum.net/share/screen7.png"/>  

Drone's back:  
<img src="http://dunkelraum.net/share/screen6.png"/>  

