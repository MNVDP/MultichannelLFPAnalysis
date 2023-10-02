%Mk 1 - Core functionality from Rhiannon
%Mk 2 - General improvements, Modifications to work with Windows 10 TDT
%    .5 - Colour specification
%    .75 - Support for red light (Mostly a debugging feature), Significant alteration to flow to support runtime red checking
%    .85 - Ability to alter red light properties on the fly

clear all; 
close all;
% instrfind;
% fclose(instrfind);

% This program works with the ROC file Calibration.rcx in the Oddball directory %
% This presents a blue light at the start of every hour, to synchronize with the camera. It also presents an air puff stimulus every 15 minutes.
%%locpath = 'C:\Users\flylab\Desktop\RhiannonSineRamp\';

%%addpath(genpath(locpath)); 
        
tdtModeIndex = [{'Idle'},{'Standby'},{'Preview'},{'Record'}];

fullDescriptiveTDT = 1; %Checks RCX name mostly
if fullDescriptiveTDT == 1
    expectedRCXName = 'Calibration_Matt';
end

redMode = 2; %Whether to use the old (MATLAB-based) or new (RCX PulseTrain) implementation of red light control, or no red light (0)

%%

if exist('DA')
    %if it is then check if connection is already established
    connectionStat=DA.CheckServerConnection();
    %If this throws an error, try it again. You can also try clear all and
    %close all. if you turn recording from Record>Idle then flicker stim
    %will stop
else
    %first time so open connection
    connectionStat=0;
end

% if there is no connection then reopen it
if connectionStat==0
    DA = actxcontrol('TDevAcc.X');
    succeed=DA.ConnectServer('Local');
    if succeed~=1
        error 'connection to TDT server could not be intialised'
    end
end

status = 0;
successConnect = 0;
while successConnect == 0 %Note: Original implementation used status to move on, but that will hold if system in Idle
   successConnect = DA.ConnectServer('Local');
   status = DA.CheckServerConnection;
   disp(['TDT connection: ', num2str(successConnect) ', status: ', num2str(status)])
   pause(0.5)
end

if successConnect == 0 || status == 0
    %************
    %Reconnect to server
    disp(['-# Connecting to server #-'])
    succeed = 0;
    a = 1;
    %while systemMode ~= desiredTDTMode && a < 20 %systemMode based
    while ( status ~= 1 || succeed ~= 1 ) && a < 20 %setSuccess based
        try
            DA.CloseConnection()
        end
        pause(1)
        clear DA
        close all
        DA = actxcontrol('TDevAcc.X');
        pause(1)
        succeed=DA.ConnectServer('Local');
        pause(1)
        status = DA.CheckServerConnection;
        disp(['Atpt:',num2str(a),' - Server conn. status: ', num2str(status), ', Connect. attempt success: ',num2str(succeed)])
        a = a + 1;
    end
    status = DA.CheckServerConnection;
    if status ~= 1
        ['## Could not reconnect to server ##']
        crash = yes
    end
    %************
else
    disp(['-- System already connected to server --'])
end

systemMode=DA.GetSysMode();

%if system is idle, it must be changed to pre
%%disp(['System is currently in ' dispStr ' mode'])
disp(['System is currently in ',tdtModeIndex{systemMode+1},' mode'])
if systemMode < 1
    ['## Error: System appears to be in Idle mode ##']
    crash = yes
end

if fullDescriptiveTDT == 1
    devRCO = DA.GetDeviceRCO('Amp1');
    if isempty(devRCO) ~= 1
        if isempty(strfind(devRCO,expectedRCXName)) ~= 1
            disp(['-- RCX name matches expectations (',expectedRCXName,') --'])
        else
            ['## Warning: RCX name does not match expectations ##']
            crash = yes
        end
    else
        ['#- Caution: Could not pull RCX name successfully -#']
    end
end

