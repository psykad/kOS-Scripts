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
LOCAL modePreSuicideBurn IS "Pre suicide burn".
LOCAL modeSuicideBurn IS "Suicide burn".
LOCAL modePreAdjustAoA IS "Pre Adjust AoA".
LOCAL modeAdjustAoA IS "Adjust AoA".
LOCAL modeDescent IS "Descent".
LOCAL modeFreeFall IS "Free fall".

// Locks
LOCK surfacePrograde TO R(0,0,0) * V(0-VELOCITY:SURFACE:X, 0-VELOCITY:SURFACE:Y, 0-VELOCITY:SURFACE:Z).

// PID Controllers
LOCAL velocity_pid IS PID_Init(0.1, 0.2, 0.005, 0, 1).
LOCAL altitude_pid IS PID_Init(0.2, 0.0, 0.050, -10, 10).
LOCAL pitch_pid IS PID_Init(2, 0.05, 0.05, -45, 45).
LOCAL yaw_pid IS PID_Init(2, 0.05, 0.05, -45, 45).

// Mission Settings
LOCAL programActive IS FALSE.
LOCAL mode IS modeIdle.
LOCAL targetBodyName IS "Mun".
LOCAL targetBodyMaxAltitude IS 5600.
LOCAL targetDescentVelocity IS -3.
LOCAL maxGroundSlope IS 5.
LOCAL currentThrottle IS 0.
LOCAL currentSteering IS surfacePrograde.
LOCAL geoAngleOffset IS 0.001.
LOCAL geoOffsetDistance IS 5.25.

// UI
LOCAL labelList IS LIST(
	"Active:",
	"Status:",
	"Profile:",
	"Mode:",
	"Alt:",
	"SB Alt:",
	"SB Time:",
	"GrndAngle:",
	"UpAngle:"
).

// Main Program
CLEARSCREEN.
DrawLabelList(labelList, 0, 0).
UNTIL FALSE {
	// Check if program should take control.
	IF STAGE:NUMBER = 0 AND GetProfile() = profileDescending {
		SET programActive TO TRUE.
	}
	
	IF STATUS = "LANDED" OR STATUS = "SPLASHED" {
		SET programActive TO FALSE.
	}
	
	IF programActive = TRUE {
		LOCK STEERING TO currentSteering.
		LOCK THROTTLE TO currentThrottle.
		
		IF GetTrueAltitude() < GetSuicideBurnAltitude() * 1.5
		AND mode <> modeSuicideBurn {
			// First thing we need to check is if we're within
			// suicide burn altitude range.
			SET mode TO modePreSuicideBurn.
		} ELSE IF GetTrueAltitude() < targetBodyMaxAltitude
		AND GetTrueAltitude() > 1000
		AND VANG(UP:VECTOR, surfacePrograde) > 45 {
			// We're at risk of hitting the side of a mountain.
			// Adjust angle of attack until we're coming in
			// at a better angle.		
			SET mode TO modePreAdjustAoA.
		} ELSE IF GetTrueAltitude() < 1000 {
			SET mode TO modeDescent.
		}
	} ELSE {
		SET mode TO modeIdle.
		
		UNLOCK STEERING.
		UNLOCK THROTTLE.		
	}
	
	IF mode = modePreSuicideBurn {
		SET currentSteering TO surfacePrograde.
		
		// Start aligning ship facing to surface prograde.
		IF CalculateDelta(SHIP:FACING, surfacePrograde:DIRECTION) < 0.1 { // TODO: See if VANG works better here.
			// We're lined up, wait for burn time.
			IF GetTimeToSuicideBurn() < 0.5 {
				SET currentThrottle TO 1.
				SET mode TO modeSuicideBurn.
			}
		} ELSE {
			// Kill throttle before starting the turn.
			// Don't want to start burning in some crazy direction.
			SET currentThrottle TO 0.			
		}
	} ELSE IF mode = modeSuicideBurn {
		SET currentSteering TO surfacePrograde.
		// Keep burning until velocity is very low.
		// 15 m/s is a good number to stop at.
		// Any lower and the thrust might spin the ship
		// around because we're locked to surface prograde.
		IF VELOCITY:SURFACE:MAG < 15 {
			// We're slow enough, kill engines.
			SET currentThrottle TO 0.	
			SET mode TO modeFreeFall.
		}
	} ELSE IF mode = modePreAdjustAoA {
		SET currentSteering TO surfacePrograde.
		
		// Wait until we're lined up with surface prograde.
		IF CalculateDelta(SHIP:FACING, surfacePrograde:DIRECTION) < 0.1 { // TODO: See if VANG works better here.
			// Start adjustments.
			SET currentThrottle TO 1.
			SET mode TO modeAdjustAoA.
		} ELSE {
			// Kill throttle while we wait for alignment.
			SET currentThrottle TO 0.
		}
	} ELSE IF mode = modeAdjustAoA {
		IF VANG(UP:VECTOR, surfacePrograde) < 45 {
			// We're now at a better AoA, kill throttle.
			SET currentThrottle TO 0.
			SET mode TO modeFreeFall.
		}
	} ELSE IF mode = modeDescent {
		// Setup starting descent velocities.
		IF GetTrueAltitude() < 1000 {
			SET targetDescentVelocity TO -50.
		}

		IF GetTrueAltitude() < 500 {
			SET targetDescentVelocity TO -25.
		}
		
		IF GetTrueAltitude() < 250 {
			SET targetDescentVelocity TO -12.
		}
		
		IF GetTrueAltitude() < 100 {
			SET targetDescentVelocity TO -6.
		}
		
		IF GetTrueAltitude() < 50 {
			// We're low enough now to start checking ground slope.
			// Lock ship up-right.
			SET currentSteering TO UP + R(0,0,0).
		} ELSE {
			LOCAL descentPrograde IS (surfacePrograde:NORMALIZED + (UP + R(0,0,0)):VECTOR:NORMALIZED):NORMALIZED.
			
			// Still descending, keep trying to reduce horizontal movement.
			// Check if we're way off from up-right, if so, lock to vector mid-way between up and surface.
			IF VANG(descentPrograde, (UP + R(0,0,0)):VECTOR) < 5 {
				// Let PID keep track of alignment.
				LOCAL pitchOffset IS -1 * PID_Seek(pitch_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:TOPVECTOR).
				LOCAL yawOffset IS PID_Seek(yaw_pid, 0, SHIP:VELOCITY:SURFACE * SHIP:FACING:STARVECTOR).		
				
				SET currentSteering TO UP + R(pitchOffset, yawOffset, 0).
			} ELSE {
				// We're way off, use mid-way vector.
				SET currentSteering TO descentPrograde.
			}
		}
		
		SET currentThrottle TO PID_Seek(velocity_pid, targetDescentVelocity, VERTICALSPEED).
	} ELSE IF mode = modeFreeFall {
		SET currentThrottle TO 0.
		SET currentSteering TO surfacePrograde.
	}
	
	// Update UI data.
	LOCAL dataList IS LIST(
		programActive,
		STATUS,
		GetProfile(),
		mode,
		ROUND(GetTrueAltitude(), 2),
		ROUND(GetSuicideBurnAltitude(), 2),
		ROUND(GetTimeToSuicideBurn(), 2),
		ROUND(GetGroundSlope(), 2),
		ROUND(VANG(UP:VECTOR, surfacePrograde), 2),
		GetPitchAngleOffset(),
		GetYawAngleOffset()
	).	
	
	DrawDataList(dataList, 15, 0).
	WAIT 0.01.
}

