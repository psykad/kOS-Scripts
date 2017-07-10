@LAZYGLOBAL OFF.

// Load libraries
run lib_general.
run lib_pid.

// Flight computer modes
global modeIdle is "Idle".
global modeSuicideFreeFall is "Suicide free fall".
global modeSuicideBurn is "Suicide burn".
global modeDescent is "Descent".
global modeHover is "Hover".

// PID Controllers
global velocity_pid is PID_Init(0.1, 0.2, 0.005, 0, 1).
global pitch_pid is PID_Init(2, 0.05, 0.05, -45, 45).
global yaw_pid is PID_Init(2, 0.05, 0.05, -45, 45).

// Locks
lock surfacePrograde to R(0,0,0) * V(0-velocity:surface:X, 0-velocity:surface:Y, 0-velocity:surface:Z).

// Misc
global flightMode is modeIdle.
global displayMode is modeIdle.

// region: Main Program
sas off.
clearscreen.

DrawLabels().
until false {
	// Check status
	if status = "PRELAUNCH" {		
	} else if status = "FLYING" {
	} else if status = "SUB_ORBITAL" {
		if GetProfile() = profileDesc {
			if GetTrueAltitude() < GetSuicideBurnAltitude*1.1 {
				if flightMode <> modeSuicideBurn {
					sas off.
					set flightMode to modeSuicideFreeFall.
				}
			} else {
				if flightMode <> modeDescent {
					sas off.
					gear on.
					set flightMode to modeDescent.					
				}				
			}
		} else {
			set flightMode to modeIdle.
		}
	} else if status = "ORBITING" {
		set flightMode to modeIdle.
	} else if status = "LANDED" OR status = "SPLASHED" {
		set flightMode to modeIdle.
	}
	
	// Check flightMode.
	if flightMode = modeSuicideFreeFall {
		if CalcDeltaBetween(ship:facing, surfacePrograde:direction) < 0.1 {
			if GetTimeToSuicideBurn() < 0.5 and GetTrueAltitude() < (GetSuicideBurnAltitude()*1.1) {
				lock throttle to 1.
				
				set flightMode to modeSuicideBurn.
			}
		} else {
			lock steering to surfacePrograde.
		}
	} else if flightMode = modeSuicideBurn {
		if velocity:surface:mag < 5 {
			lock throttle to 0.
			
			set flightMode to modeIdle.
		}
	} else if flightMode = modeDescent {
		gear on. // TODO: Add code to manually extend landing gear.
		
		local pitchOffset is -1 * PID_Seek(pitch_pid, 0, ship:velocity:surface * ship:facing:topvector).
		local yawOffset is PID_Seek(yaw_pid, 0, ship:velocity:surface * ship:facing:starvector).
		local targetVelocity is -50.
		
		// Adjust target velocity based on altitude.
		if GetTrueAltitude() < 500 {
			set targetVelocity to -25.
		}
		
		if GetTrueAltitude() < 250 {
			set targetVelocity to -15.
		}
		
		if GetTrueAltitude() < 100 {
			set targetVelocity to -10.
		}		
		
		if GetTrueAltitude() < 50 {
			set targetVelocity to -5.
		}
		
		if GetTrueAltitude() < 25 {
			set targetVelocity to -1.
		}
		
		lock throttle to PID_Seek(velocity_pid, targetVelocity, verticalspeed).
		lock steering to up + R(pitchOffset, yawOffset, 0).
	} else if flightMode = modeIdle {
		unlock steering.
		unlock throttle.
	}	
	
	RefreshScreen().

	wait 0.1.
}
// end region: Main Program

// region: Helper Functions
function RefreshScreen {
	DrawLabels().
	DrawData().
}

function DrawLabels {
	local uiLabels is list().
	
	if displayMode <> flightMode {
		set displayMode to flightMode.
		clearscreen.
	}
	
	if displayMode = modeIdle {
		set uiLabels to list(
			"Status:",
			"Flight mode:",
			"Comms:",
			"Delay:",
			"Alt:",
			"AP:",
			"PE:",
			"OrbitV:",
			"SurfaceV:"
		).
	} else if displayMode = modeSuicideFreeFall or displayMode = modeSuicideBurn {
		set uiLabels to list(
			"Status:",
			"Flight mode:",
			"Comms:",
			"Delay:",
			"Alt:",
			"Burn alt:",
			"Time To Burn:"
		).	
	} else if displayMode = modeDescent {
		set uiLabels to list(
			"Status:",
			"Flight mode:",
			"Comms:",
			"Delay:",
			"Alt:",
			"Velocity:"
		).	
	}
 
	local i is 0.
	
	for label in uiLabels {
		print label at (0, i).
		set i to i+1.
	}
}

function DrawData {
	local xPos is 15.
	local yPos is 0.
	local spaces is "               ".
	local uiData is list().
		
	if displayMode = modeIdle {
		set uiData to list(
			status, 
			flightMode, 
			GetCommsstatus(), 
			GetCommsDelay() + "s",
			round(GetTrueAltitude(), 2),
			round(apoapsis, 2),
			round(periapsis, 2),
			round(velocity:orbit:mag) + "m/s",
			round(velocity:surface:mag) + "m/s"
		).
	} else if displayMode = modeSuicideFreeFall or displayMode = modeSuicideBurn {
		set uiData to list(
			status, 
			flightMode, 
			GetCommsstatus(), 
			GetCommsDelay() + "s",
			round(GetTrueAltitude(), 2),
			round(GetSuicideBurnAltitude(), 2),
			round(GetTimeToSuicideBurn(), 2) + "s"
		).		
	} else if displayMode = modeDescent {
		set uiData to list(
			status, 
			flightMode, 
			GetCommsstatus(), 
			GetCommsDelay() + "s",
			round(GetTrueAltitude(), 2),
			round(verticalspeed, 2)
		).		
	}
	
	for data in uiData {
		print data + spaces at (xPos, yPos).
		set yPos to yPos+1.
	}
}

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

function CalcDeltaBetween { parameter dirA, dirB.	
	local deltapitch is abs(cos(dirA:pitch)-cos(dirB:pitch))+abs(sin(dirA:pitch)-sin(dirB:pitch)).
	local deltayaw is abs(cos(dirA:yaw)-cos(dirB:yaw))+abs(sin(dirA:yaw)-sin(dirB:yaw)).
		
	return deltapitch + deltayaw.
}
// end region: Helper Functions