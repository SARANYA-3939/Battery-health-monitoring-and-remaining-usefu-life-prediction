%% ================= COMBINED LIVE MONITORING + RUL PREDICTION =================
clear; clc; close all;

%% Step 1: Load your already-trained model
load('EV_Battery_Trained_Model.mat');   
% This gives you: RUL_ModelCoefficients, EOL_Threshold, etc.

%% Step 2: Set the assumed current cycle (fixed, as in your training script)
currentCycle = 80;

%% Step 3: Connect to ESP32
s = serialport("COM5", 115200);
configureTerminator(s, "LF");
flush(s);
s.Timeout = 5;

%% Step 4: Read live sensor data (20 readings)
numReadings = 20;
logVoltage = [];
logCurrent = [];
logPower   = [];
logBattery = [];

for k = 1:numReadings
    line = readline(s);
    values = str2double(split(line, ","));

    logVoltage(end+1,1) = values(1);
    logCurrent(end+1,1) = values(2);
    logPower(end+1,1)   = values(3);
    logBattery(end+1,1) = values(4);

    fprintf("Reading %d: V=%.2f I=%.2f P=%.2f Batt=%.2f%%\n", ...
        k, values(1), values(2), values(3), values(4));
end

clear s

%% Step 5: Predict future SOH using your trained model
predictedEOLCycle = ceil((EOL_Threshold - RUL_ModelCoefficients(2)) / RUL_ModelCoefficients(1));
predictedRUL = max(0, predictedEOLCycle - currentCycle);

futureCycles = (currentCycle:predictedEOLCycle)';
futurePredictedSOH = polyval(RUL_ModelCoefficients, futureCycles);

fprintf("\n--- RUL Prediction (from trained model) ---\n");
fprintf("Current Cycle: %d\n", currentCycle);
fprintf("Predicted End-of-Life Cycle: %d\n", predictedEOLCycle);
fprintf("Predicted Remaining Useful Life: %d cycles\n", predictedRUL);

%% Step 6: Show everything on one dashboard

figure('Name', 'Battery Monitoring + RUL Prediction Dashboard', ...
    'Position', [100 100 1000 600]);

% --- Live Voltage plot ---
subplot(2,2,1);
plot(logVoltage, 'b-o', 'LineWidth', 1.5);
xlabel('Reading Number');
ylabel('Voltage (V)');
title('Live Battery Voltage (ESP32)');
grid on;

% --- Live Current plot ---
subplot(2,2,2);
plot(logCurrent, 'r-o', 'LineWidth', 1.5);
xlabel('Reading Number');
ylabel('Current (mA)');
title('Live Battery Current (ESP32)');
grid on;

% --- Live Battery % plot ---
subplot(2,2,3);
plot(logBattery, 'g-o', 'LineWidth', 1.5);
xlabel('Reading Number');
ylabel('Battery (%)');
title('Live Battery Percentage (ESP32)');
grid on;

% --- RUL Prediction plot ---
subplot(2,2,4);
plot(futureCycles, futurePredictedSOH, 'm--', 'LineWidth', 2);
hold on;
yline(EOL_Threshold, 'r--', '80% EOL Threshold', 'LineWidth', 1.5);
xline(currentCycle, 'k--', 'Current Cycle', 'LineWidth', 1.5);
xline(predictedEOLCycle, 'g--', 'Predicted EOL', 'LineWidth', 1.5);
xlabel('Discharge Cycle Number');
ylabel('Predicted SOH (%)');
title('RUL Prediction (Trained Model)');
grid on;

sgtitle('EV Battery Health Monitoring + RUL Prediction Dashboard');