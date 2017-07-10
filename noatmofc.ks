@LAZYGLOBAL OFF.

// Clear ship controls
SAS OFF.

// Load libraries
RUN lib_core.
RUN lib_pid.

// Modes
LOCAL modeIdle IS "Idle".
LOCAL modeFreeFall IS "Free fall".
LOCAL modePreSuicideBurn IS "Waiting for suicide burn".
LOCAL modeSuicideBurn IS "Suicide burn".
LOCAL modeDescent IS "Descent".
LOCAL modeAlignUp IS "Align up".

// Locks
LOCK surfacePrograde TO R(0,0,0) * V(0-VELOCITY:SURFACE:X, 0-VELOCITY:SURFACE:Y, 0-VELOCITY:SURFACE:Z).
LOCK timeToImpact TO (ALTITUDE-SHIP:GEOPOSITION:TERRAINHEIGHT)/VELOCITY:SURFACE:MAG.

// Settings
LOCAL mode IS modeIdle.
LOCAL message IS "".
LOCAL targetVelocity IS -50. // Default descent velocity.
LOCAL targetAltitude IS 20. // Default hover altitude.
LOCAL latlngOffset IS 0.0002464. // Used in generating NSEW points.
LOCAL latlngDistance IS 5.25. // Distance between NS/EW points.
LOCAL maxGroundSlope IS 5. // Greatest acceptable angle to land on.
LOCAL currentSteering IS surfacePrograde.

// PID Controllers
LOCAL velocity_pid IS PID_Init(0.1, 0.2, 0.005, 0, 1).
LOCAL altitude_pid IS PID_Init(0.1, 0.2, 0.05, 0, 1).
LOCAL pitch_pid IS PID_Init(2, 0.05, 0.05, -45, 45).
LOCAL yaw_pid IS PID_Init(2, 0.05, 0.05, -45, 45).

// UI
LOCAL labelList IS LIST(
	"Mode:",
	"Profile:",
	"Message:",
	"AGL:",
	"BurnAlt:",
	"TimeToBurn:",
	"TimeToImpact:"
).

// REGION: Main Program
UNLOCK STEERING.
UNLOCK THROTTLE.

