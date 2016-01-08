--[[
	Early Warning Radar Script - 1.0 - 08/01/2016
	
	Allows use of units with radars to provide Bearing Range and Altitude information via text display to player aircraft
	
	Built and Tested in DCS 1.5.2 - See https://github.com/Bob7heBuilder/EWRS for the latest version
	
	This script uses MIST --  https://github.com/mrSkortch/MissionScriptingTools
	
	Features:
		- Uses in-game radar information to detect targets so terrain masking, beaming, low altitude flying, etc is effective for avoiding detection
		- Dynamic. If valid units with radar are created during a mission (eg. via chopper with CTLD), they will be added to the EWRS radar network
		- Can allow / disable BRA messages to fighters or sides
		- Uses player aircraft or mission bullseye for BRA reference, can be changed via F10 radio menu or restricted to one reference in the script settings
		- Can switch between imperial (feet, knots, NM) or metric (meters, km/h, km) measurements using F10 radio menu
		- Ability to change the message display time and update interval
		
	At the moment, because of limitations within DCS to not show messages to individual units, the reference, measurements, and messages
	are done per group. So a group of 4 fighters will each receive 4 BRA messages. Each message however, will have the player's name
	in it, that its refering to. Its unfortunate, but nothing I can do about it.
]]

ewrs = {} --DO NOT REMOVE
ewrs.HELO = 1
ewrs.ATTACK = 2
ewrs.FIGHTER = 3

----SCRIPT OPTIONS----

ewrs.messageUpdateInterval = 30 --How often EWRS will update BRA messages (seconds)**NOT TO BE LESS THEN 5 seconds**
ewrs.messageDisplayTime = 25 --How long EWRS BRA messages will show for (seconds)
ewrs.restrictToOneReference = false -- Disables the ability to change the BRA calls from pilot's own aircraft or bullseye. If this is true, set ewrs.defaultReference to the option you want to restrict to.
ewrs.defaultReference = "self" --The default reference for BRA calls - can be changed via f10 radio menu if ewrs.restrictToOneReference is false (self or bulls)
ewrs.defaultMeasurements = "imperial" --Default measurement units - can be changed via f10 radio menu (imperial or metric)
ewrs.disableFightersBRA = false -- disables BRA messages to fighters when true
ewrs.enableRedTeam = true -- enables / disables EWRS for the red team
ewrs.enableBlueTeam = true -- enables / disables EWRS for the blue team

--[[
Units with radar to use as part of the EWRS radar network
If you want to shorten the range of SAM radar detection, use their track radars instead of their search radars
NOTE that track radars require a search radar to detect targets (but the search radars do not need to be included in the list)
I haven't tested detection with ships (that have radar), but should work.
]]
ewrs.validSearchRadars = {
"p-10 s125 sr",			--SA-3 Search Radar
"Kub 1S91 str",			--SA-6 Search and Track Radar
"S-300PS 64H6E sr",		--SA-10 Search Radar
"S-300 PS 40B6MD sr",	--SA-10 Search Radar
"SA-11 Buk SR 9518M1",	--SA-11 Search Radar
"55G6 EWR",				--Early Warning Radar
"1L13 EWR",				--Early Warning Radar
"A-50",					--AWACS
"E-2D",					--AWACS
"E-3A",					--AWACS
"Roland Radar",			--Roland Search Radar
"Hawk sr",				--Hawk SAM Search Radar
"Patriot str"			--Patriot SAM Search and Track Radar
}