%% Generate Sine wave and square wave stimuli in MATLAB to later load into a buffer
% First sine wave
% SineWaveGeneration.m used as reference (see Code on server)
Voltage = 4; % amplitude- was 3
f1 = 1; % carrierfrequency
stimduration = 5.01; % seconds

requestedColour = 'blueChan' %What colour to send as a calibration stimulus

try
    fs = DA.GetDeviceSF('Amp1') % Sampling Frequency % tucker davis says 95.4 kilobytes a second for float output
catch 
    fs = 2.4414e+04;
end

%Values, not flags or parameters
blueChan = 10; %"Heh"
greenChan = 11;
uvChan = 13; %Note: Technically UV is channel 12, but due to RCO iterator reasons and Ch 4, it has to be this way
blankChan = 0;

%Calculate what RZ5 channel to turn on
    %Note: Highly likely to crash if blank
eval([ 'activeChannel = ',requestedColour,';' ])

t = 0:1/fs:stimduration;

stimvalue = 2*pi*f1*t-pi/2; % the -pi/2 is to subtract half a cycle
carrieronlysine = sin(stimvalue)*Voltage; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
carrieronlysquare = square(stimvalue, 50)*Voltage; % generate square wave with same parameters. 50 is the pulse width

carrieronlystim = ones(1,length(carrieronlysquare));

% removecycles = ones(1,length(keepcycles));

% to avoid odd behaviour with the gating (since first value is pre-loaded), make first and last value zero
carrieronlystim(1,1) = 0;
carrieronlystim(1,end) = 0;

carrieronlysine(1,1) = 0; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
carrieronlysquare(1,1) = 0;
carrieronlysine(1,end) = 0; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
carrieronlysquare(1,end) = 0;

carrierstim(:,1) = 0;
oddballstim(:,1) = 0;
carrierstim(:,end) = 0;
oddballstim(:,end) = 0;

% stimulusduration = floor((stimduration+offduration)*fs); % convert to samples
stimulusduration = floor((stimduration)*fs); % convert to samples

%Calculate red light stimulus shape
%%redStim = ones(1,size(carrieronlysquare,2));
%RRRRRRRRRRRRRRRRRRRRRRRRRRR
%redMode = 2; %Whether to use the old (MATLAB-based) or new (RCX PulseTrain) implementation of red light control
if redMode ~= 0
    redDur = 10.01;
    redDuration = floor((redDur)*fs);
end
if redMode == 1
    redFreq = 4;
    redT = 0:1/fs:nanmax( redDur );
    if redFreq ~= -1 %Flickering at redFreq
        redStimValue = 2*pi*redFreq*redT-pi/2;
        redSquare = square(redStimValue);%, squareDutyCycle); %Currently no support for custom red duty cycle
        redSquare(redSquare == -1) = 0; %Bootleg normalization
        redSquare(redSquare == 1) = 5;
        redSquare(1,1) = 0;
        redSquare(1,end) = 0;
    else %Constant
        redSquare = ones(1,size(redT,2))*5;
    end
    %redDuration = floor((redDur)*fs);
elseif redMode == 2
    redHi = 1000; %ms for red to be on for
    redLo = 1000; %ms for red to be off for
    redFreq = 1000 / (redHi + redLo);
    redPulseNum = floor(redDur * redFreq);
    redIntens = 5; %Red intensity (0 - 5)
end
if redMode ~= 0
    disp(['Red stimuli will be displayed at ',num2str(redFreq),'Hz for ',num2str(redDur),'s (Mode ',num2str(redMode),')'])
end       
%RRRRRRRRRRRRRRRRRRRRRRRRRRR

%%coords = [floor(size(carrieronlysquare,2)-0.5*size(carrieronlysquare,2)):size(carrieronlysquare,2)-1];
%%carrieronlysquare( coords ) = [];
carrieronlysquare = [carrieronlysquare,carrieronlysquare];
%redSquare( 1 , coords ) = [];


%% Save stimulus vectors

