@LAZYGLOBAL OFF.

PARAMETER targetTWR.

LOCAL engineList IS LIST().
LOCAL currentThrustLimit TO 100.

LOCK currentTWR TO SHIP:AVAILABLETHRUST/(SHIP:MASS*SHIP:SENSORS:GRAV:MAG).

CLEARSCREEN.

// Reset thrust limits.
LIST ENGINES IN engineList.

FOR engine IN engineList {
	SET engine:THRUSTLIMIT TO currentThrustLimit.
}

// TODO: Change to calibrate just above the target TWR.
// For example, if the next iteration brings the current TWR
// below the target TWR, undo the last change to the thrust
// limit and stop there. Being just above the target is 
// better than being below.

PRINT "Calibrating...".
UNTIL FALSE {
	// Check if current TWR is more than target TWR.
	IF currentTWR > targetTWR {
		SET currentThrustLimit TO currentThrustLimit - 0.5.
		
		IF currentThrustLimit < 5 {
			SET currentThrustLimit TO 5.
		}
		
		// Limit thrust on engines.
		LIST ENGINES IN engineList.
		
		FOR engine IN engineList {
			SET engine:THRUSTLIMIT TO currentThrustLimit.
		}
		
		IF currentThrustLimit = 5 {
			// It's as low as we can go.
			BREAK.
		}
	} ELSE {
		BREAK.
	}	
}

PRINT "Final TWR: " + currentTWR.
PRINT "Calibration complete!".