CLEARSCREEN.
DrawLabelList(labelList, 0, 0).
UNTIL FALSE {
	SET message TO "". // Reset system message.
		
	// Check if we're low enough to prepare for suicide burn.
	IF GetTrueAltitude() < GetSuicideBurnAltitude()*1.5 {
		IF mode <> modeSuicideBurn {
			SET mode TO modePreSuicideBurn.
		}
	} ELSE IF GetTrueAltitude() < 5000 {
		IF ROUND(VANG(UP:VECTOR, surfacePrograde)) > 10 {
			LOCK STEERING TO currentSteering.
			SET mode TO modeAlignUp.
		} ELSE {
		}		

		SET mode TO modeDescent.
	} ELSE {	
		IF mode <> modePreSuicideBurn {
			LOCK STEERING TO currentSteering.
			SET mode TO modeFreeFall.
		}
	}
	
	IF mode = modePreSuicideBurn {
		// Make sure steering is lined up with surface prograde before burning.
		IF CalculateDelta(SHIP:FACING, surfacePrograde:DIRECTION) < 0.1 {
			// We're lined up, check if it's time to burn.
			IF GetTimeToSuicideBurn() < 0.5 OR mode = modeAlignUp {
				LOCK THROTTLE TO 1.
				
				SET mode TO modeSuicideBurn.
				SET message TO "Performing suicide burn".
			}			
		} ELSE {
			LOCK THROTTLE TO 0.
			SET currentSteering TO surfacePrograde.
			SET message TO "Locking to surface prograde".
		}
	} ELSE IF mode = modeSuicideBurn {		
		// Keep burning until velocity is very low.
		// 5m/s is a good number to check.
		// Any lower and the thrust will spin the ship
		// around because we're locked to the surface prograde.
		IF VELOCITY:SURFACE:MAG < 15 {
			LOCK THROTTLE TO 0.
			SET mode TO modeIdle.
		}
	} ELSE IF mode = modeDescent {
		// Set descent velocity.
		IF GetTrueAltitude() < 1000 {
			SET targetVelocity TO -50.
		}
		
		IF GetTrueAltitude() < 500 {		
			SET targetVelocity TO -15.
		}
		
		IF GetTrueAltitude() < 100 {
			SET targetVelocity TO -7.
		}
		
		IF GetTrueAltitude() < 50 {
			SET targetVelocity TO -1.
		}
				
		// Check the area surrounding the ship for ground slope.
		LOCAL cPos IS SHIP:GEOPOSITION.
		LOCAL nPos IS LATLNG(cPos:LAT+latlngOffset, cPos:LNG).
		LOCAL sPos IS LATLNG(cPos:LAT-latlngOffset, cPos:LNG).
		LOCAL ePos IS LATLNG(cPos:LAT, cPos:LNG+latlngOffset).
		LOCAL wPos IS LATLNG(cPos:LAT, cPos:LNG-latlngOffset).
		LOCAL angleNS IS ROUND(ARCTAN((nPos:TERRAINHEIGHT-sPos:TERRAINHEIGHT)/latlngDistance), 2).
		LOCAL angleEW IS ROUND(ARCTAN((ePos:TERRAINHEIGHT-wPos:TERRAINHEIGHT)/latlngDistance), 2).
		
		LOCAL pitchAngleOffset IS 0.
		LOCAL yawAngleOffset IS 0.		
		
		IF ABS(angleNS) > maxGroundSlope OR ABS(angleEW) > maxGroundSlope {
			SET message TO "Seeking flatter terrain".
			
			// Adjust pitch/yaw depending on direction of slope.
			IF ABS(angleNS) > maxGroundSlope {
				SET pitchAngleOffset TO 5.
			}
			
			IF ABS(angleEW) > maxGroundSlope {
				SET yawAngleOffset TO 5.				
			}
			
			// Set throttle to hover during seek.
			LOCK THROTTLE TO PID_Seek(altitude_pid, 0, VERTICALSPEED).
		} ELSE {
			SET message TO "Controlled descent".
			
			// Ground appears to be flat, continue descent.
			LOCK THROTTLE TO PID_Seek(velocity_pid, targetVelocity, VERTICALSPEED).
		}
		
		// Calculate pitch/yaw offset to keep horizontal velocity zero.		
		LOCAL pitchOffset IS -1 * PID_Seek(pitch_pid, pitchAngleOffset, SHIP:VELOCITY:SURFACE * SHIP:FACING:TOPVECTOR).
		LOCAL yawOffset IS PID_Seek(yaw_pid, yawAngleOffset, SHIP:VELOCITY:SURFACE * SHIP:FACING:STARVECTOR).
				
		// Adjust steering based on new offset.
		SET currentSteering TO UP + R(pitchOffset, yawOffset, 0).				
		
		print abs(angleNS) + " " + abs(angleEW) + "          " AT (0, 10).		
		print round(pitchAngleOffset, 2) + " " + round(yawAngleOffset, 2) + "           " AT (0, 11).
		
	} ELSE IF mode = modeFreeFall {
		LOCK STEERING TO surfacePrograde.
	} ELSE IF mode = modeIdle {
	}
	
	// Deploy landing legs once we're low enough.
	IF GetTrueAltitude() < 100 {
		// TODO: Lower landing legs.
	}
	
	IF STATUS = "LANDED" OR STATUS = "SPLASHED" {
		// Once we're landed, release controls, then exit loop.
		LOCK STEERING TO UP.
		LOCK THROTTLE TO 0.
		BREAK.
	}
	
	// Update UI data.
	LOCAL dataList IS LIST(
		mode,
		GetProfile(),
		message,
		ROUND(GetTrueAltitude()),
		ROUND(GetSuicideBurnAltitude()),
		ROUND(GetTimeToSuicideBurn(), 2),
		ROUND(timeToImpact, 2)
	).
	
	DrawDataList(dataList, 15, 0).
	
	WAIT 0.01.
}

CLEARSCREEN.
PRINT "Landing complete.".
// END REGION: Main Program

// REGION: Helper Functions
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

FUNCTION CalculateDelta { PARAMETER directionA, directionB.
	LOCAL pitchDelta IS ABS(COS(directionA:PITCH)-COS(directionB:PITCH))+ABS(SIN(directionA:PITCH)-SIN(directionB:PITCH)).
	LOCAL yawDelta IS ABS(COS(directionA:YAW)-COS(directionB:YAW))+ABS(SIN(directionA:YAW)-SIN(directionB:YAW)).
	
	RETURN pitchDelta+yawDelta.
}

FUNCTION DeployLandingGear {	
	LOCAL landingGearList IS SHIP:PARTSNAMED("landingLeg1-2").
}
// END REGION: Helper Functions