# EWRS
Early Warning Radar Script for DCS World

	Features:
		- Uses in-game radar information to detect targets so terrain masking, beaming, low altitude flying, etc is effective for avoiding detection
		- Dynamic. If valid units with radar are created during a mission (eg. via chopper with CTLD), they will be added to the EWRS radar network
		- Can allow / disable BRA messages to fighters or sides
		- Uses player aircraft or mission bullseye for BRA reference, can be changed via F10 radio menu or restricted to one reference in the script settings
		- Can switch between imperial (feet, knots, NM) or metric (meters, km/h, km) measurements using F10 radio menu
		- Ability to change the message display time and update interval
		- Can choose to disable automated messages and allow players to request BRA from F10 menu
		- Can allow players to request Bogey Dope at any time through F10 radio menu

	At the moment, because of limitations within DCS to not show messages to individual units, the reference, measurements, and messages
	are done per group. So a group of 4 fighters will each receive 4 BRA messages. Each message however, will have the player's name
	in it, that its refering to. Its unfortunate, but nothing I can do about it.

# Script Setup
Setting up the script is easy. You will need MOOSE-  Available here:  https://github.com/FlightControl-Master

First open EWRS.lua in a text editor (Notepad++ is a good one to use), and set the script options how you want it setup. Its all commented in the code on what each one does.

Then in your mission, setup 2 triggers, one to load MOOSE and the other to load EWRS.lua. Your 2 finished triggers should look like this:

trigger -> Mission Start -> **no condition** -> DO SCRIPT FILE moose.lua

trigger -> ONCE -> TIME MORE 2 -> DO SCRIPT FILE EWRS.lua

The time more values are not that important, but just remember to load MOOSE first, and give it a couple of seconds before loading another script to ensure its fully loaded first.

###### NOTE
Any branch outside of 'master' have not been tested ingame yet and should be considered unstable
