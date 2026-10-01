%% ============================================================
% EV BATTERY HEALTH MONITORING + RUL PREDICTION
% ESP32 + INA219 + OLED
%
% NO TEMPERATURE SENSOR
%
% ESP32 DATA:
% LIVE,V,I,P,SOC,Capacity,Cycle,SOH
%
% CYCLE_END,Cycle,Capacity,SOH
%% ============================================================

clear;
clc;
close all;

%% ============================================================
% 1. SETTINGS
%% ============================================================

COM_PORT = "COM5";

BAUD_RATE = 115200;

RATED_CAPACITY_mAh = 3600;

EOL_THRESHOLD = 80;

NUMBER_OF_READINGS = 300;

%% ============================================================
% 2. LOAD NASA TRAINED MODEL
%% ============================================================

modelFile = "EV_Battery_Trained_Model.mat";

if isfile(modelFile)

    load(modelFile);

    disp("NASA trained model loaded.");

else

    warning("NASA model file not found.");

end

%% ============================================================
% 3. CONNECT TO ESP32
%% ============================================================

disp("Connecting to ESP32...");

try

    s = serialport(COM_PORT, BAUD_RATE);

    configureTerminator(s, "LF");

    s.Timeout = 5;

    flush(s);

catch ME

    error("ESP32 connection failed: %s", ME.message);

end

disp("ESP32 connected.");
disp(" ");

%% ============================================================
% 4. LIVE DATA ARRAYS
%% ============================================================

timeData = [];

voltageData = [];

currentData = [];

powerData = [];

socData = [];

capacityData = [];

cycleData = [];

sohData = [];

%% ============================================================
% 5. COMPLETED CYCLE DATA
%% ============================================================

completedCycles = [];

completedCapacity = [];

completedSOH = [];

%% ============================================================
% 6. CREATE LIVE FIGURE
%% ============================================================

figureLive = figure( ...
    "Name","ESP32 Live Battery Monitoring", ...
    "NumberTitle","off", ...
    "Position",[50 50 1200 700]);

%% Voltage

subplot(2,3,1);

voltagePlot = plot(NaN,NaN,"LineWidth",2);

grid on;

xlabel("Time (s)");

ylabel("Voltage (V)");

title("Battery Voltage");

%% Current

subplot(2,3,2);

currentPlot = plot(NaN,NaN,"LineWidth",2);

grid on;

xlabel("Time (s)");

ylabel("Current (mA)");

title("Battery Current");

%% Power

subplot(2,3,3);

powerPlot = plot(NaN,NaN,"LineWidth",2);

grid on;

xlabel("Time (s)");

ylabel("Power (mW)");

title("Battery Power");

%% SOC

subplot(2,3,4);

socPlot = plot(NaN,NaN,"LineWidth",2);

grid on;

xlabel("Time (s)");

ylabel("SOC (%)");

title("State of Charge");

ylim([0 100]);

%% Capacity

subplot(2,3,5);

capacityPlot = plot(NaN,NaN,"LineWidth",2);

grid on;

xlabel("Time (s)");

ylabel("Capacity (mAh)");

title("Discharge Capacity");

%% SOH

subplot(2,3,6);

sohPlot = plot(NaN,NaN,"LineWidth",2);

grid on;

xlabel("Time (s)");

ylabel("SOH (%)");

title("Battery SOH");

ylim([0 110]);

%% ============================================================
% 7. START TIME
%% ============================================================

startTime = datetime("now");

validReading = 0;

%% ============================================================
% 8. LIVE DATA LOOP
%% ============================================================

disp("Waiting for ESP32 data...");
disp("Turn ON toggle switch to start discharge.");
disp(" ");

