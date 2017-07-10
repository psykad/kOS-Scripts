@LAZYGLOBAL OFF.

// Load libraries
run lib_pid.

// PID Controller Settings
global velocity_pid is PID_Init(0.1, 0.2, 0.005, 0, 1).
LOCAL altitude_pid IS PID_Init(0.2, 0.0, 0.050, -10, 10).
LOCAL pitch_pid IS PID_Init(2, 0.05, 0.05, -45, 45).
LOCAL yaw_pid IS PID_Init(2, 0.05, 0.05, -45, 45).

// Profiles
GLOBAL profileAsc IS "Ascending".
GLOBAL profileDesc IS "Descending".
GLOBAL profileOrb IS "Orbiting".

GLOBAL uiX IS 8.
GLOBAL spaces IS "          ".
LOCK surfacePrograde to R(0,0,0) * V(0-VELOCITY:SURFACE:X, 0-VELOCITY:SURFACE:Y, 0-VELOCITY:SURFACE:Z).
global targetVelocity is 0.
global currentThrottle is 0.

global steerDirection to UP + R(0,0,0).
global pitchOffset is 0.
global yawOffset is 0.
global offsetX is 1.

PRINT "Waiting for launch...".
WAIT UNTIL STATUS = "FLYING" OR STATUS = "SUB_ORBITAL".

PRINT "Waiting for descent...".
WAIT UNTIL GetProfile() = profileDesc.

PRINT "Hover descent started...".
SAS OFF.
LOCK STEERING TO steerDirection.
LOCK THROTTLE TO currentThrottle.

local surfVec is vecdraw().
local midProgradeec is vecdraw().

UNTIL STATUS = "LANDED" OR STATUS = "SPLASHED" {
	// local dirA is UP + R(0, 0, 180).
	// local dirB is surfacePrograde:direction.
	// local deltaPitch is dirA:pitch - dirB:pitch.
	// local deltaYaw is dirA:yaw - dirB:yaw.
	
	// local pitchAngle is round(vang(r(dirA:pitch, 0, 180):vector, r(dirB:pitch, 0, 180):vector)).
	// local yawAngle is round(vang(r(0, dirA:yaw, 180):vector, r(0, dirB:yaw, 180):vector)).
	
	// set pitchOffset to (pitchAngle / 6).
	// set yawOffset to (yawAngle / 6).
	
	// if deltaPitch < -5 and deltaPitch > -90 {
		// set pitchOffset to pitchOffset * 1.
	// } else if (deltaPitch < -275 and deltaPitch > -360) or (deltaPitch > 5 and deltaPitch < 90) {
		// set pitchOffset to pitchOffset * -1.
	// }
	
	// if deltaYaw > 5 and deltaYaw < 90{
		// set yawOffset to yawOffset * -1.
	// } else if deltaYaw < -5 and deltaYaw > -90 {
		// set yawOffset to yawOffset * 1.
	// }
	
	if GetTrueAltitude() > 500 {
		set targetVelocity to -100.
	}
	
	if GetTrueAltitude() < 500 {
		set targetVelocity to -14.
	} 
	
	if GetTrueAltitude() < 250 {
		set targetVelocity to -7.
	} 
	
	if GetTrueAltitude() < 100 {
		set targetVelocity to -3.
	} 
	
	if GetTrueAltitude() < 50 {
		set targetVelocity to -1.
	} 
	
	local midPrograde is (surfacePrograde:normalized + (up+r(0,0,0)):vector:normalized):normalized.

	if vang(midPrograde, (up+r(0,0,0)):vector) < 5 {
		SET pitchOffset TO -1 * PID_Seek(pitch_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:TOPVECTOR).
		SET yawOffset TO PID_Seek(yaw_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:STARVECTOR).					

		set steerDirection to up + r(pitchOffset, yawOffset, 0).		
	} else {
		set steerDirection to midPrograde.	
	}

	if GetTrueAltitude() < 50 {
		LOCAL targetAltitude IS PID_Seek(altitude_pid, 45, GetTrueAltitude()).
		SET steerDirection TO UP + R(0,0,0).
		
		SET currentThrottle TO PID_Seek(velocity_pid, targetAltitude, VERTICALSPEED).
	} ELSE {
		set currentThrottle to PID_Seek(velocity_pid, targetVelocity, VERTICALSPEED).
	}
	
	wait 0.1.	
}

LOCK THROTTLE TO 0.

function CalcDirectionDelta {
	parameter dirA, dirB.
	
	local deltaPitch is ABS(COS(dirA:PITCH)-COS(dirB:PITCH))
						+ABS(SIN(dirA:PITCH)-SIN(dirB:PITCH)).
	local deltaYaw is ABS(COS(dirA:YAW)-COS(dirB:YAW))
						+ABS(SIN(dirA:YAW)-SIN(dirB:YAW)).
		
	return deltaPitch + deltaYaw.
}

function DeltaToRetro {
	LOCAL deltaPitch IS ABS(COS(SHIP:FACING:PITCH)-COS(surfacePrograde:DIRECTION:PITCH))
						+ABS(SIN(SHIP:FACING:PITCH)-SIN(surfacePrograde:DIRECTION:PITCH)).
	LOCAL deltaYaw IS ABS(COS(SHIP:FACING:YAW)-COS(surfacePrograde:DIRECTION:YAW))
						+ABS(SIN(SHIP:FACING:YAW)-SIN(surfacePrograde:DIRECTION:YAW)).
		
	RETURN deltaPitch + deltaYaw.
}

function DeltaToUp {
	LOCAL deltaPitch IS ABS(COS(SHIP:FACING:PITCH)-COS(UP:PITCH))
						+ABS(SIN(SHIP:FACING:PITCH)-SIN(UP:PITCH)).
	LOCAL deltaYaw IS ABS(COS(SHIP:FACING:YAW)-COS(UP:YAW))
						+ABS(SIN(SHIP:FACING:YAW)-SIN(UP:YAW)).
		
	RETURN deltaPitch + deltaYaw.	
}

function GetProfile {
	IF STATUS = "LANDED" {
		RETURN "N/A".
	}
	
	IF APOAPSIS > 0 AND PERIAPSIS > 0 {
		RETURN profileOrb.
	}
	
	IF ETA:APOAPSIS < ETA:PERIAPSIS {
		RETURN profileAsc.
	} ELSE {
		RETURN profileDesc.
	}
}

function GetTrueAltitude {
	LOCAL terrainHeight IS SHIP:GEOPOSITION:TERRAINHEIGHT.
	
	IF ALT:RADAR = ALTITUDE {
		RETURN ALTITUDE.
	} ELSE {
		IF terrainHeight <= 0 { 
			SET terrainHeight TO 0.
		}
		
		RETURN ALTITUDE - terrainHeight.
	}
}