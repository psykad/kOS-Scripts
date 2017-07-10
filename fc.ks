@LAZYGLOBAL OFF.

// Include libraries
RUN lib_core.

// Main program
LOCAL labelList IS LIST(
	"Status:",
	"AGL:",
	"OrbSpd:",
	"SrfSpd:",
	"Ap:",
	"Pe:",
	"ApEta:",
	"PeEta:",
	"Incl:",
	"TWR:",
	"Grav:",
	"Acc:",
	"Pres:"
).
LOCAL dataList IS LIST().

CLEARSCREEN.

DrawLabelList(labelList, 0, 0).

UNTIL FALSE {
	SET dataList TO LIST(
		STATUS,
		ROUND(GetTrueAltitude(), 2),
		ROUND(VELOCITY:ORBIT:MAG, 2),
		ROUND(VELOCITY:SURFACE:MAG, 2),
		ROUND(APOAPSIS, 2),
		ROUND(PERIAPSIS, 2),
		ROUND(ETA:APOAPSIS, 2),
		ROUND(ETA:PERIAPSIS, 2),
		ROUND(OBT:INCLINATION, 2),
		ROUND(SHIP:AVAILABLETHRUST/(SHIP:MASS*SHIP:SENSORS:GRAV:MAG), 2),
		ROUND(SHIP:SENSORS:GRAV:MAG, 2),
		ROUND(SHIP:SENSORS:ACC:MAG, 2),
		ROUND(SHIP:SENSORS:PRES, 2)
	).
	
	DrawDataList(dataList, 10, 0).
}