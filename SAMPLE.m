% Step 1: Connect to ESP32
s = serialport("COM5", 115200);
configureTerminator(s, "LF");
flush(s);
s.Timeout = 5;   % wait up to 5 seconds per reading
% Step 2: Prepare empty storage
logVoltage = [];
logCurrent = [];
logPower = [];
logBattery = [];

% Step 3: Read 20 live readings
for k = 1:20
    line = readline(s);
    values = str2double(split(line, ","));

    logVoltage(end+1,1) = values(1);
    logCurrent(end+1,1) = values(2);
    logPower(end+1,1)   = values(3);
    logBattery(end+1,1) = values(4);

    fprintf("Reading %d: V=%.2f I=%.2f P=%.2f Batt=%.2f%%\n", ...
        k, values(1), values(2), values(3), values(4));
end

% Step 4: Close connection
clear s

% Step 5: Plot the voltage over time
figure;
plot(logVoltage, 'b-o');
xlabel('Reading Number');
ylabel('Voltage (V)');
title('Live Battery Voltage from ESP32');
grid on;