%% VEHICLE TELEMETRY ANALYTICS - MAIN PIPELINE
clear; clc; close all;

% Adăugăm folderul de funcții
addpath('functions');

% load json data
fileName = 'measurement_real_simulator.json';
fprintf('⏳ Load data from %s...\n', fileName);
telemetry = load_telemetry(fileName);

% Calculate gear ratio
fprintf('⏳ Run Gear ratio algorithm..\n');
telemetry = calculate_gears(telemetry);

% 3. Generate pdf raport
pdf_filename = 'Vehicle_Telemetry_Report.pdf';
fprintf('⏳ Generate PDF raport...\n');
generate_report(telemetry, pdf_filename);

fprintf('\n✅ Pipeline successfully executed!\n');