// Misc
SET atmosphere TO 50000.
SET uiX TO 10.
SET blankOut TO "                    ".

// Profiles
SET profileAsc TO "Ascending".
SET profileDesc TO "Descending".
SET profileOrb TO "Orbiting".

// Modes
SET modeIdle TO "Idle".
SET modePreLaunch TO "PreLaunch".
SET modeAscent TO "Ascent".
SET modeOrbit TO "Orbiting".
SET modeSubOrbit TO "SubOrbit".
SET modePreDescent TO "PreDescent".
SET modeDescent TO "Descent".
SET modeChuteDescent TO "ChuteDescent".
SET modeLanded TO "Landed".

// Sensors
LOCK gravity TO SHIP:SENSORS:GRAV:MAG.
LOCK acc TO SHIP:SENSORS:ACC:MAG.
LOCK orbitSpeed TO VELOCITY:ORBIT:MAG.
LOCK surfaceSpeed TO VELOCITY:SURFACE:MAG.

//*** Main Routine ***
SET mode TO modePreLaunch.

DrawUI.

UNTIL false {
	SetMode().
	
	IF mode = modeAscent {
		IF STATUS = "ORBITING" {
			SET mode TO modeOrbit.
		}
	} ELSE IF mode = modePreDescent {
		DeactivateCommAntenna().		
		SET GEAR TO false.	
		SET mode TO modeDescent.				
	} ELSE IF mode = modeDescent {
		IF GetTrueAltitude() < 5000 {
			DropHeatShield().
			WAIT 1.
			UNLOCK STEERING.
			WAIT 1.
			DeployChutes().
			WAIT 1.
			SET GEAR TO true.

			SET mode TO modeChuteDescent.			
		} ELSE {
			AdjustSteering().
		}	
	} ELSE IF mode = modeLanded {
		LOCK STEERING TO UP.
		ActivateCommAntenna().
		
		SET mode TO modeIdle.		
	}
	
	DrawStats().
	WAIT 0.1.
}
//*** End Main Routine ***

function SetMode {
	IF STATUS = "PRELAUNCH" {
		IF mode <> modePreLaunch {
			SET mode TO modePreLaunch.
		}		
	} ELSE IF STATUS = "FLYING" {
		IF mode = modePreLaunch {
			SET mode TO modeAscent.
		} ELSE IF mode = modeOrbit OR mode = modeSubOrbit {
			SET mode TO modePreDescent.
		} ELSE IF mode = modeDescent {
		}		
	} ELSE IF STATUS = "SUB_ORBITAL" {	
		SET mode TO modeSubOrbit.
	} ELSE IF STATUS = "ORBITING" {
		SET mode TO modeOrbit.
	} ELSE IF STATUS = "LANDED" OR STATUS = "SPLASHED" {
		IF mode <> modeLanded {
			SET mode TO modeLanded.
		}
	}
}

function DrawUI {
	CLEARSCREEN.
	PRINT "Mode:" AT (0, 0).
	PRINT "Status:" AT (0, 1).
	PRINT "Comms:" AT (0, 2).
	PRINT "Delay:" AT (0, 3).
	PRINT "Alt:" AT (0, 4).
	PRINT "EC:" AT (0, 5).
	PRINT "AP:" AT (0, 6).
	PRINT "PE:" AT (0, 7).
	PRINT "OrbVel:" AT (0, 8).
	PRINT "SurfVel:" AT (0,9).
	PRINT "Pres:" AT (0, 10).
	PRINT "Temp:" AT (0, 11).
	PRINT "Grav:" AT (0, 12).
	PRINT "Acc:" AT (0, 13).
	PRINT "Gforce:" AT (0, 14).
	PRINT "Profile:" AT (0, 15).
}

