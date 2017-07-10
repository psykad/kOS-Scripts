@LAZYGLOBAL OFF.

RUN lib_core.
RUN lib_pid.
local spaces is "    ".

LOCK timeToImpact TO (ALTITUDE-SHIP:GEOPOSITION:TERRAINHEIGHT)/VELOCITY:SURFACE:MAG.

local velocity_pid is PID_Init(0.1, 0.2, 0.005, 0, 1).
local altitude_pid is PID_Init(0.1, 0.2, 0.05, 0, 1).
local pitch_pid is PID_Init(1, 0, 0, -45, 45).
local yaw_pid is PID_Init(1, 0, 0, -45, 45).

local targetAlt is 50.
local targetVelocity is -1.
local maxSlope is 5.

local offset is 0.0002464.
// local nDraw is vecdraw().
// local sDraw is vecdraw().
// local eDraw is vecdraw().
// local wDraw is vecdraw().

local currentThrottle is 0.
local steerDirection to UP + R(0,0,0).

CLEARSCREEN.
print "Waiting for descent...".
wait until GetProfile() = profileDesc.

sas off.
lock steering to steerDirection.
lock throttle to currentThrottle.

clearscreen.
UNTIL STATUS = "LANDED" OR STATUS = "SPLASHED" {
	local cPos is ship:geoposition.	
	local nPos is latlng(cPos:lat+offset, cPos:lng).
	local sPos is latlng(cPos:lat-offset, cPos:lng).
	local ePos is latlng(cPos:lat, cPos:lng+offset).
	local wPos is latlng(cPos:lat, cPos:lng-offset).
	
	local pitchOffset is -1 * PID_Seek(pitch_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:TOPVECTOR).
	local yawOffset is PID_Seek(yaw_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:STARVECTOR).		
		
	local angleNS is round(arctan((nPos:terrainheight-sPos:terrainheight)/5.25), 2).
	local angleEW is round(arctan((ePos:terrainheight-wPos:terrainheight)/5.25), 2).
	
	if abs(angleNS) > maxSlope {
		set pitchOffset to pitchOffset + 5.
	}
	
	if abs(angleEW) > maxSlope {
		set yawOffset to yawOffset + 5.
	}

	// set nDraw to vecdrawargs(nPos:altitudeposition(nPos:terrainheight+100),
		// nPos:position - nPos:altitudeposition(nPos:terrainheight+100),
		// red,"",1,true
	// ).
	// set sDraw to vecdrawargs(sPos:altitudeposition(sPos:terrainheight+100),
		// sPos:position - sPos:altitudeposition(sPos:terrainheight+100),
		// red,"",1,true
	// ).
	// set eDraw to vecdrawargs(ePos:altitudeposition(ePos:terrainheight+100),
		// ePos:position - ePos:altitudeposition(ePos:terrainheight+100),
		// red,"",1,true
	// ).
	// set wDraw to vecdrawargs(wPos:altitudeposition(wPos:terrainheight+100),
		// wPos:position - wPos:altitudeposition(wPos:terrainheight+100),
		// red,"",1,true
	// ).	
	
	if GetTrueAltitude() > 2000 {
		set targetVelocity to -100.
	}
	
	if GetTrueAltitude() < 1000 {
		set targetVelocity to -50.
	} 
	
	if GetTrueAltitude() < 500 {
		set targetVelocity to -14.
	} 
	
	if GetTrueAltitude() < 100 {
		set targetVelocity to -7.
	} 
	
	if GetTrueAltitude() < 50 {
		set targetVelocity to -3.
	} 
	
	if GetTrueAltitude() < 10 {
		set targetVelocity to -1.
	} 
	
	print round(pitchOffset) + " " + round(yawOffset) + spaces AT (0,1).
	print abs(angleNS) + " " + abs(angleEW) + spaces AT (0,2).
	
	if GetTrueAltitude() < 1000 and (abs(angleNS) > maxSlope or abs(angleEW) > maxSlope) {
		print "Seeking flatter                " at (0,0).
		set currentThrottle to PID_Seek(altitude_pid, 0, verticalspeed).		
	} else {
		print "Descending                  " at (0,0).
		set currentThrottle to PID_Seek(velocity_pid, targetVelocity, VERTICALSPEED).
	}
	
	set steerDirection to up + r(pitchOffset, yawOffset, 0).		
	
	print "tti: " + timeToImpact + spaces AT (0,3).
	
	wait 0.1.	
}

set currentThrottle to 0.
unlock throttle.
unlock steering.

function GetSuicideBurnAltitude {
	if ship:availablethrust = 0 {
		return "N/A".
	}	
	
	return (velocity:surface:mag^2)/(2*(ship:availablethrust/(ship:mass*ship:sensors:grav:mag))).
}

function GetTimeToSuicideBurn {
	local burnaltitude is GetSuicideBurnAltitude().
	
	if burnaltitude = "N/A" {
		return "N/A".
	}
	
	return (GetTrueAltitude()-burnaltitude)/velocity:surface:mag.
}
