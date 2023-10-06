%Script for display of Coloured Oddball stimuli to multichannel preparation
%Designed to operate in conjunction with Coloured_Oddball_Matt.rcx or Coloured_Oddball.rcx


%% Coloured_Oddball_03.m
% The purpose of this file is to simplify the script and also make sure
% there is a counterbalance option.

%% NOTES (_02)
% 26/03/2020 RJ This script will reverse the order/ counterbalance carriers
% and oddballs and whether they appear first.
% 27/03/2020 RJ Bug in script which causes uneven numbers of carrier and
% oddball trials per stimulus.

%% NOTES (_03)
% 27/03/2020 RJ 
    
%% Matt
%Mk 1 - TTL modifications to allow for true random (within 20s blocks) oddball position
%Mk 2 - Random 20s blocks for entire experiment length
        % 15/04/2020 RJ Use with .rcx file Coloured_Oddball_02_5.rcx (set to green stim only)
%    .5 - Various improvements (Known bugs: Unsocketed mode crashes at end of exp)
%Mk 3 - Streamlined stimOrder saving, Fixed unsocketed crash
%    .5 - 33/33/33 functionality, 'Fixed' prior rest trial, Removed arbitrary width doubling
%    .75 - Streamlined experiment switching, better flag/param saving (BUG: sentStimuli contains all previous data with each save)
%    .85 - Removed saving bug by clearing saved variables after saving
%Mk 4 - Probability Descent paradigm
%    .25 - Return to square wave, decrease in frequency of sending target
%    vals to remove artefact, automatic Idle after experiment complete
%    .5 - Modified TTL assembly to be more accurate (Now uses pre-calculated onset positions)
%Mk 5 - Improved unambiguity of TTL saving, fixed bug with WriteTargetVex (14/07/20)
%    .25 - General improvements
%Mk 6 - Repetition suppression (again)
%    .5 - Overnight operation
%    .75 - Modifications to oddball position assignment (To reduce rep. supp. overlap)
%Mk 7 - Chunking for large blocks (30/11/20)
%    .5 - ttlStruct saving to file and loading piecemeal (NOTE: BUG MAY BE PRESENT WHERE numOddballTrials DOES NOT MATCH NUMBER OF ODDBALL TRIALS IN Gating)
%Mk 8 - TDT improvements
%Mk 9 - Recapitulation of lost features (15/06/21) KNOWN BUG FOR PREVIOUS VERSIONS: Oddball groups will be pulled from last chanGroupList element preferentially 
%    .25 - Fixing of oddball display (05/07/21)
%    .5 - Modifications to support sequential dependencies paradigms/Asymmetric TTLs
%    .75 - Red light support (Designed to work with Coloured_Oddball_Matt3point5)
%    .85 - Flickering support for red light (Designed to work with Coloured_Oddball_Matt3point75)
%Mk 10 - Support for within-experiment and within-block fixed jitters

%To add:
%- Trial complement accuracy QA
%- Saving of entire script to ancillary directory/etc?

%Known issues:
%   - remainingTrialstrigger defaults to 0 or 159 after failsafe resets
%   - New OutP data in Coloured_Oddball_Matt.rcx seems to fail to reflect state properly for the first trial after a chunk if the chunking fails
%   - In presumably all versions prior to 9.25_XM, oddball elements would be biased towards the last element of chanGroupList
%       - This occurred due to the architecture of ChannelGroups/ChannelOrder and how randperm works and has been ameliorated with interleaving

close all
clear all

diary off %Will be changed if requested

%progIdent = 'Coloured_Oddball_03_Matt_9_XM' 
progIdent = mfilename %Now dynamic!
progVer = 10.0; %Now calculable!

cd 'C:\Users\flylab\Desktop\Matt\Stimulus scripts'

if ~isdir([cd '/' 'StimOrder'])
    mkdir([cd '/' 'StimOrder']); %Prepare save directory for MAT files
end

%% If you get an error like "Cannot find COM1 port", try case 1.
% Also remember to add olfactory_stimulus_controller to the path.
% ChannelSwitch = [10; 11]; % swap between channel 10 or 12

socky = 1; %1 - Socketed, 2 - Unsocketed

f1 = 10; % carrierfrequency
f2 = 2; % oddball frequency
    %These values will be overriden if requested by new values for certain expModes

overrideErrors = 1; %Whether to override 'minor' errors

chunkDatasets = 1; %Whether to 'chunk' TDT blocks into segments, rather than just one giant block
if chunkDatasets == 1
    chunkDuration = 60; %Number of minutes blocks can be
    saveIndividualChunkMATs = 1; %Whether to save a MAT file with every new block, rather than just the last block
        %Note: Each MAT file will contain all the information up till that
        %point, but only the last will be fully complete in terms of
        %sentStimuli etc
    runningMemoryClear = 1; %Whether to clear elements from ttlStruct as going to reduce RAM usage at the risk of fuckery
    piecemealTTLstruct = 1; %Whether to save ttlStruct to file rather than holding it in RAM and then only load during chunks
        %Note: It is not technically required for this to be tethered to
        %chunking, but for the moment it is simplest
    if piecemealTTLstruct == 1
        %ttlHoldFolder = 'C:\Users\flylab\Desktop\RhiannonSineRamp\SineRamp\MatlabPrograms\Matthew\ttlStruct'; %Will be where the piecemeal ttlStruct is held
        ttlHoldFolder = [cd filesep 'ttlStruct'];
    end
end

saveTTLLoad = 1; %Whether to try 'intelligently' only send TTL rows that are different to the previous block
    %Use of this may be linked to occasional instances of blocks being sent
    %without visual stimuli
    
fullDescriptiveTDT = 1; %Whether to (request and) output TDT information during operation
if fullDescriptiveTDT == 1
    %expectedRCXName = 'Coloured_Oddball_Matt.rcx';
    expectedRCXName = 'Coloured_Oddball_Matt'; %Removing ".rcx" allows for wildcard capture of different generations of RCO file
end

doDiary = 1;
if doDiary == 1 %Diary prep. pt. 1
    diaryPath = [cd filesep 'diaries'];
    if ~isdir(diaryPath)
        mkdir([diaryPath]); %Prepare save directory for diaries
    end
end

redLight = 0; %Not a flag; Will be overriden by expMode custom settings if applicable

%-------------------------------------------------------------------------
    %'Old' style - oddballFraction 0.2, oddballMode 1, CarrierOrder [1 2] and vice versa, TrialLength 10
    %Varying style - oddballFraction 0.67, oddballMode -1, CarrierOrder [1], TrialLength 36 (or some other multiple of 3)
    %0 50 50 - Same as directly above, except oddballFraction 1.0

expMode = 6; 
%1 - 'Old' style (80/20, phasic, fully counterbalanced), 
%2 - '33 33 33' (33% apiece between carrieronly, phasic and normally jittering, less counterbalanced)
%3 - 'OddCarrier' (Same as 33 33 33 except that the carrier is blank while carrieronly and oddball are green)
%4 - Probability Descent (100Hz -> 1Hz sparsening)
%5 - Repetition suppression
%6 - Overnight exp (Phasic coloured)
%7 - Sequential dependencies paradigm
%8 - Observational overnight paradigm (No visuals)
%9 - Fixed jittering oddball

if expMode == 1
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    oddballFraction = 0.2;
    repSupp = 0;
    
    oddballMode = 1; 
    %1 - Phasic, 2 - Random uniform, 3 - Random normal, 4 - Probability descent, 5 - Fixed jiiter, -1 - Multiple oddball modes in one exp
    
    TrialLength = 24; %Note: Will be multiplied by however many chanGroupLists exist

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blankChan'} ]; %Green-blank
    chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green-blue
    %chanGroupList{3} = [ {'blueChan'},{'blueChan'},{'blankChan'} ]; %Blue-blank
    chanGroupList{2} = [ {'blueChan'},{'blueChan'},{'greenChan'} ];  %Blue-green

    %CarrierOrder = [1 2];
    %CarrierOrder = [2 1];
    CarrierOrder = [1];
    
elseif expMode == 2
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    %oddballFraction = 0.66;
    
    oddballMode = -1; %1 - Phasic, 2 - Random uniform, 3 - Random normal, -1 - Multiple oddball modes in one exp
    if oddballMode ~= -1
        oddballFraction = 0.33; %Freely changeable value
    else
        oddballFraction = 0.66; %Must be 66%       
    end
    
    oddballDistProp = [0.5, 0.0, 0.5, 0.0]; %(Only used when doing varying)
    %oddballDistProp = [0.5, 0.0, 0.5]; 
        %Relative fraction of oddball trials that will be phasic, random uniform, random normal, carrieronly-like, and fixed jittering respectively
    %Note: Must add up to 1.0 and ideally should produce an integer number of trials for each oddball type
            %Secondary note: Carrieronly-like exists for rep. supp. trials because it
            %was too difficult to make an alternating carrieronly block type
    
    %TrialLength = 128; %Per colour condition
    TrialLength = 16; %Per colour condition
    %TrialLength = 48

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blankChan'} ]; %Green-blank
    chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green-blue
    chanGroupList{2} = [ {'blueChan'},{'blueChan'},{'greenChan'} ]; %Blue, blue-blank
    
    CarrierOrder = [1];
    
elseif expMode == 3
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    oddballFraction = 0.67;
    
    oddballMode = 3;
    
    oddballDistProp = [0.5, 0.0, 0.5, 0.0]; 

    TrialLength = 86;

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    chanGroupList{1} = [ {'greenChan'},{'blankChan'},{'greenChan'} ]; %Green-blank
    
    CarrierOrder = [1];
    
elseif expMode == 4
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    oddballFraction = 1.0;
    
    oddballMode = 4;
    
    %oddballDistProp = [0.0, 0.0, 1.0];
   
    TrialLength = 72;

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blankChan'} ]; %Green-blank
    
    CarrierOrder = [1];
    probDirection = -0.1; %Whether to descend (1) or ascend (-1) (Todo: In-between)
    
    f1 = 33.3;%Override f1
    f2 = NaN; %Blank out f2
    disp(['-- f1 and f2 overridden --'])
    
elseif expMode == 5
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 1; %Whether to utilise repetition suppression
    
    oddballMode = -1; 
    oddballFraction = 1.0; %Must be 66%       
    
    %oddballDistProp = [0.0, 0.0, 0.5, 0.5]; %(Only used when doing varying)
        %Phasic, Uniform, Jittering, Carrieronly-like
    oddballDistProp = [0.5, 0.0, 0.0, 0.5, 0.0];
        
    TrialLength = 72; %Per colour condition

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green-blue
    chanGroupList{1} = [ {'blueChan'},{'blueChan'},{'greenChan'} ]; %Green-blue
    
    CarrierOrder = [1];
elseif expMode == 6
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    %oddballFraction = 0.66;
    
    oddballMode = 1;
    
    oddballFraction = 0.33; %Freely changeable value
        
    TrialLength = 1240; %Per colour condition (1240 gives ~16h with two colour conditions)

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %This
    %chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green Green-Blue
    %chanGroupList{2} = [ {'greenChan'},{'blueChan'},{'greenChan'} ]; %Green, Blue-Green
    %OR
    chanGroupList{1} = [ {'blueChan'},{'greenChan'},{'blueChan'} ]; %Green Green-Blue
    chanGroupList{2} = [ {'blueChan'},{'blueChan'},{'greenChan'} ]; %Green, Blue-Green
    
    CarrierOrder = [1];
    
    redLight = 1; %Whether to use the red light LED during the experiment
    if redLight == 1
        redMode = 2; %Whether to use MATLAB-based method (1) or RCX PulseTrain (2) for red light control
        %redFreq = 10; %Frequency in Hz for the red light to flicker at (-1 for constant)
        redStatus = [1,0]; %0 - off, 1 - on
        redDur = [1800,1800]; %Duration in seconds for each phase
        redHi = 1000; %ms for red LED to be on for
        redLo = 0; %ms for red LED to off for
            %Note that these values will be used to post-calculate redFreq even for redMode == 1
            %Secondary note: Currently only support for one frequency, but that is easy to change later on
    end
    
elseif expMode == 7
    
    %f1 = 1.25; %Override f1
    %f2 = 5.125; %Override f2
    %squareDutyCycle = 10;
    f1 = 1.25; %Override f1
    f2 = 0.625; %Override f2
    squareDutyCycle = 50; % 12.5% duty cycle at 10Hz = 100ms on, 700ms off (I think)
        %Note: There is a good chance this may be actually controlled by Schmitt settings in the RCO
    disp(['-- f1 and f2 overridden --'])
    
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    %oddballFraction = 0.66;
    
    %squareDutyCycle = 10; %Percentage of period that should be high
        % 50% is a 'normal' square wave, 25% is on for 1/4 of the time, off for 3/4, etc
        %Note that this is calculated off the 'base' f1 frequency (e.g. 20% duty cycle of 10Hz -> 20ms)
        
    oddballMode = 2; %1 - Phasic, 2 - Random uniform, 3 - Random normal, -1 - Multiple oddball modes in one exp
    
    oddballFraction = 1; %Freely changeable value
        
    TrialLength = 32; %Per colour condition (1240 gives ~16h with two colour conditions)

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %This
    %chanGroupList{1} = [ {'blueChan'},{'greenChan'},{'blueChan'} ]; %Blue Green-Blue
    %chanGroupList{2} = [ {'greenChan'},{'blueChan'},{'greenChan'} ]; %Green Blue-Green
    chanGroupList{1} = [ {'uvChan'},{'greenChan'},{'uvChan'} ]; %Blue Green-Blue
    chanGroupList{2} = [ {'greenChan'},{'blueChan'},{'greenChan'} ]; %Green Blue-Green
        %Note: In the context of oddballFraction == 1, carrieronly will never be shown
    
    CarrierOrder = [1];
elseif expMode == 8
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    %oddballFraction = 0.66;
    
    oddballMode = 1; %1 - Phasic, 2 - Random uniform, 3 - Random normal, -1 - Multiple oddball modes in one exp
    
    oddballFraction = 0.0; %Freely changeable value
        
    TrialLength = 2480; %Per colour condition (1240 gives ~16h with two colour conditions)

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %This
    %chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green Green-Blue
    %chanGroupList{2} = [ {'greenChan'},{'blueChan'},{'greenChan'} ]; %Green, Blue-Green
    %OR
    chanGroupList{1} = [ {'blankChan'},{'blankChan'},{'blankChan'} ]; %Green Green-Blue
    %chanGroupList{2} = [ {'blueChan'},{'blueChan'},{'greenChan'} ]; %Green, Blue-Green
    
    CarrierOrder = [1];
    
    redLight = 1; %Whether to use the red light LED during the experiment
    if redLight == 1
        redMode = 2; %Whether to use MATLAB-based method (1) or RCX PulseTrain (2) for red light control
        %redFreq = 10; %Frequency in Hz for the red light to flicker at (-1 for constant)
        redStatus = [1,0]; %0 - off, 1 - on
        redDur = [1800,1800]; %Duration in seconds for each phase
        redHi = 1000; %ms for red LED to be on for
        redLo = 0; %ms for red LED to off for
    end
    
elseif expMode == 9
    doSine = 0; %Whether to do sine (1) or square (0) wave stimulus
    repSupp = 0; %Whether to utilise repetition suppression
        %Note: Only tested in the context of expMode == 5
    %oddballFraction = 0.66;
    
    oddballMode = 5; 
        %1 - Phasic, 2 - Random uniform, 3 - Random normal, 4 - Probability descent, 5 - Fixed jiiter, -1 - Multiple oddball modes in one exp
    if oddballMode ~= -1
        oddballFraction = 0.33; %Freely changeable value
    else
        oddballFraction = 0.66; %Must be 66%
        oddballDistProp = [0.0, 0.0, 0.0, 0.0, 1.0]; %(Only used when doing varying)
            %Moved into here to reduce ambiguity
    end
    
    %oddballDistProp = [0.5, 0.0, 0.5, 0.0]; %(Only used when doing varying)
    %oddballDistProp = [0.5, 0.0, 0.5];
    %Note: Must add up to 1.0 and ideally should produce an integer number of trials for each oddball type

    %TrialLength = 128; %Per colour condition
    TrialLength = 96; %Per colour condition
    %TrialLength = 48

    chanGroupList = []; %CarrierOnly, Carrier, Oddball
    %chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blankChan'} ]; %Green-blank
    chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green-blue
    chanGroupList{2} = [ {'blueChan'},{'blueChan'},{'greenChan'} ]; %Blue, blue-blank
    
    CarrierOrder = [1];
    
    redLight = 1; %Whether to use the red light LED during the experiment
    if redLight == 1
        redMode = 2; %Whether to use MATLAB-based method (1) or RCX PulseTrain (2) for red light control
        redStatus = [1,0]; %0 - off, 1 - on
        redDur = [300,300]; %Duration in seconds for each phase
        redHi = 1000; %ms for red LED to be on for
        redLo = 0; %ms for red LED to off for
    end
    
    f1 = 10; % carrierfrequency
    f2 = 0.5; % oddball frequency
    
    %Prepare fixed jittering params
    if oddballMode == 5 | (oddballMode == -1 && oddballDistProp(5) > 0 )
        f2 = NaN;
        fixedJitterRange = [2,10]; %Blocks of fixed jittering will be assembled between this high and low value
    end
    