while validReading < NUMBER_OF_READINGS

    line = strtrim(readline(s));

    if isempty(line)

        continue;

    end

    parts = split(line,",");

    %% ========================================================
    % LIVE MESSAGE
    %% ========================================================

    if strcmp(parts(1),"LIVE")

        if numel(parts) ~= 8

            continue;

        end

        values = str2double(parts(2:end));

        if any(isnan(values))

            continue;

        end

        validReading = validReading + 1;

        %% Store data

        voltageData(validReading,1) = values(1);

        currentData(validReading,1) = values(2);

        powerData(validReading,1) = values(3);

        socData(validReading,1) = values(4);

        capacityData(validReading,1) = values(5);

        cycleData(validReading,1) = values(6);

        sohData(validReading,1) = values(7);

        %% Time

        timeData(validReading,1) = ...
            seconds(datetime("now") - startTime);

        %% Display

        fprintf( ...
            "Cycle=%d | V=%.2f V | I=%.1f mA | P=%.1f mW | SOC=%.1f %% | Capacity=%.2f mAh | SOH=%.2f %%\n", ...
            values(6), ...
            values(1), ...
            values(2), ...
            values(3), ...
            values(4), ...
            values(5), ...
            values(7));

        %% Update plots

        set( ...
            voltagePlot, ...
            "XData",timeData, ...
            "YData",voltageData);

        set( ...
            currentPlot, ...
            "XData",timeData, ...
            "YData",currentData);

        set( ...
            powerPlot, ...
            "XData",timeData, ...
            "YData",powerData);

        set( ...
            socPlot, ...
            "XData",timeData, ...
            "YData",socData);

        set( ...
            capacityPlot, ...
            "XData",timeData, ...
            "YData",capacityData);

        set( ...
            sohPlot, ...
            "XData",timeData, ...
            "YData",sohData);

        drawnow limitrate;

    %% ========================================================
    % CYCLE END MESSAGE
    %% ========================================================

    elseif strcmp(parts(1),"CYCLE_END")

        if numel(parts) ~= 4

            continue;

        end

        cycle = str2double(parts(2));

        capacity = str2double(parts(3));

        soh = str2double(parts(4));

        if any(isnan([cycle capacity soh]))

            continue;

        end

        %% Store completed cycle

        completedCycles(end+1,1) = cycle;

        completedCapacity(end+1,1) = capacity;

        completedSOH(end+1,1) = soh;

        fprintf("\n");
        fprintf("====================================\n");

        fprintf("DISCHARGE CYCLE COMPLETED\n");

        fprintf("Cycle     : %d\n",cycle);

        fprintf("Capacity  : %.2f mAh\n",capacity);

        fprintf("SOH       : %.2f %%\n",soh);

        fprintf("====================================\n");
        fprintf("\n");

    end

end

%% ============================================================
% 9. CLOSE ESP32 CONNECTION
%% ============================================================

clear s;

%% ============================================================
% 10. CURRENT LIVE VALUES
%% ============================================================

currentCycle = cycleData(end);

currentVoltage = voltageData(end);

currentCurrent = currentData(end);

currentPower = powerData(end);

currentSOC = socData(end);

currentCapacity = capacityData(end);

currentSOH = ...
    (currentCapacity / RATED_CAPACITY_mAh) * 100;

currentSOH = max(0,min(100,currentSOH));

%% ============================================================
% 11. BATTERY STATUS
%% ============================================================

if currentSOH >= 90

    batteryStatus = "Excellent";

elseif currentSOH >= 80

    batteryStatus = "Healthy";

elseif currentSOH >= 70

    batteryStatus = "Aged";

else

    batteryStatus = "Critical";

end

%% ============================================================
% 12. LIVE BATTERY RUL MODEL
%% ============================================================

if length(completedCycles) >= 2

    %% Fit measured battery degradation

    liveModel = polyfit( ...
        completedCycles, ...
        completedSOH, ...
        1);

    liveSlope = liveModel(1);

    liveIntercept = liveModel(2);

    %% Check degradation

    if liveSlope < 0

        predictedEOLCycle = ceil( ...
            (EOL_THRESHOLD - liveIntercept) ...
            / liveSlope);

        predictedRUL = max( ...
            0, ...
            predictedEOLCycle - currentCycle);

    else

        predictedEOLCycle = NaN;

        predictedRUL = NaN;

    end

else

    liveModel = [NaN NaN];

    predictedEOLCycle = NaN;

    predictedRUL = NaN;

end

%% ============================================================
% 13. DISPLAY RESULTS
%% ============================================================

disp(" ");
disp("==============================================");
disp("           BATTERY RESULTS");
disp("==============================================");

fprintf("Actual Cycle       : %d\n",currentCycle);

fprintf("Voltage             : %.3f V\n",currentVoltage);

fprintf("Current             : %.2f mA\n",currentCurrent);

fprintf("Power               : %.2f mW\n",currentPower);

fprintf("SOC                 : %.2f %%\n",currentSOC);

fprintf("Capacity            : %.2f mAh\n",currentCapacity);

