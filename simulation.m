%% open json file and reset
clear; clc;
fileName = 'measurement_real_simulator.json'

%open file in read mode
fid = fopen(fileName,'r')

if fid == -1
   error('This file cannot not be oppened,please review the file! ');
else
    disp("The file is oppened successfully!");
end
%% initialization the vectors
rpm_raw          = [];
speed_obd_raw    = [];
coolant_temp_raw = [];
oil_temp_raw     = [];
troque_raw       = [];
g_force_raw      = [];

%% read and decodes json lines
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
%% filter dsp and create timetable
fs = 10;
dt = 1 / fs;
num_sample = length(rpm_raw);

time = (0 : num_sample - 1)' * dt;


% filter for adxl sensor
window_size = 5;

g_force_filter = movmean(g_force_raw,window_size);
 
% Creare tabel sincronizat pe baza de timp
telemetry = timetable(seconds(time), ...
    rpm_raw, speed_obd_raw, coolant_temp_raw, oil_temp_raw, ...
    g_force_raw, g_force_filter, ...
    'VariableNames', {'RPM', 'Speed_OBD', 'CoolantTemp', 'OilTemp', ...
                      'G_Force_Raw', 'G_Force_Filtered'});

% show first 5 lines for test
head(telemetry, 5)
%% calculate ratio (ratio = rpm/speed for manual gearbox)
rpm_vec = telemetry.RPM;
speed_vec = telemetry.Speed_OBD;

num1 = height(telemetry);
raw_ratio = zeros(num1,1);

%calculate ratio for speed > 3 to avoid division to 0
valid_data = (speed_vec > 3);
raw_ratio(valid_data) = rpm_vec(valid_data) ./ speed_vec(valid_data);

telemetry.RawRatio = raw_ratio;

%% data view

%filter data(using speed > 5 for safety)
moving_mask = (telemetry.Speed_OBD > 5) & (telemetry.RPM > 700);
valid_ratio = telemetry.RawRatio(moving_mask);

% create figure
figure('Name','Transmission ratio distribution','NumberTitle','off','Color', [1 1 1]);

%
subplot(1, 2, 1);
scatter(telemetry.Speed_OBD(moving_mask), telemetry.RPM(moving_mask), 15, valid_ratio, 'filled');
xlabel('Speed (km/h)');
ylabel('(RPM)');
title('RPM & Speed Map');
grid on;
colorbar;
colormap('jet');

% histogram for gear ratio
subplot(1, 2, 2);
histogram(valid_ratio, 50, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
xlabel('Raport (RPM / Speed)');
ylabel('Număr Eșantioane (Frecvență)');
title('Transmission ratio distribution');
grid on;
xlim([0 120]);

%% gear clasification

num1 = height(telemetry);
detected_gear = zeros(num1,1);

%rules based on histogram

for i = 1:num1
    speed1 = telemetry.Speed_OBD(i);
    rpm1 = telemetry.RPM(i);
    ratio1 = telemetry.RawRatio(i);

    if speed1 > 5 && rpm1 > 850
        if ratio1  >= 85
            detected_gear(i) = 1; % gear 1
        elseif ratio1 >= 55 && ratio1 < 85
            detected_gear(i) = 2; % gear 2
        elseif ratio1 >= 35 && ratio1 < 55
            detected_gear(i) = 3; % gear 3
        elseif ratio1 >= 22 && ratio1 < 35
            detected_gear(i) = 4; % gear 4
        elseif ratio1 >= 14 && ratio1 < 22
            detected_gear(i) = 5; % gear 5
        elseif ratio1 > 0 && ratio1 < 14
            detected_gear(i) = 6; % gear 6
        else
            detected_gear(i) = 0; % undefined
        end
    else
        detected_gear(i) = 0; % neutral
    end
end

% save in timetable 

telemetry.DetectedGearR = detected_gear

fprintf("Gear data saved!");
for g = 1:6
    fprintf('Gear %d: %d point\n',g,sum(detected_gear == g));
end 
%% filter for the moment when you press the clutch

filter_gear = 5;
clear_gear = medfilt1(telemetry.DetectedGearR,filter_gear);

telemetry.Gear = clear_gear;

figure('Name','Final dispersion of gear ratio','NumberTitle', 'off', 'Color', [1 1 1]);

% rpm and speed
subplot(2, 1, 1);
yyaxis left
plot(telemetry.Time, telemetry.RPM, 'LineWidth', 1.4, 'Color', [0 0.45 0.74]);
ylabel('RPM ');
grid on;

yyaxis right
plot(telemetry.Time, telemetry.Speed_OBD, 'LineWidth', 1.6, 'Color', [0.85 0.33 0.1]);
ylabel('Speed (km/h)');
title('RPM vs Speed');
legend('Motor speed', 'Vehicle speed', 'Location', 'northwest');

%gear ratio detection
subplot(2, 1, 2);
stairs(telemetry.Time, telemetry.Gear, 'LineWidth', 2, 'Color', [0.47 0.67 0.19]);
xlabel('Time');
ylabel('Gear');
ylim([-0.5 6.5]);
yticks(0:6);
yticklabels({'Neutral / Coasting', 'Tr. 1', 'Tr. 2', 'Tr. 3', 'Tr. 4', 'Tr. 5', 'Tr. 6'});
grid on;
title('Active gear ratio (Before & after filtering)');