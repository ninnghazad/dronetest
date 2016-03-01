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

You can type stuff using the display (with integrated keyboard) or directly on
the computer.

You can connect digiline-stuff to computer or use digiline to connect dronetest's 
peripherals. 

Type 'id' into input field (lower left) and click 'EXE'.  
Press 'ESC' to leave and watch display to see output.  
  
Also try 'time' or 'ls'. There are more commands, like 'dance' for drones.  

###Infos:

/rom is read-only  
/rom/apis contains all APIs  
/rom/bin contains all commands  
/ contains system's data  

Each virtual system is assigned a real folder on the server, within the the mod's folder named by it's id (sys.id).  
Systems must not ever have access to anything outside that directory.  

Userspace cannot access the minetest object, if that is possible, something is wrong.
APIs and /rom/bin-commands are allowed to do so, because they have to be installed by the server's admin,  
and are thusly deemed safe.

Take note of:
http://mesecons.net/developers.php

###Current problems:
  - There is a memleak with unloading textures somewhere in minetest, thusly using the display will leak memory, and sooner or later crash your system. to test computers running a long time, just set the display to some non-existant channel. May just be the texture-name-to-id cache...
  - New input method has to wait for https://github.com/minetest/minetest/pull/1737

##Roadmap:
Look around the source for examples on how to get stuff done.  
- Core:
  - Store data in world's instead of mod's folder.
  - Make drone inventories persist restarts: https://github.com/minetest/minetest/issues/1696
  - Better command-parser, with autocomplete.
  - Better shell, based on a better GUI. with color, and settable cursor-position, redraws...
  - Wrapping more important functions like load* and do*
- APIs:
  - See http://computercraft.info/wiki/Category:APIs for ideas.
- CMDs:
  - A set of basic fs commands, like ls,cp,rm,mv,beep,reboot,shutdown,time...
- Misc:
  - A drone-model with "wield-points" for tools and peripherals.
  - Sounds (like, beeep)
  - Some good examples / tutorials

This list is constantly changing, so don't rely on it.
  
  
  
##Pictures:
Closeup of a display:  
<img src="http://dunkelraum.net/share/screen5.png"/>  

Drone's front:  
<img src="http://dunkelraum.net/share/screen7.png"/>  