function DrawStats {
	PRINT mode + blankOut AT (uiX, 0).
	PRINT STATUS + blankOut AT (uiX, 1).
	PRINT GetCommsStatus + blankOut AT (uiX, 2).
	PRINT GetCommsDelay() + blankOut AT (uiX, 3).
	PRINT ROUND(GetTrueAltitude()) + blankOut AT (uiX, 4).
	PRINT GetElectricCharge() + blankOut AT (uiX, 5).
	PRINT ROUND(ALT:APOAPSIS) + blankOut AT (uiX, 6).
	PRINT ROUND(ALT:PERIAPSIS) + blankOut AT (uiX, 7).
	PRINT ROUND(orbitSpeed, 1) + blankOut AT (uiX, 8).
	PRINT ROUND(surfaceSpeed, 1) + blankOut AT (uiX, 9).
	PRINT ROUND(SHIP:SENSORS:PRES, 2) + blankOut AT (uiX, 10).
	PRINT ROUND(SHIP:SENSORS:TEMP, 2) + blankOut AT (uiX, 11).
	PRINT ROUND(gravity, 2) + blankOut AT (uiX, 12).
	PRINT ROUND(acc, 2) + blankOut AT (uiX, 13).
	PRINT ROUND(acc/gravity, 1) + blankOut AT (uiX, 14).
	PRINT GetProfile() + blankOut AT (uiX, 15).
}

function GetProfile {
	IF ROUND(VELOCITY:SURFACE:MAG) = 0 {
		RETURN "N/A".
	}
	
	IF APOAPSIS > atmosphere AND PERIAPSIS > atmosphere {
		RETURN profileOrb.
	}
	
	IF ETA:APOAPSIS < ETA:PERIAPSIS {
		RETURN profileAsc.
	} ELSE {
		RETURN profileDesc.
	}
}

function GetCommsStatus {
	IF ADDONS:RT:HASKSCCONNECTION(SHIP) = True {
		RETURN "Online".
	} ELSE {
		RETURN "Offline".
	}
}

function GetCommsDelay {
	IF ADDONS:RT:HASKSCCONNECTION(SHIP) {
		RETURN ROUND(ADDONS:RT:KSCDELAY(SHIP), 2).
	} ELSE {
		RETURN "Not Connected.".
	}
}

function GetElectricCharge {
	FOR res IN SHIP:RESOURCES {
		IF res:NAME = "ElectricCharge" {
			RETURN ROUND(100*res:AMOUNT/res:CAPACITY).
		}
	}
}

function GetTrueAltitude {
	SET altTrue TO 0.
	SET terrainHeight TO SHIP:GEOPOSITION:TERRAINHEIGHT.
	
	IF terrainHeight <= 0 { 
		SET terrainHeight TO 0.
	}
	
	IF ALT:RADAR = ALTITUDE {
		SET altTrue TO ALTITUDE.
	} ELSE {
		SET altTrue TO ALTITUDE - terrainHeight.
	}
	
	RETURN altTrue.
}

function ActivateCommAntenna {
	SHIP:PARTSTAGGED("mainCommsAntenna")[0]:GETMODULE("ModuleRTAntenna"):DOACTION("Activate", true).
}

function DeactivateCommAntenna {
	SHIP:PARTSTAGGED("mainCommsAntenna")[0]:GETMODULE("ModuleRTAntenna"):DOACTION("Deactivate", true).
}

function DeployChutes {
	SET shipChutes TO SHIP:PARTSDUBBED("parachuteRadial").
	
	FOR chute IN shipChutes {
		chute:GETMODULE("ModuleParachute"):DOEVENT("Deploy Chute").
	}	
}

function DropHeatShield {
	SHIP:PARTSTAGGED("heatShieldDecoupler")[0]:GETMODULE("ModuleDecouple"):DOEVENT("Decouple").
}

function ExtendSolarPanels {
	SET solarPanels TO SHIP:PARTSNAMED("solarPanels4").

	FOR solarPanel IN solarPanels {
		solarPanel:GETMODULE("ModuleDeployableSolarPanel"):DOEVENT("Extend Panels").
		WAIT 5.
	}
}

function AdjustSteering {
	SET shipPitch TO SHIP:FACING:PITCH.
	SET shipYaw TO SHIP:FACING:YAW.
	SET retroPitch TO SHIP:RETROGRADE:PITCH.
	SET retroYaw TO SHIP:RETROGRADE:YAW.	
	SET pitchDelta TO ROUND(ABS(retroPitch-shipPitch)).
	SET yawDelta TO ROUND(ABS(retroYaw-shipYaw)).	
	
	IF pitchDelta > 0 OR yawDelta > 0 {
		LOCK STEERING TO RETROGRADE.
	} ELSE {
		UNLOCK STEERING.
	}
}