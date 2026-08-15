function telemetry  = load_telemetry(fileName)
    %open file in read mode
fid = fopen(fileName,'r')

if fid == -1
   error('This file cannot not be oppened,please review the file! ');
else
    disp("The file is oppened successfully!");
end
% initialization the vectors
rpm_raw          = [];
speed_obd_raw    = [];
coolant_temp_raw = [];
oil_temp_raw     = [];
troque_raw       = [];
g_force_raw      = [];

% read and decodes json lines
lineIndex = 1 ; %index for json file line
while ~feof(fid)
    lineStr = fgetl(fid);
    
    if ischar(lineStr) && ~isempty(strtrim(lineStr))
        dataStruct = jsondecode(lineStr);
        
        % Extragere din Slave (Arduino)
        rpm_raw(lineIndex, 1)          = dataStruct.nodes.slave_simulator.data.engine_rpm;
        speed_obd_raw(lineIndex, 1)    = dataStruct.nodes.slave_simulator.data.vehicle_speed_km;
        coolant_temp_raw(lineIndex, 1) = dataStruct.nodes.slave_simulator.data.coolant_temp_c;
        oil_temp_raw(lineIndex, 1)     = dataStruct.nodes.slave_simulator.data.oil_temp_c;
        
        % Extragere din Master (ESP32)
        g_force_raw(lineIndex, 1)      = dataStruct.nodes.master_telemetry.data.g_force_x;
        
        lineIndex = lineIndex + 1;
    end
end
fclose(fid); % Inchidem fisierul

% filter dsp and create timetable
fs = 10;
dt = 1 / fs;
num_sample = length(rpm_raw);

time = (0 : num_sample - 1)' * dt;


% filter for adxl sensor
window_size = 5;

g_force_filter = movmean(g_force_raw,window_size);
 
% Create table syncronized to timetable
telemetry = timetable(seconds(time), ...
    rpm_raw, speed_obd_raw, coolant_temp_raw, oil_temp_raw, ...
    g_force_raw, g_force_filter, ...
    'VariableNames', {'RPM', 'Speed_OBD', 'CoolantTemp', 'OilTemp', ...
                      'G_Force_Raw', 'G_Force_Filtered'});

% show first 5 lines for test
head(telemetry, 5)
end