end

%QA
if isempty(chanGroupList{1}) == 1
    ['## ALERT: POTENTIAL ERROR IN chanGroupList SPECIFICATION ##']
    crash = yes
end

%QA for red
if exist('redLight') ~= 1
    redLight = 0;
    disp(['(Red light not specified; Defaulting to 0)'])
end

%-----------------

%Diary things
if doDiary == 1
    diaryName = [datestr(now, 'dd-mm-yy'),'_E',num2str(expMode),'_T',num2str(TrialLength),'.txt'];
    diary([diaryPath, filesep, diaryName])
    diary on
end

%-----------------

%-------------------------------------------------------------------------
%Special crash parameters
forceCrash = 0; %Enable this to force a crash at an early point in the run, to allow TDT to be told to suppress future crash dialog boxes
if forceCrash == 1
    ['-# Experimental parameters overwritten in line with forceCrash request #-']
    chunkDatasets = 0;
    runningMemoryClear = 0;
    piecemealTTLstruct = 0;
    saveTTLLoad = 0;
    %Fake experiment params to give quick start
    oddballMode = 1;
    oddballFraction = 0.5;
    TrialLength = 96;
    chanGroupList = [];
    chanGroupList{1} = [ {'greenChan'},{'greenChan'},{'blueChan'} ]; %Green-blue
    CarrierOrder = [1];
    proceed = input('System is requested to crash. Is this correct? (0/1) ')
    if proceed ~= 1
        ['#- Aborting -#']
        crash = yes
    end
end
%-------------------------------------------------------------------------
%Parameters that might change in future but are currently unlikely to

tdtModeIndex = [{'Idle'},{'Standby'},{'Preview'},{'Record'}];

intermissionMode = 1; %Denotes the mode that the TDT hardware should be set to between chunks
runMode = 3; %Ditto above, except for the experimental runtime
    %Note that the TDT hardware uses 0 - X indexing, therefore Mode 1 is Standby, not Idle, which is Mode 0
disp([char(10),'-- The system is requested to operate in ',tdtModeIndex{runMode+1},' mode --',char(10)])

defaultFS = 2.4414e+04; %Will be used as default fs in case of TDT fs pull failure

numFirsts = 0; %How many of the 'carrier' type to display at the start

%Addon for jitter
if oddballMode == 3 || oddballMode == -1 || oddballMode == 5
    jitterWidth = 2.5; %'Width' of jittering position (1 SD (probably)) i.e. a value of 2.5 means that 1 SD of the time the oddball will be within 2.5 cycles of the original position
end

%SineOrSquare = 'sine';
SaveSetting = 'on'; % on or off
%%StimOrder = 3; % sine first = 1; square first = 2; randomize = 3; %DEPRECATED
AirPuff = 0; % 1 is yes 0 is no

Condition = repmat({'carrieronly'; 'carrier'; 'oddball'}, 2, 1);
WaitMinutes = 0.2; % was 3
hardcodedWaitMinutes = 0.1; %"Wait for <X>s"
% Condition = {'carrieronly'; 'carrieronly'};

% amplitudes 4/08/2017
Ch10 = [0.281, 0.266]*2; % (Blue); 470nm
Ch11 = [0.321, 0.320]*2; % (Green); 525nm
Ch12 = [0.999, 0.860]*2; % (UV); 361nm
%QA
if Ch11(2) ~= 0.320*2
    ['#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#']
    ['#- Warning: Green channel power differs from current normal value -#']
    ['#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#']
end
%Luminance sweep values:
%Green [~, 0.320] , [~, 0.220] and [~, 0.120] yields <insert power here>
%Current values:
%Blue [0.281, 0.266] yields 0.500mW for sine wave and ~0.498mW(+-2mW) for square wave 100Hz at 470nm (14/7/20 until)
%Green [0.321, 0.320] yields 0.500mW for sine wave and ~0.502mW(+-2mW) for square wave 100Hz at 525nm (14/7/20 until)
%Historical values:
%Blue [0.350, 0.320] yields 0.6mW for square wave 100Hz at 470nm (24/4/20 until 14/7/20)
%Green [0.350, 0.320] yields 0.54mW for sine wave and 0.5mW for square wave 100Hz at 470nm (24/4/20 until 14/7/20)
%Super historical values:
%Blue used to be 0.742 and 0.624 (24/4/20);
%-------------------------------------------------------------------------
%Reporters
%--------------------------------
%'Standard' oddball operation
if oddballMode == 1
    oddballTypeStr = 'Oddball';
elseif oddballMode == 2
    oddballTypeStr = 'OddballRandomUniform';
elseif oddballMode == 3
    oddballTypeStr = 'OddballJitter';
elseif oddballMode == 4
    oddballTypeStr = 'OddballProbDescent';
elseif oddballMode == 5
    oddballTypeStr = 'OddballFixedJitter';
end

%33 33 33 functionality
if oddballMode == -1
    %QA
    if nansum(oddballDistProp) ~= 1.0
        ['## Alert: Requested oddball distribution does not add up to 1 ##']
        youCanNotContinue = yes %Minor Evangelion reference because "error" used later for DA stuff
    end
    oddballTypeStr = 'OddballVarying';
    disp(['-- Oddball stimulus will be ',...
        num2str(oddballDistProp(1)*100),'% phasic, ',...
        num2str(oddballDistProp(2)*100),'% random uniform, ',...
        num2str(oddballDistProp(3)*100),'% normally jittered, ',...
        num2str(oddballDistProp(4)*100),'% carrieronly-like,',...
        num2str(oddballDistProp(5)*100),'% fixed jittering ---',...
        ]);
else
    disp(['-- Oddball stimulus will be ',oddballTypeStr,' --'])
end

if oddballMode == 1 | oddballMode == 2 | oddballMode == 3 | oddballMode == -1 | oddballMode == 5
    disp(['Carrier trials will have ',num2str((1-oddballFraction)*100),'% probability first, followed by oddballs at ',num2str(oddballFraction*100),'%.'])
else
    disp(['Oddball/Carrier probability varies over time'])
end

%--------------------------------
disp(['-- f1: ',num2str(f1),'Hz, f2:',num2str(f2),'Hz --'])

debugMode = 0; %Overrides runMode, saving, etc
if debugMode == 1
    ['^^^^^^^^ Debug mode active ^^^^^^^^']
    runMode = 2;
    SaveSetting = 'off';
    hardcodedWaitMinutes = 0.02;
    WaitMinutes = 0.01;
end

%Request manual entry of block number
if socky == 1 && debugMode ~= 1
    proceed = 0;
    while proceed == 0
       prosBlockNum = input('Please input block number: ');
       blockNum = prosBlockNum;
       proceed = 1;
    end
else
   blockNum  = 99;
   disp(['Block number hard forced'])
end
idealisedBlockNum = blockNum; %This is a value that under normal conditions will mirror blockNum but will not iterate with failsafe use
    %This is because iterating blockNum as a factor of failsafe use desynchronises ttlStruct loading if piecemeal is active
disp(['-- Proceeding with block number of ',num2str(blockNum),' --',char(10)])

%Save useful flags/params to struct
flagParamSaveList = who;
flagParamSaveStruct = struct;
for i = 1:size(flagParamSaveList,1)
    eval(['flagParamSaveStruct.',flagParamSaveList{i},' = ', flagParamSaveList{i},';'])
end

customSaveStr = []; %Used for modifying the save path of saveStruct
if socky == 2
    customSaveStr = [customSaveStr, '_unsocketed_'];
end

%-------------------------------------------------------------------------