--[[
Aircraft Type ENUMs
This is used to restrict BRA messages to fighters
Change the ewrs.TYPE for each aircraft (in ewrs.acCategories) to suit your needs
For now, BRA will be displayed to everyone unless ewrs.disableFightersBRA is true.
When this is true, anything in the list below that == ewrs.FIGHTER will NOT receive BRA messages
]]
ewrs.acCategories = { --Have I left anything out? Please let me know if I have
[ "A-10A"          ] = ewrs.ATTACK  ,
[ "A-10C"          ] = ewrs.ATTACK  ,
[ "Bf-109K-4"      ] = ewrs.ATTACK  ,
[ "C-101EB"        ] = ewrs.ATTACK  ,
[ "F-15C"          ] = ewrs.FIGHTER ,
[ "FW-190D9"       ] = ewrs.ATTACK  ,
[ "Hawk"           ] = ewrs.ATTACK  ,
[ "Ka-50"          ] = ewrs.HELO    ,
[ "L-39C"		   ] = ewrs.ATTACK	,
[ "Mi-8MT"         ] = ewrs.HELO    , --This is the Mi-8 module. For some reason its ingame name is shortened
[ "MiG-15bis"      ] = ewrs.ATTACK  ,
[ "MiG-21Bis"      ] = ewrs.ATTACK  ,
[ "MiG-29A"		   ] = ewrs.FIGHTER	,
[ "MiG-29S"		   ] = ewrs.FIGHTER	,
[ "M2000C" 		   ] = ewrs.FIGHTER	,
[ "P-51D"          ] = ewrs.ATTACK	,
[ "Su-25"          ] = ewrs.ATTACK	,
[ "Su-25T"         ] = ewrs.ATTACK	,
[ "Su-27"          ] = ewrs.FIGHTER	,
[ "TF-51D"         ] = ewrs.ATTACK	,
[ "UH-1H"          ] = ewrs.HELO
}

----END OF SCRIPT OPTIONS----

function ewrs.getDistance(obj1PosX, obj1PosZ, obj2PosX, obj2PosZ)
	local xDiff = obj1PosX - obj2PosX
	local yDiff = obj1PosZ - obj2PosZ
	return math.sqrt(xDiff * xDiff + yDiff * yDiff) -- meters
end

function ewrs.getBearing(obj1PosX, obj1PosZ, obj2PosX, obj2PosZ)
    bearing = math.atan2(obj2PosZ - obj1PosZ, obj2PosX - obj1PosX)
    if bearing < 0 then
        bearing = bearing + 2 * math.pi
    end
    bearing = bearing * 180 / math.pi
    return bearing    -- degrees
end

function ewrs.getHeading(vec)
    local heading = math.atan2(vec.z,vec.x)
    if heading < 0 then
        heading = heading + 2 * math.pi
    end
    heading = heading * 180 / math.pi
    return heading -- degrees
end

function ewrs.getSpeed(velocity)
	local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2) --m/s
	return speed -- m/s
end

function ewrs.main()
	timer.scheduleFunction(ewrs.main, nil, timer.getTime() + 1) --Schedule first incase of error
	ewrs.timer = ewrs.timer + 1
	
	-- update active players, settings table and radio menus (for new groups) every 5 seconds
	-- if update interval is not divisible by 5, it could take up to 9 seconds to update. Not an issue
	if ewrs.timer % 5 == 0 then
		ewrs.buildActivePlayers()
		ewrs.buildF10Menu()
	end

	if ewrs.timer >= ewrs.messageUpdateInterval then
		ewrs.timer = 0 -- reset timer
		ewrs.findRadarUnits()
		if #ewrs.blueEwrUnits > 0 then
			ewrs.currentlyDetectedRedUnits = ewrs.getRedDetectedUnits()
		end
		if #ewrs.redEwrUnits > 0 then
			ewrs.currentlyDetectedBlueUnits = ewrs.getBlueDetectedUnits()
		end
		ewrs.displayMessage()
	end
end

