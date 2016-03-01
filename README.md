DRONETEST
=========

A computer-themed mod for the game minetest, heavily inspired by ComputerCraft.

This is not ready for use.

<img src="http://dunkelraum.net/share/screen4.png"/>

###How to use:
Install in mods-folder as "dronetest".    
'/giveme dronetest:computer'        to get a computer  
'/giveme dronetest:drone'           to get a drone-spawner  
'/giveme dronetest_display:display' to get a display  
'/giveme dronetest_transceiver:transceiver' to get a transceiver  
or use creative inventory to get items.

Display, transceiver and computer must touch or be connected using digilines. 
Right-click display and transceiver and set channel to "dronetest:computer:1".  
Right-click computer and click "ON" or use mesecons to turn it on/off.

Type 'id' into input field (lower left) and click 'EXE'.  
Press 'ESC' to leave and watch display to see output.  
  
Also try 'time' or 'ls'. There are more commands, like 'dance' for drones.  

###Infos:

/rom is read-only  
/rom/apis contains all APIs  
/rom/bin contains all commands  
/ contains system's data  

Each virtual system is assigned a real folder on the server, within the the mod's folder, named by it's id (sys.id).  
Systems must not ever have access to anything outside that directory.  

Userspace cannot and must not ever access the minetest object, if that is possible, something is wrong.
APIs and commands are allowed to do so, because they have to be installed by the server's admin,  
and are thusly deemed safe.

Take note of:
http://mesecons.net/developers.php

###Current problems:
  - ~~Bug with calling minetest.* functions from coroutines hinders use of minetest.get_objects_inside_radius() in userspace.
This means you cannot get entities in user and api-space, so drones will drive through each other. minor annoyance.~~
  - ~~Right now systems do not get automatically booted when server starts, somewhat on purpose to deal with nasty bugs.
because of that you may have to click 'OFF' and then 'ON' after a server restart to continue using that system.~~
  - There is a memleak with unloading textures somewhere in minetest, thusly using the display will leak memory, and sooner or later crash your system. to test computers running a long time, just set the display to some non-existant channel.
  - New input method has to wait for https://github.com/minetest/minetest/pull/1737

##Roadmap:
Look around the source for examples on how to get stuff done.  
- Core:
  - ~~Making sure minetest.* function can be savely called through coroutines (see current problems): https://github.com/minetest/minetest/issues/1709~~
  - ~~Drones need to spawn an invisible node when standing still, so we can interface them with other nodes, like mesecons stuff.~~
  - ~~Peripheral API. working prototype in code, but just has one wrap() function. not really an api yet.~~
  - ~~Turn drones into peripherals and still have something like the drone.* api~~
  - ~~Make recipes and crafting-hooks for computer and drone nodes.~~
  - ~~Make drone diggable.~~
  - Make drone inventories persist restarts: https://github.com/minetest/minetest/issues/1696
  - ~~Integrate (wireless)networking in event-queue (just where digilines is not enough)~~
  - Better command-parser, with autocomplete.
  - ~~Real GUI with charbased input in good refresh-rate.~~
  - Better shell, based on a better GUI. with color, and settable cursor-position, redraws...
  - Wrapping more important functions like load* and do*
  - using minetest.is_protected for all stuff that could be used for grieving.
- APIs:
See http://computercraft.info/wiki/Category:APIs
The most important ones are:
  - sys is not really an api-file, but is created on the fly by the mod, and contains stuff like system's id and mod_name
  - io/os/fs - the should use lfs.* and _makePath to provide save, sandboxed access to files and filesystem
    - for lfs.* api check https://keplerproject.github.io/luafilesystem/manual.html#introduction
    - _makePath is supposed to catch all illegal paths, and must be used whenever a path is used with lfs or some input/output
  - ~~coroutine - this will be tricky to get sandboxed right, need to make sure no privilege escalation is possible~~
  - ~~drone - this contains the drone-specific functions like movement, inventory access. partly done.~~
- CMDs:
  - A set of basic fs commands, like ls,cp,rm,mv ...
  - Other commands one expects from a OS like beep,reboot,shutdown,time...
- Misc:
  - A drone-model with "wield-points" for tools and peripherals.
  - ~~Textures~~
  - Sounds (like, beeep)
  - Some good examples / tutorials

This list is constantly changing, so don't rely on it.
  
  
  
##Pictures:
Closeup of a display:  
<img src="http://dunkelraum.net/share/screen5.png"/>  

Drone's front:  
<img src="http://dunkelraum.net/share/screen7.png"/>  

