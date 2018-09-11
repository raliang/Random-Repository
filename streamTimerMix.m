%
% 2 channel stream of AIN0 and AIN1 example using MATLAB, .NET and the UD
% driver.
%
% support@labjack.com
%

clc  % Clear the MATLAB command window
clear  % Clear the MATLAB variables

% Make the UD .NET assembly visible in MATLAB.
ljasm = NET.addAssembly('LJUDDotNet');
ljudObj = LabJack.LabJackUD.LJUD;

i = 0;
k = 0;
ioType = 0;
channel = 0;
dblValue = 0;
dblCommBacklog = 0;
dblUDBacklog = 0;
scanRate = 20000;
numScans = 1000;
numScansRequested = 0;
loopAmount = 150;  % Number of times to loop and read stream data
% Variables to satisfy certain method signatures
dummyInt = 0;
dummyDouble = 0;
dummyDoubleArray = [0];

dacVoltage = 0;  % Adjust DAC0 voltage for angular rate sensor
data = zeros(3,loopAmount);

try
    %------------------------------INFO----------------------------------
%     % Read and display the UD version.
%     disp(['UD Driver Version = ' num2str(ljudObj.GetDriverVersion())])

    % Open the first found LabJack U3.
    [ljerror, ljhandle] = ljudObj.OpenLabJackS('LJ_dtU3', 'LJ_ctUSB', '0', true, 0);

    % Stop any previous stream.
    try
        ljudObj.eGet(ljhandle, 'LJ_ioSTOP_STREAM', 0, 0, 0);
    catch
    end