// Helper Functions
FUNCTION GetGroundSlope {
	LOCAL cPos IS SHIP:GEOPOSITION.
	LOCAL nPos IS LATLNG(cPos:LAT + geoAngleOffset, cPos:LNG).
	LOCAL ePos IS LATLNG(cPos:LAT, cPos:LNG + geoAngleOffset).
	LOCAL vecCN IS nPos:POSITION - cPos:POSITION.
	LOCAL vecCE IS ePos:POSITION - cPos:POSITION.
	LOCAL groundVector IS VCRS(vecCN, vecCE).
	
	RETURN VANG(UP:VECTOR, groundVector).
}

FUNCTION GetPitchAngleOffset {
	LOCAL offset IS 0.001.
	LOCAL cPos IS SHIP:GEOPOSITION.
	LOCAL nPos IS LATLNG(cPos:LAT + geoAngleOffset, cPos:LNG).
	LOCAL sPos IS LATLNG(cPos:LAT - geoAngleOffset, cPos:LNG).
	LOCAL angleNS IS ARCTAN((nPos:TERRAINHEIGHT - sPos:TERRAINHEIGHT) / geoOffsetDistance).
	
	IF angleNS > maxGroundSlope {
		RETURN 5.
	} ELSE {
		RETURN 0.
	}
}

FUNCTION GetYawAngleOffset {
	LOCAL offset IS 0.001.
	LOCAL cPos IS SHIP:GEOPOSITION.
	LOCAL ePos IS LATLNG(cPos:LAT, cPos:LNG + geoAngleOffset).
	LOCAL wPos IS LATLNG(cPos:LAT, cPos:LNG - geoAngleOffset).
	LOCAL angleEW IS ARCTAN((ePos:TERRAINHEIGHT - wPos:TERRAINHEIGHT) / geoOffsetDistance).
	
	IF angleEW > maxGroundSlope {
		RETURN 5.
	} ELSE {
		RETURN 0.
	}
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
	
	// TODO: Use constant gravity formula instead of ship sensors.
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