function ewrs.displayMessage()
	local function sortRanges(v1,v2)
		return v1.range < v2.range
	end
	
	for i = 1, #ewrs.activePlayers do
		if ewrs.activePlayers[i].side == 1 and #ewrs.redEwrUnits > 0 or ewrs.activePlayers[i].side == 2 and #ewrs.blueEwrUnits > 0 then
		
			local targets = {}
			if ewrs.activePlayers[i].side == 2 then
				targets = ewrs.currentlyDetectedRedUnits
			else
				targets = ewrs.currentlyDetectedBlueUnits
			end
			
			local referenceX
			local referenceZ --which is really Y, but Z with DCS vectors
			local playerName = ewrs.activePlayers[i].player
			local groupID = ewrs.activePlayers[i].groupID
			if ewrs.groupSettings[tostring(groupID)].reference == "self" then
				local self = Unit.getByName(ewrs.activePlayers[i].unitname)
				local selfpos = self:getPosition()
				referenceX = selfpos.p.x
				referenceZ = selfpos.p.z
			else
				local bullseye = coalition.getMainRefPoint(ewrs.activePlayers[i].side)
				referenceX = bullseye.x
				referenceZ = bullseye.z
			end
	
			local message = {}
			local tmp = {}
			
			--these are used for labeling text output.
			local altUnits
			local speedUnits
			local rangeUnits
			
			if ewrs.groupSettings[tostring(groupID)].measurements == "metric" then
				altUnits = "m"
				speedUnits = "Km/h"
				rangeUnits = "Km"
			else
				altUnits = "ft"
				speedUnits = "Knts"
				rangeUnits = "NM"
			end
		
			for k,v in pairs(targets) do
						
				local velocity = v:getVelocity()
				local bogeypos = v:getPosition()
				local bogeyType = v:getTypeName()
				local bearing = ewrs.getBearing(referenceX,referenceZ,bogeypos.p.x,bogeypos.p.z)
				local heading = ewrs.getHeading(velocity)
				local range = ewrs.getDistance(referenceX,referenceZ,bogeypos.p.x,bogeypos.p.z) -- meters
				local altitude = bogeypos.p.y --meters
				local speed = ewrs.getSpeed(velocity) --m/s
			
				if ewrs.groupSettings[tostring(groupID)].measurements == "metric" then
					range = range / 1000 --change to KM
					speed = mist.utils.mpsToKmph(speed)
					--altitude already in meters
				else
					range = mist.utils.metersToNM(range)
					speed = mist.utils.mpsToKnots(speed)
					altitude = mist.utils.metersToFeet(altitude)
				end
				
				local j = #tmp + 1
				tmp[j] = {}
				tmp[j].unitType = bogeyType
				tmp[j].bearing = bearing
				tmp[j].range = range
				tmp[j].altitude = altitude
				tmp[j].speed = speed
				tmp[j].heading = heading
			end
		
			table.sort(tmp,sortRanges)
		
			if #targets >= 1 then
				--Display table
				table.insert(message, "\n")
				table.insert(message, "EWRS Picture Report for: " .. playerName .. " -- Reference: " .. ewrs.groupSettings[tostring(groupID)].reference)
				table.insert(message, "\n\n")
				table.insert(message, string.format( "%-16s", "TYPE"))
				table.insert(message, string.format( "%-12s", "BRG"))
				table.insert(message, string.format( "%-12s", "RNG"))
				table.insert(message, string.format( "%-21s", "ALT"))
				table.insert(message, string.format( "%-15s", "SPD"))
				table.insert(message, string.format( "%-3s", "HDG"))
				table.insert(message, "\n")
		
				for k = 1, #tmp do
					table.insert(message, "\n")
					table.insert(message, string.format( "%-16s", tmp[k].unitType))
					table.insert(message, string.format( "%03d", tmp[k].bearing))
					table.insert(message, string.format( "%8.1f %s", tmp[k].range, rangeUnits))
					table.insert(message, string.format( "%9d %s", tmp[k].altitude, altUnits))
					table.insert(message, string.format( "%9d %s", tmp[k].speed, speedUnits))
					table.insert(message, string.format( "         %03d", tmp[k].heading))
					table.insert(message, "\n")
				end
				trigger.action.outTextForGroup(groupID, table.concat(message), ewrs.messageDisplayTime)
			else -- no targets detected
				trigger.action.outTextForGroup(groupID, "\nEWRS Picture Report for: " .. playerName .. "\n\nNo targets detected", ewrs.messageDisplayTime)
			end -- if #targets >= 1 then
		end -- if ewrs.activePlayers[i].side == 1 and #ewrs.redEwrUnits > 0 or ewrs.activePlayers[i].side == 2 and #ewrs.blueEwrUnits > 0 then
	end -- for i = 1, #ewrs.activePlayers do
end