fprintf('Starting experiment at %s\n', datestr(now,'HH:MM:SS.FFF'))

%%count = 0;
% while systemMode == 3; % while system mode is set to record.
% for Hours = 1:ExperimentDuration;
% pause(30); disp('Wait 30 seconds for blue light!');
%%disp('First, will show blue light for camera synchronization!');
    %% Exp start
% Load stimulus into buffer
h = figure('Visible', 'off', 'HandleVisibility', 'off');
    %There is a non-zero possibility this figure may for some reason be critical to connecting to the TDT server...

Stims = [carrieronlysquare];
TTLvector(:,:,1) = [carrieronlystim];

%fprintf('Starting blue light for 3 seconds at time %s\n', datestr(now,'HH:MM:SS.FFF'))
disp([ 'Turning off ',requestedColour,' for ',num2str(stimduration),'s at time ', datestr(now,'HH:MM:SS.FFF') ])
DA.SetTargetVal('Amp1.duration', stimulusduration);

disp('Loading stimuli into buffer.');
DA.WriteTargetVEX(['Amp1.carrieronlystim'], 0, 'F32', single(TTLvector));
DA.WriteTargetVEX(['Amp1.stim'], 0, 'F32', single(Stims));

disp('Checking stimulus is off.');
%DA.SetTargetVal(['Amp1.carrieronly10'], 0);
%DA.SetTargetVal(['Amp1.carrieronlyON10'], 0);
%Turn off all channels
for x = 10:13
    DA.SetTargetVal(['Amp1.carrieronly',num2str(x)], 0);
    DA.SetTargetVal(['Amp1.carrieronlyON',num2str(x)], 0);
end

if redMode ~= 0
    disp(['Initialising red light'])
    setSucc = [];
    setSucc = [setSucc,DA.SetTargetVal('Amp1.redDuration', redDuration)];
    if redMode == 1
        setSucc = [setSucc,DA.WriteTargetVEX(['Amp1.redStim'], 0, 'F32', single([redSquare]))];
    else
        setSucc = [setSucc,DA.SetTargetVal('Amp1.redHi', redHi)];
        setSucc = [setSucc,DA.SetTargetVal('Amp1.redLo', redLo)];
        setSucc = [setSucc,DA.SetTargetVal('Amp1.redPulseNum', redPulseNum)];
        setSucc = [setSucc,DA.SetTargetVal('Amp1.redIntens', redIntens)];
    end
    %QA
    if nansum(setSucc) ~= size(setSucc,2)
        ['## Warning: Not all red parameters detected to have been successfully sent ##']
        crash = yes
    end
    %{
    redLightStatus = 0;
    temp=DA.GetTargetVal(['Amp1.redTriggerConstL']); %Might crash if said trigger does not exist
    temp2=DA.GetTargetVal(['Amp1.redSerIndx']); %Might crash if said trigger does not exist
    disp([char(10),', redTriggerConstL value: ',num2str(temp),' redSerIndx: ',num2str(temp2)])

    DA.SetTargetVal('Amp1.redDuration', redDur); %Used to be "redDur(redIt)"
    redLightReset=DA.SetTargetVal(['Amp1.redTrigger'], redLightStatus); %Might crash if said trigger does not exist
    DA.WriteTargetVEX(['Amp1.redStim'], 0, 'F32', single([redSquare]));

    temp=DA.GetTargetVal(['Amp1.redTriggerConstL']); %Might crash if said trigger does not exist
    temp2=DA.GetTargetVal(['Amp1.redSerIndx']); %Might crash if said trigger does not exist
    disp(['Red light MATLAB status: ',num2str(redLightStatus),', Set success: ',num2str(redLightReset),...
        char(10),', redTriggerConstL value: ',num2str(temp),' redSerIndx: ',num2str(temp2)])
    %}

    %Red query
    lastRedTime = clock;
    initTime = clock;
end

%Timing
stimStart = clock;