fprintf("SOH                 : %.2f %%\n",currentSOH);

fprintf("Battery Status      : %s\n",batteryStatus);

fprintf("\n");

if isnan(predictedRUL)

    fprintf("RUL                 : Need more completed cycles\n");

    fprintf("Predicted EOL       : Need more completed cycles\n");

else

    fprintf("Predicted EOL       : Cycle %d\n", ...
        predictedEOLCycle);

    fprintf("Remaining Useful Life: %d cycles\n", ...
        predictedRUL);

end

disp("==============================================");

%% ============================================================
% 14. SOH DEGRADATION GRAPH
%% ============================================================

figure( ...
    "Name","Actual Battery SOH", ...
    "NumberTitle","off");

if ~isempty(completedCycles)

    plot( ...
        completedCycles, ...
        completedSOH, ...
        "o-", ...
        "LineWidth",2);

    hold on;

end

yline( ...
    EOL_THRESHOLD, ...
    "--", ...
    "80% EOL Threshold", ...
    "LineWidth",1.5);

grid on;

xlabel("Actual Discharge Cycle");

ylabel("SOH (%)");

title("Actual Battery SOH Degradation");

%% ============================================================
% 15. CAPACITY DEGRADATION GRAPH
%% ============================================================

figure( ...
    "Name","Actual Battery Capacity", ...
    "NumberTitle","off");

if ~isempty(completedCycles)

    plot( ...
        completedCycles, ...
        completedCapacity, ...
        "o-", ...
        "LineWidth",2);

    hold on;

end

yline( ...
    RATED_CAPACITY_mAh * 0.80, ...
    "--", ...
    "80% EOL Capacity", ...
    "LineWidth",1.5);

grid on;

xlabel("Actual Discharge Cycle");

ylabel("Discharge Capacity (mAh)");

title("Actual Battery Capacity Degradation");

%% ============================================================
% 16. RUL PREDICTION GRAPH
%% ============================================================

figure( ...
    "Name","Battery RUL Prediction", ...
    "NumberTitle","off");

if ~isnan(predictedEOLCycle)

    futureCycles = ...
        (currentCycle:predictedEOLCycle)';

    futureSOH = polyval( ...
        liveModel, ...
        futureCycles);

    plot( ...
        completedCycles, ...
        completedSOH, ...
        "o-", ...
        "LineWidth",2, ...
        "DisplayName","Measured SOH");

    hold on;

    plot( ...
        futureCycles, ...
        futureSOH, ...
        "--", ...
        "LineWidth",2, ...
        "DisplayName","Predicted Future SOH");

    yline( ...
        EOL_THRESHOLD, ...
        "--", ...
        "80% EOL", ...
        "LineWidth",1.5);

    xline( ...
        currentCycle, ...
        "--", ...
        "Current Cycle", ...
        "LineWidth",1.5);

    xline( ...
        predictedEOLCycle, ...
        "--", ...
        "Predicted EOL", ...
        "LineWidth",1.5);

    grid on;

    xlabel("Actual Discharge Cycle");

    ylabel("SOH (%)");

    title("Battery Remaining Useful Life Prediction");

    legend("Location","best");

else

    text( ...
        0.20, ...
        0.50, ...
        "Complete at least 2 discharge cycles", ...
        "FontSize",14);

    axis off;

end

%% ============================================================
% 17. SAVE DATA
%% ============================================================

if ~isempty(completedCycles)

    cycleTable = table( ...
        completedCycles, ...
        completedCapacity, ...
        completedSOH, ...
        "VariableNames", ...
        {"Cycle","Capacity_mAh","SOH_percent"});

    writetable( ...
        cycleTable, ...
        "Actual_Battery_Cycle_History.csv");

end

liveTable = table( ...
    timeData, ...
    voltageData, ...
    currentData, ...
    powerData, ...
    socData, ...
    capacityData, ...
    cycleData, ...
    sohData, ...
    "VariableNames", ...
    {"Time_s","Voltage_V","Current_mA", ...
     "Power_mW","SOC_percent","Capacity_mAh", ...
     "Cycle","SOH_percent"});

writetable( ...
    liveTable, ...
    "ESP32_Live_Battery_Data.csv");

%% ============================================================
% END
%% ============================================================

disp(" ");
disp("Data saved successfully.");

disp("ESP32_Live_Battery_Data.csv");

disp("Actual_Battery_Cycle_History.csv");