function ewrs.buildActivePlayers()
	local redFixedWing = coalition.getGroups(1,Group.Category.AIRPLANE)
	local redRotorWing = coalition.getGroups(1,Group.Category.HELICOPTER)
	local blueFixedWing = coalition.getGroups(2,Group.Category.AIRPLANE)
	local blueRotorWing = coalition.getGroups(2,Group.Category.HELICOPTER)
	local groups = {}
	
	for i = 1, #redFixedWing do
		table.insert(groups, redFixedWing[i])
	end
	for i = 1, #redRotorWing do
		table.insert(groups, redRotorWing[i])
	end
	for i = 1, #blueFixedWing do
		table.insert(groups, blueFixedWing[i])
	end
	for i = 1, #blueRotorWing do
		table.insert(groups, blueRotorWing[i])
	end
	
	ewrs.activePlayers = {}
	for i = 1, #groups do
		local group = groups[i]
		if group ~= nil then
			local units = group:getUnits()
			for u = 1, #units do
				local unit = units[u]
				if unit ~= nil and unit:isActive() then
					playerName = unit:getPlayerName()
					if playerName ~= nil then
						unitCategory = ewrs.acCategories[unit:getTypeName()]
						if ewrs.disableFightersBRA and unitCategory == ewrs.FIGHTER then
							--DONT DO ANYTHING
						else
							if ewrs.enableBlueTeam and unit:getCoalition() == 2 then
								ewrs.addPlayer(playerName, group:getID(), unit)
							elseif ewrs.enableRedTeam and unit:getCoalition() == 1 then
								ewrs.addPlayer(playerName, group:getID(), unit)
							end
						end --if ewrs.disableFightersBRA and unitCategory == ewrs.FIGHTER then
					end --if playerName ~= nil
				end --if unit~= nil
			end --for u = 1, #units
		end --if group ~= nil
	end -- for i = 1, #groups
end

function ewrs.addPlayer(playerName, groupID, unit )
	local i = #ewrs.activePlayers + 1
	ewrs.activePlayers[i] = {}
	ewrs.activePlayers[i].player = playerName
	ewrs.activePlayers[i].groupID = groupID
	ewrs.activePlayers[i].unitname = unit:getName()
	ewrs.activePlayers[i].side = unit:getCoalition() 
	
	-- add default settings to settings table if it hasn't been done yet
	if ewrs.groupSettings[tostring(groupID)] == nil then
		ewrs.addGroupSettings(tostring(groupID))
	end
end

-- filters units so ones detected by multiple radar sites still only get listed once
-- missiles can be detected by some radars. It removes any detections that are not Object.Category.UNITs
function ewrs.filterUnits(units)
	local newUnits = {}
	for k,v in pairs(units) do
		local valid = true
		local category = v:getCategory()
		if category ~= Object.Category.UNIT then valid = false end
		if valid then
			for nk,nv in pairs (newUnits) do --recursive loop, can't see a way around this
				if v:getName() == nv:getName() then valid = false end
			end
		end
		
		if valid then
			table.insert(newUnits, v)
		end
	end
	return newUnits
end

function ewrs.getRedDetectedUnits()
	local units = {}
	for n = 1, #ewrs.blueEwrUnits do
		local ewrUnit = Unit.getByName(ewrs.blueEwrUnits[n])
		if ewrUnit ~= nil then
			ewrControl = ewrUnit:getGroup():getController()
			local detectedTargets = ewrControl:getDetectedTargets(Controller.Detection.RADAR)
			for k,v in pairs(detectedTargets) do
				table.insert(units, v["object"])
			end
		end -- if ewrUnit ~= nill
	end --for n = 1, #ewrs.ewrUnits
	return ewrs.filterUnits(units)
end

function ewrs.getBlueDetectedUnits()
	local units = {}
	for n = 1, #ewrs.redEwrUnits do
		local ewrUnit = Unit.getByName(ewrs.redEwrUnits[n])
		if ewrUnit ~= nil then
			ewrControl = ewrUnit:getGroup():getController()
			local detectedTargets = ewrControl:getDetectedTargets(Controller.Detection.RADAR)
			for k,v in pairs(detectedTargets) do
				table.insert(units, v["object"])
			end
		end -- if ewrUnit ~= nill
	end --for n = 1, #ewrs.ewrUnits
	return ewrs.filterUnits(units)
end