%     % Read and display the hardware version of this U3.
%     [ljerror, dblValue] = ljudObj.eGetSS(ljhandle, 'LJ_ioGET_CONFIG', 'LJ_chHARDWARE_VERSION', 0, 0);
%     disp(['U3 Hardware Version = ' num2str(dblValue)])
% 
%     % Read and display the firmware version of this U3.
%     [ljerror, dblValue] = ljudObj.eGetSS(ljhandle, 'LJ_ioGET_CONFIG', 'LJ_chFIRMWARE_VERSION', 0, 0);
%     disp(['U3 Firmware Version = ' num2str(dblValue)])
%     
    
    
    
    
    
    %------------------------------RESET----------------------------------
    % Start by using the pin_configuration_reset IOType so that all
    % pin assignments are in the factory default condition.
    ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);
    
    
    %------------------------------DAC---------------------------------
    % Sets DAC0 to desired voltage
    ljudObj.ePutS(ljhandle, 'LJ_ioPUT_DAC', 0, dacVoltage, 0);
    
    
    %--------------------------TIMER--------------------------------
    % Set the timer/counter pin offset to 4, which will put the first
    % timer/counter on FIO4.
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chTIMER_COUNTER_PIN_OFFSET', 4, 0, 0);

    % Use the 48 MHz timer clock base with divider (LJ_tc48MHZ_DIV).  Since we are using clock with divisor
    % support, Counter0 is not available.
    LJ_tc48MHZ_DIV = ljudObj.StringToConstant('LJ_tc48MHZ_DIV');
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chTIMER_CLOCK_BASE', LJ_tc48MHZ_DIV, 0, 0);

    % Set the divisor to 48 so the actual timer clock is 1 MHz.
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chTIMER_CLOCK_DIVISOR', 48, 0, 0);

    % Enable 1 timer. It will use FIO4.
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chNUMBER_TIMERS_ENABLED', 1, 0, 0);

    % Configure Timer0 as 8-bit PWM (LJ_tmPWM8). Frequency will be 1M/256 = 3906 Hz.
    LJ_tmPWM8 = ljudObj.StringToConstant('LJ_tmPWM8');
    ljudObj.AddRequestS(ljhandle, 'LJ_ioPUT_TIMER_MODE', 0, LJ_tmPWM8, 0, 0);

    % Set the PWM duty cycle to 50%.
    ljudObj.AddRequestS(ljhandle, 'LJ_ioPUT_TIMER_VALUE', 0, 32768, 0, 0);

    % Enable Counter1.  It will use FIO5 since 1 timer is enabled.
    ljudObj.AddRequestS(ljhandle, 'LJ_ioPUT_COUNTER_ENABLE', 1, 1, 0, 0);
    
    
    
    
    
    %----------------------SENSOR SETUP-----------------------------
    % Configure FIO0 and FIO1 as analog, all else as digital. That means we
    % will start from channel 0 and update all 16 flexible bits.  We will
    % pass a value of b0000000000000011 or d3.
    % For the last parameter we are forcing the value to an int32 to ensure
    % MATLAB uses the proper function overload.
    %ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_PORT', 0, 3, 16);
    ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_PORT', 0, 3, int32(16));

    % Configure the stream:
    % Set the scan rate.
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chSTREAM_SCAN_FREQUENCY', scanRate, 0, 0);

    % Give the driver a 5 second buffer (scanRate * 2 channels * 5 seconds).
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chSTREAM_BUFFER_SIZE', scanRate*2*5, 0, 0);

    % Configure reads to retrieve whatever data is available with waiting.
    LJ_swSLEEP = ljudObj.StringToConstant('LJ_swSLEEP');
    ljudObj.AddRequestSS(ljhandle, 'LJ_ioPUT_CONFIG', 'LJ_chSTREAM_WAIT_MODE', LJ_swSLEEP, 0, 0);

    % Define the scan list as AIN0 then AIN1.
    ljudObj.AddRequestS(ljhandle, 'LJ_ioCLEAR_STREAM_CHANNELS', 0, 0, 0, 0);
    ljudObj.AddRequestS(ljhandle, 'LJ_ioADD_STREAM_CHANNEL', 0, 0, 0, 0);
    ljudObj.AddRequestS(ljhandle, 'LJ_ioADD_STREAM_CHANNEL_DIFF', 1, 0, 32, 0);
    
    
    

    % Execute the list of requests.
    ljudObj.GoOne(ljhandle);
    
    
    
    
    %---------------------COMPILE ERRORS-----------------------------------
    % Get all the results just to check for errors.
    LJE_NO_MORE_DATA_AVAILABLE = ljudObj.StringToConstant('LJE_NO_MORE_DATA_AVAILABLE');
    finished = false;
    while finished == false
        try
            [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetNextResult(ljhandle, 0, 0, 0, 0, 0);
        catch e
            if(isa(e, 'NET.NetException'))
                eNet = e.ExceptionObject;
                if(isa(eNet, 'LabJack.LabJackUD.LabJackUDException'))
                    % If we get an error, report it. If the error is
                    % LJE_NO_MORE_DATA_AVAILABLE we are done.
                    if(int32(eNet.LJUDError) == LJE_NO_MORE_DATA_AVAILABLE)
                        finished = true;
                    end
                end
            end
            % Report non NO_MORE_DATA_AVAILABLE error.
            if(finished == false)
                throw(e)
            end
        end
    end
    
    
    
    
    %------------------------STREAMING AND TIMING--------------------------
    % Start the stream.
    [ljerror, dblValue] = ljudObj.eGetS(ljhandle, 'LJ_ioSTART_STREAM', 0, 0, 0);

    % The actual scan rate is dependent on how the desired scan rate divides
    % into the LabJack clock. The actual scan rate is returned in the value
    % parameter from the start stream command.
    disp(['Actual Scan Rate = ' num2str(dblValue)])
    disp(['Actual Sample Rate = ' num2str(2*dblValue) sprintf('\n')])  % # channels * scan rate

    % Get the enums for LJ_ioGET_STREAM_DATA and LJ_chALL_CHANNELS which we use
    % in the read stream data loop.
    typeIO = ljasm.AssemblyHandle.GetType('LabJack.LabJackUD.LJUD+IO');
    LJ_ioGET_STREAM_DATA = typeIO.GetEnumValues.Get(22);  % Use enum index for GET_STREAM_DATA 
    typeCHANNEL = ljasm.AssemblyHandle.GetType('LabJack.LabJackUD.LJUD+CHANNEL');
    LJ_chALL_CHANNELS = typeCHANNEL.GetEnumValues.Get(99);  % Use the enum index for ALL_CHANNELS

    % Read stream data
    for i=1:loopAmount
        % Loop will run the number of times specified by loopAmount variable
        % Since we are using wait mode LJ_swSLEEP, the stream read waits for a
        % certain number of scans and control how fast the program loops.

        % Init array to store data.
        adblData = NET.createArray('System.Double', 2*numScans);  % Max buffer size (#channels*numScansRequested)

        % Read the data. The array we pass must be sized to hold enough SAMPLES,
        % and the Value we pass specifies the number of SCANS to read.
        numScansRequested = numScans;
        % Use eGetPtr when reading arrays in 64-bit MATLAB. Also compatible with
        % 32-bits.
        [ljerror, numScansRequested] = ljudObj.eGetPtr(ljhandle, LJ_ioGET_STREAM_DATA, LJ_chALL_CHANNELS, numScansRequested, adblData);
           
        
    %---------------------GETTING TIME-------------------------------    
    % Request a read from the counter.
    [ljerror, dblValue] = ljudObj.eGetS(ljhandle, 'LJ_ioGET_COUNTER', 1, 0, 0);
    
    %---------------------------------------------------------------------

        % Display the number of scans that were actually read.
        disp(['Iteration # = ' num2str(i)])
        disp(['Number read = ' num2str(numScansRequested)])

        % Display the first scan.
        disp(['First scan = ' num2str(adblData(1)) ', ' num2str(adblData(2))])
        disp(['Counter 1 = ' num2str(dblValue)]);
         

        data(1,i) = dblValue;
        data(2,i) = adblData(1);
        data(3,i) = adblData(2);

        % Retrieve the current backlog. The UD driver retrieves stream data
        % from the U3 in the background, but if the computer or code is too slow
        % the driver might not be able to read the data as fast as the U3 is
        % acquiring it, and thus there will be data left over in the U3 buffer.
        [ljerror, dblCommBacklog] = ljudObj.eGetSS(ljhandle, 'LJ_ioGET_CONFIG', 'LJ_chSTREAM_BACKLOG_COMM', dblCommBacklog, dummyDoubleArray);
        disp(['Comm Backlog = ' num2str(dblCommBacklog)])

        [ljerror, dblUDBacklog] = ljudObj.eGetSS(ljhandle, 'LJ_ioGET_CONFIG', 'LJ_chSTREAM_BACKLOG_UD', dblUDBacklog, dummyDoubleArray);
        disp(['UD Backlog = ' num2str(dblUDBacklog) sprintf('\n')])
    end

    % Stop the stream
    ljudObj.eGetS(ljhandle, 'LJ_ioSTOP_STREAM', 0, 0, 0);
    
    % Reset all pin assignments to factory default condition.
    ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);
    

    disp('Done')
catch e
    showErrorMessage(e)
end

data(1,:) = data(1,:) ./ 3906;
fprintf('\nTime to first data collection: %.2f seconds.\n',data(1,1))
fprintf('The total elapsed time was %.2f seconds.\n',data(1,loopAmount))


figure(1);
plot(data(1,:),data(2,:),'b')
hold on
plot(data(1,:),data(3,:),'r')
title('Test Graph')
xlabel('Time (sec)')
ylabel('Volts (V)')
legend('Input 0', 'Input 1')
hold off

area = trapz(data(1,:),data(2,:));
fprintf('The total area under the curve is %.4f volt-seconds.\n',area)

fprintf('The data can accessed by calling the ''data'' matrix.\n')