@LAZYGLOBAL OFF.

// Clear ship controls
SAS OFF.

// Load libraries
RUN lib_pid.

// Ship profiles
LOCAL profileAscending IS "Ascending".
LOCAL profileDescending IS "Descending".
LOCAL profileOrbiting IS "Orbiting".
LOCAL profileStationary IS "Stationary".

// Mission modes
LOCAL modeIdle IS "Idle".
LOCAL modeAdjustLandingAngle IS "Adjust angle".
LOCAL modePreSuicideBurn IS "Approaching suicide burn".
LOCAL modeSuicideBurn IS "Suicide burn".
LOCAL modeDescent IS "Controlled descent".
LOCAL modeFreeFall IS "Free fall".
LOCAL modeLanded IS "Landed".

// Locks
LOCK surfacePrograde TO R(0,0,0) * V(0-VELOCITY:SURFACE:X, 0-VELOCITY:SURFACE:Y, 0-VELOCITY:SURFACE:Z).
LOCK midThrottle TO SHIP:SENSORS:GRAV:MAG/SHIP:AVAILABLETHRUST.

// PID Controllers
LOCAL velocity_pid IS PID_Init(0.1, 0.2, 0.005, 0, 1).
LOCAL altitude_pid IS PID_Init(0.1, 0.2, 0.005, 0, 1).
LOCAL pitch_pid IS PID_Init(2, 0.05, 0.05, -45, 45).
LOCAL yaw_pid IS PID_Init(2, 0.05, 0.05, -45, 45).

// Mission Settings
LOCAL mode IS modeIdle.
LOCAL targetBodyName IS "Mun".
LOCAL targetBodyMaxAltitude IS 5600.
LOCAL targetDescentVelocity IS -3.
LOCAL currentThrottle IS 0.
LOCAL currentSteering IS surfacePrograde.

// UI
LOCAL labelList IS LIST(
	"Status:",
	"Profile:",
	"Mode:",
	"Alt:",
	"SB Alt:",
	"SB Time:",
	"GrndAngle:"
).

// Main Program
CLEARSCREEN.
DrawLabelList(labelList, 0, 0).
UNTIL FALSE {
	IF SHIP:BODY:NAME = targetBodyName AND STATUS = "SUB_ORBITAL" AND GetProfile() = profileDescending {
		LOCK STEERING TO currentSteering.
		LOCK THROTTLE TO currentThrottle.
		
		IF GetTrueAltitude() < targetBodyMaxAltitude 
			AND ROUND(VANG(UP:VECTOR, surfacePrograde)) > 25
			AND GetTrueAltitude() > 1000 {
			// Make sure we're not coming in with too steep of an angle.
			SET mode TO modeAdjustLandingAngle.
		} ELSE IF GetTrueAltitude() < GetSuicideBurnAltitude()*1.5 {
			// We're close to the predicted burn altitude, setup to suicide burn if not already set.
			IF mode <> modeSuicideBurn {
				SET mode TO modePreSuicideBurn.
			}
		} ELSE IF GetTrueAltitude() < 1000 {		
			SET mode TO modeDescent.
		} ELSE {
			SET mode TO modeFreeFall.
		}
	} ELSE IF STATUS = "LANDED" OR STATUS = "SPLASHED" {
		SET mode TO modeLanded.
	} ELSE {
		SET currentThrottle TO 0.
		UNLOCK STEERING.
		UNLOCK THROTTLE.
		SET mode TO modeIdle.		
	}
	
	IF mode = modeAdjustLandingAngle {
		// Check if we're actually facing surface prograde.
		IF CalculateDelta(SHIP:FACING, surfacePrograde:DIRECTION) < 0.1 {
			// We're lined up, start burning gently.
			SET currentThrottle TO 1.
		} ELSE {
			SET currentSteering TO surfacePrograde.
			SET currentThrottle TO 0.
		}
	} ELSE IF mode = modePreSuicideBurn {
		// Check if we're actually facing surface prograde.
		IF CalculateDelta(SHIP:FACING, surfacePrograde:DIRECTION) < 0.1 {
			// We're lined up, wait for burn time.
			IF GetTimeToSuicideBurn() < 0.5 {
				SET currentThrottle TO 1.
				SET mode TO modeSuicideBurn.
			}			
		} ELSE {
			SET currentSteering TO surfacePrograde.
			SET currentThrottle TO 0.
		}
	} ELSE IF mode = modeSuicideBurn {		
		// Keep burning until velocity is very low.
		// 5m/s is a good number to check.
		// Any lower and the thrust will spin the ship
		// around because we're locked to the surface prograde.
		IF VELOCITY:SURFACE:MAG < 15 {
			SET currentThrottle TO 0.
			SET mode TO modeFreeFall.
		}
	} ELSE IF mode = modeDescent {
		LOCAL pitchOffset IS -1 * PID_Seek(pitch_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:TOPVECTOR).
		LOCAL yawOffset IS PID_Seek(yaw_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:STARVECTOR).
		LOCAL pitchAngleOffset IS 0.
		LOCAL yawAngleOffset IS 0.
		
		// Set descent velocity.
		IF GetTrueAltitude() < 1000 {
			SET targetDescentVelocity TO -50.
		}
		
		IF GetTrueAltitude() < 500 {		
			SET targetDescentVelocity TO -15.
		}
		
		IF GetTrueAltitude() < 100 {
			SET targetDescentVelocity TO -7.
		}
		
		IF GetTrueAltitude() < 50 {
			SET targetDescentVelocity TO -1.
		}
		
		IF GetTrueAltitude() < 50 AND GetGroundSlope() > 15 {
			// Add to angle offset and hover until flat ground appears.
			SET pitchAngleOffset TO 5.
			SET yawAngleOffset TO 5.
			
			SET currentThrottle TO PID_Seek(velocity_pid, 25, GetTrueAltitude()).
		} ELSE {			
			SET currentThrottle TO PID_Seek(velocity_pid, targetDescentVelocity, VERTICALSPEED).
		}		
		
		SET currentSteering TO UP + R(pitchOffset + pitchAngleOffset, yawOffset + yawAngleOffset, 0).				
	} ELSE IF mode = modeFreeFall {
		SET currentSteering TO surfacePrograde.
		SET currentThrottle TO 0.
	} ELSE IF mode = modeLanded {		
		SET currentThrottle TO 0.
	} ELSE {		
		SET currentThrottle TO 0.
	}

	// Update UI data.
	LOCAL dataList IS LIST(
		STATUS,
		GetProfile(),
		mode,
		ROUND(GetTrueAltitude(), 2),
		ROUND(GetSuicideBurnAltitude(), 2),
		ROUND(GetTimeToSuicideBurn(), 2),
		ROUND(GetGroundSlope(), 2)
	).	
	
	DrawDataList(dataList, 15, 0).
	WAIT 0.01.
}