function ewrs.findRadarUnits()
	local filter = { "[all][plane]", "[all][vehicle]", "[all][ship]"}
	local all_vecs = mist.makeUnitTable(filter)
	local redUnits = {}
	local blueUnits = {}
	
	for i = 1, #all_vecs do
		local vec = Unit.getByName(all_vecs[i])
	
		if vec ~= nil then
			if Unit.isActive(vec) then
				local vec_type = Unit.getTypeName(vec)
				for n = 1, #ewrs.validSearchRadars do
					if ewrs.validSearchRadars[n] == vec_type and Unit.getCoalition(vec) == 2 then
						table.insert(blueUnits, Unit.getName(vec))
						break
					end
					if ewrs.validSearchRadars[n] == vec_type and Unit.getCoalition(vec) == 1 then
						table.insert(redUnits, Unit.getName(vec))
						break
					end
				end --for n = 1, #ewrs.validSearchRadars do
			end --if Unit.isActive(vec) then
		end --if vec ~= nil then
	end --for i = 1, #all_vecs do
	ewrs.blueEwrUnits = blueUnits
	ewrs.redEwrUnits = redUnits
end

function ewrs.addGroupSettings(groupID)
	ewrs.groupSettings[groupID] = {}
	ewrs.groupSettings[groupID].reference = ewrs.defaultReference
	ewrs.groupSettings[groupID].measurements = ewrs.defaultMeasurements
end

function ewrs.setGroupReference(args)
	local groupID = args[1]
	ewrs.groupSettings[tostring(groupID)].reference = args[2]
	trigger.action.outTextForGroup(groupID,"Reference changed to "..args[2],ewrs.messageDisplayTime)
end

function ewrs.setGroupMeasurements(args)
	local groupID = args[1]
	ewrs.groupSettings[tostring(groupID)].measurements = args[2]
	trigger.action.outTextForGroup(groupID,"Measurement units changed to "..args[2],ewrs.messageDisplayTime)
end


function ewrs.buildF10Menu()
	for i = 1, #ewrs.activePlayers do
		local groupID = ewrs.activePlayers[i].groupID
		local stringGroupID = tostring(groupID)
		if ewrs.builtF10Menus[stringGroupID] == nil then
			local rootPath = missionCommands.addSubMenuForGroup(groupID, "EWRS")
			if not ewrs.restrictToOneReference then
				local referenceSetPath = missionCommands.addSubMenuForGroup(groupID,"Set GROUP's reference point", rootPath)
				missionCommands.addCommandForGroup(groupID, "Set to Bullseye",referenceSetPath,ewrs.setGroupReference,{groupID, "bulls"})
				missionCommands.addCommandForGroup(groupID, "Set to Self",referenceSetPath,ewrs.setGroupReference,{groupID, "self"})
			end
			
			local measurementsSetPath = missionCommands.addSubMenuForGroup(groupID,"Set GROUP's measurement units",rootPath)
			missionCommands.addCommandForGroup(groupID, "Set to Imperial (feet, knts)",measurementsSetPath,ewrs.setGroupMeasurements,{groupID, "imperial"})
			missionCommands.addCommandForGroup(groupID, "Set to Metric (meters, km/h)",measurementsSetPath,ewrs.setGroupMeasurements,{groupID, "metric"})
			ewrs.builtF10Menus[stringGroupID] = true
		end
	end
end

--SCRIPT INIT
ewrs.currentlyDetectedRedUnits = {}
ewrs.currentlyDetectedBlueUnits = {}

ewrs.redEwrUnits = {}
ewrs.blueEwrUnits = {}

ewrs.activePlayers = {}
ewrs.groupSettings = {}

ewrs.builtF10Menus = {}
ewrs.timer = 0

if ewrs.messageUpdateInterval < 5 then --Just in case they set the message update interval less then 5.
	ewrs.messageUpdateInterval = 5
end

trigger.action.outText("EWRS by Steggles is now running",15)

ewrs.main()

--[[
TODO: 
	- Improved detection logic
		- Use detectedTarget.type to see if unit type is known
		- Use detectedTarget.distance to see if distance is known
		- Implementing these will make ECM effective too - Not sure how to implement distance if its not known. If distance isn't known, BRA is impossible to calculate
			Just have threat detected in message and dont give any BRA info?? Leave it out completely? Is there a formula to be able to give bearing between xxx-xxx ?? 
]]