orderCount = 0;
for CarrierFirst = CarrierOrder;
    orderCount = orderCount + 1;
    %Make a reusable copy of the true oddball probability to simplify some elements of the code
    if oddballMode == 1 | oddballMode == 2 | oddballMode == 3 | oddballMode == -1 | oddballMode == 4 | oddballMode == 5
        if CarrierFirst == 1
            oddballFractionActive = oddballFraction;
        else
            oddballFractionActive = (1 - oddballFraction);
        end
    end

    %TDT connection
    fs = defaultFS; %Use default value at start here, will be checked for correctness later on

    %% Generate Sine wave and square wave stimuli in MATLAB to later load into a buffer
    % First sine wave
    % SineWaveGeneration.m used as reference (see Code on server)
    Voltage = 1;
    %f1 = 20; % carrierfrequency
    %f2 = 2; % oddball frequency
    % offduration = 1; % seconds
    stimduration = 20.01; % seconds
    
    %Old fs location
  
    t = 0:1/fs:stimduration;

    %New square-wave duty cycle calculations
    if exist('squareDutyCycle') == 0
        ['-# Caution: Square wave duty cycle not specified; Using default 50% #-']
        squareDutyCycle = 50;
    end
    
    stimvalue = 2*pi*f1*t-pi/2; % the -pi/2 is to subtract half a cycle
    carrieronlysine = sin(stimvalue)*Voltage; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
    %carrieronlysquare = square(stimvalue, 50)*Voltage; % generate square wave with same parameters
    carrieronlysquare = square(stimvalue, squareDutyCycle)*Voltage; % generate square wave with same parameters
    % multiplied by RMS voltage of sine wave so they're equal brightness https://qph.ec.quoracdn.net/main-qimg-0122ec8dc291cff2cbb5178cf0b18093
    %carrieronlysquare = flip(carrieronlysquare); %Testatory

    disp(['-- Preparing Oddball TTLs --'])
    disp(['(This should take no more than a few seconds...)'])
    temp = clock;
    %Matt
    cyclelength = fs/f1; %Moved up here to interface better with saving null cycleIdent for carriers
        %Note: Having this here disallows the possibility of variable frequency
        %trials within the same block (A ttlStruct that covers both carrier and
        %oddball would be necessary for such a thing)
    numCycles = floor(length(carrieronlysine) / cyclelength); %Literal number of light pulse events
    cycleOnsets = floor(linspace(1,length(carrieronlysine)-cyclelength,numCycles)); %Denotes the absolute positions of the onset of the cycles
        %Note: This has the first cycle starting at literal position 1, which
        %may act oddly with sine waves/etc
        %Secondary note: The last cycle occurs at position end-cyclelength, to allow for display of a correct number of cycles 
    carrieronlyCycleIdent = zeros(1,numCycles); %Will be used for reporting purposes whenever carrier trials are sent (0 - carrier cycle, 1 - Oddball cycle)

    ttlStruct = struct;

    %numOddballTrials = ceil( size(chanGroupList,2) * TrialLength * oddballFraction);
    %numOddballTrials = floor( size(chanGroupList,2) * TrialLength * oddballFractionActive ) * 2; % *2 because sine/square (even if that feature is currently unused)
        %Note: If there is any instability in the actual number of oddball trials this may not be enough preloadeds
    numOddballTrials = floor( size(chanGroupList,2) * TrialLength * oddballFractionActive ); %Removed *2 because of removal of arbitrary doubling

    %Pre-build oddball order
    oddballOrder = [];
    if oddballMode == -1
        oddballOrder = nan(1,numOddballTrials);
        oddballOrder = [ repmat([1],1,floor(oddballDistProp(1)*numOddballTrials)) , ...
            repmat([2],1,floor(oddballDistProp(2)*numOddballTrials)) , ...
            repmat([3],1,floor(oddballDistProp(3)*numOddballTrials)), ...
            repmat([4],1,floor(oddballDistProp(4)*numOddballTrials)),...
            repmat([5],1,floor(oddballDistProp(5)*numOddballTrials)),...
            ];
            %In a perfect world this will form a list of exactly
            %numOddballTrials long, comprised of the relative fractions of
            %oddball types
            %However, if the fractions do not yield integers when multiplied by
            %numOddballTrials, action must be taken to correct
        %QA
        if nansum(isnan(oddballOrder)) > 0 %"Fractions yielded integers less than full length"
            ['## Oddball fractions could not be rendered accurately by ',num2str(nansum(isnan(oddballOrder))),' trials (Correction applied) ##']
            oddballOrder(isnan(oddballOrder) == 1) = find(oddballDistProp ~= 0,1); %Force to be first requested oddball type with non-zero probability fraction 
        end
        if size(oddballOrder,2) > numOddballTrials
            ['## Oddball fractions resulted in overlength ',num2str(nansum(isnan(oddballOrder))),' trials (Truncation applied) ##']
            oddballOrder(numOddballTrials+1:end) = [];
        end
    else
        oddballOrder = [ repmat(oddballMode,1,numOddballTrials) ]; %Replicate oddballMode if not using varying
    end

    numOddballTrials = size(oddballOrder,2); %Retcon
    
    %Prepare some additional variables if doing fixed jitter
    if oddballMode == 5 | (oddballMode == -1 && oddballDistProp(5) > 0 )
        %f2List = linspace( fixedJitterRange(2), fixedJitterRange(1), numOddballTrials ); %Old, frequency based system
            %Generate a range of f2s based on fixedJitterRange and the number of oddball trials
        f2List = [ fixedJitterRange(1) : 1 : fixedJitterRange(2), fixedJitterRange(2) ]; %New, cycle based
            %Generate a list of intervals (With hardcoded spacing of 1)
            %The appending of the second element of fixedJitterRange is just a bootleg method to ensure vague parity of representation following interpolation
            %Might consider making this a full specified list eventually
        f2List = interp1( [1:size(f2List,2)] , f2List, [linspace(1,size(f2List,2),numOddballTrials)], 'previous' );
        f2List = f2List( randperm( size(f2List,2) ) ); %Randomise order (Otherwise this would just be a prob descent)
    end

    %Randomise oddball order OR assemble descent order
    if oddballMode ~= 4
        %oddballOrder = oddballOrder(randperm(numOddballTrials)); %Randomise oddball types (redundant if unvarying)
        oddballOrder = oddballOrder(randperm(size(oddballOrder,2))); %Randomise oddball types (redundant if unvarying)
            %Note: No additional checks currently implemented to prevent immediacy effects, etc
            %Secondary note: If numOddballTrials is not *exactly* the same as the
            %number of actually delivered oddballs then some oddball types may be
            %excluded (But randomisation technically means this exclusion will be
            %in an unbiased manner...)
    else
        oddballOrder = oddballOrder;
        if probDirection > 0 %Descending
            oddballSubOrder = [0:probDirection:1]; %What fraction of cycles should be made oddballs
        else %Ascending
            oddballSubOrder = [1:probDirection:0];
        end
        oddballSubOrder = imresize(oddballSubOrder, [1,numOddballTrials]);
        oddballSubOrder(oddballSubOrder < 0) = 0;
        oddballSubOrder(oddballSubOrder > 1) = 1;
    end

    %Determine oddball cycle positions
    hasWarned = [0,0]; %Once-off warning flag for a specific QA (Size depends on how many messages to count for)
    for condInd = 1:numOddballTrials %size(chanGroupList,2)
        oddballTTL = zeros(1, length(carrieronlysine)); %Inversion from previous method
        carrierTTL = ones(1, length(carrieronlysine)); 
        carrieronlyTTL = ones(1,length(carrieronlysine));
            %Note: Full length of carrieronlysine may be longer than original keepcycles
        %cyclelength = fs/f1;
        %numCycles = floor(length(carrieronlysine) / cyclelength); %Literal number of light pulse events
            %Note: Use of floor may induce inaccuracies here
        %###
        cycleIdent = zeros(1,numCycles); %The identity (1-Carrier,2-Oddball) of every cycle
        %###

        %Calculate repetition suppression positions if requested
        if repSupp == 1
            repSuppInds = [2:2:size(cycleIdent,2)];
            originalCycleIdent = cycleIdent;
            cycleIdent( repSuppInds ) = 1; %Set alternating cycles to be 'oddball'
        end

        if oddballMode ~= 4 %Phasic, Jittering, Varying
            
            if oddballMode ~= 5 %Anything but fixed jitter
                targetOddbFreq = f2;
                freqModulus = f1/targetOddbFreq; %New version
                    %Shifted here because fixed jitter no longer uses frequency
            else
                freqModulus = f2List(condInd); 
                targetOddbFreq = f1 / f2List(condInd);
            end
            numOddbToInsert = floor(length(carrieronlysine) / (fs / targetOddbFreq) ); %How many carriers to turn into oddballs
                %Note: If this exceeds f1 there will be problems
            %freqModulus = f1/f2;
            %freqModulus = f1/targetOddbFreq; %New version
            oddballIndices = zeros(1,numOddbToInsert);
            %QA
            if targetOddbFreq > f1 | numOddbToInsert == 0
                ['## Alert: Invalid oddball frequency values calculated ##']
                crash = yes
            end

            if oddballOrder(condInd) == 1
                oddballIndices = [freqModulus:freqModulus:numCycles];
            elseif oddballOrder(condInd)== 2
                while size(unique(oddballIndices),2) ~= numOddbToInsert || nanmin(oddballIndices) < 1 || nanmax(oddballIndices) > numCycles -1
                    %Randperm implementation (Uniformly random positions across the block)
                    %oddballIndices = randperm(numCycles,numOddbToInsert); %Find numOddbToInsert positions to do oddball at
                    oddballIndices = randperm(numCycles-2,numOddbToInsert)+1; %Find numOddbToInsert positions (but not first or last) to do oddball at
                end
            elseif oddballOrder(condInd) == 3
                while size(unique(oddballIndices),2) ~= numOddbToInsert || nanmin(oddballIndices) < 1 || nanmax(oddballIndices) > numCycles -1
                    %Random normal implementation (Normal distribution, centred around middle of each sub-group of cycles)
                    oddballIndices = floor( randn(1,numCycles/freqModulus) * jitterWidth + [freqModulus:freqModulus:numCycles] );
                end
            elseif oddballOrder(condInd) == 4
                oddballIndices = []; %Assign no oddball cycles for carrieronly-like
            elseif oddballOrder(condInd) == 5
                %Original attempted implementation of fixed jitter
                    %(Failed because inability to converge for high-frequency oddballs)
                %{
                tic
                a = 1;
                while size(unique(oddballIndices),2) ~= numOddbToInsert || nanmin(oddballIndices) < 1 || nanmax(oddballIndices) > numCycles - 1
                    %Random normal implementation (Normal distribution, centred around middle of each sub-group of cycles)
                    %(Modified for fixed jitter)
                    oddballIndices = floor( randn(1,numOddbToInsert) * jitterWidth + [freqModulus:freqModulus:numCycles] );
                    %QA for infiniloop
                    if toc > 60
                        ['-# Caution: Fixed jitter position calculations taking excessive time (',num2str(a),' it) #-']
                        crash = yes
                        tic %Prevent spam
                    end
                    a = a + 1;
                end
                %}
                %New, cycle based system
                    %Note: No QA for perfectly correct number of oddballs
                        %(But unlikely to be a huge issue)
                oddballIndices = [freqModulus:freqModulus:numCycles];    
            end

            %Manually curate oddball positions if doing rep. supp.
                %Note: Should maybe be implemented for non-rep. supp. but I cbf
                %and it's only really a problem with jittering double-ups etc
            if repSupp == 1
                for oddInd = 1:size(oddballIndices,2)
                    while cycleIdent(oddballIndices(oddInd)) == 1 && oddballIndices(oddInd) < size(cycleIdent,2)
                            %Repeat until oddball not occurring on an existing
                            %oddball event (because of alternation)
                        oddballIndices(oddInd) = oddballIndices(oddInd) + 1;
                    end
                end
            end
                %Note: This system does not prevent against oddballs occurring
                %at the same position as each other or immediately after
                    %But tbh it's an improvment on the previous loss rate...
        elseif oddballMode == 4 %Probability descent
                %Note: It is better to group all new oddball modes in the above case, to allow for easy
                %double-handling of specific oddballModes as well as oddballMode = -1
            numOddbToInsert = floor( numCycles * oddballSubOrder(condInd) );
            oddballIndices = zeros(1,numOddbToInsert);
            oddballIndices = randperm(numCycles,numOddbToInsert); %Slight modification of random uniform implementation
        end
        cycleIdent( oddballIndices ) = 1;
        %Old position of rep. supp. code

        for cycInd = 1:size(cycleIdent,2)
            %Old, semi-accurate system
            %{
            if cycleIdent(cycInd) == 1 %Is oddball
                %oddballTTL( floor( cycInd*cyclelength - 0.5*cyclelength : cycInd*cyclelength + 0.5*cyclelength )  ) = cycleIdent(cycInd);
                %oddballTTL( floor( cycInd*cyclelength - 1*cyclelength + 1 : cycInd*cyclelength )  ) = cycleIdent(cycInd); %Current generation
                %%prosRange = floor( cycInd*cyclelength - 1*cyclelength : cycInd*cyclelength+1 );
                prosRange = floor( cycInd*cyclelength );
                prosRange( prosRange < 1 ) = 1; prosRange( prosRange > size(oddballTTL,2) ) = size(oddballTTL,2); %Clean indices
                oddballTTL( prosRange ) = cycleIdent(cycInd); %Next generation (Very slightly wider)
            end
            %carrierTTL( floor( cycInd*cyclelength - 1*cyclelength + 1 : cycInd*cyclelength )  ) = ~cycleIdent(cycInd);
            %}
            %New, pre-calulated-based system
            if cycInd < size(cycleIdent,2)
                prosRange = [ cycleOnsets(cycInd) : cycleOnsets(cycInd+1) ]; %Fill from onset to start of onset of next
            else
                prosRange = [ cycleOnsets(cycInd) : length(carrieronlysine) ]; %Fill from onset to end
            end
            oddballTTL( prosRange ) = cycleIdent(cycInd); %Fill prospective range with cycle identity
        end
        carrierTTL = carrierTTL - oddballTTL;
        %QA
        if repSupp ~= 1
            if nansum(cycleIdent) ~= numOddbToInsert
                ['## Alert: Critical failure in oddball cycle position determination ##']
                crash = yes
            end
            %Second-stage QA for ensuring correct shape of TTL
            if abs( ( nansum(carrierTTL == 1) / cyclelength ) - (numCycles - numOddbToInsert) ) > 0.05*(numCycles - numOddbToInsert)
                ['## Alert: Assembled TTL differs from intended number of oddball/carrier cycles by >5% ##']
                crash = yes %Possibility this could aberrantly arise from normal running inaccuracies
                    %This QA operates by dividing the TTL Up time by cyclelength to
                    %back-calculate how many cycles were carrier (Other, difference-based methods proved...inadequate)
                        %Note: This QA will not help with indexing inaccuracies;
                        %That is presumed to be covered by new, pre-calculated
                        %methods
            end
        else
            %QA to see if alternation will abolish 'true' oddball cycles
            if isempty(intersect(oddballIndices,repSuppInds)) ~= 1  && hasWarned(1) == 0
                ['#-# Alert: ',num2str((size(intersect(oddballIndices,repSuppInds),2)/size(oddballIndices,2))*100),...
                    '% intersection between oddballs and alternation detected #-#']
                hasWarned(1) = 1;
            end
            if size(intersect(oddballIndices,repSuppInds),2) == size(oddballIndices,2)
                ['## Alert: All oddball cycle positions subsumed by alternation ##']
                crash = yes
            end
            %{
            %(Disabled because reordering has made originalCycleIdent non-functional for these purposes)
            if oddballOrder(condInd) ~= 4 && numOddbToInsert - nansum(originalCycleIdent) > 0.05*numOddbToInsert
                ['## Alert: Critical failure in oddball cycle position determination ##']
                crash = yes
            end
            %}
        end
        %Uniqueness QA for oddball indices
        if oddballOrder(condInd) ~= 4 && size(unique(oddballIndices),2) ~= size(oddballIndices,2) && hasWarned(2) == 0
            ['## Warning: At least ',num2str( size(oddballIndices,2) - size(unique(oddballIndices),2)),' oddball cycles directly overlap and have been lost ##']
            hasWarned(2) = 1;
        end

        %Clean start and end
        carrieronlyTTL(1,1) = 0; carrieronlyTTL(1,end) = 0;
        carrierTTL(1,1:1) = 0; carrierTTL(1,end) = 0;
        oddballTTL(1,1:1) = 0; oddballTTL(1,end) = 0;

        carrieronlysine(1,1) = 0; carrieronlysine(1,end) = 0; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
        carrieronlysquare(1,1) = 0; carrieronlysquare(1,end) = 0;

        %Save to overstruct
        ttlStruct(condInd).carrieronlyTTL = carrieronlyTTL;
        ttlStruct(condInd).carrierTTL = carrierTTL;
        ttlStruct(condInd).oddballTTL = oddballTTL;

        ttlStruct(condInd).combinedTTL = [carrieronlyTTL; carrierTTL; oddballTTL];

        ttlStruct(condInd).carrieronlysine = carrieronlysine;
        ttlStruct(condInd).carrieronlysquare = carrieronlysquare;

        ttlStruct(condInd).cycleIdent = cycleIdent;
        if repSupp == 1
            ttlStruct(condInd).originalCycleIdent = originalCycleIdent;
        end

        ttlStruct(condInd).oddballType = oddballOrder(condInd);
        
        ttlStruct(condInd).hasBeenSent = 0; %Keeps track of whether this oddball block has been displayed
        
        ttlStruct(condInd).idealisedBlockToBeSentIn = 0; %What number block this should have been sent in, if no failsafe or other issues
            %These values are filled in by the piecemeal section below
        
        ttlStruct(condInd).blockSentIn = 0; %Keeps track of what block number this was sent in
                
        ttlStruct(condInd).order = condInd; %Tracks what number oddball block this is (Important for synchronicity when things like piecemeal are used)
        
        %QA
        if isempty( ttlStruct(condInd).combinedTTL ) == 1
            ['## Alert: ttlStruct for oddball block ',num2str(condInd),' empty ##']
            crash = yes
        end

    end
    
    %Report metrics if using varying oddballs
    if oddballMode == -1
        disp([...
            num2str(nansum(oddballOrder == 1)),' phasic trials prepared, ',...
            num2str(nansum(oddballOrder == 2)),' random uniform trials prepared, ',...
            num2str(nansum(oddballOrder == 3)),' normally jittered trials prepared, ',...
             num2str(nansum(oddballOrder == 4)),' carrieronly-like trials prepared'])
        disp(['Order: ', num2str(oddballOrder)])
    end
    disp(['-- Oddball TTLs successfully prepared (',num2str(etime(clock,temp)),'s) --'])

    %Make 'pure' carrieronly TTL for carrieronly blocks, as well as rest 'TTL'
    carrieronlyTTL = ones(1,length(carrieronlysine));
    carrieronlyTTL(1,1) = 0; carrieronlyTTL(1,end) = 0;
    carrierOnlyTTLVector = [carrieronlyTTL; carrieronlyTTL; zeros(1,length(carrieronlysine)) ];
        %Row 1 - Carrieronly TTL, Row 2 - Carrier TTL (duplicate of
        %carrieronly), Row 3 - Oddball TTL (all zeros)
    restTTLVector = [ zeros(3,length(carrieronlysine)) ]; 

    %Testatory figure to show relationship between carrier and oddball position
    %{
    figure
    scatter(oddballIndices, [repmat(1,1,size(oddballIndices,2))])
    hold on
    blirg = [freqModulus:freqModulus:numCycles];
    scatter([blirg],[repmat(0.9,1,numOddbToInsert)]) %Only valid when normal randomisation used
    for i = 1:size(oddballIndices,2)
        line([blirg(i), oddballIndices(i)],[0.9,1])
    end
    ylim([0.8,1.2])
    %}

    %switch 1 % for sine wave and square wave stim stimuli
    %{
        case 1
            %%carrierTTL = carrierTTL.*removecycles;
            %%oddballTTL = oddballTTL.*keepcycles;

            % to avoid odd behaviour with the gating (since first value is pre-loaded), make first and last value zero
            carrieronlyTTL(1,1) = 0;
            carrierTTL(1,1:1) = 0;
            oddballTTL(1,1:1) = 0;

            carrieronlyTTL(1,end) = 0;
            carrierTTL(1,end) = 0;
            oddballTTL(1,end) = 0;

            carrieronlysine(1,1) = 0; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
            carrieronlysquare(1,1) = 0;
            carrieronlysine(1,end) = 0; % Generate Sine Wave to get RMS voltage % http://www.rfcafe.com/references/electrical/sinewave-voltage-conversion.htm
            carrieronlysquare(1,end) = 0;
            %
            % carriersquare = carrieronlysquare.*removecycles;
            % oddballsquare = carrieronlysquare.*keepcycles;

            % Try to make the removed cycles -1 instead of 0

            %{
            switch 0 % To make the 'off' parts of the oddball and carrier -1. Actually, this is doing strange things with the board so keep it off.
                case 1 % if this is turned on, oddball and carrier will not be the same amplitude for some reason.
                    for cycle = 1:iterationnumber:length(carrieronlysine);
                        if cycle == 1
                            % skip this!
                        else
                            carriersine(1, 1+floor(cycle-cyclelength:cycle)) = min(carriersine);
                            carriersquare(1, 1+floor(cycle-cyclelength:cycle)) = min(carriersquare);

                        end
                    end
                    %


                    count =0;
                    cyclevector = 1:iterationnumber:length(carrieronlysine);
                    for cycle = 1:iterationnumber:length(carrieronlysine);
                        count = count + 1;
                        try
                            oddballsine(1, 1+floor(cycle:cyclevector(count+1)-cyclelength)) = min(oddballsine);
                            oddballsquare(1, 1+floor(cycle:cyclevector(count+1)-cyclelength)) = min(oddballsquare);
                        end
                    end
            end % switch 0
            %}
    %}
    %end % switch 1

    stimulusduration = floor((stimduration)*fs); % convert to samples
    trialDuration = floor( stimduration * 1000 ); %Convert to ms

    switch 1
        case 1
            if piecemealTTLstruct ~= 1 %Mainly for piecemealTTLstruct usage
                % Check stimuli        
                figure

                % check the TTL
                numSamplesToShow = 4;
                if size(ttlStruct,2) < numSamplesToShow
                    plot(carrierTTL, 'b');
                    hold on;
                    plot(oddballTTL, 'r');

                    xlabel('Time (samples)')
                    title(['Sample of Carrier (b) and Oddball (r) TTL'])
                else
                    %ttlExamples = randperm(size(ttlStruct,2),numSamplesToShow); %Select <numSamplesToShow> examples from ttlStruct
                    ttlExamples =  floor(linspace(1,size(ttlStruct,2),numSamplesToShow)); %Select <numSamplesToShow> evenly spaced examples from ttlStruct
                    for i = 1:size(ttlExamples,2)
                        subplot(numSamplesToShow,1,i)
                        plot(ttlStruct(ttlExamples(i)).carrieronlyTTL, 'b');
                        hold on;
                        plot(ttlStruct(ttlExamples(i)).oddballTTL, 'r');

                        xlabel('Time (samples)')
                        title(['Sample of Carrier (b) and Oddball (r) TTL (Oddball block number: ',num2str(ttlExamples(i)),', type: ',num2str(ttlStruct(ttlExamples(i)).oddballType),')'])
                    end
                end
            end
    end
    
    %Red light TTL construction
    if redLight == 1
        redFreq = 1000 / (redHi + redLo); %Works for both modes
        redDurations = floor(redDur * fs); %Note that this can be more than one value
        if redMode == 1
            %redT = 0:1/fs:redDur(1);
            redT = 0:1/fs:nanmax( redDur );
            %redT = 0:1/fs:nanmax( redDur*1.25 ); %Arbitrarily increasing length
            if redFreq ~= -1 %Flickering at redFreq
                redStimValue = 2*pi*redFreq*redT-pi/2;
                redSquare = square(redStimValue);%, squareDutyCycle); %Currently no support for custom red duty cycle
                redSquare(redSquare == -1) = 0; %Bootleg normalization
                redSquare(redSquare == 1) = 5;
            else %Constant
                redSquare = ones(1,size(redT,2))*5;
            end
            %redDuration = floor(redDur * fs);
            %redDuration = floor(redDur*1.25 * fs);
        elseif redMode == 2
            redSquare = NaN; %Symbolic, to show that redSquare is not used in redMode 2
            redPulseNum = floor(redDur * redFreq);
        end
    end

    %% Assign stimulus orders
    Chan10 = repmat([10], 1, TrialLength); % blue
    Chan11 = repmat([11], 1, TrialLength); % green
    Chan12 = repmat([12], 1, TrialLength); % UV
    Chan0 = repmat([0], 1, TrialLength); % nothing/ absence
    
    %Matt
        %Old
    %{
    blueChan = Chan10; %"Heh"
    greenChan = Chan11;
    uvChan = Chan12;
    blankChan = Chan0;
    %}
        %New (Not repmatted, to allow for interleaving)
    blueChan = 10; %"Heh"
    greenChan = 11;
    uvChan = 12;
    blankChan = 0;
    
    %Assemble ChannelGroups (Matt version) %Old
        %This version simply places the colour groups in order
    %{
    ChannelGroups = [];
    for condInd = 1:size(chanGroupList,2)
        temp = [];
        for carrOdd = 1:size(chanGroupList{condInd},2)
            eval(['temp(carrOdd,:) = ', chanGroupList{condInd}{carrOdd}, ';']); %Relies on repmatted values
        end
        ChannelGroups = [ChannelGroups, temp];
    end
    %}
    %New
        %This version interleaves the groups as going
            %(Technically this may mean that some groups are under-represented, but this is unlikely to be a big issue)
    ChannelGroups = [];
    a = 1;
    for i = 1:TrialLength %Note: No support for asymetrically sized chanGroupList elements
        for x = 1:size( chanGroupList,2 )
            thisCol = [];
            for condInd = 1:size( chanGroupList{x} , 2 )
                eval(['thisCol(condInd,1) = ', chanGroupList{x}{condInd}, ';']);
            end
            ChannelGroups(:,a) = thisCol;
            a = a + 1;
        end
    end
        %This works by iterating along TrialLength, rather than chanGroupList
            %With each iteration the next element of chanGroupList is placed into the array
                %e.g. If there are two elements, ChannelGroups will be an alternation between items 1 and 2 of chanGroupList
                    %And so on, for more or less elements
        %Note: Currently only this colour layer is interleaved; Oddball correctness is handled by randperm and sine/square identity
        %does not change across the experiment
            %If either of these assumptions become not-correct then adjustments will need to be made
    
    %Assemble ChannelGroups (Rhiannon version)
    % ChannelGroups = horzcat(Chan10_11,Chan11_10,Chan10_0,Chan11_0);
    %ChannelGroups = horzcat(Chan11_10,Chan11_0); %Green and Blue, Green and Nothing
    %ChannelGroups = horzcat(Chan11_10); %Green and Blue

    SizeGroups = size(ChannelGroups,2)/TrialLength; % This is to get the number of different conditions
    HeightGroups = size(ChannelGroups,1);

    %% On Off - Gating for carrieronly, carrier, or oddball conditions

    %%OddballProb = 2; %
    %OddballProb = floor(TrialLength*oddballFractionActive);
    OddballProb = numOddballTrials; %NOTE: MAY HAVE UNINTENDED SIDE EFFECTS FOR MULTIPLE CARRIERSWITCH EXPERIMENTS
    %CarrierProb = TrialLength - OddballProb; %Using the value from the preceding line ensures floor/int synchronicity
    CarrierProb = (TrialLength*size(chanGroupList,2)) - OddballProb; %Using the value from the preceding line ensures floor/int synchronicity
    %QA for possibleness
    if floor(TrialLength*oddballFractionActive) ~= TrialLength*oddballFractionActive
        disp(['## Warning: Oddball probability of ',num2str(oddballFractionActive),...
            ' cannot be accurately rendered with trial length of ', num2str(TrialLength), ' ##'])
        disp(['(Target: ',num2str(TrialLength*oddballFractionActive),', Reality: ',num2str(floor(TrialLength*oddballFractionActive)),')'])
    end

    %Matt
    OddballCondON = repmat([1], 1, OddballProb);
    OddballCondOFF = repmat([0], 1, OddballProb);
    CarrierCondON = repmat([1], 1, CarrierProb);
    CarrierCondOFF = repmat([0], 1, CarrierProb);

    CarrierONOFF = vertcat(CarrierCondON, CarrierCondOFF, CarrierCondOFF);
    OddballONOFF = vertcat(OddballCondOFF, OddballCondON, OddballCondON);
    TrialSet = horzcat(CarrierONOFF, OddballONOFF);

    %TrialGroup = repmat([TrialSet], 1, SizeGroups);
    TrialGroup = TrialSet; %Removed repmat as it appeared to be interfering when multiple colour groups used
        
    %TrialGroup = TrialGroup(:,randperm( size(TrialGroup,2) ) ); %Randomise order of carrieronly/oddball trials
    
    ChannelGroups(:,:,2) = TrialGroup;

    %% Make sine or square Wave Stimulus (1 or 2)

    %Fixed sine-only

    if doSine == 1
        StimType = {'sine'};
        SineVector = repmat([1], 1, TrialLength);
        SineGroup = repmat([SineVector], HeightGroups, SizeGroups);
        %StimGroup = horzcat(SineGroup, SineGroup); 
        StimGroup = SineGroup;
    else
        StimType = {'square'};
        SquareVector = repmat([2], 1, TrialLength);
        SquareGroup = repmat([SquareVector], HeightGroups, SizeGroups);
        %StimGroup = horzcat(SineGroup, SineGroup); 
        StimGroup = SquareGroup;
    end

    %% Make TTL Channel

    for RowNum = 1:size(ChannelGroups,1)
        ChannelGroups(RowNum, find(ChannelGroups(RowNum, :,1) ==10), 5) = 1; % Adjust sine wave channel 10;
        ChannelGroups(RowNum, find(ChannelGroups(RowNum, :,1) ==11), 5) = 2; % Adjust sine wave channel 11;
        ChannelGroups(RowNum, find(ChannelGroups(RowNum, :,1) ==12), 5) = 4; % Adjust sine wave channel 12;
    end

    %% Randomize(/Determine order of trials)
    
    if oddballMode ~= 4
        %disp(['Randomising stimulus order'])
        disp(['Determining stimulus order'])
        %%ChannelOrder = ChannelGroups(:,randperm(size(ChannelGroups,2)),:); % shuffle columns in each dimension. %'Old' Matt system
        % ChannelOrder = ChannelGroups; % shuffle columns in each dimension.
        
        %First, collect ChannelGroups
        ChannelOrder = ChannelGroups;
        
        %Next, randomise        
        ChannelOrder = ChannelOrder(:, randperm( size(ChannelOrder,2) ) , :);
            %Caution: The carrieronly/oddball identity layer (2) is not randomised on entry (e.g. "0 0 0 0 1 1" for 75% carrieronly, 25% oddball)
                %Previously this caused large issues, because the colour layer (1) was also not randomised, but with interleaving this is protected
                    %This would manifest in oddballs being matched only ever to the last colour group, i.e.:
                    %   [green , green , green , blue , blue , blue]
                    %   [  0   ,   0   ,   0   ,  0   ,  1   ,   1 ]
                    %will yield 25% oddballs (correct), but they will all be blue oddballs (incorrect)
                
        if numFirsts ~= 0 %"Run only if forcing a set number of the first trials to be of a particular type"
            disp(['(And enforcing ',num2str(numFirsts),' first trials of carrier-type)'])
            carrierType = CarrierFirst; %Sets which condition is the 'carrier' type (carrieronly for 80/20, oddball (using carrier as a proxy) for 20/80) 
            %"IJN Akagi"
            while sum(ChannelOrder(carrierType,1:numFirsts,2)) ~= numFirsts
                %First <numFirsts> trials are carriers
                ChannelOrder = ChannelGroups(:,randperm(size(ChannelGroups,2)),:); % shuffle columns in each dimension.
            end
            %{
            if CarrierFirst == 1
                while sum(ChannelOrder(2,1:numFirsts,2)) ~= 0
                    %First <numFirsts> trials are carriers
                    ChannelOrder = ChannelGroups(:,randperm(size(ChannelGroups,2)),:); % shuffle columns in each dimension.
                end
            elseif CarrierFirst == 2
                while sum(ChannelOrder(2,1:numFirsts,2))~= numFirsts
                    %First <numFirsts> trials are carriers
                    ChannelOrder = ChannelGroups(:,randperm(size(ChannelGroups,2)),:); % shuffle columns in each dimension.
                end
            end
            %}
        end
        disp(['Randomising complete'])
    else
        disp(['Not randomising, on account of paradigm'])
        ChannelOrder = ChannelGroups;
    end
    
    %#####
    %QA for correctness
    %First, define the intended colour groups
    unCols = []; %What unique colour groups exist in the chanGroupList
    for i = 1:size(chanGroupList,2)
        for condInd = 1:size(chanGroupList{i},2)
            unCols(condInd,i) = eval([chanGroupList{i}{condInd}]);
        end
        %Mini QA on chanGroupList
        if size(chanGroupList{i},2) ~= 3
            ['## Alert: chanGroupList element not valid size ##']
            crash = yes
            %This needs to be an error because it currently is not supported
        end
    end
    %Count all groups according to their colour groups
    unColCount = zeros(2,size(unCols,2)); %Count of how many times these colour groups occurred
    for i = 1:size(ChannelOrder,2)
        thisTrialConds = find( ChannelOrder(:,i,2) == 1 ); %For carrieronly this should find row 1, for oddball it should be rows 2 and 3
        derivedTrialType = nanmin( thisTrialConds ); %Use the minimum value to define whether carrieronly (1) or oddball (2)
        for x = 1:size( unCols , 2 )
            if isequal( ChannelOrder( thisTrialConds , i , 1 ) , unCols( thisTrialConds , x ) ) == 1
                unColCount( derivedTrialType , x ) = unColCount( derivedTrialType , x ) + 1;
            end
        end
    end
    %Report
    disp([char(10)])
    for i = 1:2
        if i == 1
            predicCarrieronly = (1-oddballFraction)*TrialLength*size(chanGroupList,2);
            disp(['Predicted carrieronly trials: ',num2str( predicCarrieronly ), ', Real: ',num2str( nansum( ChannelOrder(1,:,2) == 1 ) )])
            for x = 1:size(unCols,2)
                disp([Condition{1},' ',num2str(x),' (',num2str(unCols(1,x)),') - Predicted: ',num2str( predicCarrieronly / size(chanGroupList,2) ), ', Real: ',num2str(unColCount(i,x))])
            end
            %Sub-QA (Disabled for carrieronly because using two green carrieronly groups currently)
            %{
            if abs( unColCount(i,x) - ( predicCarrieronly / size(chanGroupList,2) ) ) > 0.05 * ( predicCarrieronly / size(chanGroupList,2) )
                ['## Caution: Group count deviates from predicted by >5% ##']
                crash = yes
            end
            %}
        else
            predicOddball = (oddballFraction)*TrialLength*size(chanGroupList,2);
            disp(['Predicted oddball trials: ',num2str( predicOddball ), ', Real: ',num2str( nansum( ChannelOrder(2,:,2) == 1 ) )])
            for x = 1:size(unCols,2)
                disp([Condition{3},' ',num2str(x),' (',num2str(transpose([unCols(2:3,x)])),') - Predicted: ',num2str( predicOddball / size(chanGroupList,2) ), ', Real: ',num2str(unColCount(i,x))])
            end
            %Sub-QA
            if abs( unColCount(i,x) - ( predicOddball / size(chanGroupList,2) ) ) > 0.05 * ( predicOddball / size(chanGroupList,2) )
                ['## Caution: Group count deviates from predicted by >5% ##']
                crash = yes
            end
        end
    end
    disp([char(10)])
    %#####
    
    ChannelGroups = []; %Intentionally wiped to reduce confusion

    %ChannelOrder2 = ChannelGroups(:,randperm(size(ChannelGroups,2)),:); % shuffle columns in each dimension.
    %ChannelOrder = horzcat(ChannelOrder, ChannelOrder2); % merge for sine and square stim
    % Replicate Twice so repeated once for sine wave and once for square wave
    ChannelOrder = ChannelOrder;
    ChannelOrder(:,:,4) = StimGroup; % add non random square or sine (Not interleaved)

    % ChannelGroups = repmat([ChannelGroups], 1, length(StimType)); % replicate all of Channel Groups twice so repeated once for sine and once for square

    projRestNum = 2 + (size(CarrierOrder,2)-1) * 1; %Projected number of rests; May not be 100% accurate, but that doesn't really matter
    disp(['-- Projected total number of trials: ',num2str(size(chanGroupList,2) * TrialLength), '(+ ',num2str(projRestNum),' rest trials) --'])
    disp(['-- Estimated time to run all trials for this CarrierSwitch: ', ...
        num2str( ( (size(chanGroupList,2) * TrialLength * stimduration) + (projRestNum * stimduration) + (size(chanGroupList,2) * TrialLength *3) )/60 ), ...
        ' minutes --'])
    if size(CarrierOrder,2) * size(ChannelOrder,2) * ( stimduration + 3) > 3600
        disp(['(Estimated total experiment runtime: ',num2str( (size(CarrierOrder,2) * size(ChannelOrder,2) * ( stimduration + 3)) /60 /60 ),' hours)'])
    end
    disp([char(10),'Colour groupings:'])
    for i = 1:size(chanGroupList,2)
        disp([strcat(chanGroupList{i})])
    end
    
    %% Adjust amplitude based on square or sine wave status

    for Ch = 1:HeightGroups;
        for SquareSineStatus = 1:2;
            ChannelOrder(Ch, find(ChannelOrder(Ch, :,1) ==10 & ChannelOrder(Ch, :,4) == SquareSineStatus), 3) = Ch10(1, SquareSineStatus); % Adjust sine wave channel 10;
            ChannelOrder(Ch, find(ChannelOrder(Ch, :,1) ==11 & ChannelOrder(Ch, :,4) == SquareSineStatus), 3) = Ch11(1, SquareSineStatus); % Adjust sine wave channel 10;
            ChannelOrder(Ch, find(ChannelOrder(Ch, :,1) ==12 & ChannelOrder(Ch, :,4) == SquareSineStatus), 3) = Ch12(1, SquareSineStatus); % Adjust sine wave channel 10;
        end
    end


    %% Amplitude Randomization % Be sure to select the right Amp Vector
        %Disabled currently because not randomising amplitude
    %{
    Amp = 1;
    AmpVector = repmat([Amp],1,TrialLength);
    AmpGroup = repmat([AmpVector], HeightGroups, SizeGroups);

    % Give UV, Blue, or Green different scaling factors for signal amplitude
    %PickChannel = ChannelGroups(:,:,1);

    %%Temp = ChannelGroups; % temp was replacing ChannelGroups at one point

    ChannelGroups(:,:,3) = AmpGroup; % merge channel, condition and amplitude into the same 3-dimensional matrix.
    %}

    %% Add Breaks Between Stimulus Presentation

    %BreakVal = 11; % break val was 2
    BreakVal = TrialLength + 1; % break val was 2

    % Add breaks at regular intervals
    for AddDims = 1:size(ChannelOrder,3)
        ChanBreak(1:size(ChannelOrder,1),size(ChannelOrder,2),AddDims) = 0; %Make a full-layered break 'trial'
    end

    AddBreaks = BreakVal:BreakVal:length(ChannelOrder); %Calculate the indices of where to add breaks
    AddBreaksLength = length(AddBreaks); % add the number of breaks

    count = 0;
    for Breaks = 1:(length(ChannelOrder)+AddBreaksLength)
        if ismember(Breaks,AddBreaks) == 1; % if the break is a value then add a break
            ChanBreak(:,Breaks,:) = 0;
        else
            count = count + 1;
            ChanBreak(:, Breaks,:) = ChannelOrder(:,count,:);
        end
    end
    ChanBreak(:,length(ChanBreak)+1,:) = 0; % make sure to turn everything off at the end
        %Force last trial to be a break
        
    %Add rest trials during expected chunk locations    
    if chunkDatasets == 1
        chunkBreakList = [];
        projectedTotalTime = ((size(ChanBreak,2) * (stimduration + 2) ) / 60);
        for chunkTime = chunkDuration:chunkDuration:projectedTotalTime %Calculate places where chunks will occur
            %Note: If projectedTotalTime less than chunkDuration, no chunks
            %will be generated
            prosChunkLoc = ceil( (chunkTime * 60) / (stimduration + 2) ); 
                %Calculates the next block junction after the chunk time has elapsed
            ChanBreak(:,prosChunkLoc,:) = 0; %Make selected block a rest
            chunkBreakList = [chunkBreakList,prosChunkLoc]; %Keep a list (And check it twice)
            if prosChunkLoc < size(ChanBreak,2)
                ChanBreak(:,prosChunkLoc+1,:) = 0; %Make first block after chunk be rest as well
            end
        end
        if size(chunkBreakList,2) ~= 0
            disp(['-- ',num2str(size(chunkBreakList,2)*2),' blocks were converted to rests for chunking purposes --'])
            disp(['(Chunks will be initiated at block/s ',num2str(chunkBreakList),')'])
        else
            ['-# Warning: Chunking was requested but the projected total time was less than the specified chunk duration #-']
            disp(['-# Chunking has been disabled automatically #-'])
            chunkDatasets = 0;
            runningMemoryClear = 0;
            piecemealTTLstruct = 0;
            ttlHoldFolder = [];
        end
    end
        
    ChannelOrder = ChanBreak;

    %% Add Prior Trial
    %AddPriorTrial = zeros(3,(length(ChannelOrder)),4);

    % AddPriorTrial(:,2:length(AddPriorTrial),4) = 1;
    switch 2

        case 2
            ChannelOrder = [ zeros(size(ChannelOrder,1),1,size(ChannelOrder,3)) , ChannelOrder];
                %Adds a forced rest trial at the start of ChannelOrder

            AddPriorTrial = zeros(3,(length(ChannelOrder)),4);

            %count = 0;
            for LatchOff = 1:(length(ChannelOrder)-2) %Rhiannon
            %for LatchOff = 2:length(ChannelOrder) %Matt
                %count = count + 1;
                % Add one trial ahead to turn off for each trial.
                AddPriorTrial(:,LatchOff+1,1) = ChannelOrder(1:3,LatchOff,1);
                AddPriorTrial(:,LatchOff+1,4) = ChannelOrder(1:3,LatchOff,4);
                AddPriorTrial(:,LatchOff+1,5) = ChannelOrder(1:3,LatchOff,5);
                    %Note: The apparent 'overwriting' of the first trial in
                    %fact is a measure to ensure present-data overwriting to
                    %the TDT so that the previous trial is not displayed

                %{
                %Matt
                AddPriorTrial(:,LatchOff,1) = ChannelOrder(1:3,LatchOff,1);
                AddPriorTrial(:,LatchOff,4) = ChannelOrder(1:3,LatchOff,4);
                AddPriorTrial(:,LatchOff,5) = ChannelOrder(1:3,LatchOff,5);
                    %This version adds an artificial rest at the start of the
                    %protocol and does not reinforce the terminal rest but does
                    %incorporate if it exists already
                %}
            end
            
            if chunkDatasets == 1
                chunkBreakList = chunkBreakList + 1; %Adjust up by one to account for forced prior trial
            end

    end
    % for Check = 1:length(
    ChannelOrder = vertcat(AddPriorTrial, ChannelOrder);
        %Note: This doubles the number of rows of ChannelOrder

    %% Save Order
    % Add rest at end
    ChannelOrder(:,end,5)=ChannelOrder(:,end-1,5); %to offset the break -turn off TTL channel
    ChannelOrder(:,end,1)=ChannelOrder(:,end-1,1); %to offset the break -turn off TTL channel

    Channel = ChannelOrder(:,:,1);
    Gating = ChannelOrder(:,:,2);

    GatingSigOne = ones(3,size(ChannelOrder,2));
    GatingSigZero = zeros(3,size(ChannelOrder,2));

    GatingSig = vertcat(GatingSigZero,GatingSigOne);
    Amplitude = ChannelOrder(:,:,3);
    Stimulus = ChannelOrder(:,:,4);

    TTL = ChannelOrder(:,:,5);

    %% ttlStruct
    oddballLOCS = find(Gating(5,:) == 1); %Positions of oddball blocks within Gating
    %Save ttlStruct to file and remove it from RAM if requested
    if piecemealTTLstruct == 1
        %Clear existing ttlStruct files
        oldTTLstructFiles = dir([ttlHoldFolder,filesep,'*ttlStruct.mat']);
        disp(['-- ',num2str(size(oldTTLstructFiles,1)),' old ttlStruct piecemeal files found; Deleting... --'])
        for i = 1:size(oldTTLstructFiles,1)
            delete([ttlHoldFolder,filesep,oldTTLstructFiles(i).name])
        end
        
        disp(['-- Piecemeal TTL active; Saving ttlStruct to file and clearing --'])
        tic
        %Prepare saveTTLstruct with the correct fields
        %saveTTLstruct = struct; %"Chunks as fields"
        ttlFiels = fieldnames(ttlStruct);
        rollOddball = 1; %Rolling modifier to keep oddballCount correct
        for i = 1:size(chunkBreakList,2)
            saveTTLstruct = struct; %"Chunks as whole structure"
            
            %thisChunkName = strcat('chunk_',num2str(i)); %Not aligned with blockNum correctly
            thisChunkName = strcat('chunk_',num2str(i-1+blockNum)); %Aligned
            
            for fiel = 1:size(ttlFiels,1)
                %saveTTLstruct.(thisFieldName).(ttlFiels{fiel}) = []; %"Chunks are fields within saveTTLStruct"
                saveTTLstruct.ttlStruct.(ttlFiels{fiel}) = []; %"Chunks are individual instances of saveTTLStruct"
            end
            
            %Calculate bounds of chunk
            if i > 1
                chunkBounds = [chunkBreakList(i-1)+1:chunkBreakList(i)]; %Will probs fail horribly if chunks occuring every block but w/e
                %oddballBounds = [rollOddball:rollOddball+nansum(Gating(5,chunkBounds))-1]; %Which oddball blocks will be sent in this chunk
            else
                chunkBounds = [1:chunkBreakList(i)];
                %oddballBounds = [1:nansum(Gating(5,chunkBounds))]; %Which oddball blocks will be sent in this chunk
            end
            oddballBounds = intersect(chunkBounds,oddballLOCS); %The Gating location of the oddball blocks that will occur in the trials of this chunk
            
            
            oddballInds = [];
            for j = 1:size(oddballBounds,2)
                oddballInds = [oddballInds, find(oddballLOCS == oddballBounds(j))]; %The ttlStruct indices of these oddball blocks
            end
                %There is probably a better way of doing this

            if isempty(oddballBounds) ~= 1
                %saveTTLstruct.(thisFieldName)(1:size(oddballBounds,2)) = ttlStruct(oddballBounds);
                saveTTLstruct.ttlStruct(1:size(oddballInds,2)) = ttlStruct(oddballInds);
                for k = 1:size(oddballInds,2)
                    saveTTLstruct.ttlStruct(k).idealisedBlockToBeSentIn = i + blockNum - 1; %See above
                end
                %rollOddball = nansum( Gating(5, 1:nanmax(chunkBounds) ) )+1;
                rollOddball = nanmax(oddballInds) + 1;
            else
                saveTTLstruct.ttlStruct.(thisChunkName) = [];
            end
            saveTTLstruct.Chunk.chunkBounds = chunkBounds;
            saveTTLstruct.Chunk.oddballBounds = oddballBounds;
            saveTTLstruct.Chunk.oddballInds = oddballInds;
            save([ttlHoldFolder,filesep,thisChunkName,'_ttlStruct.mat'],['saveTTLstruct'], '-v7.3'); %Chunks as whole struct
            clear saveTTLstruct %Just in case
            
            %Clear the big memory elements from ttlStruct but not the whole thing
                %This allows for checks to be done between soon to be loaded
                %piecemeal chunks and what data remains in ttlStruct
            for m = oddballInds
                ttlStruct(m).carrieronlyTTL = [];
                ttlStruct(m).carrierTTL = [];
                ttlStruct(m).combinedTTL = [];
                ttlStruct(m).oddballTTL = [];
                ttlStruct(m).carrieronlysine = [];
                ttlStruct(m).carrieronlysquare = [];
            end
            
            %Append the idealisedBlockNum to ttlStruct
            for m = oddballInds
                ttlStruct(m).idealisedBlockToBeSentIn = i + blockNum - 1;
            end
            
        end
        
        if rollOddball <= size(ttlStruct,2) %This will always be the case unless no oddballs occur between last chunk and end of experiment

            for fiel = 1:size(ttlFiels,1)
                saveTTLstruct.ttlStruct.(ttlFiels{fiel}) = [];
            end
            
            %thisChunkName = strcat('chunk_',num2str(i+1)); %Uses iterator from previous loop
            thisChunkName = strcat('chunk_',num2str(i-1+blockNum+1));
            
            chunkBounds = [chunkBreakList(end):size(Gating,2)];
            
            oddballBounds = intersect(chunkBounds,oddballLOCS);
            oddballInds = [];
            for j = 1:size(oddballBounds,2)
                oddballInds = [oddballInds, find(oddballLOCS == oddballBounds(j))]; %The ttlStruct indices of these oddball blocks
            end
            
            %###
            %Repeated from above
            if isempty(oddballBounds) ~= 1
                saveTTLstruct.ttlStruct(1:size(oddballInds,2)) = ttlStruct(oddballInds);
                for k = 1:size(oddballInds,2)
                    saveTTLstruct.ttlStruct(k).idealisedBlockToBeSentIn = i + blockNum - 1 + 1; %See above
                        %Terminal +1 here because of last chunk nature
                end
                rollOddball = nanmax(oddballInds) + 1;
            else
                saveTTLstruct.ttlStruct.(thisChunkName) = [];
            end
            saveTTLstruct.Chunk.chunkBounds = chunkBounds;
            saveTTLstruct.Chunk.oddballBounds = oddballBounds;
            saveTTLstruct.Chunk.oddballInds = oddballInds;
            save([ttlHoldFolder,filesep,thisChunkName,'_ttlStruct.mat'],['saveTTLstruct'], '-v7.3'); %Chunks as whole struct
            clear saveTTLstruct %Just in case
            for m = oddballInds
                ttlStruct(m).carrieronlyTTL = [];
                ttlStruct(m).carrierTTL = [];
                ttlStruct(m).combinedTTL = [];
                ttlStruct(m).oddballTTL = [];
                ttlStruct(m).carrieronlysine = [];
                ttlStruct(m).carrieronlysquare = [];
            end
            %Append the idealisedBlockNum to ttlStruct
            for m = oddballInds
                ttlStruct(m).idealisedBlockToBeSentIn = i + blockNum - 1 + 1;
            end
            %###
        end

        %%save([ttlHoldFolder,filesep,'ttlStruct.mat'],['saveTTLstruct']); %Chunks as fields

        disp(['-- Piecemeal ttlStructs saved in ',num2str(toc),'s --'])
        

        %Clear the big memory elements from ttlStruct but not the whole thing
            %This allows for checks to be done between soon to be loaded
            %piecemeal chunks and what data remains in ttlStruct
                %Since this has already been done above it's probably
                %unnecessary to do it here, but it can't really hurt
                %(probably)
        for i = 1:size(ttlStruct,2)
            ttlStruct(i).carrieronlyTTL = [];
            ttlStruct(i).carrierTTL = [];
            ttlStruct(i).combinedTTL = [];
            ttlStruct(i).oddballTTL = [];
            ttlStruct(i).carrieronlysine = [];
            ttlStruct(i).carrieronlysquare = [];
        end

        
    end

    %%
    %**********************************************************************
    failsafeEngagedCount = 0;
    failsafeEngagedTimes = [];
    proceed = 0; 
    while proceed == 0
        if debugMode ~= 1
            temp = input([char(10),'Press enter key when ready to proceed (and system is in ',tdtModeIndex{runMode+1},' mode)...']);
        else
            disp(['Proceeding automatically in accordance with debug mode'])
        end

        if socky == 1
            
            %PLACE RECONNECTION CYCLING HERE
            
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
            switch systemMode
                case 0
                    dispStr='Idle';
                    %error 'Cannot continue, sys is in Idle mode';
                    ['#- Alert: System is in Idle mode -#']
                    proceed = 0;
                case 1
                    dispStr='Standby';
                    error 'Cannot continue, sys is in Standby mode';
                    ['#- Alert: System is in Standby mode -#']
                    proceed = 0;
                case 2
                    dispStr='Preview';
                    %%error 'Should not continue; Sys is in Preview mode';
                    ['#- Alert: System is in Preview mode -#']
                    proceed = 1;
                case 3
                    dispStr='Record';
                    proceed = 1;
            end
            if proceed == 0
                enGage = input(['Mode not apparently correct; Do you wish to engage failsafe to correct this? (0/1)']);
                if enGage == 1
                    [success,systemMode] = TDTFailsafeFunction(3);
                    %failsafeEngagedCount = failsafeEngagedCount + 1; %This
                    %doesn't really count, since it's almost normal
                    clear DA;
                    DA = actxcontrol('TDevAcc.X');
                    DA.ConnectServer('Local');
                        %These two lines seem necessary on account of the
                        %function changing the DA handle
                    if success == 1 && systemMode == 3
                        disp(['-- Failsafe successful in setting system to Record --'])
                        proceed = 1;
                    else
                        disp(['## Failsafe unsuccessful ##'])
                    end
                    %************
                    %Reconnect to server
                    disp(['-# Reconnecting to server after failsafe #-'])
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
                        ['## Could not reconnect to server after failsafe ##']
                        crash = yes
                    else
                        disp(['-# System sucessfully reconnected #-',char(10)])
                    end
                    %************
                else
                    ['#- Looping on account of system being in incorrect mode -#']
                end
            end
        else
            dispStr = ['UNSOCKETED'];
            proceed = 1;
        end
    end

    disp(['System is currently in ' dispStr ' mode'])

    %Check tank name
    if socky == 1
        pullTankName = DA.GetTankName();
        if isempty(strfind(pullTankName, 'Calib')) ~= 1 %Check for potentially aberrantly sending data to calib tank
            ['## Alert: Tank name indicates calib status ##']
            if overrideErrors ~= 1
                crash = yes
            end
        end
        pullCurrentDate = datestr(now, 'ddmmyy');
        if isempty(strfind(pullTankName, pullCurrentDate)) == 1 %Check tank name against current date
            ['## Alert: Tank name potentially not matching current date ##']
            if overrideErrors ~= 1
                crash = yes
            end
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
    end
    
    %try
    if socky == 1
        if systemMode ~= 0 && systemMode ~= 1
            tempfs = DA.GetDeviceSF('Amp1'); % Sampling Frequency % tucker davis says 95.4 kilobytes a second for float output
            % If the TDT equipment is not turned on, line 151 will return fs =
            % 0
            if tempfs == 0
                fs = defaultFS;
            end
            if floor(tempfs) ~= floor(fs)
                ['## Alert: TDT fs does not match fs used to assemble stimuli ##']
                crash = yes
            end
        end
    else
        fs = defaultFS;
    end
    %catch
    %    fs = defaultFS;
    %    disp(['## Could not pull fs from TDT ##'])
    %end
    disp(['fs: ',num2str(fs)])
    %**********************************************************************
    
    disp(['Wait for ',num2str(WaitMinutes),' minutes!']);

    if socky == 2
        ['## Reminder: System in unsocketed mode ##']
    end

    %Minute = 60;
    pause(60.0*WaitMinutes);

    switch AirPuff
        case 1
            disp('AIR PUFF!');
            % toc
            for i=1:3

                channel = 1:4; % could be 1:4
                duration = 500; %time to present odour in milliseconds

                % tic
                % toc
                Olf_SerialID = olfactory_init_serial;  % initiate the serial communications link to the Olfactory System....
                es = olfactory_init_new_sequence(Olf_SerialID);   % initiate new odour sequence on the Olfactory system
                es = olfactory_send_sequence_event(Olf_SerialID,channel,duration,0); % send odour information
                if i == 1;
                    DA.SetTargetVal(['Amp1.STIM'],1);
                    DA.SetTargetVal(['Amp1.STIM'],0);
                end
                es = olfactory_start_sequence(Olf_SerialID); % start the odour sequence, start/release smell for the trial
                if i == 3;
                    %     pause(0.5)
                    DA.SetTargetVal(['Amp1.STIM'],1);
                    DA.SetTargetVal(['Amp1.STIM'],0);
                end
                errorstatus = olfactory_close_serial(Olf_SerialID); % close down the Olfactory System serial link

            end
            disp(['...']);
            disp(['..']);
            disp(['.']);
            disp('Wait 30 seconds!');

        case 0
            disp('No Airpuff')
    end
    disp(['-- Waiting for hardcoded ',num2str(hardcodedWaitMinutes*60),'s --'])
    pause(hardcodedWaitMinutes*60); % Wait 30 seconds before starting stimulus for baseline recording/correction
    disp('-----------------------------------------------------------------');
    disp('--- Experiment is start ---');
    if socky == 2
        disp('(Running in unsocketed mode; Timings simulated)')
    end

    switch CarrierFirst
        case 1
            disp(['Carrier trials will have ',num2str((1-oddballFraction)*100),...
                '% probability first, followed by oddballs at ',num2str(oddballFraction*100),'%.'])
        case 2
            disp(['Oddball trials will have ',num2str((1-oddballFraction)*100),...
                '% probability first, followed by carriers at ',num2str(oddballFraction*100),'%.'])
    end
    
    %% Exp start
    expStart = tic;
    expStartTime = clock;
    trialnumval = length(Channel);
    count = 1;
    reloadCount = 1;

    trial_number = 0;
    trial_number = trial_number + 1;
    
    if redLight == 1 && socky == 1
        lastRedTime = clock;
        %redTrigger = 1; %Start on
        redIt = 1; %"#upvote"
        redTrigger = redStatus(redIt); %Set light to first element of redStatus
    end

    %If chunking
    if chunkDatasets == 1
        thisChunkStartTime = clock; %Pretty self-explanatory
        thisChunkStartTrial = trial_number; %Keeps track of the block range for this chunk
        %Load first piece of ttlStruct
        if piecemealTTLstruct == 1
            %preLoad =
            %load([ttlHoldFolder,filesep,'chunk_',num2str(blockNum),'_ttlStruct.mat']); %Old
            preLoad = load([ttlHoldFolder,filesep,'chunk_',num2str(idealisedBlockNum),'_ttlStruct.mat']); %New, uses idealisedBlockNum for sync purposes
            %ttlStruct = load([ttlHoldFolder,filesep,'ttlStruct.mat']);
            pieceList = preLoad.saveTTLstruct.Chunk.oddballInds; %Which ttlStruct elements this piecemeal chunk holds data for
            for pea = 1:size(pieceList,2)
                %Preliminary QA
                if preLoad.saveTTLstruct.ttlStruct(pea).order ~= ttlStruct(pieceList(pea)).order
                    ['## Alert: Fatal error in synchronisation between piecemeal and ttlStruct ##']
                    crash = yes
                else
                    ttlFiels = fieldnames(preLoad.saveTTLstruct.ttlStruct);
                    for fiel = 1:size(ttlFiels,1)
                        ttlStruct(pieceList(pea)).(ttlFiels{fiel}) =  preLoad.saveTTLstruct.ttlStruct(pea).(ttlFiels{fiel}); %"Chunks are individual instances of saveTTLStruct"
                    end
                        %Note: This overwrites ttlStruct.order, so the above QA is
                        %the only chance to catch errors with it
                end
            end
            disp(['(ttlStruct values loaded for ',num2str(size(pieceList,2)),' elements from piecemeal)'])
        end
    %chunkDatasets end
    end

    oddballCount = 1; %Iterator for ttlStruct purposes
    sentStimuliStruct = struct; %Structure for holding the stimuli that were sent

    Stims = [carrieronlysine; carrieronlysquare];

    %TTLvector(:,:) = [carrieronlyTTL; carrierTTL; oddballTTL]; 
        %For situations of dynamic TTL, this old code will in fact use the last-generated 
        %TTL as the first TTL
    TTLvector = [];
    %TTLvector(:,:) = [ttlStruct(oddballCount).carrieronlyTTL;...
    %    ttlStruct(oddballCount).carrierTTL;...
    %    ttlStruct(oddballCount).oddballTTL];
    %Dynamically determine first TTL, rather than sending first existing oddball TTL
    if Gating(4,trial_number) == 1
        TTLvector = carrierOnlyTTLVector;
    elseif Gating(5,trial_number) == 1
        %TTLvector(:,:) = [ttlStruct(oddballCount).carrieronlyTTL;...
        %    ttlStruct(oddballCount).carrierTTL;...
        %    ttlStruct(oddballCount).oddballTTL];
        TTLvector = ttlStruct(oddballCount).combinedTTL; %The previous lines have effectively just been shifted to earlier in the code
    else
        TTLvector = restTTLVector;
    end
    %%sameAsLast = zeros(size(TTLvector,1),1); %Will be used to identify if new TTL vector rows are the same as what was sent last
        %If this works, it will reduce block-start load on the TDT by ~33% - 66%

    reloadRemainingTrials = []; %List of reported remainingTrials values (mainly for debugging)

    %h = figure('Visible', 'off', 'HandleVisibility', 'off');

    if socky == 1
        DA.SetTargetVal(['Amp1.trialnumval'], trialnumval);
        % Load sine wave stimuli into buffer

        if Stimulus(4,1) ~= 0 %"First trial is not rest"
            DA.WriteTargetVEX(['Amp1.stim'], 0, 'F32', single(Stims(Stimulus(4), :)));
        end

        for TTLcycle = 1:size(TTLvector,1) %No intelligent sending here, since this is first instance
            DA.WriteTargetVEX(['Amp1.' Condition{TTLcycle,1} 'TTL'], 0, 'F32', single(TTLvector(TTLcycle,:)));
        end

        DA.SetTargetVal('Amp1.duration', stimulusduration);
        DA.SetTargetVal('Amp1.trialDuration', trialDuration); %New as of 9.75

        for ParseChannel = 1:size(Condition,1);
            DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], Amplitude(ParseChannel,1));
            DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], GatingSig(ParseChannel,1));
        end
        %now start protocol
        for ParseChannel = 1:size(Condition,1);
            DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
            DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
        end

        currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);
        % sleep(0.2);
        DA.SetTargetVal('Amp1.trigger', 0); % turn off the trigger afterwards


        if currentStatReset == 0
            for ParseChannel = 1:size(Condition,1);
                currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], Amplitude(ParseChannel,1));
                currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], GatingSig(ParseChannel,1));
            end
            %now start protocol
            for ParseChannel = 1:size(Condition,1);

                currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
            end

            currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);

        else
            for ParseChannel = 1:size(Condition,1);
                currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], 0);
                currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], 0);
            end
            %now start protocol
            for ParseChannel = 1:size(Condition,1);
                currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], 0);
                currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], 0);
            end

            currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 0);

            %now start protocol
            for ParseChannel = 1:size(Condition,1);
                currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], Amplitude(ParseChannel,1));
                currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], GatingSig(ParseChannel,1));
            end

            for ParseChannel = 1:size(Condition,1);
                DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
            end

            currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);
            
            %Red light initialisation
            if redLight == 1 && socky == 1
                disp(['Initialising red light'])
                DA.SetTargetVal('Amp1.redDuration', redDurations(redIt)); %Fixed to use fs-multiplied version
                setSucc = [];
                if redMode == 1
                    setSucc = [setSucc,DA.WriteTargetVEX(['Amp1.redStim'], 0, 'F32', single([redSquare]))];
                elseif redMode == 2
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redHi', redHi)];
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redLo', redLo)];
                    setSucc = [setSucc,DA.SetTargetVal('Amp1.redPulseNum', redPulseNum(redIt))];
                end
                %QA
                if nansum(setSucc) ~= size(setSucc,2)
                    ['## Warning: Not all red parameters detected to have been successfully sent ##']
                    crash = yes
                end
                redLightReset=DA.SetTargetVal(['Amp1.carrieronlyRed'], redTrigger);
                disp(['Red light status set to ',num2str(redTrigger),...
                    ' w/ success state: ',num2str(redLightReset),' (Mode:',num2str(redMode),')'])
                initTime = clock;
            end
        end

        remainingTrials=DA.GetTargetVal(['Amp1.remainingTrialstrigger']); %Borrowed from later on for completness' sake
        reloadRemainingTrials(reloadCount) = remainingTrials;

    elseif socky == 2
        remainingTrials = trialnumval; %Set up for TDT-free operation later
        reloadRemainingTrials(reloadCount) = remainingTrials; %Very similar to CheckRemainingTrials, but only fills on reload
    end
    %count = count + 1;

    %Report identity of first trial
    %%trial_number = trialnumval-trialnumval+1;
    %{
    if nansum(Gating(4:6,trial_number)) ~= 0
        disp(Condition{nanmax(find(Gating(4:6,trial_number) == 1)),1})
    else
        disp('Rest.')
    end
    %}
    %Reversion to more explicit method for better use with oddballType
    if Gating(4,trial_number) == 1
        disp([num2str(Condition{1,1})]); %"carrieronly"
        oddballType = 0; %'Null' value for later use with analysis
        cycIdentToSend = carrieronlyCycleIdent;
        %TTLvector = carrierOnlyTTLVector; %Disabled here because defined now above
    elseif Gating(5,trial_number) == 1
        disp([num2str(Condition{3,1})]); %"oddball"
        oddballType = ttlStruct(oddballCount).oddballType;
        cycIdentToSend = ttlStruct(oddballCount).cycleIdent;
        oddballCount = oddballCount + 1;
    else
        disp('Rest.'); 
        oddballType = -1; %'Null' value for later use with analysis
        cycIdentToSend = [];
        %TTLvector = restTTLVector; %Disabled here because defined now above
    end
    thisBlockStartTime = clock;

    %Append trial information to sentStimuli
    sentStimuli(trial_number).Condition = Condition{nanmax(find(Gating(4:6,trial_number) == 1)),1};
        %Finds the last instance of a true in Gating and pulls that Condition
    sentStimuli(trial_number).oddballType = oddballType;
    sentStimuli(trial_number).TTLvector = TTLvector; %Note: Memory heavy
    sentStimuli(trial_number).trialSendDatestr = datestr(now, 'yyyy dd/mm HH:MM:SS:FFF');
    sentStimuli(trial_number).trialSendDatenum = datenum(now); %Note: This appears to be some proprietary MATLAB format

    if Stimulus(4,1) ~= 0
        sentStimuli(trial_number).Stims = Stims(Stimulus(4,trial_number), :);
    else
        sentStimuli(trial_number).Stims = [];
    end
    sentStimuli(trial_number).cycleIdent = cycIdentToSend;
    sentStimuli(trial_number).sentTDTCrash = 0; %Will be overwritten if this changes

    %disp(['Experiment start!']);
    disp('First value passed.');

    CheckRemainingTrials = zeros(trialnumval*100,1,1,1,1);
    CheckRemainingTrials(1:2) = trialnumval;
    % count2 = 0;
    %count = 2; %Now defined up above initial data send

    reloadJustHappened = 0;
    
    maxApproxElapsedBlocks = 0; %Will be used to calculate if non-linearities occurring

    isFinished=false;
    if socky == 1
        tic
    end
        
    thisTime = clock;
    
    while(~isFinished)
        currentTime = clock;
        count = count + 1; %In socketed, this iterates every ~0.3s, in unsocketed it is every ~20s
        if socky == 1
            remainingTrials=DA.GetTargetVal(['Amp1.remainingTrialstrigger']); %Occurs every ~0.3s
            %disp(['RemainingTrials:',num2str(remainingTrials)])
            %CheckRemainingTrials(count) = DA.GetTargetVal(['Amp1.remainingTrialstrigger']);
            CheckRemainingTrials(count) = remainingTrials; 
                %Note: It appears like sometimes two consecutive requests to
                %DA.GetTargetVal will return two different values...
        else
            if toc > stimduration %Occurs after as much time as trial would actually have taken to run            
                remainingTrials = remainingTrials - 1;%Spoof DA value
                tic;
                if remainingTrials == 0
                    isFinished = true;
                    break %Necessary because otherwise remainder of loop is executed (and script crashes)
                end
            end
            CheckRemainingTrials(count) = remainingTrials;
        end
        %{
        %(Debugging)
        if reloadJustHappened == 1
            disp(['Stage 4 CheckRemainingTrials: ',num2str(CheckRemainingTrials(count))])
            reloadJustHappened = 0;
        end
        %}
        trial_number = trialnumval-remainingTrials+1;
        
        %Red light check and update
        thisTime = clock;
        if redLight == 1 && socky == 1
            %Red control
            if etime(thisTime,lastRedTime) > redDur( redTrigger+1 ) %Uses the trigger as index to cycle between 1 and 2 (On and off)
                %QA for redMode 2
                if redMode == 2
                    temp = [];
                    temp = [temp,DA.GetTargetVal(['Amp1.redStage'])];
                    temp = [temp,DA.GetTargetVal(['Amp1.redIdx'])];
                    disp(['-R- Redload. (Stage: ',num2str(temp(1)),', Idx: ',num2str(temp(2)),') -R-'])
                    if temp(1) ~= 0 && temp(2) ~= redPulseNum(redIt)
                        disp(['-# Caution: Non-zero (',num2str(temp(2)),') number of red pulses unsent (',num2str(redPulseNum(redIt)),' expected) before start of next red phase #-'])
                            %Note: No idea how this will work/proc with low-states
                    end
                end
                redLightReset = DA.SetTargetVal(['Amp1.carrieronlyRed'], 0); %Force a (potentially brief) down state
                    %This allows for consecutive high states, not that would be a useful thing to do in the first place
                %redTrigger = ~redTrigger;
                redIt = redIt + 1;
                if redIt > size(redStatus,2)
                    redIt = 1;
                end
                redTrigger = redStatus(redIt);
                
                %Old
                %{
                DA.SetTargetVal('Amp1.redDuration', redDuration(redIt)); %Send duration each time
                redLightReset=DA.SetTargetVal(['Amp1.redTrigger'], redTrigger);
                %disp([char(10),'** Red light status set success state: ',num2str(redLightReset),' **'])
                temp=DA.GetTargetVal(['Amp1.redTriggerConstL']);
                temp2=DA.GetTargetVal(['Amp1.redSerIndx']);
                disp(['** Red phase ',num2str(redIt),', trigger MATLAB: ',num2str(redTrigger),', set success: ',num2str(redLightReset),', TDT: ',num2str(temp), ' (Idx: ',num2str(temp2),') **'])
                %disp([char(10)])
                %}
                %New
                DA.SetTargetVal('Amp1.redDuration', redDurations(redIt)); %Fixed to use fs-multiplied version
                %DA.WriteTargetVEX(['Amp1.redStim'], 0, 'F32', single([redSquare])); %May be unnecessary to send in Off trials
                if redMode == 2
                    DA.SetTargetVal('Amp1.redPulseNum', redPulseNum(redIt));
                end
                redLightReset = DA.SetTargetVal(['Amp1.carrieronlyRed'], redTrigger);
                    %Note that this value must go from low to high for red light to be triggered
                        %i.e. If the value goes from high to high then it will probably stop on account of stim length
                disp(['-R- Red phase ',num2str(redIt),', trigger MATLAB: ',num2str(redTrigger),...
                    ', set success: ',num2str(redLightReset),'(',num2str(etime(thisTime,lastRedTime)),'s since last phase) -R-'])
                initTime = clock;
                lastRedTime = thisTime;
            end
        end

        %disp(remainingTrials)
        if remainingTrials~=trialnumval %Note: This is true for every trial except the first
            
            if CheckRemainingTrials(count)-CheckRemainingTrials(count-1) == -1
                %disp(['###############################################'])
                %disp(['Stage 1 CheckRemainingTrials: ',num2str(CheckRemainingTrials(count))])
                thisBlockEndTime = clock;
                disp(['Block elapsed time: ',num2str(etime(thisBlockEndTime,thisBlockStartTime)),'s'])
                %disp(['Stage 2 CheckRemainingTrials: ',num2str(CheckRemainingTrials(count))])
                disp(['----------------------------------------'])
                disp('Reload.');
                ignoreDuration = 0;
                %reloadJustHappened = 1;
                %SetTargetVals new position
                if socky == 1
                    for ParseChannel = 1:size(Condition,1)
                        DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                        DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                    end

                    for ParseChannel = 1:size(Condition,1)
                        DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number));
                        DA.SetTargetVal(['Amp1.stimON' num2str(Channel (ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number));
                    end
                    %TDT descriptive info
                    if fullDescriptiveTDT == 1
                        connectionStat=DA.CheckServerConnection();
                        systemMode=DA.GetSysMode();
                        disp(['(TDT connection: ',num2str(connectionStat),', current mode:',num2str(systemMode),')'])
                        %instrfind; %Based on ignored code in old versions of this script and others
                        if connectionStat == 0 || ( systemMode ~= runMode && systemMode ~= 1 ) 
                            disp(['#- Potential connection loss detected; Attempting to close and reopen connection -#'])
                            DA.CloseConnection()
                            pause(1)
                            clear DA
                            DA = actxcontrol('TDevAcc.X');
                            succeed = 0;
                            while succeed == 0
                                succeed=DA.ConnectServer('Local');
                                disp(['#- ConnectServer state report: ',num2str(succeed),' -#'])
                                pause(1)
                            end
                        end
                    end
                    
                end

                for StimCycle = 1:size(Stims,1) %Sine wave vs Square wave
                    %Stimulus reload
                    if Stimulus(4,trial_number) ~= 0 && socky == 1 %Stimulus(4,trialnumval-remainingTrials+1) ~= 0
                        DA.WriteTargetVEX(['Amp1.stim'], 0, 'F32', single(Stims(Stimulus(4,trial_number), :)));
                    end
                end

                reloadCount = reloadCount + 1;
                %lastTTLvector = TTLvector; %Unused currently
                %sameAsLast = zeros(size(TTLvector,1),1); %Old position, can cause issues if TTLvector is null for whatever reason
                if Gating(4,trial_number) == 1
                    disp([num2str(Condition{1,1})]); %"carrieronly"
                    oddballType = 0; %'Null' value for later use with analysis
                    cycIdentToSend = carrieronlyCycleIdent;
                    TTLvector = carrierOnlyTTLVector;
                    sameAsLast = zeros(size(TTLvector,1),1);
                    sameAsLast(2:3,1) = 1; %Non-dynamic force upload of carrieronly TTL but not carrier / oddball TTL 
                elseif Gating(5,trial_number) == 1
                    disp([num2str(Condition{3,1})]); %"oddball"
                    oddballType = NaN; %Should be overwritten further down...
                    cycIdentToSend = ttlStruct(oddballCount).cycleIdent;
                    TTLvector = ttlStruct(oddballCount).combinedTTL;
                    sameAsLast = zeros(size(TTLvector,1),1);
                    sameAsLast(1,1) = 1;
                    ttlStruct(oddballCount).hasBeenSent = 1; %"Oddball block sent"
                    ttlStruct(oddballCount).blockSentIn = blockNum; %What TDT block/chunk this oddball was sent in
                else
                    disp('Rest.'); 
                    oddballType = -1; %'Null' value for later use with analysis
                    cycIdentToSend = [];
                    TTLvector = restTTLVector;
                    sameAsLast = zeros(size(TTLvector,1),1);
                    if chunkDatasets == 1
                        if ismember(trial_number,chunkBreakList) ~= 0
                            disp(['(Because chunking)'])
                        elseif ismember(trial_number-1,chunkBreakList) ~= 0
                            disp(['(Because post chunking)'])
                        end
                    end
                end
                %QA for TTLvector emptiness
                if isempty(TTLvector) == 1
                    ['## Alert: TTLvector empty ##']
                    crash = yes %May be overkill in certain cases?
                end
                %Even newer location of WriteTargetVex
                if socky == 1
                    tic
                    for TTLcycle = 1:size(TTLvector,1)
                        if sameAsLast(TTLcycle,1) ~= 1 || saveTTLLoad ~= 1 %"This row of TTL needs sending, as it is different OR force always send all rows"
                            DA.WriteTargetVEX(['Amp1.' Condition{TTLcycle,1} 'TTL'], 0, 'F32', single(TTLvector(TTLcycle,:)));
                        end %Note: Introduction of this may cause unexpected behaviour
                    end
                    if saveTTLLoad == 1
                        disp(['(',num2str(size(sameAsLast,1)-nansum(sameAsLast)),' detected-new TTL row/s sent in ',num2str(toc),'s)'])
                    else
                        disp(['(',num2str(size(TTLvector,1)),' TTL row/s force-sent in ',num2str(toc),'s)'])
                    end
                end
                
                %{
                %Quick determination as to which (if any) rows of the TTL vector have changed
                %NOTE: May have been causing carrieronly failures
                sameAsLast = zeros(size(TTLvector,1),1);
                for tRow = 1:size(TTLvector,1)
                    if nansum( TTLvector(tRow,:) == lastTTLvector(tRow,:) ) == size(TTLvector,2) %Will crash if sizes different for some reason
                        sameAsLast(tRow,1) = 1; %"New TTLvector at row tRow is same as old TTLvector at tRow"
                    end
                end
                %}
                %disp(['TTLvector rows differing: ',num2str(size(sameAsLast,1)-nansum(sameAsLast))])
                disp(['Remaining trials: ', num2str(remainingTrials), ' (',num2str(trial_number),' elapsed)'])
                printTime = clock;
                disp(['(Total elapsed time: ',num2str(etime(printTime,expStartTime)/60),' min)'])
                reloadRemainingTrials(reloadCount) = remainingTrials;
                %QA for order non-linearity
                if reloadRemainingTrials(reloadCount-1) == reloadRemainingTrials(reloadCount) ||...
                        abs( reloadRemainingTrials(reloadCount) - reloadRemainingTrials(reloadCount-1) ) > 1
                    %"If reported trial number is same following reload or a trial seems to have been skipped"
                    ['## Warning: Trial non-linearity detected (',...
                        num2str(reloadRemainingTrials(reloadCount-1)),'->',num2str(reloadRemainingTrials(reloadCount)),') ##']
                    %youCanNotContinue = yes
                    if failsafeEngagedCount < 1
                        youCanNotContinue = yes
                    end
                end
                %Backup QA for non-linearity (Only do during socketed operation)
                if socky == 1
                    temp = CheckRemainingTrials;
                    temp(temp == 0) = NaN;
                    tempDiff = abs(diff(temp));
                    maxDiff = nanmax(tempDiff);
                    approxElapsedBlocks = ( etime(thisBlockEndTime,thisBlockStartTime) ) / stimduration;
                    if approxElapsedBlocks > maxApproxElapsedBlocks
                        maxApproxElapsedBlocks = approxElapsedBlocks;
                    end
                    if maxDiff > maxApproxElapsedBlocks*2
                            %This is designed to be lenient in the case of
                            %failsafe operation causing a non-zero number of
                            %blocks to be lost
                        ['## Alert: Apparent non-linearity detected in CheckRemainingTrials ##']
                        crash = yes
                        failTime = clock
                    end
                end
                %disp(['Elapsed time: ',num2str(toc), 's'])
                %TTL reload
                if Gating(5,trial_number) == 1 %Gating(3,trial_number) == 1 || Gating(6,trial_number) == 1 %Hardcoded oddball position in Condition
                        %Modified if statement to use same Gating row as previous
                    %QA before launching into TTL pull
                    if oddballCount > size(ttlStruct,2)
                        ['## ALERT: ATTEMPTED TO PULL MORE TTL VALUES FOR ODDBALL THAN EXIST ##']
                        youCanNotContinue = yes
                    end
                    oddballType = ttlStruct(oddballCount).oddballType;
                    %Old position for TTLvector work
                    %{
                    TTLvector = [];
                    TTLvector(:,:) = [ttlStruct(oddballCount).carrieronlyTTL;...
                        ttlStruct(oddballCount).carrierTTL;...
                        ttlStruct(oddballCount).oddballTTL];
                    %}
                    if oddballCount == 1 || ( oddballCount > 1 && nansum(sameAsLast) ~= size(sameAsLast,1) )%( oddballCount > 1 && nansum(TTLvector(3,:) == ttlStruct(oddballCount-1).oddballTTL) ~= size(TTLvector,2) )
                        disp(['Oddball TTL changed (Count: ', num2str(oddballCount),', Type: ',num2str(oddballType),')'])
                        %Old position of WriteTargetVex
                        %{
                        if socky == 1
                            tic
                            for TTLcycle = 1:size(TTLvector,1)
                                if sameAsLast(TTLcycle,1) ~= 1 %"This row of TTL needs sending, as it is different"
                                    DA.WriteTargetVEX(['Amp1.' Condition{TTLcycle,1} 'TTL'], 0, 'F32', single(TTLvector(TTLcycle,:)));
                                end %Note: Introduction of this may cause unexpected behaviour
                            end
                            disp(['(',num2str(size(sameAsLast,1)-nansum(sameAsLast)),' new TTL rows sent in ',num2str(toc),'s)'])
                        end
                        %}
                    else
                        disp(['Oddball TTL unchanged (#', num2str(oddballCount),')'])
                    end
                    if oddballType == 5
                        disp(['(Fixed jitter interval: ',num2str(f2List(oddballCount)),')'])
                    end
                    %disp(['Oddball type: ',num2str(oddballType)])
                    %oddballCount = oddballCount + 1; %Old position of
                        %oddballCount; Non last-ness was causing issues
                end
                %New position of WriteTargetVex that isn't restricted to just oddball
                %{
                if socky == 1
                    tic
                    for TTLcycle = 1:size(TTLvector,1)
                        if sameAsLast(TTLcycle,1) ~= 1 %"This row of TTL needs sending, as it is different"
                            DA.WriteTargetVEX(['Amp1.' Condition{TTLcycle,1} 'TTL'], 0, 'F32', single(TTLvector(TTLcycle,:)));
                        end %Note: Introduction of this may cause unexpected behaviour
                    end
                    disp(['(',num2str(size(sameAsLast,1)-nansum(sameAsLast)),' new TTL rows sent in ',num2str(toc),'s)'])
                end
                %}
                thisBlockStartTime = clock;

                %Append trial information to sentStimuli
                sentStimuli(trial_number).Condition = Condition{nanmax(find(Gating(4:6,trial_number) == 1)),1};
                    %Finds the last instance of a true in Gating and pulls that Condition
                sentStimuli(trial_number).oddballType = oddballType;
                sentStimuli(trial_number).TTLvector = TTLvector; %Note: Memory heavy
                sentStimuli(trial_number).trialSendDatestr = datestr(now, 'yyyy dd/mm HH:MM:SS:FFF');
                sentStimuli(trial_number).trialSendDatenum = datenum(now);

                if Stimulus(4,1) ~= 0
                    sentStimuli(trial_number).Stims = Stims(Stimulus(4,trial_number), :);
                else
                    sentStimuli(trial_number).Stims = [];
                end
                sentStimuli(trial_number).cycleIdent = cycIdentToSend;
                sentStimuli(trial_number).sentTDTCrash = 0; %Will be overwritten if this changes

                %Chunk recording if requested and sufficient time elapsed
                if chunkDatasets == 1
                    if ismember(trial_number,chunkBreakList) ~= 0 %"Block is chunk rest trial"
                        thisChunkEndTime = clock;
                        thisChunkEndTrial = trial_number;
                        
                        %Save MAT if requested
                        if saveIndividualChunkMATs == 1
                            tic
                            ttt =  datestr(now, 'yyyymmddTHHMMSS'); % saves the date and time in a format without ':', '-', or '_' which will let me save it in the file name below
                            thisChunkSentStimuli = sentStimuli; %Not optimal to make a full copy but honestly easier than alternatives
                            for blockInd = 1:thisChunkStartTrial
                                thisChunkSentStimuli(blockInd).TTLvector = []; %Clears the single-largest element of the structure
                            end
                            %Compact, single-file version
                            saveStruct = struct;
                            saveStruct.CarrierOrder = CarrierOrder; saveStruct.Channel = Channel; saveStruct.Amplitude = Amplitude; saveStruct.Stimulus = Stimulus; 
                            saveStruct.TTL = TTL; saveStruct.Gating = Gating; 
                            %saveStruct.sentStimuli = sentStimuli; %Old, increasing-filesize method
                            saveStruct.sentStimuli = thisChunkSentStimuli; %Note: This will not contain TTLs for blocks sent outside this chunk
                            saveStruct.chanGroupList = chanGroupList; 
                            saveStruct.ancillary.oddballFractionActive = oddballFractionActive; saveStruct.CarrierFirst = CarrierFirst;
                            saveStruct.ancillary.flagParamSaveStruct = flagParamSaveStruct; %Technically redundifies manual save of some of the above
                            saveStruct.ancillary.stimduration = stimduration; saveStruct.ancillary.StimType = StimType; 
                            saveStruct.blockNum = blockNum; %Actual recording block number (Assuming initial input was correct)
                            saveStruct.idealisedBlockNum = idealisedBlockNum; %'Ideal' block number, disregarding additional blocks due to failsafe operation
                            saveStruct.Chunk.thisChunkStartTrial = thisChunkStartTrial;
                            saveStruct.Chunk.thisChunkEndTrial = thisChunkEndTrial;
                            saveStruct.Chunk.thisChunkStartTime = thisChunkStartTime;
                            saveStruct.Chunk.thisChunkEndTrial = thisChunkEndTime;
                            save([cd '/StimOrder/' ttt '_saveStruct_' oddballTypeStr '_B' num2str(blockNum) customSaveStr '.mat'], 'saveStruct', '-v7.3');
                            clear thisChunkSentStimuli
                            disp(['(sentStimuli for chunk ',num2str(blockNum),' saved in ',num2str(toc),'s)'])
                        end
                        
                        disp(['#################################'])
                        %###
                        disp(['Chunk/Block #',num2str(blockNum), ' (',num2str(idealisedBlockNum),') finished (',num2str(etime(thisChunkEndTime,thisChunkStartTime)/60),'m); Commencing chunk/block #',num2str(blockNum+1)])
                        idealisedBlockNum = idealisedBlockNum + 1; %Ditto, but this happens here and only here
                            %This moved up here to better account for situations where the switch to intermissionMode fails
                                %Note: If the script crashes during the following section then idealisedBlockNum might be ahead of where it should be then
                        %###
                        %Set TDT to Idle and then back to Record
                        pause(5) %Allow time for rest trial to have been registered
                        tic
                        proceed = 0;
                        b = 1;
                        while proceed == 0
                            try
                                tdtStatus = DA.GetSysMode();
                                if tdtStatus == runMode
                                    disp(['Setting TDT to ',tdtModeIndex{intermissionMode+1}])
                                    %DA.SetSysMode(0);
                                    DA.SetSysMode(intermissionMode);
                                    pause(2.0) %Allow time to take effect
                                    tdtStatus = DA.GetSysMode();
                                    if tdtStatus == intermissionMode
                                        disp(['TDT successfully set to ',tdtModeIndex{intermissionMode+1}])
                                    else
                                        ['## Alert: Error in setting TDT to ',tdtModeIndex{intermissionMode+1},' ##']
                                        crash = yes
                                    end
                                    disp(['Reengaging TDT to ', tdtModeIndex{runMode+1}])
                                    DA.SetSysMode(runMode);
                                    pause(2.0)
                                    tdtStatus = DA.GetSysMode();
                                    if tdtStatus == runMode
                                        disp(['TDT successfully returned to ', tdtModeIndex{runMode+1}])
                                        blockNum = blockNum + 1; %Iterate blockNum by 1
                                        %idealisedBlockNum = idealisedBlockNum + 1; %Ditto, but this happens here and only here
                                        disp(['blockNum/idealisedBlockNum iterated (',num2str(blockNum),'/',num2str(idealisedBlockNum),')'])
                                        proceed = 1;
                                    else
                                        ['## Alert: Error in returning TDT to ', tdtModeIndex{runMode+1},' ##']
                                        crash = yes
                                    end
                                else
                                    ['## Alert: TDT not in ', tdtModeIndex{runMode+1},' mode ##']
                                    connectionStat=DA.CheckServerConnection();
                                    systemMode=DA.GetSysMode();
                                    disp(['(TDT connection: ',num2str(connectionStat),', current mode:',num2str(systemMode),')'])
                                    failTime = clock
                                        %Might be forgivable for debugging?
                                    crash = yes
                                end
                            catch
                                %disp(['## Failure to engage new chunk; Attempting again (',num2str(a),') ##'])
                                disp(['## Failure to switch to new chunk; Engaging failsafe (',num2str(b),') ##'])
                                proceed = 0;
                                pause(5)
                                %##
                                %[success,systemMode] = TDTFailsafeFunction(3); %Note that it is necessary after using failsafe to reconnect to DA
                                [success,systemMode] = TDTFailsafeFunction(runMode); %Note that it is necessary after using failsafe to reconnect to DA
                                failsafeEngagedCount = failsafeEngagedCount + 1;
                                failsafeEngagedTimes(failsafeEngagedCount,:) = clock;
                                ignoreDuration = 1; %Experimental; Should prevent aberrantly concurrent failsafe operation
                                if success == 1 && systemMode == runMode
                                    disp(['-- Failsafe successful in setting system to Record --'])
                                    proceed = 1;
                                    blockNum = blockNum + 1; %Note that this is not a perfect system
                                        %Also, idealisedBlockNum is not iterated here, to maintain perfect-world synchronicity
                                    disp(['blockNum iterated (',num2str(blockNum),')'])
                                else
                                    disp(['## Failsafe unsuccessful ##'])
                                end
                                %##
                                
                                %************
                                %Reconnect to server
                                disp(['-# Reconnecting to server after failsafe #-'])
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
                                    ['## Could not reconnect to server after failsafe ##']
                                    crash = yes
                                else
                                    disp(['-# System sucessfully reconnected #-',char(10)])
                                end
                                %************
                                
                            end
                                                       
                            b = b + 1;
                        end
                        
                        %Load applicable piece of ttlStruct
                            %Note: Possibly not correct place for this, wrt
                            %ttlStruct clearing below?
                        if piecemealTTLstruct == 1
                            %preLoad =
                            %load([ttlHoldFolder,filesep,'chunk_',num2str(blockNum),'_ttlStruct.mat']); %Old
                            preLoad = load([ttlHoldFolder,filesep,'chunk_',num2str(idealisedBlockNum),'_ttlStruct.mat']); %New
                            pieceList = preLoad.saveTTLstruct.Chunk.oddballInds; %Which ttlStruct elements this piecemeal chunk holds data for
                            for pea = 1:size(pieceList,2)
                                %Preliminary QA
                                if preLoad.saveTTLstruct.ttlStruct(pea).order ~= ttlStruct(pieceList(pea)).order
                                    ['## Alert: Fatal error in synchronisation between piecemeal and ttlStruct ##']
                                    crash = yes
                                else
                                    ttlFiels = fieldnames(preLoad.saveTTLstruct.ttlStruct);
                                    for fiel = 1:size(ttlFiels,1)
                                        ttlStruct(pieceList(pea)).(ttlFiels{fiel}) =  preLoad.saveTTLstruct.ttlStruct(pea).(ttlFiels{fiel}); %"Chunks are individual instances of saveTTLStruct"
                                    end
                                end
                            end
                            disp(['(ttlStruct values loaded for ',num2str(size(pieceList,2)),' elements from piecemeal chunk ',num2str(idealisedBlockNum),')'])
                        end
                        
                        %^^^^^^^^^^^^^^
                        
                        TTLvector = [];
                        %Dynamically determine first TTL, rather than sending first existing oddball TTL
                        if Gating(4,trial_number) == 1
                            TTLvector = carrierOnlyTTLVector;
                        elseif Gating(5,trial_number) == 1
                            TTLvector = ttlStruct(oddballCount).combinedTTL; %The previous lines have effectively just been shifted to earlier in the code
                        else
                            TTLvector = restTTLVector;
                        end
                        %%reloadRemainingTrials = []; %List of reported remainingTrials values (mainly for debugging)
                        if socky == 1
                            %%DA.SetTargetVal(['Amp1.trialnumval'], trialnumval); %Original
                            if remainingTrials == 0
                                ['## Alert: remainingTrials detected to be 0 prior to setting ##']
                                crash = yes
                            end
                            DA.SetTargetVal(['Amp1.trialnumval'], remainingTrials); %Modified
                            % Load sine wave stimuli into buffer

                            if Stimulus(4,1) ~= 0 %"[First] trial is not rest"
                                DA.WriteTargetVEX(['Amp1.stim'], 0, 'F32', single(Stims(Stimulus(4), :)));
                            end

                            for TTLcycle = 1:size(TTLvector,1) %No intelligent sending here, since this is first instance
                                DA.WriteTargetVEX(['Amp1.' Condition{TTLcycle,1} 'TTL'], 0, 'F32', single(TTLvector(TTLcycle,:)));
                            end

                            DA.SetTargetVal('Amp1.duration', stimulusduration);

                            for ParseChannel = 1:size(Condition,1);
                                %DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], Amplitude(ParseChannel,1));
                                %DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], GatingSig(ParseChannel,1));
                                DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number)); %Modified
                                DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number)); %Modified
                            end
                            %now start protocol
                            for ParseChannel = 1:size(Condition,1);
                                %DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                                %DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                                DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                                DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                            end

                            currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);
                            % sleep(0.2);
                            DA.SetTargetVal('Amp1.trigger', 0); % turn off the trigger afterwards

                            if currentStatReset == 0
                                for ParseChannel = 1:size(Condition,1);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], Amplitude(ParseChannel,1));
                                    %currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], GatingSig(ParseChannel,1));
                                    currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number));
                                    currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number));
                                end
                                %now start protocol
                                for ParseChannel = 1:size(Condition,1);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                                    %currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                                    currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                                    currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                                end

                                currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);

                            else
                                for ParseChannel = 1:size(Condition,1);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], 0);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], 0);
                                    currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], 0);
                                    currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], 0);
                                end
                                %now start protocol
                                for ParseChannel = 1:size(Condition,1);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], 0);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], 0);
                                    currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], 0);
                                    currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], 0);
                                end

                                currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 0);

                                %now start protocol
                                for ParseChannel = 1:size(Condition,1);
                                    %currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,1))], Amplitude(ParseChannel,1));
                                    %currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,1))], GatingSig(ParseChannel,1));
                                    currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number));
                                    currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number));
                                end

                                for ParseChannel = 1:size(Condition,1);
                                    %DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                                    %DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,1))], Gating(ParseChannel,1));
                                    DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                                    DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                                end

                                currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);
                            end

                            remainingTrials=DA.GetTargetVal(['Amp1.remainingTrialstrigger']); %Borrowed from later on for completness' sake
                            %%reloadRemainingTrials(reloadCount) = remainingTrials;
                            if remainingTrials == 0
                                ['## Alert: remainingTrials detected to be 0 post setting ##']
                                crash = yes
                            end
                            disp(['(Remaining trials, post chunk: ',num2str(remainingTrials),')'])

                        elseif socky == 2
                            remainingTrials = trialnumval; %Set up for TDT-free operation later
                            %%reloadRemainingTrials(reloadCount) = remainingTrials; %Very similar to CheckRemainingTrials, but only fills on reload
                        end
                        
                        %^^^^^^^^^^^^^^
                        
                        thisChunkStartTime = clock; %Pretty self-explanatory
                        thisChunkStartTrial = trial_number; %Keeps track of the block range for this chunk
                            %Note: May not be optimal location for this
                        
                        disp(['Chunking completed in ',num2str(toc),'s'])
                        disp(['########################################'])
                        %QA for block type during chunking
                        if Gating(5,trial_number) ~= 0 || Gating(4,trial_number) ~= 0
                            ['## Warning: Chunking appears to have occurred on non-rest block ##']
                        end
                    end
                    
                    %disp(['Stage 3 CheckRemainingTrials: ',num2str(CheckRemainingTrials(count))])
                    chunkDistances = chunkBreakList - trial_number;
                    if nansum(chunkDistances > 0) >= 1 
                        disp(['(',num2str(chunkBreakList(  find(chunkDistances > 0,1) ) - trial_number),' trial block\s until next chunking event)'])
                    else
                        disp(['(No more chunks until projected end of experiment)'])
                    end
                    %pause(10)
                    
                end

                
                %Clear unnecessary elements from ttlStruct as going
                    %Warning: This means ttlStruct cannot be used for
                    %anything at the end of the experiment
                if Gating(5,trial_number) == 1 && runningMemoryClear == 1
                    disp(['(Oddball block ',num2str(oddballCount),' wiped from ttlStruct to save memory)'])
                    %Only clear following oddball blocks, since carrieronly
                    %blocks are not stored in ttlStruct (currently)
                    ttlStruct(oddballCount).carrieronlyTTL = [];
                    ttlStruct(oddballCount).carrierTTL = [];
                    ttlStruct(oddballCount).combinedTTL = [];
                    ttlStruct(oddballCount).oddballTTL = [];
                    ttlStruct(oddballCount).carrieronlysine = [];
                    ttlStruct(oddballCount).carrieronlysquare = [];
                        %This struct field specification necessary because
                        %wiping whole index will mess with correct indexing
                        %of following trials
                    %QA to check haven't just wiped a block that hasn't
                    %been sent yet
                    if ttlStruct(oddballCount).hasBeenSent == 0
                        ['## Alert: Unsent oddball block has been cleared accidentally ##']
                        crash = yes
                            %Might be wiser to put this up above and have
                            %it stop the if loop?
                    end
                end
                
                %Iterate oddballCount as last action
                if Gating(5,trial_number) == 1
                    oddballCount = oddballCount + 1;
                end
                
                %Force a crash after everything loaded, if applicable
                if forceCrash == 1
                    disp([char(10),'-# Attempting to force crash, as requested #-'])
                    if socky == 1
                        DA.ZeroTarget(['Amp1.',Condition{ParseChannel,1},'TTL']);
                        pause(5)
                        succCrash = 0;
                        while succCrash == 0
                            connectionStat=DA.CheckServerConnection();
                            systemMode=DA.GetSysMode();
                            disp(['Post-crash TDT report - TDT connection: ',num2str(connectionStat),', current mode:',num2str(systemMode)])
                            if systemMode ~= runMode
                               disp(['-# Task failed successfully #-'])
                               succCrash = 1;
                            else
                                disp(['#- Failure to fail; Attempting again #-'])
                                DA.ZeroTarget(['Amp1.',Condition{ParseChannel,1},'TTL']);
                                pause(5)
                            end
                        end
                        %disp(['-# Task failed successfully #-'])
                        plannedCrash = yes
                    else
                        plannedCrash = yes %Look how easy that was
                    end
                end
                
                %Check red light status, if applicable
                if redLight == 1
                    temp = [];
                    temp = [temp,DA.GetTargetVal(['Amp1.triggerRed'])];
                    temp = [temp,DA.GetTargetVal(['Amp1.redIdx'])];
                    temp = [temp,DA.GetTargetVal(['Amp1.redChVal'])];
                    temp = [temp,DA.GetTargetVal(['Amp1.edgeRed'])];
                    temp = [temp,DA.GetTargetVal(['Amp1.redStage'])];
                    disp(['-R- ',num2str(etime(currentTime,initTime)),'s - Phase: ',num2str(redIt),', triggerRed: ',num2str(temp(1)),...
                        ', redIdx: ',num2str(temp(2)),', redChVal: ',num2str(temp(3)),', redStage: ',num2str(temp(5)),' -R-'])
                end

            elseif CheckRemainingTrials(count) - CheckRemainingTrials(count-1)==trialnumval-1 || reloadCount == size(ChannelOrder,2)
                isFinished = true;
                if CheckRemainingTrials(count) - CheckRemainingTrials(count-1) ~= trialnumval-1 && reloadCount == size(ChannelOrder,2)
                    ['#- reloadCount fallback used to determine experiment end -#']
                    %notkay
                end
            end

            %{
            %TDT check and cycle connection loop
            %This was here because the previous instance at the Reload.
            %point might not occur if TDT crashes completely or goes offline
                %Note: It may be unwise to check this every 0.3 seconds
            if socky == 1 && fullDescriptiveTDT == 1
                connectionStat=DA.CheckServerConnection();
                systemMode=DA.GetSysMode();
                %disp(['(TDT connection: ',num2str(connectionStat),', current mode:',num2str(systemMode),')'])
                if connectionStat == 0 || ( systemMode ~= 3 && systemMode ~= 1 ) 
                    disp(['#- Potential connection loss detected; Attempting to close and reopen connection -#'])
                    DA.CloseConnection()
                    pause(1)
                    clear DA
                    DA = actxcontrol('TDevAcc.X');
                    succeed = 0;
                    while succeed == 0
                        succeed=DA.ConnectServer('Local');
                        disp(['#- ConnectServer state report: ',num2str(succeed),' -#'])
                        pause(1)
                    end
                end
            end
            %}
            
            %Check how long trial has been running for
            %currentTime = clock;
            if etime(currentTime,thisBlockStartTime) > 2.5*stimduration && ignoreDuration ~= 1 %"Current block has been going for 2x longer than a block should have"
                ['## Alert: Current block duration exceeds intentions ##']
                %pause(20)
                %crash = yes
                ['## Engaging failsafe ##']
                %##
                [success,systemMode] = TDTFailsafeFunction(runMode);
                if success == 1 && systemMode == runMode
                    disp(['-- Failsafe successful in setting system to ',tdtModeIndex{runMode+1},' --'])
                    proceed = 1;
                    blockNum = blockNum + 1; %Note that this is not a perfect system
                    ignoreDuration = 1; %Prevents next loop from catching again
                        %(Cleaner than falsely adjusting thisBlockStartTime)
                    disp(['blockNum iterated (',num2str(blockNum),')'])
                else
                    disp(['## Failsafe unsuccessful ##'])
                    crash = yes;
                end
                %************
                %Reconnect to server
                disp(['-# Reconnecting to server after failsafe #-'])
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
                    ['## Could not reconnect to server after failsafe ##']
                    crash = yes
                else
                    disp(['-# System sucessfully reconnected #-',char(10)])
                end
                %************
                
                %##
                %TDT restart code borrowed from chunking
                %^^^^^^^^^^^^^^
                TTLvector = [];
                %Dynamically determine first TTL, rather than sending first existing oddball TTL
                if Gating(4,trial_number) == 1
                    TTLvector = carrierOnlyTTLVector;
                elseif Gating(5,trial_number) == 1
                    TTLvector = ttlStruct(oddballCount).combinedTTL; %The previous lines have effectively just been shifted to earlier in the code
                else
                    TTLvector = restTTLVector;
                end
                
                %if socky == 1
                DA.SetTargetVal(['Amp1.trialnumval'], remainingTrials); %Modified
                % Load sine wave stimuli into buffer
                if Stimulus(4,1) ~= 0 %"[First] trial is not rest"
                    DA.WriteTargetVEX(['Amp1.stim'], 0, 'F32', single(Stims(Stimulus(4), :)));
                end

                for TTLcycle = 1:size(TTLvector,1) %No intelligent sending here, since this is first instance
                    DA.WriteTargetVEX(['Amp1.' Condition{TTLcycle,1} 'TTL'], 0, 'F32', single(TTLvector(TTLcycle,:)));
                end

                DA.SetTargetVal('Amp1.duration', stimulusduration);

                for ParseChannel = 1:size(Condition,1);
                    DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number)); %Modified
                    DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number)); %Modified
                end
                %now start protocol
                for ParseChannel = 1:size(Condition,1);
                    DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                    DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                end

                currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);
                DA.SetTargetVal('Amp1.trigger', 0); % turn off the trigger afterwards

                if currentStatReset == 0
                    for ParseChannel = 1:size(Condition,1);
                        currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number));
                        currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number));
                    end
                    %now start protocol
                    for ParseChannel = 1:size(Condition,1);
                        currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                        currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                    end

                    currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);

                else
                    for ParseChannel = 1:size(Condition,1);
                        currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], 0);
                        currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], 0);
                    end
                    %now start protocol
                    for ParseChannel = 1:size(Condition,1);
                        currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], 0);
                        currentStatReset=DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], 0);
                    end

                    currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 0);

                    %now start protocol
                    for ParseChannel = 1:size(Condition,1);
                        currentStatReset=DA.SetTargetVal(['Amp1.carrieronlyAMP' num2str(Channel(ParseChannel,trial_number))], Amplitude(ParseChannel,trial_number));
                        currentStatReset=DA.SetTargetVal(['Amp1.stimON' num2str(Channel(ParseChannel,trial_number))], GatingSig(ParseChannel,trial_number));
                    end

                    for ParseChannel = 1:size(Condition,1);
                        DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} 'ON' num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                        DA.SetTargetVal(['Amp1.' Condition{ParseChannel,1} num2str(TTL(ParseChannel,trial_number))], Gating(ParseChannel,trial_number));
                    end

                    currentStatReset=DA.SetTargetVal(['Amp1.trigger'], 1);
                end

                remainingTrials=DA.GetTargetVal(['Amp1.remainingTrialstrigger']); %Borrowed from later on for completness' sake
                
                sentStimuli(trial_number).sentTDTCrash = 1;
                
                %elseif socky == 2
                %    remainingTrials = trialnumval; %Set up for TDT-free operation later
                %    %%reloadRemainingTrials(reloadCount) = remainingTrials; %Very similar to CheckRemainingTrials, but only fills on reload
                %end
                %^^^^^^^^^^^^^^
            end
            
            pause(0.3)

        else
            if CheckRemainingTrials(count) - CheckRemainingTrials(count-1)==trialnumval-1
                isFinished = true;
            end
            pause(0.3)
        end
    end

    disp(['----------------------------------------'])
    disp('End of flicker sequence!');
    
    %Turn off red light if valid
    if redLight == 1 && socky == 1 & redMode == 1
        %DA.SetTargetVal('Amp1.redDuration', redDur(redIt));
        DA.WriteTargetVEX(['Amp1.redStim'], 0, 'F32', single([redSquare]));
        redLightReset=DA.SetTargetVal(['Amp1.redTrigger'], 0); %Turn off
        disp(['Red light status (0) set success state: ',num2str(redLightReset)])
    end
    
    %Quick QA
    if oddballCount ~= size(ttlStruct,2)
        ['#- Warning: ',num2str(size(ttlStruct,2) - oddballCount),' elements in ttlStruct were never displayed  -#']
            %i.e. Oddball blocks were prepared but not used
    end
    
    if failsafeEngagedCount ~= 0
        ['-# TDT failsafe was engaged ',num2str(failsafeEngagedCount),' times #-']
        disp([num2str(failsafeEngagedTimes)])
    else
        disp(['-- No detected crashes for TDT --'])
    end
    
    %{
    %Rendered non-functional by flagrant use of tic
    if socky == 1
        toc
    end
    %}

    %Save MAT files
    switch SaveSetting
        case 'on'
            % Date for filename
            ttt =  datestr(now, 'yyyymmddTHHMMSS'); % saves the date and time in a format without ':', '-', or '_' which will let me save it in the file name below

            % Create folder to save stimulus order in (that way directory doesn't get
            % clogged with files)
            %{
            %(Moved above to decrease runtime load)
            if ~isdir([cd '/' 'StimOrder'])
                mkdir([cd '/' 'StimOrder']);
            end
            %}

            % Save as .mat variable in directory above
            %{
            save([cd '/StimOrder/' ttt '_Channel_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) '.mat'], 'Channel','CarrierOrder');
            save([cd '/StimOrder/' ttt '_Condition_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) '.mat'], 'Gating','CarrierOrder');
            save([cd '/StimOrder/' ttt '_Amplitude_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) '.mat'], 'Amplitude','CarrierOrder');
            save([cd '/StimOrder/' ttt '_Stimulus_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) '.mat'], 'Stimulus','CarrierOrder');
            save([cd '/StimOrder/' ttt '_TTL_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) '.mat'], 'TTL','CarrierOrder');
            save([cd '/StimOrder/' ttt '_sentStimuli_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) '.mat'], 'sentStimuli','CarrierOrder');
            %}

            %Compact, single-file version
            saveStruct = struct;
            saveStruct.CarrierOrder = CarrierOrder; saveStruct.Channel = Channel; saveStruct.Amplitude = Amplitude; saveStruct.Stimulus = Stimulus; 
            saveStruct.TTL = TTL; saveStruct.Gating = Gating; saveStruct.sentStimuli = sentStimuli; saveStruct.chanGroupList = chanGroupList; 
            saveStruct.ancillary.oddballFractionActive = oddballFractionActive; saveStruct.CarrierFirst = CarrierFirst;
            saveStruct.ancillary.flagParamSaveStruct = flagParamSaveStruct; %Technically redundifies manual save of some of the above
            saveStruct.ancillary.stimduration = stimduration; saveStruct.ancillary.StimType = StimType; 
                %Note: StimType may change in the future block to block and this will need to become dynamic
            saveStruct.blockNum = blockNum;
            saveStruct.idealisedBlockNum = idealisedBlockNum;
            %save([cd '/StimOrder/' ttt '_saveStruct_' oddballTypeStr '_carrOdd' num2str(CarrierFirst) customSaveStr '.mat'], 'saveStruct');
            save([cd '/StimOrder/' ttt '_saveStruct_' oddballTypeStr '_B' num2str(blockNum) customSaveStr '.mat'], 'saveStruct', '-v7.3');
                %It might be cleaner to introduce a checking system for
                %whether saveStruct can be saved as non-7.3 but that could
                %introduce disparities within experiments
            
            disp(['End of experiment data saved to saveStruct'])
            
            clear Channel Gating Amplitude Stimulus sentStimuli saveStruct


        case 'off'
            disp('Not saving trial order.');
    end

    disp('Wait 30 seconds!');
    pause(30)

    if orderCount ~= size(CarrierOrder,2)
        disp('Changing stimulus protocol...');
    else
        disp('All stimulus protocols completed!');
    end

    disp(['-- Experimental duration: ',num2str(toc(expStart)),'s --'])

%CarrierFirst end
end

if socky == 1
    %Set device to Idle
    DA.SetTargetVal('Amp1.trigger', 0);
    DA.SetSysMode(0);
    pause(3.0)
    if DA.GetSysMode() == 0
        disp(['-- System successfully returned to Idle --'])
    else
        ['## Failure to return system to Idle! ##']
    end
    %and close connection
    DA.CloseConnection()
end

if doDiary == 1
    diary off
end

%Fin