%New, dynamic
for x = 10:13
    if x == activeChannel
        disp(['Flickering ',requestedColour]);
        disp(['-- Turning stimuli on --'])
        DA.SetTargetVal(['Amp1.carrieronly',num2str(x)], 1);
        DA.SetTargetVal(['Amp1.carrieronlyON',num2str(x)], 1);
        stimStart = clock;

        %pause(stimduration);
        %DA.SetTargetVal(['Amp1.carrieronly',num2str(x)], 0);
        %DA.SetTargetVal(['Amp1.carrieronlyON',num2str(x)], 0);
    end
end

ready = 0;

startTime = clock;

dont_quit_now = 1;
while dont_quit_now ~= 0
    currentTime = clock;
    %Old, fixed
    %{
    disp('Flickering Blue LED');
    DA.SetTargetVal(['Amp1.carrieronly10'], 1);
    DA.SetTargetVal(['Amp1.carrieronlyON10'], 1);

    pause(stimduration);
    DA.SetTargetVal(['Amp1.carrieronly10'], 0);
    DA.SetTargetVal(['Amp1.carrieronlyON10'], 0);
    %}
    %New, dynamic
    for x = 10:13
        if x == activeChannel
            %disp(['Flickering ',requestedColour]);
            %DA.SetTargetVal(['Amp1.carrieronly',num2str(x)], 1);
            %DA.SetTargetVal(['Amp1.carrieronlyON',num2str(x)], 1);
            %stimStart = clock;
                
            %pause(stimduration);
            if etime(currentTime,stimStart) > stimduration
                disp(['-- Turning stimuli off --'])
                DA.SetTargetVal(['Amp1.carrieronly',num2str(x)], 0);
                DA.SetTargetVal(['Amp1.carrieronlyON',num2str(x)], 0);
                ready = 1; %Ready for next stim question/display
            end
        end
    end

    if ready == 1
        %fprintf('Turning off Blue LED at time %s\n', datestr(now,'HH:MM:SS.FFF'))
        disp([ 'Turning off ',requestedColour,' at time ', datestr(now,'HH:MM:SS.FFF') ])
        dont_quit_now = input([char(10),'Do you wish to send another stimulus? (0/1) ']);
        
        if ( dont_quit_now == 2 || dont_quit_now == 3 || dont_quit_now == 4 || dont_quit_now == 5 ) && redMode ~= 0
            %Set red lo if time elapsed
                %Overridden to always set low
            %if etime(clock,initTime) > redDur 
                redLightStatus = 0; %Set lo
                DA.SetTargetVal(['Amp1.carrieronlyRed'], redLightStatus);
                disp(['Red light status set low (',num2str(etime(clock,initTime)),'s of ',num2str(redDur),'s elapsed)'])
            %end
            
            disp(['Red light request acknowledged (Mode: ',num2str(redMode),')'])
            if dont_quit_now < 4
                %redLightStatus = ~redLightStatus; %Invert
                redLightStatus = dont_quit_now - 2;
                DA.SetTargetVal(['Amp1.carrieronlyRed'], redLightStatus); %May react oddly to no enforced low state after redDur seconds
                initTime = clock;
            else
                disp(['Request to alter red light properties acknowledged'])
                %RRRRRRRRRRRRRRRRRRRRRRRRRRR
                if redMode ~= 0
                    %redDur = 40.01;
                    redDur = input('Input red duration (s): ');
                    redDuration = floor((redDur)*fs);
                end
                if redMode == 1
                    %redFreq = 4;
                    redFreq = input('Input red freq. (Hz): ');
                    redT = 0:1/fs:nanmax( redDur );
                    if redFreq ~= -1 %Flickering at redFreq
                        redStimValue = 2*pi*redFreq*redT-pi/2;
                        redSquare = square(redStimValue);%, squareDutyCycle); %Currently no support for custom red duty cycle
                        redSquare(redSquare == -1) = 0; %Bootleg normalization
                        redSquare(redSquare == 1) = 5;
                        redSquare(1,1) = 0;
                        redSquare(1,end) = 0;
                    else %Constant
                        redSquare = ones(1,size(redT,2))*5;
                    end
                    %redDuration = floor((redDur)*fs);
                elseif redMode == 2
                    %redHi = 1000; %ms for red to be on for
                    %redLo = 1000; %ms for red to be off for
                    %%redHiLo = input('Input red [hi,lo] time (ms): '); %Square brackets necessary
                    redHiLo = [];
                    redHiLo(1) = input('Input red hi time (ms): '); 
                    redHiLo(2) = input('Input red lo time (ms): '); 
                    %redFreq = 1000 / (redHi + redLo);
                    redFreq = 1000 / nansum( redHiLo );
                    redPulseNum = floor(redDur * redFreq);
                    redIntens = input('Input red intensity (0-5): ');
                end
                if redMode ~= 0
                    disp(['Red stimuli will be displayed at ',num2str(redFreq),'Hz for ',num2str(redDur),'s (Mode ',num2str(redMode),')'])
                end       
                %RRRRRRRRRRRRRRRRRRRRRRRRRRR
                disp(['Initialising red light'])
                setSucc = [];
                setSucc = [setSucc,DA.SetTargetVal('Amp1.redDuration', redDuration)];
                if redMode == 1
                    setSucc = [setSucc,DA.WriteTargetVEX(['Amp1.redStim'], 0, 'F32', single([redSquare]))];
                else
                    %setSucc = [setSucc,DA.SetTargetVal('Amp1.redHi', redHi)];
                    %setSucc = [setSucc,DA.SetTargetVal('Amp1.redLo', redLo)];
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redHi', redHiLo(1))];
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redLo', redHiLo(2))];
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redPulseNum', redPulseNum)];
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redIntens', redIntens)];
                end
                %QA
                if nansum(setSucc) ~= size(setSucc,2)
                    ['## Warning: Not all red parameters detected to have been successfully sent ##']
                    crash = yes
                end
                redLightStatus = dont_quit_now - 4;
                DA.SetTargetVal(['Amp1.carrieronlyRed'], redLightStatus); %May react oddly to no enforced low state after redDur seconds
                initTime = clock;
            end
        end
        
        if dont_quit_now ~= 0
            %New, dynamic
            for x = 10:13
                if x == activeChannel
                    disp(['Flickering ',requestedColour]);
                    disp(['-- Turning stimuli on --'])
                    DA.SetTargetVal(['Amp1.carrieronly',num2str(x)], 1);
                    DA.SetTargetVal(['Amp1.carrieronlyON',num2str(x)], 1);
                    stimStart = clock;
                end
            end
        end
        
        ready = 0; %Prevent infinicycle
    end
    
    %Red query
    if redMode ~= 0 & etime(currentTime,lastRedTime) > 1
        temp = DA.GetTargetVal(['Amp1.triggerRed']);
        temp2 = DA.GetTargetVal(['Amp1.redIdx']);
        temp3 = DA.GetTargetVal(['Amp1.redChVal']);
        temp4 = DA.GetTargetVal(['Amp1.edgeRed']);
        temp5 = DA.GetTargetVal(['Amp1.redStage']);
        disp([num2str(etime(currentTime,initTime)),'s - triggerRed: ',num2str(temp),...
            ', redIdx: ',num2str(temp2),', redChVal: ',num2str(temp3),', redStage: ',num2str(temp5)])
        lastRedTime = clock;
    end
end

disp('Reloading stimuli.');
DA.WriteTargetVEX(['Amp1.carrieronlystim'], 0, 'F32', single(TTLvector));
DA.WriteTargetVEX(['Amp1.stim'], 0, 'F32', single(Stims));
disp('End of flicker sequence!');

%and close connection
DA.CloseConnection()

%diary off