// Helper Functions
FUNCTION GetGroundSlope {
	LOCAL offset IS 0.001.
	LOCAL cPos IS SHIP:GEOPOSITION.
	LOCAL nPos IS LATLNG(cPos:LAT + offset, cPos:LNG).
	LOCAL ePos IS LATLNG(cPos:LAT, cPos:LNG + offset).
	LOCAL vecCN IS nPos:POSITION - cPos:POSITION.
	LOCAL vecCE IS ePos:POSITION - cPos:POSITION.
	LOCAL groundVector IS VCRS(vecCN, vecCE).
	
	RETURN VANG(UP:VECTOR, groundVector).
}

FUNCTION CalculateDelta { PARAMETER directionA, directionB.
	LOCAL pitchDelta IS ABS(COS(directionA:PITCH)-COS(directionB:PITCH))+ABS(SIN(directionA:PITCH)-SIN(directionB:PITCH)).
	LOCAL yawDelta IS ABS(COS(directionA:YAW)-COS(directionB:YAW))+ABS(SIN(directionA:YAW)-SIN(directionB:YAW)).
	
	RETURN pitchDelta+yawDelta.
}

FUNCTION GetSuicideBurnAltitude {
	IF SHIP:AVAILABLETHRUST = 0 {
		RETURN -1.
	}
	
	RETURN (VELOCITY:SURFACE:MAG^2)/(2*(SHIP:AVAILABLETHRUST/(SHIP:MASS*SHIP:SENSORS:GRAV:MAG))).
}

FUNCTION GetTimeToSuicideBurn {
	LOCAL burnAltitude IS GetSuicideBurnAltitude().
	
	IF burnAltitude < 0 {
		RETURN -1.
	}
	
	RETURN (GetTrueAltitude()-burnAltitude)/VELOCITY:SURFACE:MAG.
}

FUNCTION GetProfile {
	IF STATUS = "PRELAUNCH" OR STATUS = "LANDED" OR STATUS = "SPLASHED" {
		RETURN profileStationary.
	}
	
	IF APOAPSIS > 0 and PERIAPSIS > 0 {
		RETURN profileOrbiting.
	}
	
	IF ETA:APOAPSIS < ETA:PERIAPSIS {
		RETURN profileAscending.
	} ELSE {
		RETURN profileDescending.
	}	
}

FUNCTION GetTrueAltitude {
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

FUNCTION DrawLabelList { PARAMETER labelList, xPos, yPos.
	FOR label IN labelList {
		PRINT label AT (xPos, yPos).
		SET yPos TO yPos + 1.
	}
}

FUNCTION DrawDataList { PARAMETER dataList, xPos, yPos.
	LOCAL spaces IS "                              ".
	
	FOR data in dataList {
		PRINT data + spaces AT (xPos, yPos).
		SET yPos TO yPos + 1.
	}
}

FUNCTION GetCommStatus {	
	IF ADDONS:RT:HASKSCCONNECTION(SHIP) = TRUE {
		RETURN "Connected".
	} ELSE {
		RETURN "Not connection".
	}
}

FUNCTION GetCommDelay {
	IF ADDONS:RT:HASKSCCONNECTION(SHIP) {
		RETURN ROUND(ADDONS:RT:KSCDELAY(SHIP), 2).
	} ELSE {
		RETURN "Not connected".
	}
}