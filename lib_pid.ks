@LAZYGLOBAL OFF.

FUNCTION PID_Init { PARAMETER Kp, Ki, Kd, controlMin, controlMax.
	LOCAL P IS 0.
	LOCAL I IS 0.
	LOCAL D IS 0.
	LOCAL previousError IS 0.
	LOCAL previousOutput IS 0.
	
	LOCAL PID_Array IS LIST(Kp, Ki, Kd, controlMin, controlMax, P, I, D, previousError, previousOutput).
	
	RETURN PID_Array.
}

FUNCTION PID_Seek { PARAMETER PID_Array, targetValue, currentValue.
	// Fill LOCAL variables from input array.
	LOCAL Kp IS PID_Array[0].
	LOCAL Ki IS PID_Array[1].
	LOCAL Kd IS PID_Array[2].
	LOCAL controlMin IS PID_Array[3].
	LOCAL controlMax IS PID_Array[4].	
	LOCAL P IS PID_Array[5].
	LOCAL I IS PID_Array[6].
	LOCAL D IS PID_Array[7].
	LOCAL previousError IS PID_Array[8].
	LOCAL previousOutput IS PID_Array[9].	
	LOCAL dT IS 0.1.
	
	// Find new error.
	LOCAL error IS targetValue - currentValue.
	
	// Calculate integral.
	SET I TO I + (error * dT).
	
	IF I * Ki > controlMax {
		SET I TO controlMax / Ki.
	}
	
	IF I * Ki < controlMin {
		SET I TO controlMin / Ki.
	}
	
	// Calculate derivative.
	SET D TO (error - previousError) / dT.
	
	// Calculate new output.
	LOCAL output IS (Kp * error) + (Ki * I) + (Kd * D).
	
	IF output > controlMax {
		SET output TO controlMax.
	}
	
	IF output < controlMin {
		SET output TO controlMin.
	}
	
	// Update array with new values.
	SET PID_Array[5] TO P.
	SET PID_Array[6] TO I.
	SET PID_Array[7] TO D.
	SET PID_Array[8] TO error.
	SET PID_Array[9] TO output.
	
	RETURN output.
}