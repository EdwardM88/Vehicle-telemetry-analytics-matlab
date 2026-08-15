function telemetry = calculate_gears(telemetry)
    num1 = height(telemetry);
    raw_ratio = zeros(num1, 1);
    detected_gear = zeros(num1, 1);
    
    % gear ratio calcul without filter
    valid_data = (telemetry.Speed_OBD > 3);
    raw_ratio(valid_data) = telemetry.RPM(valid_data) ./ telemetry.Speed_OBD(valid_data);
    telemetry.RawRatio = raw_ratio;

    % clasification of gears based on conditions
    for i = 1:num1
        speed1 = telemetry.Speed_OBD(i);
        rpm1 = telemetry.RPM(i);
        ratio1 = telemetry.RawRatio(i);
    
        if speed1 > 5 && rpm1 > 850
            if ratio1  >= 85
                detected_gear(i) = 1;
            elseif ratio1 >= 55 && ratio1 < 85
                detected_gear(i) = 2;
            elseif ratio1 >= 35 && ratio1 < 55
                detected_gear(i) = 3;
            elseif ratio1 >= 22 && ratio1 < 35
                detected_gear(i) = 4;
            elseif ratio1 >= 14 && ratio1 < 22
                detected_gear(i) = 5;
            elseif ratio1 > 0 && ratio1 < 14
                detected_gear(i) = 6;
            else
                detected_gear(i) = 0;
            end
        else
            detected_gear(i) = 0;
        end
    end
    
    telemetry.DetectedGearR = detected_gear;
    
    % clucht filter
    telemetry.Gear = medfilt1(telemetry.DetectedGearR, 5);
end