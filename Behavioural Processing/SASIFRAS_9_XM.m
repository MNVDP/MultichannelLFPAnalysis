%%
%S[OFAS] Ancillary Script for Instruct (and others) File Reading and AnalysiS (SASIFRAS)
%                           "SaSiFRaS: AutomatA"

%Note: Some PE functionality is replicated/coopted in/by SUBSIFRAS
%   (Although it is probably deprecated by Mk 7 standards)

%Mk 1 - Core functionality
%   2 - Generalisation to use automated analysis output files
%   3 - Further FFT analysis, control segregation
%   4 - Switch to unsmoothed data for most things
%    .5 - Across-bout metrics, within-bout metrics
%    .75 - Within-bout splitting
%    .95 - Refinements to within-bout splitting
%   5 - Sleep curves, wake analysis
%    .25 - Refinements to wake analysis, Normalisation, Duration metrics, More ZT curves
%    .5 - Experimental deployment of processList on prob data
%    .75 - Data generalisation, significant prob. analysis implementation
%    .85 - Additional PE spell splitting
%   6 - Plot order consolidation and cleaning
%    .25 - PE detection major reshuffling
%    .35 - Removal of aberrant 0.5* on SEMs, addition of sleep bouts CuSu plot
%    .45 - Modifications to work with MATLAB 2020a, Small isempty-armouring for Spell plot, Bart-style inter-PE-interval histogram 
%    .55 - BigBird compatibility modifications
%   7 - Improvements to PE exclusion (probInterval changed to 1.25s [Was 1.5s], Lonesome disabled) (Note: FFT-related value of 1.5 is in Hz, not s), spell min. size changed to 8 (inclusive) from 10 (exclusive),
%       Switched sleepRail to use proper PE detection rather than above-mean detection (Note: Current PE -> Sig flattening implementation uses probInterval in a pointwise manner, as opposed to flattening entire FFT windows)
%           ((This is less harsh on perio detection (e.g. 10 evenly spaced PEs can't eliminate perio detection for an entire 5m bout), but will permit bleedthrough of PE into perio detection))
%    .55 - Significant adjustment of order to bring PE detection above fouri calculations to allow native ant. signal flattening, All L/R ant. data referencing collapsed to central reference
%    .7 - Improvements to PE detection (Stronger enforcement of 'natural' shape) w/ addition of instantaneous change exclusion; Added any perio. column/s to flidStruct 
%    .85 - Calculation of PE angles (For DLC data)
%    .95 - Rose plots for PE angles
%   8 - Ant. perio. during wake, Moved barStats to own function
%    .25 - PE detection tinkering, Switch to parameter grouping, bodyStruct improvements
%   9 - Alternative PE detection (Reach-inspired), Other metrics
%       Note: Alt detection uses probMetric > alternativeNoiseThresh, followed by eliminating instances < alternativeMinSize*fs in length, followed by stitching remaining together if separated by < alternativeMinSize again (One round only)

%{
saveTime = 1; %Whether to keep variables loaded rather than reload during rapid processing
if saveTime ~= 1
    clear
else
	clearvars('-except','overVar')   
end
%}
clear
close all
warning('off','rmpath:DirNotFound');
warning('off','MATLAB:print:FigureTooLargeForPage')
warning('off','MATLAB:handle_graphics:exceptions:SceneNode')

tic

%progIdent = 'SASIFRAS_7point95_XM'
progIdent = mfilename %Now automated!

%--------------------------------
%Add toolboxes
%%toolPath = 'C:\Users\labpc\Desktop\Matt\MATLAB toolboxes';
toolPath = 'D:\group_swinderen\Matthew\Scripts\toolboxes';

addpath(toolPath)

%FieldTrip (Defined here but not added till later)
%ftPath = 'C:\Users\labpc\Desktop\Matt\MATLAB toolboxes\fieldtrip-20151223';
ftPath = [toolPath, filesep, 'fieldtrip-20151223'];
if exist('fieldtrip') == 7
    rmpath(genpath(ftPath));
    disp(['# Pre-existing fieldtrip path found and removed #'])
end

% [lastmsg,lastid] = lastwarn; % to find last warning.

%addpath(genpath([toolPath filesep 'functions'])); % Bipolar Reference and other functions
%addpath([toolPath filesep 'FastICA_25']);
%addpath(genpath(procPath)); % add to path
addpath([toolPath filesep 'basefindpeaks']); %Adds the base form of findpeaks as a function
    %This is necessary because chronux has a findpeaks that overwrites the (arguably superior) MATLAB inbuilt
%addpath(genpath([toolPath filesep 'joyPlot'])); % Joy Division - Unknown Pleasures style 3D plot
addpath(genpath([toolPath filesep 'run_exiftool']));
addpath(genpath([toolPath filesep 'chronux']));
addpath(genpath([toolPath filesep 'barwitherr']));
addpath(genpath([toolPath filesep 'altmany-export_fig-9676767']));
addpath(genpath([toolPath filesep 'swtest']));
addpath(genpath([toolPath filesep 'violin']));
addpath(genpath([toolPath filesep 'polar2']));

warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved'); %Suppress warnings related to export_fig

%--------------------------------

%-------------
%Parameters

%dataPath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\SavOut\NewFormat' %Behavioural sleep data

%Sleep behavioural data (Primary sleep behaviour parameter set, including for Sri figures)

dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SPECIFICNEWDLC'; 
    %manThreshes = [15,12,27,15,15,18,15,15,15,18,20];
    %manThreshes: 030119(Speculated),050219,070219,140419,170119,200519,210119,240119,300119,171218,211218
    overAltAngGroups = [...
        {{ [330-40,330],[331,331+40] }},... %03 01 19
        {{ [334-40,334],[335,335+40] }},... %05 02 19
        {{ [300-40,300],[301,301+40] }},... %07 02 19
        {{ [308-40,308],[309,309+40] }},... %14 04 19
        {{ [292-40,292],[293,293+40] }},... %17 01 19
        {{ [300-40,300],[301,301+40] }},... %20 05 19
        {{ [300-40,300],[301,301+40] }},... %21 01 19
        {{ [300-40,300],[301,301+40] }},... %24 01 19
        {{ [311-40,311],[312,312+40] }},... %30 01 19
        {{ [331-40,331],[332,332+40] }},... %17 12 18
        {{ [300-40,300],[301,301+40] }},... %21 12 18
        ];
  
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SPECIFICNEW'; manThreshes = [30,12,27,15,15,18,15,15,15,18,20];
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\OVERNIGHT GREENBLUE' 
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SPECIFICPETESTING2'
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SPECIFICPETESTING_NEWDLC'; manThreshes = [6];
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SUPERSPECIFICNEW4'; manThreshes = []; overAltAngGroups = [{{ [330-40,330],[331,331+40] }}];
doFFT=1;
processList = [{'xRight'},{'xLeft'}, {'probData'}]; plotProcessList = [{'rightThetaProc'},{'leftThetaProc'},{'probMetric'}]; 
%processList = [{'xRight'},{'xLeft'}]; plotProcessList = [{'rightThetaProc'},{'leftThetaProc'}];
%processList = [{'probData'}]; plotProcessList = [{'probMetric'}];
doAggPEFlat = 1;
automatedSavePlots = 0;
automatedSaveWorkspace = 1;
splitBouts = 1;
loadBodyStruct = 0; %Whether to look for and load (if existing) a file generated by MANCUB with manual information on body angle
doTimeCalcs = 1; 
useExclusionCriteria = 1;
doGaussExclusion = 0; doBSnrExclusion = 0; doLonesomeExclusion = 0; doTooFastExclusion = 0; doWExclusion = 1; doTooHighExclusion = 1; doInstChangeExclusion = 1;
doAltDetection = 1; %Whether to do alternative proboscis movements detection (~1 - 2 mins per dataset)
useManualAltThresholds = 0;
doSriBoxPlot = 1; %Whether to do Sri-aesthetic boxplots alongside barplots
%{
%Deprecated with overAltAngGroups
if loadBodyStruct == 1
    %altAngGroups = [{[180,220]},{[221,280]}]; %Same, but corrected for different angles when bodyStruct in use; Overnight greenblue specific
    %altAngGroups = [{[270,290]},{[291,311]}]; %Sleep behav data (NOT ADJUSTED FOR BODYSTRUCT YET)
else    
    %altAngGroups = [{[90,130]},{[131,190]}]; %Arbitrary angle groups to split alt detection events into based on their angle; Overnight greenblue specific
    %altAngGroups = [{[270,290]},{[291,311]}]; %Sleep behav data
end
%}
%}
%Sleep behavioural data
%{
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SUPERSPECIFICNEW3' %Behavioural sleep data (Cutdown)
dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SPECIFICNEW' %Behavioural sleep data
doFFT=1;
processList = [{'xRight'},{'xLeft'}, {'probData'}]; plotProcessList = [{'rightThetaProc'},{'leftThetaProc'},{'probMetric'}]; 
%processList = [{'xRight'},{'xLeft'}]; plotProcessList = [{'rightThetaProc'},{'leftThetaProc'}];
doAggPEFlat = 1;
automatedSavePlots = 1;
automatedSaveWorkspace = 1;
splitBouts = 1;
loadBodyStruct = 1; %Whether to look for and load (if existing) a file generated by MANCUB with manual information on body angle
%}
%{
dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\OVERNIGHT GREENBLUE' %LFP sleep data
doFFT=1; processList = [{'probData'}]; plotProcessList = [{'probMetric'}];
%}
%{
dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\SPECIFICRED' %LFP Red sleep data
doFFT=1; processList = [{'probData'}]; plotProcessList = [{'probMetric'}];
%}
%Red controls
%{
dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\REDCONTROLS' %As above
doFFT=1; processList = [{'probData'}]; plotProcessList = [{'probMetric'}]; doAggPEFlat = 1; 
%}
%Jelena data
%{
dataPath = 'D:\group_swinderen\Jelena\OUT\SavOut' %As above
doFFT=1; processList = [{'probData'}]; plotProcessList = [{'probMetric'}]; doAggPEFlat = 1; 
automatedSavePlots = 1;
automatedSaveWorkspace = 1;
%}
%Red 2023
%{
%dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\RED2023CONTROL' %As above
dataPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut\RED2023EXPERIMENTAL' %As above
doFFT=1; processList = [{'probData'}]; plotProcessList = [{'probMetric'}];
doAggPEFlat = 1;
automatedSavePlots = 1;
automatedSaveWorkspace = 1;
splitBouts = 0;
loadBodyStruct = 0; %Whether to look for and load (if existing) a file generated by MANCUB with manual information on body angle
doTimeCalcs = 1; 
useExclusionCriteria = 1;
doGaussExclusion = 0; doBSnrExclusion = 0; doLonesomeExclusion = 0; doTooFastExclusion = 0; doWExclusion = 1; doTooHighExclusion = 1; doInstChangeExclusion = 1;
doAltDetection = 0; %Whether to do alternative proboscis movements detection (~1 - 2 mins per dataset)
useManualAltThresholds = 0;
doSriBoxPlot = 0;

%}

%--------------------------------

%loadVarList = [{'inStruct'}, {'flyName'}, {'combDiver'}, {'rightThetaSmoothed'}, {'leftThetaSmoothed'}, {'avProbContourSizeSmoothed'}, ...
%    {'avContourSizeSmoothed'}, {'rightThetaProc'},{'leftThetaProc'}, {'overGlob'}, {'trueAv'}, {'adjAv'}, {'dlcSmoothSize'}, {'hasDataList'}]
    %List of variables to load from files, rather than whole things
loadVarList = [{'inStruct'}, {'flyName'}, {'avProbContourSizeSmoothed'}, ...
    {'avContourSizeSmoothed'}, {'overGlob'}, {'trueAv'}, {'adjAv'}, {'dlcSmoothSize'}, {'hasDataList'}] 

%figPath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\FigOut'
figPath = [dataPath, filesep, 'Figs'];
if isempty(dir(figPath))  == 1
    mkdir(figPath)    
end
%Switches
subPlotMode = 1 %1 - use subplots (tiny panels), 2 - use scrollSubPlot (less tiny panels but not as saveable)
savePlots = 0 %Whether to save plots as PNGs (will behave poorly if scrollSubPlots in use) [Not necessary for automatedSavePlots]
automatedSavePlots = automatedSavePlots %Whether to use an automated system to pull figure names and save them
%(Specification moved above)
if automatedSavePlots == 1
    autoFigPath = figPath;
    automatedSaveVectors = 1; %Whether to try save vector versions of figs before saving as PNGs
    vectorAutoFigPath = [figPath, filesep, 'Vec'];
    clearOldFigures = 1; %Whether to clear old auto-generated figures
    closeFiguresAfterSaving = 0; %Whether to iteratively close figures during the save process to save memory
    additionalFigParams = ['']; %Any relevant modifiers will be appended to this
end
automatedSaveWorkspace = automatedSaveWorkspace; %Whether to save a small number of descriptive variables along with plots
%(Specification moved above)
if automatedSaveWorkspace == 1
    descVariablesList = [{'overVar(IIDN).fileDate'},{'overVar(IIDN).trueAv'},{'overVar(IIDN).adjAv'},{'overVar(IIDN).inStructCarry.holeStarts'},{'overVar(IIDN).inStructCarry.holeEnds'},...
        {'overVar(IIDN).overGlob.dataList'},{'overVar(IIDN).overGlob.importStruct'},{'sleepStruct.combBout'}];
    %To add: alt detection vars
    clearOldWorkspaceSaves = 1; %Whether to delete old .mat files in workspace save directory
    savePEInformation = 1; %Whether to save structures denoting PE and PE spell locations
    if savePEInformation == 1
        peVariablesList =  [{'probScatter'},{'overAllPE'},{'overVar(IIDN).fileDate'},{'overVar(IIDN).inStructCarry'}];
    end
end
saveFullWorkspace = 0; %Whether to save the full contents of the workspace (Note: Takes a significant amount of time, makes a huge file and doesn't really speed up much)
if saveFullWorkspace == 1
    %workSavePath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\WorkOut';
    workSavePath = 'D:\group_swinderen\Matthew\TDTs\SleepData\WorkOut';
end
saveIntegrationVariables = 0; %Whether to save a number of variables necessary for integration with LFP scripts to file
if saveIntegrationVariables == 1
    integVariablesList =  [{'overVar(IIDN).flyName'},{'overVar(IIDN).inStructCarry'},{'overVar(IIDN).railStruct'},{'overVar(IIDN).dataFrameRate'},{'overVar(IIDN).probMetric'},{'probScatter(IIDN)'},{'overAllPE(IIDN)'},...
        {'overVar(IIDN).overGlob.acRaw'}];
    %integVariablesList =  [{'overVar(IIDN).flyName'},{'overVar(IIDN).inStructCarry'},{'overVar(IIDN).railStruct'},{'overVar(IIDN).dataFrameRate'},{'overVar(IIDN).probMetric'},{'probScatter(IIDN)'},{'overAllPE(IIDN)'},...
    %    {'overVar(IIDN).overGlob.tempRaw'}];
    integPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\IntegOut';
    clearOldIntegSaves = 1; %Self-descriptive (Note: Only applies to saves sharing same name as current integ, not all)
end
doDLC = 1 %Whether to do calculations on DLC data
if doDLC == 1
   safeHeight = 480; %Hardcoded video height for centreline extrapolation purposes
   dlcSmoothSize = 30; %How many timepoints to rolling smooth for DLC data display purposes
   doMedianGeometry = 1; %Whether to calculate angles relative to a fixed median intercept point
   forceUseDLCData = 1; %Forces the script to try use DLC data for antennal angles and proboscis extensions
    %Not currently a "DLC or Bust" setting but might become that later down the line
end

%dataFrameRate = 30.0 %Used for conversion from frames to seconds (NOTE: WILL BE DISABLED ONCE AUTODERIVING FULLY FUNCTIONAL)
autoDeriveFrameRate = 1;
if autoDeriveFrameRate ~= 1
    assumedDataFrameRate = 30.0 %Used for conversion from frames to seconds
end

applyFilter = 0; %Whether to apply a Butterworth filter (1) or linear interpolation (2) to data (Currently only proboscis)
    %Note: Butterworth filtering can induce 'ringing' in very fast data spikes
if applyFilter ~= 0
    ftype= 1; %Only used by Butterworth (Determines whether to High or Low pass)
    %cutOffFreq = [1.5]; %Traditional value
    cutOffFreq = [10]; %Used by all
end
doFFT = doFFT %Moved up above
%(Specification moved above)
if doFFT == 1
    F = 0.05:0.01:1.5; %List of frequencies to sample
        %Note: With current smoothing on the 1s scale in place, it is not possible to identify movement of a higher frequency than 1Hz
    %processList and plotProcessList specification moved up above
    %processList = [{'xRight'},{'xLeft'}];
    %%processList = [{'xRight'},{'xLeft'}, {'probData'}]; %Note: If intending to use probData, it must be placed last to operate correctly with flattenRail
    %%plotProcessList = [{'rightThetaSmoothed'},{'leftThetaSmoothed'},{'probMetric'}];
        %Note: plotProcessList must be matched with processList
    %processList = [{'probData'}];
    %plotProcessList = [{'probMetric'}]; %Same as processList, but designed for later plotting
    timeSubStart = -9000; %Negative time in frames from timeSubEnd to start subsetting at
    timeSubEnd = 0; %Position in frames to end subset at (0 -> end, anything else -> frame number anything else)
        %Set both of these to -1 to not use this processing feature
    doSpectro = 1; %Whether to calculate and plot spectrograms for bouts
        %Note: Currently this flag is needed for complete operation of the script
    if doSpectro == 1
        %winSize = 840; %Size of rolling spectro window (/30 for seconds)
        %winOverlap = 420; %Size of rolling overlap
        winSize = 28; %Size of rolling spectro window; Now in seconds, converted with fs later on
        winOverlap = 0.5*winSize; %Size of rolling overlap; Now set to fraction of winSize
        %F = 0.05:0.01:1; %List of frequencies to sample
        %Fs = 30; %Sampling rate
        %%Fs = dataFrameRate; %Now using automatically derived value
        forceSynchronyOfRail = 0; %Whether to eliminate detected freq. peaks that are not present in both antenna (Note: Highly experimental)
        doProbSpectro = 1 %Whether to do spectro on proboscis data too
        if doProbSpectro == 1
            probF = 0.05:0.01:1.5;
            flattenRail = 0; %Whether to use subtract proboscis periodicity from antennal periodicity to reduce noise
            if flattenRail == 1
                flattenAllPEs = 0; %Whether to flatten based purely on presence of PE
            end
                %Note: These two methods superseded by new, aggressive ant. signal filtering
            probMeanThresh = 10; %Value to multiply average by for detecting PEs
            doBinaryParallel = 1; %Whether to calculate a parallel spectrogram from the sleep Rail (*Steins Gate theme intensifies*)
        end
    end
    doScram = 0; %Whether to temporally scramble bouts for internal control purposes
    %scramWinSize = 1; %Currently unused window for translocation window size
    doSNR = 1; %Whether to do SNR calculations and plots
    if doSNR == 1
        leakFraction = 0.004; %Roughly equivalent to 36/8192;
        ceilHz = 0.95; %Maximum frequency to search for SNR peak until
        if ceilHz >= max(F)
            ['## Alert: Incorrect F and/or ceilHz values specified ##']
            error = yes
        end
        %colours = 'rgbymck';
        colours = 'mbgrcyk';
        doSpecificFFTs = 0; %Whether to plot a big version/s of a specific FFT/SNR
        if doSpecificFFTs == 1
            specFFTList = [1;2]; %{IIDN,k}
        end
        SNRThresh = 2.0; %Threshold for what is a significant SNR peak (Previously 1.0 until 11/11/22)
        targetPerioFreqRange = [0.05,1.5]; %Min and max values for detected SNR peaks to be considered as 'periodicity'
        %targetPerioFreqRange = [0.05,0.15];
    end
    minSafeLength = 8 * (max(F) / min(F)); %A bout shorter than this cannot be properly FFT'd
                                         %(This result is approximately eight times the lowest frequency component being searched for)
    stateColours = 'rbg'; %Specific colour set for states (Will crash if more than 3 states)
end
useControl = 0 %Whether to import a dead fly dataset as a control
if useControl == 1
    %controlPath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\SavOut\deadFly control'
    controlPath = [dataPath, filesep, 'deadFly control']; 
end
doTimeCalcs = 1; %Whether to analyse for events over time, such as proboscis extensions
    %Note: Cannot be feasibly disabled without crashing large downstream portions of the code
if doTimeCalcs == 1
%    colourz = jet(24); %Hardcoded 24 possible colours for scatter display
    splitMode = 2; %What way to segment the night into (1 = Equal 'portions', 2 = By hour)
    nightTimeStart = 19; %Currently fixed
    nightTimeEnd = 32; %Currently fixed
    if splitMode == 1
        porSplit = 4; %How many portions to split the night into (starting and ending at arbitrary points (Currently))
        timeSplit = [nightTimeStart:((nightTimeEnd-nightTimeStart)/porSplit):nightTimeEnd]; %How many segments to split the night into (centred around the middle ZT occurence; Must be continuous and starting at 1)
        sliceBouts = 1; %Whether to 'slice' out bouts that occurred before/after nighttime from combined/pooled analysis
    else
        timeSplit = [nightTimeStart:1:nightTimeEnd]; %What hours to split data by (can technically be discontinuous but cannot be repetitious)
        sliceBouts = 0; %This *must* be zero for this mode of operation
    end
    scatterMode = 1; %How to do colours for scatter augmentation to bar plots (1 = coloured per X position, 2 = coloured per fly)
    sleepCurveZT = [{'17'},{'18'},{'19'},{'20'},{'21'},{'22'},{'23'},{'00'},{'01'},{'02'},{'03'},{'04'},{'05'},{'06'},{'07'},{'08'},{'09'},{'10'},{'11'}]; %Range of values to bin sleep curves by
        %Note: If this is discontinuous, certain plots will be critically affected
    sleepCurveZTNums = [];
    for i = 1:size(sleepCurveZT,2)
        sleepCurveZTNums(i) = str2num(sleepCurveZT{i});
    end
    noSleepBehaviour = -1; %Whether to use the overall mean as a stand-in value for instances of <X> / <zero sleep> (1), zeroes (0) or NaNs (-1)
    %Esoteric prob-related parameters
    probInterval = 1.25; %Minimum time (s) between proboscis extensions for findPeaks (Previously 1.5)
    contiguityThreshold = 4.8; %Maximum number of probIntervals separation to allow before splitting a PE spell (Was 4 previously, 4.8 now to give same threshold of 6s)
    minRaftSize = 8; %Minimum number of PEs required for a spell to be considered a spell (Inclusive from Mk 7 onwards)
    minProbPeakHeight = 5; %Minimum contour size (or hypotenuse distance, depending on data usage) for thresholding findpeaks with (Note: This value does not scale according to measurement)
    useMaxPeakHeight = 0; %Whether to restrict peaks to a maximum height (Note: Liable to reduce true positives but might be necessary for certain noisy DLC cases); Only currently deployed on rollingFindPeaks
        %Note: The use of this is not recommended, since it just turns one too-high peak into two almost-too-high peaks
            %Secondary note: This is actually not a critical error, since findpeaks seems to ignore these one-sided cliffs, but it is still less than optimal
    if useMaxPeakHeight == 1
        dlcMaxPeakHeight = 75; %Somewhat arbitrary
        sriMaxPeakHeight = 300; %Again, arbitrary
    else
        dlcMaxPeakHeight = Inf; 
        sriMaxPeakHeight = Inf;
    end
    meanBinSizeFactor = 1; %How many times the dataFrameRate to bin data for averaging purposes
    rollingFindPeaks = 1; %Whether to use binning for findpeaks rather than applying to entire bout at once (1 for binning, 0 for no binning). Note: Experimental
    if rollingFindPeaks == 1
        finderBinSize = 10; %Size (seconds) to split bouts into for spell detection (multiplied by dataFrameRate to get index values)
        cleanMean = 1; %Whether to employ aggressive mean cleaning techniques
        if cleanMean == 1
            cleanFraction = 0.25; %"Flatten highest 25% of values per bin"
        end
    end
    doIndividualPEPlot = 0; %Whether to do a slow plot that iterates through all detected sleep bouts and each PE within said bouts, for *each* fly
    splitSpells = 0; %Whether to do splitting and analysis on spells
    if splitSpells == 1
        splitCoords = [0,50; 75,125; 150,200]; %Split bins (seconds)
        maxRelRange = 1000; %Sets the range to which the data will be upsampled (or less commonly, downsampled) for display of relative time plots
            %I.e. With a maxRelRange of 1000 a 10s spell will be split into chunks of 0.01s, while a 1000s spell would be split into chunks of 1s
    end
    useExclusionCriteria = useExclusionCriteria; %Whether to (try) exclude non-PEs
    %useExclusionCriteria = 1; %Whether to (try) exclude non-PEs
    if useExclusionCriteria == 1
        centTol = 0.02; %Tolerance for centroid position deviation of Gaussian peaks
        %doGaussExclusion = 0; %Whether to use a Gaussian fitting method to exclude oddly shaped peaks (Note: V. slow at quantities of scale (0.1s per peak tested)) [Traditionally 0]
        doGaussExclusion = doGaussExclusion;
        %doBSnrExclusion = 1; %Whether to use bootleg SNR calculations for exclusion [Traditionally 1]
        doBSnrExclusion = doBSnrExclusion;
        if doBSnrExclusion == 1
            %bootlegSNRThresh = 2; %Noise level factor for bootleg SNR exclusion (i.e. A value of 2 means that the signal must have twice as much relative signal than the noise)
            bootlegSNRThresh = 3;
                %Note: Values too high will bias towards detection of PEs during low noise conditions (e.g. Inactivity)
                    %Qualitative values from legacy data (30 01 19) indicate typical sleep PE ratio of 4.5x 
        end
        %doLonesomeExclusion = 0; %Whether to exclude peaks that have other significant peaks within their window [Traditionally 0]
        doLonesomeExclusion = doLonesomeExclusion;
            %Note: probInterval provides a measure of lonesome protection by ensuring a minimum separation of probInterval seconds between peaks, with or without lonesome
        doNotActuallyExclude = 0; %Bug-testing/display switch for enabling display of peaks that *would* have been excluded
        if doNotActuallyExclude == 1
            displayTestatoryFigure = 0; %Whether to also go and display an iterating, single-PE plot showing which PEs would have been excluded and why
        end
        %doTooFastExclusion = 0; %Whether to exclude PEs that happen too fast (according to an arbitrary threshold) [Traditionally 0]
        doTooFastExclusion = doTooFastExclusion;
        if doTooFastExclusion == 1
            tooFastThresh = 0.2; %If the full PE occurred in less time (s) than this, exclude it
        end
        %doWExclusion = 1; %Whether to exclude peaks with an insufficient Width [Traditionally 1]
        doWExclusion = doWExclusion;
        if doWExclusion == 1
            wExclusionThreshFactor = 2; %Since W scales with framerate, this value will be used to calculate the W threshold [Traditionally 3]
                %For data with a framerate of 30FPS, a value of 3 will give a W thresh of 10 frames (i.e. "Width of at least 0.33s")
        end
        %doTooHighExclusion = 1; %Whether to exclude peaks that are too high (Also excludes peaks that have a too-high element anywhere inside their probInterval) [Traditionally 1]
        doTooHighExclusion = doTooHighExclusion;
        if doTooHighExclusion == 1
            dlcTooHeight = 75; %Numbers pulled from historical useMaxPeakHeight values
            sriTooHeight = 300; 
        end
        %doInstChangeExclusion = 1; %Whether to exclude peaks that have an instantaneous change anywhere in their window of more than a threshold [Traditionally 1]
        doInstChangeExclusion = doInstChangeExclusion;
        if doInstChangeExclusion == 1
           %instChangeThreshold = 2025; %This value will be divided by the framerate and is calculated to give a per-frame movement of 45px(?) at 45FPS, and corresponding values for other recording framerates
           instChangeThresholdFrac = 0.75; %Max diff will be calculated as a frac. of the highest possible change and any PE with a diff that exceeds this will be excluded
            %i.e. A PE with two points that rose 80% of the max height in a single frame will be excluded etc
            %Note: Only tested on DLC prob. data
            %Secondary note: May lead to exclusion of true PEs which happen to have artefacts in their data, but that is probably acceptable
        end
    end
    %rollBinSize = 5*60*dataFrameRate; %Duration over which to calculate average PEs/min (in frames)
    %groupFactor = 3; %How many groups to separate certain data into (Namely the splitting of PE counts into ZT bins)
    groupFactor = 9; %How many groups to separate certain data into (Namely the splitting of PE counts into ZT bins)
    peBinaryExpansionFactor = 10; %How many times to 'expand' PE point occurence data for visual display in binary plots
    %Alternative PE detection parameters
    doAltDetection = doAltDetection;
    if doAltDetection == 1
        if useManualAltThresholds ~= 1
            alternativeNoiseThresh = 1.5; %How many SD above mean probMetric needs to be to be counted as an event
                %A lower threshold is actually preferred here, since minSize/etc will remove short, very sharp anomalous spikes
        end
        alternativeMinSize = 0.5; %Minimum size of a prob event (in s)
            %Stitching max size will be also calculated from this
        %altAngGroups = altAngGroups; %As describe above; Deprecated with overAltAngGroups
        rollingAltBaselineCorrection = 1; %Whether to correct the metric/s used alt detection across time
            %This will act by calculating the median probMetric at intervals of rollCorrInterval, interpolating between those, and then subtracting that from probMetric/etc 
                %Note: A very short rollCorrInterval will lead to PEs unduly affecting the median, thus decreasing the likelihood of PE detection
                %Secondary note: Qualitative evidence indicates that 'true' PE events are separate from the noise level, thus adjusting the baseline may in fact lower their true peak distance/amplitude 
        if rollingAltBaselineCorrection == 1
            rollCorrInterval = 60; %Time in seconds between keyframes
        end
        arbitraryPlotDuration = 10; %How many seconds to cut duration plots off at (Does not affect analysis; Just plotting)
    end
end
wipeProbStarts = 0; %Whether to engage a small loop that neutralises proboscis activity that was already occuring at the start of a bout
splitBouts = splitBouts; %Whether to split bouts into segments (by altering inStruct)
%(Specification moved above)
if splitBouts == 1
    %{
    if doTimeCalcs == 1
        splitBouts = 0; %Force override
        ['## Alert: Time calcs and bout splitting cannot be concomittantly active; Bout splitting disabled ##']
    end
    %}
    %numSplits = 3; %How many segments to split each bout into (Deprecated on account of splitDurs being decomposed for this number)
    splitDurs = [60, 60, NaN, 60, 60]; %Time duration of each bout split (Must be synchronised with numSplits; Write as all NaNs if mathematically equal splits (Default)
    %%splitDurs = [300, NaN]; 
        %Note: A mix of times and consecutive NaNs are not allowed, as is splitting into less than 3 parts if time is to be used
    splitDursText = [{'1st min.'},{'2nd min.'},{'Middle mins'},{'2nd last min.'},{'Last min.'}];
    %%splitDursText = [{'1st 5 min.'},{'Remaining min.'}];
    captureAllSlices = 0; %Whether to make artificial slices in the event that data would otherwise be lost by splitDurs that do not add up to the exact bout length
    if sum(isnan(splitDurs)) ~= size(splitDurs,2) && sum(isnan(splitDurs)) ~= 0 %"splitDurs is not all NaNs nor is it all rigid times"
        contiguousTimeSplits = 1; %Whether to choreograph splits to be contiguous with each other
            %i.e. "Min. 1, Min. 2, Min. Middle, Second-last Min., Last Min."
        if contiguousTimeSplits == 1
            captureAllSlices = 0; %Not a switch; Forced override here to avoid interfence
        end
    else
        contiguousTimeSplits = 0; %Not a switch; Overriden here to avoid interference
    end
end
analyseWake = 0; %Whether to adjust inStruct to focus on wake rather than sleep
if analyseWake == 1
    shiftFactor = 1; %How far to shift bouts by (i.e. A factor of 1 means "1 times" as in, a 20 min bout will be shifted rearwards 20 mins)
end
suppressIndivPlots = 0; %Whether to suppress all the individual plots that can clutter up everything
doDurs = 0; %Whether to calculate duration-based metrics (Note: This is mutually exclusive with splitBouts)
if doDurs == 1
    durBins = [0,600,1200,1800]; %Exclusive on low end, inclusive on high end
end
targPEs = [{'inBoutPEsLOCS'},{'outBoutPEsLOCS'}]; %Defines PE targets for averaged plots (will be pulled from allPEStruct)
targPEsIndex = [{'inBouts'},{'outBouts'}]; %Corresponds with targetPEs (Manual synchronisation necessary)
normalisePEs = 0; %Whether to not normalise PEs (0) or normalise by mean of max PE amplitude per all PEs of given target (1) (Only applies to final PE trace plot, not anything preceding)
normalisePEsIndex = [{'Not normalised'},{'All PE max mean normalised'}];
baselineCorrectPEs = 1; %Whether to correct PEs (in certain plots) to zero based on overall minimum (And PE coords to a start of 0)
alphaValue = 0.05; %Used for some stats
cutOffDataAt8H = 1; %Whether to cut off data at 8h to match ephys sleep recordings
    %Note: Only applies to certain late plots
colourDictionary = [{'b'},{'r'},{'k'},{'m'},{'c'}]; %Used for auto colouring certain plots (Reordered)
%-------------

if automatedSaveWorkspace == 1
    flagList = who;
end

%Suppress warnings
warning('off', 'signal:findpeaks:largeMinPeakHeight');

%-------------
%Pre-flight checks
if exist(dataPath) ~= 7 %A return of 7 means a directory
    ['### ALERT: INVALID DATA PATH SPECIFIED ###']
    error = yes
end

if savePlots == 1 || automatedSavePlots == 1
    %%%%
    %Check if figure folder exists and if not, make one
    ping = dir([figPath]);
    if isempty(ping) == 1
        mkdir(figPath);
    end
    %%%%
    if automatedSavePlots == 1 & automatedSaveVectors == 1
    %%%%
    %Check if figure folder exists and if not, make one
    ping = dir([vectorAutoFigPath]);
    if isempty(ping) == 1
        mkdir(vectorAutoFigPath);
    end
    %%%%    
    end
end

%QA
if subPlotMode == 2 && savePlots == 1
    ['### Warning: Scrolling subplots selected to be used but also saved, which may lead to odd output ###']    
end

%Load all .mat files in dataPath folder
overVar = struct;
%%listAAFiles = dir([dataPath, '\', '*.mat']); %List of detected Automated Analysis output files
listAAFiles = dir([dataPath, '\', '*_analysis.mat']); %List of detected Automated Analysis output files
if isempty(listAAFiles) == 1
    ['## Alert: No inStruct files found ##']
    error = yes    
end
%Load control file/s
if useControl == 1
    overCont = struct;
    c = 1; %Iterator for controls
    listContFiles = dir([controlPath, '\', '*.mat']); %List of detected Automated Analysis output files
    if isempty(listContFiles) == 1
        ['## Alert: No control file/s found ##']
        %%error = yes %Probably unnecessary to crash for this reason
    end
    listAAFiles = [listAAFiles; listContFiles]; %Append control to main files list for ease of import
end

['-- ',num2str(size(listAAFiles,1)), ' files detected; Attempting to load --']

%Check for mismatch between certain alt detection params and number of files
if doAltDetection == 1 
    if useManualAltThresholds == 1
        if size(manThreshes,2) ~= size(listAAFiles,1)
            ['## Alert: Mismatch between specified number of manual thresholds and detected files ##']
            crash = yes
        end
    end
    if exist('overAltAngGroups') ~= 1 || isempty(overAltAngGroups) == 1
        ['# overAltAngGroups not specified; Generating default #']
        overAltAngGroups = repmat( {{ [300-40,300],[301,301+40] }} , 1, size(listAAFiles,1) );
    end
end

successFiles = 0;
for i = 1:size(listAAFiles,1)
    %Check for whether control before proceeding
    isControl = 0; %Keeps track of whether current file is a control dataset
    if useControl == 1
        contHit = 0;
        for contInd = 1:size(listContFiles,1)
            contFound = strfind(listAAFiles(i).name,listContFiles(contInd).name);
            if isempty(contFound) ~= 1 
                contHit = contHit + 1;
            end
        end
        if contHit == 1 %Should be normal case
            disp(['-- Following dataset detected to be control --'])
            isControl = 1;
        elseif contHit > 1 %Duplication of control dataset, etc
            ['## Critical overfind error in control detection ##']
            error = yes
        end
    end
    
    overVar(i).fileDate = listAAFiles(i).name(1:end-4);
    successVars = 0;
    for IIDN = 1:size(loadVarList,2)
        preLoad = [];
        if isControl == 0
            preLoad = load(strcat([dataPath, '\',listAAFiles(i).name]),loadVarList{IIDN});
        else
            preLoad = load(strcat([controlPath, '\',listAAFiles(i).name]),loadVarList{IIDN});
        end
        try %If variable existed in loaded file
            kuAy = preLoad.(loadVarList{IIDN}); %"QA"
            overVar(i).(loadVarList{IIDN}) = preLoad.(loadVarList{IIDN});
            successVars = successVars + 1;
        catch %Will catch when variable did not in fact exist
            disp(['## Warning: Variable ', (loadVarList{IIDN}) ,' could not be loaded from file ', overVar(i).fileDate,' ##'])
            preLoad = [];
            overVar(i).(loadVarList{IIDN}) = [];
            successVars = successVars;
        end
    end
    
    overVar(i).controlState = isControl;

    %If control, mirror data to control structure
    if isControl == 1
        %%overCont(c) = overVar(i);
        oVarNames = fieldnames(overVar); %Get overVar fieldnames
        for z = 1:size(oVarNames,1)
            overCont(c).(oVarNames{z}) = overVar(i).(oVarNames{z});
        end
        c = c + 1;
    end
    
    if successVars == size(loadVarList,2) %All variables loaded correctly
        successFiles = successFiles + 1;
    else
        successFiles = successFiles; %Not all variables loaded correctly
    end
    disp(['-- Successfully loaded file ',overVar(i).fileDate, ' (', num2str(i), ' of ', num2str(size(listAAFiles,1)), ') --'])
end

['--- ',num2str(successFiles),' out of ', num2str(size(listAAFiles,1)),' loaded completely successfully ---']

%Analysis duplication QA
for i = 1:size(overVar,2)
    nameHits = 0;
    for x = 1:size(overVar,2)
        if isempty(strfind(overVar(x).flyName,overVar(i).flyName)) ~= 1
            nameHits = nameHits + 1;
        end
    end
    if nameHits > 1
        ['### Alert: Probable duplication of analysis detected ###']
        overVar(i).flyName
        error = yes
    end
end

%Load bodystruct (if applicable)
if loadBodyStruct == 1
    %Find and load bodyStruct
    temp = dir( [dataPath,filesep,'bodyCoords.mat'] );
    if isempty( temp ) == 1
        ['## Error: Could not find bodyStruct file ##']
        crash = yes %May in future make this non-critical
    else
        load( [temp.folder,filesep,temp.name] )
        disp(['-- bodyStruct loaded successfully --'])
    end
    %Pre QA
        %Deprecated now with bodyStruct element removal
    %{
    if size( listAAFiles,1 ) ~= size( bodyStruct,2 )
        ['## Alert: Number of files in bodyStruct does not match detected dataset count ##']
        crash = yes %This is more of an issue
    end
    %}
    %Find position of overVar elements in bodyStruct
    reOrder = [];
    for IIDN = 1:size(overVar,2)
        isFound = 0;
        for i = 1:size(bodyStruct,2)
            if contains( bodyStruct(i).fileDate, overVar(IIDN).fileDate ) == 1
                %Pre QA in case of overfind
                if isFound == 1
                    ['## Alert: bodyStruct overfind ##']
                    crash = yes
                end
                reOrder = [reOrder,i];
                isFound = 1;
            end
        end
    end
    %Cut down bodyStruct (if necessary)
    bodyStruct = bodyStruct(reOrder);
    
    %QA to ensure bodyStruct actually contributing useful information
    if size(bodyStruct,2) == 0
        ['## Alert: bodyStruct contains no data relevant to these save files ##']
        crash = yes
    end
end

%Old-style data (pre-BASE generalisation) correction
for i = 1:size(overVar,2)
    if isfield(overVar(i).overGlob,'BaseFrameTime') ~= 1 && isfield(overVar(i).overGlob,'DorsFrameTime') == 1
        disp(['#- Dataset ',num2str(i), ' (',overVar(i).fileDate,') does not contain BaseFrameTime; DorsFrameTime used instead -#', ])
            %Old data
        overVar(i).overGlob.BaseFrame = overVar(i).overGlob.DorsFrame;
        overVar(i).overGlob.BaseFrameTime = overVar(i).overGlob.DorsFrameTime;
        overVar(i).overGlob.BaseFrameRef = overVar(i).overGlob.DorsFrameRef;
        overVar(i).overGlob.firstBaseFrameTimeIdx = overVar(i).overGlob.firstDorsFrameTimeIdx;
        overVar(i).overGlob.firstBaseFrameTimeTime = overVar(i).overGlob.firstDorsFrameTimeTime;
        overVar(i).overGlob.firstBaseFrameTimeTimeDate = overVar(i).overGlob.firstDorsFrameTimeTimeDate;
        overVar(i).inStruct.holeRangesBaseFrameMatched = overVar(i).inStruct.holeRangesDorsFrameMatched;
    end
    %{
    if isfield(overVar(i).overGlob,'BaseFrameTime') == 1 && isfield(overVar(i).overGlob,'DorsFrameTime') ~= 1
        disp(['#- Dataset ',num2str(i), ' (',overVar(i).fileDate,') does not contain DorsFrameTime; BaseFrameTime used instead -#', ])
            %New data (Note: This is a stopgap measure in lieu of switching to a dependency on switching to BaseFrameTime)
        overVar(i).overGlob.DorsFrame = overVar(i).overGlob.BaseFrame;
        overVar(i).overGlob.DorsFrameTime = overVar(i).overGlob.BaseFrameTime;
        overVar(i).overGlob.DorsFrameRef = overVar(i).overGlob.BaseFrameRef; 
    end
    %}
end

%Back-calculate dataFrameRate
for i = 1:size(overVar,2)
    if autoDeriveFrameRate == 1
        temp = diff(overVar(i).overGlob.BaseFrameTime); %All inter-frame timing differences
        temp = 1.0 ./ temp;
        prosFR = nanmedian( temp );
        %QA
        if nanstd( temp ) > 0.05*prosFR
            disp( ['-# Caution: More than 5% variability (',num2str(nanstd( temp ), 3),'fps) in derived framerate for ',overVar(i).fileDate,' #-'] )
            %crash = yes %Maybe don't crash later, but for the moment it's not safe to use an assumed value that may be horribly wrong
            %overVar(i).dataFrameRate = assumedDataFrameRate;
            %proceed = input(' Proceed? (0/1) ');
            %if proceed == 0
            %    halt = yes
            %end
        end
        %overVar(i).dataFrameRate = round(prosFR); %Less float problems, but will reduce accuracy
        overVar(i).dataFrameRate = prosFR; %Note: Might be potential complications with float framerate
        overVar(i).dataFrameRateInteger = round(prosFR); %Integer, for use where float is an issue
    else
        overVar(i).dataFrameRate = assumedDataFrameRate;
    end
end

%%

%Compilate useful metrics
['--- Beginning data processing ---']

colourz = jet(size(overVar,2));
colourW = winter(size(overVar,2));
colourS = spring(size(overVar,2));
colourMegaZord = ( colourz + colourW + colourS ) / 3;

colourProcesses = jet(size(processList,2));

%--------------------------------------------------------------------------
%Adjust inStruct if analysing wake
if analyseWake == 1
    for IIDN = 1:size(overVar,2)
        inStruct = overVar(IIDN).inStruct;
        wakeStruct = struct;
            %Note: This uses the inverse of inStruct to label activity bouts
                %If it works correctly, all frames should exist in either inStruct or wakeStruct at some point
        nTerminus = [size(overVar(IIDN).overGlob.movFrameTime,1), size(overVar(IIDN).avProbContourSizeSmoothed,1), size(overVar(IIDN).rightThetaProc,1)];
        
        for bout = 1:size(inStruct.holeRanges,2) + 1
            if bout == 1 %Pre-first bout
                searchRange = [1:inStruct.holeStarts(bout)-1]; %Will search from frame 1 to start (non-inclusive) of first sleep bout for non-NaN               
            elseif bout == size(inStruct.holeRanges,2) + 1 %Post-last bout
                %searchRange = [inStruct.holeEnds(bout-1)+1:size(overVar(IIDN).overGlob.movFrameTime,1)]; %Search from end of last bout to end of data
                searchRange = [inStruct.holeEnds(bout-1)+1:min(nTerminus)]; %Search from end of last bout to end of data (Uses the smallest value of the involved data)
                    %Note: There are no checks for synchronisation currently for avProbContourSizeSmoothed reference frames vs movFrameTime reference frame/etc
            else %Every other bout
                searchRange = [inStruct.holeEnds(bout-1)+1:inStruct.holeStarts(bout)-1]; %Search from end of previous bout to start of current bout
            end
            searchIDs = overVar(IIDN).overGlob.movFrameTime(searchRange);
            firstNonNaNMovFrameInd = find(isnan(searchIDs) ~= 1,1,'First'); %Ensure not starting padded with NaNs
            lastNonNaNMovFrameInd = find(isnan(searchIDs) ~= 1,1,'Last'); %Ensure not ending on NaNs
            
            wakeStruct.holeStarts(bout) = searchRange(firstNonNaNMovFrameInd); %Take end of previous bout as start
            wakeStruct.holeEnds(bout) = searchRange(lastNonNaNMovFrameInd); %Use start of this bout as end of wake bout
                %Note: The indexing of searchRange here is key to countering the fact that find returns the index within searchRange, not overall
            
            wakeStruct.holeSizes(bout) = wakeStruct.holeEnds(bout) - wakeStruct.holeStarts(bout); %May not match perfectly with holeRanges
            wakeStruct.holeRanges{bout} = [wakeStruct.holeStarts(bout):wakeStruct.holeEnds(bout)];
            wakeStruct.holeStartsTimes{bout} = datestr(datetime(overVar(IIDN).overGlob.movFrameTime(wakeStruct.holeStarts(bout)), 'ConvertFrom', 'posixtime'));
            wakeStruct.holeEndsTimes{bout} = datestr(datetime(overVar(IIDN).overGlob.movFrameTime(wakeStruct.holeEnds(bout)), 'ConvertFrom', 'posixtime'));
            wakeStruct.holeSizesSeconds(bout) = overVar(IIDN).overGlob.BaseFrameTime(wakeStruct.holeEnds(bout)) - overVar(IIDN).overGlob.BaseFrameTime(wakeStruct.holeStarts(bout));
            %wakeStruct.holeStartsZT(bout) = str2num(wakeStruct.holeStartsTimes{bout}(end-7:end-6)) + (str2num(wakeStruct.holeStartsTimes{bout}(end-4:end-3)) / 60.0);
                %Pulls the ZT hour from holeStartsTimes and adds the minutes as fractions of the hour
        end
        
        overVar(IIDN).wakeStruct = wakeStruct; %Save data for overuse
        
        additionalFigParams = [additionalFigParams, '_Wake'];
    %IIDN end    
    end
%analyseWake end    
end
%--------------------------------------------------------------------------

%Split bouts if called for
if splitBouts == 1
    %----------------------------------------------------------------------
    %Assemble splitStruct
    for IIDN = 1:size(overVar,2)
        if analyseWake ~= 1
            inStruct = overVar(IIDN).inStruct; %"Not analysing wake -> Use original inStruct"
        else
            inStruct = overVar(IIDN).wakeStruct; %"Analysing wake -> Use inverted inStruct"
        end
        splitStruct = struct;
        splitStruct.splitRangeYs = [];
        a = 1;
        for bout = 1:size(inStruct.holeRanges,2)
            %Pre QA
            if nansum(splitDurs)*overVar(IIDN).dataFrameRate > size(inStruct.holeRanges{bout},2)
                ['## Error: Program requested to split bout into portions larger than bout itself ##']
                error = yes
            end
            if sum(isnan(splitDurs)) == size(splitDurs,2) %All NaNs
                %discPos = floor([1:size(inStruct.holeRanges{bout},2)/(size(splitDurs,2)):size(inStruct.holeRanges{bout},2),inStruct.holeSizes(bout)]); %Find numSplit+1 equally spaced indices along the holeRange (inclusive)
                    %Old format; Starts and ends overlap (i.e. ["Seg 1 start", "Seg 1 end/Seg 2 start", "Seg 2 end/Seg 3 start", "Seg 3 end"])
                for splitSeg = 1:size(splitDurs,2)
                    pos1It = (splitSeg-1)*2+1;
                    pos2It = (splitSeg)*2;
                    discPos(pos1It) = floor((splitSeg-1)*(size(inStruct.holeRanges{bout},2)/size(splitDurs,2))+1);
                    discPos(pos2It) = floor((splitSeg)*(size(inStruct.holeRanges{bout},2)/size(splitDurs,2)));
                        %New format; Exclusive starts and ends (i.e. ["Seg 1 start", "Seg 1 end", "Seg 2 start", "Seg 2 end", "Seg 3 start", "Seg 3 end"])
                            %(Ideally though these should be perfectly abutting)
                    %QA
                    if splitSeg > 1
                        if discPos(pos1It) ~= discPos((splitSeg-1)*2)+1 %"If start segment does not abutt with end of previous segment"
                            discPos(pos1It) = discPos((splitSeg-1)*2)+1; %If non-abutting, match to previous end + 1
                        end                        
                    end
                %splitSeg end    
                end                 
            else %Time-based bout splitting (Not all NaNs)

                %First stage
                discEd = [];
                for x = 1:size(splitDurs,2)
                    discEd(x,1:2) = NaN;
                end
                
                %Second stage
                for x = 1:size(splitDurs,2)
                    if isnan(splitDurs(x)) ~= 1
                        if x == 1
                            discEd(x,1:2) = floor([1,(splitDurs(x) * overVar(IIDN).dataFrameRate)*1]); %[1,<duration in frames>]
                        elseif x == size(splitDurs,2)
                            discEd(x,1:2) = floor([size(inStruct.holeRanges{bout},2) - (splitDurs(x) * overVar(IIDN).dataFrameRate)*1,size(inStruct.holeRanges{bout},2)]); %[end-<duration in frames>,end]
                        else
                            if contiguousTimeSplits ~= 1 || (contiguousTimeSplits == 1 && x-0.5 == size(splitDurs,2)/2)
                                centroidPos = ((x-1) * (size(inStruct.holeRanges{bout},2) / (size(splitDurs,2)-1)));
                                discEd(x,1:2) = floor([centroidPos - (splitDurs(x) * overVar(IIDN).dataFrameRate)*0.5, centroidPos + (splitDurs(x) * overVar(IIDN).dataFrameRate)*0.5]); %[<centroid>-<half duration in frames>,<centroid>+<half duration in frames>]
                            else
                                if x-0.5 < size(splitDurs,2)/2 %First half of data
                                    discEd(x,1:2) = floor([discEd(x-1,2)+1, discEd(x-1,2)+1 + (splitDurs(x) * overVar(IIDN).dataFrameRate)*1]); %[<end of previous segment>+1, <end of previous segment >+1+<duration in frames>]
                                        %Is not first split segement; Can use end of previous split segment as start of next (Accounts for variable split lengths)
                                elseif x-0.5 > size(splitDurs,2)/2 %Second half of data
                                    sumTimePos = size(inStruct.holeRanges{bout},2) - nansum(splitDurs(x:end))* overVar(IIDN).dataFrameRate; %Because iterating upwards, we will not know the details of the last split when doing the second to last split
                                                                                          %Thus, it is necessary to work out when the segment *should* be
                                    discEd(x,1:2) = floor([sumTimePos-1, sumTimePos + (splitDurs(x) * overVar(IIDN).dataFrameRate)*1 - 1]); %
                                        %Is not last split segement; Infer startpoint from sum of segments to follow
                                    %Quick QA to check validity of this inference
                                    if sum(isnan(splitDurs(x:end))) ~= 0
                                        ['## Alert: Attempted to infer segment sizes where NaNs present ##']
                                        error = yes %This designed to catch abnormal <time>,NaN orderings in splitDurs (i.e. [<time>,<time>,NaN,<time>,NaN,<time>])
                                    end
                                end
                            end
                        end
                    %isNan end    
                    end
                %splitDurs end    
                end
       
                %Third stage
                for x = 1:size(splitDurs,2)
                    if isnan(splitDurs(x)) == 1
                        if x == 1
                            discEd(x,1:2) = [1,discEd(x+1,1)-1]; %Free range first -> Use 1 as start and start of next fixed dur. split as end
                        elseif x == size(splitDurs,2)
                            discEd(x,1:2) = [discEd(x-1,2)+1,size(inStruct.holeRanges{bout},2)]; %Free range end -> Use end of previous fixed dur. as start and size as end
                        else
                            discEd(x,1:2) = [discEd(x-1,2)+1,discEd(x+1,1)-1]; %Free range middle -> Use end of previous and start of next as start and end respectively
                                %Note: This is critically weak to consecutive NaNs (avoidable)
                        end
                    end
                end
                
                %Third point fifth stage (optional)
                if captureAllSlices == 1
                    discEdCap = [];
                    discEdCap(1,1:2) = discEd(1,1:2);
                    b = 2;
                    for x = 2:size(discEd,1)
                        if discEd(x-1,2) ~= discEd(x,1)-1 %Non-contiguous split
                            discEdCap(b,1:2) = [discEd(x-1,2)+1,discEd(x,1)-1];
                            discEdCap(b+1,1:2) = [discEd(x,1),discEd(x,2)];
                            b = b + 2;
                        else
                            discEdCap(b,1:2) = [discEd(x,1),discEd(x,2)];
                            b = b + 1;
                        end
                    %x end    
                    end
                    discEd = discEdCap;
                end
                
                %Fourth stage
                discPos = [];
                %discPos = [1,discEd(:,2)'];
                for x = 1:size(discEd,1)
                    ind1 = ((x-1)*2)+1;
                    ind2 = ((x)*2);
                    discPos(1,ind1:ind2) = [discEd(x,1),discEd(x,2)];
                end
                
            %splitDurs end    
            end

            splitStruct.splitRangeYs{bout} = []; 
            for splitSeg = 1:size(discPos,2)/2
                %Find positions to split bout along
                pos1It = discPos((splitSeg-1)*2+1);
                pos2It = discPos((splitSeg)*2);
                splitStruct.splitRangeYs{bout}(1:2,splitSeg) = ...
                    [inStruct.holeRanges{bout}(pos1It),inStruct.holeRanges{bout}(pos2It)]'; %Rows represent start and end of new bouts as points in whole data length, columns are bout segments
                %   [inStruct.holeRanges{bout}(discPos(splitSeg)+1),inStruct.holeRanges{bout}(discPos(splitSeg+1))]'; %Rows represent start and end of new bouts as points in whole data length, columns are bout segments
                %if splitSeg == 1
                %    splitStruct.splitRangeYs{bout}(1,1) = splitStruct.splitRangeYs{bout}(1,1)-1; %Ugly, but it prevents the loss of the first data point
                %end
                
                splitStruct.FLID(1,a) = bout; %Row 1 - Original bout identity
                splitStruct.FLID(2,a) = splitSeg; %Row 2 - FLID identity
                splitStruct.FLID(3,a) = a; %Row 3 - New bout identity

                %Split bout
                splitStruct.holeStarts(a) = splitStruct.splitRangeYs{bout}(1,splitSeg); %Use first row of <bout> column to find start (units: all data)
                splitStruct.holeEnds(a) = splitStruct.splitRangeYs{bout}(2,splitSeg); %Ditto, but with second row as end
                splitStruct.holeSizes(a) = (splitStruct.holeEnds(a) - splitStruct.holeStarts(a)) + 1; %Calculate size from end - start
                %splitStruct.holeRanges{a} = inStruct.holeRanges{bout}(discPos(splitSeg):discPos(splitSeg+1)); %Assemble range by grabbing values from range (less assumptions than interpolation)
                splitStruct.holeRanges{a} = inStruct.holeRanges{bout}(pos1It:pos2It); %Assemble range by grabbing values from range (less assumptions than interpolation)
                splitStruct.holeStartsTimes{a} = datestr(datetime(overVar(IIDN).overGlob.BaseFrameTime(splitStruct.holeStarts(a)), 'ConvertFrom', 'posixtime')); %Use holeStart to find posix of first frame and convert to realtime
                splitStruct.holeEndsTimes{a} = datestr(datetime(overVar(IIDN).overGlob.BaseFrameTime(splitStruct.holeEnds(a)), 'ConvertFrom', 'posixtime')); %Ditto, for end
                splitStruct.holeSizesSeconds(a) = overVar(IIDN).overGlob.BaseFrameTime(splitStruct.holeEnds(a)) - overVar(IIDN).overGlob.BaseFrameTime(splitStruct.holeStarts(a)); %Subtract posix end from posix start
                %splitStruct.holeRangesDorsFrameMatched{a} = inStruct.holeRangesDorsFrameMatched{bout}(discPos(splitSeg):discPos(splitSeg+1)); %Pull dorsFrameMatched values from inStruct (If fails, probs because asymmetry)
                %splitStruct.holeRangesMovFrameMatched{a} = inStruct.holeRangesMovFrameMatched{bout}(discPos(splitSeg):discPos(splitSeg+1)); %Ditto, for mov
                splitStruct.holeRangesBaseFrameMatched{a} = inStruct.holeRangesBaseFrameMatched{bout}(pos1It:pos2It); %Pull BaseFrameMatched values from inStruct (If fails, probs because asymmetry)
                splitStruct.holeRangesMovFrameMatched{a} = inStruct.holeRangesMovFrameMatched{bout}(pos1It:pos2It); %Ditto, for mov
                %splitStruct.holeStartsZT(a) = str2num(splitStruct.holeStartsTimes{a}(end-7:end-6)) + str2num(splitStruct.holeStartsTimes{a}(end-4:end-3)) / 60.0; %Disabled on account of existing standalone further down

                a = a + 1;
            end

            %Quick QA
            if splitStruct.holeRanges{a-1}(end) ~= inStruct.holeRanges{bout}(end) %| sum(splitStruct.holeSizes(a-size(discPos,2)/2:a-1)) ~= inStruct.holeSizes(bout)
                ['### WARNING: ASYMMETRY PRESENT BETWEEN HOLERANGE ENDS BETWEEN ORIGINAL AND SPLIT BOUTS ###']
                error = yes %Note: 1 - 2 frame asymmetry might be 'normal' here with index integerising/etc
            end
            if sum(isnan(splitDurs)) > 0 && abs( sum(splitStruct.holeSizes(a-size(discPos,2)/2:a-1)) - inStruct.holeSizes(bout) ) > 0.01*inStruct.holeSizes(bout)
                ['### WARNING: SIGNIFICANT ASYMMETRY PRESENT BETWEEN HOLESIZES FOR MIXED ANALYSIS ###']
                error = yes %Note: 1 - 2 frame asymmetry might be 'normal' here with index integerising/etc
            end
        %bout end    
        end
        
        overVar(IIDN).splitStruct = splitStruct; %Save for overuse
    %IIDN end    
    end
    
    %----------------------------------------------------------------------
    
%splitBouts end    
end

%--------------------------------------------------------------------------
%Decide which version of inStruct to carry forwards
for IIDN = 1:size(overVar,2)
    if splitBouts == 1 %"Bouts split -> Use splitStruct regardless of whether sleep or wake"
        overVar(IIDN).inStructCarry = overVar(IIDN).splitStruct;
    elseif splitBouts ~= 1 && analyseWake == 1 %"Bouts not split and wake set to analyse -> Use wake"
        overVar(IIDN).inStructCarry = overVar(IIDN).wakeStruct;
    else %"All other cases -> Use original inStruct"
        overVar(IIDN).inStructCarry = overVar(IIDN).inStruct; %RESCUE TO over Var (IIDN) .in Struct;
    end
end
%--------------------------------------------------------------------------

%Post-hoc calculate bout start ZTs
for IIDN = 1:size(overVar,2)
    if isempty(fieldnames(overVar(IIDN).inStructCarry)) ~= 1 %Only really not applicable when analysing datasets that contain no detectable sleep bouts
        for i = 1:size(overVar(IIDN).inStructCarry.holeStartsTimes,2)
            %Adapted ZT calculation from splitStruct
            overVar(IIDN).inStructCarry.holeStartsZT(i) = str2num(overVar(IIDN).inStructCarry.holeStartsTimes{i}(end-7:end-6)) + str2num(overVar(IIDN).inStructCarry.holeStartsTimes{i}(end-4:end-3)) / 60.0;
        end
    end
end

%FFT
%disp(['-- Processing FFTs --'])
overFouri = struct;
if useControl == 1
    overFouriCont = struct;
    c = 1;
end

if applyFilter == 1
    if ftype == 1
        disp(['-- Data will be low-pass filtered with Butterworth at ',num2str(cutOffFreq(1,ftype)),'Hz --'])
    elseif ftype == 2
        disp(['-- Data will be high-pass filtered with Butterworth at ',num2str(cutOffFreq(1,ftype)),'Hz --'])
    end
end


%PE initialisation
probScatter = struct;
overExclude = struct;
overAllPE = struct;
for IIDN = 1:size(overVar,2)
    %%try    
        
        %%if doSpectro == 1 && doProbSpectro == 1
        %Will probs fail if prob doesn't exist
        if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
            probMetric = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisHyp;
            dlcProbStatus = '- DLC Prob.';
        else
            probMetric = overVar(IIDN).avProbContourSizeSmoothed;
            dlcProbStatus = '- Sri Prob.';
        end

        if nansum( isnan( probMetric ) == 1 ) > 0
            probMetric( isnan( probMetric ) == 1 ) = nanmean(probMetric);
            disp(['## Warning: NaNs had to be removed from probMetric ##'])
        end

        if applyFilter == 1
            %----------------------
            %Rhiannon
            %ftype= 1;
            %cutOffFreq = [1.5];
            %sampleRate=dataFrameRate;

            filtProbMetric = ButterworthFilt( probMetric', ftype, 10, cutOffFreq(1,ftype), overVar(IIDN).dataFrameRate);
            probMetric = filtProbMetric';
                %Note: Filtering the probMetric at such an early stage may have *significant* downstream effects
            clear filtProbMetric
            %----------------------
            %%end
            
            %%overVar(IIDN).probMetric = probMetric; %This stores whichever type of prob data was selected to be used
            %%overVar(IIDN).dlcProbStatus = dlcProbStatus;
        elseif applyFilter == 2
            notImplementedYet = yes
            %%[filtProbMetric, filT] = resample( probMetric, cutOffFreq , round( overVar(IIDN).dataFrameRate ) );
            %%probMetric = filtProbMetric';
            %%clear filtProbMetric
        end
        overVar(IIDN).probMetric = probMetric; %This stores whichever type of prob data was selected to be used
        overVar(IIDN).dlcProbStatus = dlcProbStatus;
        
        %PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
        %PE detection (New location Mk 7.55)
        %%for IIDN = 1:size(overVar,2)
        %if splitBouts ~= 1
        inStruct = overVar(IIDN).inStructCarry;
        %else
        %    inStruct = overVar(IIDN).splitStruct;
        %end

        %{
        if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
            probMetric = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisHyp;
        else
            probMetric = overVar(IIDN).avProbContourSizeSmoothed;
        end
        %}
        %%probMetric = overVar(IIDN).probMetric; %Redundant with shift to new location

        probScatter(IIDN).probEventsCount = []; 
        probScatter(IIDN).probStartTimes = [];
        probScatter(IIDN).probStartZT = [];
        %probScatter(IIDN).probEventsNorm = [];
        probScatter(IIDN).probEventsDur = [];
        probScatter(IIDN).probEventsDurProp = [];
        if forceUseDLCData ~= 1 | isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') ~= 1
            probScatter(IIDN).avProbContourSizeSmoothedEvent = zeros(size(probMetric,1)+overVar(IIDN).dlcSmoothSize+1,1);
            probScatter(IIDN).avProbContourSizeSmoothedEventRail = zeros(size(probMetric,1)+overVar(IIDN).dlcSmoothSize+1,1);
                %Not quite sure why the padding with dlcSmoothSize is needed here but whatever
        else
            probScatter(IIDN).avProbContourSizeSmoothedEvent = zeros(size(probMetric,1),1);
            probScatter(IIDN).avProbContourSizeSmoothedEventRail = zeros(size(probMetric,1),1);
        end
            %Replicates avProbContourSizeSmoothed except that no PE -> 0s and PEs -> 1s a la following sleep Rail processing
            %Note: Due to smoothing, this variable may be displaced from true timing by as much as dlcSmoothSize frames (i.e. 1s or so)
                %Secondary note: An improved method of smoothing that doesn't alter the final number of frames may redundify parts of this
            %Tertiary note: This variable only captures proboscis extensions occuring during bouts dictated by inStruct by virtue of limitation of range down lower to inStruct coordinates
            %eventRail captures all proboscis extensions, regardless of whether in bout or out bout, but may take a while to generate

        %%MEANavProbContourSizeSmoothed = nanmean(avProbContourSizeSmoothed); %NOTE: avProbContourSizeSmoothed is not limited to sleep bouts, thus this mean comes from waking activity as well
            %This variable deprecated but might be useful in future if DLC is used for PE calculations during waking activity
        %{
        %This method deprecated because slow
        for i = 1:size(avProbContourSizeSmoothed,1) %May be slow
            if avProbContourSizeSmoothed(i) > MEANavProbContourSizeSmoothed*0.5
                 probScatter(IIDN).avProbContourSizeSmoothedEventRail(i,1) = 1; %"PE is occurring -> Set PERail to 1 in this location"
            end
        end
        %}
        avProbContourSizeSmoothedRestricted = zeros(size(probMetric,1),1); %This will eventually be a copy of prob. contour sizes that is only non-nan when bouts were occurring
        avProbContourSizeSmoothedRestricted(avProbContourSizeSmoothedRestricted == 0) = NaN; %A bit of an ugly way to make a big NaN array but nans(10,1) doesn't exist AFAIK so...
        for holeNum = 1:size(inStruct.holeSizes,2)
            avProbContourSizeSmoothedRestricted(inStruct.holeRanges{holeNum}) = probMetric(inStruct.holeRanges{holeNum}); 
            %Populate the restricted version of avProbContourSizeSmoothed only when sleep bouts occurring
        end
        meanAvProbContourSizeSmoothedRestricted = nanmean(avProbContourSizeSmoothedRestricted); %Mean of prob. contour sizes only during sleep bouts
            %Note: The value of this differs from the unrestricted mean by a factor of 30 or so (i.e. restricted detected mean of 5px vs unrestricted detected mean of 175px)    

        probScatter(IIDN).avProbContourSizeSmoothedEventRail(avProbContourSizeSmoothedRestricted > meanAvProbContourSizeSmoothedRestricted) = 1;

        %Pre-define some spells-related structure fields
        probScatter(IIDN).spellsPooled.matchingContigHoleNum = [];
        probScatter(IIDN).spellsPooled.matchingContigSizesPooled = [];
        probScatter(IIDN).spellsPooled.matchingContigStartEndPooled = [];
        probScatter(IIDN).spellsPooled.matchingContigStartEndAbsolutePooled = [];
        probScatter(IIDN).spellsPooled.matchingContigPEsPos = [];
        probScatter(IIDN).spellsPooled.matchingContigFreqs = [];

        %------------------------------------------------------------------
        %------------------------------------------------------------------
        disp(['-- Finding all PEs for file number ', num2str(IIDN) ,' --'])
        %Find all PEs, irrespective of within bout or not
        %boutData = probMetric(inStruct.holeRanges{holeNum});
        boutData = probMetric;
        allPEStruct = struct;

        x = 1;
        %binSpecs = finderBinSize*overVar(IIDN).dataFrameRate;
        binSpecs = finderBinSize*overVar(IIDN).dataFrameRateInteger;
        PKS = []; LOCS = []; W = []; P = []; rollingFinderMean = [];
        for rollInd = 1:binSpecs:size(boutData,1)
            binCoords = [ 1 + (x - 1) * binSpecs : x * binSpecs ]; %Specify search coords
            binCoords( binCoords > size(boutData,1) ) = [];
            subData = boutData(binCoords(1):binCoords(end));
            if useMaxPeakHeight == 1
                if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                    subData( subData > dlcMaxPeakHeight ) = NaN; %Using DLC data
                else
                    subData( subData > sriMaxPeakHeight ) = NaN; %Using Sri data
                end
            end
            dataForNanmean = subData;
            if cleanMean == 1
                [~, indFor] = sort(subData, 1, 'descend');
                dataForNanmean( indFor( 1:floor(cleanFraction*size(subData,1)) ) ) = NaN;
            end
            targetThresh = nanmean(dataForNanmean) + minProbPeakHeight;
            minimalPeakSeparation = overVar(IIDN).dataFrameRate*probInterval; %Specifying here to simplify later referencing
            if size(subData,1) > minimalPeakSeparation %Necessary because findpeaks has a minimum data size
                try
                    [tempPKS,tempLOCS,tempW,tempP] = findpeaks(subData, 'MinPeakDistance', minimalPeakSeparation, ...
                        'MinPeakHeight', targetThresh);
                        %Note: This rolling mean may drastically reduce the true positive rate during situations of actual proboscis extension
                            %(Since during these times the value may be rapidly fluctuating in time with the proboscis)
                catch
                    [tempPKS,tempLOCS,tempW,tempP] = findpeaksbase(subData, 'MinPeakDistance', minimalPeakSeparation, ...
                        'MinPeakHeight', targetThresh);
                        %Same as above, except for cases where fieldtrip or others might be interfering with 'findpeaks'
                end

                PKS = [PKS; tempPKS]; LOCS = [LOCS; tempLOCS + binCoords(1)]; W = [W; tempW]; P = [P; tempP];
                    %Note: tempLocs + binCoords(1) is crucial to maintaining correct rolling reference frame
                        %Without + binCoords, LOCS has the index reference frame of the bin rather than the bout
                tempPKS = []; tempLOCS = []; tempW = []; %Completely redundant with current structure but a good reminder
            end
            rollingFinderMean = [rollingFinderMean; targetThresh, binCoords(1), binCoords(end)]; %Note: Placing this outside if-size may cause asynchrony

            x = x + 1;
        end

        if useExclusionCriteria == 1
            exclusionStruct = struct;
            gaussExcludeList = zeros(size(LOCS,1),1); %Iterative list that at end will be used to wipe failing PEs
            bSNRExcludeList = zeros(size(LOCS,1),1); %Ditto, but from BSnr data
            lonesomeExcludeList = zeros(size(LOCS,1),1); %Ditto, but from lonesome data
            tooFastExcludeList = zeros(size(LOCS,1),1); %Ditto, but from too-fast data
            wExclusionList = zeros(size(LOCS,1),1); %Ditto, but from cleanW data
            tooHighExcludeList = zeros(size(LOCS,1),1); %Ditto, but from tooHigh data
            instChangeExcludeList = zeros(size(LOCS,1),1); %Ditto, but from instChange data

            %Testatory exclusion figure
            %%figure

            %Calculate a necessary value
            if doWExclusion == 1
                wExclusionThresh = floor( overVar(IIDN).dataFrameRate/wExclusionThreshFactor ); %Floor to make it a little fairer on the int W values
            end

            for contigInd = 1:size(LOCS,1)
                exclusionStruct(contigInd).LOCabs = LOCS(contigInd);
                %Fit Gaussian
                %PEsubCoords = [LOCS(contigInd) - probInterval*overVar(IIDN).dataFrameRateInteger : LOCS(contigInd) + probInterval*overVar(IIDN).dataFrameRateInteger - 1];
                PEsubCoords = floor([LOCS(contigInd) - probInterval*overVar(IIDN).dataFrameRateInteger : LOCS(contigInd) + probInterval*overVar(IIDN).dataFrameRateInteger - 1]); %Floored to allow for varying framerates
                if nanmin(PEsubCoords) <= 0 || nanmax(PEsubCoords) > size(boutData,1)
                    PEsubCoords(PEsubCoords <= 0) = [];
                    PEsubCoords(PEsubCoords > size(boutData,1)) = [];
                end
                dataToBeFit = boutData(PEsubCoords);
                xToBeFit = [1:size(PEsubCoords,2)]';
                trueCenter = find(PEsubCoords == LOCS(contigInd), 1) - 1;
                exclusionStruct(contigInd).trueCenter = trueCenter;

                cleanW = ceil(W(contigInd)); %Use detected peak half-width to set up coords for noise vs signal
                if cleanW > 0.5 * probInterval * overVar(IIDN).dataFrameRate
                    cleanW = floor(0.5 * probInterval * overVar(IIDN).dataFrameRate); %Artifically cap in case of aberrantly high W[idth]
                end
                if trueCenter - cleanW <= 0 %trueCenter too close to zero given original cleanW
                    cleanW = floor(trueCenter / 2);
                end
                if trueCenter + cleanW >= size(PEsubCoords,2) %trueCenter too close to zero given original cleanW
                    cleanW = floor( (size(PEsubCoords,2) - trueCenter) / 2);
                end

                exclusionStruct(contigInd).cleanW = cleanW;

                peakCoords = [ xToBeFit( trueCenter-cleanW:trueCenter ) ; xToBeFit( trueCenter+1:trueCenter + cleanW) ]; %Coords for peak
                peakData = dataToBeFit( peakCoords ); %This variable formed to reduce accidental indexing errors
                nonPeakMean = nanmean( dataToBeFit( setdiff([1:size(dataToBeFit)], peakCoords) ) );
                    %Technically these lines are part of the BSnr criteria, but they are useful to others
                exclusionStruct(contigInd).peakCoords = peakCoords;
                exclusionStruct(contigInd).nonPeakMean = nonPeakMean;

                if doBSnrExclusion == 1
                    %Bootleg SNR
                    %cheekCoords = [ xToBeFit(1:cleanW); xToBeFit(end-cleanW:end) ]; %Equally sized noise 'cheeks' placed at the start and end of window
                    cheekCoords = [ setdiff([1:size(dataToBeFit)], peakCoords) ]'; %Coords for noise 'cheeks'
                        %"Find mean of all points *not* in peak"
                    cheekData = dataToBeFit( cheekCoords );

                    %cheekSum = nansum(  dataToBeFit(dataToBeFit(cheekCoords) > nonPeakMean) ); %Not normalised to relative size
                    cheekSum = nansum( cheekData(cheekData > nonPeakMean) ) / ( size(cheekCoords,1) / size(peakCoords,1) ); %Normalised to relative size of noise cheeks against peak size
                    peakSum = nansum( peakData(peakData > nonPeakMean) );
                        %"Calculate positive component of noise/signal"
                            %This method is less susceptible to large dips below the mean being falsely interpreted as signal
                    if  cheekSum * bootlegSNRThresh > peakSum
                        %"If noise level of first and last segments * thresh > peak signal level -> Exclude"
                        bSNRExcludeList(contigInd) = 1; %Yes for exclude
                    else
                        bSNRExcludeList(contigInd) = 0;
                    end

                    %exclusionStruct(contigInd).nonPeakMean = nonPeakMean;
                    exclusionStruct(contigInd).BSnr.cheekCoords = cheekCoords;
                    %exclusionStruct(contigInd).peakCoords = peakCoords;
                    exclusionStruct(contigInd).BSnr.cheekSum = cheekSum;
                    exclusionStruct(contigInd).BSnr.peakSum = peakSum;
                end

                if doLonesomeExclusion == 1
                    %Exclude peaks that are not alone in their window
                    loneTargetThresh = nonPeakMean + minProbPeakHeight;
                    try
                        [lonePKS,loneLOCS,~,~] = findpeaks(dataToBeFit, ... 
                            'MinPeakHeight', loneTargetThresh);
                    catch
                        [lonePKS,loneLOCS,~,~] = findpeaksbase(dataToBeFit, ... 
                            'MinPeakHeight', loneTargetThresh);
                    end
                    if size(loneLOCS,1) > 1 | ( size(loneLOCS,1) == 1 & abs(loneLOCS(1) - trueCenter) > centTol )
                        %"If more than one peak OR one peak, but it is not the initially detected peak"
                        lonesomeExcludeList(contigInd) = 1; %Exclude on non-lonesome grounds
                    else
                        lonesomeExcludeList(contigInd) = 0;
                    end
                    exclusionStruct(contigInd).lone.loneLOCS = loneLOCS;
                    exclusionStruct(contigInd).lone.lonePKS = lonePKS;
                end

                if doGaussExclusion == 1
                    [FO, G, ~] = fit( xToBeFit, dataToBeFit, 'gauss2' ); %"More like...FGO"
                        %Note: This takes about 0.1 seconds to run per PE to be fit
                    %Compare with thresholds
                    %Centroid criteria
                    FOAmps = [FO.a1 , FO.a2]; %Original amplitude values
                    FOCents = [FO.b1 , FO.b2]; %Original centroid values
                    [withinWindowGausses] = ( [FO.b1, FO.b2] >= nanmin(xToBeFit) & [FO.b1, FO.b2] < nanmax(xToBeFit) ); %Find which gauss' within window
                    acFOAmps = FOAmps .* withinWindowGausses; %Pared down list where only gauss' within window are non-zero
                    acFOAmps( acFOAmps == 0) = NaN; %Necessary in case of negative amps
                    [~, biggestGaussInd] = nanmax(acFOAmps); %Decide which gauss biggest

                    if abs( FOCents(biggestGaussInd) - trueCenter) > centTol * (probInterval * overVar(IIDN).dataFrameRate * 2)
                        %" If biggest (valid) gauss centroid distance from true center > tolerance -> Exclude"
                        gaussExcludeList(contigInd) = 1; %Yes for exclude
                    else
                        gaussExcludeList(contigInd) = 0; 
                    end
                    exclusionStruct(contigInd).FO = FO;
                    exclusionStruct(contigInd).G = G;
                end

                if doTooFastExclusion == 1 && applyFilter ~= 1
                    if W(contigInd) < tooFastThresh*overVar(IIDN).dataFrameRate
                        tooFastExcludeList(contigInd) = 1; %Exclude, as width too small
                        exclusionStruct(contigInd).W = W(contigInd);
                    else
                        tooFastExcludeList(contigInd) = 0;
                    end
                end

                if doWExclusion == 1
                    if cleanW < wExclusionThresh
                        wExclusionList(contigInd) = 1;
                    else
                        wExclusionList(contigInd) = 0;
                    end
                end

                if doTooHighExclusion == 1
                    tooHighExcludeList(contigInd) = 0; %Default state
                    if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                        if PKS(contigInd) > dlcTooHeight || nansum( dataToBeFit > dlcTooHeight ) > 0
                            tooHighExcludeList(contigInd) = 1;
                        end
                    else
                        if PKS(contigInd) > sriTooHeight || nansum( dataToBeFit > sriTooHeight ) > 0
                            tooHighExcludeList(contigInd) = 1;
                        end
                    end
                end
                
                if doInstChangeExclusion == 1
                    %instChangeThresholdActive = instChangeThreshold / overVar(IIDN).dataFrameRate; %Old style
                    %if nanmax(diff(dataToBeFit)) > instChangeThresholdActive
                    if nanmax(diff(dataToBeFit)) / ( nanmax(dataToBeFit) - nanmin(dataToBeFit) ) > instChangeThresholdFrac
                        instChangeExcludeList(contigInd) = 1;
                    else
                        instChangeExcludeList(contigInd) = 0;
                    end
                end

                %Testatory exclusion fig pt 2
                %{
                if contigInd > 1140 && contigInd < 1150
                    clf
                    plot(dataToBeFit)
                    hold on
                    %scatter(trueCenter,dataToBeFit(floor(trueCenter)),[],[0,0,0])
                    yPull = get(gca,'YLim');
                    if doBSnrExclusion == 1
                        text(5,nanmax(yPull)*0.9,['bSNR: ',num2str(bSNRExcludeList(contigInd))],'Color','r')
                    end
                    if doLonesomeExclusion == 1
                        text(5,nanmax(yPull)*0.85,['Lone: ',num2str(lonesomeExcludeList(contigInd))],'Color','g')
                        scatter( exclusionStruct(contigInd).lone.loneLOCS , exclusionStruct(contigInd).lone.lonePKS, 'filled' )
                    end
                    if doTooFastExclusion == 1
                        text(5,nanmax(yPull)*0.8,['2fast: ',num2str(tooFastExcludeList(contigInd)), ' [',num2str(exclusionStruct(contigInd).W),']'],'Color','b');
                    end
                    scatter(trueCenter,dataToBeFit(floor(trueCenter)),[],[0,0,0]) %Putting at end so drawn on top
                    title(['LOC #',num2str(contigInd),' : ',num2str(LOCS(contigInd))])
                    pause(2.0)
                end
                %}
            end

            %Invalid parameter check for tooFast and Butterworth
            if doTooFastExclusion == 1 && applyFilter == 1
                ['#- Caution: Too Fast exclusion may not have worked properly given Butterworth activation -#']
            end
        %end

            %Keep a copy of pre-exclusion LOCS/PKS/etc
            preLOCS = LOCS; prePKS = PKS; preW = W; preP = P;

            %Exclude peaks according to various criteria
            overallExcludeList = zeros(size(LOCS,1),1);

            %Detect peaks too close together
            tooCloseExcludeList = [0; diff(LOCS) < minimalPeakSeparation]; %First-item 0 necessary to account for indexing alteration induced by diff
            %Detect peaks too near to the start or end
            tooNearExcludeList = [LOCS < probInterval*overVar(IIDN).dataFrameRate | LOCS > size(boutData,1) - probInterval*overVar(IIDN).dataFrameRate];

            overallExcludeList(tooCloseExcludeList == 1) = 1;
            overallExcludeList(tooNearExcludeList == 1) = 1;
            overallExcludeList(gaussExcludeList == 1) = 1;
            overallExcludeList(bSNRExcludeList == 1) = 1;
            overallExcludeList(lonesomeExcludeList == 1) = 1;
            overallExcludeList(tooFastExcludeList == 1) = 1;
            overallExcludeList(wExclusionList == 1) = 1;
            overallExcludeList(tooHighExcludeList == 1) = 1;
            overallExcludeList(instChangeExcludeList == 1) = 1;
                %These lines are a pretty inefficient way to just form an intersection
            if doNotActuallyExclude ~= 1 %Most of the time this should be true
                LOCS(overallExcludeList == 1) = []; PKS(overallExcludeList == 1) = []; W(overallExcludeList == 1) = []; P(overallExcludeList == 1) = [];
                %exclusionStruct( find(overallExcludeList == 1) ) = []; %Necessary to maintain synchrony
            end

            %{
            %QA
            if isempty(LOCS) ~= 1 & size(LOCS,1) ~= size(exclusionStruct,2)
                ['## ALERT: CRITICAL DESYNCHRONISATION DURING EXCLUSION ##']
                error = yes
            end
            %}

            overExclude(IIDN).exclusionStruct{holeNum} = exclusionStruct;
            overExclude(IIDN).overallExcludeList{holeNum} = overallExcludeList; %Note: This is desynchronised from final PE numbers if exclusion was actually applied
        
        end

        %----------------

        %Save data to struct
        allPEStruct.allLOCS = LOCS;
        allPEStruct.allPKS = PKS;
        allPEStruct.allW = W;
        allPEStruct.allP = P;

        allPEStruct.rollingFinderMean = rollingFinderMean;

        %----------------
        
        %----------------------------------------------------------------------------------------------------------------------------------------------
        
        %Proboscis extension angle calculations (if applicable)
            %Could use an automated system based on hasDataList here for full future-proofing, but cbf atm
            %New position
        overVar(IIDN).dlcProbDataLocation = NaN; 
        if contains( overVar(IIDN).dlcProbStatus, 'DLC' ) == 1
            probMed = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisMedCoords; %Grab median
            %Decide whether old or new data
            if isfield( overVar(IIDN).overGlob , 'DLC_PROB_dlcData' ) == 1
                overVar(IIDN).dlcProbDataLocation = 'DLC_PROB_dlcData';
                %temp = [ overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( LOCS ) - probMed(1) , overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( LOCS ) - probMed(2)]; %Find all X and Y distances from median (LOCS specific)
                %temp = [ overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( : ) - probMed(1) , overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( : ) - probMed(2)]; %Find all X and Y distances from median (All)
            elseif isfield( overVar(IIDN).overGlob , 'DLC_SIDE_dlcData' ) == 1
                %temp = [ overVar(IIDN).overGlob.DLC_SIDE_dlcData.proboscis_x( LOCS ) - probMed(1) , overVar(IIDN).overGlob.DLC_SIDE_dlcData.proboscis_y( LOCS ) - probMed(2)]; %LOCS
                %temp = [ overVar(IIDN).overGlob.DLC_SIDE_dlcData.proboscis_x( : ) - probMed(1) , overVar(IIDN).overGlob.DLC_SIDE_dlcData.proboscis_y( : ) - probMed(2)]; %All
                overVar(IIDN).dlcProbDataLocation = 'DLC_SIDE_dlcData';
            else
                ['-# Alert: No valid DLC coordinates could be found in overGlob #-']
                crash = yes
            end
            temp = [ overVar(IIDN).overGlob.( overVar(IIDN).dlcProbDataLocation ).proboscis_x( : ) - probMed(1) , overVar(IIDN).overGlob.( overVar(IIDN).dlcProbDataLocation ).proboscis_y( : ) - probMed(2)]; %Find all X and Y distances from median (All)
            %LOCAngs = rad2deg( atan2(temp(:,2) , temp(:,1) ) ); %Calculate angle between aforementioned points and median
            tempAngs = rad2deg( atan2(temp(:,2) , temp(:,1) ) ); %Calculate angle between aforementioned points and median
            tempAngs = wrapTo360(tempAngs);
            %Testatory data plot of all PEs and their angles
            %{
            figure
            set(gcf,'Name', 'PE angle testatory')
            for i = 1:size(temp,1)
                scatter( [overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( LOCS(i) ),probMed(1)] , [overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( LOCS(i) ),probMed(2)] )
                hold on
                line( [overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( LOCS(i) ),probMed(1)] , [overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( LOCS(i) ),probMed(2)], 'Color', 'g', 'LineStyle', ':' )
                text( nanmean([overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( LOCS(i) ),probMed(1)]), nanmean([overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( LOCS(i) ),probMed(2)]), [num2str(LOCAngs(i)),'°'] , 'Color', 'r')
                xlim([ nanmin(overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( LOCS )) , nanmax(overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_x( LOCS )) ])
                ylim([ nanmin(overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( LOCS )) , nanmax(overVar(IIDN).overGlob.DLC_PROB_dlcData.proboscis_y( LOCS )) ])
                title(['k:',num2str(i),' of ',num2str(size(temp,1)) ])
                pause(0.5)
                clf
            end
            %}
            
            if loadBodyStruct == 1 || exist('bodyStruct') == 1
                thisFlyBodyAngle = rad2deg( -atan2( diff(bodyStruct(IIDN).coords(:,1)) , diff(bodyStruct(IIDN).coords(:,2)) ) );
                    %Negative because attempt to put PEs in same reference frame as body direction
                        %i.e. -135 -> 135 degs -> "0 deg PE" means perfectly in line with body
                %LOCAngs = LOCAngs - thisFlyBodyAngle;
                tempAngs = wrapTo360( tempAngs - thisFlyBodyAngle );
                bodyAngleCorrected = 1;
                allPEStruct.flyBodyAngle = thisFlyBodyAngle;
            else
                bodyAngleCorrected = 0;
            end
            
            overVar(IIDN).dlcProbAngle = tempAngs;
            
            %allPEStruct.allAngs = LOCAngs;
            allPEStruct.locAngs = tempAngs( LOCS );
            %inBoutPEAngs = LOCAngs( ismember(LOCS, [inStruct.holeRanges{:}]) ); %Technically a superior, vectorised form of the above
            %outBoutPEAngs = LOCAngs( ~ismember(LOCS, [inStruct.holeRanges{:}]) );
            inBoutPEAngs = allPEStruct.locAngs( ismember(LOCS, [inStruct.holeRanges{:}]) ); %Technically a superior, vectorised form of the above
            outBoutPEAngs = allPEStruct.locAngs( ~ismember(LOCS, [inStruct.holeRanges{:}]) );
        end
        
        %----------------------------------------------------------------------------------------------------------------------------------------------
        if doAltDetection == 1  
            disp(['-- Labelling probMetric for alt PE detection --'])
            %Alternative PE detection
            altStruct = struct;
            %temp = [ overVar(IIDN).overGlob.DLC_SIDE_dlcData.proboscis_x( : ) - probMed(1) , overVar(IIDN).overGlob.DLC_SIDE_dlcData.proboscis_y( : ) - probMed(2)];

            %tempAng = rad2deg( atan2(temp(:,2) , temp(:,1) ) );

            probUpper = probMetric;
            
            %Apply rolling correction (if requested)
                %Note: This will allow probUpper to go negative
            if rollingAltBaselineCorrection == 1
                rollCorrIntervalActive = floor( overVar(IIDN).dataFrameRate )*rollCorrInterval; %Set up interval
                
                rollCoords = [rollCorrIntervalActive:rollCorrIntervalActive:length(probMetric)]; %Establish coords
                    %Note: Will not go up till very end (unless data length is perfect multiple)
                
                temp = nanmedian( probMetric( repmat( rollCoords, rollCorrIntervalActive, 1 )' - repmat( [rollCorrIntervalActive-1:-1:0], length(rollCoords), 1 ) ) ,2);
                    %"Expand rollCoords [e.g. 1,1,1,1], then subtract increasing indices [e.g. 1,2,3,4], and use this to obtain elements of probMetric in a rowwise fashion, then find the row medians of this"
                
                expTemp = interp1( [1:length(rollCoords)] , temp , linspace(1,length(rollCoords),nanmax(rollCoords)), 'linear' )';
                    %"Interpolate median across original coordinate range"
                        %Note: As expected, will be shorter than probMetric by up to one multiple of rollCorrIntervalActive
                expTemp( length(expTemp):length(probMetric) ) = interp1( [1,2] , [expTemp(end),nanmedian( probMetric(length(expTemp):length(probMetric)) )], linspace(1,2,length(probMetric)-length(expTemp)+1) );
                    %"Complete last missing elements of expTemp as an interpolation between the last expTemp point and the median of the remaining probMetric"
                
                probUpper = probUpper - expTemp;
                    %"And apply"
            end
            
            if useManualAltThresholds == 1
                thisThresh = manThreshes(IIDN);
            else
                %thisThresh = nanmedian(probMetric)+alternativeNoiseThresh*nanstd(probMetric);
                thisThresh = nanmedian(probMetric)+alternativeNoiseThresh*nanstd(probUpper); %Updated to use potentially baseline corrected version
            end
            %probUpper( probMetric < thisThresh ) = 0;
            probUpper( probUpper < thisThresh ) = 0; %Ditto updated
            %disp(['-- Labelling probMetric for alt PE detection (Thresh:',num2str(thisThresh),') --'])
            probLabel = bwlabel( probUpper);
            %And clean up (if requested)
            alternativeMinSizeActual = alternativeMinSize*overVar(IIDN).dataFrameRate;
            alternativeStitchTolerance = alternativeMinSizeActual;
            %Too Small
            tooSmallCount = 0;
            for i = 1:nanmax(probLabel)
                if alternativeMinSize ~= -1 && nansum( probLabel == i ) < alternativeMinSizeActual
                    %probLabel( probLabel == i ) = 0;
                    probUpper( probLabel == i ) = 0;
                    tooSmallCount = tooSmallCount + 1;
                end
            end
            %probLabel = bwlabel( probLabel ); %This doesn't feel safe, but in theory is okay
            probLabel = bwlabel( probUpper ); %This doesn't feel safe, but in theory is okay
            disp(['(',num2str(tooSmallCount),' detections were removed because smaller than ',num2str(alternativeMinSizeActual),' frames)'])
            %Stitch
            temp = bwlabel(probUpper == 0);
            stitchCount = 0;
            for i = 1:nanmax(temp)
                if alternativeMinSize ~= -1 && nansum( temp == i ) < alternativeMinSizeActual
                    %probLabel( temp == i ) = 1; %Note: Could have used a n-1 pasting here, but worried about phase shifts if first element of probUpper > threshold etc
                    try
                        probLabel( temp == i ) = probLabel( find( temp == i , 1 ) -1 );
                    catch
                        ['-# Error during alternative PE detection stitching #-'] %Liable to happen if gap between start and first PE is less than stitch threshold
                        probLabel( temp == i ) = 1;
                    end
                    %probUpper( temp == i ) = nanmedian(probMetric)+alternativeNoiseThresh*nanstd(probMetric); %Artificially adjust probUpper, to show stitching has occurred
                    probUpper( temp == i ) = thisThresh; %Artificially adjust probUpper, to show stitching has occurred
                    stitchCount = stitchCount + 1;
                end
            end
            probLabel = bwlabel( probLabel ); %This doesn't feel safe, but in theory is okay
            disp(['(',num2str(stitchCount),' detections were stitched because separated by < ',num2str(alternativeMinSizeActual),' frames)'])

            tic
            %probAngs = nan( nanmax(probLabel) , 1200 );
            probSizes = nan( nanmax(probLabel) , 1);
            probInds = nan( nanmax(probLabel) , 1);
            for i = 1:nanmax(probLabel)
                probSizes(i,1) = nansum(probLabel == i);
                %probAngs(i, 1:length( tempAng( find(probLabel == i) ) ) ) = tempAng( find(probLabel == i) );
                probInds(i,1) = find( probLabel == i, 1 );
            end
            probAngs = nan( nanmax(probLabel) , nanmax(probSizes) ); %Angles during alt event detection
            probUpps = nan( nanmax(probLabel) , nanmax(probSizes) ); %probMetric (rolling corrected or not) during said detection
            for i = 1:nanmax(probLabel)
                probAngs(i, 1:length( overVar(IIDN).dlcProbAngle( find(probLabel == i) ) ) ) = wrapTo360( overVar(IIDN).dlcProbAngle( find(probLabel == i) ) );
                %probAngs(i, 1:length( tempAng( find(probLabel == i) ) ) ) = tempAng( find(probLabel == i) );
                probUpps(i, 1:length( overVar(IIDN).dlcProbAngle( find(probLabel == i) ) ) ) = probUpper( find(probLabel == i) );
            end
            toc

            %{
            tooSmols = probSizes < 22;
            probSizes(tooSmols == 1) = [];
            probAngs(tooSmols == 1,:) = [];
            %}

            probAngMeds = nanmedian( probAngs,2 );

            %Plot
            figure
            subplot(3,1,1)
            %hist(probSizes,128)
            h = histogram( probSizes , 128);
            xlabel(['Proboscis event length (frames)'])
            ylabel(['Count'])
            xlim([0,arbitraryPlotDuration*overVar(IIDN).dataFrameRate])
            %title([overVar(IIDN).flyName,char(10),'probSizes hist'])
            titleStr = [overVar(IIDN).flyName,char(10),'probSizes hist'];
            %Count loss
            histLossProp = nansum( h.Values( h.BinEdges(1:end-1) > arbitraryPlotDuration*overVar(IIDN).dataFrameRate ) ) / nansum( h.Values );
            titleStr = [titleStr,char(10),'(',num2str(histLossProp*100),'% loss from X-limit)'];
            title(titleStr)

            subplot(3,1,2)
            hist(probAngMeds,128)
            xlim([0,360])
            if bodyAngleCorrected == 1
                title(['Median probAngles hist (Body corrected)'])
            else
                title(['Median probAngles hist (Not body corrected)'])
            end
            xlabel(['Proboscis event median angle (degs)'])
            ylabel(['Count'])

            subplot(3,1,3)
            scatter(probAngMeds,probSizes)
            xlim([0,360])
            xlabel(['Proboscis event median angle (degs)'])
            ylabel(['Proboscis event length (frames)'])

            set(gcf,'Name',[overVar(IIDN).flyName,'-Alternative PE detection sizes and median angles'])

            %Seperate into sleep/wake
            inBoutProbInds = probInds( ismember(probInds, [inStruct.holeRanges{:}]) );
            outBoutProbInds = probInds( ~ismember(probInds, [inStruct.holeRanges{:}]) );
            inBoutProbUpps = probUpps( ismember(probInds, [inStruct.holeRanges{:}]) );
            outBoutProbUpps = probUpps( ~ismember(probInds, [inStruct.holeRanges{:}]) );
            inBoutProbAngleMeds = probAngMeds( ismember(probInds, [inStruct.holeRanges{:}]) );
            outBoutProbAngleMeds = probAngMeds( ~ismember(probInds, [inStruct.holeRanges{:}]) );
            inBoutProbSizes = probSizes( ismember(probInds, [inStruct.holeRanges{:}]) );
            outBoutProbSizes = probSizes( ~ismember(probInds, [inStruct.holeRanges{:}]) );

            %Plot separated histograms
            sepIndex = [{'inBout'},{'outBout'}];
            sepColours = [{'b'},{'r'}];
            figure
            for sepInd = 1:size(sepIndex,2)
                subplot(2, size(sepIndex,2) , sepInd )
                thisData = eval( [strcat(sepIndex{sepInd},'ProbSizes')] );
                histogram( thisData , 128, 'FaceColor', sepColours{sepInd}, 'FaceAlpha', 0.3 )
                xlim([0,nanmax(probSizes)])
                title([overVar(IIDN).flyName,char(10),strcat(sepIndex{sepInd},'ProbSizes')])

                subplot(2, size(sepIndex,2) , sepInd+1*size(sepIndex,2) )
                thisData = eval( [strcat(sepIndex{sepInd},'ProbAngleMeds')] );
                h = histogram( thisData , 128, 'FaceColor', sepColours{sepInd}, 'FaceAlpha', 0.3 );
                hold on
                try
                    f = fit(h.BinEdges(1:end-1).',h.Values.','gauss1');
                    g = plot(f,'c--');
                    g.LineWidth = 2;
                    f = fit(h.BinEdges(1:end-1).',h.Values.','gauss2');
                    g = plot(f,'m--');
                    g.LineWidth = 2;
                catch
                    ['## Error in Gaussian fitting for ',overVar(IIDN).flyName,' ##']
                end
                xlim([0,360])
                title([strcat(sepIndex{sepInd},'ProbAngleMeds')])
            end

            altStruct.probInds = probInds;
            altStruct.probSizes = probSizes;
            altStruct.probAngs = probAngs;
            altStruct.probAngMeds = probAngMeds;
            altStruct.probUpps = probUpps;
            altStruct.inBoutProbInds = inBoutProbInds;
            altStruct.outBoutProbInds = outBoutProbInds;
            altStruct.inBoutProbUpps = inBoutProbUpps;
            altStruct.outBoutProbUpps = outBoutProbUpps;
            altStruct.inBoutProbSizes = inBoutProbSizes;
            altStruct.outBoutProbSizes = outBoutProbSizes;
            altStruct.inBoutProbAngleMeds = inBoutProbAngleMeds;
            altStruct.outBoutProbAngleMeds = outBoutProbAngleMeds;

            %Testatory for alt PE upper and angles

            blirg = (overVar(IIDN).dlcProbAngle/100)+30;
            blirg( probUpper == 0 )= NaN;
            figure
            if rollingAltBaselineCorrection ~= 1
                plot(probMetric)
            else
                plot(probMetric-expTemp) %I mean, we could print the uncorrected form, but since it'll be compared to the corrected/cleaned version it feels incorrect
            end
            hold on
            plot(probUpper)
            xlim([0,30000])
            %xlim([24800,29000])
            plot(blirg)
            line([1,length(probMetric)], [30,30], 'Color', 'k', 'LineStyle', '--')
            line([1,length(probMetric)], [33.6,33.6], 'Color', 'k', 'LineStyle', '--')
            line([1,length(probMetric)], [31.8,31.8], 'Color', 'k', 'LineStyle', '--')
            %line([0,length(probMetric)], [ nanmedian(probMetric)+alternativeNoiseThresh*nanstd(probMetric) ,nanmedian(probMetric)+alternativeNoiseThresh*nanstd(probMetric) ])
            line([0,length(probMetric)], [ thisThresh ,thisThresh ], 'LineStyle', '--')
            hold off
            titleStr = [overVar(IIDN).flyName];
            if isfield( overVar(IIDN).overGlob, 'dlcLikelinessZOH' ) && overVar(IIDN).overGlob.dlcLikelinessZOH.applied == 1
                titleStr = [titleStr, char(10), '(Likeliness ZOHed)'];
            else
                titleStr = [titleStr, char(10), '(Not likeliness ZOHed)'];
            end
            titleStr = [titleStr, char(10)];
            title(titleStr)

            %Append text
            for i = 1:nanmax( probLabel )
                text( find(probLabel == i, 1, 'last')+1 , blirg(find(probLabel == i, 1, 'last')), num2str(round(probAngMeds(i),1)) )
            end
            set(gcf,'Name', 'Alt detection testatory')
            %}
             
        end
        
        %----------------------------------------------------------------------------------------------------------------------------------------------
        
        %Assemble rail
        allPERail = zeros( size(probMetric,1), 6 ); %Honestly at this point do I have to explain the concept of rails
        allPERail(:,1) = overVar(IIDN).overGlob.BaseFrameTime; %Col 1 - Epoch time for every single point
        allPERail(LOCS,2) = 1; %Col 2 - All detected PE locations
        allPERail(:,3) = repmat( NaN, size(allPERail,1), 1 ); %Col 3 - Hole numbers (or NaNs, if not hole)
        allPERail(:,4) = repmat( NaN, size(allPERail,1), 1 ); %Col 4 - Within-bout PEs
        allPERail(:,5) = repmat( -1, size(allPERail,1), 1 ); %Col 5 - Not-holes (or NaNs, if hole)
        %allPERail(:,6) = repmat( NaN, size(allPERail,1), 1 ); %Col 6 - Out of bout PEs (Do not NaN on account of inversion)
        allPERail(:,7) = repmat( NaN, size(allPERail,1), 1 ); %Col 7 - Seconds pre/post 5PM

        %QA
        if size(probMetric,1) ~= size(overVar(IIDN).overGlob.BaseFrameTime,1)
            ['## Alert: Critical asynchrony between probMetric and BaseFrameTime ##']
            error = yes
        end

        %Separate by bout or not
        inStruct = overVar(IIDN).inStructCarry;

        inBoutPEsLOCS = []; %Will store LOCS of PEs that occurred within bouts
        outBoutPEsLOCS = []; %Ditto, but for all other PEs
        inBoutPEsPKS = [];
        outBoutPEsPKS = [];

        for holeNum = 1:size(inStruct.holeRanges,2)
            allPERail(inStruct.holeRanges{holeNum},3) = repmat( holeNum, size(inStruct.holeRanges{holeNum},2) , 1 ); %Col 3 - Hole numbers
            allPERail(inStruct.holeRanges{holeNum},4) = repmat( 0, size(inStruct.holeRanges{holeNum},2) , 1 ); %Col 4 - Within bout PEs (prepping with zeroes)
            allPERail(inStruct.holeRanges{holeNum},5) = repmat( NaN, size(inStruct.holeRanges{holeNum},2) , 1 ); %Col 5 - Not-holes
            allPERail(inStruct.holeRanges{holeNum},6) = repmat( NaN, size(inStruct.holeRanges{holeNum},2) , 1 ); %Col 6 - Out of bout PEs
            inBoutPEsLOCS = [inBoutPEsLOCS; LOCS( ismember(LOCS, inStruct.holeRanges{holeNum}) )];
            inBoutPEsPKS = [inBoutPEsPKS; PKS( ismember(LOCS, inStruct.holeRanges{holeNum}) )];
        end
        outBoutPEsLOCS = LOCS( ismember(LOCS, inBoutPEsLOCS) ~= 1 ); %Correct indexing not thoroughly checked
        outBoutPEsPKS = PKS( ismember(LOCS, inBoutPEsLOCS) ~= 1 ); %Correct indexing not thoroughly checked

        allPERail(inBoutPEsLOCS,4) = 1; %Col 4 - Within-bout PEs
        allPERail(outBoutPEsLOCS,6) = 1; %Col 6 - Out of bout PEs

        %Calculate relative posix
        %@@@@@@@@@@@@@@@@@@

        firstNonNaNMovFrameInd = find(isnan(allPERail(:,1)) ~= 1,1,'First');
        firstMovFrameTime = datestr(datetime(allPERail(firstNonNaNMovFrameInd,1), 'ConvertFrom', 'posixtime')); %Find datetime of first mov frame

        ZTarget = num2str(sleepCurveZTNums(1));
        ZTargetNum = str2num(ZTarget);

        timeToFind = firstMovFrameTime; %Stage 1

        timeToFind(end-7:end) = '00:00:00'; %Zero out HMS
        timeToFind(end-7:end-8+size(ZTarget,2)) = ZTarget; %Set HMS to target ZT

        timeToFindPosix = posixtime(datetime(timeToFind,'Format', 'dd-MM-yyyy HH:mm:ss')); %Takes the manually assembled target ZT and converts it to a posix

        %@@@@@@@@@@@@@@@@@@@@@@@

        allPERail(:,7) = allPERail(:,1) - timeToFindPosix; %Col 7 - Time(s) since 5PM on the first day of the recording
            %Note: If a recording was started early in the day most of these values will be negative
                %I.e. An 8AM-start recording will be negative until 9 hours later

        %----------------

        %Calculate useful metrics for plotting
        PERailTimes = allPERail(:,1);
        PERailTimesDiff = [0; diff(PERailTimes)];
        inBoutPEsAvgPerMin = nansum(allPERail(:,4)) / ...
                ( nansum( PERailTimesDiff( isnan(allPERail(:,3)) ~= 1 ) ) / 60);
                %"Total number of in-bout PEs / sum of inter-frame time differences for all times when bout was occurring, in seconds"
        outBoutPEsAvgPerMin = nansum(allPERail(:,6)) / ...
                ( nansum( PERailTimesDiff( isnan(allPERail(:,5)) ~= 1 ) ) / 60);
                %Ditto, but inverse

        %rollBinSize = 5*60*dataFrameRate; %10 minutes
        rollBinSize = floor(5*60*overVar(IIDN).dataFrameRate); %10 minutes
        rollPEY = [];
        rollPEX = [];
        a = 1;
        for i = 1:rollBinSize:size(probMetric,1)
            rollCoords = [ (a-1)*rollBinSize+1 : a*rollBinSize ];
            if nanmax(rollCoords) > size(probMetric,1)
                rollCoords(rollCoords > size(probMetric,1)) = [];
            end
            %rollPEX(a) = (a * rollBinSize) - (0.5 * rollBinSize); %Points will show up in the X-middle of the bin
            rollPEX(a) = floor( (a * rollBinSize) - (0.5 * rollBinSize) ); %Points will show up in the X-middle of the bin
            if rollPEX(a) > size(probMetric,1)
                rollPEX(a) = size(probMetric,1); %Cap for certain end conditions
            end
            rollPEY(a) = ( nanmean( allPERail(rollCoords,2) ) ) * overVar(IIDN).dataFrameRate * 60;
                %"Calculate mean number of PEs per frame, then multiply by frames in 1s, then multiply by seconds in 1m"
            a = a + 1;
        end            

        %----------------

        %Save data to struct
        allPEStruct.inBoutPEsLOCS = inBoutPEsLOCS;
        allPEStruct.inBoutPEsPKS = inBoutPEsPKS;
        allPEStruct.outBoutPEsLOCS = outBoutPEsLOCS;
        allPEStruct.outBoutPEsPKS = outBoutPEsPKS;
        if exist('inBoutPEAngs') == 1
            allPEStruct.inBoutPEAngs = inBoutPEAngs;
            allPEStruct.outBoutPEAngs = outBoutPEAngs;
        end

        allPEStruct.allPERail = allPERail;

        allPEStruct.inBoutPEsAvgPerMin = inBoutPEsAvgPerMin;
        allPEStruct.outBoutPEsAvgPerMin = outBoutPEsAvgPerMin;
        allPEStruct.rollPEY = rollPEY;
        allPEStruct.rollPEX = rollPEX;

        %----------------

        %[Testatory] Figure for plot of all prob data
        %{
        figure
        plot(boutData, 'g')
        hold on
        scatter(preLOCS,prePKS, 'k') %Redundant, because LOCS/PKS cleaned up at end of exclusion
        scatter(inBoutPEsLOCS,inBoutPEsPKS, 2, 'c')
        scatter(outBoutPEsLOCS,outBoutPEsPKS, 2, 'm')
        line([1:binSpecs:size(boutData,1)], [rollingFinderMean(:,1)], 'Color', 'b')
        if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
            ylim([0 dlcMaxPeakHeight])
        else
            ylim([0 sriMaxPeakHeight])
        end
        %Ancillary text
        try
            for pInd = 1:size(preLOCS,1)
                scaText = [];
                scaText = [scaText,num2str(pInd)];
                if isempty( find( LOCS == preLOCS(pInd) ) ) ~= 1
                    scaText = [scaText,' (',num2str(find( LOCS == preLOCS(pInd) )),')'];
                end
                scaText = [scaText,char(10),'W:',num2str(exclusionStruct(pInd).cleanW)];
                if doBSnrExclusion == 1
                    scaText = [scaText,char(10),'bSNR:',num2str( round(exclusionStruct(pInd).BSnr.peakSum,2) ),'/',num2str( round(exclusionStruct(pInd).BSnr.cheekSum,2) )];
                end
                thisColour = 'k';
                if nansum( inBoutPEsLOCS == preLOCS(pInd) ) == 1
                    thisColour = 'c';
                elseif nansum( outBoutPEsLOCS == preLOCS(pInd) ) == 1
                    thisColour = 'm';
                end
                %text( preLOCS(pInd), prePKS(pInd) + 8 , scaText , 'FontSize', 8, 'Color', 'k' )
                text( preLOCS(pInd), prePKS(pInd) + 8 , scaText , 'FontSize', 8, 'Color', thisColour )
            end
        catch
            ['-# Alert: Could not add ancillary text to PE plot #-'] %Will fail on no exclusion i guess
        end
        %xlim([2.0230e5 2.0664e5])
        title(strcat(overVar(IIDN).fileDate, ' - All prob data and PEs -', dlcProbStatus))
        %}
        %touma

        %----------------

        %Save data for overuse
        overAllPE(IIDN).allPEStruct = allPEStruct;
        disp(['-- ', num2str(size(LOCS,1)) ,' PEs detected and itemised --'])
        if doAltDetection == 1
            overAllPE(IIDN).altStruct = altStruct;
            disp(['-- ', num2str(size(altStruct.probInds,1)) ,' alternative PEs/reaches detected --'])
        end

        
        

        %--------------------------------------------------------------

        %Detect Proboscis Extension Spells
        overAllPE(IIDN).spellStruct = struct;
        timeRailData = overVar(IIDN).overGlob.movFrameTime';

        %subTimeData = timeRailData(inStruct.holeRanges{holeNum});
        allTimeData = timeRailData;
        %[PKS,LOCS,W,P] = findpeaks(probMetric(inStruct.holeRanges{i}), 'MinPeakDistance', dataFrameRate*probInterval); %Find peaks within prob data, separated by at least 1s
            %Note: This means that PEs occurring faster than 1Hz will be excluded, but this seems uncommon

        timeDiff = allTimeData(LOCS)' - allTimeData(circshift(LOCS, [1,0]))'; %Raw inter-PE times
        timeDiff(1) = NaN; %Because of circshifting this value is nonsense
        interProbFreqData = 1.0 ./ timeDiff; %Raw frequency of the time duration between PEs

        %probScatter(IIDN).findPEs(holeNum).interProbFreqData = interProbFreqData;
        %overAllPE(IIDN).spellStruct.interProbFreqData = interProbFreqData;
        overAllPE(IIDN).allPEStruct.interProbFreqData = interProbFreqData;

        %Contiguity detection
        contigSizes = []; matchingContigs = []; matchingContigStartEnd = []; matchingContigPEsPos = []; matchingContigLOCS = []; matchingContigLOCSTime = []; matchingContigFreqs = [];

        contigBoolDiff = diff( timeDiff <  ( probInterval * contiguityThreshold ) );

        posDiff = find(contigBoolDiff == 1);
        negDiff = find(contigBoolDiff == -1);

        if isempty(posDiff) ~= 1 && isempty(negDiff) ~= 1                 
            if size(negDiff,1) < size(posDiff,1)
                %negDiff(size(negDiff,1)+1:size(posDiff,1),1) = NaN;
                negDiff(size(negDiff,1)+1:size(posDiff,1),1) = size(LOCS,1);
                    %The assumption here is that no end was detected because no new contiguous raft occurred before the end of the sleep bout
                        %This may not be always true
            else
                posDiff(size(posDiff,1)+1:size(negDiff,1),1) = NaN;
            end

            contigSizes = negDiff - posDiff; %Assumptions of directionality here...

            %contigFreqs = interProbFreqData(posDiff:negDiff);

            matchingContigs = find(contigSizes >= minRaftSize);

            matchingContigStartEnd = [LOCS( posDiff(matchingContigs) ), LOCS( negDiff(matchingContigs) )]; %Might be misaligned by up to 1 frame

            for contigInd = 1:size(matchingContigStartEnd,1)
                matchingContigPEsPos{contigInd} = [ 1 + posDiff(matchingContigs(contigInd,:)) : negDiff(matchingContigs(contigInd,:)) ]';
                matchingContigLOCS{contigInd} = [LOCS( 1 + posDiff(matchingContigs(contigInd,:)) : negDiff(matchingContigs(contigInd,:)) )]; 
                matchingContigLOCSTime{contigInd} = [allTimeData( LOCS( 1 + posDiff(matchingContigs(contigInd,:)) : negDiff(matchingContigs(contigInd,:)) ) )]';
                matchingContigFreqs{contigInd} = interProbFreqData( 1 + posDiff(matchingContigs(contigInd,:)) : negDiff(matchingContigs(contigInd,:)) );
                    %+1 is to prevent from pulling first value of contiguous spell, which has a variably high inter-prob interval
                    %Multi-level indexing is cruicial to proper operation here
                        %e.g. "Pull LOCS based on indices from rows of posDiff and negDiff that correspond to the contigInd (and add 1 to posDiff to eliminate the first element)"
                    %The progression of analysis: contigSizes is pared down to large enough rafts, the coordinate/s of these rafts are pulled from posDiff/negDiff and related
                    %back to LOCS for coordinate purposes and interProbFreqData for manually calculated frequency purposes
                %QA
                if size(matchingContigPEsPos{contigInd},1) ~= size(matchingContigFreqs{contigInd},1) || ...
                        size(matchingContigLOCSTime{contigInd},1) ~= size(matchingContigFreqs{contigInd},1)
                    ['## Alert: Critical symmetry failure in prob. spell processing ##']
                    error = yes
                end
            end
        end

        %--------
        overAllPE(IIDN).spellStruct.allContigSizes = contigSizes; %Size of all spells that are contiguous but not guaranteed to be above minimum size
        overAllPE(IIDN).spellStruct.allLOCCoords = [ posDiff, negDiff ]; %Start/end coords of the above (Relate to LOC reference)
        overAllPE(IIDN).spellStruct.allStartEnd = [ LOCS(posDiff), LOCS(negDiff) ];
        overAllPE(IIDN).spellStruct.matchingContigSizes = contigSizes(matchingContigs); %Size of spells that are both contiguous and larger than the threshold length and amplitudes
        overAllPE(IIDN).spellStruct.matchingContigLOCS = matchingContigLOCS; %Point coords of PEs (LOCS inds == probMetric inds)
        overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute = matchingContigStartEnd; %Start/end coords of the above (Absolute to probMetric)
        overAllPE(IIDN).spellStruct.matchingContigPEsPos = matchingContigPEsPos; %Full coords of the above (Relate to LOC reference)
        overAllPE(IIDN).spellStruct.matchingContigFreqs = matchingContigFreqs; %interProbFreqData for the full coords of the above
        %--------

        if isempty(matchingContigStartEnd) ~= 1
            %probScatter(IIDN).spellsPooled.matchingContigHoleNum = [ probScatter(IIDN).spellsPooled.matchingContigHoleNum; holeNum ];
            probScatter(IIDN).spellsPooled.matchingContigSizesPooled = overAllPE(IIDN).spellStruct.matchingContigSizes;
            %probScatter(IIDN).spellsPooled.matchingContigStartEndPooled = [ probScatter(IIDN).spellsPooled.matchingContigStartEndPooled; matchingContigStartEnd ]; %Deprecated because whole probMetric
            probScatter(IIDN).spellsPooled.matchingContigStartEndAbsolutePooled = overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute;
            for contigInd = 1:size(matchingContigFreqs,2) %This loop necessary for cell type data
                probScatter(IIDN).spellsPooled.matchingContigHoleNum(contigInd, 1) = NaN; %Value will be updated later if applicable
                probScatter(IIDN).spellsPooled.matchingContigPEsPos{ size( probScatter(IIDN).spellsPooled.matchingContigFreqs,1 ) + 1, 1 } = matchingContigPEsPos{contigInd};
                probScatter(IIDN).spellsPooled.matchingContigLOCS{ size( probScatter(IIDN).spellsPooled.matchingContigFreqs,1 ) + 1, 1 } = matchingContigLOCS{contigInd};
                probScatter(IIDN).spellsPooled.matchingContigLOCSTime{ size( probScatter(IIDN).spellsPooled.matchingContigFreqs,1 ) + 1, 1 } = matchingContigLOCSTime{contigInd};
                probScatter(IIDN).spellsPooled.matchingContigFreqs{ size( probScatter(IIDN).spellsPooled.matchingContigFreqs,1 ) + 1, 1 } = matchingContigFreqs{contigInd};
            end
        end

        %--------

        for holeNum = 1:size(inStruct.holeRanges,2)
            holeCoords = inStruct.holeRanges{holeNum};

            %--------
            %Assemble copy of avProbContourSizeSmoothedEventRail where only time within bouts is considered
            probScatter(IIDN).avProbContourSizeSmoothedEvent(min(inStruct.holeRanges{holeNum}):max(inStruct.holeRanges{holeNum}),1) = ...
                probScatter(IIDN).avProbContourSizeSmoothedEventRail(min(inStruct.holeRanges{holeNum}):max(inStruct.holeRanges{holeNum}),1);
                %Use subset of all PE data to save having to iterate through loop again
            if wipeProbStarts == 1
                i = min(inStruct.holeRanges{holeNum});
                %if avProbContourSizeSmoothed(i) > MEANavProbContourSizeSmoothed*0.5 %"Is supra-threshold proboscis activity already occuring at the first frame?"
                if probMetric(i) > meanAvProbContourSizeSmoothedRestricted*probMeanThresh %"Is supra-threshold proboscis activity already occuring at the first frame?"
                    %wipeEnd = find(avProbContourSizeSmoothed(i:end) < MEANavProbContourSizeSmoothed*0.5, 1); 
                    wipeEnd = find(probMetric(i:end) < meanAvProbContourSizeSmoothedRestricted*probMeanThresh, 1); 
                        %Returns an index relative to the first frame after min(inStruct.holeRanges{holeNum}) whereupon prob. activity was sub-threshold
                    probScatter(IIDN).avProbContourSizeSmoothedEvent(i:i+wipeEnd-1,1) = 0;                    
                end
            end

            probScatter(IIDN).probEventsCount(holeNum) = nansum(ismember(LOCS, inStruct.holeRanges{holeNum}));

            probScatter(IIDN).probStartTimes(holeNum) = str2num(inStruct.holeStartsTimes{holeNum}(end-8:end-6)) + str2num(inStruct.holeStartsTimes{holeNum}(end-4:end-3)) / 60;
                %Decimal hour time of day of hole
            probScatter(IIDN).probStartZT(holeNum) = inStruct.holeStartsZT(holeNum);
                %Adjusted ZT of hole start
            probScatter(IIDN).probEventsDur(holeNum) = nansum(probScatter(IIDN).avProbContourSizeSmoothedEvent(min(inStruct.holeRanges{holeNum}):max(inStruct.holeRanges{holeNum}),1)) / ...
                overVar(IIDN).dataFrameRate;
                    %"Divide number of frames where proboscis activity was larger than threshold by framerate"
            probScatter(IIDN).probEventsDurProp(holeNum) = probScatter(IIDN).probEventsDur(holeNum) / ( inStruct.holeSizes(holeNum) / overVar(IIDN).dataFrameRate );
                    %"Divide raw duration of >threshold proboscis activity by bout size"

            %--------
            probScatter(IIDN).findPEs(holeNum).LOCS = LOCS(ismember(LOCS, inStruct.holeRanges{holeNum})) - inStruct.holeStarts(holeNum);
            probScatter(IIDN).findPEs(holeNum).LOCSAbsolute = LOCS(ismember(LOCS, inStruct.holeRanges{holeNum}));
            probScatter(IIDN).findPEs(holeNum).PKS = PKS(ismember(LOCS, inStruct.holeRanges{holeNum}));
            probScatter(IIDN).findPEs(holeNum).W = W(ismember(LOCS, inStruct.holeRanges{holeNum}));
            probScatter(IIDN).findPEs(holeNum).P = P(ismember(LOCS, inStruct.holeRanges{holeNum}));
            probScatter(IIDN).findPEs(holeNum).interProbFreqData = interProbFreqData(ismember(LOCS, inStruct.holeRanges{holeNum}));
            if isempty(probScatter(IIDN).findPEs(holeNum).interProbFreqData) == 1
                probScatter(IIDN).findPEs(holeNum).interProbFreqData = NaN;
            end

            %--------

            %Find contigs that occurred within hole
            subsetSpells = []; %Which (if any) of the LOCS/matchingContigs are within this hole
            tempSubsetInds=[]; subsetFullCoordsAbsolute=[]; subsetStartEndAbsolute=[]; subsetStartEnd=[]; subsetCoordsAbsolute=[]; subsetLOCSAbsolute=[];subsetLOCS=[];subsetPEsPos=[]; subsetPEsFreq=[];
            %subsetInds = []; %Cell array to store indices for matching contigs within hole
            for contigInd = 1:size(overAllPE(IIDN).spellStruct.matchingContigSizes,1)
                contigFullCoords = [ overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,1) : overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,2) ];
                tempSubsetInds = []; %Cell array to store indices for matching contigs within hole
                if nansum( ismember( contigFullCoords , holeCoords) ) > 0 %"Any of contig coords within this sleep bout"
                    subsetSpells = [subsetSpells, contigInd];
                    %subsetInds{ 1, size(subsetSpells,2) } = contigCoords( ismember( contigCoords , holeCoords) );
                    tempSubsetInds = ismember( contigFullCoords , holeCoords); %Boolean for which contig points are in the hole
                    subArrayInd = size(subsetSpells,2); %Simplifies referencing (Note: Should tick up with each matching contig)
                    subsetFullCoordsAbsolute{ 1, subArrayInd } = contigFullCoords( tempSubsetInds );
                    subsetStartEndAbsolute{ 1, subArrayInd } = [ nanmin(subsetFullCoordsAbsolute{ 1, subArrayInd }) , nanmax(subsetFullCoordsAbsolute{ 1, subArrayInd }) ];
                    subsetStartEnd{ 1, subArrayInd } = [ subsetStartEndAbsolute{ 1, subArrayInd }(1) - inStruct.holeStarts(holeNum) , subsetStartEndAbsolute{ 1, subArrayInd }(2) - inStruct.holeStarts(holeNum) ];
                    subsetLOCSAbsolute{ 1, subArrayInd } = overAllPE(IIDN).spellStruct.matchingContigLOCS{contigInd}( ismember( overAllPE(IIDN).spellStruct.matchingContigLOCS{contigInd} , subsetFullCoordsAbsolute{ 1, subArrayInd } ) );
                    subsetLOCS{ 1, subArrayInd } = subsetLOCSAbsolute{ 1, subArrayInd } - inStruct.holeStarts(holeNum);
                    subsetPEsPos{ 1, subArrayInd } = overAllPE(IIDN).spellStruct.matchingContigPEsPos{ contigInd }; %contigInd because otherwise data is duplicated
                    subsetPEsFreqs{ 1, subArrayInd } = overAllPE(IIDN).spellStruct.matchingContigFreqs{ contigInd }; %Ditto
                    subsetContigInd{ 1, subArrayInd } = contigInd; %Stores the original 'overall' contig number for later backtracking purposes
                end
            end

            probScatter(IIDN).spells(holeNum).holeNum = holeNum; %Hole number, for reference

            a = 1;
            for subSpell = 1:size(subsetSpells,2)
                if size(subsetLOCSAbsolute{subSpell},1) > minRaftSize %Enforce minimum raft size for potentially split contigs
                        %Note: This means that a contig that overlaps a hole by only a small amount will not count as being in that hole
                            %This is probably both good and bad
                    %--------

                    probScatter(IIDN).spells(holeNum).matchingContigSizes( a , 1 ) = size(subsetLOCSAbsolute{subSpell},1); %Select from contigs that occurred within hole
                    probScatter(IIDN).spells(holeNum).matchingContigIndOriginal( a , 1 ) = subsetContigInd{subSpell}; %Original contig from all PE data
                    probScatter(IIDN).spells(holeNum).matchingContigFullCoordsAbsolute{ a , 1 } = subsetFullCoordsAbsolute{ subSpell };
                    probScatter(IIDN).spells(holeNum).matchingContigStartEnd( a , 1:2 ) = subsetStartEnd{ subSpell }; %Start/end coords of the above (Relative to hole start)
                    probScatter(IIDN).spells(holeNum).matchingContigStartEndAbsolute{ a , 1 } = subsetStartEndAbsolute{ subSpell }; %Start/end coords of the above (Absolute to probMetric)
                    probScatter(IIDN).spells(holeNum).matchingContigPEsPos{ a , 1 } = subsetPEsPos{subSpell}; %Indexes of PEs within grand LOCS (maybe?)
                    probScatter(IIDN).spells(holeNum).matchingContigFreqs{ a , 1 } = subsetPEsFreqs{subSpell}; %interProbFreqData for the full coords of the above

                    %--------

                    probScatter(IIDN).spellsPooled.matchingContigHoleNum(subsetSpells(a) , 1) = holeNum; %Append this value to indicate that contig occurred within hole
                    a = a + 1; %Necessary because of minRaftSize induced desynchronisation
                end
            end

            %--------
        end

        %--------------------------------------------------------------


        %------------------------------------------------------------------
        %------------------------------------------------------------------

        
        %IIDN end
        %%end

        %IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
        %%Intermediate
        %Load ant data (if existing)
        %--
        %Load ant data if existing (Borrowed from below)
        antDataCase = -1; %Simplifies later modification of original values
        if ( isfield(overVar(IIDN).overGlob.hasDataList, 'DORS') == 1 && overVar(IIDN).overGlob.hasDataList.DORS == 1 ) || ...
                ( isfield(overVar(IIDN).overGlob.hasDataList, 'DLC_ANT') == 1 && overVar(IIDN).overGlob.hasDataList.DLC_ANT == 1 )  %Designed to catch if dorsal data doesn't exist, but may not operate correctly for Swarmsight-derived antennal angles
            if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1
                xRightAll = overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj; %Calculated DLC antennal angles, adjusted for relative body angle
                xLeftAll = overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj;
                antDataCase = 1;
            else
                %%rightThetaSmoothed = overVar(IIDN).rightThetaSmoothed; %Smoothed data
                %%leftThetaSmoothed = overVar(IIDN).leftThetaSmoothed;
                try
                    xRightAll = overVar(IIDN).rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                    xLeftAll = overVar(IIDN).leftThetaProc;
                    antDataCase = 2;
                catch
                    xRightAll = overVar(IIDN).overGlob.rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                    xLeftAll = overVar(IIDN).overGlob.leftThetaProc;
                    antDataCase = 3;
                    %disp(['-# Warning: Failure to find antennal values in expected structure location (Backup location used instead) #-'])
                end
            end
        end
        if antDataCase == -1
            xRightAll = [];
            xLeftAll = [];
        end
        %--
        
        %Flatten other processList elements based on pure presence of PE extensions
            %Borrowed from PE sleepRail flattening
        if doAggPEFlat == 1
            if antDataCase  ~= -1 && isempty( overAllPE(IIDN).allPEStruct.allLOCS ) ~= 1
                disp(['-- Performing aggressive PE -> Ant. data flattening --'])
                for n = 1:size( overAllPE(IIDN).allPEStruct.allLOCS , 1 )
                    peFlatCoords = floor([ overAllPE(IIDN).allPEStruct.allLOCS(n) - probInterval * overVar(IIDN).dataFrameRate : overAllPE(IIDN).allPEStruct.allLOCS(n) + probInterval * overVar(IIDN).dataFrameRate ]);
                    for sode = 1:size( processList,2 ) 
                        if isempty(strfind(processList{sode},'xRight')) ~= 1                            
                            xRightAll( peFlatCoords ) = nanmean( xRightAll(peFlatCoords) );
                            
                        end
                        if isempty(strfind(processList{sode},'xLeft')) ~= 1                            
                            xLeftAll( peFlatCoords ) = nanmean( xLeftAll(peFlatCoords) );
                        end
                            %By rights this should be made dynamic, but I cbf right now
                    end
                end
                %Adjust variables
                %overVar(IIDN).xRightAll = xRightAll;
                %overVar(IIDN).xLeftAll = xLeftAll;
                
                %clear xRightAll xLeftAll
            end
        end
        %New names
            %If agg PE flattening, these will have been modified
        overVar(IIDN).xRightAll = xRightAll;
        overVar(IIDN).xLeftAll = xLeftAll;
        clear xRightAll xLeftAll
        
        %FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        %Fouri begin
        
        %Assemble initial fouriers
            %(Moved from up above)
        fouriStruct = struct;

        %if splitBouts ~= 1
        inStruct = overVar(IIDN).inStructCarry;
        %else
        %    inStruct = overVar(IIDN).splitStruct;
        %end
        
        boundHasCross = 0; %Boolean for whether boundary crossing has occurred
        boundCross = 0; %Scalar to apply constantly to data
        %Old
        %{
        if ( isfield(overVar(IIDN).overGlob.hasDataList, 'DORS') == 1 && overVar(IIDN).overGlob.hasDataList.DORS == 1 ) || ...
                ( isfield(overVar(IIDN).overGlob.hasDataList, 'DLC_ANT') == 1 && overVar(IIDN).overGlob.hasDataList.DLC_ANT == 1 )  %Designed to catch if dorsal data doesn't exist, but may not operate correctly for Swarmsight-derived antennal angles
            if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1
                rightThetaProc = overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj; %Calculated DLC antennal angles, adjusted for relative body angle
                leftThetaProc = overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj;
            else
                %%rightThetaSmoothed = overVar(IIDN).rightThetaSmoothed; %Smoothed data
                %%leftThetaSmoothed = overVar(IIDN).leftThetaSmoothed;
                try
                    rightThetaProc = overVar(IIDN).rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                    leftThetaProc = overVar(IIDN).leftThetaProc;
                catch
                    rightThetaProc = overVar(IIDN).overGlob.rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                    leftThetaProc = overVar(IIDN).overGlob.leftThetaProc;
                    disp(['-# Warning: Failure to find antennal values in expected structure location (Backup location used instead) #-'])
                end
            end
        end
        %}
        rightThetaProc = overVar(IIDN).xRightAll;
        leftThetaProc = overVar(IIDN).xLeftAll;
        
        rightThetaHoleAll = []; %Stores ligated right theta data
        leftThetaHoleAll = []; %Stores ligated left theta data

        for i = 1:size(inStruct.holeRanges,2)
            %{
            %Calculate ZT post-hoc (Note: This is adjusted ZT, which aims for a continuous rollover at midnight)
            preZT = str2num(inStruct.holeStartsTimes{i}(end-8:end-6)) + str2num(inStruct.holeStartsTimes{i}(end-4:end-3)) / 60;
            if i == 1 && preZT < 12 %Catch instances where first hole did not happen till after midnight
                    boundHasCross = 1;
                    boundCross = boundCross + 24; %Day boundary likely crossed
            end
            if i > 1 
                if preZT < inStruct.holeStartsZT(i-1) && boundHasCross == 0 %Check if day boundary has been crossed
                    boundHasCross = 1;
                    boundCross = boundCross + 24; %Day boundary likely crossed
                end
            end
            inStruct.holeStartsZT(i) = preZT + boundCross;
            %}
            
            %%i = 3;
            if isfield(overVar(IIDN).overGlob.hasDataList, 'DORS') == 1 && overVar(IIDN).overGlob.hasDataList.DORS == 1 || ...
                ( isfield(overVar(IIDN).overGlob.hasDataList, 'DLC_ANT') == 1 && overVar(IIDN).overGlob.hasDataList.DLC_ANT == 1 )
                xRight = rightThetaProc(inStruct.holeRanges{i})';
                xLeft = leftThetaProc(inStruct.holeRanges{i})';
                
                rightThetaHoleAll = [rightThetaHoleAll, xRight]; %Incorporate cull list?
                leftThetaHoleAll = [leftThetaHoleAll, xLeft];
            end
            if doSpectro == 1 && doProbSpectro == 1
                probData = probMetric(inStruct.holeRanges{i})';
            end
            
            %----------------------------------
            
            %%x = fakeData3;
            %fs = 30; %Sampling rate of data
            fs = overVar(IIDN).dataFrameRate;
            
            if doFFT == 1 && doSpectro == 1
                winSizeActive = floor( winSize*fs );
                winOverlapSizeActive = floor( winOverlap*fs );
            end
            
            if exist('xRight') == 1
                if size(xRight,2) < minSafeLength %Bout too short to analyse
                    disp(['-- Warning: Bout too short to analyse for the given frequencies --'])
                    f = NaN; %X axis; Singleton NaN-ing here may cause issues
                    P1 = NaN; %Raw trace
                else
                    % Compute the discrete Fourier transform of the signal. Find the phase of the transform and plot it as a function of frequency.
                    %Right antennal angles
                    if length(xRight) / 2.0 ~= floor(length(xRight) / 2.0) %Ensure even size
                        endInd = length(xRight) - 1;
                    else
                        endInd = length(xRight);
                    end
                    y = fft(xRight(1:endInd));
                    %L = length(xRight);
                    L = length(y);
                    P2 = abs(y/L);
                    P1 = P2(1:L/2+1);
                    P1(2:end-1) = 2*P1(2:end-1);
                    f = fs*(0:(L/2))/L; % find the frequency vector

                    fouriStruct(i).fRight = f;
                    fouriStruct(i).P1Right = P1;

                    %Left antennal angles
                    if length(xLeft) / 2.0 ~= floor(length(xLeft) / 2.0)
                        endInd = length(xLeft) - 1;
                    else
                        endInd = length(xLeft);
                    end
                    y = fft(xLeft(1:endInd));
                    %L = length(xLeft);
                    L = length(y);
                    P2 = abs(y/L);
                    P1 = P2(1:L/2+1);
                    P1(2:end-1) = 2*P1(2:end-1);
                    f = fs*(0:(L/2))/L; % find the frequency vector
                end

                fouriStruct(i).fLeft = f;
                fouriStruct(i).P1Left = P1;

                overVar(IIDN).inStruct.xRight{i} = xRight; %Technically redundant
                overVar(IIDN).inStruct.xLeft{i} = xLeft;
            end
            
            %----------------------------------
            %{
            if timeSubStart == 0 || timeSubEnd == 0
                %Same, but on subset of data
                if timeSubEnd == 0 %Work backwards from end of data
                    xRightSub = xRight(end+timeSubStart:end);
                    xLeftSub = xLeft(end+timeSubStart:end);
                else %Backwards from specified point
                    xRightSub = xRight(timeSubEnd+timeSubStart:timeSubEnd);
                    xLeftSub = xLeft(timeSubEnd+timeSubStart:timeSubEnd);
                end

                %Right antennal angles
                y = fft(xRightSub);
                L = length(xRightSub);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = fs*(0:(L/2))/L; % find the frequency vector

                fouriStruct(i).fRightSub = f;
                fouriStruct(i).P1RightSub = P1;

                %Left antennal angles
                y = fft(xLeftSub);
                L = length(xLeftSub);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = fs*(0:(L/2))/L; % find the frequency vector

                fouriStruct(i).fLeftSub = f;
                fouriStruct(i).P1LeftSub = P1;
            end
            %}
            %Temporally scramble data and calculate FFT of such
            if doScram == 1 %Launch every Zig
                if exist('xRight') == 1 && exist('xLeft') == 1
                    %Prepare scrambleds
                    xRightScram = zeros(1,size(xRight,2));
                    xRightScram(xRightScram == 0) = NaN;
                    xLeftScram = zeros(1,size(xLeft,2));
                    xLeftScram(xLeftScram == 0) = NaN;

                    %Randomly place values from orig into scram without replacement
                    scramInds = randperm(size(xRight,2));
                    xRightScram(1:end) = xRight(scramInds);
                    xLeftScram(1:end) = xLeft(scramInds);
                        %Note: Right and left still tethered here together (by choice)

                    if size(xRightScram,2) < minSafeLength %Bout too short to analyse
                        disp(['-- Warning: Bout too short to analyse for the given frequencies --'])
                        f = NaN; %X axis; Singleton NaN-ing here may cause issues
                        P1 = NaN; %Raw trace
                    else    

                        %Calculate FFTs like normal
                        %Right antennal angles
                        if length(xRightScram) / 2.0 ~= floor(length(xRightScram) / 2.0)
                            endInd = length(xRightScram) - 1;
                        else
                            endInd = length(xRightScram);
                        end
                        y = fft(xRightScram(1:endInd));
                        %L = length(xRightScram);
                        L = length(y);
                        P2 = abs(y/L);
                        P1 = P2(1:L/2+1);
                        P1(2:end-1) = 2*P1(2:end-1);
                        f = fs*(0:(L/2))/L; % find the frequency vector

                        fouriStruct(i).fRightScram = f;
                        fouriStruct(i).P1RightScram = P1;

                        %Left antennal angles
                        if length(xLeftScram) / 2.0 ~= floor(length(xLeftScram) / 2.0)
                            endInd = length(xLeftScram) - 1;
                        else
                            endInd = length(xLeftScram);
                        end
                        y = fft(xLeftScram(1:endInd));
                        %L = length(xLeftScram);
                        L = length(y);
                        P2 = abs(y/L);
                        P1 = P2(1:L/2+1);
                        P1(2:end-1) = 2*P1(2:end-1);
                        f = fs*(0:(L/2))/L; % find the frequency vector
                    end

                    fouriStruct(i).fLeftScram = f;
                    fouriStruct(i).P1LeftScram = P1;

                    overVar(IIDN).inStruct.xRightScram{i} = xRightScram; %Technically redundant
                    overVar(IIDN).inStruct.xLeftScram{i} = xLeftScram;
                end
            %scram end
            end

            if doSNR == 1
                %%processList = [{'xRight'},{'xLeft'}];
                
                for side = 1:size(processList,2)
                    try
                        [processTarget] = eval(processList{side});
                        %QA
                        processTarget(isnan(processTarget) == 1) = nanmean(processTarget);

                        if size(processTarget,2) < minSafeLength %Bout too short to analyse
                            disp(['-- Warning: Bout too short to analyse for the given frequencies --'])
                            %{
                            p = 1; %Detected peak in Hz
                            SNR = NaN; %SNR value for detected peak
                            filteredF = NaN; %X axis (filtered); Singleton NaN-ing here may cause issues
                            filteredP1 = NaN; %Raw trace (filtered)
                            crushedFilteredP1 = NaN; %Trace sans signal peak
                            antiCrushedFilteredP1 = NaN; %Utilised noise components of trace
                            %}

                            fouriStruct(i).(strcat('sigPeak_',processList{side})) = NaN; %Detected peak in Hz
                            fouriStruct(i).(strcat('sigSNR_',processList{side})) = NaN; %SNR value for detected peak
                            fouriStruct(i).(strcat('sigFilteredF_',processList{side})) = NaN; %X axis (filtered)
                            fouriStruct(i).(strcat('sigFilteredP1_',processList{side})) = NaN; %Raw trace (filtered)
                            fouriStruct(i).(strcat('sigCrushedFilteredP1_',processList{side})) = NaN; %Trace sans signal peak
                            fouriStruct(i).(strcat('sigAntiCrushedFilteredP1_',processList{side})) = NaN; %Utilised noise components of trace

                        else %Bout of sufficient length              
                            %Calculate signal power
                            %%N               = 8192; % FFT length
                            %%leak            = 50;
                            %%leakFraction = 36/8192;
                            % considering a leakage of signal energy to 50 bins on either side of major freq component
                            %fft_s           = fft(inptSignal,N); % analysing freq spectrum
                            %abs_fft_s       = abs(fft_s);
                            if length(processTarget) / 2.0 ~= floor(length(processTarget) / 2.0)
                                endInd = length(processTarget) - 1;
                            else
                                endInd = length(processTarget);
                            end
                            y = fft(processTarget(1:endInd));
                            %%L = length(xRight);
                            %L = size(processTarget,2);
                            L = length(y);
                            P2 = abs(y/L);
                            P1 = P2(1:L/2+1);
                            P1(2:end-1) = 2*P1(2:end-1);
                            f = fs*(0:(L/2))/L; % find the frequency vector

                            filteredF = f(f > min(F) & f < max(F));
                            filteredP1 = P1(f > min(F) & f < max(F));
                            newN = size(filteredF,2);

                            %%[~,p]           = max(abs_fft_s(1:N/2));
                            %%[~,p]           = max(filteredP1(1:end));
                            [~,ceilHzPos,~] = find(filteredF >= ceilHz,1); %Find endpoint to search P1 until
                            [~,p]           = max(filteredP1(1:ceilHzPos));
                            if isempty(p) == 1
                                ['## WARNING: CRITICAL ERROR IN SIGNAL PEAK FIND ##']
                                error = yes
                            end
                            % Finding the peak in the freq spectrum
                            leakSizeActual = floor(size(filteredF,2)*leakFraction);
                                %Note: Current indications have this as a rather tiny value
                                %...and quite possibly 0
                            %%sigpos          = [p-leak:p+leak N-p-leak:N-p+leak];
                            %%sigpos          = [p-leakSizeActual:p+leakSizeActual newN-p-leakSizeActual:newN-p+leakSizeActual];
                            sigpos          = [p-leakSizeActual:p+leakSizeActual]; %Removed signal detection at end of data
                            if min(sigpos) <= 0
                                sigpos = sigpos + leakSizeActual; %Rudimentary protection code
                            end
                            noisepos = [p-leakSizeActual*2-1:p-leakSizeActual-1,p+leakSizeActual+1:p+leakSizeActual*2+1];
                            if min(noisepos) <= 0
                                noisepos = [p+leakSizeActual+1:p+leakSizeActual*3+2]; %Shifts utilised noise to post peak
                            end
                                %Note: This will all be no help if peak is at Nyquist edge
                            % finding the bins corresponding to the signal around the major peak
                            % including leakage
                            %%sig_pow         = sum(abs_fft_s(sigpos)); % signal power = sum of magnitudes of bins conrresponding to signal
                            sig_pow         = sum(filteredP1(sigpos)); % signal power = sum of magnitudes of bins conrresponding to signal
                            %%abs_fft_s([sigpos]) = 0; % making all bins corresponding to signal zero:==> what ever that remains is noise
                            crushedFilteredP1 = filteredP1; %All noise
                            crushedFilteredP1([sigpos]) = 0; % making all bins corresponding to signal zero:==> what ever that remains is noise
                            antiCrushedFilteredP1 = zeros(1,size(filteredP1,2)); %Only relevant noise
                            antiCrushedFilteredP1([noisepos]) = filteredP1([noisepos]);
                            %%noise_pow       = sum(abs_fft_s); % sum of rest of componenents == noise power
                            %%noise_pow       = sum(crushedFilteredP1); % sum of rest of componenents == noise power
                            noise_pow       = sum(crushedFilteredP1([noisepos])); % sum of noise from equivalent size bin
                            SNR             = 10*log10(sig_pow/noise_pow);

                            fouriStruct(i).(strcat('sigPeak_',processList{side})) = filteredF(p); %Detected peak in Hz
                            fouriStruct(i).(strcat('sigSNR_',processList{side})) = SNR; %SNR value for detected peak
                            fouriStruct(i).(strcat('sigFilteredF_',processList{side})) = filteredF; %X axis (filtered)
                            fouriStruct(i).(strcat('sigFilteredP1_',processList{side})) = filteredP1; %Raw trace (filtered)
                            fouriStruct(i).(strcat('sigCrushedFilteredP1_',processList{side})) = crushedFilteredP1; %Trace sans signal peak
                            fouriStruct(i).(strcat('sigAntiCrushedFilteredP1_',processList{side})) = antiCrushedFilteredP1; %Utilised noise components of trace

                            %Use spectro to identify periodicity duration
                            if doSpectro == 1
                                %[y,f,t,p] = spectrogram(xRight,winSize,winOverlap,F,Fs,'yaxis');
                                %tic
                                b = 1;
                                for x = winSizeActive+1:winSizeActive+1:size(processTarget,2) %Note: This will give ~2 samples for a 1 minute bout
                                                                                    %It may be possible to make this truly rolling but it could cost a lot of time
                                                                                        %(Rough projections put it at 1.25:1 with bout durations)
                                    y = fft(processTarget(1,x-winSizeActive:x-1)); %"Select from processTarget in window of size winSize"
                                    L = size(processTarget(1,x-winSizeActive:x-1),2);
                                    P2 = abs(y/L);
                                    P1 = P2(1:L/2+1);
                                    P1(2:end-1) = 2*P1(2:end-1);
                                    f = fs*(0:(L/2))/L; % find the frequency vector

                                    rollFilteredF = f(f > min(F) & f < max(F));
                                    rollFilteredP1 = P1(f > min(F) & f < max(F));
                                    newN = size(rollFilteredF,2);

                                    [~,ceilHzPos,~] = find(rollFilteredF >= ceilHz,1); %Find endpoint to search P1 until
                                    p = []; %Blanking this to be sure of no bleedthrough
                                    [~,p]           = max(rollFilteredP1(1:ceilHzPos));
                                    if isempty(p) == 1
                                        ['## WARNING: CRITICAL ERROR IN SIGNAL PEAK FIND ##']
                                        error = yes
                                    end
                                    % Finding the peak in the freq spectrum
                                    leakSizeActual = floor(size(rollFilteredF,2)*leakFraction);

                                    sigpos          = [p-leakSizeActual:p+leakSizeActual]; %Removed signal detection at end of data
                                    if min(sigpos) <= 0
                                        sigpos = sigpos + leakSizeActual; %Rudimentary protection code
                                    end
                                    noisepos = [p-leakSizeActual*2-1:p-leakSizeActual-1,p+leakSizeActual+1:p+leakSizeActual*2+1];
                                    if min(noisepos) <= 0
                                        noisepos = [p+leakSizeActual+1:p+leakSizeActual*3+2]; %Shifts utilised noise to post peak
                                    end
                                    % finding the bins corresponding to the signal around the major peak (including leakage)
                                    sig_pow         = sum(rollFilteredP1(sigpos)); % signal power = sum of magnitudes of bins corresponding to signal
                                    rollCrushedFilteredP1 = rollFilteredP1; %All noise
                                    rollCrushedFilteredP1([sigpos]) = 0; % making all bins corresponding to signal zero:==> what ever that remains is noise
                                    rollAntiCrushedFilteredP1 = zeros(1,size(rollFilteredP1,2)); %Only relevant noise
                                    rollAntiCrushedFilteredP1([noisepos]) = rollFilteredP1([noisepos]);
                                    noise_pow       = sum(rollCrushedFilteredP1([noisepos])); % sum of noise from equivalent size bin
                                    rollSNR             = 10*log10(sig_pow/noise_pow);

                                    %Save to fouriStruct
                                    fouriStruct(i).(strcat('rollCoords_',processList{side})){b} = [x-winSizeActive,x-1]; 
                                        %Note: Roll coords is formatted according to index within xRight and xLeft, which are subsets of right and leftThetaProc respectively based on inStruct holeRanges
                                    fouriStruct(i).(strcat('rollSigPeak_',processList{side}))(b) = rollFilteredF(p);
                                    fouriStruct(i).(strcat('rollSigSNR_',processList{side}))(b) = rollSNR;
                                    %{
                                    %Testatory for investigating 0.1Hz preponderance in prob data
                        if side == 3 && rollSNR > 1 && rollFilteredF(p) < 0.1
                            figure
                            plot(f,P1)
                            xlim([min(F),1])
                            title(['i: ',num2str(i),' - x: ',num2str(x)])
                            %wildside
                        end
                                    %}
                                    b = b + 1;
                                end
                                %toc
                            %doSpectro end    
                            end

                        %minSafeLength end
                        end

                        %{
                        %(This portion moved as was suffering bleedthrough from doSpectro portion)
                        %%fouriStruct(i).sigPeak = filteredF(p); %Detected peak in Hz
                        fouriStruct(i).(strcat('sigPeak_',processList{side})) = filteredF(p); %Detected peak in Hz
                        fouriStruct(i).(strcat('sigSNR_',processList{side})) = SNR; %SNR value for detected peak
                        fouriStruct(i).(strcat('sigFilteredF_',processList{side})) = filteredF; %X axis (filtered)
                        fouriStruct(i).(strcat('sigFilteredP1_',processList{side})) = filteredP1; %Raw trace (filtered)
                        fouriStruct(i).(strcat('sigCrushedFilteredP1_',processList{side})) = crushedFilteredP1; %Trace sans signal peak
                        fouriStruct(i).(strcat('sigAntiCrushedFilteredP1_',processList{side})) = antiCrushedFilteredP1; %Utilised noise components of trace
                        %}

                        %To implement:
                        %Rolling SNR code that uses a sliding noise window that redistributes automatically at low and high indexes
                        %SNR end
                    catch
                        disp(['-# Caution: Could not SNR ',processList{side},' #-'])
                        love
                        processList = processList( find([1:size(processList,2)]~=side) );
                        disp(['(Element removed from processList)'])
                    end
                %side end
                end
            %doSNR end    
            end
            
        %inStruct end
        end
        if splitBouts ~= 1
            overVar(IIDN).inStruct = inStruct; %Not the best but keeps things sleek
        else
            overVar(IIDN).splitStruct = inStruct; %Name alteration because of name alteration when this is drawn from overVar
        end

    %%catch
    %    ['## Warning: Could not calculate FFT for ',overVar(IIDN).fileDate,' ##']
    %%end
    %freak
    %Process ligated antennal angles
    %fs = 30; %Sampling rate of data
    %fs = overVar(IIDN).dataFrameRate; %Already acquired above
    if doFFT == 1
        if exist('xRight','var') == 1
            if size(rightThetaHoleAll,2) < minSafeLength
                ['-- Alert: Ligated antennal data is of insufficient length --']
                f = NaN;
                P1 = NaN;
            else
                %Right antennal angles
                y = fft(rightThetaHoleAll);
                L = length(rightThetaHoleAll);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = fs*(0:(L/2))/L; % find the frequency vector

                fouriStruct(1).allFRight = f;
                fouriStruct(1).allP1Right = P1;

                %Left antennal angles
                y = fft(leftThetaHoleAll);
                L = length(leftThetaHoleAll);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = fs*(0:(L/2))/L; % find the frequency vector
            end

            fouriStruct(1).allFLeft = f;
            fouriStruct(1).allP1Left = P1;
        end
        
        %-------------------------------------------------------------
        
        %Rolling FFT across whole recording
        %Right antennal angles
        %tic
        rollStruct = struct;
        %winSizeActive = floor(29*overVar(IIDN).dataFrameRate)
        for side = 1:size(processList,2)
            %if exist('xRight','var') == 1
            if contains( processList{side}, 'xRight' ) == 1 || contains( processList{side}, 'xLeft' ) == 1
                sourceData = overVar(IIDN).( strcat(processList{side},'All') );
            elseif contains( processList{side}, 'probData' ) == 1
                sourceData = overVar(IIDN).probMetric;
            end
            %QA
            sourceData(isnan(sourceData) == 1) = nanmean(sourceData);
            a = 1;
            %sourceData = xRightAll;
            for binInd = winSizeActive:winSizeActive:size( sourceData,1 )
                fftData = sourceData(binInd-winSizeActive+1:binInd);

                if length(fftData) / 2.0 ~= floor(length(fftData) / 2.0) %Ensure even size
                    endInd = length(fftData) - 1;
                else
                    endInd = length(fftData);
                end

                y = fft(fftData(1:endInd));
                %L = length(xRight);
                L = length(y);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = fs*(0:(L/2))/L; % find the frequency vector

                %rollStruct(a).f = f;
                %rollStruct(a).P1 = P1;
                %rollStruct(a).inds = [binInd-winSizeActive+1:binInd];
                rollStruct(a).(processList{side}).f = f;
                rollStruct(a).(processList{side}).P1 = P1;
                rollStruct(a).(processList{side}).inds = [binInd-winSizeActive+1:binInd];
                
                %And calculate SNR too (May add time)
                filteredF = f(f > min(F) & f < max(F));
                filteredP1 = P1(f > min(F) & f < max(F));
                newN = size(filteredF,2);

                [~,ceilHzPos,~] = find(filteredF >= ceilHz,1); %Find endpoint to search P1 until
                [~,p]           = max(filteredP1(1:ceilHzPos));
                if isempty(p) == 1
                    ['## WARNING: CRITICAL ERROR IN SIGNAL PEAK FIND ##']
                    error = yes
                end
                % Finding the peak in the freq spectrum
                leakSizeActual = floor(size(filteredF,2)*leakFraction);
                    %Note: Current indications have this as a rather tiny value
                    %...and quite possibly 0
                sigpos          = [p-leakSizeActual:p+leakSizeActual]; %Removed signal detection at end of data
                if min(sigpos) <= 0
                    sigpos = sigpos + leakSizeActual; %Rudimentary protection code
                end
                noisepos = [p-leakSizeActual*2-1:p-leakSizeActual-1,p+leakSizeActual+1:p+leakSizeActual*2+1];
                if min(noisepos) <= 0
                    noisepos = [p+leakSizeActual+1:p+leakSizeActual*3+2]; %Shifts utilised noise to post peak
                end
                    %Note: This will all be no help if peak is at Nyquist edge
                % finding the bins corresponding to the signal around the major peak
                % including leakage
                sig_pow         = sum(filteredP1(sigpos)); % signal power = sum of magnitudes of bins conrresponding to signal
                crushedFilteredP1 = filteredP1; %All noise
                crushedFilteredP1([sigpos]) = 0; % making all bins corresponding to signal zero:==> what ever that remains is noise
                antiCrushedFilteredP1 = zeros(1,size(filteredP1,2)); %Only relevant noise
                antiCrushedFilteredP1([noisepos]) = filteredP1([noisepos]);
                noise_pow       = sum(crushedFilteredP1([noisepos])); % sum of noise from equivalent size bin
                SNR             = 10*log10(sig_pow/noise_pow);
                
                rollStruct(a).(processList{side}).sigPeak = filteredF(p);
                rollStruct(a).(processList{side}).sigSNR = SNR;
                                
                a = a + 1;
            end
            %toc

            %{
            figure
            hold on
            for rollInd = 1:size(rollStruct,2)
                plot(rollStruct(rollInd).(processList{side}).f( rollStruct(rollInd).(processList{side}).f > F(1) & rollStruct(rollInd).(processList{side}).f < F(end) ) ,...
                    rollStruct(rollInd).(processList{side}).P1( rollStruct(rollInd).(processList{side}).f > F(1) & rollStruct(rollInd).(processList{side}).f < F(end) ))
                %plot(blirg(lirg).f( blirg(lirg).f > viewWindow(1) & blirg(lirg).f < viewWindow(2) )  , blirg(lirg).P1( blirg(lirg).f > viewWindow(1) & blirg(lirg).f < viewWindow(2) ) ./...
                %    nanmax(blirg(lirg).P1( blirg(lirg).f > viewWindow(1) & blirg(lirg).f < viewWindow(2) )))
                hold on
                %title('prob')
                %title([processList{side},' rolling FFT'])
            end
            xlim([F(1),F(end)])
            title([processList{side},' rolling FFT'])
            %}
            clear sourceData
            %end
        end
        
        %-------------------------------------------------------------

        overFouri(IIDN).fouriStruct = fouriStruct;
        overFouri(IIDN).winSizeActive = winSizeActive;
        overFouri(IIDN).winOverlapSizeActive = winOverlapSizeActive;
        overFouri(IIDN).rollStruct = rollStruct;
    
    end
    
    %If control, mirror to control structure
    if overVar(IIDN).controlState == 1
        %%overFouriCont(c) = overFouri(IIDN);
        oVarNames = fieldnames(overFouri); %Get overVar fieldnames
        for z = 1:size(oVarNames,1)
            overFouriCont(c).(oVarNames{z}) = overFouri(IIDN).(oVarNames{z});
        end
    end
    
    disp(['-- ', num2str(IIDN), ' of ', num2str(size(overVar,2)), ' FFT analysis complete --'])
    clear probMetric rightThetaProc leftThetaProc
%IIDN end
end

%Collate fouriStruct data into table
summTab = struct;

pooledSummTab = struct;
pooledSummTab.allPeaks = [];

if size(overFouri,2) ~= size(overVar,2)
   ['## ERROR: ASYMMETRY DETECTED BETWEEN OVERFOURI AND OVERVAR ##']
   error = yes
end
for IIDN = 1:size(overFouri,2)
    summTab(IIDN).fileName = overVar(IIDN).fileDate;
    
        
    for side = 1:size(processList,2)
        summTab(IIDN).(strcat('supraThreshSNRCount_',processList{side})) = 0; %Count of significant SNRS for this side
        summTab(IIDN).(strcat('supraThreshSNRIDs_',processList{side})) = []; %Bout IDs for significant SNRS
        summTab(IIDN).(strcat('supraThreshSNRPeaks_',processList{side})) = []; %Frequency position of significant SNR
        for i = 1:size(overFouri(IIDN).fouriStruct,2)
            %fouriStruct(i).(strcat('sigPeak_',processList{side}))
            if overFouri(IIDN).fouriStruct(i).(strcat('sigSNR_',processList{side})) > SNRThresh
                summTab(IIDN).(strcat('supraThreshSNRCount_',processList{side})) = summTab(IIDN).(strcat('supraThreshSNRCount_',processList{side})) + 1;
                summTab(IIDN).(strcat('supraThreshSNRIDs_',processList{side})) = [summTab(IIDN).(strcat('supraThreshSNRIDs_',processList{side})), i];
                summTab(IIDN).(strcat('supraThreshSNRPeaks_',processList{side})) = [summTab(IIDN).(strcat('supraThreshSNRPeaks_',processList{side})), overFouri(IIDN).fouriStruct(i).(strcat('sigPeak_',processList{side}))];                
            end
        end
        summTab(IIDN).(strcat('supraThreshSNRCountFractionOfAll_',processList{side})) = summTab(IIDN).(strcat('supraThreshSNRCount_',processList{side})) / size(overFouri(IIDN).fouriStruct,2);
    
    pooledSummTab.allPeaks = [pooledSummTab.allPeaks, summTab(IIDN).(strcat('supraThreshSNRPeaks_',processList{side}))];  
    %side end    
    end
        
end

%{
%Remove anomalous fouris
    %Note: This is based on a strong assumption of the current layout of data sets
fouriCullList = [{{2,13:16}},{{3,12:13}},{{3,36}},{{4,3}},{{4,7}},{{5,17:18}},{{6,1:38}},{{8,1}},{{8,5}},{{8,7}},{{8,13:15}}];
    %This is a list of the specific holes that have seemingly anomalous FFT results and have been chosen to be culled for noise' sake
for i = 1:size(fouriCullList,2) 
    for x = 2
        for y = 1:size(fouriCullList{i}{x},2)
            overFouri(fouriCullList{i}{1}).fouriStruct(fouriCullList{i}{2}(y)).fRight = [];
            overFouri(fouriCullList{i}{1}).fouriStruct(fouriCullList{i}{2}(y)).P1Right = [];
            overFouri(fouriCullList{i}{1}).fouriStruct(fouriCullList{i}{2}(y)).fLeft = [];
            overFouri(fouriCullList{i}{1}).fouriStruct(fouriCullList{i}{2}(y)).P1Left = [];
        end
    end
end
%This loop takes list of files/hole numbers (e.g. {{2,13:16}}) and nulls
%those instances in the overFouri structure
%}
%(Takes a really long time)
%{
%Process fouris
for i = 1:size(overFouri,2)
    overFouri(i).sumFouri = struct;
    preSumFVals = [];
    for x = 1:size(overFouri(IIDN).fouriStruct,2)
        preSumFVals = [preSumFVals, overFouri(IIDN).fouriStruct(x).fRight];
    end
    sumfVals = sort(preSumFVals);
    allP1Vals = [];
    for x = 1:size(overFouri(IIDN).fouriStruct,2)
        for y = 1:size(overFouri(IIDN).fouriStruct(x).P1Right,2)
            fInd = find(sumfVals == overFouri(IIDN).fouriStruct(x).fRight(y), 1, 'last');
            allP1Vals(x,fInd) = overFouri(IIDN).fouriStruct(x).P1Right(y);
        end
    end
    sumP1Vals = [];
    for x = 1:size(allP1Vals,2)
        sumP1Vals(1,x) = nansum(allP1Vals(:,x));
    end
end
%}

if doTimeCalcs == 1    
    %(Old location of PE detection)
    
    disp([char(10)])
    
    %Calculate sleep curves
    for IIDN = 1:size(overVar,2)
        railStruct = struct; %This is used to simplify the storage of some of the dynamic variables further down
        %inStruct = overVar(IIDN).inStructCarry; %Note: inStruct timing based on movFrameMovCntrAvSize
                                                %...which should theoretically be synchronious with DorsFrame timing
        inStruct = overVar(IIDN).inStruct; %Force use of 'original' (non-segmented) sleep bouts
        probMetric = overVar(IIDN).probMetric;
        
        %------------------------------------------------------------------
        
        if doSpectro == 1 && forceSynchronyOfRail == 1
            forcedCols = 0;
        end
        if doSpectro == 1 && flattenRail == 1
            flattenedCols = 0;
        end
        
        %Assemble continuous array of sleep vs not sleep
        sleepRail = []; 
            %Col 1 - Sleep binary, Col 2 - Posix, Col 3 - PE binary, Col 4/6/8 - Perio. in right/left/prob binary, Col 5/7/9 - Freq. pos. of perio. in right/left/prob, Col 10 - Time(s) since 5PM on the first day of the recording, Col 11 - Inter-frame interval
        sleepRail = zeros(size(overVar(IIDN).overGlob.movFrameMovCntrAvSize,1),1,1); %Assemble zeroes of size of angle data       
        for i = 1:size(inStruct.holeRanges,2)
            sleepRail(inStruct.holeRanges{i},1) = 1; %Set times when sleep occuring to 1 (Column 1)
        end
        sleepRail(:,2) = overVar(IIDN).overGlob.movFrameTime; %Append posix time of mov frames (Column 2)
        %sleepRail(:,3) = probScatter(IIDN).avProbContourSizeSmoothedEvent; %Append binary judgement of whether PE occurring or not (Note: This is only within sleep bouts) (Column 3)
            %Note: avProbContourSizeSmoothedEvent only lists PEs within sleep bouts
                %Secondary note: Doesn't seem based on PE detection but rather contour size > mean (Ln 1500 -> 2046)
        sleepRail(:,3) = overAllPE(IIDN).allPEStruct.allPERail(:,2); %New, modified to use proper PE detection 
                    
        if exist('overFouri') == 1
            %sleepRail(:,4) = NaN;
            %sleepRail(:,5) = 0; %Note: NaNs are not recommended here because of how they interact with the 'unique' command
                %These preceding two lines superseded by a move to maintenance of side identity for significance and peaks
            for side = 1:size(processList,2)
                sleepRail(:,2+side*2) = NaN;
                sleepRail(:,3+side*2) = 0; %Note: NaNs are not recommended here because of how they interact with the 'unique' command
                    %Nominally this will wipe columns 4,5 and 6,7
            end
            inStructCarry = overVar(IIDN).inStructCarry; %Use segmented inStruct (if applicable) because it more easily aligns with fouriStruct
            for i = 1:size(inStructCarry.holeRanges,2)
                %sleepRail(inStructCarry.holeRanges{i},4) = 0; %Superseded by dynamic side usage
                for side = 1:size(processList,2)
                    sleepRail(inStructCarry.holeRanges{i},2+side*2) = 0;
                    for x = 1:size(overFouri(IIDN).fouriStruct(i).(strcat('rollSigSNR_',processList{side})),2)
                        if overFouri(IIDN).fouriStruct(i).(strcat('rollSigSNR_',processList{side}))(x) > SNRThresh && ...
                                ( overFouri(IIDN).fouriStruct(i).(strcat('rollSigPeak_',processList{side}))(x) >= min(targetPerioFreqRange) && ...
                                overFouri(IIDN).fouriStruct(i).(strcat('rollSigPeak_',processList{side}))(x) <= max(targetPerioFreqRange) )   
                                %"If periodicity was detected in rolling window within the target frequency in this bout segment"
                                   
                            rollCoordsToApply = overFouri(IIDN).fouriStruct(i).(strcat('rollCoords_',processList{side})){x};
                            sleepRailCoordsToApply = inStructCarry.holeRanges{i}(rollCoordsToApply(1):rollCoordsToApply(2));
                            %sleepRail(sleepRailCoordsToApply,4) = 1; %Significant antennal periodicity with targetPerioFreq detected (Column 4)
                            sleepRail(sleepRailCoordsToApply,2+side*2) = 1; %Significant antennal periodicity with targetPerioFreq detected (Column/s 4 and 6)
                                %The lack of a zeroing counterpart to this means that any positive instance will cause a hit
                            %[num2str(i), ' - ', processList{side}, ' - ', num2str(x),' - ', num2str(overFouri(IIDN).fouriStruct(i).(strcat('rollSigSNR_',processList{side}))(x)), ...
                            %    ' - [', num2str(num2str(inStructCarry.holeRanges{i}(rollCoordsToApply(1)))), ',', num2str(inStructCarry.holeRanges{i}(rollCoordsToApply(2))),']']
                            %sleepRail(sleepRailCoordsToApply,5) = overFouri(IIDN).fouriStruct(i).(strcat('rollSigPeak_',processList{side}))(x); %Append detected signal peak position (Column 5)
                            sleepRail(sleepRailCoordsToApply,3+side*2) = overFouri(IIDN).fouriStruct(i).(strcat('rollSigPeak_',processList{side}))(x); %Append detected signal peak position (Column/s 5 and 7)
                            
                            %Check for synchrony of rail
                            if doSpectro == 1 && doProbSpectro == 1 && forceSynchronyOfRail == 1 && isempty(strfind(processList{side},'probData')) == 1 %"If forcing rail synchrony AND not probData"
                                %Caution: forceSynchronyOfRail may be failing on side == 1 case? [Deprecated?]
                                %Note: forceSynchronyOfRail is not actually used often
                                freqSigNotPresent = 0; %Keeps track of whether significance is present in all applicable columns
                                freqPosNotPresent = 0; %Ditto but for the peak pos.
                                
                                %Check
                                for sode = 1:size(processList,2) %Iterate along list of processTargets
                                    if isempty(strfind(processList{sode},'probData')) == 1 %&& sode ~= side %...but only operate if not actuating on probData %or itself
                                            %Note: Self recognition disabled because it was reducing effectiveness to 50%
                                        %Sig
                                        if isnan(sleepRail(sleepRailCoordsToApply(1),2+sode*2)) ~= 1 && sleepRail(sleepRailCoordsToApply(1),2+sode*2) ~= 1 %Check for significance
                                                %Note: isnan is critical in this statement for the case of side == 1, where the side == 2 column has not even been assigned yet
                                                    %If an out is not provided via isnan then the side == 1 case will always return an absence of significance for (the not-yet-processed) side == 2 case
                                            freqSigNotPresent = freqSigNotPresent + 1; %Significance was not present in this column
                                            %blirg{bl} = processList{sode};
                                            %bl = bl + 1;
                                        end
                                        %Freq
                                        if isnan(sleepRail(sleepRailCoordsToApply(1),2+sode*2)) ~= 1 && sleepRail(sleepRailCoordsToApply(1),3+sode*2) ~= sleepRail(sleepRailCoordsToApply(1),3+side*2) %Check for identicality of detected freq.
                                                %Note: High chance this may be over-conservative
                                            freqPosNotPresent = freqPosNotPresent + 1; %Same frequency peak was not present in this column
                                        end
                                    end
                                end
                                
                                %Flatten (if required)
                                if freqSigNotPresent ~= 0 || freqPosNotPresent ~= 0
                                    for sode = 1:size(processList,2)
                                        if isempty(strfind(processList{sode},'probData')) == 1 %Don't flatten prob column
                                            sleepRail(sleepRailCoordsToApply,2+sode*2) = 0; %Flatten sig. column
                                            sleepRail(sleepRailCoordsToApply,3+sode*2) = 0; %Flatten freq. pos. column
                                                %WARNING: CHECK FOR PROPHECY-FULFILLMENT INDUCTION AS A RESULT OF THIS
                                        end
                                    end
                                    forcedCols = forcedCols + 1;
                                end
                                
                            %forceSynchrony end    
                            end
                            
                            %Use probData to flatten 'anomalous' antennal frequency detection, if requested (But don't flatten prob. activity)
                            if doSpectro == 1 && isempty(strfind(processList{side},'probData')) ~= 1 && flattenRail == 1 %&& size(processList,2) == 3 %"If side == probData AND requesting to flatten rail %AND 3 process targets total"
                                %Note: Significance of probData peridicity assured from parent if statements
                                %{
                                sleepRail(sleepRailCoordsToApply,2+1*2) = 0; %Flatten xRight significance column (Hardcoded)
                                sleepRail(sleepRailCoordsToApply,3+1*2) = 0; %Flatten xRight freq. pos. column
                                sleepRail(sleepRailCoordsToApply,2+2*2) = 0; %Flatten xLeft significance column
                                sleepRail(sleepRailCoordsToApply,3+2*2) = 0; %Flatten xLeft freq. pos. column
                                    %Note: These lines are hardcoded for a process list made of 'xRight', 'xLeft' and 'probData'
                                        %Anything less and if this operates there will be odd behaviour
                                        %Anything additional and the columns will not be flattened
                                %}
                                
                                for sode = 1:side-1 %Iterate until one less than the current side
                                    if sleepRail(sleepRailCoordsToApply(1),2+sode*2) == 1 %Only flatten if significance exists (Note: This may be too conservative)
                                        sleepRail(sleepRailCoordsToApply,2+sode*2) = 0; %Flatten sig. column
                                        sleepRail(sleepRailCoordsToApply,3+sode*2) = 0; %Flatten freq. pos. column
                                        flattenedCols = flattenedCols + 1;
                                            %By placing this here and only flattening if there was significance to be flattened, flattenedCols should
                                            %represent the actual count of when there was bleedover between prob. and ant. periodicity
                                    end
                                end
                                %flattenedCols = flattenedCols + 1; %Keep a count of how many times this was done
                                
                            end
                            
                            %QA
                            if size(rollCoordsToApply,2) > 2 || ...
                                    nansum(sleepRail(sleepRailCoordsToApply,1)) ~= (max(sleepRailCoordsToApply) - min(sleepRailCoordsToApply)) + 1
                                ['## Alert: Critical error in rollCoords ##']
                                error = yes %Note: Designed to catch on either too many rollCoords OR attempts to write outside a bout
                                                %The latter case may actually happen given slight asymmetries
                            end

                        end
                    %x end    
                    end                 
                %side end    
                end
            %holeRanges end    
            end
            
            %New: Flatten based on pure presence of PE, regardless of periodicity
            if flattenRail == 1 && flattenAllPEs == 1
                peFlattenedSigs = 0;
                if isempty( overAllPE(IIDN).allPEStruct.allLOCS ) ~= 1
                    for n = 1:size( overAllPE(IIDN).allPEStruct.allLOCS , 1 )
                        for sode = 1:size( processList,2 ) 
                            if isempty(strfind(processList{sode},'probData')) == 1
                                if sleepRail( overAllPE(IIDN).allPEStruct.allLOCS(n) ,2+sode*2) == 1
                                    peFlatCoords = floor([ overAllPE(IIDN).allPEStruct.allLOCS(n) - probInterval * overVar(IIDN).dataFrameRate : overAllPE(IIDN).allPEStruct.allLOCS(n) + probInterval * overVar(IIDN).dataFrameRate ]);
                                    peFlatCoords( peFlatCoords < 1 ) = []; peFlatCoords( peFlatCoords > size(sleepRail,1) ) = []; %QA
                                    sleepRail(peFlatCoords,2+sode*2) = 0; %Flatten sig. column
                                    sleepRail(peFlatCoords,3+sode*2) = 0; %Flatten freq. pos. column
                                    peFlattenedSigs = peFlattenedSigs + 1;
                                end
                            end
                        end
                    end
                end
            end
            
        %exist end    
        end
        
        %Append time post-5PM for easier CuSu analysis
        %Calculate relative posix
        firstNonNaNMovFrameInd = find(isnan(sleepRail(:,2)) ~= 1,1,'First');
        firstMovFrameTime = datestr(datetime(sleepRail(firstNonNaNMovFrameInd,2), 'ConvertFrom', 'posixtime')); %Find datetime of first mov frame

        ZTarget = num2str(sleepCurveZTNums(1));
        ZTargetNum = str2num(ZTarget);

        timeToFind = firstMovFrameTime; %Stage 1
        timeToFind(end-7:end) = '00:00:00'; %Zero out HMS
        timeToFind(end-7:end-8+size(ZTarget,2)) = ZTarget; %Set HMS to target ZT

        timeToFindPosix = posixtime(datetime(timeToFind,'Format', 'dd-MM-yyyy HH:mm:ss')); %Takes the manually assembled target ZT and converts it to a posix

        sleepRail(:,size(sleepRail,2)+1) = sleepRail(:,2) - timeToFindPosix; %Col <10> - Time(s) since 5PM on the first day of the recording
            %Note: If a recording was started early in the day most of these values will be negative
                %I.e. An 8AM-start recording will be negative until 9 hours later
        
        sleepRail(:,size(sleepRail,2)+1) =  [0; diff( sleepRail(:,2) )]; %Inter-frame time difference
                
        railStruct.sleepRail = sleepRail;
        
        %QA
        if size(overVar(IIDN).overGlob.movFrameTime,1) ~= size(overVar(IIDN).overGlob.movFrameMovCntrAvSize,1) || size(overVar(IIDN).overGlob.movFrameTime,1) ~= size(probScatter(IIDN).avProbContourSizeSmoothedEvent,1)
            ['## Warning: Critical asymmetry in movFrame ##']
            error = yes
        end
        
        %------------------------------------------------------------------
        
        %{
        %Find invididual datetime for every single frame
        %Note: This carries zero assumptions but takes like, 16 minutes per recording
        for i = 1:size(sleepRail,1) 
            thisMovFrameTimeStr = datestr(datetime(sleepRail(i,2), 'ConvertFrom', 'posixtime'));
            sleepRail(i,3) = str2num(thisMovFrameTimeStr(end-7:end-6)); %Write the hour of the day into column 3 (Hardcoded format)
            sleepRail(i,4) = str2num(thisMovFrameTimeStr(end-4:end-3)) / 60.0; %Ditto, for minute of the hour
        end
        %}
        %Assign ZTs to unique posixtimes       
        firstNonNaNMovFrameInd = find(isnan(sleepRail(:,2)) ~= 1,1,'First'); %This is necessary due to NaN padding of mov data
        firstMovFrameTime = datestr(datetime(sleepRail(firstNonNaNMovFrameInd,2), 'ConvertFrom', 'posixtime')); %Find datetime of first mov frame
        lastNonNaNMovFrameInd = find(isnan(sleepRail(:,2)) ~= 1,1,'Last'); 
        lastMovFrameTime = datestr(datetime(sleepRail(lastNonNaNMovFrameInd,2), 'ConvertFrom', 'posixtime')); %Find datetime of last (non-NaN) mov frame

        sleepZTRangeYs = [];
        for i = 1:size(sleepCurveZT,2)
            ZTarget = sleepCurveZT{i};
            ZTargetNum = sleepCurveZTNums(i);
            if nanmax(sleepCurveZTNums(1:i)) <= ZTargetNum %This theoretically should calculate if the current ZT is on the near side of the midnight boundary
                %Basically works by finding if a given ZT is the ordered max of all ZTs (i.e. 23 is the max of 21,22,23 but 01 is not the max of 21,22,23,00,01)
                %(Might behave erratically with disorded ZTs or odd lists of ZTs)
                timeToFind = firstMovFrameTime; %Stage 1
            else %"ZT on far side of midnight boundary"
                timeToFind = lastMovFrameTime;
            end
            timeToFind(end-7:end) = '00:00:00'; %Zero out HMS
            timeToFind(end-7:end-8+size(ZTarget,2)) = ZTarget; %Set HMS to target ZT
            
            timeToFindPosix = posixtime(datetime(timeToFind,'Format', 'dd-MM-yyyy HH:mm:ss')); %Takes the manually assembled target ZT and converts it to a posix
            sleepZTRangeYs(i) = timeToFindPosix; %Note: Unlike other RangeYs, this will be a 1:1 array of inclusive starts/ends, rather than 1:2 array of starts and separate ends
        end        
        
        %Bin sleep and PEs (and antennal periodicity) according to hour
        %{
        sleepRailZTCurveBinned = [];
        sleepRailZTCurveBinnedSum = [];
        sleepRailZTPEsBinned = [];
        sleepRailZTPEsBinnedSum = [];
        if exist('overFouri') == 1
            sleepRailZTAntPerioBinned = [];
            sleepRailZTAntPerioBinnedSum = [];
            sleepRailZTAntPerioFreqPosBinned = [];
        end
        %}        
        for i = 1:size(sleepCurveZT,2)-1
            railStruct.sleepRailZTCurveCoords{i} = find([sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1)] == 1);
            railStruct.sleepRailZTCurveStartEndTime{i} = [ sleepRail( nanmin(railStruct.sleepRailZTCurveCoords{i}) ,2) , sleepRail( nanmax(railStruct.sleepRailZTCurveCoords{i}) ,2) ];
            %Sleep
            railStruct.sleepRailZTCurveBinned{i} = sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,1 ); %1s in this array = Sleeping, 0 = Not sleeping
            %sleepRailZTCurveBinned{i} = sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,1 ); %1s in this array = Sleeping, 0 = Not sleeping
                %"Select column 1 (sleep binary) from sleepRail column 1 where the posix was larger or equal to the target ZT posix and less than the target + 1 ZT posix"
            if isempty(railStruct.sleepRailZTCurveBinned{i}) ~= 1
            %if isempty(sleepRailZTCurveBinned{i}) ~= 1
                %%railStruct.sleepRailZTCurveBinnedSum(i) = nansum(railStruct.sleepRailZTCurveBinned{i}); %Sum of inactive frames that were big/contiguous enough to be a bout occurring during this ZT range
                    %Note: Will only accurately convert to seconds if framerate consistent
                %sleepRailZTCurveBinnedSum(i) = nansum(sleepRailZTCurveBinned{i}); %Sum of inactive frames that were big/contiguous enough to be a bout occurring during this ZT range
                railStruct.sleepRailZTCurveBinnedSumTime{i} = nansum( railStruct.sleepRail( railStruct.sleepRailZTCurveCoords{i}( railStruct.sleepRail( railStruct.sleepRailZTCurveCoords{i} , 1) == 1 ) , size(railStruct.sleepRail,2) ) );
                    %Find all places where coords of this sleep bout also coincided with sleep == 1 (Col 1 of sleepRail), use those derived coords to grab the inter-frame time differences
                        %Note: This is a true time-based system, unlike the original CurveBinnedSum, which relied on each frame representing exactly 1.0/dataFrameRate seconds
            else
                %%railStruct.sleepRailZTCurveBinnedSum(i) = NaN; %Should be useful later on for separating late/early starting flies that might postcede an early ZT bin
                %sleepRailZTCurveBinnedSum(i) = NaN; %Should be useful later on for separating late/early starting flies that might postcede an early ZT bin
                railStruct.sleepRailZTCurveBinnedSumTime{i} = NaN;
            end
            
            %PEs
                %NOTE: ONLY CAPTURES PES THAT OCCURRED DURING SLEEP BOUTS
            railStruct.sleepRailZTPEsBinned{i} = sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,3 ); %1s in this array = PE event, 0 = No PE event
            %sleepRailZTPEsBinned{i} = sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,3 ); %1s in this array = PE event, 0 = No PE event
                %"Select column 3 (PE binary) from sleepRail column 1 where the posix was larger or equal to the target ZT posix and less than the target + 1 ZT posix"
            if isempty(railStruct.sleepRailZTPEsBinned{i}) ~= 1
            %if isempty(sleepRailZTPEsBinned{i}) ~= 1
                railStruct.sleepRailZTPEsBinnedSum(i) = nansum(railStruct.sleepRailZTPEsBinned{i}); %Sum of inactive frames that were big/contiguous enough to be a bout occurring during this ZT range
                %sleepRailZTPEsBinnedSum(i) = nansum(sleepRailZTPEsBinned{i}); %Sum of inactive frames that were big/contiguous enough to be a bout occurring during this ZT range
                railStruct.sleepRailZTPEsBinnedSumTime{i} = nansum( railStruct.sleepRail( railStruct.sleepRailZTCurveCoords{i}( railStruct.sleepRail( railStruct.sleepRailZTCurveCoords{i} , 3) == 1 ) , size(railStruct.sleepRail,2) ) );
                    %Ditto sleepRailZTCurveBinnedSumTime above, except for PEs
            else
                railStruct.sleepRailZTPEsBinnedSum(i) = NaN; %Should be useful later on for separating late/early starting flies that might postcede an early ZT bin
                %sleepRailZTPEsBinnedSum(i) = NaN; %Should be useful later on for separating late/early starting flies that might postcede an early ZT bin
                railStruct.sleepRailZTPEsBinnedSumTime{i} = NaN;
            end

            %<Insert body part here> periodicity
            if exist('overFouri') == 1
                for side = 1:size(processList,2)
                   railStruct.(strcat('sleepRailZTAntPerioBinned_',processList{side})){i} = ... 
                       sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,2+side*2 ); %1s in this array = ant. perio., 0 = No ant. perio.
                    %sleepRailZTAntPerioBinned{i} = sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,4 ); %1s in this array = ant. perio., 0 = No ant. perio.
                        %"Select column 4 (antennal periodicity binary) from sleepRail column 1 where the posix was larger or equal to the target ZT posix and less than the target + 1 ZT posix"
                    
                    railStruct.(strcat('sleepRailZTAntPerioFreqPosBinned_',processList{side})){i} = ...
                        sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,3+side*2 ); %Values in this array represent detected signal peak position
                    %sleepRailZTAntPerioFreqPosBinned{i} = sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) ,5 ); %Values in this array represent detected signal peak position
                        %Ditto, but select column 5 (Ant. perio. freq. position)
                        
                    if isempty(railStruct.(strcat('sleepRailZTAntPerioBinned_',processList{side})){i}) ~= 1
                    %if isempty(sleepRailZTAntPerioBinned{i}) ~= 1
                        railStruct.(strcat('sleepRailZTAntPerioBinnedSum_',processList{side}))(i) = ...
                            nansum(railStruct.(strcat('sleepRailZTAntPerioBinned_',processList{side})){i}); %Sum of inactive frames that were big/contiguous enough to be a bout occurring during this ZT range
                        %sleepRailZTAntPerioBinnedSum(i) = nansum(sleepRailZTAntPerioBinned{i}); %Sum of inactive frames that were big/contiguous enough to be a bout occurring during this ZT range
                        railStruct.(strcat('sleepRailZTAntPerioBinnedTime_',processList{side}))(i) = ...
                            nansum( sleepRail( sleepRail(:,2) >= sleepZTRangeYs(i) & sleepRail(:,2) < sleepZTRangeYs(i+1) & sleepRail( : , 2+side*2 ) == 1 , size(sleepRail,2) ) );
                                %Marry sleep ZT coords with periodicity determination to pull inter-frame times then sum
                    else
                        railStruct.(strcat('sleepRailZTAntPerioBinnedSum_',processList{side}))(i) = ...
                            NaN; %Should be useful later on for separating late/early starting flies that might postcede an early ZT bin
                        %sleepRailZTAntPerioBinnedSum(i) = NaN; %Should be useful later on for separating late/early starting flies that might postcede an early ZT bin
                        railStruct.(strcat('sleepRailZTAntPerioBinnedTime_',processList{side}))(i) = ...
                            NaN;
                    end
                %side end    
                end
            end
            
        %sleepCurveZT end    
        end
        
        sleepRail = []; %To prevent bleedover
        
        %Save data for overUse
        overVar(IIDN).railStruct = railStruct;
        %{
        overVar(IIDN).sleepRail = sleepRail;
        overVar(IIDN).sleepRailZTCurveBinnedSum = sleepRailZTCurveBinnedSum;
        overVar(IIDN).sleepRailZTPEsBinnedSum = sleepRailZTPEsBinnedSum;
        if exist('overFouri') == 1
            overVar(IIDN).sleepRailZTAntPerioBinnedSum = sleepRailZTAntPerioBinnedSum;
            overVar(IIDN).sleepRailZTAntPerioFreqPosBinned = sleepRailZTAntPerioFreqPosBinned;
        end
        %}
        
        %After the fact reporting
        if doSpectro == 1 && doProbSpectro == 1 && forceSynchronyOfRail == 1
            disp(['-- ', overVar(IIDN).fileDate, ': ' , num2str(forcedCols), ' column window instances forced synchronous --'])
        end
        if doSpectro == 1 && flattenRail == 1
            disp(['-- ', overVar(IIDN).fileDate, ': ' , num2str(flattenedCols), ' column window perio instances flattened --'])
        end
        if doSpectro == 1 && flattenRail == 1 && flattenAllPEs == 1
            disp(['-- ', overVar(IIDN).fileDate, ': ' , num2str(peFlattenedSigs), ' singular perio instances flattened because of PEs --'])
        end
        
        clear probMetric
    %IIDN end    
    end   
    
%timeCalcs end
end

%----------------------

%Sleep
sleepStruct = struct;

%Iterate
for i = 1:size(overVar,2)
    %Load appropriate inStruct
    if splitBouts ~= 1
        inStruct = overVar(i).inStruct;
    else
        inStruct = overVar(i).splitStruct;
    end
    
    %Simple metrics
    sleepStruct.numBouts(i) = size(inStruct.holeStarts,2); %Number of bouts for this fly
    sleepStruct.avBoutLengthSeconds(i) = nanmean(inStruct.holeSizesSeconds); %Mean of bout lengths for this fly
    sleepStruct.boutLengthSeconds{i} = inStruct.holeSizesSeconds; %Individual bout lengths for this fly
    %sleepStruct.stdBoutLengthSeconds(i) = nanstd(overVar(i).inStruct.holeSizesSeconds);
    sleepStruct.boutStartTimesZT{i} = inStruct.holeStartsZT; %Individual bout start times for this fly
    %sleepStruct.boutStartTimesZTPooled(1:size(overVar(1).inStruct.holeStartsZT,2)) = overVar(1).inStruct.holeStartsZT;
    if i ~= 1
        sleepStruct.boutStartTimesZTPooled(size(sleepStruct.boutStartTimesZTPooled,2)+1:size(sleepStruct.boutStartTimesZTPooled,2)+size(inStruct.holeStartsZT,2)) = inStruct.holeStartsZT;
            %Pooled individual bout start times
    else
        sleepStruct.boutStartTimesZTPooled(1:size(inStruct.holeStartsZT,2)) = inStruct.holeStartsZT;
            %Pooled individual bout start times
    end
    
    %{
    %Calculate PE durations (Deprecated with discovery that probScatter contains the same metric)
    if exist('probScatter') == 1
        for bout = 1:size(inStruct.holeRanges,2)
            sleepStruct.boutPEDurs{i}(bout) = nansum(overVar(i).sleepRail(inStruct.holeRanges{bout},3)) / dataFrameRate; %Total duration of PEs in this bout
            %"Divide the sum number of frames where PE was occuring by the frame rate to give PE duration for this bout in seconds"
        end
    end
    %}
    
    %Combine bout metrics
    %Col 1 - Bout start times
    %Col 2 - Bout durations (s)
    %Col 3 - xRight periodicity sig. 
    %Col 4 - xRight periodicity freq. pos.
    %Col 5 - xLeft periodicity sign. 
    %Col 6 - xLeft periodicity freq. pos. 
    %Col 7 - probData periodicity sig. (processList size == 3) OR xRight perioCount (processList size == 2)
    %Col 8 - probData periodicity freq. pos. (processList size == 3) OR xLeft perioCount (processList size == 2)
    %Col 9 - xRight perioCount (processList size == 3) OR Number of PEs (processList size == 2)
    %Col 10 - xLeft perioCount (processList size == 3) OR PE duration (processList size == 2)
    %Col 11 - probData perioCount (processList size == 3)
    %Col 12 - Number of PEs (processList size == 3)
    %Col 13 - PE duration (processList size == 3)
    
    
    sleepStruct.combBout{i} = []; %Combined bout metrics for individual bouts
    sleepStruct.combBout{i}(:,1) = sleepStruct.boutStartTimesZT{i}'; %1 - Backbone of bout start times
    sleepStruct.combBout{i}(:,2) = sleepStruct.boutLengthSeconds{i}'; %2 - 'Y' axis of bout lengths
    if exist('overFouri') == 1
        for side = 1:size(processList,2) %"Left, Right"
            sleepStruct.combBout{i}(:,side*2+1) = [overFouri(i).fouriStruct(:).(strcat('sigSNR_',processList{side}))]' > SNRThresh; %3,5,7 - Whether SNR peak exists that exceeds SNRThresh
            sleepStruct.combBout{i}(:,side*2+2) = [overFouri(i).fouriStruct(:).(strcat('sigPeak_',processList{side}))]'; %4,6,8 - Freq. position of detected peak if it exists
            %sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,side*2+1) == 0,side*2+2) = NaN;
            if doSpectro == 1
                for z = 1:size(overFouri(i).fouriStruct,2) %"Row of combBout" (not necessary in earlier operations because not dealing with more than one double ever)
                    perioCount = 0; %Counts how many sigPeaks fulfilled all the necessary criteria
                    tempSimpleSig = overFouri(i).fouriStruct(z).(strcat('rollSigSNR_',processList{side})); %Simplifies the giant and complicated indexing
                    tempSimplePeak = overFouri(i).fouriStruct(z).(strcat('rollSigPeak_',processList{side})); %Ditto, for peak
                    for om = 1:size(tempSimpleSig,2) %"Roll position within bout" (Note: This is flattened by coordination with perioCount)
                        if tempSimpleSig(om) > SNRThresh && (tempSimplePeak(om) >= min(targetPerioFreqRange) && tempSimplePeak(om) <= max(targetPerioFreqRange))   
                            perioCount = perioCount + 1;
                            %"Add 1 to count if rollSigSNR > SNRThresh and rollSigPeak within target range"
                        end                        
                    end
                    combBoutPerioCountCol = 2 + size(processList,2)*2 + side;
                    sleepStruct.combBout{i}(z,combBoutPerioCountCol) = perioCount; %9,10,11 - perioCount
                        %"Put perio count at <number of hardcoded columns> + <total number of processList sig. and freq. pos columns> + <side>"
                    %sleepStruct.combBout{i}(z,combBoutPerioCountCol) = perioCount;
                end
                %sleepStruct.combBout{i}(:,combBoutPerioCountCol+1) = NaN; %Because I am currently too lazy to adjust indexing to have column 10 be properly next to column 8
            %doSpectro end    
            end
        %side end    
        end
        %sleepStruct.combBout{i}(:,9) = NaN; %Because I am currently too lazy to adjust indexing to have column 10 be properly next to column 8
    %overFouri exist end    
    end
    if exist('probScatter') == 1
        %sleepStruct.combBout{i}(:,size(processList,2)*2+2+1) = [probScatter(i).probEventsNorm]'; %7 - Normalised number of PEs
        %sleepStruct.combBout{i}(:,size(processList,2)*2+2+1) = [probScatter(i).probEventsCount]'; %7 - Number of PEs
        combBoutNumPEsCol = 2 + size(processList,2)*2 + size(processList,2) + 1; %Disambiguates later referencing
        sleepStruct.combBout{i}(:,combBoutNumPEsCol) = [probScatter(i).probEventsCount]'; %(9/)12 - Number of PEs
            %This indexing should allow for flexibility in processList and non-interference of columns
                %Note: If doSpectro is not enabled there will be a large size buffer before these columns
        %sleepStruct.combBout{i}(:,size(processList,2)*2+8) = sleepStruct.boutPEDurs{i}(:);
        combBoutDurPEsCol = 2 + size(processList,2)*2 + size(processList,2) + 2;
        sleepStruct.combBout{i}(:,combBoutDurPEsCol) = [probScatter(i).probEventsDur]'; %(10/)13 - PE durs
        %sleepStruct.combBout{i}(:,size(processList,2)*2+8) = [probScatter(i).probEventsDur]';
    end

    %Append spell information
    if exist('probScatter') == 1 && isfield(probScatter,'spells') == 1
        spellsCol = 2 + size(processList,2)*2 + size(processList,2) + 3; %(11/)14 - Number of spells
        for boutNum = 1:size(probScatter(i).spells,2)
            if isfield(probScatter(i).spells(boutNum),'matchingContigSizes')
                sleepStruct.combBout{i}(boutNum,spellsCol) = size(probScatter(i).spells(boutNum).matchingContigSizes,1); %Number of spells (as derived from number of matching contigs)
                sleepStruct.combBout{i}(boutNum,spellsCol+1) = size(probScatter(i).spells(boutNum).matchingContigSizes,1) / sleepStruct.combBout{i}(boutNum,2); %(12/)15 - Spells/min.
                spellSumDur = 0; %Sum duration of all spells in this bout
                for spellNum = 1:size(probScatter(i).spells(boutNum).matchingContigFullCoordsAbsolute,1)
                    spellSumDur = spellSumDur + ( size(probScatter(i).spells(boutNum).matchingContigFullCoordsAbsolute{spellNum},2) / overVar(IIDN).dataFrameRate );
                end
                sleepStruct.combBout{i}(boutNum,spellsCol+2) = spellSumDur; %(13/)16 - Sum duration (s) of spells within this bout
            else
                sleepStruct.combBout{i}(boutNum,spellsCol) = 0;
                sleepStruct.combBout{i}(boutNum,spellsCol+1) = 0;
                sleepStruct.combBout{i}(boutNum,spellsCol+2) = 0;
            end
        end
    end

    if i ~= 1
        rowIt = size(sleepStruct.combBoutPooled,1)+1; %Carried forward as a row position iterator to simplify the following lines
        combBoutRowIt = size(sleepStruct.combBout{i}(:,1),1); %Ditto, but for the new to be inserted combBout rows
        %sleepStruct.combBoutPooled(size(sleepStruct.combBoutPooled,1)+1:size(sleepStruct.combBoutPooled,1)+size(sleepStruct.combBout{i}(:,1),1),1) = sleepStruct.combBout{i}(:,1);
        sleepStruct.combBoutPooled(rowIt:rowIt+combBoutRowIt-1,1) = sleepStruct.combBout{i}(:,1);
        %sleepStruct.combBoutPooled(size(sleepStruct.combBoutPooled,1)+1-size(sleepStruct.combBout{i}(:,2),1):size(sleepStruct.combBoutPooled,1),2) = sleepStruct.combBout{i}(:,2); %Note difference in assignation due to existing (Replicable for further additions)
        %{
        sleepStruct.combBoutPooled(rowIt:rowIt+combBoutRowIt-1,2) = sleepStruct.combBout{i}(:,2); %Note difference in assignation due to existing (Replicable for further additions)
        if exist('overFouri') == 1
            for side = 1:size(processList,2)
                sleepStruct.combBoutPooled(rowIt:rowIt+combBoutRowIt-1,side*2+1) = sleepStruct.combBout{i}(:,side*2+1);
                sleepStruct.combBoutPooled(rowIt:rowIt+combBoutRowIt-1,side*2+2) = sleepStruct.combBout{i}(:,side*2+2);
            end
        end
        if exist('probScatter') == 1
            sleepStruct.combBoutPooled(rowIt:rowIt+combBoutRowIt-1,size(sleepStruct.combBoutPooled,2)+1) = sleepStruct.combBout{i}(:,7); %7 - PEs
        end
            %Pooled combBout
        %}
        for x = 2:size(sleepStruct.combBout{i},2)
            sleepStruct.combBoutPooled(rowIt:rowIt+combBoutRowIt-1,x) = sleepStruct.combBout{i}(:,x);
        end  
        
    else
        %sleepStruct.combBoutPooled(1:size(overVar(i).inStruct.holeStartsZT,2),1) = sleepStruct.combBout{i}(:,1);
        %sleepStruct.combBoutPooled(1:size(overVar(i).inStruct.holeStartsZT,2),2) = sleepStruct.combBout{i}(:,2);
        for x = 1:size(sleepStruct.combBout{i},2)
            sleepStruct.combBoutPooled(1:size(inStruct.holeStartsZT,2),x) = sleepStruct.combBout{i}(:,x);
        end
            %Pooled combBout
    end
end
sleepStruct.combBoutPooledSorted = sortrows(sleepStruct.combBoutPooled); %Ascending sorted version of combBoutPooled
if sliceBouts == 1
    sleepStruct.combBoutPooledSortedSliced = sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledSorted(:,1) >= nightTimeStart & sleepStruct.combBoutPooledSorted(:,1) <= nightTimeEnd,1:2);
        %Note that this is only used if portion splitting requested
        %(If splitting by ZT, slicing is achieved by the limits of the timeSplit range)
end

%Define bin ranges
sleepStruct.combBoutPooledRangeYs = [];
%Old
%{
if splitMode ~= 1
    for zt = 1:size(timeSplit,2)-1
        ztArray = find(sleepStruct.combBoutPooledSorted(:,1) >= timeSplit(zt) & sleepStruct.combBoutPooledSorted(:,1) < timeSplit(zt+1));
        sleepStruct.combBoutPooledRangeYs(1:2,zt) = [min(ztArray),max(ztArray)]';
    end
else
    for i = timeSplit
        if sliceBouts ~= 1
            sleepStruct.combBoutPooledRangeYs(1:2,i) = [floor(size(sleepStruct.combBoutPooledSorted,1) / timeSplit(end) * (i-1)) + 1, floor(size(sleepStruct.combBoutPooledSorted,1) / timeSplit(end) * i)];
        else
            sleepStruct.combBoutPooledRangeYs(1:2,i) = [floor(size(sleepStruct.combBoutPooledSortedSliced,1) / timeSplit(end) * (i-1)) + 1, floor(size(sleepStruct.combBoutPooledSortedSliced,1) / timeSplit(end) * i)];
        end
    end
end
%}
%New
for i = 1:size(timeSplit,2)-1
    if sliceBouts ~= 1
        ztArray = find(sleepStruct.combBoutPooledSorted(:,1) >= timeSplit(i) & sleepStruct.combBoutPooledSorted(:,1) < timeSplit(i+1));
        %sleepStruct.combBoutPooledRangeYs(1:2,i) = [min(ztArray),max(ztArray)]';
    else
        ztArray = find(sleepStruct.combBoutPooledSortedSliced(:,1) >= timeSplit(i) & sleepStruct.combBoutPooledSortedSliced(:,1) < timeSplit(i+1));
        %sleepStruct.combBoutPooledRangeYs(1:2,i) = [min(ztArray),max(ztArray)]';        
    end
    
    if isempty(ztArray) ~= 1
        sleepStruct.combBoutPooledRangeYs(1:2,i) = [min(ztArray),max(ztArray)]';
    else
        sleepStruct.combBoutPooledRangeYs(1:2,i) = [NaN,NaN]';
    end
end

%Use bin ranges to group data
sleepStruct.lenNanYs = [];
sleepStruct.lenStdYs = [];
sleepStruct.lenSemYs = [];

sleepStruct.numBoutsBinnedPooled = [];
sleepStruct.numMeanYs = [];
sleepStruct.numStdYs = [];
sleepStruct.numSemYs = [];

for i = 1:size(timeSplit,2)-1
    %Find bouts within timeSplit time and note statistics about them (NaN susceptible)
    if isnan(sleepStruct.combBoutPooledRangeYs(1,i)) ~= 1
        if sliceBouts ~= 1
            sleepStruct.lenNanYs = [sleepStruct.lenNanYs, nanmean(sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2))];
            sleepStruct.lenStdYs = [sleepStruct.lenStdYs, nanstd(sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2))];
            sleepStruct.lenSemYs = [sleepStruct.lenSemYs, nanstd(sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2)) / sqrt(size(sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2),1))];
            %{
            for IIDN = 1:size(sleepStruct.combBout,2)
                sleepStruct.numBoutsBinnedPooled(IIDN,i) = size(sleepStruct.combBout{IIDN}(sleepStruct.combBout{IIDN}(:,1) >= timeSplit(i) & sleepStruct.combBout{IIDN}(:,1) < timeSplit(i+1)),1);
                    %Time-linked operation
            end
            %}
        else
            sleepStruct.lenNanYs = [sleepStruct.lenNanYs, nanmean(sleepStruct.combBoutPooledSortedSliced(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2))];
            sleepStruct.lenStdYs = [sleepStruct.lenStdYs, nanstd(sleepStruct.combBoutPooledSortedSliced(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2))];
            sleepStruct.lenSemYs = [sleepStruct.lenSemYs, nanstd(sleepStruct.combBoutPooledSortedSliced(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2)) / sqrt(size(sleepStruct.combBoutPooledSortedSliced(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2),1))];
            %end
            %{
            for IIDN = 1:size(sleepStruct.combBout,2)
                sleepStruct.numBoutsBinnedPooled(IIDN,i) = size(sleepStruct.combBout{IIDN}(sleepStruct.combBout{IIDN}(:,1) >= timeSplit(i) & sleepStruct.combBout{IIDN}(:,1) < timeSplit(i+1)),1);
                    %Portion-linked operation
            end
            %}
        end
    else
        sleepStruct.lenNanYs = [sleepStruct.lenNanYs, NaN];
        sleepStruct.lenStdYs = [sleepStruct.lenStdYs, NaN];
        sleepStruct.lenSemYs = [sleepStruct.lenSemYs, NaN];
    end
    
    for IIDN = 1:size(sleepStruct.combBout,2)
        if sliceBouts ~= 1
            sleepStruct.numBoutsBinnedPooled(IIDN,i) = size(sleepStruct.combBout{IIDN}(sleepStruct.combBout{IIDN}(:,1) >= timeSplit(i) & sleepStruct.combBout{IIDN}(:,1) < timeSplit(i+1)),1);
        else
            sleepStruct.numBoutsBinnedPooled(IIDN,i) = size(sleepStruct.combBout{IIDN}(sleepStruct.combBout{IIDN}(:,1) >= timeSplit(i) & sleepStruct.combBout{IIDN}(:,1) < timeSplit(i+1) ...
                & sleepStruct.combBout{IIDN}(:,1) >= nightTimeStart & sleepStruct.combBout{IIDN}(:,1) < nightTimeEnd ),1);
                    %Note that currently these last two ifs are doubleups on account of nightTimeStart/End being used to define timeSplit in the first place
        end
    end  
    sleepStruct.numMeanYs = [sleepStruct.numMeanYs, nanmean(sleepStruct.numBoutsBinnedPooled(:,i))];
    sleepStruct.numStdYs = [sleepStruct.numStdYs, nanstd(sleepStruct.numBoutsBinnedPooled(:,i))];
    sleepStruct.numSemYs = [sleepStruct.numSemYs, nanstd(sleepStruct.numBoutsBinnedPooled(:,i)) / sqrt(size(sleepStruct.numBoutsBinnedPooled(:,i),1))];
end

%----------------------

%Separate data by bout duration
if doDurs == 1 && splitBouts == 1
    ['# Warning: splitBouts and doDurs requested to be simultaneously active #']
    error = yes
end

if splitBouts ~= 1 && doDurs == 1 %Forced bout durations will affect calculations
    sleepStruct.durSubStruct = struct; %This will store information relating to duration x <metric>
    
    for bin = 1:size(durBins,2)-1
        
        binName = strcat(['bin_', num2str(durBins(bin)),'to',num2str(durBins(bin+1))]);
        %sleepStruct.durSubStruct.(binName) = [];
        sleepStruct.durSubStruct.(binName).boutDurs = sleepStruct.combBoutPooled(sleepStruct.combBoutPooled(:,2) >= durBins(bin) & ...
            sleepStruct.combBoutPooled(:,2) < durBins(bin+1), 2);
            %Select from combBoutPooled column 2 (Duration) where column 2 (Duration) >= bin lower bound and < bin upper bound
        sleepStruct.durSubStruct.(binName).boutTimes = sleepStruct.combBoutPooled(sleepStruct.combBoutPooled(:,2) >= durBins(bin) & ...
            sleepStruct.combBoutPooled(:,2) < durBins(bin+1), 1);
            %Select from combBoutPooled column 1 (Time) where column 2 (Duration) >= bin lower bound and < bin upper bound
        for side = 1:size(processList,2)
            tempCol = sleepStruct.combBoutPooled(sleepStruct.combBoutPooled(:,2) >= durBins(bin) & ...
                sleepStruct.combBoutPooled(:,2) < durBins(bin+1), side*2+1);
                %Select from combBoutPooled column side*2+2 (processTarget periodicity significance) where column 2 (Duration) >= bin lower bound and < bin upper bound    
            sleepStruct.durSubStruct.(binName).(strcat('antPerioFreqPos_',processList{side})) = sleepStruct.combBoutPooled(sleepStruct.combBoutPooled(:,2) >= durBins(bin) & ...
                sleepStruct.combBoutPooled(:,2) < durBins(bin+1), side*2+2);
                %Select from combBoutPooled column side*2+2 (processTarget periodicity frequency position) where column 2 (Duration) >= bin lower bound and < bin upper bound 
            sleepStruct.durSubStruct.(binName).(strcat('antPerioFreqPos_',processList{side}))(tempCol == 0) = NaN;
                %NaN out elements that failed to meet significance
        end
        
    %bin end    
    end
%doDurs end    
end

%----------------------

if splitBouts == 1
    %FLID
    flidStruct = struct;
    flidStruct.pooled = []; 
    
    a = 1;
    for IIDN = 1:size(overVar,2)
        b = 1;
        %splitStruct = overVar(IIDN).splitStruct;
        splitStruct = overVar(IIDN).inStructCarry;
        %Quick QA
        if size(overVar(IIDN).inStructCarry.holeStartsTimes,2) ~= size(overVar(IIDN).splitStruct.holeStartsTimes,2)
            ['## Alert: Critical desynchronisation between splitStruct and inStructCarry ##']
            error = yes
        end
        
        %Initialise
        for i = 1:size(splitDurs,2)
            flidStruct.pooled.peBoutNumTotal(IIDN,i) = 0;
            flidStruct.pooled.peBoutNumNormTotal(IIDN,i) = 0;
            flidStruct.pooled.peBoutDurTotal(IIDN,i) = 0;
            flidStruct.pooled.peBoutDurNormTotal(IIDN,i) = 0;
            for side = 1:size(processList,2)
                flidStruct.pooled.(strcat('antBoutNum_',processList{side}))(IIDN,i) = 0; %Raw count of number of significant bouts for each side
                flidStruct.pooled.(strcat('antBoutNumNorm_',processList{side}))(IIDN,i) = 0; %Ditto but normalised by bout length
                if doSpectro == 1
                    flidStruct.pooled.(strcat('antBoutPerioDur_',processList{side}))(IIDN,i) = 0; %Cumulative sum of spectro-derived duration of antennal periodicity at target duration
                    flidStruct.pooled.(strcat('antBoutPerioDurNorm_',processList{side}))(IIDN,i) = 0; %Ditto, but normalised to the size of the entire bout
                        %Note: With bout segments that are not exact multiples of the bin size it may not be possible to even achieve a value of 1 for example
                            %i.e. If bout segments are 60s and the bin size is 40s, it will only ever be possible to achieve a value of 0.6666
                            %This is accounted for down lower by proportionalising by the maximum 'possible' value, rather than the idealistic bout segment length
                end
            end
            %---
            flidStruct.pooled.antBoutNum_any(IIDN,i) = 0; %As above, but combining for any perio
            flidStruct.pooled.antBoutNumNorm_any(IIDN,i) = 0; %As above, but combining for any perio
            flidStruct.pooled.antBoutPerioDur_any(IIDN,i) = 0;
            flidStruct.pooled.antBoutPerioDurNorm_any(IIDN,i) = 0;
            %---
            flidStruct.pooled.boutDurTotal(IIDN,i) = 0;
            flidStruct.pooled.spellBoutNumTotal(IIDN,i) = 0;
            flidStruct.pooled.spellBoutNumNormTotal(IIDN,i) = 0;
            flidStruct.pooled.spellBoutDurTotal(IIDN,i) = 0;
            flidStruct.pooled.spellBoutDurNormTotal(IIDN,i) = 0;
        end
        for i = 1:size(splitStruct.FLID,2)
            splitSeg = splitStruct.FLID(2,i); %Segment number
            splitBoutID = splitStruct.FLID(3,i); %New bout number
            
            flidStruct.pooled.boFlIDs{a,splitStruct.FLID(2,i)} = strcat([num2str(IIDN),'-',num2str(splitStruct.FLID(1,i)),'-',num2str(splitStruct.FLID(2,i)),'-',num2str(splitStruct.FLID(3,i))]); 
                %"<fly>-<bout>-<split segment>-<new bout number>" (i.e. "3-2-3-6" -> "fly 3 - bout 2 - split segment 3 - new bout identity 6")
            
            flidStruct.pooled.holeSizes(a,splitSeg) = splitStruct.holeSizes(splitBoutID);
            flidStruct.pooled.holeRanges{a,splitSeg} = splitStruct.holeRanges{splitBoutID};
            flidStruct.pooled.holeStartsTimes{a,splitSeg} = splitStruct.holeStartsTimes{splitBoutID};
            flidStruct.pooled.holeStartsZT(a,splitSeg) = splitStruct.holeStartsZT(splitBoutID);       
            
            flidStruct.pooled.combBout{splitSeg}(a,:) = sleepStruct.combBout{IIDN}(splitBoutID,:); %Contains all combBout metrics (i.e. ZT start, duration, SNR peaks, PEs) 
            
            flidStruct.individual.peBoutNum{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,combBoutNumPEsCol); %Raw count of PEs (Col 12)
            flidStruct.individual.peBoutNumNorm{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,combBoutNumPEsCol) * ...
                 (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)); %PEs/min (not averaged or totalled) (Col 13)
            flidStruct.individual.peBoutDur{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,combBoutDurPEsCol);
            flidStruct.individual.peBoutDurNorm{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,combBoutDurPEsCol) * ...
                (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2));
            
            flidStruct.pooled.peBoutNumTotal(IIDN,splitSeg) = flidStruct.pooled.peBoutNumTotal(IIDN,splitSeg) + ...
                (flidStruct.pooled.combBout{splitSeg}(a,combBoutNumPEsCol) ~= 0); %Add a 1 if at least one PE occurred in this bout
            flidStruct.pooled.peBoutNumNormTotal(IIDN,splitSeg) = flidStruct.pooled.peBoutNumNormTotal(IIDN,splitSeg) + ...
                 ( (flidStruct.pooled.combBout{splitSeg}(a,7) ~= 0) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)) ); %Add a value that depends on the length of the bout
            flidStruct.pooled.peBoutDurTotal(IIDN,splitSeg) = flidStruct.pooled.peBoutDurTotal(IIDN,splitSeg) + flidStruct.pooled.combBout{splitSeg}(a,combBoutDurPEsCol);
            flidStruct.pooled.peBoutDurNormTotal(IIDN,splitSeg) = flidStruct.pooled.peBoutDurNormTotal(IIDN,splitSeg) + ...
                ( flidStruct.pooled.combBout{splitSeg}(a,combBoutDurPEsCol) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)) );
                %Takes the duration value from combBout and divides it per minutes
                    %Note: If combBout columns ever shift this reference will be invalidated
                        %Also note: This is a processing doubleup with a data column from probScatter, but that structure did not have FLID information
            for side = 1:size(processList,2)
                flidStruct.pooled.(strcat('antBoutNum_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutNum_',processList{side}))(IIDN,splitSeg) + flidStruct.pooled.combBout{splitSeg}(a,side*2+1);
                    %Use combBout columns 3 and 5 to count the number of bouts with significant right or left antennal periodicity
                flidStruct.pooled.(strcat('antBoutNumNorm_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutNumNorm_',processList{side}))(IIDN,splitSeg) + ...
                    (flidStruct.pooled.combBout{splitSeg}(a,side*2+1) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)));
                %Any perio
                %flidStruct.pooled.antBoutNum_any(IIDN,splitSeg) = flidStruct.pooled.antBoutNum_any(IIDN,splitSeg) + flidStruct.pooled.combBout{splitSeg}(a,side*2+1); %Add all information, regardless of side; Old
                %flidStruct.pooled.antBoutNumNorm_any(IIDN,splitSeg) = flidStruct.pooled.antBoutNumNorm_any(IIDN,splitSeg) + ...
                %    ( flidStruct.pooled.combBout{splitSeg}(a,side*2+1) * ((60.0 / flidStruct.pooled.combBout{splitSeg}(a,2))/size(processList,2)) ); %Divide time factor by number of times it will be applied
                %    ( flidStruct.pooled.combBout{splitSeg}(a,side*2+1) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)) ); %Not properly accounting for multiple side data
                %Bootleg periodicity duration calculations
                if doSpectro == 1
                    flidStruct.pooled.(strcat('antBoutPerioDur_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutPerioDur_',processList{side}))(IIDN,splitSeg) + ...
                        (flidStruct.pooled.combBout{splitSeg}(a,2 + size(processList,2)*2 + side) * (overFouri(IIDN).winSizeActive / overVar(IIDN).dataFrameRate));
                        %"Take the current value of antBoutPerioDur_<side> and add the number of time bins containing periodicity * size of bins in seconds"
                    flidStruct.pooled.(strcat('antBoutPerioDurNorm_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutPerioDurNorm_',processList{side}))(IIDN,splitSeg) + ...
                        ( (flidStruct.pooled.combBout{splitSeg}(a,2 + size(processList,2)*2 + side) * (overFouri(IIDN).winSizeActive / overVar(IIDN).dataFrameRate)) / ...
                        (floor(flidStruct.pooled.combBout{splitSeg}(a,2) / (overFouri(IIDN).winSizeActive / overVar(IIDN).dataFrameRate)) * (overFouri(IIDN).winSizeActive / overVar(IIDN).dataFrameRate)) ); %(Might crash if bin size exceeds bout segment size)
                        %"Ditto, but divide the derived periodicity duration by the maximum possible duration of periodicity for this bout"\
                            %I.e. If the bout is 60 seconds long and bins are 28 seconds long, the maximum possible duration is only 56 seconds
                            %Note: This value is added up per each bout segment, so it will require post-hoc nanMean-ing or similar
                            %Secondary note: This value is effectively meaningless until it is proportionalised by the number of bout segments that made it up
                        %( (flidStruct.pooled.combBout{splitSeg}(a,combBoutPerioCountCol) * (winSize / dataFrameRate)) / flidStruct.pooled.combBout{splitSeg}(a,2));
                        %"Ditto, but divide the derived periodicity duration by the size of the bout"
                    %flidStruct.pooled.antBoutPerioDur_any(IIDN,splitSeg) = flidStruct.pooled.antBoutPerioDur_any(IIDN,splitSeg) + ...
                    %    (flidStruct.pooled.combBout{splitSeg}(a,2 + size(processList,2)*2 + side) * ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) );
                    %flidStruct.pooled.antBoutPerioDurNorm_any(IIDN,splitSeg) = flidStruct.pooled.antBoutPerioDurNorm_any(IIDN,splitSeg) + ...
                    %    ( (flidStruct.pooled.combBout{splitSeg}(a,2 + size(processList,2)*2 + side) * ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) ) / ...
                    %    (floor(flidStruct.pooled.combBout{splitSeg}(a,2) / ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) ) * ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) ) );
                    %    %"...and the award for the most number of nested parentheses goes to..."
                end
            end
            %---
            %Any (New)
                %Disabled (currently) on account of unsureness of validity of calculations
                %In principle supposed to be measure of "How many bouts, if any", but in practice may be "Nansum bouts"
            %{
            flidStruct.pooled.antBoutNum_any(IIDN,splitSeg) = flidStruct.pooled.antBoutNum_any(IIDN,splitSeg) + nansum( flidStruct.pooled.combBout{splitSeg}(a,[1:size(processList,2)]*2+1) ); %Add all information, regardless of side; New
            flidStruct.pooled.antBoutNumNorm_any(IIDN,splitSeg) = flidStruct.pooled.antBoutNumNorm_any(IIDN,splitSeg) + ...
                    ( nansum(flidStruct.pooled.combBout{splitSeg}(a,[1:size(processList,2)]*2+1)) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)) ); %Searches for any perio and divides by time of bin (No size(processList,2) fuckery)
            if doSpectro == 1
                flidStruct.pooled.antBoutPerioDur_any(IIDN,splitSeg) = flidStruct.pooled.antBoutPerioDur_any(IIDN,splitSeg) + ...
                        ( nansum(flidStruct.pooled.combBout{splitSeg}(a,2 + size(processList,2)*2 + [1:size(processList,2)])) * (winSize / overVar(IIDN).dataFrameRate) );
                flidStruct.pooled.antBoutPerioDurNorm_any(IIDN,splitSeg) = flidStruct.pooled.antBoutPerioDurNorm_any(IIDN,splitSeg) + ...
                        ( (flidStruct.pooled.combBout{splitSeg}(a,2 + size(processList,2)*2 + side) * ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) ) / ...
                        (floor(flidStruct.pooled.combBout{splitSeg}(a,2) / ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) ) * ((winSize / overVar(IIDN).dataFrameRate)/size(processList,2)) ) );    
            end
            %}
            %---
            
            
            %Spells
            flidStruct.individual.spellBoutNum{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,spellsCol); %Raw count of spells (Col 14)
            flidStruct.individual.spellBoutNumNorm{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,spellsCol+1) * ...
                 (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)); %Spells/min (not averaged or totalled) (Col 15)
            flidStruct.individual.spellBoutDur{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,spellsCol+2); %Spell durations (Col 16)
            flidStruct.individual.spellBoutDurNorm{IIDN}(b,splitSeg) = flidStruct.pooled.combBout{splitSeg}(a,spellsCol+2) * ...
                (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)); %Spell durations normalised by bout length

            flidStruct.pooled.boutDurTotal(IIDN,splitSeg) = flidStruct.pooled.spellBoutDurTotal(IIDN,splitSeg) + flidStruct.pooled.combBout{splitSeg}(a,2); %Total bout lengths
            flidStruct.pooled.spellBoutNumTotal(IIDN,splitSeg) = flidStruct.pooled.spellBoutNumTotal(IIDN,splitSeg) + ...
                (flidStruct.pooled.combBout{splitSeg}(a,spellsCol) ~= 0); %Add a 1 if at least one spell occurred in this bout (Column index based on combBout reference)
            flidStruct.pooled.spellBoutNumNormTotal(IIDN,splitSeg) = flidStruct.pooled.spellBoutNumNormTotal(IIDN,splitSeg) + ...
                 ( (flidStruct.pooled.combBout{splitSeg}(a,spellsCol+2) ~= 0) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)) ); %Add a value that depends on the length of the bout
            flidStruct.pooled.spellBoutDurTotal(IIDN,splitSeg) = flidStruct.pooled.spellBoutDurTotal(IIDN,splitSeg) + flidStruct.pooled.combBout{splitSeg}(a,spellsCol+2);
            flidStruct.pooled.spellBoutDurNormTotal(IIDN,splitSeg) = flidStruct.pooled.spellBoutDurNormTotal(IIDN,splitSeg) + ...
                ( flidStruct.pooled.combBout{splitSeg}(a,spellsCol+2) * (60.0 / flidStruct.pooled.combBout{splitSeg}(a,2)) );
            
            %QA
            if flidStruct.pooled.combBout{splitSeg}(a,1) ~= flidStruct.pooled.holeStartsZT(a,splitSeg)
                ['## Warning: Critical desynchronisation between splitStruct and sleepStruct ##']
                error = yes
            end 
            if splitStruct.FLID(2,i) == size(splitDurs,2) %Reached end of this row
                a = a + 1; %Note: This value roughly equivocates to IIDN
                b = b + 1;
            end
        end

        %This portion of the code divides raw counts and durations into proportions
        for splitSeg = 1:size(splitDurs,2)
            flidStruct.pooled.peBoutNumMean(IIDN,splitSeg) = flidStruct.pooled.peBoutNumTotal(IIDN,splitSeg)/ (sleepStruct.numBouts(IIDN) / size(splitDurs,2)); 
                %Post-hoc calculate number of bouts for each file from numBouts / how many times bouts were split
            flidStruct.pooled.peBoutNumNormMean(IIDN,splitSeg) = flidStruct.pooled.peBoutNumNormTotal(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
                %Ditto, except with length-normalised values rather than raw Yes/No
            for side = 1:size(processList,2)
                flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutNum_',processList{side}))(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
                    %"Number of sig. bouts / (Number of segmented bouts total / Number of segments that original bout number was multiplied by)"
                flidStruct.pooled.(strcat('antBoutPropNorm_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutNumNorm_',processList{side}))(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
                    %Ditto, except uses bout proportions normalised by bout lengths in seconds
                if doSpectro == 1
                    flidStruct.pooled.(strcat('antBoutPerioDurPropNorm_',processList{side}))(IIDN,splitSeg) = flidStruct.pooled.(strcat('antBoutPerioDurNorm_',processList{side}))(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
                    %This number represents the average proportion of bout segments that was periodic antennal activity of the target range
                        %Aforementioned binning/multiples issues may exist however
                end
            end
            %{
            flidStruct.pooled.antBoutProp_any(IIDN,splitSeg) = flidStruct.pooled.antBoutNum_any(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2)); %High likelihood of ceiling effect here
            flidStruct.pooled.antBoutPropNorm_any(IIDN,splitSeg) = flidStruct.pooled.antBoutNumNorm_any(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
            if doSpectro == 1
                flidStruct.pooled.antBoutPerioDurPropNorm_any(IIDN,splitSeg) = flidStruct.pooled.antBoutPerioDurNorm_any(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
            end
            %}
            %Spells
            flidStruct.pooled.spellBoutNumMean(IIDN,splitSeg) = flidStruct.pooled.spellBoutNumTotal(IIDN,splitSeg)/ (sleepStruct.numBouts(IIDN) / size(splitDurs,2)); 
            flidStruct.pooled.spellBoutNumNormMean(IIDN,splitSeg) = flidStruct.pooled.spellBoutNumNormTotal(IIDN,splitSeg) / (sleepStruct.numBouts(IIDN) / size(splitDurs,2));
        %splitSeg end    
        end
        
    %IIDN end    
    end
    
    %QA
    if size(flidStruct.pooled.combBout{1},1) ~= size(flidStruct.pooled.combBout{size(splitDurs,2)},1)
        ['## Warning: Asymmetry present in FLID combBout data ##']
        error = yes
    end
%splitBouts end
end

%----------------------

%Pool sleepRail metrics ("More like...Matt-rics")
%{
pooledZTCurveSums = []; %Sum of hourly sleep per hour (in frames)
pooledZTCurveSumsMins = []; %Sum, in minutes
pooledZTPEsSums = []; %Sum of how many frames were a PE per hour
pooledZTPEsSumsMins = []; %Sum of how much time was PE (in mins)
pooledZTPEsSumsMinsSleepRatio = []; %Ratio of PEs to sleep within bouts
%}
%{
if exist('overFouri') == 1
    pooledZTAntPerioSums = []; %Sum of hourly sleep per hour (in frames)
    pooledZTAntPerioSumsMins = []; %Sum, in minutes
end
%}
for IIDN = 1:size(overVar,2)
    for i = 1:size(sleepCurveZT,2)-1
        %Sleep
        %sleepStruct.pooledZTCurveSums(IIDN,i) = overVar(IIDN).railStruct.sleepRailZTCurveBinnedSum(i);
        %pooledZTCurveSums(IIDN,i) = overVar(IIDN).railStruct.sleepRailZTCurveBinnedSum(i);
        %sleepStruct.pooledZTCurveSumsMins(IIDN,i) = sleepStruct.pooledZTCurveSums(IIDN,i) / (dataFrameRate * 60); %Old system, reliance on correct/stable framerate
        
        sleepStruct.pooledZTCurveSumsMins(IIDN,i) = overVar(IIDN).railStruct.sleepRailZTCurveBinnedSumTime{i} / 60.0; %New system using inter-frame time difference early calculations
        
        %pooledZTCurveSumsMins(IIDN,i) = pooledZTCurveSums(IIDN,i) / (dataFrameRate * 60);
        %Quick QA as fallback check for weird numbers
        if sleepStruct.pooledZTCurveSumsMins(IIDN,i) > 60.01 %Softened v. slightly for cases when entire hour was sleep epoch
            ['## Alert: Impossible amount of sleep detected ##']
            error = yes
        end
        
        %PEs
        %sleepStruct.pooledZTPEsSums(IIDN,i) = overVar(IIDN).railStruct.sleepRailZTPEsBinnedSum(i);
        %pooledZTPEsSums(IIDN,i) = overVar(IIDN).railStruct.sleepRailZTPEsBinnedSum(i);
        %sleepStruct.pooledZTPEsSumsMins(IIDN,i) = sleepStruct.pooledZTPEsSums(IIDN,i) / (dataFrameRate * 60);  %Old system, reliance on correct/stable framerate
        
        sleepStruct.pooledZTPEsSumsMins(IIDN,i) = overVar(IIDN).railStruct.sleepRailZTPEsBinnedSumTime{i} / 60.0; %New system
        
        %pooledZTPEsSumsMins(IIDN,i) = pooledZTPEsSums(IIDN,i) / (dataFrameRate * 60);
        sleepStruct.pooledZTPEsSumsMinsSleepRatio(IIDN,i) = sleepStruct.pooledZTPEsSumsMins(IIDN,i) / sleepStruct.pooledZTCurveSumsMins(IIDN,i); %Proportion of sleep mins in this bin that also has PEs
        %pooledZTPEsSumsMinsSleepRatio(IIDN,i) = pooledZTPEsSumsMins(IIDN,i) / pooledZTCurveSumsMins(IIDN,i); %Proportion of sleep mins in this bin that also has ant. perio.
            %Note: No noSleepBehaviour action here; Offloaded to plotting
            
        %Antennal periodicity
        if exist('overFouri') == 1
            for side = 1:size(processList,2)
                %sleepStruct.(strcat('pooledZTAntPerioSums_',processList{side}))(IIDN,i) = ...
                %    overVar(IIDN).railStruct.(strcat('sleepRailZTAntPerioBinnedSum_',processList{side}))(i); %Frames of ant. perio.
                
                %pooledZTAntPerioSums(IIDN,i) = overVar(IIDN).sleepRailZTAntPerioBinnedSum(i); %Frames of ant. perio.
                
                %Old
                %sleepStruct.(strcat('pooledZTAntPerioSumsMins_',processList{side}))(IIDN,i) = ...
                %    sleepStruct.(strcat('pooledZTAntPerioSums_',processList{side}))(IIDN,i) / (dataFrameRate * 60); %Mins of ant. perio. in this bin (Old, assumption-based system)
                %New
                sleepStruct.(strcat('pooledZTAntPerioSumsMins_',processList{side}))(IIDN,i) = ...
                    overVar(IIDN).railStruct.(strcat('sleepRailZTAntPerioBinnedTime_',processList{side}))(i) / 60.0; %Mins of ant. perio. in this bin (New, inter-frame time based system)
                
                %pooledZTAntPerioSumsMins(IIDN,i) = pooledZTAntPerioSums(IIDN,i) / (dataFrameRate * 60); %Mins of ant. perio. in this bin
                
                sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}))(IIDN,i) = ...
                    sleepStruct.(strcat('pooledZTAntPerioSumsMins_',processList{side}))(IIDN,i) / sleepStruct.pooledZTCurveSumsMins(IIDN,i); %Proportion of sleep mins in this bin that also has ant. perio.
                        %Note: pooledZTCurveSumsMins has been updated to use inter-frame times
                
                %pooledZTAntPerioSumsMinsSleepRatio(IIDN,i) = pooledZTAntPerioSumsMins(IIDN,i) / pooledZTCurveSumsMins(IIDN,i); %Proportion of sleep mins in this bin that also has ant. perio.
                if isnan(sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}))(IIDN,i)) == 1 %"More like...Ismail"
                %if isnan(pooledZTAntPerioSumsMinsSleepRatio(IIDN,i)) == 1 %"More like...Ismail"
                    if ( noSleepBehaviour == 0 || isnan(sleepStruct.pooledZTCurveSumsMins(IIDN,i)) == 1 ) && noSleepBehaviour ~= -1 %"If ( using zeroes as stand-in OR bin precedes data ) AND not forcing NaN acceptance
                    %if ( noSleepBehaviour == 0 || isnan(sleepStruct.pooledZTCurveSums(IIDN,i)) == 1 ) && noSleepBehaviour ~= -1 %"If ( using zeroes as stand-in OR bin precedes data ) AND not forcing NaN acceptance (Old)
                    %if ( noSleepBehaviour == 0 || isnan(pooledZTCurveSums(IIDN,i)) == 1 ) && noSleepBehaviour ~= -1 %"If ( using zeroes as stand-in OR bin precedes data ) AND not forcing NaN acceptance
                        sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}))(IIDN,i) =...
                            0; %Force instances of no sleep to yield a ratio of zero
                        %pooledZTAntPerioSumsMinsSleepRatio(IIDN,i) = 0; %Force instances of no sleep to yield a ratio of zero
                            %(This is debatably superior to using a mean or some other value)
                    elseif noSleepBehaviour == 1
                        
                        %Old
                        %sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}))(IIDN,i) = ...
                        %    nanmean(overVar(IIDN).railStruct.(strcat('sleepRailZTAntPerioBinnedSum_',processList{side})) / (dataFrameRate * 60)) / ...
                        %    nanmean(overVar(IIDN).railStruct.(strcat('sleepRailZTCurveBinnedSum_',processList{side})) / (dataFrameRate * 60));
                        %New
                        sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}))(IIDN,i) = ...
                            nanmean(overVar(IIDN).railStruct.(strcat('sleepRailZTAntPerioBinnedTime_',processList{side})) / 60.0) / ...
                            nanmean([overVar(IIDN).railStruct.sleepRailZTCurveBinnedSumTime{:}] / 60.0); 
                        
                        %pooledZTAntPerioSumsMinsSleepRatio(IIDN,i) = nanmean(overVar(IIDN).sleepRailZTAntPerioBinnedSum / (dataFrameRate * 60)) / ...
                        %    nanmean(overVar(IIDN).sleepRailZTCurveBinnedSum / (dataFrameRate * 60));
                                %"Divide average ant. perio. mins by average sleep mins to give a stand-in value"
                    elseif noSleepBehaviour == -1
                        sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}))(IIDN,i) = NaN;
                        %pooledZTAntPerioSumsMinsSleepRatio(IIDN,i) = NaN;
                    else
                        ['## Impossible boolean case in ant. perio. pooling detected ##']
                        error = yes
                    end
                end  
                sleepStruct.(strcat('pooledZTAntPerioFreqPos_',processList{side})){IIDN,i} = ...
                    overVar(IIDN).railStruct.(strcat('sleepRailZTAntPerioFreqPosBinned_',processList{side})){i}; %Note: This variable will be much bigger than its partner sleepStruct fields
                %pooledZTAntPerioFreqPos{IIDN,i} = overVar(IIDN).sleepRailZTAntPerioFreqPosBinned{i}; %Note: This variable will be much bigger than its partner sleepStruct fields
            end
        %overFouri end
        end
    end
end

%Additional FFTs
if doFFT == 1
    stateMax = 0;
    for IIDN = 1:size(overFouri,2)
        for side = 1:size(processList,2)
            if contains( processList{side}, 'xRight' ) == 1 || contains( processList{side}, 'xLeft' ) == 1
                thisData = overVar(IIDN).( strcat(processList{side},'All') );
            elseif contains( processList{side}, 'probData' ) == 1
                thisData = overVar(IIDN).probMetric;
            end
            
            %fftData = sourceData(binInd-winSizeActive+1:binInd);

            if length(thisData) / 2.0 ~= floor(length(thisData) / 2.0) %Ensure even size
                endInd = length(thisData) - 1;
            else
                endInd = length(thisData);
            end


            %All FFT
            y = fft(thisData(1:endInd));
            %L = length(xRight);
            L = length(y);
            P2 = abs(y/L);
            P1 = P2(1:L/2+1);
            P1(2:end-1) = 2*P1(2:end-1);
            P1Log = log(P1);
            f = overVar(IIDN).dataFrameRate*(0:(L/2))/L; % find the frequency vector

            overFouri(IIDN).allFFT.(processList{side}).f = f;
            overFouri(IIDN).allFFT.(processList{side}).P1 = P1;
            overFouri(IIDN).allFFT.(processList{side}).P1Log = P1Log;
            
            %Sleep and wake FFT
            states = unique( overVar(IIDN).railStruct.sleepRail(:,1) );
            if size(states,1) > stateMax
                stateMax = size(states,1);
            end
            for statInd = 1:size(states,1)
                thisState = states(statInd);
                
                thisStateData = thisData( overVar(IIDN).railStruct.sleepRail(:,1) == thisState );
                
                if length(thisStateData) / 2.0 ~= floor(length(thisStateData) / 2.0) %Ensure even size
                    endInd = length(thisStateData) - 1;
                else
                    endInd = length(thisStateData);
                end
                
                y = fft(thisStateData(1:endInd));
                %L = length(xRight);
                L = length(y);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = overVar(IIDN).dataFrameRate*(0:(L/2))/L; % find the frequency vector
                P1Log = log(P1);

                overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).f = f;
                overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).P1 = P1;
                overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).P1Log = P1Log;
            
            end
            
            %And plot
            %{
            figure
            subplot( 1+size(states,1), 1, 1 )
            plot( overFouri(IIDN).allFFT.(processList{side}).f , overFouri(IIDN).allFFT.(processList{side}).P1 , 'Color', 'k' )
            %plot( overFouri(IIDN).allFFT.(processList{side}).f , overFouri(IIDN).allFFT.(processList{side}).P1Log , 'Color', 'k' )
            xlim([nanmin(F),nanmax(F)])
            ylim('auto')
            title([processList{side},' all data FFT'])
            %title([processList{side},' all data FFT (Log)'])
            
            for statInd = 1:size(states,1)
                subplot( 1+size(states,1), 1, 1+statInd )
                thisState = states(statInd);
                plot( overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).f , overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).P1, 'Color', stateColours(statInd) )
                %plot( overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).f , overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).P1Log, 'Color', stateColours(statInd) )
                xlim([nanmin(F),nanmax(F)])
                ylim('auto')
                title([processList{side},' state ',num2str(thisState),' FFT'])      
                %title([processList{side},' state ',num2str(thisState),' FFT (Log10)'])  
            end
            set(gcf,'Name', [overVar(IIDN).flyName,'-',processList{side},' Additional FFTs'])
            %}
            
        end
        
        %And plot
            %Stalled because I can't figure out matrix indices
        %{
        figure
        for side = 1:size(processList,2)
            %subplot( 1+size(states,1), 1, 1 )
            subplot( 1+size(states,1), size(processList,2), 1+side-1 )
            plot( overFouri(IIDN).allFFT.(processList{side}).f , overFouri(IIDN).allFFT.(processList{side}).P1 , 'Color', 'k' )
            %plot( overFouri(IIDN).allFFT.(processList{side}).f , overFouri(IIDN).allFFT.(processList{side}).P1Log , 'Color', 'k' )
            xlim([nanmin(F),nanmax(F)])
            ylim('auto')
            title([processList{side},' all data FFT'])
            %title([processList{side},' all data FFT (Log)'])

            for statInd = 1:size(states,1)
                %subplot( 1+size(states,1), 1, 1+statInd )
                subplot( 1+size(states,1), size(processList,2), size(processList,2)+(statInd+side) )
                thisState = states(statInd);
                plot( overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).f , overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).P1, 'Color', stateColours(statInd) )
                %plot( overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).f , overFouri(IIDN).stateFFT.(strcat( 'State_', num2str(thisState) )).(processList{side}).P1Log, 'Color', stateColours(statInd) )
                xlim([nanmin(F),nanmax(F)])
                ylim('auto')
                title([processList{side},' state ',num2str(thisState),' FFT'])      
                %title([processList{side},' state ',num2str(thisState),' FFT (Log10)'])  
            end
            set(gcf,'Name', [overVar(IIDN).flyName,' Additional FFTs'])
        end
        %}
        
    end
    %{
    %Find F coords
    fCoords = [];
    for fInd = 1:size(F,2)
        [~, index] = min(abs(f-F(fInd)));
        fCoords( 1, size(fCoords,2)+1 ) = f(index);
        fCoords( 2, size(fCoords,2) ) = index;
    end
    %}
    
    %Plot all flies for each processList element
    for side = 1:size(processList,2)
        figure
        for IIDN = 1:size(overFouri,2)
            subplot( ceil(size(overFouri,2) / 2) , 2 , IIDN )
            %plot( overFouri(IIDN).allFFT.(processList{side}).f , overFouri(IIDN).allFFT.(processList{side}).P1 , 'Color', colours(side) )
            %plot( overFouri(IIDN).allFFT.(processList{side}).f , overFouri(IIDN).allFFT.(processList{side}).P1Log , 'Color', 'k' )
            %plot( fCoords(1,:) , overFouri(IIDN).allFFT.(processList{side}).P1( fCoords(2,:) ) , 'Color', colours(side) )
            plot( overFouri(IIDN).allFFT.(processList{side}).f(1:100:end) , overFouri(IIDN).allFFT.(processList{side}).P1(1:100:end) , 'Color', 'k' )
            %plot( overFouri(IIDN).allFFT.(processList{side}).f(1:100:end) , overFouri(IIDN).allFFT.(processList{side}).P1Log(1:100:end) , 'Color', 'k' )
            xlim([nanmin(F),nanmax(F)])
            %xlim([nanmin(F),nanmax(F)])
            ylim('auto')
            title([overVar(IIDN).flyName])
        end
        set(gcf,'Name', ['Collated ',processList{side},' all FFTs'])
    end
    
    %And states
    %for side = 1:size(processList,2)
    for side = 1:size(processList,2)
        figure
        a = 1;
        for IIDN = 1:size(overFouri,2)
            thisStatesList = fieldnames(overFouri(IIDN).stateFFT);
            for statInd = 1:size(thisStatesList,1)
                thisState = thisStatesList{statInd};
                subplot( ceil( (size(overFouri,2)*stateMax) / (2*stateMax) ) , 2*stateMax , a )
                %plot( overFouri(IIDN).stateFFT.(thisState).(processList{side}).f , overFouri(IIDN).stateFFT.(thisState).(processList{side}).P1, 'Color', stateColours(statInd) )
                plot( overFouri(IIDN).stateFFT.(thisState).(processList{side}).f(1:100:end) , overFouri(IIDN).stateFFT.(thisState).(processList{side}).P1(1:100:end), 'Color', stateColours(statInd) )
                xlim([nanmin(F),nanmax(F)])
                ylim('auto')
                title([overVar(IIDN).flyName,'-',thisState])
                a = a + 1;
            end
        end
        set(gcf,'Name', ['Collated ',processList{side},' state FFTs'])
    end
    %end
    
end

%--------------------------------------------------------------------------------------------------------
['--- Data processing complete ---']
%----------------------
%Save workspace
if automatedSaveWorkspace == 1
    disp(['---- COMMENCING AUTOMATED WORKSPACE (SUBSET) SAVING ----'])
    
    %Assemble packing structure to hold variables
    packStruct = struct;
    for i = 1:size(flagList,1) 
        eval(['packStruct.flags.',flagList{i},' = ', flagList{i},';']);
    end
    for i = 1:size(descVariablesList,2)
        if isempty(strfind(descVariablesList{i}, 'IIDN')) == 1
            eval(['packStruct.desc.',descVariablesList{i},' = ', descVariablesList{i},';']);
        else
            for IIDN = 1:size(overVar,2) %Note: It's possible some variables would differ in size, but unlikely
                eval(['packStruct.desc.',descVariablesList{i},' = ', descVariablesList{i},';']);
            end
        end
    end
    %Note: The structure architecture is preserved in this variable but only a subset of variables from each struct are copied
    
    if clearOldWorkspaceSaves == 1
        oldName = strcat(figPath,'\', progIdent, '_Workspace_', '*' ,'.mat');
        oldSaveList = dir(oldName);
        
        s = warning('error', 'MATLAB:DELETE:Permission');
        for i = 1:size(oldSaveList,1)
            try   
               delete(strcat([figPath, '\', oldSaveList(i).name]));
               disp(['-- Old workspace save deleted --'])
            catch
                ['#### Could not delete existing data file ####']
                error = yes
            end
        end
    end
    
    currDate = datestr(now);
    currDate = currDate(1:12); %Hardcoded, but probably fairly safe
    saveName = strcat(figPath,'\', progIdent, '_Workspace_', currDate ,'.mat');
    save(saveName, '-struct', 'packStruct'); 
    disp(['---- WORKSPACE SAVED ----'])

    if savePEInformation == 1
        
        if clearOldWorkspaceSaves == 1
            oldName = strcat(figPath,'\', progIdent, '_ProbExt_', '*' ,'.mat');
            oldSaveList = dir(oldName);

            s = warning('error', 'MATLAB:DELETE:Permission');
            for i = 1:size(oldSaveList,1)
                try   
                   delete(strcat([figPath, '\', oldSaveList(i).name]));
                   disp(['-- Old workspace save deleted --'])
                catch
                    ['#### Could not delete existing data file ####']
                    error = yes
                end
            end
        end  
        
        %Assemble packing structure to hold variables
        packStruct = struct;
        for i = 1:size(peVariablesList,2)
            if isempty(strfind(peVariablesList{i}, 'IIDN')) == 1 %Check if it is necessary to do an IIDN loop
                eval(['packStruct.',peVariablesList{i},' = ', peVariablesList{i},';']);
            else
                for IIDN = 1:size(overVar,2) %Note: It's possible some variables would differ in size, but unlikely
                    eval(['packStruct.',peVariablesList{i},' = ', peVariablesList{i},';']);
                end
            end
        end
        
        %Save
        currDate = datestr(now);
        currDate = currDate(1:12); %Hardcoded, but probably fairly safe
        saveName = strcat(figPath,'\', progIdent, '_ProbExt_', currDate ,'.mat');
        save(saveName, '-struct', 'packStruct'); 
        disp(['---- PROB EXT DATA SAVED ----'])
        
    end
    
end

if saveFullWorkspace == 1
    disp(['-- Saving full contents of processed data to file -- '])
    tic
    save([workSavePath, filesep, 'workSpace.mat'],'-v7.3')
    disp(['-- Contents of processed data saved to file in ',num2str(toc),'s -- '])
end

if saveIntegrationVariables == 1
    %New
    for IIDN = 1:size(overVar,2) 
    
        %Assemble packing structure to hold variables
        packStruct = struct;
        if automatedSaveWorkspace == 1
            for i = 1:size(flagList,1) 
                eval(['packStruct.flags.',flagList{i},' = ', flagList{i},';']); %Save flags as well, if applicable
            end
        end

        for i = 1:size(integVariablesList,2)
            if isempty(strfind(integVariablesList{i}, 'IIDN')) == 1
                varAc = integVariablesList{i};
            else
                varAc = strrep( integVariablesList{i} ,'(IIDN)' , '' );
            end
            %if isempty(strfind(integVariablesList{i}, 'IIDN')) == 1 %Check if it is necessary to do an IIDN loop
            %    eval(['packStruct.',integVariablesList{i},' = ', integVariablesList{i},';']);
            %else
            %    for IIDN = 1:size(overVar,2) %Note: It's possible some variables would differ in size, but unlikely
                    %eval(['packStruct.',integVariablesList{i},' = ', integVariablesList{i},';']);
                    try
                        eval(['packStruct.',varAc,' = ', integVariablesList{i},';']); %Asymmetry to account for IIDN differences
                    catch
                        ['-# Alert: Variable ',integVariablesList{i},' could not be packed #-']
                    end
                    %    end
            %end
        end

        %Save
        %currDate = datestr(now);
        %currDate = currDate(1:12); %Hardcoded, but probably fairly safe
        %if size(listAAFiles,1) == 1
            saveName = strcat(integPath,'\', overVar(IIDN).flyName, '_behavProcessed.mat');
        %else
        %    %saveName = strcat(integPath,'\', overVar.flyName, '_behavProcessed.mat');
        %    %Need to write some code to mash names together or similar
        %    ['Not implemented yet']
        %    notImplemented = yes
        %end

        if clearOldIntegSaves == 1
            %oldName = strcat(figPath,'\', progIdent, '_ProbExt_', '*' ,'.mat');
            oldSaveList = dir(saveName);

            s = warning('error', 'MATLAB:DELETE:Permission');
            for i = 1:size(oldSaveList,1)
                try   
                   delete(strcat([integPath, '\', oldSaveList(i).name]));
                   disp(['-- Old integ save deleted --'])
                catch
                    ['#### Could not delete existing integ file ####']
                    error = yes
                end
            end
        end 

        save(saveName, '-struct', 'packStruct'); 
        disp(['-- Integration variables saved for ',overVar(IIDN).flyName,' --'])

    end
    
end

%----------------------

%%

overPlot = struct; %(Hopefully) useful structure for storing plot data

%requiem

%Plot useful metrics

%--------------------------------------------------------------------------
%{
%Plot scatter of numBouts
figure
scatter(ones(1,size(sleepStruct.numBouts,2)), sleepStruct.numBouts)
ylabel(['Number of bouts per fly'])
%%title(['Average number of bouts'])

%Plot average bout lengths per fly
figure
barwitherr([nanstd(sleepStruct.avBoutLengthSeconds)], [nanmean(sleepStruct.avBoutLengthSeconds)])
ylabel(['Average bout length (seconds)'])
%%title(['Average number of bouts'])
hold on
scatter(ones(1,size(sleepStruct.avBoutLengthSeconds,2)), sleepStruct.avBoutLengthSeconds)
ylim([0,max(sleepStruct.avBoutLengthSeconds)*1.1])
hold off
%}
%--------------------------------------------------------------------------

if suppressIndivPlots ~= 1
    %Holes (2003)
    for IIDN = 1:size(overVar,2)      
        %%try
            %Plot antennal angles during extracted sleep bouts ('holes')
            %if splitBouts ~= 1
            inStruct = overVar(IIDN).inStructCarry;
            %else
            %    inStruct = overVar(IIDN).splitStruct;
            %end
            %{
            if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1
                %%rightThetaSmoothed = overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed; %Smoothed data
                %%leftThetaSmoothed = overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed;
                rightThetaProc = overVar(IIDN).overGlob.dlcRightAntennaAngleAdj; %Calculated DLC antennal angles, adjusted for relative body angle
                leftThetaProc = overVar(IIDN).overGlob.dlcLeftAntennaAngleAdj;
            else
                if isfield(overVar,'rightThetaSmoothed') == 1
                    %%rightThetaSmoothed = overVar(IIDN).rightThetaSmoothed; %Smoothed data
                    %%leftThetaSmoothed = overVar(IIDN).leftThetaSmoothed;
                    rightThetaProc = overVar(IIDN).rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                    leftThetaProc = overVar(IIDN).leftThetaProc;
                    if forceUseDLCData == 1
                        ['## Warning: Program requested to use DLC data but said data unavailable (IIDN:',num2str(IIDN),') ##']
                    end
                else
                    %%rightThetaSmoothed = [];
                    %%leftThetaSmoothed = [];
                    rightThetaProc = [];
                    leftThetaProc = [];
                end
            end
            %}
            rightThetaProc = overVar(IIDN).xRightAll;
            leftThetaProc = overVar(IIDN).xLeftAll;
            %{
            probMetric = [];
            if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                probMetric = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisHyp;
                dlcProbStatus = '- DLC Prob.'; %Used later for figure title to keep track of what data types in use
            else
                probMetric = overVar(IIDN).avProbContourSizeSmoothed;
                if forceUseDLCData == 1
                    ['## Warning: Program requested to use DLC data but said data unavailable ##']
                end
                dlcProbStatus = '- Sri Prob.';
            end
            %}
            probMetric = overVar(IIDN).probMetric;
            dlcProbStatus = overVar(IIDN).dlcProbStatus;
            
            %QA to pad out smoothed data with NaNs to prevent crashes when plotting bouts that run right up to end
                %Smoothed data disabled
            %{
            if isfield(overVar(IIDN),'rightThetaSmoothed') == 1 && size(rightThetaSmoothed,1) < size(overVar(IIDN).overGlob.rightThetaProc,1)
                rightThetaSmoothed(size(rightThetaSmoothed,1)+1:size(overVar(IIDN).overGlob.rightThetaProc,1)) = NaN;
                leftThetaSmoothed(size(leftThetaSmoothed,1)+1:size(overVar(IIDN).overGlob.leftThetaProc,1)) = NaN;
            end
            %}

            figure
            for i = 1:size(inStruct.holeRanges,2)
                %%scrollsubplot(3,3,i)
                if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                    subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                else %Hardcoded 3x3 that is easier to look at but requires scrolling
                    scrollsubplot(3,3,i)
                end
                try
                    if isempty(rightThetaProc) ~= 1 %For datasets that might exist sans antennal data %isempty(rightThetaSmoothed) ~= 1 %For datasets that might exist sans antennal data
                        %Note: Might affect later axes
                        %%plot(rightThetaSmoothed(inStruct.holeRanges{i}), 'k')
                        %%hold on
                        %%plot(leftThetaSmoothed(inStruct.holeRanges{i}), 'b')
                        plot(rightThetaProc(inStruct.holeRanges{i}), 'k')
                        hold on
                        plot(leftThetaProc(inStruct.holeRanges{i}), 'b')
                        %%hold on
                        xlim([0 inStruct.holeSizes(i)])
                        %ax = gca;
                        %exTicks = 0:60:inStruct.holeSizesSeconds(i);
                        %exTicks = ax.XTick;
                        %{
                        exTicks = linspace(0,inStruct.holeSizes(i),5);
                        exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                        %%maxTick = max(get(gca,'Xtick'));
                        maxTick = inStruct.holeSizes(i);
                        %%xTickScale = maxTick/size(exTicks,2); %Get existing number of X tick labels, calculate behind the scenes scaler
                        ax = gca;
                        ax.XTick = exTicks;
                        ax.XTickLabel = [round(exTicksSeconds/60,1)];
                        %}
                        if i == 1
                            %xlabel('Time (m)')
                            ylabel('Angle (degs)')
                        end
                        

                        ylim([0 50]) %Hardcoded
                        %%ylabel('Angle (degs)')
                    end
                    
                    %Separated from antennal angle dependence
                    exTicks = linspace(0,inStruct.holeSizes(i),5);
                    exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                    %%maxTick = max(get(gca,'Xtick'));
                    maxTick = inStruct.holeSizes(i);
                    %%xTickScale = maxTick/size(exTicks,2); %Get existing number of X tick labels, calculate behind the scenes scaler
                    ax = gca;
                    ax.XTick = exTicks;
                    ax.XTickLabel = [round(exTicksSeconds/60,1)];
                    if i == 1
                        xlabel('Time (m)')
                        %ylabel('Angle (degs)')
                    end
                    
                    if i == 1
                        title(strcat('IIDN:', num2str(IIDN), ' - ', inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ') - ', dlcProbStatus))
                    else
                        title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')'))
                    end 

                    %DLC
                    if doDLC == 1
                        %{
                        %Plot hypotenuse
                        if isempty(overVar(IIDN).dlcLeftAntennaTip_hyp) ~= 1
                            axPos = get(ax,'Position');
                            ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
                            hold on

                            %%plot(overVar(IIDN).dlcLeftAntennaTip_hyp(inStruct.holeRanges{i}), 'red')
                            plot(overVar(IIDN).dlcLeftAntennaTip_hyp_smoothed(inStruct.holeRanges{i}), 'red')
                        end
                        %}
                        %Plot derived angle
                        if isfield(overVar(IIDN).overGlob, 'dlcDataProc') == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1 & ...
                                isempty(overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj) ~= 1
                            %%plot(overVar(IIDN).dlcLeftAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'c')   
                            %%plot(overVar(IIDN).dlcRightAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'r')
                            %plot(overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'r')   
                            %plot(overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'm')
                            %%plot(overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj(inStruct.holeRanges{i}), 'r')   
                            %%plot(overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj(inStruct.holeRanges{i}), 'm')
                            plot(overVar(IIDN).xLeftAll(inStruct.holeRanges{i}), 'r')   
                            plot(overVar(IIDN).xRightAll(inStruct.holeRanges{i}), 'm')
                        end
                    end
                    
                    %Prob
                    if isempty(probMetric) ~= 1 %isempty(overVar(IIDN).avProbContourSizeSmoothed) ~= 1
                        if isempty(rightThetaProc) ~= 1 %isempty(rightThetaSmoothed) ~= 1 %Only do the second axis operations if first axis was never filled with anything
                            axPos = get(ax,'Position');
                            ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
                            set(gca,'XTickLabel',[]); %Hide top X labels (Honestly this should've been implemented long, long ago...)
                            %hold on
                        end
                        hold on
                        plot(probMetric(inStruct.holeRanges{i}), 'green')
                        %%sortedAvPrCnSiSm = sort(avProbContourSizeSmoothed(inStruct.holeRanges{i}));
                        try
                            xlim([0 size(inStruct.holeRanges{i},2)])
                            tempProb = probMetric(inStruct.holeRanges{i});
                            tempProb = tempProb(tempProb ~= 0);
                            tempProb(tempProb > nanmean(tempProb)+2*nanstd(tempProb)) = NaN;
                            %ylim([1 nanmean(tempProb)*15])
                            ylim([1 150]) %Hardcoded for simplicity
                        catch
                            %%ylim([0 nanmean(avProbContourSizeSmoothed(inStruct.holeRanges{i}))*8])
                            %%ylim([0 max(avProbContourSizeSmoothed(inStruct.holeRanges{i}))*3+1])
                            ylim([0 max(probMetric(inStruct.holeRanges{i}))*1.5+1])
                        end
                    end
                    
                    if doTimeCalcs == 1
                        %Add scatter of all detected PEs
                        scatter( probScatter(IIDN).findPEs(i).LOCS, probScatter(IIDN).findPEs(i).PKS, 10 )
                        
                        %Plot raft coords
                        if isfield(probScatter(IIDN).spells(i), 'matchingContigStartEnd') == 1
                            hold on
                            for raftInd = 1:size(probScatter(IIDN).spells(i).matchingContigStartEnd,1)
                                xData = [repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1),1,2), repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2),1,2), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1)];
                                %yData = [0,probInterval, probInterval, 0, 0];
                                yData = [0,nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, 0, 0];
                                fill(xData, yData,'k', 'LineStyle', 'none') %Error shading
                                alpha(0.15)

                                text( nanmean([probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2)]) , ...
                                    nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.15, num2str(raftInd), 'Color', 'c');
                                %{
                                %Add text readouts of freq for peaks within matching coords
                                for subRaftInd = 1:size(probScatter(IIDN).spells(i).matchingContigFreqs{raftInd},1)-1 %Note: -1 tacked on due to overrun issues
                                    text(probScatter(IIDN).findPEs(i).LOCS( probScatter(IIDN).spells(i).matchingContigPEsPos{raftInd}(subRaftInd) )-20, ...
                                        probScatter(IIDN).findPEs(i).PKS( probScatter(IIDN).spells(i).matchingContigPEsPos{raftInd}(subRaftInd) )+3, ...
                                        num2str( round( probScatter(IIDN).spells(i).matchingContigFreqs{raftInd}(subRaftInd) ,3 ) ), 'Color', 'r')
                                    %Honestly the indexing for these text items is almost too complicated to be worth explaining but:
                                    %"Select locations from the total peaks location list based on the subset matchingCoords position list" and so on for the peak heights/etc
                                end
                                %}
                            end
                        end

                        %Plot the prob. threshold
                        hold on
                        if rollingFindPeaks == 0
                            line([0, inStruct.holeSizes(i)], [minProbPeakHeight, minProbPeakHeight], 'Color', 'k', 'LineStyle', ':')
                        else
                            thisBoutRollMeanCoords = ...
                                find( ( overAllPE(IIDN).allPEStruct.rollingFinderMean(:,3) > inStruct.holeRanges{i}(1) & overAllPE(IIDN).allPEStruct.rollingFinderMean(:,3) < inStruct.holeRanges{i}(end) )  );
                            %line([probScatter(IIDN).spells(i).rollingFinderMean(:,2)], [probScatter(IIDN).spells(i).rollingFinderMean(:,1)], 'Color', 'b') %Old system, flawed understanding of rollingFinderMean scale
                            line([ overAllPE(IIDN).allPEStruct.rollingFinderMean(thisBoutRollMeanCoords,3)-inStruct.holeRanges{i}(1) ], [ overAllPE(IIDN).allPEStruct.rollingFinderMean(thisBoutRollMeanCoords,1) ], 'Color', 'b')
                        end
                    end
                    
                    %Perio. shading
                    if exist('overFouri') == 1
                        %shadeColourList = jet(size(processList,2));
                        %if isfield(overFouri(IIDN).fouriStruct,'rollCoords_xLeft') == 1 && isempty(overFouri(IIDN).fouriStruct(i).rollCoords_xLeft) ~= 1 & doSpectro == 1 %Disabling this will probably cause crashes if overFouri could not be calculated for this dataset
                            for side = 1:size(processList,2)
                                %for z = 1:size(overFouri(i).fouriStruct,2) %"Row of combBout" (not necessary in earlier operations because not dealing with more than one double ever)
                                rollCoords = overFouri(IIDN).fouriStruct(i).(strcat('rollCoords_',processList{side}));
                                tempSimpleSig = overFouri(IIDN).fouriStruct(i).(strcat('rollSigSNR_',processList{side})); %Simplifies the giant and complicated indexing
                                tempSimplePeak = overFouri(IIDN).fouriStruct(i).(strcat('rollSigPeak_',processList{side})); %Ditto, for peak
                                for om = 1:size(tempSimpleSig,2) %"Roll position within bout" (Note: This is flattened by coordination with perioCount)
                                    if tempSimpleSig(om) > SNRThresh && (tempSimplePeak(om) >= min(targetPerioFreqRange) && tempSimplePeak(om) <= max(targetPerioFreqRange))
                                        shadeVerty = 1; %How big the shading should be vertically
                                        subRollCoordsRel = rollCoords{om};
                                        subRollCoordsAbs = rollCoords{om} + overVar(IIDN).inStructCarry.holeStarts(i);
                                        shadeXCoords = [ subRollCoordsRel(1) , subRollCoordsRel(2) , subRollCoordsRel(2) , subRollCoordsRel(1) ];
                                        %Old, hardcoded system
                                        %{
                                        if side == 1
                                            shadeYCoords = [ rightThetaSmoothed(subRollCoordsAbs(1)) + shadeVerty , rightThetaSmoothed(subRollCoordsAbs(2)) + shadeVerty ,...
                                                rightThetaSmoothed(subRollCoordsAbs(2)) - shadeVerty , rightThetaSmoothed(subRollCoordsAbs(1)) - shadeVerty ]; %5 arbitrary
                                            shadeColour = 'm';
                                        elseif side == 2
                                            shadeYCoords = [ leftThetaSmoothed(subRollCoordsAbs(1)) + shadeVerty , leftThetaSmoothed(subRollCoordsAbs(2)) + shadeVerty ,...
                                                leftThetaSmoothed(subRollCoordsAbs(2)) - shadeVerty , leftThetaSmoothed(subRollCoordsAbs(1)) - shadeVerty ]; %5 arbitrary
                                            shadeColour = 'r';   
                                        elseif side == 3
                                            shadeYCoords = [ probMetric(subRollCoordsAbs(1)) + shadeVerty , probMetric(subRollCoordsAbs(2)) + shadeVerty ,...
                                                probMetric(subRollCoordsAbs(2)) - shadeVerty , probMetric(subRollCoordsAbs(1)) - shadeVerty ]; %5 arbitrary
                                            shadeColour = 'g';                                            
                                        end
                                        %}
                                        %New
                                        thisProcessData = eval(plotProcessList{side});
                                        shadeYCoords = [ thisProcessData(subRollCoordsAbs(1)) + shadeVerty , thisProcessData(subRollCoordsAbs(2)) + shadeVerty ,...
                                                thisProcessData(subRollCoordsAbs(2)) - shadeVerty , thisProcessData(subRollCoordsAbs(1)) - shadeVerty ]; %5 arbitrary
                                        %shadeColour = 'm';
                                        
                                        fill(shadeXCoords, shadeYCoords, colourProcesses(side,:))
                                        alpha(0.15)
                                    end                        
                                end
                                %end  
                            end
                        %end
                    end
                    
                    
                catch
                    disp(['-- Could not plot hole ', num2str(i), ' of file ', num2str(IIDN), ' --'])
                end
            %inStruct end
            end

            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_HoleFig','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
                if automatedSavePlots == 1 && closeFiguresAfterSaving == 1
                    close gcf
                end
            end

        %%catch
        %%    ['## Warning: Could not plot extracted inactivity bouts ##']
        %%    error = yes
        %%end
    %IIDN end    
    end

    %--------------------------------------------------------------------------

    if doFFT == 1
        %{
        overFouri = struct;
        %}
        successFiles = 0;
        for IIDN = 1:size(overVar,2)
            %try    
                fouriStruct = overFouri(IIDN).fouriStruct;

                %if splitBouts ~= 1
                inStruct = overVar(IIDN).inStructCarry;
                %else
                %    inStruct = overVar(IIDN).splitStruct;
                %end

                %Plot all holes Fouriers
                figure
                for i = 1:size(inStruct.holeRanges,2)
                    if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                        subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                    else %Hardcoded 3x3 that is easier to look at but requires scrolling
                        scrollsubplot(3,3,i)
                    end
                    %Old
                    %{
                    plot(fouriStruct(i).fRight,fouriStruct(i).P1Right,'m')
                    hold on
                    plot(fouriStruct(i).fLeft,fouriStruct(i).P1Left, 'b')
                    %}
                    %New
                    for side = 1:size(processList,2)
                        plot( fouriStruct(i).( strcat('sigFilteredF_',processList{side}) ) ,fouriStruct(i).( strcat('sigFilteredP1_',processList{side}) ) , 'Color', colourProcesses(side,:) )
                    end
                    hold off
                    xlim([0 0.5])
                    %ylim([0 1])
                    if i == 1
                        xlabel('Frequency (Hz)')
                        ylabel('Power')
                    end

                    %%title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ')'))
                    if i == 1
                        %title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ') - Right (m) and Left (b) FFT'))
                        title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ') - ',processList{:},' FFT'))
                    else
                        title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')'))
                    end 

                end
                successFiles = successFiles + 1;
                %{
                %(Block commented because has own section now)
                %Spectro
                if doSpectro == 1
                    figure
                    for i = 1:size(inStruct.holeRanges,2)
                        if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                            subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                        else %Hardcoded 3x3 that is easier to look at but requires scrolling
                            scrollsubplot(3,3,i)
                        end

                        rightThetaSmoothed = overVar(IIDN).rightThetaSmoothed;
                        leftThetaSmoothed = overVar(IIDN).leftThetaSmoothed;
                        xRight = rightThetaSmoothed(inStruct.holeRanges{i})';
                        xLeft = leftThetaSmoothed(inStruct.holeRanges{i})';
                        spectrogram(xLeft,winSize,winOverlap,F,Fs,'yaxis');
                        %%[y,f,t,p] = spectrogram(xRight,winSize,winOverlap,F,Fs,'yaxis'); 
                    end
                end
                %}
            %catch
            %    ['## Warning: Could not plot FFT for ',overVar(IIDN).fileDate,' ##']
            %    successFiles = successFiles;
            %end

            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_FFTFig','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
                if automatedSavePlots == 1 && closeFiguresAfterSaving == 1
                    close gcf
                end
            end

         %{ 
         overFouri(IIDN).fouriStruct = fouriStruct;
         %}
        %IIDN end
        end
        ['-- ',num2str(successFiles),' out of ', num2str(size(listAAFiles,1)),' FFTs plotted successfully --']
    %doFFT end
    end

    %Spectro
    if doFFT == 1 && doSpectro == 1 && nansum( contains( processList, 'xRight' ) ) > 0      
        ['-- Calculating and plotting right antennal spectrograms --']
        for IIDN = 1:size(overVar,2)
            Fs = overVar(IIDN).dataFrameRate; %May need to be integer...
            %if splitBouts ~= 1
            inStruct = overVar(IIDN).inStructCarry;
            %else
            %    inStruct = overVar(IIDN).splitStruct;
            %end

            figure
            for i = 1:size(inStruct.holeRanges,2)
                if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                    subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                else %Hardcoded 3x3 that is easier to look at but requires scrolling
                    scrollsubplot(3,3,i)
                end
                
                try
                    %if isfield(overVar(IIDN).overGlob.hasDataList, 'DORS') == 1 && overVar(IIDN).overGlob.hasDataList.DORS == 1
                        %{
                        if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1
                            %rightThetaSmoothed = overVar(IIDN).overGlob.dlcRightAntennaAngleAdj_smoothed; %Smoothed data
                            %leftThetaSmoothed = overVar(IIDN).overGlob.dlcLeftAntennaAngleAdj_smoothed;
                            rightThetaProc = overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj; %Calculated DLC antennal angles, adjusted for relative body angle
                            leftThetaProc = overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj;
                        else
                            %rightThetaSmoothed = overVar(IIDN).rightThetaSmoothed; %Smoothed data
                            %leftThetaSmoothed = overVar(IIDN).leftThetaSmoothed;
                            %%rightThetaProc = overVar(IIDN).rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                            %%leftThetaProc = overVar(IIDN).leftThetaProc;
                            try %Borrowed from above
                                rightThetaProc = overVar(IIDN).rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                                leftThetaProc = overVar(IIDN).leftThetaProc;
                            catch
                                rightThetaProc = overVar(IIDN).overGlob.rightThetaProc; %Raw, unsmoothed data (processed only to remove anomalously large values)
                                leftThetaProc = overVar(IIDN).overGlob.leftThetaProc;
                                %disp(['-# Warning: Failure to find antennal values in expected structure location (Backup location used instead) #-'])
                            end
                        end
                        %}
                        %xRight = rightThetaProc(inStruct.holeRanges{i})';
                        %xLeft = leftThetaProc(inStruct.holeRanges{i})';
                        xRight = overVar(IIDN).xRightAll(inStruct.holeRanges{i})';
                        xLeft = overVar(IIDN).xLeftAll(inStruct.holeRanges{i})';
                        spectrogram(xRight,overFouri(IIDN).winSizeActive,winOverlapSizeActive,F,Fs,'yaxis');
                        %%[y,f,t,p] = spectrogram(xRight,winSize,winOverlap,F,Fs,'yaxis');
                    %end
                catch
                    disp(['- Could not plot spectrogram for bout number ', num2str(i), ' from file ', num2str(IIDN), ' -'])
                end

                %%title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ')'))
                if i == 1
                    title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ')- Right antennal'))
                else
                    title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')'))
                end
            %holeRanges end
            end        

            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_SpectroFig','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
                if automatedSavePlots == 1 && closeFiguresAfterSaving == 1
                    close gcf
                end
            end
        %IIDN end
        end
        ['-- Spectrograms calculated and plotted successfully --']
    end

    %Spectro on proboscis data
    if doFFT == 1 && doSpectro == 1 && doProbSpectro == 1
        ['-- Calculating and plotting proboscis spectrograms --']
        
        if splitSpells == 1
            overSplit = struct;
        end
        
        for IIDN = 1:size(overVar,2)
            %if splitBouts ~= 1
            inStruct = overVar(IIDN).inStructCarry;
            %else
            %    inStruct = overVar(IIDN).splitStruct;
            %end
            %{
            if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                probMetric = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisHyp;
                dlcProbStatus = '- DLC Prob.';
            else
                probMetric = overVar(IIDN).avProbContourSizeSmoothed;
                dlcProbStatus = '- Sri Prob.';
            end
            %}
            probMetric = overVar(IIDN).probMetric;
            dlcProbStatus = overVar(IIDN).dlcProbStatus;

            figure
            for i = 1:size(inStruct.holeRanges,2)
                if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                    subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                else %Hardcoded 3x3 that is easier to look at but requires scrolling
                    scrollsubplot(3,3,i)
                end
                try
                    %if isempty(overVar(IIDN).avProbContourSizeSmoothed) ~= 1
                    %{
                    %Moved outside of loop to speed things up
                    if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                        probMetric = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisHyp;
                        dlcProbStatus = '- DLC Prob.';
                    else
                        probMetric = overVar(IIDN).avProbContourSizeSmoothed;
                        dlcProbStatus = '- Sri Prob.';
                    end
                    %}
                    %%rightThetaProc = overVar(IIDN).rightThetaProc;
                    %%leftThetaProc = overVar(IIDN).leftThetaProc;
                    probData = probMetric(inStruct.holeRanges{i});
                    %%xRight = rightThetaProc(inStruct.holeRanges{i})';
                    %%xLeft = leftThetaProc(inStruct.holeRanges{i})';
                    spectrogram(probData,overFouri(IIDN).winSizeActive,overFouri(IIDN).winOverlapSizeActive,probF,Fs,'yaxis');
                    %%[y,f,t,p] = spectrogram(xRight,winSize,winOverlap,F,Fs,'yaxis');

                    %%title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ')'))
                    %end
                catch
                    disp(['- Could not plot proboscis spectrogram for bout number ', num2str(i), ' from file ', num2str(IIDN), ' -'])
                end

                if i == 1
                    title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ') - ', dlcProbStatus))
                else
                    title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')'))
                end
            %holeRanges end
            end        

            if doBinaryParallel == 1
                %Calculate parallel frequency results from binary PE detection
                timeRailData = overVar(IIDN).railStruct.sleepRail(:,2)'; %Hardcoded posix time data
                
                colourSpell = jet(size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1));
                
                figure
                for i = 1:size(inStruct.holeRanges,2)
                    if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                        subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                    else %Hardcoded 3x3 that is easier to look at but requires scrolling
                        scrollsubplot(3,3,i)
                    end
                    plotData  = probMetric(inStruct.holeRanges{i});                
                    
                    %Use this if you want to print the interProbFreq data in isolation
                        %Note: Mutually exclusive with plotting prob data (more or less)
                    if isempty(probScatter(IIDN).findPEs(i).LOCS) ~= 1
                        %Plot inter-peak freq. data as a line, using real time cooords
                        %line(LOCS, interProbFreqData, 'Color', 'k')
                        scatter(probScatter(IIDN).findPEs(i).LOCS, probScatter(IIDN).findPEs(i).interProbFreqData, 10, 'k')
                        ylim([0 probInterval])
                    end
                    %[Re]plot contig PEs in colours to match pooled plot
                    if isempty(probScatter(IIDN).spellsPooled) ~= 1
                        for contigInd = 1:size(probScatter(IIDN).spellsPooled.matchingContigHoleNum,1)
                            if probScatter(IIDN).spellsPooled.matchingContigHoleNum(contigInd) == i
                                hold on
                                scatter(probScatter(IIDN).spellsPooled.matchingContigLOCS{contigInd} - inStruct.holeStarts(i), ...
                                    probScatter(IIDN).spellsPooled.matchingContigFreqs{contigInd}, 10, colourSpell(contigInd,:))
                            end
                        end
                    end
                    hold off                                        
                    %{
                    %Plot prob data
                    plot(plotData, 'Color', 'g')
                    %}
                    
                    
                    xlim([0 inStruct.holeSizes(i)])
                    ax = gca;
                    exTicks = linspace(0,inStruct.holeSizes(i),5);
                    exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                    maxTick = inStruct.holeSizes(i);
                    ax.XTick = exTicks;
                    ax.XTickLabel = [round(exTicksSeconds/60,1)];
                    xlabel('Time (mins)')
                    
                    %ylim([0, 300])

                    
                    %Tack on detected peak locations
                    %hold on
                    %scatter(LOCS,PKS)
                    %scatter(probScatter(IIDN).findPEs(i).LOCS,probScatter(IIDN).findPEs(i).PKS)
                    
                    %Add descriptive text to peaks
                    %{
                    for peakInd = 1:size(probScatter(IIDN).findPEs(i).LOCS,1)
                        text(probScatter(IIDN).findPEs(i).LOCS(peakInd)-60,probScatter(IIDN).findPEs(i).PKS(peakInd)+3, num2str(probScatter(IIDN).findPEs(i).interProbFreqData(peakInd)), 'Color', 'r')
                    end
                    %}
                    

                    if i == 1
                        title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ') - ', dlcProbStatus, ' manual freq'))
                        ylabel(['Inter-PE freq (Hz)'])
                        %xlabel('Time (mins)')
                    else
                        title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')'))
                    end

                    %Plot raft coords
                    if isfield(probScatter(IIDN).spells(i), 'matchingContigStartEnd') == 1
                        hold on
                        for raftInd = 1:size(probScatter(IIDN).spells(i).matchingContigStartEnd,1)
                            xData = [repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1),1,2), repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2),1,2), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1)];
                            yData = [0,probInterval, probInterval, 0, 0];
                            %yData = [0,nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, 0, 0];
                            fill(xData, yData,'k', 'LineStyle', 'none') %Error shading
                            alpha(0.15)

                            text( nanmean([probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2)]) , ...
                                nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.15, num2str(raftInd), 'Color', 'c');
                            %{
                            %Add text readouts of freq for peaks within matching coords
                            for subRaftInd = 1:size(probScatter(IIDN).spells(i).matchingContigFreqs{raftInd},1)-1 %Note: -1 tacked on due to overrun issues
                                text(probScatter(IIDN).findPEs(i).LOCS( probScatter(IIDN).spells(i).matchingContigPEsPos{raftInd}(subRaftInd) )-20, ...
                                    probScatter(IIDN).findPEs(i).PKS( probScatter(IIDN).spells(i).matchingContigPEsPos{raftInd}(subRaftInd) )+3, ...
                                    num2str( round( probScatter(IIDN).spells(i).matchingContigFreqs{raftInd}(subRaftInd) ,3 ) ), 'Color', 'r')
                                %Honestly the indexing for these text items is almost too complicated to be worth explaining but:
                                %"Select locations from the total peaks location list based on the subset matchingCoords position list" and so on for the peak heights/etc
                            end
                            %}
                        end
                    end
                    %{
                    %Plot the prob. threshold
                    hold on
                    line([0, inStruct.holeSizes(i)], [minProbPeakHeight, minProbPeakHeight], 'Color', 'k', 'LineStyle', ':')
                    %}
                    
                %holeRanges end        
                end
                
                %------------------------

                %Plot all interProbFreq data
                figure
                
                %Plot all interProbFreqData
                scatter(overAllPE(IIDN).allPEStruct.allLOCS, overAllPE(IIDN).allPEStruct.interProbFreqData, 3, 'k')
                hold on
                
                %Separate by wake and sleep
                if isempty(overAllPE(IIDN).allPEStruct.inBoutPEsLOCS) ~= 1
                    inBoutInds = ismember(overAllPE(IIDN).allPEStruct.allLOCS, overAllPE(IIDN).allPEStruct.inBoutPEsLOCS);
                    scatter( overAllPE(IIDN).allPEStruct.inBoutPEsLOCS, overAllPE(IIDN).allPEStruct.interProbFreqData(inBoutInds), 3, 'b' )
                end
                
                if isempty(overAllPE(IIDN).allPEStruct.outBoutPEsLOCS) ~= 1
                    outBoutInds = ismember(overAllPE(IIDN).allPEStruct.allLOCS, overAllPE(IIDN).allPEStruct.outBoutPEsLOCS);
                    scatter( overAllPE(IIDN).allPEStruct.outBoutPEsLOCS, overAllPE(IIDN).allPEStruct.interProbFreqData(outBoutInds), 3, 'r' )
                end
                
                if isempty(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute) ~= 1
                    hold on
                    for raftInd = 1:size(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute,1)
                        xData = [repmat(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,1),1,2), repmat(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,2),1,2)];
                        yData = [0,probInterval, probInterval, 0];
                        %yData = [0,nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, 0, 0];
                        fill(xData, yData,'k') %Error shading
                        alpha(0.15)

                        text( nanmean([overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,1:2)]) , ...
                            probInterval*0.85, num2str(raftInd), 'Color', 'c');
                    end
                end
                
                try
                    xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate; %Legacy data
                catch
                    xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate; %Modern data
                end
                for i = 1:size(xTimesProc,1)
                    xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
                end
                ax = gca;
                ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
                ax.XTickLabel = [xTimesProc];
                xlabel('Time of day (24h)')
                xlim([0 nanmax(overAllPE(IIDN).allPEStruct.allLOCS)])
                ylim([0 probInterval])
                ylabel('Inter-PE frequency (Hz)')
                title(strcat(overVar(IIDN).fileDate, ' - All inter-PE freqs -', dlcProbStatus))
                
                %------------------------
                
                %Plot pooled spells
                figure
                
                %colourSpell = jet(size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1));
                
                plotXData = [];
                plotYData = [];
                for i = 1:size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1)
                    %{
                    %Deprecated and inefficient method for collating pooled data
                    plotYData( 1:size(probScatter(IIDN).spellsPooled.matchingContigFreqs{i},1), i) = probScatter(IIDN).spellsPooled.matchingContigFreqs{i}; %Manually calculated frequencies
                    plotXData( 1:size(probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i},1), i) = probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i} - ...
                        probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i}(1); %Relative times
                    plotYData( plotYData == 0 ) = NaN;
                    plotXData( plotXData == 0 ) = NaN;
                    %}
                    plotXData = probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i} - ...
                        probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i}(1); %Relative times
                    plotYData = probScatter(IIDN).spellsPooled.matchingContigFreqs{i}; %Manually calculated frequencies
                    scatter(plotXData,plotYData, [], colourSpell(i,:))
                    hold on
                    line(plotXData,plotYData, 'Color', colourSpell(i,:))
                    %pause(1)
                end
                xlim([0, 200])
                ylabel(['Inter-PE freq (Hz)'])
                %ylim([0 probInterval])
                xlabel(['Time (s)'])
                %title(['Pooled PE spell inter-PE freqs'])
                title(strcat(overVar(IIDN).fileDate, ' - Pooled PE spell inter-PE freqs -', dlcProbStatus))
                
                %Place all data into a shared coordinate system
                plotRail = [];
                for i = 1:size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1)
                    plotRail(i, probScatter(IIDN).spellsPooled.matchingContigLOCS{i} - probScatter(IIDN).spellsPooled.matchingContigLOCS{i}(1) + 1 ) =...
                        probScatter(IIDN).spellsPooled.matchingContigFreqs{i};
                        %"Place freqs into relative positions defined by LOCS"
                        %Note: This operation carries a heavy assumption of a relatively constant framerate
                            %But the alternative would require super-sampling time data and is just honestly really complicated
                end
                plotRail( plotRail == 0 ) = NaN;
                
                %Calculate mean in bins
                a = 1;
                nanXData = [];
                nanMeanData = []; %More like...na[n]-mi da"
                nanSEMData = [];
                %binSpecs = (overVar(IIDN).dataFrameRate*meanBinSizeFactor);
                binSpecs = (overVar(IIDN).dataFrameRateInteger*meanBinSizeFactor);
                for x = 1:binSpecs:size(plotRail,2) / binSpecs
                    %binCoords = [ 1 + (x - 1) * binSpecs : x * binSpecs ]; %Specify search coords
                    binCoords = floor([ 1 + (x - 1) * binSpecs : x * binSpecs ]); %Specify search coords; Floor because float
                    subRail = plotRail(:, binCoords ); %Slice out bin
                    presentData = subRail( isnan( subRail ) ~= 1 ); %Filter bin by non-NaNs
                    %{
                    nanMeanData(a) = nanmean( nanmean( plotRail(:, binCoords ) ) ); %Double nanmeans necessary to collapse across both dimensions
                        %When the bin catches more than one set of events, the outermost nanmean is also needed to flatten both catches
                    nanSEMData(a) = nanmean( nanstd( plotRail(:, binCoords ) ) ) / sqrt( nansum( nansum( isnan( plotRail(:, binCoords ) ) ~= 1 ) ) ); %This may seem a little strange but again, it's for collapsing dimensions
                        %"Flatten the nanstd, then calculate the sqrt of the flattened sum of all non-nan values that would have made up said nanstd"
                            %Honestly if this line needs to be rejigged it'll probably be easier to start from scratch rather than try to adjust the indexing in-line
                    %}
                    nanMeanData(a) = nanmean(presentData);
                    nanSEMData(a) = nanstd(presentData) / sqrt( size( presentData,1 ) ); %Normal isnans not necessary here as presentData cannot contain NaNs (probably)
                    nanXData(a) = nanmean(binCoords);
                    a = a + 1;
                end
                
                %Plot mean
                hold on
                line(nanXData / overVar(IIDN).dataFrameRate,nanMeanData, 'Color', 'k')
                    
                %Plot shaded error
                if nansum( nanSEMData ~= 0 ) > 1 %If not true, nanSEMs/nanSTDs will not be valid
                    %shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
                    shadeCoordsX = [nanXData / overVar(IIDN).dataFrameRate , flip( nanXData / overVar(IIDN).dataFrameRate )];
                    %shadeCoordsY = [nanMeans+0.5*nanSEMs,flip(nanMeans-0.5*nanSEMs)];
                    shadeCoordsY = [nanMeanData+nanSEMData , flip(nanMeanData-nanSEMData)];
                    %shadeCoordsY( isnan( shadeCoordsY ) == 1 ) = nanMeanData( isnan( shadeCoordsY ) == 1 ); %Experimental to preserve shading but has too many assumptions
                    fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
                    alpha(0.25)
                end

                %----------------------------------------------------------

                if doIndividualPEPlot == 1

                    %Plot each detected PE in order
                    %i = 1; %Which hole to operate on

                    dynamaFig = figure;

                    for i = 1:size(inStruct.holeRanges,2)
                        clf
                        if isempty(probScatter(IIDN).findPEs(i).LOCS) ~= 1
                            %Plot PE trace for this section
                            %subplot(2,1,1)
                            ox = subplot(2,1,1, 'Parent', dynamaFig);
                            
                            %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

                            plot(probMetric(inStruct.holeRanges{i}), 'green')
                            %ylim([1 300]) %Hardcoded for simplicity
                            ylim('auto')

                            %ox = gca;
                            exTicks = linspace(0,inStruct.holeSizes(i),5);
                            exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                            maxTick = inStruct.holeSizes(i);
                            ox.XTick = exTicks;
                            ox.XTickLabel = [round(exTicksSeconds/60,1)];
                            xlabel('Time (m)')
                            %ylabel('probMetric units')
                            title(strcat('IIDN:', num2str(IIDN), ' - ', inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ') - ', dlcProbStatus))

                            hold on

                            %end

                            if doTimeCalcs == 1
                                %Add scatter of all detected PEs
                                scatter( probScatter(IIDN).findPEs(i).LOCS, probScatter(IIDN).findPEs(i).PKS, 10 )

                                %Plot raft coords
                                hold on
                                for raftInd = 1:size(probScatter(IIDN).spells(i).matchingContigStartEnd,1)
                                    xData = [repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1),1,2), repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2),1,2), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1)];
                                    %yData = [0,probInterval, probInterval, 0, 0];
                                    yData = [0,nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, 0, 0];
                                    fill(xData, yData,'k', 'LineStyle', 'none') %Error shading
                                    alpha(0.15)

                                    text( nanmean([probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2)]) , ...
                                        nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.15, num2str(raftInd), 'Color', 'c');
                                end

                                %Plot the prob. threshold
                                hold on
                                if rollingFindPeaks == 0
                                    line([0, inStruct.holeSizes(i)], [minProbPeakHeight, minProbPeakHeight], 'Color', 'k', 'LineStyle', ':')
                                else  
                                    line([probScatter(IIDN).spells(i).rollingFinderMean(:,2)], [probScatter(IIDN).spells(i).rollingFinderMean(:,1)], 'Color', 'b')
                                end
                            end     

                            %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

                            %subplot(2,1,2)
                            ax = subplot(2,1,2, 'Parent', dynamaFig);
                            for contigInd = 1:size(probScatter(IIDN).findPEs(i).LOCS,1)
                                PEsubCoords = [probScatter(IIDN).findPEs(i).LOCS(contigInd) - probInterval*overVar(IIDN).dataFrameRate : probScatter(IIDN).findPEs(i).LOCS(contigInd) + probInterval*overVar(IIDN).dataFrameRate];
                                if nanmin(PEsubCoords) <= 0 || nanmax(PEsubCoords) > inStruct.holeRanges{i}(end)
                                    PEsubCoords(PEsubCoords <= 0) = [];
                                    PEsubCoords(PEsubCoords > inStruct.holeRanges{i}(end)) = [];
                                end
                                PEsubEpochTime = overVar(IIDN).railStruct.sleepRail(inStruct.holeRanges{i}( PEsubCoords ), 2);

                                plotData = probMetric(inStruct.holeRanges{i});
                                plot( plotData(PEsubCoords) , 'g')
                                
                                %Change X axis to real time
                                %xLimits = [0 probInterval*dataFrameRate*2];
                                xLimits = [0 size(PEsubCoords,2) - 1];
                                xlim(xLimits)
                                %ax = gca;
                                exTicks = linspace(xLimits(1),xLimits(2),5);
                                %exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                                exTicksSeconds = datestr(datetime(PEsubEpochTime( floor(exTicks) + 1 ), 'ConvertFrom', 'posixtime'), 'HH:MM:SS:FFF');
                                maxTick = xLimits(2);
                                ax.XTick = exTicks;
                                ax.XTickLabel = [exTicksSeconds];
                                ax.XTickLabelRotation = 310;
                                xlabel('Time (ZT)')
                                
                                hold on
                                trueCenter = find(PEsubCoords == probScatter(IIDN).findPEs(i).LOCS(contigInd), 1) - 1;
                                scatter(trueCenter, probScatter(IIDN).findPEs(i).PKS(contigInd), 10, 'k')
                                
                                figTitle = [ 'k: ', num2str(i) ', contigInd: ', num2str(contigInd), ' of ', num2str(size(probScatter(IIDN).findPEs(i).LOCS,1)) ];
                                
                                if useExclusionCriteria == 1 & isfield( overExclude(IIDN).exclusionStruct{i}, 'nonPeakMean' ) == 1
                                    line([0, 90], [overExclude(IIDN).exclusionStruct{i}(contigInd).nonPeakMean, overExclude(IIDN).exclusionStruct{i}(contigInd).nonPeakMean], 'Color', 'r', 'LineStyle', ':')
                                    line([0, 90], [overExclude(IIDN).exclusionStruct{i}(contigInd).nonPeakMean + minProbPeakHeight, overExclude(IIDN).exclusionStruct{i}(contigInd).nonPeakMean + minProbPeakHeight], 'Color', 'k', 'LineStyle', ':')

                                    %{
                                    %Fit and plot Gaussian
                                    dataToBeFit = plotData(PEsubCoords);
                                    xToBeFit = [1:size(PEsubCoords,2)]';
                                    [FO, G, ~] = fit( xToBeFit, dataToBeFit, 'gauss2' ); %"More like...FGO"
                                    hold on
                                    %plot(FO)
                                    plot(overExclude(IIDN).exclusionStruct(contigInd).FO)
                                    %}
                                    if doBSnrExclusion == 1
                                        %Bootleg SNR
                                        cheekSize = floor(size(overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.cheekCoords,1)/2);
                                        shadeXLeft = [overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.cheekCoords( 1:cheekSize  ); ...
                                            flip( overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.cheekCoords( 1:cheekSize ) )]';
                                        shadeYLeft = [repmat(nanmin( plotData(PEsubCoords) ), 1, cheekSize), repmat(probScatter(IIDN).findPEs(i).PKS(contigInd), 1, cheekSize)];
                                        fill(shadeXLeft, shadeYLeft,'r') %Error shading
                                        alpha(0.25)
                                        shadeXRight = [overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.cheekCoords( cheekSize+1:end  ); ...
                                            flip( overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.cheekCoords( cheekSize+1:end ) )]';
                                        shadeYRight = [repmat(nanmin( plotData(PEsubCoords) ), 1, cheekSize+1), ...
                                            repmat(probScatter(IIDN).findPEs(i).PKS(contigInd), 1, cheekSize+1)];
                                        fill(shadeXRight, shadeYRight,'r') %Error shading
                                        alpha(0.25)
                                        peakSize = overExclude(IIDN).exclusionStruct{i}(contigInd).cleanW;
                                        shadeXPeak = [repmat(overExclude(IIDN).exclusionStruct{i}(contigInd).trueCenter - peakSize, 1, 2), repmat(overExclude(IIDN).exclusionStruct{i}(contigInd).trueCenter + peakSize, 1, 2) ];
                                        shadeYPeak = [nanmin( plotData(PEsubCoords) ) , probScatter(IIDN).findPEs(i).PKS(contigInd), ...
                                            probScatter(IIDN).findPEs(i).PKS(contigInd), nanmin( plotData(PEsubCoords) )];
                                        fill(shadeXPeak, shadeYPeak,'b') %Error shading
                                        alpha(0.25)

                                    end
                                    %{
                                    %Cannot be used effective in current format due to desynchronisation
                                    if overExclude(IIDN).gaussExcludeList(contigInd) == 1
                                        text([overExclude(IIDN).exclusionStruct{i}(contigInd).trueCenter], [probScatter(IIDN).findPEs(i).PKS(contigInd)*0.5], '## EXCLUDED ##', 'Color', 'r' )
                                    end
                                    %}
                                    
                                    
                                    %Valid but currently suppressed along with parent Gauss calculations
                                    if doGaussExclusion == 1
                                        figTitle = [figTitle, ' (A1: ', num2str(round(overExclude(IIDN).exclusionStruct{i}(contigInd).Gauss.FO.a1,2)), ', B1: ', ...
                                            num2str(round(overExclude(IIDN).exclusionStruct{i}(contigInd).Gauss.FO.b1,2)),', A2: ', ...
                                            num2str(round(overExclude(IIDN).exclusionStruct{i}(contigInd).Gauss.FO.a2,2)),', B2: ', ...
                                            num2str(round(overExclude(IIDN).exclusionStruct{i}(contigInd).Gauss.FO.b2,2)), ')' ]; %Bootleg SNR
                                    end

                                    if doBSnrExclusion == 1
                                        figTitle = [figTitle, ' (BSnr: ', num2str( round(overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.peakSum/overExclude(IIDN).exclusionStruct{i}(contigInd).BSnr.cheekSum,2) ), ')' ]; %Bootleg SNR
                                    end
                                    if doLonesomeExclusion == 1 & isempty( overExclude(IIDN).exclusionStruct{i}(contigInd).lone.lonePKS ) ~= 1
                                        figTitle = [figTitle, ' (Lone peaks: ', num2str( size( overExclude(IIDN).exclusionStruct{i}(contigInd).lone.lonePKS,1 ) ), ')' ];
                                    end
                                %useGaussianExclusion end
                                end

                                %Plot marker of current PE on zoomed out plot
                                currPECoords = [probScatter(IIDN).findPEs(i).LOCS(contigInd), probScatter(IIDN).findPEs(i).LOCS(contigInd)];
                                plot(ox, [currPECoords], [0, probScatter(IIDN).findPEs(i).PKS(contigInd)], 'r');
                                %text(ox, [currPECoords(1)], [probScatter(IIDN).findPEs(i).PKS(contigInd) + 1], num2str(contigInd), 'Color', 'r')

                                %ylim([282 300])
                                hold off
                                %title([ 'contigInd: ', num2str(contigInd), ' (P:', num2str(probScatter(IIDN).findPEs(i).P(contigInd)), ',W:', num2str(probScatter(IIDN).findPEs(i).W(contigInd)), ')' ])
                                %title([ 'contigInd: ', num2str(contigInd), ' (A1: ', num2str(round(FO.a1,2)), ', B1: ', num2str(round(FO.b1,2)),', A2: ', num2str(round(FO.a2,2)),', B2: ', num2str(round(FO.b2,2)), ')' ])
                                %title([ 'contigInd: ', num2str(contigInd), ' of ', num2str(size(probScatter(IIDN).findPEs(i).LOCS,1)), ...
                                %    ' (BSnr: ', num2str(overExclude(IIDN).exclusionStruct(contigInd).peakSum/overExclude(IIDN).exclusionStruct(contigInd).cheekSum), ')' ])
                                
                                %title(['k: ', num2str(holeNum) ', contigInd: ', num2str(contigInd), ' of ', num2str(size(LOCS,1))]) %Blank
                                
                                title(figTitle);
                                
                                pause(1)
                            end
                            if i ~= size(inStruct.holeRanges,2) && contigInd ~= size(probScatter(IIDN).findPEs(i).LOCS,1)
                                clf
                            end
                            
                        %isempty end
                        end
                    %inStruct end
                    end
                %individualPEPlot end    
                end

                %----------------------------------------------------------
                %Split pooled spells and plot
                
                if splitSpells == 1
                    
                    %----------------------
                    %Absolute time split
                    
                    figure

                    %Prepare data
                    splitData = [];
                    allData = [];
                    for splitInd = 1:size(splitCoords,1)
                        splitData{splitInd} = [];
                        for contigInd = 1:size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1) %Might crash on empty
                            splitMatchingFreqs = probScatter(IIDN).spellsPooled.matchingContigFreqs{contigInd}( ...
                                probScatter(IIDN).spellsPooled.matchingContigLOCSTime{contigInd} - probScatter(IIDN).spellsPooled.matchingContigLOCSTime{contigInd}(1) >= splitCoords(splitInd,1) & ...
                                probScatter(IIDN).spellsPooled.matchingContigLOCSTime{contigInd} - probScatter(IIDN).spellsPooled.matchingContigLOCSTime{contigInd}(1) <  splitCoords(splitInd,2) );
                                %"Find all freqs where the relative time from start of spell was larger or equal to the coords minimum bound and less than the coords maximum bound"
                            %splitData{splitInd} = [splitData{splitInd}; splitMatchingFreqs]; %All spells pooled together (from their matching time coordinates obviously)
                            splitData{splitInd} = [splitData{splitInd}; nanmean(splitMatchingFreqs)]; %Mean of matching time periods from spells pooled
                            allData(contigInd,splitInd) = nanmean(splitMatchingFreqs); %Not rigorously checked for zeroes
                        end
                    end

                    %Calculate end-stage means/SDs
                    meanData = [];
                    semData = [];
                    exTicks = [];
                    for splitInd = 1:size(splitCoords,1)
                        meanData(1,splitInd) = nanmean( splitData{splitInd} );
                        semData(1,splitInd) = nanstd( splitData{splitInd} ) / sqrt( nansum( isnan( splitData{splitInd} ) ~= 1 ) );
                            %"SD of data for this split divided by the number of non-NaN values in the component data"
                        exTicks{splitInd} = strcat([num2str(splitCoords(splitInd,1)),' to ',num2str(splitCoords(splitInd,2)),'s']);    
                    end

                    %Plot
                    barwitherr(semData,meanData)
                    hold on
                    %{
                    for splitInd = 1:size(splitCoords,1)
                        scatter(repmat(splitInd, size(splitData{splitInd},1),1 ), splitData{splitInd}); %Points represent spells
                    end
                    %}
                    for contigInd = 1:size(allData,1)
                        scatter( [1:size(splitCoords,1)], allData(contigInd,:), [], colourSpell(contigInd,:) ); %Points represent spells
                    end

                    xlabel('Bin')
                    ax = gca;
                    ax.XTickLabel = exTicks;
                    ylabel(['Mean freq. pos. (Hz)'])

                    title(strcat(overVar(IIDN).fileDate, ' - Split PE spell inter-PE freqs -', dlcProbStatus))
                    
                    %Save data for overuse
                    overSplit(IIDN).allData = allData;
                    overSplit(IIDN).meanData = meanData;
                    
                    %----------------------
                    %Relative position split
                    
                    figure

                    %Prepare data
                    relSplitData = [];
                    relAllData = []; %"More like...Re-L"
                    rellFullData = []; %Stores the actual all data
                    for splitInd = 1:size(splitCoords,1)
                        relSplitData{splitInd} = [];
                        for contigInd = 1:size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1) %Might crash on empty
                            spellData = probScatter(IIDN).spellsPooled.matchingContigFreqs{contigInd};
                            relSplitCoords = [ (splitInd - 1)*floor(size(spellData,1)/size(splitCoords,1))+1 : (splitInd)*floor(size(spellData,1)/size(splitCoords,1)) ];
                                %Note: Use of floor is necessary for indices here but may result in some data being missed
                            splitMatchingFreqs = probScatter(IIDN).spellsPooled.matchingContigFreqs{contigInd}(relSplitCoords);
                            relSplitData{splitInd} = [relSplitData{splitInd}; nanmean(splitMatchingFreqs)]; %Mean of matching time periods from spells pooled
                            relAllData(contigInd,splitInd) = nanmean(splitMatchingFreqs); %Not rigorously checked for zeroes
                            relFullData{contigInd,splitInd} = splitMatchingFreqs; %Rows are spell identity, columns are relative bin identity
                        end
                    end

                    %Calculate end-stage means/SDs
                    meanData = [];
                    semData = [];
                    exTicks = [];
                    for splitInd = 1:size(splitCoords,1)
                        meanData(1,splitInd) = nanmean( relSplitData{splitInd} );
                        semData(1,splitInd) = nanstd( relSplitData{splitInd} ) / sqrt( nansum( isnan( relSplitData{splitInd} ) ~= 1 ) );
                            %"SD of data for this split divided by the number of non-NaN values in the component data"
                        exTicks{splitInd} = strcat([num2str(splitInd-1),'/',num2str(size(splitCoords,1)),' to ', num2str(splitInd),'/',num2str(size(splitCoords,1))]);    
                    end

                    %Plot
                    barwitherr(semData,meanData)
                    hold on
                    for contigInd = 1:size(relAllData,1)
                        scatter( [1:size(splitCoords,1)], relAllData(contigInd,:), [], colourSpell(contigInd,:) ); %Points represent spells
                    end

                    xlabel('Relative bin')
                    ax = gca;
                    ax.XTickLabel = exTicks;
                    ylabel(['Mean freq. pos. (Hz)'])

                    title(strcat(overVar(IIDN).fileDate, ' - Relative split PE spell inter-PE freqs -', dlcProbStatus))
                    
                    %Save data for overuse
                    overSplit(IIDN).relAllData = relAllData;
                    overSplit(IIDN).relMeanData = meanData;
                    overSplit(IIDN).relFullData = rellFullData;
                    
                    %----------------------
                    
                    %Plot pooled relative spells
                    figure
                    
                    plotRelTimes = [];
                    plotXData = [];
                    plotYData = [];
                    for i = 1:size(probScatter(IIDN).spellsPooled.matchingContigFreqs,1)
                        plotRelTimes = probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i} - ...
                            probScatter(IIDN).spellsPooled.matchingContigLOCSTime{i}(1);
                        plotXData = (plotRelTimes / nanmax(plotRelTimes)) * maxRelRange;
                        plotYData = probScatter(IIDN).spellsPooled.matchingContigFreqs{i}; %Manually calculated frequencies
                        scatter(plotXData,plotYData, [], colourSpell(i,:))
                        hold on
                        line(plotXData,plotYData, 'Color', colourSpell(i,:))
                        %pause(1)
                    end
                    xlim([0, maxRelRange])
                    ylabel(['Inter-PE freq (Hz)'])
                    %ylim([0 probInterval])
                    exTicks = [0:floor(maxRelRange/10)/maxRelRange:(maxRelRange/maxRelRange)];
                    ax = gca;
                    ax.XTickLabel = exTicks;
                    xlabel(['Relative time fraction (AU)'])
                    %title(['Pooled PE spell inter-PE freqs'])
                    title(strcat(overVar(IIDN).fileDate, ' - Pooled relative PE spell inter-PE freqs -', dlcProbStatus))
                    
                    %----------------------
                    
                end
                %----------------------------------------------------------
                
            %binaryParallel end    
            end
            
        %IIDN end
        end
        ['-- Spectrograms calculated and plotted successfully --']
            
        if splitSpells == 1 & isempty(overSplit) ~= 1
            
            %--------------------------------------
            
            %Plot pooled split figure
            figure
            
            plotData = [];
            for IIDN = 1:size(overSplit,2)
                plotData(IIDN,:) = overSplit(IIDN).meanData;
            end
            
            meanData = [];
            semData = [];
            exTicks = [];
            for splitInd = 1:size(splitCoords,1)
                meanData(1,splitInd) = nanmean(plotData(:,splitInd));
                semData(1,splitInd) = nanstd( plotData(:,splitInd) ) / sqrt( nansum( isnan( plotData(:,splitInd) ) ~= 1 ) );
                exTicks{splitInd} = strcat([num2str(splitCoords(splitInd,1)),' to ',num2str(splitCoords(splitInd,2)),'s']);    
            end
            
            barwitherr(semData, meanData)
            hold on
            for IIDN = 1:size(plotData,1)
                scatter( [1:size(splitCoords,1)], plotData(IIDN,:));%, [], colourS(IIDN,:) ); %Points represent means of spells (flies)
            end
            
            xlabel('Bin')
            ax = gca;
            ax.XTickLabel = exTicks;
            ylabel(['Mean freq. pos. (Hz)'])

            title(['Pooled binned PE freq in spells per time bin'])
            
            %--------------------------------------
            
            %Plot relative pooled split figure
            figure
            
            plotData = [];
            for IIDN = 1:size(overSplit,2)
                for splitInd = 1:size(splitCoords,1)
                    if isempty(overSplit(IIDN).relAllData) ~= 1
                        plotData(IIDN,splitInd) = nanmean(overSplit(IIDN).relAllData(:,splitInd));
                    else
                        plotData(IIDN,splitInd) = NaN;
                    end
                end
            end
            
            meanData = [];
            semData = [];
            exTicks = [];
            for splitInd = 1:size(splitCoords,1)
                meanData(1,splitInd) = nanmean(plotData(:,splitInd));
                semData(1,splitInd) = nanstd( plotData(:,splitInd) ) / sqrt( nansum( isnan( plotData(:,splitInd) ) ~= 1 ) );
                exTicks{splitInd} = strcat([num2str(splitInd-1),'/',num2str(size(splitCoords,1)),' to ', num2str(splitInd),'/',num2str(size(splitCoords,1))]);
            end
            
            barwitherr(semData, meanData)
            hold on
            for IIDN = 1:size(plotData,1)
                scatter( [1:size(splitCoords,1)], plotData(IIDN,:), [], colourz(IIDN,:) ); %Points represent mean of spells (flies)
            end
            
            xlabel('Bin')
            ax = gca;
            ax.XTickLabel = exTicks;
            ylabel(['Mean freq. pos. (Hz)'])

            title(['Pooled binned PE freq in spells per relative fraction bin'])
            
            %--------------------------------------
        end
        
        %------------------------------------------------------------------
        
        %PE wake vs sleep comparison plots per fly
        for IIDN = 1:size(overVar,2)
            probMetric = overVar(IIDN).probMetric;
            inStruct = overVar(IIDN).inStructCarry;
            %-----------------

            %Raw counts

            figure
            
            plotData = [];
            %{
            plotData(1) = size(overAllPE(IIDN).allPEStruct.inBoutPEsLOCS,1);
            plotData(2) = size(overAllPE(IIDN).allPEStruct.outBoutPEsLOCS,1);
            %}
            plotData(1,1:2) = [size(overAllPE(IIDN).allPEStruct.inBoutPEsLOCS,1), size(overAllPE(IIDN).allPEStruct.outBoutPEsLOCS,1)];

            bar(plotData);

            xlim([0.5, 2.5])
            ylabel(['Raw PE counts'])
            %ylim([0 probInterval])
            if analyseWake == 0
                exTicks = [{'Sleep'},{'Wake'}];
            else
                exTicks = [{'Wake'},{'Sleep'}];
            end
            ax = gca;
            ax.XTickLabel = exTicks;
            title(strcat(overVar(IIDN).fileDate, ' - Raw PE counts -', dlcProbStatus))

            %overAllPE(IIDN).plots.rawCounts.plotData = plotData;

            %-----------------

            %Counts normalised by time
            figure
        
            plotData = [];
            %{
            PERailTimes = overAllPE(IIDN).allPEStruct.allPERail(:,1);
            PERailTimesDiff = [0; diff(PERailTimes)];

            plotData(1) = nansum(overAllPE(IIDN).allPEStruct.allPERail(:,4)) / ...
                ( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1 ) ) / 60);
                %"Total number of in-bout PEs / sum of inter-frame time differences for all times when bout was occurring, in seconds"
            plotData(2) = nansum(overAllPE(IIDN).allPEStruct.allPERail(:,6)) / ...
                ( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,5)) ~= 1 ) ) / 60);
                %Ditto, but for the inverse
            %}
            plotData(1,1:2) = [overAllPE(IIDN).allPEStruct.inBoutPEsAvgPerMin, overAllPE(IIDN).allPEStruct.outBoutPEsAvgPerMin];
            %Temporarily suppressed
            bar(plotData);

            xlim([0.5, 2.5])
            ylabel(['PEs/min.'])
            %ylim([0 probInterval])
            if analyseWake == 0
                exTicks = [{'Sleep'},{'Wake'}];
            else
                exTicks = [{'Wake'},{'Sleep'}];
            end
            ax = gca;
            ax.XTickLabel = exTicks;
            PERailTimes = overAllPE(IIDN).allPEStruct.allPERail(:,1);
            PERailTimesDiff = [0; diff(PERailTimes)];
            figTitle = [strcat(overVar(IIDN).fileDate, ' - Average PEs/min. -', dlcProbStatus)];
            figTitle = [figTitle, ' (InB:', num2str(( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1 ) ) / 60)), 'm, OutB:', ...
                 num2str(( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,5)) ~= 1 ) ) / 60)), 'm)'];
            title(figTitle)

            %overAllPE(IIDN).plots.normCounts.plotData = plotData;

            %-----------------

            %Rolling average PEs/min

            figure
            
            plotDataY = [];
            plotDataX = [];
            %{
            rollBinSize = 5*60*dataFrameRate; %10 minutes

            plotDataY = [];
            plotDataX = [];
            a = 1;
            for i = 1:rollBinSize:size(probMetric,1)
                rollCoords = [ (a-1)*rollBinSize+1 : a*rollBinSize ];
                if nanmax(rollCoords) > size(probMetric,1)
                    rollCoords(rollCoords > size(probMetric,1)) = [];
                end
                plotDataX(a) = (a * rollBinSize) - (0.5 * rollBinSize);
                plotDataY(a) = ( nanmean( overAllPE(IIDN).allPEStruct.allPERail(rollCoords,2) ) ) * dataFrameRate * 60;
                    %"Calculate mean number of PEs per frame, then multiple by frames in 1s, then multiple by seconds in 1m"
                a = a + 1;
            end
            %}
            plotDataY = overAllPE(IIDN).allPEStruct.rollPEY;
            plotDataX = overAllPE(IIDN).allPEStruct.rollPEX;

            plot(plotDataX, plotDataY, 'Color', colourz(IIDN,:)) %Plot PEs/min. as binned by parameter above

            %Plot bout locations
            hold on
            for bout = 1:size(inStruct.holeRanges,2)
                shadeXCoords = [inStruct.holeStarts(bout), inStruct.holeStarts(bout), inStruct.holeEnds(bout), inStruct.holeEnds(bout)];
                shadeYCoords = [0, nanmax(plotDataY), nanmax(plotDataY), 0];
                fill(shadeXCoords, shadeYCoords,'k') %Error shading
                alpha(0.05)
            end

            %xlim([0.5, 2.5])
            ylabel(['PEs/min.'])
            xLimits = [0 size(probMetric,1) - 1];
            xlim(xLimits)
            ax = gca;
            ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;
            %xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate;
            xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate;
            for i = 1:size(xTimesProc,1)
                xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
            end
            ax.XTickLabel = [xTimesProc];
            ax.XTickLabelRotation = 310;
            ax.XColor = 'k';
            ax.YColor = 'k';
            xlabel('Time of day (24h)')
            %ax = gca;
            %ax.XTickLabel = exTicks;
            figTitle = [strcat(overVar(IIDN).fileDate, ' - Average PEs/min. -', dlcProbStatus)];
            %figTitle = [figTitle, ' (InB:', num2str(( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1 ) ) / 60)), 's, OutB:', ...
            %     num2str(( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,5)) ~= 1 ) ) / 60)), 's)'];
            title(figTitle)

            %overAllPE(IIDN).plots.rollPEs.plotDataY = plotDataY;
            %overAllPE(IIDN).plots.rollPEs.plotDataX = plotDataX;

            %-----------------
            
            %Cumulative sum plot for PEs/PE spells
            figure
            
            subplot(2,1,1)
            
            %All PEs
            allPECSData = cumsum(overAllPE(IIDN).allPEStruct.allPERail(:,2));
            plot(allPECSData, 'k')
            hold on
            %Sleep PEs
            tempSleep = overAllPE(IIDN).allPEStruct.allPERail(:,4); %All PEs that occurred within sleep bouts
            tempSleep(isnan(tempSleep) == 1) = 0; %Ditto, but non-sleep bouts have been set to zero
                %This maintains absolute time consistency but may be misleading if studied in isolation
            sleepPECSData = cumsum(tempSleep);
            plot(sleepPECSData,'b')
            %Wake PEs
            tempWake = overAllPE(IIDN).allPEStruct.allPERail(:,6); %All PEs that occurred during wake
            tempWake(isnan(tempWake) == 1) = 0; %Ditto, but sleep bouts have been set to zero
                %This maintains absolute time consistency but may be misleading if studied in isolation
            wakePECSData = cumsum(tempWake);
            plot(wakePECSData,'r')
            
            %====
            ylabel(['Total PE count'])
            xLimits = [0 size(probMetric,1) - 1];
            xlim(xLimits)
            ax = gca;
            ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;
            xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate;
            for i = 1:size(xTimesProc,1)
                xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
            end
            ax.XTickLabel = [xTimesProc];
            ax.XTickLabelRotation = 310;
            ax.XColor = 'k';
            ax.YColor = 'k';
            xlabel('Time of day (24h)')
            figTitle = [strcat(overVar(IIDN).fileDate, ' - PE cumulative sum -', dlcProbStatus)];
            title(figTitle)
            %====
            
            subplot(2,1,2)
            
            %PE spells
            spellRail = zeros(size(probMetric,1), 1);
            for contigInd = 1:size(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute,1)
                %spellRail( overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,1) : overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,2) ) = 1; %Set whole spell to 1s
                spellRail( overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,1) ) = 1; %Set just start to 1
                    %The difference between these two is that the former will give slopes rather than 'spikes' in the cumulative sum
            end
            spellsCSData = cumsum(spellRail);
            plot(spellsCSData, 'Color', colourz(IIDN,:))
            
            %====
            ylabel(['Total PE spell count'])
            xLimits = [0 size(probMetric,1) - 1];
            xlim(xLimits)
            ax = gca;
            ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;
            xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate;
            for i = 1:size(xTimesProc,1)
                xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
            end
            ax.XTickLabel = [xTimesProc];
            ax.XTickLabelRotation = 310;
            ax.XColor = 'k';
            ax.YColor = 'k';
            xlabel('Time of day (24h)')
            figTitle = [strcat(overVar(IIDN).fileDate, ' - PE spell cumulative sum -', dlcProbStatus)];
            title(figTitle)
            %====
            
            %-----------------
        end
               
        %chise
        
    end
    %--------------------------------------------------------------------------

    %--------------------------------------------------------------------------

    if doFFT == 1 && doScram == 1
        %Plot scrambled antennal angles
        for IIDN = 1:size(overVar,2)
            %if splitBouts ~= 1
            inStruct = overVar(IIDN).inStructCarry;
            %else
            %    inStruct = overVar(IIDN).splitStruct;
            %end

            figure
            for i = 1:size(inStruct.holeRanges,2)
                %%scrollsubplot(3,3,i)
                if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                    subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                else %Hardcoded 3x3 that is easier to look at but requires scrolling
                    scrollsubplot(3,3,i)
                end
                plot(inStruct.xRightScram{i}, 'k')
                hold on
                plot(inStruct.xLeftScram{i}, 'b')
                xlim([0 inStruct.holeSizes(i)])
                ax = gca;
                exTicks = linspace(0,inStruct.holeSizes(i),5);
                exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                maxTick = inStruct.holeSizes(i);
                ax.XTick = exTicks;
                ax.XTickLabel = [round(exTicksSeconds/60,1)];
                if i == 1
                    xlabel('Time (m)')
                    ylabel('Angle (degs)')
                end

                ylim([40 100]) %Hardcoded

                %%title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ') - Scrambled'))
                if i == 1
                    title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ')-Scram'))
                else
                    title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')-Scram'))
                end 
            %i end    
            end
            %{
            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_HoleFigScram','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
            end
            %}
        %IIDN end    
        end

        %Scrambled fouris
        for IIDN = 1:size(overVar,2)
            %try    
                fouriStruct = overFouri(IIDN).fouriStruct;

                %if splitBouts ~= 1
                inStruct = overVar(IIDN).inStructCarry;
                %else
                %    inStruct = overVar(IIDN).splitStruct;
                %end

                %Plot all holes Fouriers
                figure
                for i = 1:size(inStruct.holeRanges,2)
                    if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                        subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                    else %Hardcoded 3x3 that is easier to look at but requires scrolling
                        scrollsubplot(3,3,i)
                    end
                    plot(fouriStruct(i).fRightScram,fouriStruct(i).P1RightScram)
                    hold on
                    plot(fouriStruct(i).fLeftScram(2:end),fouriStruct(i).P1LeftScram(2:end))
                    hold off
                    xlim([0 1])
                    ylim([0 1])
                    if i == 1
                        xlabel('Frequency (Hz)')
                        ylabel('Power')
                    end

                    %%title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ') - Scrambled'))
                    if i == 1
                        title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ')-Scram'))
                    else
                        title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')-Scram'))
                    end               
                end

            %{
            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_FFTFigScram','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
            end
            %}

        %IIDN end
        end

    end

    %--------------------------------------------------------------------------

    %FFTs with SNR overlay
    if doFFT == 1 && doSNR == 1
        for IIDN = 1:size(overVar,2)

            fouriStruct = overFouri(IIDN).fouriStruct;

            %if splitBouts ~= 1
            inStruct = overVar(IIDN).inStructCarry;
            %else
            %    inStruct = overVar(IIDN).splitStruct;
            %end

            %Plot all holes Fouriers
            figure
            for i = 1:size(inStruct.holeRanges,2)
                if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                    subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                else %Hardcoded 3x3 that is easier to look at but requires scrolling
                    scrollsubplot(3,3,i)
                end
                %{
                plot(fouriStruct(i).sigFilteredF,fouriStruct(i).sigFil)
                hold on
                plot(fouriStruct(i).fLeftScram(2:end),fouriStruct(i).P1LeftScram(2:end))
                hold off
                xlim([0 1])
                ylim([0 1])
                if i == 1
                    xlabel('Frequency (Hz)')
                    ylabel('Power')
                end

                title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ') - Scrambled'))
                %}
                sigSNRList = [];
                strProcessList = []; %String, single-line version of processList for title usage
                for side = 1:size(processList,2)
                    strProcessList = [strProcessList, processList{side}, ','];
                    if side*3 <= size(colours,2)
                        plotColours = [{colours((side-1)*3+1)},{colours((side-1)*3+2)},{colours((side-1)*3+3)}];
                    else
                        plotColours = [{'r'},{'g'},{'b'}];
                    end

                    %%plot(fouriStruct(i).sigFilteredF,fouriStruct(i).sigFilteredP1,'r')
                    filteredF = fouriStruct(i).(strcat('sigFilteredF_',processList{side}));
                    filteredP1 = fouriStruct(i).(strcat('sigFilteredP1_',processList{side}));
                    crushedFilteredP1 = fouriStruct(i).(strcat('sigCrushedFilteredP1_',processList{side}));
                    antiCrushedFilteredP1 = fouriStruct(i).(strcat('sigAntiCrushedFilteredP1_',processList{side}));
                    sigSNR = fouriStruct(i).(strcat('sigSNR_',processList{side}));
                    sigSNRList = [sigSNRList,num2str(round(sigSNR,2))];
                    if side < size(processList,2)
                        sigSNRList = [sigSNRList,','];
                    end
                    hold on
                    plot(filteredF,filteredP1,plotColours{1})
                    %%title(['Filtered FFT'])
                    %%xlim([min(F) 1])
                    %%figure
                    hold on
                    plot(filteredF,crushedFilteredP1,plotColours{2})
                    %%title(['Crushed, filtered FFT'])
                    hold on
                    plot(filteredF,antiCrushedFilteredP1,plotColours{3})
                    %%title(['Anticrushed, filtered FFT'])
                    hold off
                    %%title(['Filtered FFT'])
                    %{
                    if i == 1
                        title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ') S:', num2str(round(sigSNR,2))))
                    else
                        title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), ' - ',inStruct.holeEndsTimes{i}(end-8:end-3),' (k= ', num2str(i), ') S:', num2str(round(sigSNR,2))))
                    end
                    %}
                    xlim([min(F) 1])
                    %%ylim([0 2])
                %side end
                end

                if i == 1
                    %title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ')S:', sigSNRList))
                    title({ strcat( inStruct.holeStartsTimes{i}(1:end-3), ' - ',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ') - FFT w/ SNR' ), strcat('S:', sigSNRList ), strcat( strProcessList ) })
                else
                    %title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')', 'S:', sigSNRList))
                    %title(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')', 'S:', sigSNRList)
                    title({strcat( inStruct.holeStartsTimes{i}(end-8:end-3), ' - ',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')' ), strcat('S:', sigSNRList )})
                end
            %i end
            end

            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_FFTFigWSNR','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
                if automatedSavePlots == 1 && closeFiguresAfterSaving == 1
                    close gcf
                end
            end

        %IIDN end
        end 
    end

    %Grand plot of all data for processList elements
    if doFFT == 1 && doSNR == 1
        for IIDN = 1:size(overVar,2)
            figure
            for side = 1:size(processList,2)
                if contains( processList{side}, 'xRight' ) == 1 || contains( processList{side}, 'xLeft' ) == 1
                    thisData = overVar(IIDN).( strcat(processList{side},'All') );
                elseif contains( processList{side}, 'probData' ) == 1
                    thisData = overVar(IIDN).probMetric;
                end

                subplot( size(processList,2) , 4, [(side*4)-3:(side*4)-1] )
                %plot( thisData( overVar(IIDN).railStruct.sleepRail(:,2+side*2) == 1 ) )
                plot( [1:nansum(overVar(IIDN).railStruct.sleepRail(:,2+side*2) == 1)]./overVar(IIDN).dataFrameRate, thisData( overVar(IIDN).railStruct.sleepRail(:,2+side*2) == 1 ) )
                xlabel( ['Non-contiguous time (s)'] )
                title([processList{side},' data during ', processList{side}, ' perio. (SNRThresh: ',num2str(SNRThresh),')'])

                subplot( size(processList,2) , 4, [side*4] )
                y = fft( thisData( overVar(IIDN).railStruct.sleepRail(:,2+side*2) == 1 ) );
                L = length(y);
                P2 = abs(y/L);
                P1 = P2(1:L/2+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = fs*(0:(L/2))/L;
                plot( f , P1 )
                xlim([min(F) 1])
                title([processList{side},' perio. FFT'])
                %Note: In essence this is an FFT of data selected by FFT, just FYI

            end
            set(gcf,'Name', [overVar(IIDN).flyName,' - periodicity data and freqs'])

            %And for LOCs PEs
            figure

            subplot(1,4,[1:3])
            tempCoords = find( overVar(IIDN).railStruct.sleepRail(:,3) == 1 );
            minTempCoords = floor(tempCoords - probInterval*overVar(IIDN).dataFrameRate);
            maxTempCoords = floor(tempCoords + probInterval*overVar(IIDN).dataFrameRate);
            tempFullCoords = [];
            for i = 1:size(tempCoords)
                tempFullCoords = [tempFullCoords,minTempCoords(i):maxTempCoords(i)];
            end
            %plot( overVar(IIDN).probMetric( tempFullCoords ) )
            plot( [1:size(tempFullCoords,2)]./overVar(IIDN).dataFrameRate, overVar(IIDN).probMetric( tempFullCoords ) )
            xlabel( ['Non-contiguous time (s)'] )
            title(['probMetric during PE LOCs'])

            subplot(1,4,4)
            temp = diff( find(overVar(IIDN).railStruct.sleepRail(:,3) == 1) )./overVar(IIDN).dataFrameRate;
            %arbCutoff = 20;
            arbCutoff = probInterval*contiguityThreshold;
            tempLoss = 1 - ( nansum( temp < arbCutoff ) / size(temp,1) ); %Fraction of inter-PE intervals about to be lost
            temp = temp(temp < arbCutoff);
            hist( 1./temp , 32 )
            %xlim([0,1/arbCutoff])
            xlabel(['Freq (Hz)'])
            title(['Inter-PE freq for all inBout PEs (',num2str(tempLoss*100),'% exceeded ',num2str(arbCutoff),'s and were excluded)'])  
            set(gcf,'Name', [overVar(IIDN).flyName,' - PE LOCs data and freq'])
        end
    end

    %Custom specific FFT
    if doFFT == 1 && doSNR == 1 && doSpecificFFTs == 1
        for custIt = 1:size(specFFTList,2)
            IIDN = specFFTList(1,custIt);


            fouriStruct = overFouri(IIDN).fouriStruct;

            %if splitBouts ~= 1
            inStruct = overVar(IIDN).inStructCarry;
            %else
            %    inStruct = overVar(IIDN).splitStruct;
            %end

            %Plot all holes Fouriers
            figure
            %%for custItStage2 = 1:size(inStruct.holeRanges,2)
                i = specFFTList(2,custIt);
                %{
                if subPlotMode == 1 %Plot on one big page, with rows/column sizes determined by number of things to plot
                    subplot(round(sqrt(size(inStruct.holeRanges,2)),0),ceil(sqrt(size(inStruct.holeRanges,2))),i)
                else %Hardcoded 3x3 that is easier to look at but requires scrolling
                    scrollsubplot(3,3,i)
                end
                %}
                %{
                plot(fouriStruct(i).sigFilteredF,fouriStruct(i).sigFil)
                hold on
                plot(fouriStruct(i).fLeftScram(2:end),fouriStruct(i).P1LeftScram(2:end))
                hold off
                xlim([0 1])
                ylim([0 1])
                if i == 1
                    xlabel('Frequency (Hz)')
                    ylabel('Power')
                end

                title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ') - Scrambled'))
                %}
                sigSNRList = [];
                for side = 1:size(processList,2)
                    if side*3 <= size(colours,2)
                        plotColours = [{colours((side-1)*3+1)},{colours((side-1)*3+2)},{colours((side-1)*3+3)}];
                    else
                        plotColours = [{'r'},{'g'},{'b'}];
                    end

                    %%plot(fouriStruct(i).sigFilteredF,fouriStruct(i).sigFilteredP1,'r')
                    filteredF = fouriStruct(i).(strcat('sigFilteredF_',processList{side}));
                    filteredP1 = fouriStruct(i).(strcat('sigFilteredP1_',processList{side}));
                    crushedFilteredP1 = fouriStruct(i).(strcat('sigCrushedFilteredP1_',processList{side}));
                    antiCrushedFilteredP1 = fouriStruct(i).(strcat('sigAntiCrushedFilteredP1_',processList{side}));
                    sigSNR = fouriStruct(i).(strcat('sigSNR_',processList{side}));
                    sigSNRList = [sigSNRList,num2str(round(sigSNR,2))];
                    if side < size(processList,2)
                        sigSNRList = [sigSNRList,','];
                    end
                    hold on
                    plot(filteredF,filteredP1,plotColours{1})
                    %%title(['Filtered FFT'])
                    %%xlim([min(F) 1])
                    %%figure
                    hold on
                    plot(filteredF,crushedFilteredP1,plotColours{2})
                    %%title(['Crushed, filtered FFT'])
                    hold on
                    plot(filteredF,antiCrushedFilteredP1,plotColours{3})
                    %%title(['Anticrushed, filtered FFT'])
                    hold off
                    %%title(['Filtered FFT'])
                    %{
                    if i == 1
                        title(strcat(inStruct.holeStartsTimes(i), ' - ',inStruct.holeEndsTimes{i}(end-8:end),' (k= ', num2str(i), ') S:', num2str(round(sigSNR,2))))
                    else
                        title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), ' - ',inStruct.holeEndsTimes{i}(end-8:end-3),' (k= ', num2str(i), ') S:', num2str(round(sigSNR,2))))
                    end
                    %}
                    xlim([min(F) 1])
                    xlabel('Frequency (Hz)')
                    ylabel('Power')
                    %%ylim([0 2])
                %side end
                end

                %if i == 1
                    title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ')S:', sigSNRList))
                %else
                %    title(strcat(inStruct.holeStartsTimes{i}(end-8:end-3), '-',inStruct.holeEndsTimes{i}(end-8:end-3),' (k:', num2str(i), ')S:', sigSNRList))
                %end
            %i end
            %%end

            if savePlots == 1
                saveName = strcat(figPath,'\',overVar(IIDN).fileDate(1:end-9),'_FFTFigWSNR_Specific','.png');
                %%saveas(gcf, saveName, 'png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                export_fig(saveName)
                if automatedSavePlots == 1 && closeFiguresAfterSaving == 1
                    close gcf
                end
            end

        %IIDN end
        end 
    end
        
%-------------
%suppressIndivPlots end
end

%----------------------------------------------------------------------
%Modified activity over whole recording plot


%Plot smoothed average contour size and antennal angles in one graph
for IIDN = 1:size(overVar,2)
    %SASIFRAS load
    xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate;
    avContourSizeSmoothed = overVar(IIDN).avContourSizeSmoothed;
    %{
    if isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1 %|| isfield( overVar(IIDN).overGlob.dlcDataProc ,'dlcRightAntennaAngleAdj_smoothed') == 1
        if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1
            %%rightThetaSmoothed = overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed; %Smoothed data
            %%leftThetaSmoothed = overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed;
            rightThetaProc = overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj; %Smoothed data
            leftThetaProc = overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj;
        else
            rightThetaSmoothed = overVar(IIDN).rightThetaSmoothed; %Smoothed data
            leftThetaSmoothed = overVar(IIDN).leftThetaSmoothed;
        end
    end
    %}
    rightThetaProc = overVar(IIDN).xRightAll;
    leftThetaProc = overVar(IIDN).xLeftAll;
    %{
    if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
        probMetric = overVar(IIDN).overGlob.dlcDataProc.dlcProboscisHyp;
    else
        probMetric = overVar(IIDN).avProbContourSizeSmoothed;
    end
    %}
    probMetric = overVar(IIDN).probMetric;
    dlcProbStatus = overVar(IIDN).dlcProbStatus;

    trueAv = overVar(IIDN).trueAv;
    adjAv = overVar(IIDN).adjAv;
    inStruct = overVar(IIDN).inStructCarry;

    for i = 1:size(xTimesProc,1)
        xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
    end

    figure

    hold on
    %{
    if isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1 || isfield( overVar(IIDN).overGlob.dlcDataProc ,'dlcRightAntennaAngleAdj_smoothed') == 1
        plot(rightThetaSmoothed, 'c') %Right SwarmSight antennal angle
        hold on
        plot(leftThetaSmoothed, 'b') %Left SwarmSight antennal angle
    end
    %}
    plot(overVar(IIDN).xRightAll, 'c') %Right SwarmSight antennal angle
    hold on
    plot(overVar(IIDN).xLeftAll, 'b') %Left SwarmSight antennal angle
    %{
    plot(overVar(IIDN).overGlob.dlcLeftAntennaAngleAdj_smoothed, 'r')   
    plot(overVar(IIDN).overGlob.dlcRightAntennaAngleAdj_smoothed, 'm')
    %}

    %Sri detected movement contour size
    ax = gca;
    ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
    ax.XTickLabel = [xTimesProc];
    ax.XColor = 'k';
    ax.YColor = 'k';
    xlabel('Time of day (24h)')
    ylabel(overVar(IIDN).flyName)

    axPos = get(ax,'Position');
    ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
    hold on
    if exist('avContourSizeSmoothed') == 1 && isempty(avContourSizeSmoothed) ~= 1
        plot(avContourSizeSmoothed, 'black')
        limMax = round(1.1*nanmax(avContourSizeSmoothed),0);
        %ylim([0 4*nanmax(avContourSizeSmoothed)])
        ylim([0 limMax])
    else
       disp(['Cannot plot avContourSizeSmoothed'])
       ylim('auto')
       limMax = nanmax( get(gca,'ylim') );
    end
    
    title([overVar(IIDN).flyName])

    plot(probMetric, 'green') %Sri detected proboscis extension contour size

    %{
    %Hole indexes
    hold on
    %Plot true mean for separation purposes
    xVals = [1:size(avContourSizeSmoothed,1)];
    yVals = [repmat(trueAv,1,size(avContourSizeSmoothed,1))];
    plot(xVals, yVals, 'MarkerFaceColor', 'g');

    hold on
    %Plot true mean for separation purposes
    xVals = [1:size(avContourSizeSmoothed,1)];
    yVals = [repmat(adjAv,1,size(avContourSizeSmoothed,1))];
    plot(xVals, yVals, 'MarkerFaceColor', 'r');
    %hold off
    %}
    %{
    hold on %when you feel like all hope is gone
    %Plot box around detected 'holes'
    for i = 1:size(inStruct.holeStarts,2)
        xData = [repmat(inStruct.holeStarts(i),1,2), repmat(inStruct.holeEnds(i),1,2), inStruct.holeStarts(i)];
        yData = [1,limMax, limMax, 1, 1];
        line(xData,yData, 'Color', 'r')
        %hold on
    end
    %}

    hold on
    %Plot shaded fill over hole
    for i = 1:size(inStruct.holeStarts,2)
        xData = [repmat(inStruct.holeStarts(i),1,2), repmat(inStruct.holeEnds(i),1,2), inStruct.holeStarts(i)];
        yData = [1,limMax, limMax, 1, 1];
        fill(xData, yData,'k') %Error shading
        alpha(0.25)
    end    

    %{
    %Plot starting times of detected >threshold 'holes'
    for i = 1:size(inStruct.holeStarts,2)
        xVals = [repmat(inStruct.holeStarts(i),1,limMax)];
        yVals = [1:limMax];
        plot(xVals, yVals, 'MarkerFaceColor', 'r');
    end
    hold on %when you feel like all hope is gone
    %Plot ending times of detected >threshold 'holes'
    for i = 1:size(inStruct.holeEnds,2)
        xVals = [repmat(inStruct.holeEnds(i),1,limMax)];
        yVals = [1:limMax];
        plot(xVals, yVals, 'MarkerFaceColor', 'r');
    end
    %}

    hold on %when you feel like all hope is gone
    %Plot hole numbers on graph
    xVals = [];
    yVals = [];
    yLims = ylim;
    for i = 1:size(inStruct.holeStarts,2)
        xVals = [xVals nanmean([inStruct.holeStarts(i), inStruct.holeEnds(i)])]; %Plot in middle of 'hole'
        yVals = [yVals 0.85*yLims(2)];
        text(xVals(i), yVals(i), num2str(i), 'Color', 'r');
    end
    hold off

end

%----------------------------------------------------------------------

%--------------------------------------------------------------------------

%Transplanted PE plots
if doFFT == 1 && doSpectro == 1 && doProbSpectro == 1 && doTimeCalcs == 1
        %------------------------------------------------------------------
        %Pooled raw counts
        figure
        
        plotData = [];
        for IIDN = 1:size(overVar,2)
            %plotData(IIDN,1) = overAllPE(IIDN).plots.rawCounts.plotData(1);
            %plotData(IIDN,2) = overAllPE(IIDN).plots.rawCounts.plotData(2);
            plotData(IIDN,1) = size( overAllPE(IIDN).allPEStruct.inBoutPEsLOCS ,1);
            plotData(IIDN,2) = size( overAllPE(IIDN).allPEStruct.outBoutPEsLOCS ,1);
        end
        
        meanData = [];
        semData = [];
        
        meanData = nanmean(plotData,1); %Note dimensionality specification
        if size(plotData,1) > 1
            semData = nanstd(plotData,1) / sqrt( size(plotData,1) );
        else
            semData(1,1:2) = [0,0];
        end
        
        barwitherr(semData,meanData)
        
        for IIDN = 1:size(overVar,2)
            hold on
            scatter( [1:2] , plotData(IIDN,:), [], colourz(IIDN,:))
            line([1,2],[plotData(IIDN,:)], 'Color', colourz(IIDN,:))
        end
        
        xlim([0.5, 2.5])
        ylabel(['Raw PE counts'])
        %ylim([0 probInterval])
        if analyseWake == 0
            exTicks = [{'Sleep'},{'Wake'}];
        else
            exTicks = [{'Wake'},{'Sleep'}];
        end
        ax = gca;
        ax.XTickLabel = exTicks;
        figTitle = ['Pooled raw PE counts'];
        
        %#######
        %Stats
        if size(plotData,1) > 3
            %Normality
            figTitle = [figTitle, ' (Normality: '];
            for i = 1:size(plotData,2)
                [normHdata(i), normPdata(i)] = swtest(plotData(:,i));
                figTitle = [figTitle, exTicks{i}, ' ', num2str(normHdata(i)), ' , '];
            end
            figTitle = [figTitle, '; Test p: '];
            %WSR or Paired T-test
            statTestUsed = '';
            if nansum(normHdata) ~= size(normHdata,2) %"Not all samples normal"
                [statPdata, statHdata] = ranksum(plotData(:,1), plotData(:,2));
                statTestUsed = 'WSR';
            else
                [statHdata, statPdata] = ttest(plotData(:,1), plotData(:,2));
                statTestUsed = 'Paired T-test';
            end
            figTitle = [figTitle, num2str(round(statPdata,4)), ' ; ', statTestUsed , ')'];
        end
        %#######
        
        title(figTitle)
        
        %------------------------------------------------------------------
        
        %Pooled normalised PEs during sleep vs wake
        figure
        
        plotData = [];
        for IIDN = 1:size(overVar,2)
            %plotData(IIDN,1) = overAllPE(IIDN).plots.normCounts.plotData(1);
            %plotData(IIDN,2) = overAllPE(IIDN).plots.normCounts.plotData(2);
            plotData(IIDN,1) = overAllPE(IIDN).allPEStruct.inBoutPEsAvgPerMin;
            plotData(IIDN,2) = overAllPE(IIDN).allPEStruct.outBoutPEsAvgPerMin;
        end
        
        meanData = [];
        semData = [];
        
        meanData = nanmean(plotData,1); %Note dimensionality specification
        if size(plotData,1) > 1
            semData = nanstd(plotData,1) / sqrt( size(plotData,1) );
        else
            semData(1,1:2) = [0,0];
        end
        
        barwitherr(semData,meanData)
        
        for IIDN = 1:size(overVar,2)
            hold on
            scatter( [1:2] , plotData(IIDN,:), [], colourz(IIDN,:))
            line([1,2],[plotData(IIDN,:)], 'Color', colourz(IIDN,:))
        end
        
        xlim([0.5, 2.5])
        ylabel(['PEs/min.'])
        %ylim([0 probInterval])
        if analyseWake == 0
            exTicks = [{'Sleep'},{'Wake'}];
        else
            exTicks = [{'Wake'},{'Sleep'}];
        end
        ax = gca;
        ax.XTickLabel = exTicks;
        figTitle = ['Pooled time-normalised PE counts'];
        title(figTitle)
        set(gcf,'Name', 'PEs per min sleep vs wake')
        barStats(plotData,alphaValue,[],[],1); %inputData, alpha, exTicks, allow Y expansion, check normality (And do non-parametric if non-normal detected)
        if doSriBoxPlot == 1
            sriBoxPlot(plotData,alphaValue,exTicks,0.2,[0,0,1;1,0,0],[],[],[],1) %"Why Try"            
        end
        
        %#######
        %Stats
        %{
        if size(plotData,1) > 3
            %Normality
            figTitle = [figTitle, ' (Normality: '];
            for i = 1:size(plotData,2)
                [normHdata(i), normPdata(i)] = swtest(plotData(:,i));
                figTitle = [figTitle, exTicks{i}, ' ', num2str(normHdata(i)), ' , '];
            end
            figTitle = [figTitle, '; Test p: '];
            %WSR or Paired T-test
            statTestUsed = '';
            if nansum(normHdata) ~= size(normHdata,2) %"Not all samples normal"
                [statPdata, statHdata] = ranksum(plotData(:,1), plotData(:,2));
                statTestUsed = 'WSR';
            else
                [statHdata, statPdata] = ttest(plotData(:,1), plotData(:,2));
                statTestUsed = 'Paired T-test';
            end
            figTitle = [figTitle, num2str(round(statPdata,4)), ' ; ', statTestUsed , ')'];
        end
        %}
        %#######
          
        
        %------------------------------------------------------------------
        
        %Pooled normalised spells during sleep vs wake
        figure
        
        plotData = [];
        for IIDN = 1:size(overVar,2)
            
            %Calculate total time within bouts (i.e. Sleeping)
            PERailTimes = overAllPE(IIDN).allPEStruct.allPERail(:,1);
            PERailTimesDiff = []; %Not sure if necessary but too scared to not have in place
            PERailTimesDiff = [0; diff(PERailTimes)];
            totalSleepTimeMins = ( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1 ) ) / 60); %Note: Column reference hardcoded
            totalWakeTimeMins = ( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,5)) ~= 1 ) ) / 60);
            
            %Calculate number of spells that occurred with-in and with-out holes
                %Note: Spells that span both wake and sleep will probably be double-counted here maybe?
            totalSpellCount = size( overAllPE(IIDN).spellStruct.matchingContigSizes,1 );
            totalSleepSpellCount = 0;
            for sleepHoleNum = 1:size(probScatter(IIDN).spells,2)
                if isfield(probScatter(IIDN).spells(sleepHoleNum), 'matchingContigSizes') == 1
                    totalSleepSpellCount = totalSleepSpellCount + size(probScatter(IIDN).spells(sleepHoleNum).matchingContigSizes,1); %Raw count of spells
                end
            end
            totalWakeSpellCount = totalSpellCount - totalSleepSpellCount; %Simple math...
            if totalSleepSpellCount > totalSpellCount
                ['## Warning: Potentially aberrant sleep spell count detected']
                error = yes %Technically can happen if a spell extends from the end of one sleep bout, across the intervening wake and into the next sleep bout
            end
            
            %Normalise total counts by durations
            totalSleepSpellCountNorm = totalSleepSpellCount / totalSleepTimeMins;
            totalWakeSpellCountNorm = totalWakeSpellCount / totalWakeTimeMins;
            
            plotData(IIDN,1) = totalSleepSpellCountNorm;
            plotData(IIDN,2) = totalWakeSpellCountNorm;
        end
        
        meanData = [];
        semData = [];
        
        
        if size(plotData,1) > 1
            meanData = nanmean(plotData,1);
            semData = nanstd(plotData,1) / sqrt( size(plotData,1) );
        else
            meanData = plotData;
            semData(1,1:2) = [0,0];
        end
        
        barwitherr(semData,meanData)
        
        for IIDN = 1:size(overVar,2)
            hold on
            scatter( [1:2] , plotData(IIDN,:), [], colourz(IIDN,:))
            line([1,2],[plotData(IIDN,:)], 'Color', colourz(IIDN,:))
        end
        
        xlim([0.5, 2.5])
        ylabel(['Spells/min.'])
        %ylim([0 probInterval])
        if analyseWake == 0
            exTicks = [{'Sleep'},{'Wake'}];
        else
            exTicks = [{'Wake'},{'Sleep'}];
        end
        ax = gca;
        ax.XTickLabel = exTicks;
        figTitle = ['Pooled time-normalised spells'];
        
        %#######
        %Stats
        if size(plotData,1) > 3
            %Normality
            figTitle = [figTitle, ' (Normality: '];
            for i = 1:size(plotData,2)
                [normHdata(i), normPdata(i)] = swtest(plotData(:,i));
                figTitle = [figTitle, exTicks{i}, ' ', num2str(normHdata(i)), ' , '];
            end
            figTitle = [figTitle, '; Test p: '];
            %WSR or Paired T-test
            statTestUsed = '';
            if nansum(normHdata) ~= size(normHdata,2) %"Not all samples normal"
                [statPdata, statHdata] = ranksum(plotData(:,1), plotData(:,2));
                statTestUsed = 'WSR';
            else
                [statHdata, statPdata] = ttest(plotData(:,1), plotData(:,2));
                statTestUsed = 'Paired T-test';
            end
            figTitle = [figTitle, num2str(round(statPdata,4)), ' ; ', statTestUsed , ')'];
        end
        %#######
        
        title(figTitle)
        
        %------------------------------------------------------------------
        
        %Prepare spell hists
        nBins = 40;
        binLimit = 40;
        binCentres = linspace(0,binLimit,nBins); %Needed because otherwise hist bin centres vary slightly depending on how close the largest value/s are to arbitraryTooFarThreshold 
        %[N,X] = hist(locDiffDataTime,binCentres);
        poolNs = [];
        poolXs = [];
        for IIDN = 1:size(overVar,2)
            [poolNs(IIDN,:),poolXs(IIDN,:)] = hist(overAllPE(IIDN).spellStruct.allContigSizes,binCentres);
        end
        
        %Spell size histogram (Individual)
        figure
        %plotData = [];
        xLimList = [];
        yLimList = [];
        for IIDN = 1:size(overVar,2)
            subplot(ceil(size(overVar,2)/4),4,IIDN)
            %hist( overAllPE(IIDN).spellStruct.allContigSizes, 64 )
            hist( overAllPE(IIDN).spellStruct.allContigSizes, binCentres )
            %plotData = [plotData; overAllPE(IIDN).spellStruct.allContigSizes];
            %title(['All spell hist - ',overVar(IIDN).flyName])
            titleStr = ['All spell hist - ',overVar(IIDN).flyName];
            if nanmax( overAllPE(IIDN).spellStruct.allContigSizes ) > binLimit
                titleStr = [titleStr,char(10),' (',num2str(nansum(nanmax( overAllPE(IIDN).spellStruct.allContigSizes )>binLimit)),' elements > X limit [',num2str(binLimit),'])'];
            end
            title(titleStr)
            xlim([0 binLimit])
            xLimList = [xLimList; get(gca,'XLim')];
            yLimList = [yLimList; get(gca,'YLim')];
            xlabel('# of PEs in spell')
            ylabel('Count')
        end
        %Automated X (and Y) lim matching system
            %Currently being overriden by binLimit
        %{
        for i = 1:size(overVar,2)
            subplot(ceil(size(overVar,2)/4),4,i)
            xlim([nanmin(xLimList(:,1)),nanmax(xLimList(:,2))])
            %ylim([nanmin(yLimList(:,1)),nanmax(yLimList(:,2))])
        end
        %}
        
        %Pooled
        figure
        plotData = [];
        
        for IIDN = 1:size(overAllPE,2)
            plotData = [plotData; overAllPE(IIDN).spellStruct.allContigSizes];
            [poolNs(IIDN,:),poolXs(IIDN,:)] = hist(overAllPE(IIDN).spellStruct.allContigSizes,binCentres);
        end
        hist( plotData, 64 )
        title(['Pooled spell size hist'])
        
        %Pooled indivs
            %(Borrowed from pooled inter-PE-interval plot)
        %thisDataMean = overType.(thisPETarget).plotDataMean{i};
        %thisDataSEM = overType.(thisPETarget).plotDataSEM{i};
        thisDataMean = nanmean( poolNs , 1 );
        thisDataSEM = nanstd( poolNs , [], 1 ) ./ sqrt( size(poolNs,1) );
        %h = bar(binCentres,thisDataMean);
        figure
        for barInd = 1:size(binCentres,2)
            xCoords = [ binCentres(barInd)-0.5*(binLimit/(nBins-1)) , binCentres(barInd)-0.5*(binLimit/(nBins-1)), ...
                binCentres(barInd)+0.5*(binLimit/(nBins-1)) , binCentres(barInd)+0.5*(binLimit/(nBins-1)) ];
                %Should place fill in bin centre
            yCoords = [0, thisDataMean(barInd) , thisDataMean(barInd) , 0];
            %h = fill(xCoords,yCoords,colourDictionary{peType});
            h = fill(xCoords,yCoords,'b');
            %set(h,'FaceAlpha',alphaValues(peType));
            hold on
        end
        %set(h,'FaceColor',[0.3,0.3,0.3]);
        %hold on
        for z = 1:size(binCentres,2)
            line([binCentres(z),binCentres(z)],[thisDataMean(z) - thisDataSEM(z),thisDataMean(z) + thisDataSEM(z)], 'Color', 'k')
            %line([binCentres(z),binCentres(z)],[thisDataMean(z) - thisDataSEM(z),thisDataMean(z) + thisDataSEM(z)], 'Color', colourDictionary{peType})
                %BOOTLEG CUSTOM ERROR BARS
        end
        xlim([0 binLimit])
        titleStr = ['All spell size pooled raw (N=',num2str(size(poolNs,1)),')'];
        title(titleStr)
        xlabel('# of PEs in spell')
        ylabel('Count')
        
        %Fractional
        plotData = [];
        for IIDN = 1:size(overAllPE,2)
            plotData(IIDN,:) = poolNs(IIDN,:) ./ nansum( poolNs(IIDN,:) );
        end
        thisDataMean = nanmean( plotData , 1 );
        thisDataSEM = nanstd( plotData , [], 1 ) ./ sqrt( size(plotData,1) );
        figure
        for barInd = 1:size(binCentres,2)
            xCoords = [ binCentres(barInd)-0.5*(binLimit/(nBins-1)) , binCentres(barInd)-0.5*(binLimit/(nBins-1)), ...
                binCentres(barInd)+0.5*(binLimit/(nBins-1)) , binCentres(barInd)+0.5*(binLimit/(nBins-1)) ];
                %Should place fill in bin centre
            yCoords = [0, thisDataMean(barInd) , thisDataMean(barInd) , 0];
            %h = fill(xCoords,yCoords,colourDictionary{peType});
            h = fill(xCoords,yCoords,'b');
            %set(h,'FaceAlpha',alphaValues(peType));
            hold on
        end
        %set(h,'FaceColor',[0.3,0.3,0.3]);
        %hold on
        for z = 1:size(binCentres,2)
            line([binCentres(z),binCentres(z)],[thisDataMean(z) - thisDataSEM(z),thisDataMean(z) + thisDataSEM(z)], 'Color', 'k')
            %line([binCentres(z),binCentres(z)],[thisDataMean(z) - thisDataSEM(z),thisDataMean(z) + thisDataSEM(z)], 'Color', colourDictionary{peType})
                %BOOTLEG CUSTOM ERROR BARS
        end
        yMax = get(gca,'YLim');
        line( [minRaftSize,minRaftSize] , [0,nanmax(yMax)], 'LineStyle', ':', 'Color', 'k' )
        xlim([0 binLimit])
        titleStr = ['All spell size pooled fractional (N=',num2str(size(plotData,1)),')'];
        titleStr = [titleStr, '(Min. spell size: ', num2str(minRaftSize),'PEs ; Max. PE gap: ',num2str(contiguityThreshold*probInterval),'s )'];
        title(titleStr)
        xlabel('# of PEs in spell')
        ylabel('Fraction of all spells')
        
        %------------------------------------------------------------------
        
        %Grouped pooled avg. PEs min
        %figure
        
        plotData = []; %For un-separated data
        sepPlotData = []; %For data separated into sleep and wake
        normSepPlotData = [];
        exLabels = [];
        groupModulus = floor(size(sleepCurveZT,2)/groupFactor);
        for groupInd = 1:groupFactor 
            groupZTs = sleepCurveZT( (groupInd - 1) * groupModulus + 1 : groupInd*groupModulus ); %Raw ZT times that will be captured
            groupPost5PMStartEnd = [ ((groupInd - 1) * groupModulus)*60*60 , (groupInd*groupModulus - 1)*60*60]; %Above ZTs, converted to seconds post lowest sleepCurveZT (normally 5PM)
                %i.e. "[ ((1-1)*6)*mins. in an hour*seconds in a min. : etc];
            
            for IIDN = 1:size(overVar,2)
                tempData = [];
                tempCount = 0;
                
                sleepCount = 0; %Consider these children of tempCount
                wakeCount = 0;
                
                timeDiff = [0; diff(overAllPE(IIDN).allPEStruct.allPERail(:,1))];
                                
                for peInd = 1:size(overAllPE(IIDN).allPEStruct.allLOCS,1)
                    thisPEPos = overAllPE(IIDN).allPEStruct.allLOCS(peInd);
                    thisPEPost5PMTime = overAllPE(IIDN).allPEStruct.allPERail(thisPEPos,7);
                    
                    if thisPEPost5PMTime >= groupPost5PMStartEnd(1) && thisPEPost5PMTime <= groupPost5PMStartEnd(2)
                        tempData = [tempData; thisPEPos ];
                        tempCount = tempCount + 1; %Count of PEs from this file that were within the selected time group

                        %Separate by sleep and wake
                        if isnan(overAllPE(IIDN).allPEStruct.allPERail(thisPEPos,3)) ~= 1 %"Sleep"
                            sleepCount = sleepCount + 1;
                        else
                            wakeCount = wakeCount + 1;
                        end
                            %Note: Technically vulnerable to odd state specifiers/bugs in allPERail
                    end 
                end
                
                sleepInds = overAllPE(IIDN).allPEStruct.allPERail(:,7) >= groupPost5PMStartEnd(1) & overAllPE(IIDN).allPEStruct.allPERail(:,7) <= groupPost5PMStartEnd(2) & isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1;
                    %"Find all points that are within the specified time range AND are sleep bouts"
                tempSleepTime = nansum( timeDiff( sleepInds  )  );
                normSleepCount = (sleepCount / tempSleepTime)*60; %Turns sleepCount into a value of PEs / min
                wakeInds = overAllPE(IIDN).allPEStruct.allPERail(:,7) >= groupPost5PMStartEnd(1) & overAllPE(IIDN).allPEStruct.allPERail(:,7) <= groupPost5PMStartEnd(2) & overAllPE(IIDN).allPEStruct.allPERail(:,5) == -1;
                tempWakeTime = nansum( timeDiff( wakeInds  )  );
                normWakeCount = (wakeCount / tempWakeTime)*60; %Turns wakeCount into a value of PEs/min
            
                %QA
                if tempCount ~= (sleepCount+wakeCount)
                    ['## ALERT: CRITICAL FAILURE IN CORRECT SEPARATION OF PES ##']
                    error = yes
                end
                
                plotData(IIDN,groupInd) = tempCount;
                
                sepPlotData{1}(IIDN,groupInd) = sleepCount;
                sepPlotData{2}(IIDN,groupInd) = wakeCount;
                
                normSepPlotData{1}(IIDN,groupInd) = normSleepCount;
                normSepPlotData{2}(IIDN,groupInd) = normWakeCount;
                
            end
            
            exLabels{groupInd} = [];
            for GM = 1:groupModulus
                exLabels{groupInd} = [exLabels{groupInd}, groupZTs{GM}, ', '];
            end
        end
        
        
        %*******
        %Pooled, unseparated raw counts
        figure
        
        %Calculate mean, SEM
        meanData = [];
        semData = [];
        if size(overVar,2) > 1
            meanData = nanmean(plotData);
            semData = nanstd(plotData) / sqrt( size(plotData,1) ); %Note: No anti-NaN here 
        else
            meanData = plotData;
            semData = zeros(1,groupFactor);
        end
        
        %Plot
        h = barwitherr(semData,meanData);
        set(h,'FaceColor','g');
        
        %Scatter
        for IIDN = 1:size(overVar,2)
            hold on
            scatter( [1:groupFactor] , plotData(IIDN,:), [], colourz(IIDN,:))
            line([1:groupFactor],[plotData(IIDN,:)], 'Color', colourz(IIDN,:))
        end
        
        %Axes, etc
        xlim([0.5, groupFactor+0.5])
        ylabel(['Raw PE counts'])
        xlabel(['Time (24h)'])
            %Note: If sleepCurveZT values discontinuous, this will be a lie
        %ylim([0 probInterval])
        ax = gca;
        ax.XTickLabel = exLabels;
        figTitle = ['Pooled raw PE counts split by time group'];
        title(figTitle)
        %*******
        
        %*******
        %Pooled, separated raw counts
        figure
        
        %Calculate mean, SEM
        sepMeanData = [];
        sepSemData = [];
        for sepInd = 1:size(sepPlotData,2)
            sepMeanData{sepInd} = [];
            sepSemData{sepInd} = [];
            if size(overVar,2) > 1
                sepMeanData{sepInd} = nanmean(sepPlotData{sepInd});
                sepSemData{sepInd} = nanstd(sepPlotData{sepInd}) / sqrt( size(sepPlotData{sepInd},1) ); %Note: No anti-NaN here 
            else
                sepMeanData{sepInd} = sepPlotData{sepInd};
                sepSemData{sepInd} = zeros(1,groupFactor);
            end

            %Plot
            %posMod =  (1 / size(sepPlotData,2)) + ( (sepInd-1) * (1) ) ; %Position modifier for barplot
            if sepInd == 1
                %barXPos = [1:3]-0.1; %Hardcoded because CBF
                barXPos = [1:size(sepMeanData{sepInd},2)]-0.1; %Hardcoded because CBF
            else
                barXPos = [1:size(sepMeanData{sepInd},2)]+0.1;
            end
            for barInd = 1:size(sepMeanData{sepInd},2)
                %h = barwitherr(sepSemData{sepInd}(barInd),barXPos(barInd),sepMeanData{sepInd}(barInd), 0.25);
                h = bar(barXPos(barInd),sepMeanData{sepInd}(barInd), 0.25);
                line([barXPos(barInd),barXPos(barInd)],[sepMeanData{sepInd}(barInd) - sepSemData{sepInd}(barInd),sepMeanData{sepInd}(barInd) + sepSemData{sepInd}(barInd)], 'Color', 'k')
                        %BOOTLEG CUSTOM ERROR BARS
                hold on
                if sepInd == 1 %"Sleep"
                    set(h,'FaceColor','b');
                else %"Wake"
                    set(h,'FaceColor','y');
                end
            end


            %Scatter
            for IIDN = 1:size(overVar,2)
                hold on
                scatter( barXPos , sepPlotData{sepInd}(IIDN,:), [], colourz(IIDN,:))
                line(barXPos,[sepPlotData{sepInd}(IIDN,:)], 'Color', colourz(IIDN,:))
            end

        end
        
        %Axes, etc
        %xlim([0.5, groupFactor+0.5])
        ylabel(['Raw PE counts'])
        xlabel(['Time (24h)'])
            %Note: If sleepCurveZT values discontinuous, this will be a lie
        %ylim([0 probInterval])
        ax = gca;
        ax.XTick = [1:groupFactor];
        ax.XTickLabel = exLabels;
        figTitle = ['Pooled raw PE counts split by time group, separated by sleep/wake'];
        title(figTitle)
        %*******
        
        %*******
        %Pooled, separated normalised PEs / <time span>
        figure
        
        %Calculate mean, SEM
        normSepMeanData = [];
        normSepSemData = [];
        for sepInd = 1:size(normSepPlotData,2)
            normSepMeanData{sepInd} = [];
            normSepSemData{sepInd} = [];
            if size(overVar,2) > 1
                normSepMeanData{sepInd} = nanmean(normSepPlotData{sepInd});
                normSepSemData{sepInd} = nanstd(normSepPlotData{sepInd}) / sqrt( size(normSepPlotData{sepInd},1) ); %Note: No anti-NaN here 
            else
                normSepMeanData{sepInd} = normSepPlotData{sepInd};
                normSepSemData{sepInd} = zeros(1,groupFactor);
            end

            %Plot
            %posMod =  (1 / size(sepPlotData,2)) + ( (sepInd-1) * (1) ) ; %Position modifier for barplot
            if sepInd == 1
                %barXPos = [1:3]-0.1; %Hardcoded because CBF
                barXPos = [1:size(sepMeanData{sepInd},2)]-0.1; %Hardcoded because CBF
            else
                barXPos = [1:size(sepMeanData{sepInd},2)]+0.1;
            end
            for barInd = 1:size(normSepMeanData{sepInd},2)
                %g = barwitherr(normSepSemData{sepInd}(barInd),normSepMeanData{sepInd}(barInd),normSepMeanData{sepInd}(barInd), 0.25);
                h = bar(barXPos(barInd),normSepMeanData{sepInd}(barInd), 0.25);
                hold on
                line([barXPos(barInd),barXPos(barInd)],[normSepMeanData{sepInd}(barInd) - normSepSemData{sepInd}(barInd),normSepMeanData{sepInd}(barInd) + normSepSemData{sepInd}(barInd)], 'Color', 'k')
                        %BOOTLEG CUSTOM ERROR BARS
                if sepInd == 1 %"Sleep"
                    set(h,'FaceColor','b');
                else %"Wake"
                    set(h,'FaceColor','y');
                end
            end

            %{
            %Scatter
            for IIDN = 1:size(overVar,2)
                hold on
                scatter( barXPos , sepPlotData{sepInd}(IIDN,:), [], colourz(IIDN,:))
                line(barXPos,[sepPlotData{sepInd}(IIDN,:)], 'Color', colourz(IIDN,:))
            end
            %}
        end
        
        %Axes, etc
        %xlim([0.5, groupFactor+0.5])
        ylabel(['PEs/min'])
        xlabel(['Time (24h)'])
            %Note: If sleepCurveZT values discontinuous, this will be a lie
        %ylim([0 probInterval])
        ax = gca;
        ax.XTick = [1:groupFactor];
        ax.XTickLabel = exLabels;
        figTitle = ['Pooled normalised PE counts split by time group, separated by sleep/wake'];
        title(figTitle)
        %*******
                        
        %------------------------------------------------------------------
        
        %Pooled normalised spell durations during sleep vs wake
        figure
        
        plotData = [];
        for IIDN = 1:size(overVar,2)
            
            %Calculate total time within bouts (i.e. Sleeping)
            PERailTimes = overAllPE(IIDN).allPEStruct.allPERail(:,1);
            PERailTimesDiff = []; %Not sure if necessary but too scared to not have in place
            PERailTimesDiff = [0; diff(PERailTimes)];
            totalSleepTimeMins = ( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1 ) ) / 60); %Note: Column reference hardcoded
            totalWakeTimeMins = ( nansum( PERailTimesDiff( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,5)) ~= 1 ) ) / 60);
            
            %Calculate number of spells that occurred with-in and with-out holes
                %Note: Spells that span both wake and sleep will probably be double-counted here maybe?
            totalSpellDuration = 0; %Technically this is done a better way above but the symmetry is nice
            for contigInd = 1:size(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute,1)
                totalSpellDuration = totalSpellDuration + ...
                    ( overAllPE(IIDN).allPEStruct.allPERail(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,2),1) - ...
                    overAllPE(IIDN).allPEStruct.allPERail(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(contigInd,1),1) ); %Total spell duration in seconds
            end
            totalSleepSpellDuration = 0;
            for sleepHoleNum = 1:size(probScatter(IIDN).spells,2)
                if isfield(probScatter(IIDN).spells(sleepHoleNum), 'matchingContigSizes') == 1
                    for contigInd = 1:size(probScatter(IIDN).spells(sleepHoleNum).matchingContigStartEndAbsolute,1)
                        totalSleepSpellDuration = totalSleepSpellDuration + ...
                            ( overAllPE(IIDN).allPEStruct.allPERail(probScatter(IIDN).spells(sleepHoleNum).matchingContigStartEndAbsolute{contigInd}(2)) - ...
                            overAllPE(IIDN).allPEStruct.allPERail(probScatter(IIDN).spells(sleepHoleNum).matchingContigStartEndAbsolute{contigInd}(1)) ); %Total spell duration in seconds
                    end
                end
            end
            totalWakeSpellDuration = totalSpellDuration - totalSleepSpellDuration; %Simple math...           
            
            %Normalise total counts by durations
            totalSleepSpellDurationNorm = totalSleepSpellDuration / totalSleepTimeMins;
            totalWakeSpellDurationNorm = totalWakeSpellDuration / totalWakeTimeMins;
            
            plotData(IIDN,1) = totalSleepSpellDurationNorm;
            plotData(IIDN,2) = totalWakeSpellDurationNorm;
        end
        
        meanData = [];
        semData = [];
        
        if size(plotData,1) > 1
            meanData = nanmean(plotData,1);
            semData = nanstd(plotData,1) / sqrt( size(plotData,1) );
        else
            meanData = plotData;
            semData(1,1:2) = [0,0];
        end
        
        barwitherr(semData,meanData)
        
        for IIDN = 1:size(overVar,2)
            hold on
            scatter( [1:2] , plotData(IIDN,:), [], colourz(IIDN,:))
            line([1,2],[plotData(IIDN,:)], 'Color', colourz(IIDN,:))
        end
        
        xlim([0.5, 2.5])
        ylabel(['Normalised spell duration'])
        %ylim([0 probInterval])
        if analyseWake == 0
            exTicks = [{'Sleep'},{'Wake'}];
        else
            exTicks = [{'Wake'},{'Sleep'}];
        end
        ax = gca;
        ax.XTickLabel = exTicks;
        figTitle = ['Pooled time-normalised spell duration (sec./min.)'];
        
        %#######
        %Stats
        if size(plotData,1) > 3
            %Normality
            figTitle = [figTitle, ' (Normality: '];
            for i = 1:size(plotData,2)
                [normHdata(i), normPdata(i)] = swtest(plotData(:,i));
                figTitle = [figTitle, exTicks{i}, ' ', num2str(normHdata(i)), ' , '];
            end
            figTitle = [figTitle, '; Test p: '];
            %WSR or Paired T-test
            statTestUsed = '';
            if nansum(normHdata) ~= size(normHdata,2) %"Not all samples normal"
                [statPdata, statHdata] = ranksum(plotData(:,1), plotData(:,2));
                statTestUsed = 'WSR';
            else
                [statHdata, statPdata] = ttest(plotData(:,1), plotData(:,2));
                statTestUsed = 'Paired T-test';
            end
            figTitle = [figTitle, num2str(round(statPdata,4)), ' ; ', statTestUsed , ')'];
        end
        %#######
        figTitle = [figTitle, '(Min. size:', num2str(minRaftSize), ')'];
        
        title(figTitle)
        
        %------------------------------------------------------------------
                
        
        %Pooled rolling PEs/min.
        figure
        
        yDataRail = []; %This rail will hold rollPEY data at indices denoted by xTimesRel
        yDataRail = zeros( size(overVar,2), 24*60*60 ); %Make rail 24h in length (easier than trying to find the longest dataset ahead of time tbh)
            %Again, note that the index scale here is seconds, *not* frames
        yDataRail( yDataRail == 0 ) = NaN;
        
        for IIDN = 1:size(overVar,2)

            %@@@@@@@@@@@@@@@@@@
             
            firstNonNaNMovFrameInd = find(isnan(overAllPE(IIDN).allPEStruct.allPERail(:,1)) ~= 1,1,'First');
            firstMovFrameTime = datestr(datetime(overAllPE(IIDN).allPEStruct.allPERail(firstNonNaNMovFrameInd,1), 'ConvertFrom', 'posixtime')); %Find datetime of first mov frame

            ZTarget = num2str(sleepCurveZTNums(1));
            ZTargetNum = str2num(ZTarget);

            timeToFind = firstMovFrameTime; %Stage 1

            timeToFind(end-7:end) = '00:00:00'; %Zero out HMS
            timeToFind(end-7:end-8+size(ZTarget,2)) = ZTarget; %Set HMS to target ZT

            timeToFindPosix = posixtime(datetime(timeToFind,'Format', 'dd-MM-yyyy HH:mm:ss')); %Takes the manually assembled target ZT and converts it to a posix
            
            %@@@@@@@@@@@@@@@@@@@@@@@     

            
            %yData = overAllPE(IIDN).plots.rollPEs.plotDataY;
            yData = overAllPE(IIDN).allPEStruct.rollPEY;
            
            %xData = overAllPE(IIDN).plots.rollPEs.plotDataX;
            xData = overAllPE(IIDN).allPEStruct.rollPEX;
            
            %yData( xData > size( overAllPE(IIDN).allPEStruct.allPERail,1 ) ) = []; %Necessary due to imprecise auto-generated X positions
            %xData( xData > size( overAllPE(IIDN).allPEStruct.allPERail,1 ) ) = []; %Necessary due to imprecise auto-generated X positions
            xPosixTimes = overAllPE(IIDN).allPEStruct.allPERail(xData,1);
            xPosixTimesRel = xPosixTimes - timeToFindPosix;           

            plot(xPosixTimesRel,yData, 'Color', colourz(IIDN,:))
            hold on
            
            %Save data for later binning
            railXPosixTimesRel = round( xPosixTimesRel( xPosixTimesRel > 0 ), 0 ); %Remove non-zero components (i.e. timepoints before 5PM) and round to integer
            railYData = yData( xPosixTimesRel > 0 );
            yDataRail(IIDN, railXPosixTimesRel) = railYData;
            
            
            %Plot raft coords
            if isempty(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute) ~= 1
                hold on
                for raftInd = 1:size(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute,1)
                    %xData = [repmat( overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,1) ,1,2), repmat( overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,2) ,1,2)];
                    xShadeData = [repmat( overAllPE(IIDN).allPEStruct.allPERail(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,1)) - timeToFindPosix ,1,2),...
                        repmat( overAllPE(IIDN).allPEStruct.allPERail(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,2)) - timeToFindPosix ,1,2)];
                    %{
                    [~, closestBottomInd] = min(abs(xPosixTimesRel-nanmin(xShadeData)')); %Find closest xPosixTimesRel to start of shading
                    [~, closestTopInd] = min(abs(xPosixTimesRel-nanmax(xShadeData)')); %Find closest xPosixTimesRel to start of shading
                    %QA
                    if closestBottomInd > size(railYData,2)
                        closestBottomInd = size(railYData,2);
                    end
                    if closestTopInd > size(railYData,2)
                        closestTopInd = size(railYData,2);
                    end
                    maxRailY = nanmax( railYData( closestBottomInd:closestTopInd ) );
                    %}
                    maxRailY = 25; %Hardcoded, arbitrary
                    yShadeData = [0,maxRailY, maxRailY, 0]; %Make shading be the height of the yData at shading coords
                    %yData = [0,nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, 0, 0];
                    fill(xShadeData, yShadeData, colourz(IIDN,:), 'LineStyle', 'none') %Error shading
                    alpha(0.3)

                    text( nanmean([overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(raftInd,1:2)]) , ...
                        probInterval*0.85, num2str(raftInd), 'Color', 'c');
                end
            end
            

        %IIDN end
        end
        
        ylabel(['Average PEs/min.'])
        xlabel(['Time (ZT)'])
        ax = gca;
        numHours = size(sleepCurveZT,2)-1;
        exTicks = [0:60*60:numHours*60*60];
        ax.XTick = exTicks;
        exTickLabels = [];
        for label = 1:numHours+1
            exTickLabels{label} = sleepCurveZT{label};
        end
        ax.XTickLabel = exTickLabels;
        xlim([0 numHours*60*60])
        
        %------
        %Calculate and plot binned average
        binXCoords = [];
        binXData = [];
        binYData = [];
        
        meanData = [];
        semData = [];

        for i = 1:size(sleepCurveZT,2)
            binXCoords = [(i-1)*(60*60)+1 : i*(60*60)]; %Bin in 1hr chunks (Hardcoded)
                %Note: Indexes are seconds from 5PM, not frames
            %binYData = 
            tempY = [];
            for IIDN = 1:size(overVar,2)
                tempY(IIDN,1) = nanmean( yDataRail(IIDN,binXCoords) );
            end
            binXData(i) = nanmean(binXCoords); %Should theoretically be middle of the hour
            binYData(:,i) = tempY;
            
            meanData(i) = nanmean(tempY);
            medianData(i) = nanmedian(tempY);
            semData(i) = nanstd( tempY ) / sqrt( nansum( isnan(tempY) ~= 1 ) );
        end
        
        %Plot mean
        line(binXData,meanData, 'Color', 'k')
        %Calculate shading
        %shadeCoordsX = [1:1:size(meanData,2),size(meanData,2):-1:1];
        shadeCoordsX = [binXData,flip(binXData)];
        shadeCoordsY = [meanData+semData,flip(meanData-semData)];
        fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
        alpha(0.25)
        
        %------
        
        figTitle = ['Pooled rolling PEs/min.'];
        title(figTitle)
        
        %------------------------------------------------------------------

        %Cumulative sum plots
                
        %PEs over time cusu
        figure
        
        CSDataRail = []; %This rail will hold PE data at indices denoted by xTimesRel
        CSDataRail = nan( size(overVar,2), 24*60*60 ); %Make rail 24h in length (easier than trying to find the longest dataset ahead of time tbh)
            %Again, note that the index scale here is seconds, *not* frames
        %CSDataRail( CSDataRail == 0 ) = NaN;
        plotDataRail = CSDataRail;
        
        subCols = [4,6];
        subStyles = [{'- -'},{':'}]; %Must match or be longer than subCols
        subColours = [{'b'},{'y'}];
        for i = 1:size(subCols,2)
            subDataRail{i} = CSDataRail;
            subPlotRail{i} = CSDataRail;
            subMeanData{i} = [];
            subSEMData{i} = [];
        end
        %sleepDataRail = CSDataRail; wakeDataRail = CSDataRail; %Ditto, but for sleep and wake PEs separated
        %sleepPlotRail = CSDataRail; wakePlotRail = CSDataRail;
        
        for IIDN = 1:size(overVar,2)
            
            isPE = overAllPE(IIDN).allPEStruct.allPERail(:,2) == 1;
            isPERelTimes = floor( overAllPE(IIDN).allPEStruct.allPERail( isPE, 7) );
            isPERelTimes( isPERelTimes < 1) = []; %Remove negative components (i.e. Before 5PM components)
            CSDataRail(IIDN,isPERelTimes) = 1;
                %This puts PEs within the common 24h ZT framework

            %Separate sleep and wake PEs
            %{
            isSleepPETimes = floor( overAllPE(IIDN).allPEStruct.allPERail( find(overAllPE(IIDN).allPEStruct.allPERail(:,4) == 1), 7) );
            isWakePETimes = floor( overAllPE(IIDN).allPEStruct.allPERail( find(overAllPE(IIDN).allPEStruct.allPERail(:,6) == 1), 7) );
                %"Find time post-5PM for all occurences of PE in sleep and wake columns of allPERail, respectively"
            isSleepPETimes( isSleepPETimes < 0 ) = []; isWakePETimes( isWakePETimes < 0 ) = [];
            sleepDataRail(IIDN,isSleepPETimes) = 1; wakeDataRail(IIDN,isWakePETimes) = 1;
            %}

            for i = 1:size(subCols,2)
                isSubPETimes = floor( overAllPE(IIDN).allPEStruct.allPERail( find(overAllPE(IIDN).allPEStruct.allPERail(:,subCols(i)) == 1), 7) );
                    %"Find time post-5PM for all occurences of PE in specified column of allPERail"
                isSubPETimes(isSubPETimes < 0) = [];
                subDataRail{i}(IIDN,isSubPETimes) = 1;
            end

            %Plot CS of PEs for this dataset
            tempData = CSDataRail(IIDN,:);
            tempData( isnan(tempData) == 1 ) = 0;
            thisPECSData = cumsum(tempData) / nansum(tempData); %Make cumulative distribution, rather than sum
            plot(thisPECSData, 'Color', colourz(IIDN,:))
            hold on

            %Add on sleep/wake
            %{
            tempSleepData = sleepDataRail(IIDN,:); tempWakeData = wakeDataRail(IIDN,:);
            tempSleepData( isnan(tempSleepData) == 1) = 0; tempWakeData( isnan(tempWakeData) == 1) = 0;
            thisPESleepCSData = cumsum(tempSleepData) / nansum(tempSleepData); thisPEWakeCSData = cumsum(tempWakeData) / nansum(tempWakeData);
            plot(thisPESleepCSData, 'Color', colourz(IIDN,:), 'LineStyle', '- -'); plot(thisPEWakeCSData, 'Color', colourz(IIDN,:), 'LineStyle', ':');
            %}

            for i = 1:size(subCols,2)
                tempSubData = subDataRail{i}(IIDN,:);
                tempSubData( isnan(tempSubData) == 1) = 0;
                thisPESubCSData = cumsum(tempSubData) / nansum(tempSubData);
                plot(thisPESubCSData, 'Color', colourz(IIDN,:), 'LineStyle', subStyles{i});
                
                subPlotRail{i}(IIDN,:) = thisPESubCSData;
            end

            plotDataRail(IIDN,:) = thisPECSData; %Post-hoc saving of proportionalised cumulative sum
                       
        end
        
        %Calculate mean/SEM
        if size(overVar,2) > 1
            meanData = nanmean(plotDataRail);
            semData = nanstd( plotDataRail ) / sqrt( size(plotDataRail,1) );
        else
            meanData = plotDataRail;
            semData = zeros( 1, size(plotDataRail,2) );
        end
        %%plot(meanData, 'k')
        %And for sleep/wake
        for i = 1:size(subCols,2)
            if size(overVar,2) > 1
                subMeanData{i} = nanmean(subPlotRail{i});
                subSEMData{i} = nanstd( subPlotRail{i} ) / sqrt( size(subPlotRail{i},1) );
            else
                subMeanData{i} = subPlotRail{i};
                subSEMData{i} = zeros( 1, size(subPlotRail{i},2) );
            end
        end
                
        ylabel(['Cumulative distribution of PEs'])
        xlabel(['Time (24h)'])
        ax = gca;
        numHours = size(sleepCurveZT,2)-1;
        exTicks = [0:60*60:numHours*60*60];
        ax.XTick = exTicks;
        exTickLabels = [];
        for label = 1:numHours+1
            exTickLabels{label} = sleepCurveZT{label};
        end
        ax.XTickLabel = exTickLabels;
        xlim([0 numHours*60*60])
        figTitle = ['Pooled cumulative dist. of PEs over time'];
        title(figTitle)
        
        %****
        %Calculate smoothed mean
        %Calculate less line-heavy mean
        cutdownXData = find(diff(meanData) ~= 0); %Find only the times when the mean changed
            %Note: This technique probably only works for permanently increasing plots like cumulative dists.
        cutdownMeanData = meanData(cutdownXData);
        cutdownSEMData = semData(cutdownXData);
        smoothedCutdownXData = [];
        smoothedCutdownMeanData = [];
        smoothedCutdownSEMData = [];
        for xInd = 1:size(exTicks,2) - 1
            smoothedCutdownXData = [smoothedCutdownXData, nanmean( cutdownXData( cutdownXData > exTicks(xInd) & cutdownXData < exTicks(xInd+1) ) ) ];
            smoothedCutdownMeanData = [smoothedCutdownMeanData, nanmean( cutdownMeanData( cutdownXData > exTicks(xInd) & cutdownXData < exTicks(xInd+1) ) ) ];
            smoothedCutdownSEMData = [smoothedCutdownSEMData, nanmean( cutdownSEMData( cutdownXData > exTicks(xInd) & cutdownXData < exTicks(xInd+1) ) ) ];
        end
        plot(smoothedCutdownXData, smoothedCutdownMeanData, 'k')
        if size(overVar,2) > 1
            %Calculate shading
            shadeCoordsX = [smoothedCutdownXData,flip(smoothedCutdownXData)];
            shadeCoordsY = [smoothedCutdownMeanData+smoothedCutdownSEMData,flip(smoothedCutdownMeanData-smoothedCutdownSEMData)];
            fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
            alpha(0.25)
        end
        %And for sleep/wake
        for i = 1:size(subCols,2)
            cutdownXDataSub = find(diff(subMeanData{i}) ~= 0); %Find only the times when the mean changed
            cutdownMeanDataSub = subMeanData{i}(cutdownXDataSub);
            cutdownSEMDataSub = subSEMData{i}(cutdownXDataSub);
            smoothedCutdownXDataSub = [];
            smoothedCutdownMeanDataSub = [];
            smoothedCutdownSEMDataSub = [];
            for xInd = 1:size(exTicks,2) - 1
                smoothedCutdownXDataSub = [smoothedCutdownXDataSub, nanmean( cutdownXDataSub( cutdownXDataSub > exTicks(xInd) & cutdownXDataSub < exTicks(xInd+1) ) ) ];
                smoothedCutdownMeanDataSub = [smoothedCutdownMeanDataSub, nanmean( cutdownMeanDataSub( cutdownXDataSub > exTicks(xInd) & cutdownXDataSub < exTicks(xInd+1) ) ) ];
                smoothedCutdownSEMDataSub = [smoothedCutdownSEMDataSub, nanmean( cutdownSEMDataSub( cutdownXDataSub > exTicks(xInd) & cutdownXDataSub < exTicks(xInd+1) ) ) ];
            end
            plot(smoothedCutdownXDataSub, smoothedCutdownMeanDataSub, 'k')
            if size(overVar,2) > 1
                %Calculate shading
                shadeCoordsXSub = [smoothedCutdownXDataSub,flip(smoothedCutdownXDataSub)];
                shadeCoordsYSub = [smoothedCutdownMeanDataSub+smoothedCutdownSEMDataSub,flip(smoothedCutdownMeanDataSub-smoothedCutdownSEMDataSub)];
                fill(shadeCoordsXSub, shadeCoordsYSub,subColours{i}) %Error shading
                alpha(0.15)
            end
        end
        %****
        
        %------------------------------------------------------------------

        %Sleep bouts CuSu
        figure
        
        sleepDataRail = [];
        sleepDataRail = nan( size(overVar,2), 24*60*60 );
        sleepCSRail = sleepDataRail;
        
        for IIDN = 1:size(overVar,2)
            isSleep = overVar(IIDN).railStruct.sleepRail(:,1) == 1; %Times when this individual was sleeping, according to the rail
            %isSleepRelTimes = floor( overVar(IIDN).railStruct.sleepRail( isSleep, size( overVar(IIDN).railStruct.sleepRail ,2 ) ) ); %Old sleepRail coordinate specification; Points to wrong column
            isSleepRelTimes = floor( overVar(IIDN).railStruct.sleepRail( isSleep, size( overVar(IIDN).railStruct.sleepRail ,2 )-1 ) ); %New specification; Correctly(?) points to Time Post 5PM
            isSleepRelTimes( isSleepRelTimes < 1) = [];
            isSleepRelTimes( isnan(isSleepRelTimes) == 1) = [];
            isSleepRelTimes = unique(isSleepRelTimes);
            sleepDataRail(IIDN,isSleepRelTimes) = 1;
            
            %Plot
            tempData = sleepDataRail(IIDN,:);
            tempData( isnan(tempData) == 1 ) = 0;
            thisSleepCSData = cumsum(tempData) / nansum(tempData); %Make cumulative distribution, rather than sum
            %%plot(thisSleepCSData, 'Color', colourz(IIDN,:))
            hold on
            
            sleepCSRail(IIDN,:) = thisSleepCSData; %Post-hoc saving of proportionalised cumulative sum
            
        end
        
        %Calculate mean/SEM
        if size(overVar,2) > 1
            meanData = nanmean(sleepCSRail);
            semData = nanstd( sleepCSRail ) / sqrt( size(sleepCSRail,1) );
        else
            meanData = sleepCSRail;
            semData = zeros( 1, size(sleepCSRail,2) );
        end
        plot(meanData, 'LineWidth', 2, 'Color', 'k')
        %And for sleep/wake
        %{
        for i = 1:size(subCols,2)
            if size(overVar,2) > 1
                subMeanData{i} = nanmean(subPlotRail{i});
                subSEMData{i} = nanstd( subPlotRail{i} ) / sqrt( size(subPlotRail{i},1) );
            else
                subMeanData{i} = subPlotRail{i};
                subSEMData{i} = zeros( 1, size(subPlotRail{i},2) );
            end
        end
        %}
                        
        ylabel(['Cumulative distribution of sleep bouts'])
        xlabel(['Time (24h)'])
        ax = gca;
        numHours = size(sleepCurveZT,2)-1;
        exTicks = [0:60*60:numHours*60*60];
        ax.XTick = exTicks;
        exTickLabels = [];
        for label = 1:numHours+1
            exTickLabels{label} = sleepCurveZT{label};
        end
        ax.XTickLabel = exTickLabels;
        xlim([0 numHours*60*60])
        figTitle = ['Pooled cumulative dist. of sleep bouts over time'];
        title(figTitle)
        
        %Shading etc
        %Calculate smoothed mean
        %Calculate less line-heavy mean
        cutdownXData = find(diff(meanData) ~= 0); %Find only the times when the mean changed
            %Note: This technique probably only works for permanently increasing plots like cumulative dists.
        cutdownMeanData = meanData(cutdownXData);
        cutdownSEMData = semData(cutdownXData);
        smoothedCutdownXData = [];
        smoothedCutdownMeanData = [];
        smoothedCutdownSEMData = [];
        for xInd = 1:size(exTicks,2) - 1
            smoothedCutdownXData = [smoothedCutdownXData, nanmean( cutdownXData( cutdownXData > exTicks(xInd) & cutdownXData < exTicks(xInd+1) ) ) ];
            smoothedCutdownMeanData = [smoothedCutdownMeanData, nanmean( cutdownMeanData( cutdownXData > exTicks(xInd) & cutdownXData < exTicks(xInd+1) ) ) ];
            smoothedCutdownSEMData = [smoothedCutdownSEMData, nanmean( cutdownSEMData( cutdownXData > exTicks(xInd) & cutdownXData < exTicks(xInd+1) ) ) ];
        end
        plot(smoothedCutdownXData, smoothedCutdownMeanData, 'k')
        if size(overVar,2) > 1
            %Calculate shading
            shadeCoordsX = [smoothedCutdownXData,flip(smoothedCutdownXData)];
            shadeCoordsY = [smoothedCutdownMeanData+smoothedCutdownSEMData,flip(smoothedCutdownMeanData-smoothedCutdownSEMData)];
            fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
            alpha(0.15)
        end
        
        
        %------------------------------------------------------------------

        %Pooled cumulative dist. plot for spells 
        
        figure
        
        CSDataRail = []; %This rail will hold PE data at indices denoted by xTimesRel
        CSDataRail = zeros( size(overVar,2), 24*60*60 ); %Make rail 24h in length (easier than trying to find the longest dataset ahead of time tbh)
            %Again, note that the index scale here is seconds, *not* frames
        CSDataRail( CSDataRail == 0 ) = NaN;
        plotDataRail = CSDataRail;
        
        for IIDN = 1:size(overVar,2)
            if isempty(overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute) ~= 1
                isSpell = overAllPE(IIDN).spellStruct.matchingContigStartEndAbsolute(:,1); %List of starting indices of spells
                isSpellRelTimes = floor( overAllPE(IIDN).allPEStruct.allPERail( isSpell, 7) );
                isSpellRelTimes( isSpellRelTimes < 1) = []; %Remove negative components (i.e. Before 5PM components)
                CSDataRail(IIDN,isSpellRelTimes) = 1;
                    %This puts spells within the common 24h ZT framework
            end
            
           %Plot CS of PEs for this dataset
           tempData = CSDataRail(IIDN,:);
           tempData( isnan(tempData) == 1 ) = 0;
           thisSpellCSData = cumsum(tempData) / nansum(tempData); %Make cumulative distribution, rather than sum
           plot(thisSpellCSData, 'Color', colourz(IIDN,:))
           hold on
           
           plotDataRail(IIDN,:) = thisSpellCSData; %Post-hoc saving of proportionalised cumulative sum
           
        end
        
        %Calculate and plot mean/SEM
        if size(overVar,2) > 1
            meanData = nanmean(plotDataRail);
            semData = nanstd( plotDataRail ) / sqrt( size(plotDataRail,1) );
        else
            meanData = plotDataRail;
            semData = zeros( 1, size(plotDataRail,2) );
        end
        %{
        plot(meanData, 'k')
        if size(overVar,2) > 1
            %Calculate shading
            shadeCoordsX = [1:1:size(meanData,2),size(meanData,2):-1:1];
            shadeCoordsY = [meanData+0.5*semData,flip(meanData-0.5*semData)];
            fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
            alpha(0.25)
        end
        %}
        
        ylabel(['Cumulative distribution of Spells'])
        xlabel(['Time (ZT)'])
        ax = gca;
        numHours = size(sleepCurveZT,2)-1;
        exTicks = [0:60*60:numHours*60*60];
        ax.XTick = exTicks;
        exTickLabels = [];
        for label = 1:numHours+1
            exTickLabels{label} = sleepCurveZT{label};
        end
        ax.XTickLabel = exTickLabels;
        xlim([0 numHours*60*60])
        figTitle = ['Pooled cumulative dist. of PE spells over time'];
        title(figTitle)
        
        %****
        %Calculate smoothed mean
        %Calculate less line-heavy mean
        cutdownXData = find(diff(meanData) ~= 0); %Find only the times when the mean changed
            %Note: This technique probably only works for permanently increasing plots like cumulative dists.
        cutdownMeanData = meanData(cutdownXData);
        cutdownSEMData = semData(cutdownXData);
        smoothedCutdownXData = [];
        smoothedCutdownMeanData = [];
        smoothedCutdownSEMData = [];
        for xInd = 1:size(exTicks,2)
            if xInd ~= size(exTicks,2)
                lowerEx = exTicks(xInd);
                upperEx = exTicks(xInd+1);
            else
                lowerEx = exTicks(xInd);
                upperEx = Inf;               
            end
            sendX = nanmean( cutdownXData( cutdownXData > lowerEx & cutdownXData < upperEx ) );
            if isnan(sendX) == 1
                if xInd ~= size(exTicks,2)
                    sendX = nanmean([lowerEx, upperEx]);
                else
                    sendX = lowerEx;
                end
                [~, sendInd] = min(abs(cutdownXData-sendX));
                sendMean = cutdownMeanData(sendInd);
                sendSEM = cutdownSEMData(sendInd);
            else
                if xInd ~= size(exTicks,2)
                    sendX = nanmean( cutdownXData( cutdownXData > lowerEx & cutdownXData < upperEx ) );
                    sendMean = nanmean( cutdownMeanData( cutdownXData > lowerEx & cutdownXData < upperEx ) );
                    sendSEM = nanmean( cutdownSEMData( cutdownXData > lowerEx & cutdownXData < upperEx ) );                
                elseif xInd == size(exTicks,2)
                    sendX = lowerEx;
                    sendMean = cutdownMeanData(end);
                    sendSEM = cutdownSEMData(end);
                end
            end
            %smoothedCutdownXData = [smoothedCutdownXData, nanmean( cutdownXData( cutdownXData > lowerEx & cutdownXData < upperEx ) ) ];
            %smoothedCutdownMeanData = [smoothedCutdownMeanData, nanmean( cutdownMeanData( cutdownXData > lowerEx & cutdownXData < upperEx ) ) ];
            %smoothedCutdownSEMData = [smoothedCutdownSEMData, nanmean( cutdownSEMData( cutdownXData > lowerEx & cutdownXData < upperEx ) ) ];
            smoothedCutdownXData = [smoothedCutdownXData, sendX ];
            smoothedCutdownMeanData = [smoothedCutdownMeanData, sendMean ];
            smoothedCutdownSEMData = [smoothedCutdownSEMData, sendSEM ];
        end
        smoothedCutdownXData( isnan(smoothedCutdownXData) == 1 ) = 0; smoothedCutdownMeanData( isnan(smoothedCutdownMeanData) == 1 ) = 0; smoothedCutdownSEMData( isnan(smoothedCutdownSEMData) == 1 ) = 0; %Fixes hollow shadebars
            %Note: Applying "NaN" -> 0 to X data may result in malformed shadebars if this occurs anywhere except the start or end
        plot(smoothedCutdownXData, smoothedCutdownMeanData, 'k')
        if size(overVar,2) > 1
            %Calculate shading
            %shadeCoordsX = [1:1:size(meanData,2),size(meanData,2):-1:1]; %All points
            %shadeCoordsX = [cutdownXData,flip(cutdownXData)]; %Cutdown points
            shadeCoordsX = [smoothedCutdownXData,flip(smoothedCutdownXData)]; %Smoothed, cutdown points
            %shadeCoordsY = [meanData+0.5*semData,flip(meanData-0.5*semData)];
            %shadeCoordsY = [cutdownMeanData+0.5*cutdownSEMData,flip(cutdownMeanData-0.5*cutdownSEMData)];
            shadeCoordsY = [smoothedCutdownMeanData+smoothedCutdownSEMData,flip(smoothedCutdownMeanData-smoothedCutdownSEMData)];
            fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
            alpha(0.25)
        end
        %****
        
        %------------------------------------------------------------------

        %Rolling PEs per continuous minute
        figure

        plotData = [];
        meanData = [];
        semData = [];
        overMeanData = [];
        overSEMData = [];
        for plotInd = 1:2
            meanData{plotInd} = NaN(size(overAllPE,2), 720); %Make NaN array that should be far bigger than any conceivable bout
            semData{plotInd} = NaN(size(overAllPE,2), 720);
            for IIDN = 1:size(overAllPE,2)
                %Find contiguous sleep or wake bouts
                if plotInd == 1 %Sleep
                    preContig = overAllPE(IIDN).allPEStruct.allPERail(:,3);
                    plotColour = 'b';
                else %Wake
                    preContig = overAllPE(IIDN).allPEStruct.allPERail(:,5);
                    plotColour = 'r';
                end
                preContig(isnan(preContig) == 1) = 0;
                plotContig = bwlabel(preContig);

                %Quickly determine longest sleep/wake bouts
                N = hist(plotContig(plotContig ~= 0),nanmax(plotContig));
                    %Note: This is a one-line method, but it is not rigorous or assumption-free
                longestContig = find(N == nanmax(N),1);
                longestContigSize = N(longestContig);

                %Assemble array for data to go into
                plotData{plotInd}{IIDN} = NaN( nanmax(plotContig) , ceil(longestContigSize / (overVar(IIDN).dataFrameRate*60)) );

                %Place data into array
                for contigInd = 1:nanmax(plotContig)
                    subRail = overAllPE(IIDN).allPEStruct.allPERail(plotContig == contigInd,2); %Equal in size to the bout length (Whether it be sleep or wake)
                    binModulus = floor(overVar(IIDN).dataFrameRate*60);
                    for i = 1:size(plotData{plotInd}{IIDN},2)
                        binCoords = [ (i-1)*binModulus + 1 : i*binModulus ];
                        if nanmax(binCoords) > size(subRail,1)
                            binCoords(binCoords > size(subRail,1)) = [];
                        end
                        plotData{plotInd}{IIDN}(contigInd,i) = nansum(subRail(binCoords)) / ( size(binCoords,2) / (overVar(IIDN).dataFrameRate*60) );
                            %Finds the number of PEs in the bin and divides by the number of mins subtended by the bin (usually 1 except for the end of the data)
                    end
                end

                %Mean and SEM
                if size(plotData{plotInd}{IIDN},1) > 1
                   %meanData{plotInd}(IIDN,:) = nanmean(plotData{plotInd}{IIDN});
                   meanData{plotInd}(IIDN, 1:size(plotData{plotInd}{IIDN},2) ) = nanmean(plotData{plotInd}{IIDN});
                   for i = 1:size(plotData{plotInd}{IIDN},2)
                       semData{plotInd}(IIDN,i) = nanstd(plotData{plotInd}{IIDN}(:,i)) / sqrt( nansum( isnan( plotData{plotInd}{IIDN}(:,i) ) ~= 1 ) );      
                   end
                else
                    %meanData{plotInd} = plotData{plotInd}{IIDN};
                    meanData{plotInd}(IIDN, 1:size(plotData{plotInd}{IIDN},2) ) = plotData{plotInd}{IIDN};
                    semData{plotInd}(IIDN,1:size(plotData{plotInd}{IIDN},2)) = 0;
                end
                
                if suppressIndivPlots ~= 1
                    %Plot individual means
                    plot( meanData{plotInd}(IIDN, 1:size(plotData{plotInd}{IIDN},2) ), '-o', 'MarkerSize', 4, 'MarkerEdgeColor', plotColour )
                    %Error shading
                    hold on
                    semDataFriend = semData{plotInd}(IIDN,1:size(plotData{plotInd}{IIDN},2));
                    semDataFriend(isnan(semDataFriend) == 1) = 0;
                    shadeXCoords = [ 1:size(plotData{plotInd}{IIDN},2), flip(1:size(plotData{plotInd}{IIDN},2)) ];
                    shadeYCoords = [ meanData{plotInd}(IIDN, 1:size(plotData{plotInd}{IIDN},2) )+semDataFriend ,...
                        flip(meanData{plotInd}(IIDN, 1:size(plotData{plotInd}{IIDN},2) )-semDataFriend) ];
                    fill(shadeXCoords, shadeYCoords , colourz(IIDN,:), 'LineStyle', 'none') %Error shading
                    alpha(0.25)
                    %Loss Of N indication
                    lossList = [];
                    for i = 1:size(plotData{plotInd}{IIDN},2)
                        detectLoss = find( isnan(plotData{plotInd}{IIDN}(:,i)) == 1 );
                        newLoss = setdiff(detectLoss,lossList);
                        lossList = [lossList ; newLoss];
                        if isempty(newLoss) ~= 1
                            line([i,i],[0,nanmax(nanmax(meanData{plotInd}(IIDN, 1:size(plotData{plotInd}{IIDN},2) )))], 'LineStyle', ':', 'Color', plotColour);
                            %text(i-0.25, nanmax(nanmax(meanData{plotInd}))*1, num2str(newLoss), 'Color', plotColour,'FontSize',6);
                            text(i-0.25, 4 + plotInd, num2str(newLoss), 'Color', plotColour,'FontSize',6);
                            text(i, 0.5*plotInd, [num2str(nansum(isnan(plotData{plotInd}{IIDN}(:,i)) ~= 1))], 'Color', plotColour,'FontSize',10);
                        end 
                    end
                end
                
            end
            
            %Calculate mean of means
            if size(meanData{plotInd},1) > 1
                overMeanData{plotInd} = nanmean(meanData{plotInd});
                for i = 1:size(meanData{plotInd},2)
                    if nansum( isnan( meanData{plotInd}(:,i) ) ) ~= size(meanData{plotInd},1)
                        overSEMData{plotInd}(1,i) = nanstd(meanData{plotInd}(:,i)) / sqrt( nansum( isnan( meanData{plotInd}(:,i) ) ~= 1 ) );
                    end
                end
                overMeanData{plotInd}( size(overSEMData{plotInd},2)+1:end ) = []; %Post-hoc shorten overMean to be only where there is data
            else
                overMeanData{plotInd} = meanData{plotInd};
                for i = 1:size(meanData{plotInd},2)
                    if nansum( isnan( meanData{plotInd}(:,i) ) ) ~= size(meanData{plotInd},1)
                        overSEMData{plotInd}(1,i) = 0;
                    end
                end
                overMeanData{plotInd}( size(overSEMData{plotInd},2)+1:end ) = []; %Post-hoc shorten overMean to be only where there is data
            end

            %Plot
            plot( overMeanData{plotInd}, '-o', 'MarkerSize', 4, 'MarkerEdgeColor', plotColour )
            %Error shading
            hold on
            overSemDataFriend = overSEMData{plotInd};
            overSemDataFriend(isnan(overSemDataFriend) == 1) = 0;
            shadeXCoords = [ 1:size(overMeanData{plotInd},2), flip(1:size(overMeanData{plotInd},2)) ];
            shadeYCoords = [ overMeanData{plotInd}+overSemDataFriend , flip(overMeanData{plotInd}-overSemDataFriend) ];
            fill(shadeXCoords, shadeYCoords , plotColour, 'LineStyle', 'none') %Error shading
            alpha(0.25)
            %{
            %Loss Of N indication
            lossList = [];
            for i = 1:size(plotData{plotInd}{IIDN},2)
                detectLoss = find( isnan(plotData{plotInd}{IIDN}(:,i)) == 1 );
                newLoss = setdiff(detectLoss,lossList);
                lossList = [lossList ; newLoss];
                if isempty(newLoss) ~= 1
                    line([i,i],[0,nanmax(nanmax(meanData{plotInd}))], 'LineStyle', ':', 'Color', plotColour);
                    %text(i-0.25, nanmax(nanmax(meanData{plotInd}))*1, num2str(newLoss), 'Color', plotColour,'FontSize',6);
                    text(i-0.25, 4 + plotInd, num2str(newLoss), 'Color', plotColour,'FontSize',6);
                    text(i, 0.5*plotInd, [num2str(nansum(isnan(plotData{plotInd}{IIDN}(:,i)) ~= 1))], 'Color', plotColour,'FontSize',10);
                end 
            end
            %}
        end

        %Limits and things
        xlabel(['Continuous minutes (min.)'])
        ylabel(['Avg. PEs/min'])
        xlim([1, 30]); %Matt axes
        %xlim([1, 27]); %Rhiannon axes
        %ylim([0, 7]); %Rhiannon axes
        %ylim([0, 1.25*nanmax([meanData{1}, meanData{2}])]);
        %set(gca, 'XTick', [0:size(plotData{plotInd},2)])
        title(['Binned PEs per continuous minute of sleep (b) and wake (r) (n:',num2str(size(overAllPE,2)),')'])

        %------------------------------------------------------------------

        
%doFFT etc end        
end

%--------------------------------------------------------------------------

%{
%Ligated antennal data FFTs
if doFFT == 1
    for IIDN = 1:size(overVar,2)
        try
            fouriStruct = overFouri(IIDN).fouriStruct;
            
            figure
            plot(fouriStruct(1).allFRight,fouriStruct(1).allP1Right)
            xlim([0 1])
            ylim([0 1])
            %%if i == 1
            xlabel('Frequency (Hz)')
            ylabel('Power')
            %%end
            title([overVar(IIDN).flyName])
        catch
            ['## Warning: Failure to plot ligated FFT ##']
        end
    %IIDN end
    end
%doFFT end
end
%}

%--------------------------------------------------------------------------
% Time (- Hans Zimmer)
if doTimeCalcs == 1
    %colourz = jet(size(overVar,2));
    %---------------------------------------------------------
    %Plot prob events as a scatter per time
    figure
    for IIDN = 1:size(overVar,2) 
        %if IIDN ~= 2
        scatter(probScatter(IIDN).probStartZT,probScatter(IIDN).probEventsCount,[],colourz(IIDN,:));
        %%prePlot =  [probScatter(IIDN).probStartZT];
        %%prePlot2 =  [probScatter(IIDN).probEvents];
        %%plot(prePlot,prePlot2);
        hold on
        %end
    end
    %Plot trend
    %%hold on
    %%fitLine = polyfit(probScatter(IIDN).probStartZT, probScatter(IIDN).probEvents, 1);
    %plot(polyval(fitLine,probScatter(IIDN).probStartZT));
    %plot(polyval(fitLine,[min(probScatter(IIDN).probStartZT):max(probScatter(IIDN).probStartZT)]));
    hold off
    xLims = [16 36];
    xlim(xLims)
    set(gca,'XTick',(xLims(1):4:xLims(2)))
    xlabel('Time (24h)')
    ylabel('# of PE in bout')
    title(['Prob. events per ZT'])
    
    %Plot normalised prob events as a scatter per time
    figure
    for IIDN = 1:size(overVar,2) 
        %if IIDN ~= 2
        scatter(probScatter(IIDN).probStartZT,probScatter(IIDN).probEventsDurProp,[],colourz(IIDN,:));
        hold on
        %end
    end
    hold off
    xLims = [16 36];
    xlim(xLims)
    set(gca,'XTick',(xLims(1):4:xLims(2)))
    xlabel('Time (24h)')
    ylabel('Av. PEs per time (a.u.)')
    title(['Prob. events per ZT (Normalised to bout length)'])
    %---------------------------------------------------------
    
    %---------------------------------------------------------
    %Total numbers of bouts
    figure
    
    hist(sleepStruct.numBouts,8)
    xlabel('Number of bouts')
    %ylabel('# of PE in bout')
    title(['Hist. of total # of bouts per fly'])
    
    %---------------------------------------------------------
    
    %---------------------------------------------------------
    %----------------------
    %Bout length scatter
    figure
    
    for IIDN = 1:size(sleepStruct.combBout,2) 
        scatter(sleepStruct.combBout{IIDN}(:,1),sleepStruct.combBout{IIDN}(:,2),[],colourz(IIDN,:));
        hold on
    end
    hold off
    xLims = [16 36];
    xlim(xLims)
    set(gca,'XTick',(xLims(1):4:xLims(2)))
    xlabel('Time (24h)')
    ylabel('Bout length (s)')
    title(['Bout length per adjusted ZT'])
    
    %----------------------
    
    %Bout length barplot
    figure    
    %ys = [nanmean(sleepStruct.combBoutPooledSorted(:,1)),nanmean(sleepStruct.combBoutPooledSorted(:,1))];   
    %bar([1:timeSplit],[nanYs]);
    %Old
    %{
    if splitMode ~= 1
        %%barwitherr([stdYs],[1:timeSplit(1:end-1)],[nanYs]); %STD
        barwitherr([sleepStruct.lenSemYs],[timeSplit(1:end-1)],[sleepStruct.lenNanYs]); %SEM
    else
        %%barwitherr([stdYs],[1:timeSplit],[nanYs]); %STD
        barwitherr([sleepStruct.lenSemYs],[timeSplit],[sleepStruct.lenNanYs]); %SEM
    end
    %}
    %New
    %%barwitherr([stdYs],[1:timeSplit(1:end-1)],[nanYs]); %STD
    barwitherr([sleepStruct.lenSemYs],[timeSplit(1:end-1)],[sleepStruct.lenNanYs]); %SEM
    hold on
    
    %Scatter of points, coloured by time
    %Old
    %{
    if scatterMode == 1
        if splitMode ~= 1
            for zt = 1:size(sleepStruct.combBoutPooledRangeYs,2)
                scatter([repmat(timeSplit(zt),1,sleepStruct.combBoutPooledRangeYs(2,zt)-sleepStruct.combBoutPooledRangeYs(1,zt)+1)],[sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,zt):sleepStruct.combBoutPooledRangeYs(2,zt),2)]);
            end
        else
            if sliceBouts ~= 1
                for i = 1:timeSplit
                    scatter([repmat(i,1,sleepStruct.combBoutPooledRangeYs(2,i)-sleepStruct.combBoutPooledRangeYs(1,i)+1)],[sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2)]);
                end
            else
                for i = 1:timeSplit
                    scatter([repmat(i,1,sleepStruct.combBoutPooledRangeYs(2,i)-sleepStruct.combBoutPooledRangeYs(1,i)+1)],[sleepStruct.combBoutPooledSortedSliced(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2)]);
                end
            end
        end
    else
        %Scatter of points, coloured by fly
        for i = 1:size(sleepStruct.combBout,2)
            xAxes = floor(sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > min(timeSplit) & sleepStruct.combBout{i}(:,1) < max(timeSplit),1));
            yAxes = sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > min(timeSplit) & sleepStruct.combBout{i}(:,1) < max(timeSplit),2);
            scatter(xAxes,yAxes)
            hold on
        end
    end
    %}
    %New
    if scatterMode == 1
        try
            %Scatter of points, coloured by time
            if sliceBouts ~= 1
                for i = 1:size(sleepStruct.combBoutPooledRangeYs,2)
                    scatter([repmat(timeSplit(i),1,sleepStruct.combBoutPooledRangeYs(2,i)-sleepStruct.combBoutPooledRangeYs(1,i)+1)],[sleepStruct.combBoutPooledSorted(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2)]);
                        %"Select from pooled combBout data according to predefined ranges"
                end
            else
                for i = 1:size(sleepStruct.combBoutPooledRangeYs,2)
                    scatter([repmat(timeSplit(i),1,sleepStruct.combBoutPooledRangeYs(2,i)-sleepStruct.combBoutPooledRangeYs(1,i)+1)],[sleepStruct.combBoutPooledSortedSliced(sleepStruct.combBoutPooledRangeYs(1,i):sleepStruct.combBoutPooledRangeYs(2,i),2)]);
                end
            end
        catch
            ['## Could not use specified scatterMode ##']
            scatterMode = 2;
        end
    else
        %Scatter of points, coloured by fly
        for i = 1:size(sleepStruct.combBout,2)
            xAxes = [];
            yAxes = [];
            %xAxes = floor(sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > min(timeSplit) & sleepStruct.combBout{i}(:,1) < max(timeSplit),1));
            %xAxes = timeSplit(1:end-1);
            %yAxes = sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > min(timeSplit) & sleepStruct.combBout{i}(:,1) < max(timeSplit),2);
            for y = 1:size(timeSplit,2)-1
                xAxes = [xAxes, repmat(timeSplit(y),1,size(sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > timeSplit(y) & sleepStruct.combBout{i}(:,1) < timeSplit(y+1),2)',2))];
                yAxes = [yAxes, sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > timeSplit(y) & sleepStruct.combBout{i}(:,1) < timeSplit(y+1),2)'];
                    %"Select from individual combBout data for each timeSplit point where the bout ZT is larger than the current timeSplit point and smaller than the next timeSplit point"
            end
            scatter(xAxes,yAxes)
            hold on
        end        
    end

    hold off
    %%%if splitMode ~= 1
    xlabel('ZT hour')
        %ylabel('# of PE in bout')
    title(['Bar/Scatter plot of bout lengths per hour of night'])       
    %%%else
    %%%    xlabel('Portion of night')
    %%%    %ylabel('# of PE in bout')
    %%%    title(['Bar/Scatter plot of bout lengths per portion of night'])
    %%%end
    
    %----------------------
    
    %Bout number (binned) barplot
    figure
    
    %Old
    %{
    if splitMode ~= 1
        %%barwitherr([stdYs],[1:timeSplit(1:end-1)],[nanYs]); %STD
        barwitherr([sleepStruct.numSemYs],[timeSplit(1:end-1)],[sleepStruct.numMeanYs]); %SEM
    else
        %%barwitherr([stdYs],[1:timeSplit],[nanYs]); %STD
        barwitherr([sleepStruct.lenSemYs],[timeSplit],[sleepStruct.lenNanYs]); %SEM
    end
    %}
    %New
    %%barwitherr([stdYs],[1:timeSplit(1:end-1)],[nanYs]); %STD
    barwitherr([sleepStruct.numSemYs],[timeSplit(1:end-1)],[sleepStruct.numMeanYs]); %SEM
    hold on
    
    if scatterMode == 1
        for i = 1:size(sleepStruct.numBoutsBinnedPooled,2) 
            scatter([repmat(timeSplit(i),1,size(sleepStruct.numBoutsBinnedPooled,1))],[sleepStruct.numBoutsBinnedPooled(:,i)])
        end
    else
        %Scatter of points, coloured by fly
        for i = 1:size(sleepStruct.combBout,2)
            %xAxes = floor(sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > min(timeSplit) & sleepStruct.combBout{i}(:,1) < max(timeSplit),1));
            %yAxes = sleepStruct.combBout{i}(sleepStruct.combBout{i}(:,1) > min(timeSplit) & sleepStruct.combBout{i}(:,1) < max(timeSplit),2);
            xAxes = [timeSplit(1:end-1)];
            yAxes = [sleepStruct.numBoutsBinnedPooled(i,:)];
            
            scatter(xAxes,yAxes, [], colourz(i,1:3))
            line(xAxes,yAxes, 'Color', colourz(i,1:3))
            hold on
        end
    end
    
    hold off
    %%%if splitMode ~= 1
    %%%    xlabel('ZT hour')
    %%%    %ylabel('# of PE in bout')
    %%%    title(['Bar/Scatter plot of bout lengths per hour of night'])       
    %%%else
    xlabel('ZT')
    %ylabel('# of PE in bout')
    title(['Bar/Scatter plot of bout number per hour'])
    %%%end
    %----------------------
    
    %---------------------------------------------------------
    %Total numbers of bouts
    figure
    
    hist(sleepStruct.boutStartTimesZTPooled,24)
    xlabel('Bout start time')
    %ylabel('# of PE in bout')
    title(['Hist. of bout start times'])
    
    
    %---------------------------------------------------------
    
    %Number of PEs as a factor of bout length scatter
    figure
    
    %hist(sleepStruct.boutStartTimesZTPooled,24)
    if scatterMode == 1
        scatter(sleepStruct.combBoutPooled(:,2),sleepStruct.combBoutPooled(:,combBoutNumPEsCol)) 
            %All data; X - Bout duration (s), Y - Number of PEs (count; Zero included)
        %scatter(sleepStruct.combBoutPooled(:,2),sleepStruct.combBoutPooled(:,7)) 
            %All data; X - Bout duration (s), Y - Number of PEs (count; Zero included)
    else
        for IIDN = 1:size(sleepStruct.combBout,2)
            scatter(sleepStruct.combBout{IIDN}(:,2),sleepStruct.combBout{IIDN}(:,combBoutNumPEsCol), [], colourz(IIDN,:)) 
                %Individual flies; X - Bout duration (s), Y - Number of PEs (count; Zero included)
            %scatter(sleepStruct.combBout{IIDN}(:,2),sleepStruct.combBout{IIDN}(:,7), [], colourz(IIDN,:)) 
                %Individual flies; X - Bout duration (s), Y - Number of PEs (count; Zero included)
            hold on
        end
    end
    hold off
    
    xlabel('Bout length (s)')
    ylabel('# of PE in bout')
    title(['Scatter of # PEs vs Bout length'])
    
    %---------------------------------------------------------
    
    %Sleep 'curves'
    figure
    
    plotData = sleepStruct.pooledZTCurveSumsMins;
    nanMeans = nanmean(plotData,1); %",1" is critical for times when only one dataset is being analysed
    nanSTDs = nanstd(plotData,1);
    for i = 1:size(nanSTDs,2)
        nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
    end
    if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
        shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
        shadeCoordsY = [nanMeans+nanSEMs,flip(nanMeans-nanSEMs)];
        fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
        alpha(0.25)
    end
    hold on
    plot(nanMeans, 'k-o') %Average
    
    if scatterMode ~= 1
        for i = 1:size(plotData,1)
            plot(plotData(i,:), '-o') %Individual flies
            hold on
        end
    end
    
    xlim([1, size(plotData,2)])
    ylim([0, 60])
    set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
    set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
    xlabel('ZT (24h)')
    if analyseWake ~= 1
        ylabel('Mins of sleep/hr')
        title(['Average sleep mins/hr (binned)'])
    else
        ylabel('Mins of wake/hr')
        title(['Average wake mins/hr (binned)'])
    end
    
    %---------------------------------------------------------
    
    %PE 'curve' for PEs within bouts
    figure
    
    plotData = sleepStruct.pooledZTPEsSumsMins;
    nanMeans = []; nanSTDs = []; nanSEMs = [];
    nanMeans = nanmean(plotData,1);
    nanSTDs = nanstd(plotData,1);
    for i = 1:size(nanSTDs,2)
        nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
    end
    
    if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
        shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
        shadeCoordsY = [nanMeans+nanSEMs,flip(nanMeans-nanSEMs)];
        fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
        alpha(0.25)
    end
    hold on
    plot(nanMeans, 'k-o') %Average
    
    if scatterMode ~= 1
        for i = 1:size(plotData,1)
            plot(plotData(i,:), '-o') %Individual flies
            hold on
        end
    end
    
    xlim([1, size(plotData,2)])
    %ylim([0, 60])
    set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
    set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
    xlabel('ZT (24h)')
    ylabel('Mins of PE/hr occurring within bouts')
    title(['Average PE mins/hr within bouts (binned)'])
    barStats( plotData , alphaValue );
    ylim('auto')

    %---------------------------------------------------------
    
    %PE 'curve' for PEs within bouts (Normalised to max of each fly)
    figure
    
    plotData = sleepStruct.pooledZTPEsSumsMins;
    for i = 1:size(plotData,1)
        plotData(i,:) = plotData(i,:) / nanmax(plotData(i,:));
    end
    if noSleepBehaviour == -1 %Script has been set to nanify instances of no sleep (Because PEs are subset of sleep bouts)
        sleepData = sleepStruct.pooledZTCurveSumsMins;
        plotData(sleepData == 0) = NaN;
    end
    nanMeans = nanmean(plotData,1);
    nanSTDs = nanstd(plotData,1);
    for i = 1:size(nanSTDs,2)
        nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
    end
    if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
        shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
        shadeCoordsY = [nanMeans+nanSEMs,flip(nanMeans-nanSEMs)];
        fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
        alpha(0.25)
    end
    hold on
    plot(nanMeans, 'k-o') %Average
    
    if scatterMode ~= 1
        for i = 1:size(plotData,1)
            plot(plotData(i,:), '-o') %Individual flies
            hold on
        end
    end
    
    xlim([1, size(plotData,2)])
    ylim([0, 1.25])
    set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
    set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
    xlabel('ZT (24h)')
    ylabel('Normalised PE amounts (a.u.)')
    title(['Normalised average PE amounts (binned)'])
    if noSleepBehaviour == -1
        for i = 1:size(plotData,2)
            xVal = [i];
            yVal = [nanMeans(i) + 0.05];
            textVal = [nansum(isnan(plotData(:,i)) ~= 1)];
            text([xVal], [yVal], [num2str(textVal)], 'Color', 'r');
        end        
    end
    barStats( plotData , alphaValue );
    ylim('auto')
    
    %---------------------------------------------------------
    
    %Hist of sleep bout length
    %Pooled
    figure
    plotData = [];
    for IIDN = 1:size(overVar,2)
        plotData = [plotData, overVar(IIDN).inStruct.holeSizesSeconds/60];
    end
    hist( plotData, 128 )
    figName = ['Pooled hole sizes'];
    title(figName)
    set(gcf,'Name',figName)
    xlabel('Hole size (mins) [Some data may be excluded]')
    xlim([5, 60])
    
    %Averaged
    figure
    plotData = [];
    for IIDN = 1:size(overVar,2)
        %plotData = [plotData, overVar(IIDN).inStruct.holeSizesSeconds/60];
        [plotData(IIDN,:),X] = hist( overVar(IIDN).inStruct.holeSizesSeconds/60 , [5:5:60] );
    end
    %hist( plotData, 12 )
    meanData = nanmean(plotData,1);
    sdData = nanstd( plotData, [], 1 );
    semData = sdData ./ sqrt( nansum( plotData ) );
    barwitherr( semData , meanData )
    figName = ['Averaged hole sizes histogram'];
    title(figName)
    xticklabels( [X] )
    set(gcf,'Name',figName)
    xlabel('Hole size (mins) [Some data may be excluded]')
    %xlim([5, 60])
    
    %---------------------------------------------------------
    
    if exist('overFouri') == 1
        for side = 1:size(processList,2)
            
            %---------------------------------------------------------
            
            %Antennal periodicity 'curve' for periodicity within bouts
            figure
            
            plotData = sleepStruct.(strcat('pooledZTAntPerioSumsMins_',processList{side}));
            %plotData = sleepStruct.pooledZTAntPerioSumsMins;
            nanMeans = nanmean(plotData,1);
            nanSTDs = nanstd(plotData,1);
            for i = 1:size(nanSTDs,2)
                nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
            end
            if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
                shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
                shadeCoordsY = [nanMeans+nanSEMs,flip(nanMeans-nanSEMs)];
                fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
                alpha(0.25)
            end
            hold on
            plot(nanMeans, 'k-o') %Average

            if scatterMode ~= 1
                for i = 1:size(plotData,1)
                    plot(plotData(i,:), '-o') %Individual flies
                    hold on
                end
            end

            xlim([1, size(plotData,2)])
            ylim([0, 60])
            set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
            set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
            xlabel('ZT (24h)')
            ylabel('Mins of ant. perio./hr occurring within bouts')
            title(['Average ant. perio. mins/hr within bouts (binned) for ',processList{side}])
            %title(['Average ant. perio. mins/hr within bouts (binned)'])

        
            %------------------------------------------------------------------

            %Antennal periodicity/sleep ratio 'curve' for proportion of time with periodicity within bouts
            figure
            
            plotData = sleepStruct.(strcat('pooledZTAntPerioSumsMinsSleepRatio_',processList{side}));
            %plotData = sleepStruct.pooledZTAntPerioSumsMinsSleepRatio;
            nanMeans = nanmean(plotData,1);
            nanSTDs = nanstd(plotData,1);
            for i = 1:size(nanSTDs,2)
                nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
            end
            if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
                shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
                shadeCoordsY = [nanMeans+nanSEMs,flip(nanMeans-nanSEMs)];
                fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
                alpha(0.25)
            end
            hold on
            plot(nanMeans, 'k-o') %Average

            if scatterMode ~= 1
                for i = 1:size(plotData,1)
                    plot(plotData(i,:), '-o') %Individual flies
                    hold on
                end
            end

            xlim([1, size(plotData,2)])
            ylim([0, 1])
            set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
            set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
            xlabel('ZT (24h)')
            ylabel('Proportion of sleep mins containing ant. perio.')
            if noSleepBehaviour == 0
                title(['Average ant. perio. to sleep ratio within bouts (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) ') for ',processList{side},'; Zeroes zeroed']) %<BF1942 theme song>
            elseif noSleepBehaviour == 1
                title(['Average ant. perio. to sleep ratio within bouts (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) ') for ',processList{side},'; Zeroes averaged']) 
            elseif noSleepBehaviour == -1
                title(['Average ant. perio. to sleep ratio within bouts (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) ') for ',processList{side}])
                %Write post-zero-NaNing Ns on plot
                for i = 1:size(plotData,2)
                    xVal = [i];
                    yVal = [nanMeans(i) + 0.05];
                    textVal = [nansum(isnan(plotData(:,i)) ~= 1)];
                    text([xVal], [yVal], [num2str(textVal)], 'Color', 'r');
                end
            end

            %------------------------------------------------------------------

            %Antennal periodicity frequency position 'curve' for periodicity within bouts
            figure

            preData = [];
            plotData = [];
            plotDataDeep = [];

            for IIDN = 1:size(sleepStruct.(strcat('pooledZTAntPerioFreqPos_',processList{side})),1)
            %for IIDN = 1:size(sleepStruct.pooledZTAntPerioFreqPos,1)
                for i = 1:size(sleepStruct.(strcat('pooledZTAntPerioFreqPos_',processList{side})),2)
                %for i = 1:size(sleepStruct.pooledZTAntPerioFreqPos,2)
                    %preTemp = unique(sleepStruct.pooledZTAntPerioFreqPos{IIDN,i}); %Capture all unique frequency positions
                        %Note: This flattens all information about duration (i.e. "0, 0.16, 0.24" could have been a thousand seconds of 0.16Hz and one second of 0.24Hz)
                    preTemp = sleepStruct.(strcat('pooledZTAntPerioFreqPos_',processList{side})){IIDN,i}; %Use all data, not just uniques
                    %preTemp = sleepStruct.pooledZTAntPerioFreqPos{IIDN,i}; %Use all data, not just uniques
                    preTemp(preTemp == 0) = NaN; %Remove processing-induced zeroes
                    plotDataDeep{IIDN,i} = nanmedian(preTemp); %For individual plotting (Not used directly in pooled plotting)
                    plotData(IIDN,i) = nanmedian(preTemp); %For averaging (Switched to preTemp so plotDataDeep can be freeform)
                end
            end
            %plotData = sleepStruct.pooledZTAntPerioSumsMins;
            %nanMeans = nanmean(plotData);
            nanMedians = nanmedian(plotData,1);
            nanSTDs = nanstd(plotData,1);
            for i = 1:size(nanSTDs,2)
                nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
            end
            if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
                shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
                shadeCoordsY = [nanMedians+nanSEMs,flip(nanMedians-nanSEMs)];
                fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
                alpha(0.25)
            end
            hold on
            plot(nanMedians, 'k-o') %Average

            if scatterMode ~= 1
                for IIDN = 1:size(plotDataDeep,1)
                    %{
                    %Disabled on account of plotDataDeep reduced to one number and thus plottable as line
                    for i = 1:size(plotDataDeep,2)
                        %xVals = repmat(i,size(plotDataDeep{IIDN,i},1),1);
                        %(i - 0.5) + IIDN*(0.5/size(overVar,2))
                        xVals = repmat( (i) + IIDN*(0.5/size(overVar,2)) , size(plotDataDeep{IIDN,i},1),1);
                        plot(xVals ,plotDataDeep{IIDN,i}, 'o', 'Color', colourW(IIDN,:)); %Individual flies
                            %Plot as points
                        hold on
                    end
                    %}
                    plot(plotData(IIDN,:), '-o', 'Color', colourz(IIDN,:)); %Individual flies
                        %Plot as line
                    hold on
                end
            end

            xlim([1, size(plotData,2)])
            ylim([min(targetPerioFreqRange), max(targetPerioFreqRange)])
            set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
            set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
            xlabel('ZT (24h)')
            ylabel('Freq. peak positions within bouts')
            title(['Median of all detected freq positions within bouts (binned) (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)), ') for ',processList{side}])
            %title(['Median of all detected freq positions within bouts (binned) (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)), ')'])
            if noSleepBehaviour == -1
                for i = 1:size(plotData,2)
                    xVal = [i];
                    %yVal = [nanMeans(i) + 0.05];
                    yVal = [nanMedians(i) + 0.05];
                    textVal = [nansum(isnan(plotData(:,i)) ~= 1)];
                    text([xVal], [yVal], [num2str(textVal)], 'Color', 'r');
                end
            end
            %------------------------------------------------------------------
            
        %side end
        end
        
        %PE/sleep ratio 'curve' for proportion of time with PEs within bouts
        figure

        plotData = sleepStruct.pooledZTPEsSumsMinsSleepRatio;
        nanMeans = nanmean(plotData,1);
        %nanMedians = nanmedian(plotData,1);
        nanSTDs = nanstd(plotData,1);
        for i = 1:size(nanSTDs,2)
            nanSEMs(1,i) = nanSTDs(1,i) / sqrt(nansum(isnan(plotData(:,i)) ~= 1));
        end
        if size(plotData,1) > 1 %If not true, nanSEMs/nanSTDs will not be valid
            shadeCoordsX = [1:1:size(plotData,2),size(plotData,2):-1:1];
            shadeCoordsY = [nanMeans+nanSEMs,flip(nanMeans-nanSEMs)];
            %shadeCoordsY = [nanMedians+0.5*nanSEMs,flip(nanMedians-0.5*nanSEMs)];
            fill(shadeCoordsX, shadeCoordsY,'y') %Error shading
            alpha(0.25)
        end
        hold on
        plot(nanMeans, 'k-o') %Average
        %plot(nanMedians, 'k-o') %Median

        if scatterMode ~= 1
            for i = 1:size(plotData,1)
                plot(plotData(i,:), '-o') %Individual flies
                hold on
            end
        end

        xlim([1, size(plotData,2)])
        ylim([0, 1])
        set(gca,'XTick',(1:1:size(sleepCurveZT,2)-1))
        set(gca,'XTickLabel',[sleepCurveZT(1:end-1)])
        xlabel('ZT (24h)')
        ylabel('Proportion of sleep mins containing PEs')
        if noSleepBehaviour == 0
            title(['Mean PEs to sleep ratio within bouts (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) '); Zeroes zeroed']) %<BF1942 theme song>
        elseif noSleepBehaviour == 1
            title(['Mean PEs to sleep ratio within bouts (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) '); Zeroes averaged']) 
        elseif noSleepBehaviour == -1
            title(['Mean PEs to sleep ratio within bouts (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) ')'])
            %Write post-zero-NaNing Ns on plot
            for i = 1:size(plotData,2)
                xVal = [i];
                %yVal = [nanMeans(i) + 0.05];
                yVal = [nanMedians(i) + 0.05];
                textVal = [nansum(isnan(plotData(:,i)) ~= 1)];
                text([xVal], [yVal], [num2str(textVal)], 'Color', 'r');
            end
        end

        %---------------------------------------------------------    
                    
    %overFouri end    
    end    
%timeCalcs end    
end

%--------------------------------------------------------------------------
%Specific hole plot

try
    %Plot antennal angles during extracted sleep bouts ('holes')
    IIDN = 5;

    inStruct = overVar(IIDN).inStructCarry;

    rightThetaProc = overVar(IIDN).xRightAll;
    leftThetaProc = overVar(IIDN).xLeftAll;
    %if isempty(overVar(IIDN).avProbContourSizeSmoothed) ~= 1

    probMetric = overVar(IIDN).probMetric;
    dlcProbStatus = overVar(IIDN).dlcProbStatus;
    %end
    
    %QA to pad out smoothed data with NaNs to prevent crashes when plotting bouts that run right up to end
    %{
    if isfield(overVar(IIDN),'rightThetaSmoothed') == 1 && size(rightThetaSmoothed,1) < size(overVar(IIDN).overGlob.rightThetaProc,1)
        rightThetaSmoothed(size(rightThetaSmoothed,1)+1:size(overVar(IIDN).overGlob.rightThetaProc,1)) = NaN;
        leftThetaSmoothed(size(leftThetaSmoothed,1)+1:size(overVar(IIDN).overGlob.leftThetaProc,1)) = NaN;
    end
    %}

    figure
    i = 18;
    
    disp(['-- Specifically plotting hole ',num2str(i), ' of file number ',num2str(IIDN),' --'])
    
    if isempty(rightThetaProc) ~= 1
        %plot(rightThetaProc(inStruct.holeRanges{i}), 'm')
        filtData = lowpass(rightThetaProc(inStruct.holeRanges{i}),0.5, overVar(IIDN).dataFrameRate);
        plot(filtData(2:end-1), 'm')
        hold on
        filtData = lowpass(leftThetaProc(inStruct.holeRanges{i}),0.5, overVar(IIDN).dataFrameRate);
        %plot(leftThetaProc(inStruct.holeRanges{i}), 'b')
        plot(filtData(2:end-1), 'b')
        %ylabel('Angle (degs)')
        ylabel('[Filtered] Antennal Angle (degs)')
        xlim([0 inStruct.holeSizes(i)])
    end
    hold on
    
    exTicks = linspace(0,inStruct.holeSizes(i),5);
    exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
    ax = gca;
    maxTick = inStruct.holeSizes(i);
    ax.XTick = exTicks;
    ax.XTickLabel = [round(exTicksSeconds/60,1)];

    xlabel('Time (m)')

    title(strcat(inStruct.holeStartsTimes(i), '-',inStruct.holeEndsTimes{i}(end-8:end),' (k:', num2str(i), ',# PEs:', num2str(sleepStruct.combBout{IIDN}(i,combBoutNumPEsCol)) ,')'))

    %DLC
    %{
    if doDLC == 1
        %Plot derived angle
        if isfield(overVar(IIDN).overGlob, 'dlcDataProc') == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcLeftAntennaAngleAdj') == 1 & ...
                isempty(overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj) ~= 1
            plot(overVar(IIDN).overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'r')   
            plot(overVar(IIDN).overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'm')
        end
    end
    %}

    %Prob
    if isempty(probMetric) ~= 1 %isempty(overVar(IIDN).avProbContourSizeSmoothed) ~= 1
        axPos = get(ax,'Position');
        ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
        hold on

        %Plot prob activity
        plot(probMetric(inStruct.holeRanges{i}), 'green')

        %Plot average threshold for prob
        line('XData', [0 inStruct.holeSizes(i)], 'YData', [meanAvProbContourSizeSmoothedRestricted*probMeanThresh meanAvProbContourSizeSmoothedRestricted*probMeanThresh], 'LineStyle', '--', ...
           'LineWidth', 2, 'Color','r');
        try
            xlim([0 size(inStruct.holeRanges{i},2)])
            ylim([1 meanAvProbContourSizeSmoothedRestricted*75])
        catch
            ylim([0 max(probMetric(inStruct.holeRanges{i}))*3+1])
        end
    end
    
    if doTimeCalcs == 1
        %Add scatter of all detected PEs
        scatter( probScatter(IIDN).findPEs(i).LOCS, probScatter(IIDN).findPEs(i).PKS, 10 )

        %Plot raft coords
        if isfield(probScatter(IIDN).spells(i), 'matchingContigStartEnd') == 1
            hold on
            for raftInd = 1:size(probScatter(IIDN).spells(i).matchingContigStartEnd,1)
                xData = [repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1),1,2), repmat(probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2),1,2), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1)];
                %yData = [0,probInterval, probInterval, 0, 0];
                yData = [0,nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.25, 0, 0];
                fill(xData, yData,'k', 'LineStyle', 'none') %Error shading
                alpha(0.15)

                text( nanmean([probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,1), probScatter(IIDN).spells(i).matchingContigStartEnd(raftInd,2)]) , ...
                    nanmax( probScatter(IIDN).findPEs(i).PKS ) * 1.15, num2str(raftInd), 'Color', 'c');
                %{
                %Add text readouts of freq for peaks within matching coords
                for subRaftInd = 1:size(probScatter(IIDN).spells(i).matchingContigFreqs{raftInd},1)-1 %Note: -1 tacked on due to overrun issues
                    text(probScatter(IIDN).findPEs(i).LOCS( probScatter(IIDN).spells(i).matchingContigPEsPos{raftInd}(subRaftInd) )-20, ...
                        probScatter(IIDN).findPEs(i).PKS( probScatter(IIDN).spells(i).matchingContigPEsPos{raftInd}(subRaftInd) )+3, ...
                        num2str( round( probScatter(IIDN).spells(i).matchingContigFreqs{raftInd}(subRaftInd) ,3 ) ), 'Color', 'r')
                    %Honestly the indexing for these text items is almost too complicated to be worth explaining but:
                    %"Select locations from the total peaks location list based on the subset matchingCoords position list" and so on for the peak heights/etc
                end
                %}
            end
        end

        %Plot the prob. threshold
        hold on
        if rollingFindPeaks == 0
            line([0, inStruct.holeSizes(i)], [minProbPeakHeight, minProbPeakHeight], 'Color', 'k', 'LineStyle', ':')
        else
            thisBoutRollMeanCoords = ...
                find( ( overAllPE(IIDN).allPEStruct.rollingFinderMean(:,3) > inStruct.holeRanges{i}(1) & overAllPE(IIDN).allPEStruct.rollingFinderMean(:,3) < inStruct.holeRanges{i}(end) )  );
            %line([probScatter(IIDN).spells(i).rollingFinderMean(:,2)], [probScatter(IIDN).spells(i).rollingFinderMean(:,1)], 'Color', 'b') %Old system, flawed understanding of rollingFinderMean scale
            line([ overAllPE(IIDN).allPEStruct.rollingFinderMean(thisBoutRollMeanCoords,3)-inStruct.holeRanges{i}(1) ], [ overAllPE(IIDN).allPEStruct.rollingFinderMean(thisBoutRollMeanCoords,1) ], 'Color', 'b')
        end
    end
    
    %Perio. shading
    if exist('overFouri') == 1
        %shadeColourList = jet(size(processList,2));
        %if isfield(overFouri(IIDN).fouriStruct,'rollCoords_xLeft') == 1 && isempty(overFouri(IIDN).fouriStruct(i).rollCoords_xLeft) ~= 1 & doSpectro == 1 %Disabling this will probably cause crashes if overFouri could not be calculated for this dataset
            for side = 1:size(processList,2)
                %for z = 1:size(overFouri(i).fouriStruct,2) %"Row of combBout" (not necessary in earlier operations because not dealing with more than one double ever)
                rollCoords = overFouri(IIDN).fouriStruct(i).(strcat('rollCoords_',processList{side}));
                tempSimpleSig = overFouri(IIDN).fouriStruct(i).(strcat('rollSigSNR_',processList{side})); %Simplifies the giant and complicated indexing
                tempSimplePeak = overFouri(IIDN).fouriStruct(i).(strcat('rollSigPeak_',processList{side})); %Ditto, for peak
                for om = 1:size(tempSimpleSig,2) %"Roll position within bout" (Note: This is flattened by coordination with perioCount)
                    if tempSimpleSig(om) > SNRThresh && (tempSimplePeak(om) >= min(targetPerioFreqRange) && tempSimplePeak(om) <= max(targetPerioFreqRange))
                        shadeVerty = 1; %How big the shading should be vertically
                        subRollCoordsRel = rollCoords{om};
                        subRollCoordsAbs = rollCoords{om} + overVar(IIDN).inStructCarry.holeStarts(i);
                        shadeXCoords = [ subRollCoordsRel(1) , subRollCoordsRel(2) , subRollCoordsRel(2) , subRollCoordsRel(1) ];
                        %New
                        thisProcessData = eval(plotProcessList{side});
                        shadeYCoords = [ thisProcessData(subRollCoordsAbs(1)) + shadeVerty , thisProcessData(subRollCoordsAbs(2)) + shadeVerty ,...
                                thisProcessData(subRollCoordsAbs(2)) - shadeVerty , thisProcessData(subRollCoordsAbs(1)) - shadeVerty ]; %5 arbitrary
                        fill(shadeXCoords, shadeYCoords, colourProcesses(side,:))
                        alpha(0.15)
                    end                        
                end
                %end  
            end
        %end
    end

catch
    disp(['## Could not do specific hole plot ##'])
    try
        disp(['(Requested hole #',num2str(i),' of file #',num2str(IIDN),', where ',num2str(size(inStruct.holeSizes,2)),' holes exist)'])
    end
    %crash = yes
end

%End of specific hole plot
%--------------------------------------------------------------------------
if splitBouts == 1 && doTimeCalcs == 1
    %FLID plots
      
    %-----------------------------
    %FLID Bout lengths
    %(This is essentially a control figure when FLID bout lengths are fixed)
    figure

    plotData = [];
    for i = 1:size(splitDurs,2)
        plotData(:,i) = flidStruct.pooled.combBout{i}(:,2); %Bout length column
    end

    barwitherr(nanstd(plotData,1),[1:size(splitDurs,2)],nanmean(plotData,1))
    
    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    %ylabel('# of PE in bout')
    title(['Bout length per segment'])
    
    %-----------------------------
    
    %FLID mean number of PEs (Mean of total pooled numbers, SD from pooled data)
    figure
    
    plotData = [];
    plotDataSizes = [];
    plotDataSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(:,i) = flidStruct.pooled.combBout{i}(:,combBoutNumPEsCol); 
            %PE count column
        %plotData(:,i) = flidStruct.pooled.combBout{i}(:,7); 
            %PE count column
        %plotData(plotData == 0) = NaN;
        plotDataSizes(1,i) = nansum(isnan(plotData(:,i)) ~= 1);
        plotDataSEMs(1,i) = nanstd(plotData(:,i))/sqrt(plotDataSizes(i));
    end
    %plotData(plotData == 0) = NaN;
        %NOTE: This changes this analysis from "Number of PEs on average" to "Number of PEs on average, when PEs were actually occuring"
            %Also introduces a variable (and much smaller) n
    
    barwitherr(plotDataSEMs,[1:size(splitDurs,2)],nanmean(plotData,1))
    
    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel('# of PE in bout')
    title(['Mean number of PEs per segment (from all bouts)'])
    
    %-----------------------------
    
    %FLID normalised mean number of PEs (Mean of total pooled numbers divided by time, SD from plot data)
    %(This plot adjusted to not use underlying sizes that were probably SEM hacking the data)
    figure
    
    preData = [];
    for i = 1:size(flidStruct.individual.peBoutNumNorm,2)
        preData(i,:) = nanmean(flidStruct.individual.peBoutNumNorm{i},1);
    end
    plotData = [];
    plotDataSizes = [];
    plotDataSEMs = [];
    for i = 1:size(splitDurs,2)
        %for y = 1:size(flidStruct.pooled.combBout{i}(:,2),1)
        %    plotData(y,i) = flidStruct.pooled.combBout{i}(y,7) / (flidStruct.pooled.combBout{i}(y,2) / 60.0); %PE count column / (Bout segment duration (s) column / 60 seconds in a minute)
        %end
        plotData(1,i) = nanmean(preData(:,i),1);
        %plotData(plotData == 0) = NaN;
        %plotDataSizes(1,i) = nansum(isnan(plotData(:,i)) ~= 1);
        %plotDataSizes(1,i) = size(preData(:,i),1);
        plotDataSEMs(1,i) = nanstd(preData(:,i),1)/sqrt(size(preData(:,i),1));
    end
    %plotData(plotData == 0) = NaN;
        %NOTE: This changes this analysis from "Number of PEs on average" to "Number of PEs on average, when PEs were actually occuring"
            %Also introduces a variable (and much smaller) n
    
    barwitherr(plotDataSEMs,[1:size(splitDurs,2)],plotData, 'g')
    
    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel('Normalised # of PE per minute in bout')
    title(['Mean number of PEs/min. per segment (from all bouts)'])
    if size( preData,1 ) > 1
        barStats( preData , alphaValue );
    end
    
    %-----------------------------
    
    %FLID PEs/min, proportionalised within fly 
    figure
    
    preData = [];
    for i = 1:size(flidStruct.individual.peBoutNumNorm,2)
        preData(i,:) = nanmean(flidStruct.individual.peBoutNumNorm{i},1) / nanmax(nanmean(flidStruct.individual.peBoutNumNorm{i},1));
    end
    plotData = [];
    plotDataSizes = [];
    plotDataSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(1,i) = nanmean(preData(:,i));
        plotDataSEMs(1,i) = nanstd(preData(:,i))/sqrt(size(preData(:,i),1));
    end
    
    barwitherr(plotDataSEMs,[1:size(splitDurs,2)],plotData, 'y')

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel('Prop. of max PE/min (within bouts)')
    title(['Prop. of max mean number of PEs/min. per segment (from all bouts)'])
    if size( preData,1 ) > 1
        barStats( preData , alphaValue );
    end
    
    %-----------------------------
    
    %FLID PE bout prevalence (Individual fly means, SD from across flies)
    figure
    
    %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
    plotData = [];
    plotSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(:,i) = nanmean(flidStruct.pooled.peBoutNumMean(:,i)); %"Where sig. peridicity, grab freq. peak"
        plotSEMs(1,i) = nanstd(flidStruct.pooled.peBoutNumMean(:,i)) / sqrt(size(flidStruct.pooled.peBoutNumMean(:,i),1));
    end
    %plotData(plotData == 0) = NaN; 
    
    barwitherr(plotSEMs,[1:size(splitDurs,2)],plotData)

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel('Prop. of bouts containing PEs')
    title(['Proportion of segments containing PEs'])
    if size( flidStruct.pooled.peBoutNumMean,1 ) > 1
        barStats( flidStruct.pooled.peBoutNumMean , alphaValue );
    end
    
    %-----------------------------
       
    %FLID Spells/min, proportionalised within fly 
    figure
    
    preData = [];
    for i = 1:size(flidStruct.individual.spellBoutNumNorm,2)
        preData(i,:) = nanmean(flidStruct.individual.spellBoutNumNorm{i},1) / nanmax(nanmean(flidStruct.individual.spellBoutNumNorm{i},1));
    end
    plotData = [];
    plotDataSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(1,i) = nanmean(preData(:,i));
        plotDataSEMs(1,i) = nanstd(preData(:,i))/sqrt(size(preData(:,i),1));
    end
    
    barwitherr(plotDataSEMs,[1:size(splitDurs,2)],plotData, 'y')

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel('Prop. of max spells/min (within bouts)')
    title(['Prop. of max mean number of spells/min. per segment (from all bouts)'])
    if size( preData,1 ) > 1
        barStats( preData , alphaValue );
    end
    
    %-----------------------------
           
    %FLID spell durations normalised 
    figure
    
    preData = [];
    for fly = 1:size(flidStruct.pooled.spellBoutDurTotal,1)
        preData(fly,:) = flidStruct.pooled.spellBoutDurTotal(fly,:) ./ flidStruct.pooled.boutDurTotal(fly,:);
    end
    plotData = [];
    plotDataSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(1,i) = nanmean(preData(:,i));
        plotDataSEMs(1,i) = nanstd(preData(:,i))./sqrt(size(preData(:,i),1));
    end
    
    barwitherr(plotDataSEMs,[1:size(splitDurs,2)],plotData, 'y')

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel('Bout duration prop.')
    title(['Prop. of bout segment that was spell (>= ',num2str(minRaftSize),' PEs)'])
    if size( preData,1 ) > 1
        barStats( preData , alphaValue );
    end
    
    %-----------------------------
    
    %Antennal periodicity bout prevalence (Mean of individual fly counts, SD from across flies)
    for side = 1:size(processList,2)
        figure

        %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
        plotData = [];
        meanData = [];
        plotSEMs = [];
        for i = 1:size(splitDurs,2)
            %plotData(:,i) =  nanmean(flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(:,i)); %Mean of per-fly calculated proportion of bouts containing antennal periodicity
            plotData(:,i) =  flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(:,i); %Mean of per-fly calculated proportion of bouts containing antennal periodicity
            meanData(i) = nanmean( plotData(:,i) );
            plotSEMs(1,i) = nanstd(flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(:,i)) / sqrt(size(flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(:,i),1));
        end
        %plotData(plotData == 0) = NaN; 

        barwitherr(plotSEMs,[1:size(splitDurs,2)],meanData)
        
        ax = gca;
        ylim([0 0.66])
        ax.XTickLabel = splitDursText;
        xlabel('Bout segment')
        ylabel(['Prop. of bouts'])
        title(['Prop. of bout segments containing ', processList{side}, ' periodicity (of any Freq.) (SNRThresh: ',num2str(SNRThresh),')'])
        if size(plotData,1) > 1
            barStats(plotData,alphaValue);
        else
            disp(['-# Cannot barStats with only one fly #-'])
        end
    end
    
    %{
    %Normalised antennal periodicity bout prevalence (Mean of individual fly counts, SD from across flies)
    for side = 1:size(processList,2)
        figure

        %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
        plotData = [];
        plotSEMs = [];
        for i = 1:size(splitDurs,2)
            plotData(:,i) =  nanmean(flidStruct.pooled.(strcat('antBoutPropNorm_',processList{side}))(:,i)); %Mean of per-fly calculated proportion of bouts containing antennal periodicity
            plotSEMs(1,i) = nanstd(flidStruct.pooled.(strcat('antBoutPropNorm_',processList{side}))(:,i)) / sqrt(size(flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(:,i),1));
        end
        %plotData(plotData == 0) = NaN; 

        barwitherr(plotSEMs,[1:size(splitDurs,2)],plotData, 'm')

        xlabel('Bout segment')
        ylabel(['Normalised prop. of bouts'])
        title(['Norm. prop. of bout segments containing ', processList{side}, ' periodicity (of any Freq.)'])
    end
    %}
    %-----------------------------
    
    %Normalised antennal periodicity bout duration (Mean of individual fly counts, SD from across flies)
    for side = 1:size(processList,2)
        figure

        %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
        plotData = [];
        plotSEMs = [];
        for i = 1:size(splitDurs,2)
            plotData(:,i) =  nanmean(flidStruct.pooled.(strcat('antBoutPerioDurPropNorm_',processList{side}))(:,i)); %Mean of per-fly calculated proportion of bouts containing antennal periodicity
            plotSEMs(1,i) = nanstd(flidStruct.pooled.(strcat('antBoutPerioDurPropNorm_',processList{side}))(:,i)) / sqrt(size(flidStruct.pooled.(strcat('antBoutPerioDurPropNorm_',processList{side}))(:,i),1));
        end
        %plotData(plotData == 0) = NaN; 

        barwitherr(plotSEMs,[1:size(splitDurs,2)],plotData, 'c')
    
        ax = gca;
        ax.XTickLabel = splitDursText;
        xlabel('Bout segment')
        ylabel(['Normalised duration prop. of bouts'])
        title(['Norm. duration prop. of bout segments containing ', processList{side}, ...
            ' periodicity (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) ')'])
        if size( flidStruct.pooled.(strcat('antBoutPerioDurPropNorm_',processList{side})),1 ) > 1
            barStats( flidStruct.pooled.(strcat('antBoutPerioDurPropNorm_',processList{side})) , alphaValue );
        end
    end
    
    %-----------------------------
        
    %Combined antennal data plot
        %Note: This is just an average of left and right data, not a measure of how much *any* perio was occurring
    if isempty( strfind( [processList{:}] , 'xLeft' ) ) ~= 1 && isempty( strfind( [processList{:}] , 'xRight' ) ) ~= 1
        %Averaged
        %{
        figure

        plotData = [];
        meanData = [];
        plotSEMs = [];
        a = 0;
        for side = 1:size(processList,2)
            if isempty( strfind( processList{side} , 'xLeft' ) ) ~= 1 || isempty( strfind( processList{side} , 'xRight' ) ) ~= 1
                for i = 1:size(splitDurs,2)
                    plotData( 1+a:size(flidStruct.pooled.(strcat('antBoutProp_',processList{side})),1)+a ,i) =  flidStruct.pooled.(strcat('antBoutProp_',processList{side}))(:,i); 
                end
                a = size(plotData,1);
            end
        end
        meanData = nanmean( plotData, 1 );
        plotSEMs = nanstd( plotData, [], 1 ) ./ sqrt( size(plotData,1) );

        barwitherr(plotSEMs,[1:size(splitDurs,2)],meanData)
        
        ax = gca;
        ylim([0 0.66])
        ax.XTickLabel = splitDursText;
        xlabel('Bout segment')
        ylabel(['Prop. of bouts'])
        title(['Prop. of bout segments containing averaged xLeft and xRight periodicity (of any Freq.) (SNRThresh: ',num2str(SNRThresh),')'])
        if size(plotData,1) > 1
            barStats(plotData,alphaValue);
        else
            disp(['-# Cannot barStats with only one fly #-'])
        end
        %}
        
        %Pooled (Borrows methods from pooled rolling sig likelihood plot/s)
            %In theory should yield the same plot, but with better significance
                    %In practice, significance is unchanged...
        rightSide = find( contains(processList,'xRight') );
        leftSide = find( contains(processList,'xLeft') );
        
        plotData = [];
        plotData = [ flidStruct.pooled.antBoutProp_xRight ];
        plotData = [ plotData ; flidStruct.pooled.antBoutProp_xLeft ];
        
        figure
        barwitherr( nanstd(plotData,[],1) ./ sqrt(size(plotData,1)) , nanmean(plotData,1) )
        ylim([0 0.66])
        xticklabels(splitDursText)
        xlabel('Bout segment')
        ylabel(['Prop. of bouts'])
        title(['Prop. of bout segments containing pooled xLeft and xRight periodicity (of any Freq.) (SNRThresh: ',num2str(SNRThresh),')'])
        barStats(plotData,alphaValue);
        set(gcf,'Name','Pooled ant segment props')
        if doSriBoxPlot == 1
            sriBoxPlot(plotData,alphaValue,splitDursText,0.2) %"Why Try"
            %Bruno recommendation supermerged plot
            if size(splitDurs,2) == 5
                %plotDataMerge = nan(size(plotData,1)*4,2);
                %plotDataMerge(:,1) = vertcat( plotData(:,1), plotData(:,2) ,  plotData(:,4) , plotData(:,5) );
                plotDataMerge = nan(size(plotData,1),2);
                plotDataMerge(1:size(plotData,1),1) = nanmean(plotData(:,[1,2,4,5]),2); %Average within fly
                plotDataMerge(1:size(plotData,1),2) = plotData(:,3);
                sriBoxPlot(plotDataMerge,alphaValue,[{'All other groups'},{'Midsleep'}],0.2)
            else
                ['-# Cannot do supermerged plot with non-four splitDurs #-'] %I mean, theoretically can do with any odd value, but unsafe
            end
        end
        
    end
    
    %-----------------------------
    
    %(_any plots disabled currently because of reasons listed in flidStruct processing)
    %{
    %Any periodicity bout prevalence (Mean of individual fly counts, SD from across flies)
        %Borrowed from above mostly
    %for side = 1:size(processList,2)
    figure

    plotData = [];
    meanData = [];
    plotSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(:,i) =  flidStruct.pooled.antBoutProp
        (:,i); %Mean of per-fly calculated proportion of bouts containing antennal periodicity
        meanData(i) = nanmean( plotData(:,i) );
        plotSEMs(1,i) = nanstd(flidStruct.pooled.antBoutProp_any(:,i)) / sqrt(size(flidStruct.pooled.antBoutProp_any(:,i),1));
    end
    %plotData(plotData == 0) = NaN; 

    barwitherr(plotSEMs,[1:size(splitDurs,2)],meanData)

    ax = gca;
    %ylim([0 0.66])
    ylim('auto')
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel(['Prop. of bouts'])
    title(['Prop. of bout segments containing any periodicity (of any Freq.) (SNRThresh: ',num2str(SNRThresh),')',char(10),'[Number validity unconfirmed]'])
    if size(plotData,1) > 1
        barStats(plotData,alphaValue);
    else
        disp(['-# Cannot barStats with only one fly #-'])
    end
    %end
    
    %-----------------------------
    
    %Any antennal periodicity bout duration (Mean of individual fly counts, SD from across flies)
    %for side = 1:size(processList,2)
    figure

    %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
    plotData = [];
    plotSEMs = [];
    for i = 1:size(splitDurs,2)
        plotData(:,i) =  nanmean(flidStruct.pooled.antBoutPerioDurPropNorm_any(:,i)); %Mean of per-fly calculated proportion of bouts containing antennal periodicity
        plotSEMs(1,i) = nanstd(flidStruct.pooled.antBoutPerioDurPropNorm_any(:,i)) / sqrt(size(flidStruct.pooled.antBoutPerioDurPropNorm_any(:,i),1));
    end

    barwitherr(plotSEMs,[1:size(splitDurs,2)],plotData, 'c')

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel(['Normalised duration prop. of bouts'])
    title(['Norm. duration prop. of bout segments containing any',...
        ' periodicity (F:',num2str(min(targetPerioFreqRange)), '-',num2str(max(targetPerioFreqRange)) ')'])
    if size( flidStruct.pooled.antBoutPerioDurPropNorm_any,1 ) > 1
        barStats( flidStruct.pooled.antBoutPerioDurPropNorm_any , alphaValue );
    end
    %end
    %}
    %-----------------------------
    
    %Sleep vs Wake perio. presence based on rollStruct
    overCount = repmat({nan(size(overFouri,2),4)},1,size(processList,2)); %Cells = Side -> Rows = Flies , Cols = Count/Total/Count/Total
    %overPeak = repmat( {{}} , 1 , size(processList,2) ); %Cells = Side -> Rows =  Cols = Peaks during wake/sleep respective
    overPeak = repmat({nan(size(overFouri,2),2)},1,size(processList,2)); %Cells = Side -> Rows = Flies , Cols = Av sig peak sleep/wake respective
    for IIDN = 1:size(overFouri,2)
        for side = 1:size(processList,2)
            thisPart = processList{side};
            thisCount = [0,0,0,0]; %[Sleep bins had sig, Total sleep bin count, Wake bins had sig, Wake bin count]
            thisPeak = nan( size(overFouri(IIDN).rollStruct,2) , 2 );
            for i = 1:size(overFouri(IIDN).rollStruct,2)
                if nanmean( overVar(IIDN).railStruct.sleepRail( overFouri(IIDN).rollStruct(i).(thisPart).inds , 1 ) ) > 0.5 %Find mean of sleep status during these rolling inds; "Sleeping"
                    if overFouri(IIDN).rollStruct(i).(thisPart).sigSNR > SNRThresh %"Significant peak found in this rolling window"
                        thisCount(1:2) = thisCount(1:2) + 1; %Increment both
                        thisPeak(i,1) = overFouri(IIDN).rollStruct(i).(thisPart).sigPeak;
                    else %Not sig
                        thisCount(2) = thisCount(2) + 1; %Only increment total
                    end
                else
                    if overFouri(IIDN).rollStruct(i).(thisPart).sigSNR > SNRThresh %"Significant peak found in this rolling window"
                        thisCount(3:4) = thisCount(3:4) + 1; %Increment both
                        thisPeak(i,2) = overFouri(IIDN).rollStruct(i).(thisPart).sigPeak;
                    else %Not sig
                        thisCount(4) = thisCount(4) + 1; %Only increment total
                    end
                end
            end
            overCount{side}(IIDN,:) = thisCount;
            overPeak{side}(IIDN,:) = nanmean( thisPeak,1 );
        end
    end
    %Plot
    figure
    for side = 1:size(processList,2)
        thisPart = processList{side};
        subplot( 1, size(processList,2) , side )
        thisRatioData = [ overCount{side}(:,1) ./ overCount{side}(:,2) , overCount{side}(:,3) ./ overCount{side}(:,4) ];
        errorbar( nanmean(thisRatioData,1) , nanstd(thisRatioData,[],1) ./ sqrt(size(thisRatioData,1)) )
        xlim([0.5,2.5])
        xticks([1:2])
        xticklabels([{'Sleep'},{'Wake'}])
        ylabel(['Likelihood of bout containing sig.'])
        yLim = get(gca,'YLim');
        if nanmax(yLim) < 0.5
            ylim([0,0.5]) %Basically an ugly way of autoranging to 0.5
        end
        title([thisPart,' bout sig likelihoods'])
        barStats(thisRatioData,alphaValue);
    end
    set(gcf,'Name','processList rolling sig likelihoods')
    %Pooled left and right antennal data
        %Note: Qualitatively similar to 'averaged' plots down below/above, except pooled for SEM reasons rather than flat averaged
    if nansum( contains(processList,'xRight') ) == 1 && nansum( contains(processList,'xLeft') ) == 1
        pooledAntPerioRollingData = [];
        rightSide = find( contains(processList,'xRight') );
        leftSide = find( contains(processList,'xLeft') );
        
        pooledAntPerioRollingData = [ overCount{rightSide}(:,1) ./ overCount{rightSide}(:,2) , overCount{rightSide}(:,3) ./ overCount{rightSide}(:,4) ];
        pooledAntPerioRollingData = [ pooledAntPerioRollingData ; overCount{leftSide}(:,1) ./ overCount{leftSide}(:,2) , overCount{leftSide}(:,3) ./ overCount{leftSide}(:,4) ];
        
        figure
        errorbar( nanmean(pooledAntPerioRollingData,1) , nanstd(pooledAntPerioRollingData,[],1) ./ sqrt(size(pooledAntPerioRollingData,1)) )
        xlim([0.5,2.5])
        xticks([1:2])
        xticklabels([{'Sleep'},{'Wake'}])
        ylabel(['Likelihood of bout containing sig.'])
        yLim = get(gca,'YLim');
        if nanmax(yLim) < 0.5
            ylim([0,0.5]) %Basically an ugly way of autoranging to 0.5
        end
        title(['Pooled left/right ant. bout sig likelihoods (SNRThresh: ',num2str(SNRThresh),'SD)'])
        barStats(pooledAntPerioRollingData,alphaValue);
        set(gcf,'Name','Pooled ant rolling sig likelihoods')
        if doSriBoxPlot == 1
            sriBoxPlot(pooledAntPerioRollingData,alphaValue,[{'Sleep'},{'Wake'}],0.2,[0,0,1;1,0,0],[], [] ,[], 1) %"Why Try"            
        end
    end
    
    %Plot signal peaks
    figure
    for side = 1:size(processList,2)
        thisPart = processList{side};
        subplot( 1, size(processList,2) , side )
        %thisRatioData = [ overCount{side}(:,1) ./ overCount{side}(:,2) , overCount{side}(:,3) ./ overCount{side}(:,4) ];
        errorbar( nanmean(overPeak{side},1) , nanstd(overPeak{side},[],1) ./ sqrt(size(overPeak{side},1)) )
        xlim([0.5,2.5])
        xticks([1:2])
        xticklabels([{'Sleep'},{'Wake'}])
        ylabel(['Mean freq. (Hz)'])
        %yLim = get(gca,'YLim');
        %if nanmax(yLim) < 0.5
        %    ylim([0,0.5]) %Basically an ugly way of autoranging to 0.5
        %end
        ylim([nanmin(F),ceilHz])
        title([thisPart,' bout sig peaks'])
        barStats(overPeak{side},alphaValue);
    end
    set(gcf,'Name','processList rolling sig peaks')
    %Pooled left and right antennal data
        %Note: Qualitatively similar to 'averaged' plots down below/above, except pooled for SEM reasons rather than flat averaged
    if nansum( contains(processList,'xRight') ) == 1 && nansum( contains(processList,'xLeft') ) == 1
        pooledAntPerioRollingPeak = [];
        rightSide = find( contains(processList,'xRight') );
        leftSide = find( contains(processList,'xLeft') );
        
        pooledAntPerioRollingPeak = [ overPeak{rightSide} ];
        pooledAntPerioRollingPeak = [ pooledAntPerioRollingPeak ; overPeak{leftSide} ];
        
        figure
        errorbar( nanmean(pooledAntPerioRollingPeak,1) , nanstd(pooledAntPerioRollingPeak,[],1) ./ sqrt(size(pooledAntPerioRollingPeak,1)) )
        xlim([0.5,2.5])
        xticks([1:2])
        xticklabels([{'Sleep'},{'Wake'}])
        ylabel(['Freq. (Hz)'])
        ylim([nanmin(F),ceilHz])
        title(['Pooled left/right ant. bout sig peak (Hz)'])
        barStats(pooledAntPerioRollingPeak,alphaValue);
        set(gcf,'Name','Pooled ant rolling sig peaks')
        if doSriBoxPlot == 1
            sriBoxPlot(pooledAntPerioRollingPeak,alphaValue,[{'Sleep'},{'Wake'}],0.2,[0,0,1;1,0,0],[], [] ,[], 1) %"Why Try"            
        end
    end
    
    %-----------------------------
    
    %Proboscis extension bout duration (Mean of individual fly counts, SD from across flies)
    figure

    %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
    plotData = [];
    plotSEMs = [];
    for i = 1:size(splitDurs,2)
        %plotData(:,i) =  nanmean(flidStruct.pooled.peBoutDur(:,i)); 
        %plotSEMs(1,i) = nanstd(flidStruct.pooled.peBoutDur(:,i)) / sqrt(size(flidStruct.pooled.peBoutDur(:,i),1));
        %%plotData(:,i) =  nanmean(flidStruct.pooled.combBout{i}(:,12));
        %%plotSEMs(1,i) = nanstd(flidStruct.pooled.combBout{i}(:,12)) / sqrt(size((flidStruct.pooled.combBout{i}(:,12)),1));
            %Note: Hardcoded 12th column only valid with full sized processList
            %Secondary note: 12th col may be incorrectly pointing to PE number, not duration
        plotData(:,i) =  nanmean(flidStruct.pooled.combBout{i}(:,combBoutDurPEsCol));
        plotSEMs(1,i) = nanstd(flidStruct.pooled.combBout{i}(:,combBoutDurPEsCol)) / sqrt(size((flidStruct.pooled.combBout{i}(:,combBoutDurPEsCol)),1));
    end
    %plotData(plotData == 0) = NaN; 

    barwitherr(plotSEMs,[1:size(splitDurs,2)],plotData)

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel(['Duration prop. of PE'])
    title(['Mean dur. of PE in bout segments'])
    %{
    %Stats currently too complex to implement for this graph
    if size( flidStruct.pooled.combBout{i} ,1 ) > 1 %Note: Relates here to pooled bouts, not number of flies
        barStats( flidStruct.pooled.combBout{i}(:,combBoutDurPEsCol) , alphaValue )
    end
    %}
    
    
    %-----------------------------
    
    %Normalised proboscis extension bout duration (Mean of individual fly counts, SD from across flies)
    figure

    %plotData = zeros(size(flidStruct.pooled.combBout{1},1),size(splitDurs,2));
    preData = [];
    plotData = [];
    plotSEMs = [];
    for i = 1:size(splitDurs,2)
        %plotData(:,i) =  nanmean(flidStruct.pooled.peBoutDurNorm(:,i)); 
        %plotSEMs(1,i) = nanstd(flidStruct.pooled.peBoutDurNorm(:,i)) / sqrt(size(flidStruct.pooled.peBoutDurNorm(:,i),1));
        for x = 1:size(flidStruct.pooled.combBout{i})
            %preData(x,i) = flidStruct.pooled.combBout{i}(x,12) / flidStruct.pooled.combBout{i}(x,2);
            preData(x,i) = flidStruct.pooled.combBout{i}(x,combBoutDurPEsCol) / flidStruct.pooled.combBout{i}(x,2); 
                %Note: Theoretically combBoutDurPEsCol is IIDN-specific, but it will only ever be an issue if processList varies between individuals
        end
        plotData(:,i) = nanmean(preData(:,i)); 
        plotSEMs(1,i) = nanstd(preData(:,i)) / sqrt(size(preData(:,i),1));
    end
    %plotData(plotData == 0) = NaN; 

    barwitherr(plotSEMs,[1:size(splitDurs,2)],plotData, 'c')

    ax = gca;
    ax.XTickLabel = splitDursText;
    xlabel('Bout segment')
    ylabel(['Normalised duration prop. of PE'])
    title(['Norm. mean duration prop. of PE in bout segments'])
    if size( preData,1 ) > 1
        barStats( preData , alphaValue );
    end
    
    %-----------------------------
    
    %PE LOCs graphs
    upperPEFreqLimit = 1/probInterval;
    %lowerPEFreqLimit = 0.1;%Caution: Arbitrary
    lowerPEFreqLimit = 1 / (probInterval*contiguityThreshold);%Caution: Slightly less arbitrary (Based on spell contiguity parameters)
    peLOCsPerioStruct = struct;
    %Individual
    for IIDN = 1:size(overVar,2)
        
        %Split
        for split = 1:size(overVar(IIDN).splitStruct.FLID,2)
            thisSplitPEs = find( overAllPE(IIDN).allPEStruct.allPERail( overVar(IIDN).splitStruct.holeRanges{split} ,2) == 1 ) + overVar(IIDN).splitStruct.holeStarts(split);
                %Addition of holeStarts coord is necessary to put find coords in right reference frame
            if isempty( thisSplitPEs ) ~= 1
                thisPEsDiff = diff(thisSplitPEs);
                thisPEsDiffFreq = 1 ./ (thisPEsDiff ./ overVar(IIDN).dataFrameRate);
                thisPEsDiffFreq( thisPEsDiffFreq > upperPEFreqLimit) = NaN; %Remove too-fast PE freqs
                thisPEsDiffFreq( thisPEsDiffFreq < lowerPEFreqLimit) = NaN; %Remove too slow freqs

                peLOCsPerioStruct.individual(IIDN).splitPEPerio{ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) } = ...
                    thisPEsDiffFreq; %Calculated freq. between detected PEs in this split
                peLOCsPerioStruct.individual(IIDN).splitPEPerioFreqMean( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    nanmean( thisPEsDiffFreq ); %Mean of above, for simplicity
                peLOCsPerioStruct.individual(IIDN).splitPEPerioPEFrac( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    nansum( ~isnan( thisPEsDiffFreq ) ) / size( thisPEsDiffFreq,1 ); %What fraction of PE differences were periodic (Note: Technically one less than PE number, because diff)
                peLOCsPerioStruct.individual(IIDN).splitPEPerioBoutFrac( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    nansum(thisPEsDiff(~isnan(thisPEsDiffFreq))) / overVar(IIDN).splitStruct.holeSizes(split); %What fraction of this split bout was PE LOCs perio.
                
                peLOCsPerioStruct.individual(IIDN).splitPEPerioBoutNum( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    size(thisPEsDiff(~isnan(thisPEsDiffFreq)),1); %How many perio PE LOCS occurred in bout segment (Note: Not normalised by time)
                peLOCsPerioStruct.individual(IIDN).splitPEBoutNum( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    size(thisSplitPEs,1); %How many total PE LOCS in this bout segment (Note: Not normalised by time)
            else
                peLOCsPerioStruct.individual(IIDN).splitPEPerio{ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) } = ...
                    [];
                peLOCsPerioStruct.individual(IIDN).splitPEPerioFreqMean( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    NaN;
                peLOCsPerioStruct.individual(IIDN).splitPEPerioPEFrac( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    NaN;
                peLOCsPerioStruct.individual(IIDN).splitPEPerioBoutFrac( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    0;
                
                peLOCsPerioStruct.individual(IIDN).splitPEPerioBoutNum( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    0;
                peLOCsPerioStruct.individual(IIDN).splitPEBoutNum( overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) ) = ...
                    0;
            end
        end
        
        %Wake vs Sleep
        states = unique( overVar(IIDN).railStruct.sleepRail(:,1) );
        peLOCsPerioStruct.ancillary.states = states;
        for statInd = 1:size(states,1)
            thisState = states(statInd);
            statePELOCs = find( overVar(IIDN).railStruct.sleepRail(:,1) == thisState & overAllPE(IIDN).allPEStruct.allPERail(:,2) == 1 );
            
            statePELOCsDiff = diff( statePELOCs );
            statePELOCsDiff( statePELOCsDiff < (1/upperPEFreqLimit)*overVar(IIDN).dataFrameRate ) = NaN; %Remove too-fast PEs
            statePELOCsDiff( statePELOCsDiff > (1/lowerPEFreqLimit)*overVar(IIDN).dataFrameRate ) = NaN; %Remove too slow PE gaps
            
            statePELOCsDiffFreq = 1 ./ (statePELOCsDiff./overVar(IIDN).dataFrameRate);
            
            peLOCsPerioStruct.individual(IIDN).statePEPerio{statInd} = statePELOCsDiffFreq;
            peLOCsPerioStruct.individual(IIDN).statePEPerioFreqMean(statInd) = nanmean( statePELOCsDiffFreq );
            peLOCsPerioStruct.individual(IIDN).statePEPerioPEFrac(statInd) = nansum( ~isnan( statePELOCsDiffFreq ) ) / size( statePELOCsDiffFreq,1 );
            peLOCsPerioStruct.individual(IIDN).statePEPerioStateFrac(statInd) = nansum(statePELOCsDiff(~isnan(statePELOCsDiffFreq))) / nansum( overVar(IIDN).railStruct.sleepRail(:,1) == thisState );
            
        end
        
        
    end
    
    %Pooled
    peLOCsPerioStruct.pooled.splitPEPerioFreqMean = nan( size(overVar,2) , size(splitDurs,2) ); %Freq means of PE LOCs within specified bounds
    peLOCsPerioStruct.pooled.splitPEPerioBoutFrac = zeros( size(overVar,2) , size(splitDurs,2) ); %Fraction of bouts that was PE LOC periodicity
    peLOCsPerioStruct.pooled.splitPEPerioPEFrac = nan( size(overVar,2) , size(splitDurs,2) ); %Fraction of PEs within bouts that were periodic
        %Note: With large lower bounds for freq (i.e. 0.05Hz), the time allowed for a PE to be considered periodic may approach the length of the split segment itself
            %In effect, any more than one PE in a bout is likely to fall within the definition of "periodicity"
   
    peLOCsPerioStruct.pooled.splitPEPerioBoutNum = zeros( size(overVar,2) , size(splitDurs,2) ); %How many perio PE LOCS occurred in bout segment (Note: Not normalised by time)
    peLOCsPerioStruct.pooled.splitPEBoutNum = zeros( size(overVar,2) , size(splitDurs,2) ); %How many total PE LOCS in this bout segment (Note: Not normalised by time)
        %Note: The latter will usually be the former+1 here, unless PEs were very spaced
            
    %Split
    for IIDN = 1:size(overVar,2)
        peLOCsPerioStruct.pooled.splitPEPerioFreqMean( IIDN, : ) = nanmean( peLOCsPerioStruct.individual(IIDN).splitPEPerioFreqMean , 1 );
        peLOCsPerioStruct.pooled.splitPEPerioBoutFrac( IIDN, : ) = nanmean( peLOCsPerioStruct.individual(IIDN).splitPEPerioBoutFrac , 1 );
        peLOCsPerioStruct.pooled.splitPEPerioPEFrac( IIDN, : ) = nanmean( peLOCsPerioStruct.individual(IIDN).splitPEPerioPEFrac , 1 );
        
        peLOCsPerioStruct.pooled.splitPEPerioBoutNum( IIDN, : ) = nanmean( peLOCsPerioStruct.individual(IIDN).splitPEPerioBoutNum , 1 );
        peLOCsPerioStruct.pooled.splitPEBoutNum( IIDN, : ) = nanmean( peLOCsPerioStruct.individual(IIDN).splitPEBoutNum , 1 ); %CBF adding these to state-specificity atm
    end
    
    %States
    for IIDN = 1:size(overVar,2)
        peLOCsPerioStruct.pooled.statePEPerioFreqMean( IIDN, : ) = peLOCsPerioStruct.individual(IIDN).statePEPerioFreqMean;
        peLOCsPerioStruct.pooled.statePEPerioPEFrac( IIDN, : ) = peLOCsPerioStruct.individual(IIDN).statePEPerioPEFrac;
        peLOCsPerioStruct.pooled.statePEPerioStateFrac( IIDN, : ) = peLOCsPerioStruct.individual(IIDN).statePEPerioStateFrac;
    end
    
    
    %Plot splits
    %Bout fracs
    figure
    bar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioBoutFrac , 1 ) )
    hold on
    errorbar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioBoutFrac , 1 ) , nanstd(peLOCsPerioStruct.pooled.splitPEPerioBoutFrac , [], 1) ./ sqrt( size( peLOCsPerioStruct.pooled.splitPEPerioBoutFrac , 1 ) ) )
    for split = 1:size(splitDurs,2)
        scatter( repmat( [split] , size(overVar,2) , 1 ) , peLOCsPerioStruct.pooled.splitPEPerioBoutFrac(:,split) )
    end
    xticklabels(splitDursText)
    xlabel(['Bout segment'])
    title(['Fraction of bout segments that was PE LOCs perio.'])
    set(gcf,'Name', 'Pooled PE LOCs perio bout frac')
    if size( peLOCsPerioStruct.pooled.splitPEPerioBoutFrac,1 ) > 1
        try
            barStats( peLOCsPerioStruct.pooled.splitPEPerioBoutFrac , alphaValue );
        end
    end
    if doSriBoxPlot == 1
        sriBoxPlot(peLOCsPerioStruct.pooled.splitPEPerioBoutFrac,alphaValue,splitDursText,0.2,[],[],[],[],1) %"Why Try"            
        %Bruno recommendation supermerged plot
        plotData = peLOCsPerioStruct.pooled.splitPEPerioBoutFrac;
        if size(splitDurs,2) == 5
            %plotDataMerge = nan(size(plotData,1)*4,2);
            %plotDataMerge(:,1) = vertcat( plotData(:,1), plotData(:,2) ,  plotData(:,4) , plotData(:,5) ); %Keep all
            plotDataMerge = nan(size(plotData,1),2);
            plotDataMerge(1:size(plotData,1),1) = nanmean(plotData(:,[1,2,4,5]),2); %Average within fly
            plotDataMerge(1:size(plotData,1),2) = plotData(:,3);
            sriBoxPlot(plotDataMerge,alphaValue,[{'All other groups'},{'Midsleep'}],0.2)
        else
            ['-# Cannot do supermerged plot with non-four splitDurs #-'] %I mean, theoretically can do with any odd value, but unsafe
        end
        plotData = [];
    end
    
    %Bout freq means
    figure
    bar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioFreqMean , 1 ) )
    hold on
    errorbar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioFreqMean , 1 ) , nanstd(peLOCsPerioStruct.pooled.splitPEPerioFreqMean , [], 1) ./ sqrt( size( peLOCsPerioStruct.pooled.splitPEPerioFreqMean , 1 ) ) )
    for split = 1:size(splitDurs,2)
        scatter( repmat( [split] , size(overVar,2) , 1 ) , peLOCsPerioStruct.pooled.splitPEPerioFreqMean(:,split) )
    end
    xticklabels(splitDursText)
    xlabel(['Bout segment'])
    title(['Mean freq. of PE LOCs perio. (>',num2str(lowerPEFreqLimit),'Hz & <',num2str(upperPEFreqLimit),'Hz)'])
    set(gcf,'Name', 'Pooled PE LOCs perio freqs')
    if size( peLOCsPerioStruct.pooled.splitPEPerioFreqMean,1 ) > 1
        try
            barStats( peLOCsPerioStruct.pooled.splitPEPerioFreqMean , alphaValue );
        end
    end
    
    %PE fracs
    figure
    bar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioPEFrac , 1 ) )
    hold on
    errorbar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioPEFrac , 1 ) , nanstd(peLOCsPerioStruct.pooled.splitPEPerioPEFrac , [], 1) ./ sqrt( size( peLOCsPerioStruct.pooled.splitPEPerioPEFrac , 1 ) ) )
    for split = 1:size(splitDurs,2)
        scatter( repmat( [split] , size(overVar,2) , 1 ) , peLOCsPerioStruct.pooled.splitPEPerioPEFrac(:,split) )
    end
    xticklabels(splitDursText)
    xlabel(['Bout segment'])
    title(['Fraction of PEs within bout segment that were periodic'])
    set(gcf,'Name', 'Pooled PE LOCs PE perio frac')
    if size( peLOCsPerioStruct.pooled.splitPEPerioPEFrac ,1 ) > 1
        try
            barStats( peLOCsPerioStruct.pooled.splitPEPerioPEFrac , alphaValue );
        end
    end
    
    %Num of periodic PE LOCs in bout segments
    figure
    bar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioBoutNum , 1 ) )
    hold on
    errorbar( nanmean( peLOCsPerioStruct.pooled.splitPEPerioBoutNum , 1 ) , nanstd(peLOCsPerioStruct.pooled.splitPEPerioBoutNum , [], 1) ./ sqrt( size( peLOCsPerioStruct.pooled.splitPEPerioBoutNum , 1 ) ) )
    for split = 1:size(splitDurs,2)
        scatter( repmat( [split] , size(overVar,2) , 1 ) , peLOCsPerioStruct.pooled.splitPEPerioBoutNum(:,split) )
    end
    xticklabels(splitDursText)
    xlabel(['Bout segment'])
    title(['Number of periodic PE LOCS in bout segment'])
    set(gcf,'Name', 'Pooled perio PE LOCs num')
    if size( peLOCsPerioStruct.pooled.splitPEPerioBoutNum,1 ) > 1
        try
            barStats( peLOCsPerioStruct.pooled.splitPEPerioBoutNum , alphaValue );
        end
    end
    if doSriBoxPlot == 1
        sriBoxPlot(peLOCsPerioStruct.pooled.splitPEPerioBoutNum,alphaValue,splitDursText,0.2,[],[],[],[],1) %"Why Try" 
    end
    
    %Num of PE LOCs in bout segments (Periodic or not)
    figure
    bar( nanmean( peLOCsPerioStruct.pooled.splitPEBoutNum , 1 ) )
    hold on
    errorbar( nanmean( peLOCsPerioStruct.pooled.splitPEBoutNum , 1 ) , nanstd(peLOCsPerioStruct.pooled.splitPEBoutNum , [], 1) ./ sqrt( size( peLOCsPerioStruct.pooled.splitPEBoutNum , 1 ) ) )
    for split = 1:size(splitDurs,2)
        scatter( repmat( [split] , size(overVar,2) , 1 ) , peLOCsPerioStruct.pooled.splitPEBoutNum(:,split) )
    end
    xticklabels(splitDursText)
    xlabel(['Bout segment'])
    title(['Total number of PE LOCS in bout segment'])
    set(gcf,'Name', 'Pooled PE LOCs raw num')
    if size( peLOCsPerioStruct.pooled.splitPEBoutNum,1 ) > 1
        try
            barStats( peLOCsPerioStruct.pooled.splitPEBoutNum , alphaValue );
        end
    end
    if doSriBoxPlot == 1
        sriBoxPlot(peLOCsPerioStruct.pooled.splitPEBoutNum,alphaValue,splitDursText,0.2,[],[],[],[],1) %"Why Try" 
    end
    
    %Plot states
    %scatCoords = repmat( [1:size(states,1)] , 1 , size(overVar,2) )'; %INCORRECT
    scatCoords = repmat( [1:size(states,1)] , size(overVar,2) , 1 ); %Correct
    %State freq means
    figure
    plotData = nanmean( peLOCsPerioStruct.pooled.statePEPerioFreqMean , 1 );
    bar( plotData )
    hold on
    errorbar( plotData , nanstd(peLOCsPerioStruct.pooled.statePEPerioFreqMean,[],1) ./ sqrt( size(peLOCsPerioStruct.pooled.statePEPerioFreqMean,1) ) )
    scatter( scatCoords(:) , peLOCsPerioStruct.pooled.statePEPerioFreqMean(:) )
    %Add ancillary text
    for texInd = 1:size(scatCoords,2)
        for IIDN = 1:size(peLOCsPerioStruct.pooled.statePEPerioFreqMean,1)
            text(texInd+0.1,peLOCsPerioStruct.pooled.statePEPerioFreqMean(IIDN,texInd),num2str(IIDN),'Color','r')
        end
    end
    xticklabels(states)
    xlabel(['State'])
    ylabel(['Freq. (Hz)'])
    title(['Frequency of PE periodicity within states'])
    set(gcf,'Name', 'Pooled states PE LOCs PE perio freq')
    if size(peLOCsPerioStruct.pooled.statePEPerioFreqMean,1) > 1
        try
            barStats(peLOCsPerioStruct.pooled.statePEPerioFreqMean,alphaValue);
        end
    end
    if doSriBoxPlot == 1
        sriBoxPlot(peLOCsPerioStruct.pooled.statePEPerioFreqMean,alphaValue,states,0.2,[0,0,1;1,0,0],[],[],[],1)
    end
    plotData = [];
    
    %State PE fracs
    figure
    plotData = nanmean( peLOCsPerioStruct.pooled.statePEPerioStateFrac , 1 );
    bar( plotData )
    hold on
    errorbar( plotData , nanstd(peLOCsPerioStruct.pooled.statePEPerioStateFrac,[],1) ./ sqrt( size(peLOCsPerioStruct.pooled.statePEPerioStateFrac,1) ) )
    %scatCoords = repmat( [1:size(states,1)] , 1 , size(overVar,2) )'; %INCORRECT
    scatCoords = repmat( [1:size(states,1)] , size(overVar,2) , 1 ); %Correct
    scatter( scatCoords(:) , peLOCsPerioStruct.pooled.statePEPerioStateFrac(:) )
    %Add ancillary text
    for texInd = 1:size(scatCoords,2)
        for IIDN = 1:size(peLOCsPerioStruct.pooled.statePEPerioStateFrac,1)
            text(texInd+0.1,peLOCsPerioStruct.pooled.statePEPerioStateFrac(IIDN,texInd),num2str(IIDN),'Color','r')
        end
    end
    xticklabels(states)
    xlabel(['State'])
    ylabel(['Fraction'])
    title(['Fraction of state with PE LOCs periodicity'])
    set(gcf,'Name', 'Pooled states PE LOCs state perio frac')
    if size(peLOCsPerioStruct.pooled.statePEPerioStateFrac,1) > 1
        try
            barStats(peLOCsPerioStruct.pooled.statePEPerioStateFrac,alphaValue);
        end
    end
    if doSriBoxPlot == 1
        sriBoxPlot(peLOCsPerioStruct.pooled.statePEPerioStateFrac,alphaValue,[{'0'},{'1'}],0.2,[1,0,0;0,0,1],[],[],[], 1) %"Why Try"            
    end
    plotData = [];
    
    %PE periodic fracs in state
    figure
    plotData = nanmean( peLOCsPerioStruct.pooled.statePEPerioPEFrac , 1 );
    bar( plotData )
    hold on
    errorbar( plotData , nanstd(peLOCsPerioStruct.pooled.statePEPerioPEFrac,[],1) ./ sqrt( size(peLOCsPerioStruct.pooled.statePEPerioPEFrac,1) ) )
    %scatCoords = repmat( [1:size(states,1)] , 1 , size(overVar,2) )'; %INCORRECT
    scatCoords = repmat( [1:size(states,1)] , size(overVar,2) , 1 ); %Correct
    scatter( scatCoords(:) , peLOCsPerioStruct.pooled.statePEPerioPEFrac(:) )
    %Add ancillary text
    for texInd = 1:size(scatCoords,2)
        for IIDN = 1:size(peLOCsPerioStruct.pooled.statePEPerioPEFrac,1)
            text(texInd+0.1,peLOCsPerioStruct.pooled.statePEPerioPEFrac(IIDN,texInd),num2str(IIDN),'Color','r')
        end
    end
    xticklabels(states)
    xlabel(['State'])
    ylabel(['Fraction'])
    title(['Fraction of state PEs that were periodic'])
    set(gcf,'Name', 'Pooled states PE LOCs PE perio frac')
    if size(peLOCsPerioStruct.pooled.statePEPerioPEFrac,1) > 1
        try
            barStats(peLOCsPerioStruct.pooled.statePEPerioPEFrac,alphaValue);
        end
    end
    if doSriBoxPlot == 1
        sriBoxPlot(peLOCsPerioStruct.pooled.statePEPerioPEFrac,alphaValue,states,0.2,[0,0,1;1,0,0],[],[],[],1)
    end
    plotData = [];

    %-----------------------------
    
    %Ant. perio. freq splits
    antPerioStruct = struct;
    for IIDN = 1:size(overVar,2)
        %As = zeros(1,size(processList,2));
        %Collect all
        for split = 1:size(overVar(IIDN).splitStruct.FLID,2)
            %As = zeros(1,size(processList,2));
            for side = 1:size(processList,2)
                thisSplitAntFreqs = ...
                    overVar(IIDN).railStruct.sleepRail( ...
                    find( overVar(IIDN).railStruct.sleepRail( overVar(IIDN).splitStruct.holeRanges{split} , 2+side*2 ) == 1 ) + overVar(IIDN).splitStruct.holeStarts(split) -1 ...
                    , 3+side*2 );
                if isempty(thisSplitAntFreqs) ~= 1
                    %temp = [As(side)+1 : As(side)+size(thisSplitAntFreqs,1)];
                    %antPerioStruct.individual(IIDN).( strcat('split',processList{side},'Perio') ){ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) }(temp,1) = thisSplitAntFreqs;
                    %antPerioStruct.individual(IIDN).( strcat('split',processList{side},'Perio') ){ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) } = thisSplitAntFreqs; 
                    antPerioStruct.( strcat('split',processList{side},'Perio') ).individual{IIDN}{ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) } = thisSplitAntFreqs; %Rearrangement of grand architecture
                    %As(side) = As(side) + size(thisSplitAntFreqs,1);
                else
                    %antPerioStruct.individual(IIDN).( strcat('split',processList{side},'Perio') ){ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) }(As(side)+1,1) = NaN;
                    %antPerioStruct.individual(IIDN).( strcat('split',processList{side},'Perio') ){ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) } = NaN;
                    antPerioStruct.( strcat('split',processList{side},'Perio') ).individual{IIDN}{ overVar(IIDN).splitStruct.FLID(1,split) , overVar(IIDN).splitStruct.FLID(2,split) } = NaN; %Rearrangement of grand architecture
                    %As(side) = As(side) + 1;
                end
            end
        end

        %Pool and mean within split
        for side = 1:size(processList,2)
            for splitSeg = 1:size( antPerioStruct.( strcat('split',processList{side},'Perio') ).individual{IIDN},2 )
                antPerioStruct.( strcat('split',processList{side},'Perio') ).pooled(IIDN,splitSeg) = ...
                    nanmean( cell2mat( antPerioStruct.( strcat('split',processList{side},'Perio') ).individual{IIDN}(:,splitSeg) ) );
            end
        end
        
    end
    
    %Plot (Separated by side)
    pooledPlotData = [];
    figure
    for side = 1:size(processList,2)
        subplot(1,size(processList,2),side)
        plotData = antPerioStruct.( strcat('split',processList{side},'Perio') ).pooled;
        pooledPlotData = [pooledPlotData; plotData]; %Will fail horribly if dimensions different between sides and/or individuals
        bar( nanmean( plotData , 1 ) )
        hold on
        errorbar( nanmean( plotData , 1 ) , nanstd( plotData , [], 1 ) ./ sqrt(size(plotData,1)) )
        %scatCoords = repmat( [1:size(plotData,2)] , 1 , size(plotData,2) )';
        %scatter( scatCoords(:) , plotData(:) )
        xticklabels(splitDursText)
        xlabel(['Bout segment'])
        ylabel(['Freq. (Hz)'])
        title(['Mean freq. of ',processList{side},' perio.'])
        set(gcf,'Name', [processList{side},' perio freqs'])
        if size( plotData,1 ) > 1
            try
                barStats( plotData , alphaValue );
            end
        end
        plotData = [];
    end
    
    %Pooled left and right antenna (If applicable)
    if isempty( strfind( [processList{:}] , 'xLeft' ) ) ~= 1 && isempty( strfind( [processList{:}] , 'xRight' ) ) ~= 1
        
        rightSide = find( contains(processList,'xRight') );
        leftSide = find( contains(processList,'xLeft') );
        
        plotData = [];
        plotData = [ antPerioStruct.splitxRightPerio.pooled ];
        plotData = [ plotData ; antPerioStruct.splitxLeftPerio.pooled ];
        
        figure
        barwitherr( nanstd(plotData,[],1) ./ sqrt(size(plotData,1)) , nanmean(plotData,1) )
        ylim([0 0.66])
        xticklabels(splitDursText)
        xlabel('Bout segment')
        ylabel(['Freq. (Hz)'])
        title(['Mean freq. of pooled left/right antennal perio. across bout segments'])
        barStats(plotData,alphaValue);
        set(gcf,'Name','Pooled ant segment freqs')
    end
    
    %Plot (Pooled)
    figure
    bar( nanmean( pooledPlotData , 1 ) )
    hold on
    errorbar( nanmean( pooledPlotData , 1 ) , nanstd( pooledPlotData , [], 1 ) ./ sqrt(size(pooledPlotData,1)) ) %Is this still valid given that flies are effectively being sampled twice?
    xticklabels(splitDursText)
    xlabel(['Bout segment'])
    ylabel(['Freq. (Hz)'])
    title(['Mean freq. of all perio. (across sides)'])
    set(gcf,'Name', ['All perio freqs'])
    if size( plotData,1 ) > 1
        try
            barStats( pooledPlotData , alphaValue );
        end
    end
    pooledPlotData = [];
    
    %-----------------------------
    
end
%--------------------------------------------------------------------------

%Plot duration metrics
if doDurs == 1
    
    %Plot bout occurence times according to binned duration of bout
    figure
    %plotData = [];
    for bin = 1:size(durBins,2)-1
        subplot(1,size(durBins,2)-1,bin)
        binName = strcat(['bin_', num2str(durBins(bin)),'to',num2str(durBins(bin+1))]);
        %plotData(bin) = nanmedian(sleepStruct.durSubStruct.(binName).boutTimes);
        hist(sleepStruct.durSubStruct.(binName).boutTimes,24);
        hold on
        xlim([0,24])
        set(gca,'XTick',(0:4:24))
        xlabel(['Time (24h)'])
        title(['Bout start time for duration ', strrep(binName,'_',' ')])
    end
        
    %Plot significant periodicity freq. positions according to binned duration of bout
    for side = 1:size(processList,2)
        figure
        plotData = [];
        nanMedians = [];
        nanSEMs = [];
        exTicks = [];
        for bin = 1:size(durBins,2)-1
            binName = strcat(['bin_', num2str(durBins(bin)),'to',num2str(durBins(bin+1))]);
            binNameLabel = strcat([num2str(durBins(bin)),' to ',num2str(durBins(bin+1)),'s']); %Ditto, but lacking an underscore because that causes label troubles
            exTicks{bin} = binNameLabel;
            plotData{bin} = sleepStruct.durSubStruct.(binName).(strcat('antPerioFreqPos_',processList{side}));
            nanMedians(bin) = nanmedian(plotData{bin});
            nanSEMs(bin) = nanstd(plotData{bin}) / sqrt(size(plotData{bin},1));
        end
        
        barwitherr(nanSEMs,[1:size(durBins,2)-1],nanMedians)

        xlabel('Bin')
        ax = gca;
        ax.XTickLabel = exTicks;
        ylabel(['Median freq. pos. (Hz)'])
        
        title(['Median of all detected ', processList{side}, ' freq. pos. for duration bins'])
        for i = 1:size(plotData,2)
            xVal = [i];
            %yVal = [nanMeans(i) + 0.05];
            yVal = [nanMedians(i) + 0.05];
            textVal = [nansum(isnan(plotData{i}) ~= 1)];
            text([xVal], [yVal], [num2str(textVal)], 'Color', 'r');
        end
        
    end
    
end

%--------------------------------------------------------------------------

if suppressIndivPlots ~= 1
    %Bout/PE/Ant binary plots
        %Note: PEs are across entire time, periodicity is only across sleep
        %(Due to allPERail vs sleepRail differences)
    %Construct custom colormap
    cutDownColorMap = [0,0,1; 0,1,0; 1,0,1; 1,1,0; 0,1,1; 1,0,0];

    for IIDN = 1:size(overVar,2)
        imageStruct = struct;
        a = 1;

        figure

        %Prepare X axis
        xTimesProc = overVar(IIDN).overGlob.firstBaseFrameTimeTimeDate;
        for i = 1:size(xTimesProc,1)
            xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
        end

        %Plot sleep/wake
        subplot(size(processList,2)+3,1,1)
        plotData = overVar(IIDN).railStruct.sleepRail(:,1)'; %Manual scaling in case of binary failure
        %imagesc(plotData)
        %colormap(gca,parula);
        colormap(gca,[0,0,0; cutDownColorMap(1,:)]);
        plotImage = imagesc(plotData);
        %------------------
        imageStruct(a).XData = plotImage.XData;
        imageStruct(a).YData = [a];
        imageStruct(a).CData = plotImage.CData;
        a = a + 1;
        %------------------    
        ax = gca;
        ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
        ax.XTickLabel = [xTimesProc];
        xlabel('Time of day (24h)')
        title([strrep(overVar(IIDN).fileDate, '_', ' '),' sleep/wake bouts'])
        hold off

        %Plot all PE binary
        subplot(size(processList,2)+3,1,2)
        preData = overAllPE(IIDN).allPEStruct.allPERail(:,2)'; %All PEs, regardless of bout or non-bout (Point occurences)
        plotData = zeros(1, size(preData,2));
        peCoords = find(preData == 1);
        for i = 1:size(peCoords,2)
            peExpansionCoords = [peCoords(i) - floor( peBinaryExpansionFactor*probInterval*overVar(IIDN).dataFrameRate ) : peCoords(i) + floor( peBinaryExpansionFactor*probInterval*overVar(IIDN).dataFrameRate)];
            peExpansionCoords( peExpansionCoords < 1 ) = 1;
            peExpansionCoords( peExpansionCoords > size(plotData,2) ) = size(plotData,2);
            plotData( 1 , peExpansionCoords ) = 1;
                %'Expands' point occurences of PEs in allPERail to be events
        end
        %Quick QA
        if size(overAllPE(IIDN).allPEStruct.allPERail(:,2)',2) ~= size(overVar(IIDN).railStruct.sleepRail(:,3)',2)
            ['## Warning: Dissimilar sizes present between sleepRail and allPERail ##']
            error = yes
        end
        %colormap(gca,customColorMap(7:8,:));
        colormap(gca,[0,0,0; cutDownColorMap(2,:)]);
        plotImage = imagesc(plotData);
        %------------------
        imageStruct(a).XData = plotImage.XData;
        imageStruct(a).YData = [a];
        imageStruct(a).CData = plotImage.CData;
        a = a + 1;
        %------------------     
        ax = gca;
        ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
        ax.XTickLabel = [xTimesProc];
        title(['All PE detection'])
        hold off
        
        %{
        %Make testatory vector-friendly version of all PE plot
        halt = yes %Necessary because otherwise new figure generation will interfere with plot
        figure
        plot(plotData)
        hold on
        for i = 1:size(overVar(IIDN).inStruct.holeStarts,2)
            line([overVar(IIDN).inStruct.holeStarts(i),overVar(IIDN).inStruct.holeStarts(i)],[0,1], 'Color', 'r')
            line([overVar(IIDN).inStruct.holeEnds(i),overVar(IIDN).inStruct.holeEnds(i)],[0,1], 'Color', 'm')
            %Note: inStructCarry might be more rigorous here
        end
        ax = gca;
        ax.XTick = overVar(IIDN).overGlob.firstDorsFrameTimeIdx;       
        ax.XTickLabel = [xTimesProc];
        title(['Sleep PE detection'])
        hold off
        %}

        %Plot sleep-only PEs
        subplot(size(processList,2)+3,1,3)
        plotData = overVar(IIDN).railStruct.sleepRail(:,3)'; %PEs only within sleep bouts (Note: Not point occurrences)
        colormap(gca,[0,0,0; cutDownColorMap(2,:)]);
        plotImage = imagesc(plotData);
        %------------------
        imageStruct(a).XData = plotImage.XData;
        imageStruct(a).YData = [a];
        imageStruct(a).CData = plotImage.CData;
        a = a + 1;
        %------------------     
        ax = gca;
        ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
        ax.XTickLabel = [xTimesProc];
        title(['Sleep PE detection'])
        hold off
        
        %Plot periodicity
        for side = 1:size(processList,2)
            subplot(size(processList,2)+3,1,side+3)
            plotData = overVar(IIDN).railStruct.sleepRail(:,2+side*2)';
            %colormap(gca,customColorMap(2*side+1:2*side+2,:));
            colormap(gca,[0,0,0; cutDownColorMap(side+2,:)]);
            plotImage = imagesc(plotData);
            %------------------
            imageStruct(a).XData = plotImage.XData;
            imageStruct(a).YData = [a];
            imageStruct(a).CData = plotImage.CData;
            a = a + 1;
            %------------------         
            ax = gca;
            ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
            ax.XTickLabel = [xTimesProc];
            title([processList{side}, ' periodicity'])
        end
        hold off

        %All-together variant ("All For One")
        figure

        for i = 1:size(imageStruct,2)    
            deepImage = reshape( imageStruct(i).CData' * cutDownColorMap(i,:) , 1, size(imageStruct(i).CData',1) , 3 );
                %Take transposed colour data from previous plot and multiply it by the selected colour and then reshape it into 1 row by <data length) columns by 3 deep matrix
                    %I.e. Data of [0 1 1 0] might be multiplied by 'red' ([1,0,0]) to become [0,0,0; 1,0,0; 1,0,0; 0,0,0] and then [0-0-0, 1-0-0, 1-0-0, 0-0-0]

            image([1 size(imageStruct(i).CData',1)], [i], deepImage);
            ylim([0.5 size(imageStruct,2)+0.5]);
            hold on
        end
        hold off
        ax = gca;
        ax.XTick = overVar(IIDN).overGlob.firstBaseFrameTimeIdx;       
        ax.XTickLabel = [xTimesProc];
        title([strrep(overVar(IIDN).fileDate, '_', ' '),' sleep/wake, all PEs, sleep PEs, ', processList{:}, ' periodicity'])        
        
    end

end

%Bart plot
%Pre-prepare
%cutDownColorMap = [0,0,1; 0,1,0; 1,0,1; 1,1,0; 0,1,1; 1,0,0];
maxSize = [];
maxTime = [];
for i = 1:size(overVar,2)
    maxSize(i) = size(overVar(i).railStruct.sleepRail,1);
    %maxTime(i) = nanmax(overVar(i).railStruct.sleepRail(:,10));
    maxTime(i) = nanmax(overVar(i).railStruct.sleepRail(:, size(overVar(i).railStruct.sleepRail,2)-1 )); %Semi-hardcoded assumption of sleepRail format
end
maxMaxTime = ceil(nanmax(maxTime));
figure
set(gcf, 'Color', 'w');
set(gcf,'units','normalized','outerposition',[0 0 1 1]) %Fullscreen recommended here to cut down on odd grapical warping
for IIDN = 1:size(overVar,2)
    %subplot(size(overVar,2),1,IIDN)
    %colormap(gca,[0,0,0; cutDownColorMap(1,:)]);

    plotData = nan( 3 , maxMaxTime );
    
    %blackCoords = ceil( overVar(IIDN).railStruct.sleepRail(:,10) );
    %blackCoords = ceil( overVar(IIDN).railStruct.sleepRail(:, size(overVar(i).railStruct.sleepRail,2)-1 ) ); %Reference to i probably wrong
    blackCoords = ceil( overVar(IIDN).railStruct.sleepRail(:, size(overVar(IIDN).railStruct.sleepRail,2)-1 ) );
    
    sleepCoords = blackCoords( overVar(IIDN).railStruct.sleepRail(:,1) == 1 );
    sleepCoords = unique(sleepCoords); %Cut down list to more manageable
    
    peCoords = blackCoords( find(overAllPE(IIDN).allPEStruct.allPERail(:,2) == 1) );
    
    blackCoords( blackCoords < 1 ) = []; blackCoords(isnan(blackCoords) == 1) = []; blackCoords = unique(blackCoords);
    sleepCoords( sleepCoords < 1 ) = []; sleepCoords(isnan(sleepCoords) == 1) = []; sleepCoords = unique(sleepCoords);
    peCoords( peCoords < 1 ) = []; peCoords(isnan(peCoords) == 1) = []; peCoords = unique(peCoords);
    
    plotData(1,blackCoords) = 1; %Black
    plotData(2,blackCoords) = 0; %Sleep/Wake preparation
    
    plotData(2,sleepCoords) = 1; %Sleep locations
    
    plotData(3,peCoords) = 1; %PE point locations

    %Make image
    imageData = [];
    
    
    if doSriBoxPlot == 0 %Default
        imageData = zeros(1,size(plotData,2),3); %Prepare
        
        imageData(1, blackCoords, [1,2]) = 1; %Recording span (slash wake)

        imageData(1, sleepCoords, [1:2]) = [0]; %Sleep
        imageData(1, sleepCoords, 3) = [1]; %Sleep

        imageData(1, peCoords, [1,3]) = [0]; %PEs
        imageData(1, peCoords, 2) = [1]; %PEs
    else %Sri aesthetic
        imageData = ones(1,size(plotData,2),3); %Prepare
        
        imageData(1, blackCoords, [1]) = 179/255; %Recording span (slash wake)
        imageData(1, blackCoords, [2]) = 77/255; %Recording span (slash wake)
        imageData(1, blackCoords, [3]) = 77/255; %Recording span (slash wake)

        imageData(1, sleepCoords, [1]) = [13/255]; %Sleep
        imageData(1, sleepCoords, [2]) = [40/255]; %Sleep
        imageData(1, sleepCoords, [3]) = [242/255]; %Sleep

        %imageData(1, peCoords, [1,3]) = [0]; %PEs
        %imageData(1, peCoords, 2) = [1]; %PEs
    end
        
    subplot(size(overVar,2),1,IIDN), image(imageData);
    
    %Axes and things
    if IIDN == size(overVar,2) %Last fly
        timeCoords = [1:60*60:size(imageData,2)];
        if doSriBoxPlot == 0
            timeCoordsHours = mat2cell(floor(timeCoords/60/60),1,size(timeCoords,2));
        else
            timeCoordsHours = mat2cell( floor(timeCoords/60/60)+(str2num(sleepCurveZT{1})-8) ,1,size(timeCoords,2) );
        end
        
        set(gca,'XTick',timeCoords)
        set(gca,'XTickLabel',timeCoordsHours)
        %set(gca,'XLabel',['Hours post 5PM'])
        %try %Yes I know this should have a catch
            %xlabel(['Hours post 5PM']) %Note: 5PM theoretically comes from the lowest item in sleepZT or whatever
        if doSriBoxPlot == 0
            xlabel(['Hours post ',sleepCurveZT{1},':00'])
        else
            xlabel(['ZT'])
        end
        %end

    else
        set(gca,'XTickLabel',[])
        %set(gca,'YTickLabel',[])
        set(gca,'XTick',[])
        %set(gca,'YTick',[])
    end
    grid('off')
    set(gca,'TickLength',[0,0])
    set(gca,'YTick',[1]);
    set(gca,'YTickLabel',[num2str(IIDN)]);

    %xlim([0, 16*60*60*fs]) %Hardcoded 16 hours timescale
end
figName = ['Experiment chronology'];
if doSriBoxPlot == 1
    figName = [figName,'- Sri Aesthetic'];
end
set(gcf,'Name', figName)

%--------------------------------------------------------------------------

%Plot position trace of PEs

for IIDN = 1:size(overAllPE,2)
    figure
    
    %pesData = [{overAllPE(IIDN).allPEStruct.inBoutPEsLOCS},{overAllPE(IIDN).allPEStruct.outBoutPEsLOCS}]; %Old, manual method
    pesData = [];
    for p = 1:size(targPEs,2)
        pesData = [pesData, {overAllPE(IIDN).allPEStruct.(targPEs{p})}]; %New, dynamic system
    end
    probMetric = overVar(IIDN).probMetric;
    
    allMax = [];
    allPEData = [];
    allPEMean = [];
    allPEMedian = [];
    allPESEM = [];
    allPECoords = [];
    allPECoordsMean = [];
    allPECoordsSEM = [];
    
    for targInd = 1:size(pesData,2)
        %subplot(size(targetPEs,2),1,targInd) %Nominally 2 rows, 1 col
        %subplot(1,size(pesData,2),targInd) %1 row, nominally 2 cols
        %subplot(2,size(pesData,2),targInd) %2 rows, nominally 2 cols 
        subplot(3,size(pesData,2),targInd) %3 rows, nominally 2 cols 
        
        %allPEData{targInd} = zeros(size(pesData{targInd},1),2*probInterval*overVar(IIDN).dataFrameRate);
        allPEData{targInd} = nan(size(pesData{targInd},1),floor(2*probInterval*overVar(IIDN).dataFrameRateInteger)+1);
        allPEMean{targInd} = [];
        allPEMedian{targInd} = [];
        allPESEM{targInd} = [];
        allPECoords{targInd} = nan( 2 , floor(2*probInterval*overVar(IIDN).dataFrameRateInteger)+1, size(pesData{targInd},1) );
        allPECoordsMean{targInd} = [];
        allPECoordsSEM{targInd} = [];
        
        allMax{targInd} = [];
        
        for i = 1:size(pesData{targInd},1)
            peSnipCoords = floor([pesData{targInd}(i)-probInterval*overVar(IIDN).dataFrameRate + 1 :  pesData{targInd}(i)+probInterval*overVar(IIDN).dataFrameRate]); %+1 to maintain size correctness; Floor because reasons
                %Note: This is weak to variable framerates
            peSnipCoords( peSnipCoords < 1 ) = 1;
            peSnipCoords( peSnipCoords > size(probMetric,1) ) = size(probMetric,1);
            %Extract PE snippet from probMetric
            thisData = probMetric( peSnipCoords ); %PE metric (e.g. Hypotenuse)  
            thisCoordsData = [ overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_x( peSnipCoords ) , overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_y( peSnipCoords ) ]'; %Original coords (Uncorrected)
                %May fail if angles not calculated
                %Dimensionality not also assured
            thisCoordsData(2,:) = -thisCoordsData(2,:); %Flip, because Y axis reasons
            %Quick dimensionality check
            if size(thisData,1) > 1 && size(thisData,2) == 1
                thisData = thisData';
            elseif size(thisData,1) > 1 && size(thisData,2) > 1
                ['## Alert: Error in prob data matrix assembly ##']
                crash = yes
            end
            if baselineCorrectPEs == 1
                %thisData = thisData - nanmean(thisData(1:floor(probInterval*dataFrameRate*0.25))); %Normalise data by first 25%
                thisData = thisData - nanmin(thisData); %Baseline correct data by overall minimum
                %thisCoordsData(1,:) = thisCoordsData(1,:) - nanmin( thisCoordsData(1,:) );
                %thisCoordsData(2,:) = thisCoordsData(2,:) - nanmin( thisCoordsData(2,:) );
                thisCoordsData(1,:) = thisCoordsData(1,:) - thisCoordsData(1,1); %Correct start point to 0
                thisCoordsData(2,:) = thisCoordsData(2,:) - thisCoordsData(2,1);
            end
            %QA to make sure that thisData is right size
            if size(thisData,2) ~= size( allPEData{targInd} , 2 )
                thisData = interp1( [size(allPEData{targInd},2) / size( thisData,2 ) : size(allPEData{targInd},2) / size( thisData,2 ) : size(allPEData{targInd},2)] , thisData , [1:size(allPEData{targInd},2)] , 'previous' );
                    %This interpolates the data to match the framerate allPEData was built with
                    %It relies on the assumption that for datasets with wildly varying framerates that the span of a sliced PE is equivalent in time to the assembly case
                temp = [];
                temp(1,:) = interp1( [size(allPEData{targInd},2) / size( thisData,2 ) : size(allPEData{targInd},2) / size( thisData,2 ) : size(allPEData{targInd},2)] , thisCoordsData(1,:) , [1:size(allPEData{targInd},2)] , 'previous' ); %Same as above, but for coords
                temp(2,:) = interp1( [size(allPEData{targInd},2) / size( thisData,2 ) : size(allPEData{targInd},2) / size( thisData,2 ) : size(allPEData{targInd},2)] , thisCoordsData(2,:) , [1:size(allPEData{targInd},2)] , 'previous' );
                    %Probably a case for 2D interpolation, but cbf figuring out how to use
                thisCoordsData = temp; %Correctness of operation not checked (yet)    
            end
            allPEData{targInd}(i,:) = thisData;
            allMax{targInd}(i,1) = nanmax(thisData);
            allPECoords{targInd}(:,:,i) = thisCoordsData;
                
            %Plot individual PEs
            %{
            plot(thisData, 'Color', colourz(IIDN,:))
            hold on
            %pause(0.1)
            %}
        end
        
        %Normalise, if requested
        if normalisePEs == 1
            allPEData{targInd} = allPEData{targInd} / nanmean(allMax{targInd}); %Calculate mean of all PE max amps and normalise values to this
            allPECoords{targInd}(1,:,:) = allPECoords{targInd}(1,:,:) / nanmean( nanmax( allPECoords{targInd}(1,:,:) ) , 3 );
            allPECoords{targInd}(2,:,:) = allPECoords{targInd}(2,:,:) / nanmean( nanmax( allPECoords{targInd}(2,:,:) ) , 3 );
        end
        
        %Calculate mean, etc
        allPEMean{targInd} = nanmean(allPEData{targInd},1);
        allPESEM{targInd} = nanstd(allPEData{targInd},1) / sqrt(size(allPEData{targInd},1)); %Technically susceptible to single-datapoint problems, but that would imply one PE or less...
        allPEMedian{targInd} = nanmedian(allPEData{targInd},1);
        allPECoordsMean{targInd}(1,:) = nanmean( allPECoords{targInd}(1,:,:) , 3 );
        allPECoordsMean{targInd}(2,:) = nanmean( allPECoords{targInd}(2,:,:) , 3 ); %Could probably achieve this with careful nanmean dimensionality, but wary
        allPECoordsSEM{targInd}(1,:) = nanstd( allPECoords{targInd}(1,:,:) , [], 3 ) ./ sqrt( size( allPECoords{targInd} , 3 ) );
        allPECoordsSEM{targInd}(2,:) = nanstd( allPECoords{targInd}(2,:,:) , [], 3 ) ./ sqrt( size( allPECoords{targInd} , 3 ) );
        
        %Plot individual PEs
        for i = 1:size(pesData{targInd},1)
            plot( allPEData{targInd}(i,:) , 'Color', colourz(IIDN,:) )
            hold on
        end
        
        %Plot mean, etc
        plot(allPEMean{targInd}, 'k')
        if nansum(isnan(allPEMean{targInd})) ~= size(allPEMean{targInd},2)
            shadeCoordsX = [ [1:size(allPEData{targInd},2)] , flip( [1:size(allPEData{targInd},2)] )];
            shadeCoordsY = [allPEMean{targInd}+allPESEM{targInd} , flip(allPEMean{targInd}-allPESEM{targInd})];
            fill(shadeCoordsX, shadeCoordsY,'k'); %Error shading
            alpha(0.25);
        end
        
        if normalisePEs == 0
            if useExclusionCriteria == 1
                if doTooHighExclusion == 1
                    if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                        ylim([ 0 , dlcTooHeight ]);
                    else
                        ylim([ 0 , sriTooHeight ]);
                    end
                end
            else
                ylim([0 120])
            end
            %ylim([0 120]) %Not normalised
        %else
        %    ylim([0,nanmax(nanmax(allPEData{targInd}))]) %Normalised
        end
        xlim([1,size(allPEMean{targInd},2)])
        %title(['IIDN: ',num2str(IIDN),' - Hyp. size (PE target: ',targPEsIndex{targInd},'), n=',num2str(size(allPEData{targInd},1)), char(10), '[',normalisePEsIndex{normalisePEs+1},']']) %+1 necessary because order
        title(['IIDN: ',num2str(IIDN), ' - ', overVar(IIDN).flyName, char(10),' Hyp. size (PE target: ',targPEsIndex{targInd},'), n=',num2str(size(allPEData{targInd},1)), char(10), '[',normalisePEsIndex{normalisePEs+1},']']) %+1 necessary because order
        
        
        %Hist
        %subplot(2,size(pesData,2),targInd+size(pesData,2)) %2 rows, nominally 2 cols 
        subplot(3,size(pesData,2),targInd+size(pesData,2)) %3 rows, nominally 2 cols 
        
        hist( nanmax(allPEData{targInd},[],2), 128 )
        if useExclusionCriteria == 1
            if doTooHighExclusion == 1
                if forceUseDLCData == 1 & isfield(overVar(IIDN).overGlob.dlcDataProc, 'dlcProboscisHyp') == 1
                    xlim([ 0 , dlcTooHeight ])
                else
                    xlim([ 0 , sriTooHeight ])
                end
            end
        end
        xlabel(['Max PE ext. distance (px)']) %Valid for DLC
        ylabel(['Count'])
        title([targPEsIndex{targInd},' PE max dists.'])
        
        %Plot of instantaneous rise as a fraction of maximum change in height
            %Note that the max change in height is calculated from the max to the min, not between any two guaranteed contiguous points
            %(Replaced currently by W hist)
        %{
        subplot(3,size(pesData,2),targInd+2*size(pesData,2))
        hist( nanmax( diff( allPEData{targInd},1,2 ) , [], 2 ) ./ (nanmax(allPEData{targInd},[],2)-nanmin(allPEData{targInd},[],2)) , 128 )
        xlim([0,1])
        xlabel(['Max inst. rise as frac. of max delta'])
        titleStr = [targPEsIndex{targInd},' PE max inst. rise as frac.'];
        if doTimeCalcs == 1 && useExclusionCriteria == 1 && doInstChangeExclusion == 1
            yLim = get(gca,'YLim');
            line([instChangeThresholdFrac, instChangeThresholdFrac], [0, nanmax(yLim)], 'Color', 'r', 'LineStyle', ':')
            titleStr = [titleStr,char(10),'(And inst. change frac. threshold)'];
        end
        title(titleStr)
        %}
        
        %Targ Ws
        subplot(3,size(pesData,2),targInd+2*size(pesData,2))
        targWs{targInd} = [];
        temp = intersect( overAllPE(IIDN).allPEStruct.(targPEs{targInd}) , overAllPE(IIDN).allPEStruct.allLOCS );
        for i = 1:size(temp,1)
            targWs{targInd} = [targWs{targInd}; overAllPE(IIDN).allPEStruct.allW( find( overAllPE(IIDN).allPEStruct.allLOCS == temp(i), 1 ) ) ];
        end
        histogram( targWs{targInd} , 128, 'FaceColor', colourDictionary{targInd}, 'FaceAlpha', 0.3 )
        %histogram( execOverTargWs{targInd} , 128, 'FaceColor', colourDictionary{targInd}, 'FaceAlpha', 0.3 )
        xlim([0,200])
        xlabel(['W[idth]'])
        ylabel(['Count'])
        titleStr = [targPEsIndex{targInd},' Ws hist'];
        title(titleStr)
        
    end
    set(gcf,'Name', [overVar(IIDN).flyName,' - PE descriptive'])
    
    %Shared Y axis limits (for normalised data)
    if normalisePEs ~= 0
        overMax = [];
        for targInd = 1:size(pesData,2)
            overMax(targInd) = nanmax(nanmax(allPEData{targInd}));
        end
        for targInd = 1:size(pesData,2)
            %subplot(1,size(pesData,2),targInd)
            %subplot(2,size(pesData,2),targInd)
            subplot(3,size(pesData,2),targInd)
            ylim([0,nanmax(overMax)])
            subplot(2,size(pesData,2),targInd+size(pesData,2))
            xlim([0,nanmax(overMax)])
        end
    end
    
    %{
    %Max size hist.
    figure
    for targInd = 1:size(targetPEs,2)
        subplot(1,size(targetPEs,2),targInd) %1 col, nominally 2 rows 
        hist(allMax{targInd}, 64)
        title(['IIDN: ',num2str(IIDN),' Hypotenuse size hist. (PE target type: ',num2str(targInd),')'])
    end
    %}
    
    %Plot PE coords
    figure
    for targInd = 1:size(pesData,2)
        %Raw traces
        %subplot(1,size(pesData,2),targInd)
        subplot(2,size(pesData,2),targInd)
        for i = 1:size(allPECoords{targInd},3)
            plot( allPECoords{targInd}(1,:,i) , allPECoords{targInd}(2,:,i) , 'Color', colourz(IIDN,:) )
            hold on
        end
        plot(allPECoordsMean{targInd}(1,:),allPECoordsMean{targInd}(2,:), 'k')
        scatter( allPECoordsMean{targInd}(1,1) , allPECoordsMean{targInd}(2,1), 'g', 'filled' )
        scatter( allPECoordsMean{targInd}(1,end) , allPECoordsMean{targInd}(2,end), 'r', 'filled' )
        %{
        %Shading currently unimplemented because 2-dimensional
        if nansum(isnan(allPECoordsMean{targInd}(1,:))) ~= size(allPECoordsMean{targInd}(1,:),2) %Check X coords for NaN nature
            shadeCoordsX = [ [1:size(allPEData{targInd},2)] , flip( [1:size(allPEData{targInd},2)] )];
            shadeCoordsY = [allPEMean{targInd}+allPESEM{targInd} , flip(allPEMean{targInd}-allPESEM{targInd})];
            fill(shadeCoordsX, shadeCoordsY,'k'); %Error shading
            alpha(0.25);
        end
        %}
        hold off
        title(['IIDN: ',num2str(IIDN), ' - ', overVar(IIDN).flyName, char(10),' Coords (PE target: ',targPEsIndex{targInd},'), n=',num2str(size(allPEData{targInd},1)), char(10), '[',normalisePEsIndex{normalisePEs+1},']']) %+1 necessary because order
    
        %Bootleg heatmap
        axLims = [get(gca,'XLim');get(gca,'YLim')];
        %heatMap = zeros( ceil( axLims(2,2)-axLims(2,1) ) , ceil( axLims(1,2)-axLims(1,1) ) );
        %heatMap = zeros( ceil( nanmax(nanmax(allPECoords{targInd}(2,:,:))) - nanmin(nanmin(allPECoords{targInd}(2,:,:))) ) , ...
        %    ceil( nanmax(nanmax(allPECoords{targInd}(1,:,:))) - nanmin(nanmin(allPECoords{targInd}(1,:,:))) ) ); %Make an array that spans the full range of observed values
        temp = nan( 2 , size(allPECoords{targInd},2) , size(allPECoords{targInd},3) );
        temp(1,:,:) = allPECoords{targInd}(1,:,:) - nanmin(nanmin(allPECoords{targInd}(1,:,:))) + 1;
        temp(2,:,:) = allPECoords{targInd}(2,:,:) - nanmin(nanmin(allPECoords{targInd}(2,:,:))) + 1;
        temp = round(temp);
        heatMap = zeros( ceil( nanmax(nanmax(temp(2,:,:))) - nanmin(nanmin(temp(2,:,:))) ) + 1, ...
            ceil( nanmax(nanmax(temp(1,:,:))) - nanmin(nanmin(temp(1,:,:))) ) + 1 ); %Make an array that spans the full range of observed values
        for i = 1:size(temp,3)
            heatMap( temp(2,:,i) , temp(1,:,i) ) = heatMap( temp(2,:,i) , temp(1,:,i) ) + 1;
        end
        heatMap = flip(heatMap); %Because reasons
        subplot(2,size(pesData,2),targInd+1*size(pesData,2))
        imagesc( heatMap )
        title(['Heatmap'])
        
    end
    set(gcf,'Name', [overVar(IIDN).flyName,' - PE Coords'])
    
    overPlot.PEdXdT(IIDN).allPEData = allPEData;
    overPlot.PEdXdT(IIDN).allPEMean = allPEMean;
    overPlot.PEdXdT(IIDN).allPEMedian = allPEMedian;
end

%Plot AUCs for PEs
    %Note: Potentially critically weak to variable baselines
figure
for IIDN = 1:size(overPlot.PEdXdT,2)
    subplot( ceil(size(overPlot.PEdXdT,2)/2) , 2, IIDN )
    allPESums = [];
    for targInd = 1:size(overPlot.PEdXdT(IIDN).allPEData,2)
        allPESums{targInd} = nansum(overPlot.PEdXdT(IIDN).allPEData{targInd}');
        
        histogram( allPESums{targInd} , 128, 'FaceColor', colourDictionary{targInd}, 'FaceAlpha', 0.3 )
        hold on
    end
    hold off
    xlabel(['Sum of probMetric'])
    ylabel(['Occurences'])
    title([overVar(IIDN).flyName])
end
set(gcf,'Name', 'Indiv PE trace sums')

%Plot averaged average plot
figure
for targInd = 1:size(pesData,2)
    %subplot(1,size(pesData,2),targInd) %1 row, nominally 2 cols 
    subplot(2,size(pesData,2),targInd) %1 row, nominally 2 cols 
    
    hold on
    
    plotData = [];
    allDataPooled = [];
    for IIDN = 1:size(overPlot.PEdXdT,2)
        %plotData(IIDN,:) = overPlot.PEdXdT(IIDN).allPEMean{targInd}; %Use mean
        if IIDN == 1 | size( overPlot.PEdXdT(IIDN).allPEMedian{targInd} , 2 ) == size( plotData,2 )
            plotData(IIDN,:) = overPlot.PEdXdT(IIDN).allPEMedian{targInd}; %Use median
            allDataPooled = [allDataPooled; overPlot.PEdXdT(IIDN).allPEData{targInd}];
        else
            plotData(IIDN,:) = interp1( [size(plotData,2) / size( overPlot.PEdXdT(IIDN).allPEMedian{targInd},2 ) : size(plotData,2) / size( overPlot.PEdXdT(IIDN).allPEMedian{targInd},2 ) : size(plotData,2)] ,...
                overPlot.PEdXdT(IIDN).allPEMedian{targInd} , [1:size(plotData,2)] , 'previous' ); %Use median
            for row = 1:size( overPlot.PEdXdT(IIDN).allPEData{targInd} , 1 )
                allDataPooled( size(allDataPooled,1)+1 , : ) = ...
                    interp1( [size(plotData,2) / size( overPlot.PEdXdT(IIDN).allPEData{targInd}(row,:),2 ) : size(plotData,2) / size( overPlot.PEdXdT(IIDN).allPEData{targInd}(row,:),2 ) : size(plotData,2)] ,...
                        overPlot.PEdXdT(IIDN).allPEData{targInd}(row,:) , [1:size(plotData,2)] , 'previous' );
            end
        end
        %Indiv
        %plot(overPlot.PEdXdT(IIDN).allPEMean{targInd}, 'Color', colourz(IIDN,:))
        plot(plotData(IIDN,:), 'Color', colourz(IIDN,:))
    end
    
    %Calculate SEM of averaged average
    plotMean = nanmean(plotData,1);
    plotSEM = nanstd(plotData,1) / sqrt(size(plotData,1));

    plot(plotMean, 'k')
    hold on
    shadeCoordsX = [ [1:size(plotMean,2)] , flip( [1:size(plotMean,2)] )];
    shadeCoordsY = [plotMean+plotSEM , flip(plotMean-plotSEM)];
    fill(shadeCoordsX, shadeCoordsY,'k') %Error shading
    alpha(0.25)

    %Titles, etc
    if normalisePEs == 0
        ylim([0 120])
    else
        %ylim([0,nanmax(overMax)])
        ylim([0 nanmax(plotMean)*1.5])
    end
    title(['Median hypotenuse amplitude over time (PE target: ',targPEsIndex{targInd},'), N = ',num2str(size(plotData,1)), char(10),  '[',normalisePEsIndex{normalisePEs+1},']'])
    
    %Hist of all instances pooled
    subplot(2,size(pesData,2),targInd+size(pesData,2)) %1 row, nominally 2 cols 
    
    hist( nanmax(allDataPooled,[],2) , 128 )
    xlim([0 nanmax(plotMean)*3])
    set(gcf,'Name', ['Averaged PE traces'])
    
end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%{
%(For use with testatory probUpper/probAng plots)
nurg = 82146;
xlim([nurg-1000,nurg+1000])
%}

overHist = struct; %Will hold hist data across flies
%%
%Alt PE pooled figures
if doAltDetection == 1
    arbColours = winter( size(overAltAngGroups{1},2) ); %Auto derive a colour matrix
    
    %Calculate some necessary FLID details, if requested
    if splitBouts == 1
        postFLID = struct;
        for IIDN = 1:size(overVar,2)
            temp = [];
            %Prepare sizes
            for i = 1:size(overVar(IIDN).inStructCarry.FLID,2)
                temp( overVar(IIDN).inStructCarry.FLID(1,i) , overVar(IIDN).inStructCarry.FLID(2,i) ) = length( overVar(IIDN).inStructCarry.holeRanges{ overVar(IIDN).inStructCarry.FLID(3,i)} );
            end
            postFLID(IIDN).allFLID = nan( nansum( nanmax( temp , [] , 2 ) ) , size(splitDurs,2) );
            %Assign all coord data to struct
            as = ones( 1 , size(splitDurs,2) );
            for i = 1:size(overVar(IIDN).inStructCarry.FLID,2)
                postFLID(IIDN).allFLID( as( overVar(IIDN).inStructCarry.FLID(2,i) ):as( overVar(IIDN).inStructCarry.FLID(2,i) )+temp( overVar(IIDN).inStructCarry.FLID(1,i) , overVar(IIDN).inStructCarry.FLID(2,i) )-1 , overVar(IIDN).inStructCarry.FLID(2,i) )...
                    = overVar(IIDN).inStructCarry.holeRanges{ overVar(IIDN).inStructCarry.FLID(3,i)};
                as( overVar(IIDN).inStructCarry.FLID(2,i) ) = as( overVar(IIDN).inStructCarry.FLID(2,i) ) + nanmax( temp( overVar(IIDN).inStructCarry.FLID(1,i) , : ) );
            end
        end
    end
       
    %Calculate metrics
    indivArbAngData = [];
    indivArbSizes = [];
    pooledArbSizes = [];
    indivArbSizesZScore = [];
    pooledArbSizesZScore = [];
    pooledArbCount = [];
    pooledArbCountProp = [];
    pooledArbSizesState = [];
    pooledArbSizesZScoreState = [];
    pooledArbCountState = [];
    pooledArbCountPropState = [];
    %FLID-specific things, if applicable
    if splitBouts == 1
        pooledArbCountFLID = repmat( {zeros( size(overAllPE,2) , size(splitDurs,2) )} , 1 , size(overAltAngGroups{1},2) ); %Cells - Arb group -> Rows - Fly, Cols - FLID group
        pooledArbCountFLIDNorm = repmat( {zeros( size(overAllPE,2) , size(splitDurs,2) )} , 1 , size(overAltAngGroups{1},2) ); %Cells - Arb group -> Rows - Fly, Cols - FLID group
    end
    for IIDN = 1:size(overAllPE,2)
        altAngGroups = overAltAngGroups{IIDN};
        for arbInd = 1:size(altAngGroups,2)
            coords = overAllPE(IIDN).altStruct.probAngMeds >= altAngGroups{arbInd}(1) & overAllPE(IIDN).altStruct.probAngMeds <= altAngGroups{arbInd}(2);
            if splitBouts == 1
                temp = overAllPE(IIDN).altStruct.probInds(coords);
                thisFLID = [];
                %Raw counts
                for i = 1:size(temp,1)
                    [~,k] = find( postFLID(IIDN).allFLID == temp(i) ); %Will return empty for wake events
                    if isempty(k) ~= 1
                        thisFLID(i,1) = k; %Mostly for reporting
                        pooledArbCountFLID{arbInd}(IIDN,k) = pooledArbCountFLID{arbInd}(IIDN,k) + 1; %Increment FLID by appropriate amount
                    else
                        thisFLID(i,1) = NaN;
                    end
                end
                %Normalised by segment durations
                for i = 1:size(splitDurs,2)
                     pooledArbCountFLIDNorm{arbInd}(IIDN,i) = pooledArbCountFLID{arbInd}(IIDN,i) / ( size( postFLID(IIDN).allFLID,1 ) - nansum( isnan(postFLID(IIDN).allFLID(:,i)) ) ) * overVar(IIDN).dataFrameRate * 60;
                        %Theoretically events/min
                end
            end
            indivArbAngData{IIDN,arbInd} = overAllPE(IIDN).altStruct.probAngMeds( coords );
            indivArbSizes{IIDN,arbInd} = overAllPE(IIDN).altStruct.probSizes( coords );
            pooledArbSizes(IIDN,arbInd) = nanmean( indivArbSizes{IIDN,arbInd} );
            temp = zscore( overAllPE(IIDN).altStruct.probSizes ); %Needs to be non-coords, to ensure Z-scoring is occurring across all sizes
            indivArbSizesZScore{IIDN,arbInd} = temp(coords);
            pooledArbSizesZScore(IIDN,arbInd) = nanmean( indivArbSizesZScore{IIDN,arbInd} );
            pooledArbCount(IIDN,arbInd) = size( overAllPE(IIDN).altStruct.probInds( coords ) , 1);
            pooledArbCountProp(IIDN,arbInd) = size( overAllPE(IIDN).altStruct.probInds( coords ) , 1) / size( overAllPE(IIDN).altStruct.probInds , 1);
            for sepInd = 1:size(sepIndex,2)
                thisSizeData = overAllPE(IIDN).altStruct.( strcat(sepIndex{sepInd},'ProbSizes') ); %Doesn't exist yet
                thisAngData = overAllPE(IIDN).altStruct.( strcat(sepIndex{sepInd},'ProbAngleMeds') );
                pooledArbSizesState{sepInd}(IIDN,arbInd) = ...
                    nanmean( thisSizeData( thisAngData >= altAngGroups{arbInd}(1) & thisAngData <= altAngGroups{arbInd}(2) ) ); %Select only elements matching arb. angle group
                zCoords = nan( size( thisSizeData , 1 ) , 1 );
                for i = 1:size( thisSizeData , 1 )
                    zCoords(i) = find( overAllPE(IIDN).altStruct.probSizes == thisSizeData(i) , 1 ); %Because 'intersect' ignores duplicates
                end
                %QA
                if nansum(isnan(zCoords)) > 0
                    ['## Error of state to greater list matching ##']
                    crash = yes
                end
                %[~,zCoords,~] = intersect( overAllPE(IIDN).altStruct.probSizes , thisSizeData ); %Find probSizes for this state in greater probSizes list
                zTemp = temp(zCoords); %Extract Z-scored probSizes from greater list based on above coords
                pooledArbSizesZScoreState{sepInd}(IIDN,arbInd) = ...
                    nanmean( zTemp( thisAngData >= altAngGroups{arbInd}(1) & thisAngData <= altAngGroups{arbInd}(2) ) ); %Select only elements matching arb. angle group
                %thisData = overAllPE(IIDN).altStruct.( strcat(sepIndex{sepInd},'ProbAngleMeds') );
                pooledArbCountState{sepInd}(IIDN,arbInd) = ...
                    size( thisAngData( thisAngData >= altAngGroups{arbInd}(1) & thisAngData <= altAngGroups{arbInd}(2) ) , 1);
                pooledArbCountPropState{sepInd}(IIDN,arbInd) = ...
                    size( thisAngData( thisAngData >= altAngGroups{arbInd}(1) & thisAngData <= altAngGroups{arbInd}(2) ) , 1) / size( thisAngData , 1);
            end
        end
    end
    clear altAngGroups %Just in case
    
    %Plots
    exLabels = [];
    %for arbInd = 1:size(altAngGroups,2)
    for arbInd = 1:size(overAltAngGroups{1},2) %Use first element as example
        %exLabels{arbInd} = [ num2str(altAngGroups{arbInd}(1)) , ' <= x <= ' , num2str(altAngGroups{arbInd}(2)) ];
        exLabels{arbInd} = [ 'Arb group ',num2str(arbInd) ];
    end
    
    %Indiv hist w/ arb edges plot
    figure
    pooledData = nan( size( overAllPE,2 ) , 360 - 1 );
    for IIDN = 1:size( overAllPE,2 )
        altAngGroups = overAltAngGroups{IIDN};
        subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        %scatter(probAngMeds,probSizes)
        %xlim([0,360])
        %hold on
        %ax = gca;
        %axPos = get(ax,'Position');
        %ax2 = axes('Position', axPos, 'XAxisLocation', 'bottom', 'YAxisLocation', 'right', 'Color', 'none');
        %hist(overAllPE(IIDN).altStruct.probAngMeds,128)
        %h = histogram( overAllPE(IIDN).altStruct.probAngMeds , 128);
        h = histogram( overAllPE(IIDN).altStruct.probAngMeds , linspace(0,360,360));
        hold on
        xlim([0,360])
        if isfield(overAllPE(IIDN).allPEStruct,'flyBodyAngle') == 1
            title([overVar(IIDN).flyName,char(10),'Median probAngles hist (Body corrected)'])
        else
            title([overVar(IIDN).flyName,char(10),'Median probAngles hist (Not body corrected)'])
        end
        xlabel(['Proboscis event median angle (degs)'])
        ylabel(['Count'])
        yLims = get(gca,'YLim');
        for arbInd = 1:size(altAngGroups,2)
            line([altAngGroups{arbInd}(1),altAngGroups{arbInd}(1)],[0,nanmax(yLims)], 'Color', 'k', 'LineStyle', ':')
            line([altAngGroups{arbInd}(2),altAngGroups{arbInd}(2)],[0,nanmax(yLims)], 'Color', 'k', 'LineStyle', ':')
            text(nanmean([altAngGroups{arbInd}(1),altAngGroups{arbInd}(2)]),nanmax(yLims),...
                [exLabels{arbInd},char(10),num2str( (pooledArbCount(IIDN,arbInd) / size(overAllPE(IIDN).altStruct.probAngMeds,1))*100 ),'%'],'HorizontalAlignment','Center')
        end
        hold off
        overHist(IIDN).altProbAngles.Data = h.Values;
        overHist(IIDN).altProbAngles.BinEdges = h.BinEdges;
        pooledData(IIDN,:) = h.Values; %Will fail if size mismatch, which is intended
    end
    set(gcf,'Name', 'Alt Prob Angs Hist w Arb Groups')
    clear altAngGroups
    %Pooled angle hist (Sum)
    figure
    bar( linspace(0,360,360-1) , nansum(pooledData,1) )
    xlim([220,360])
    xlabel(['Angle (degs)'])
    ylabel(['Pooled count'])
    title(['Pooled alt ang hist sum'])
    
    %Indiv sizes scatter
    figure
    for IIDN = 1:size( overAllPE,2 )
        altAngGroups = overAltAngGroups{IIDN};
        subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        scatter(overAllPE(IIDN).altStruct.probAngMeds,overAllPE(IIDN).altStruct.probSizes)
        xlim([0,360])
        hold on
        xlim([0,360])
        if isfield(overAllPE(IIDN).allPEStruct,'flyBodyAngle') == 1
            title([overVar(IIDN).flyName,char(10),'Median probSizes hist (Body corrected)'])
        else
            title([overVar(IIDN).flyName,char(10),'Median probSizes hist (Not body corrected)'])
        end
        xlabel(['Proboscis event median angle (degs)'])
        ylabel(['Event duration (frames)'])
        yLims = get(gca,'YLim');
        for arbInd = 1:size(altAngGroups,2)
            line([altAngGroups{arbInd}(1),altAngGroups{arbInd}(1)],[0,nanmax(yLims)], 'Color', 'k', 'LineStyle', ':')
            line([altAngGroups{arbInd}(2),altAngGroups{arbInd}(2)],[0,nanmax(yLims)], 'Color', 'k', 'LineStyle', ':')
            text(nanmean([altAngGroups{arbInd}(1),altAngGroups{arbInd}(2)]),nanmax(yLims),...
                [exLabels{arbInd},char(10),num2str( (pooledArbCount(IIDN,arbInd) / size(overAllPE(IIDN).altStruct.probAngMeds,1))*100 ),'%'],'HorizontalAlignment','Center')
        end
        hold off
    end
    set(gcf,'Name', 'Alt Prob Sizes Hist w Arb Groups')
    clear altAngGroups
    
    
    %Sizes
    figure
    for IIDN = 1:size(overAllPE,2)
        altAngGroups = overAltAngGroups{IIDN};
        %{
        %Arbitrary PE separation
        arbAngData = [];
        arbSizeData = [];
        arbSizeMean = [];
        arbSizeSEM = [];
        exLabels = [];
        for arbInd = 1:size(altAngGroups,2)
            arbAngData{arbInd} = overAllPE(IIDN).altStruct.probAngMeds( overAllPE(IIDN).altStruct.probAngMeds >= altAngGroups{arbInd}(1) & overAllPE(IIDN).altStruct.probAngMeds <= altAngGroups{arbInd}(2) );
            arbSizeData{arbInd} = overAllPE(IIDN).altStruct.probSizes( overAllPE(IIDN).altStruct.probAngMeds >= altAngGroups{arbInd}(1) & overAllPE(IIDN).altStruct.probAngMeds <= altAngGroups{arbInd}(2) );
            arbSizeMean(arbInd) = nanmean( arbSizeData{arbInd} );
            arbSizeSEM(arbInd) = nanstd( arbSizeData{arbInd} ) / sqrt( size(arbSizeData{arbInd},1) );
            exLabels{arbInd} = [ num2str(altAngGroups{arbInd}(1)) , ' <= x <= ' , num2str(altAngGroups{arbInd}(2)) ];
        end
        %}
        
        subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        %errorbar( arbSizeMean , arbSizeSEM )
        try
            errorbar( pooledArbSizes(IIDN,:) , cellfun(@nanstd,indivArbSizes(IIDN,:)) ./ sqrt( cellfun(@length,indivArbSizes(IIDN,:)) ) )
            %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
            %ylim([(nanmin(cellfun(@nanmean,indivArbSizes(IIDN,:)))-nanmax(cellfun(@nanstd,indivArbSizes(IIDN,:)) ./ sqrt( cellfun(@length,indivArbSizes(IIDN,:)) )))*1.1, ...
            %    (nanmax(cellfun(@nanmean,indivArbSizes(IIDN,:)))+nanmax(cellfun(@nanstd,indivArbSizes(IIDN,:)) ./ sqrt( cellfun(@length,indivArbSizes(IIDN,:)) )))*1.1])
            ylim('auto')
        catch
            disp(['-# Failure to plot dataset ',overVar(IIDN).flyName,' #-'])
        end
        xlim([0,size(altAngGroups,2)+1])
        xticks([1:size(altAngGroups,2)])
        xticklabels(exLabels)
        xlabel(['Arbitrary angle groups (degs)'])
        ylabel(['Event duration (frames)'])
        title(overVar(IIDN).flyName)
        %And stats
        inputData = nan( nanmax(cellfun(@length,indivArbSizes(IIDN,:))), size(altAngGroups,2) );
        for arbInd = 1:size(altAngGroups,2)
            inputData( 1:size(indivArbSizes{IIDN,arbInd},1) ,arbInd) = indivArbSizes{IIDN,arbInd};
        end
        barStats(inputData,alphaValue,[],1);
    end
    set(gcf,'Name','Alt detection arb size comparison barplots')
    clear altAngGroups
    
    %Z-scored sizes
    figure
    for IIDN = 1:size(overAllPE,2)
        altAngGroups = overAltAngGroups{IIDN};
        subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        try
            %errorbar( arbSizeMean , arbSizeSEM )
            errorbar( pooledArbSizesZScore(IIDN,:) , cellfun(@nanstd,indivArbSizesZScore(IIDN,:)) ./ sqrt( cellfun(@length,indivArbSizesZScore(IIDN,:)) ) )
            %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
            %ylim([(nanmin(cellfun(@nanmean,indivArbSizesZScore(IIDN,:)))+nanmax(cellfun(@nanstd,indivArbSizesZScore(IIDN,:)) ./ sqrt( cellfun(@length,indivArbSizesZScore(IIDN,:)) )))*1.1, ...
            %    (nanmax(cellfun(@nanmean,indivArbSizesZScore(IIDN,:)))+nanmax(cellfun(@nanstd,indivArbSizesZScore(IIDN,:)) ./ sqrt( cellfun(@length,indivArbSizesZScore(IIDN,:)) )))*1.1])
        catch
            disp(['-# Failure to plot dataset ',overVar(IIDN).flyName,' #-'])
        end
        ylim('auto')
        xlim([0,size(altAngGroups,2)+1])
        xticks([1:size(altAngGroups,2)])
        xticklabels(exLabels)
        xlabel(['Arbitrary angle groups (degs)'])
        ylabel(['Z-scored event duration'])
        title(overVar(IIDN).flyName)
        %And stats
        inputData = nan( nanmax(cellfun(@length,indivArbSizesZScore(IIDN,:))), size(altAngGroups,2) );
        for arbInd = 1:size(altAngGroups,2)
            inputData( 1:size(indivArbSizesZScore{IIDN,arbInd},1) ,arbInd) = indivArbSizesZScore{IIDN,arbInd};
        end
        barStats(inputData,alphaValue);
    end
    set(gcf,'Name','Alt detection arb Z-scored size comparison barplots')
    clear altAngGroups
    
    %----------
    %Counts
    figure
    %subplot(2,2,1)
    subplot(3,2,1)
    errorbar( nanmean(pooledArbCount,1) , nanstd(pooledArbCount,[],1) / sqrt(size(pooledArbCount,1)) )
    %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
    %xlim([0.5,size(altAngGroups,2)+0.5])
    %xticks([1:size(altAngGroups,2)])
    xlim([0.5,size(overAltAngGroups{1},2)+0.5])
    xticks([1:size(overAltAngGroups{1},2)])
    xticklabels(exLabels)
    xlabel(['Arbitrary angle groups (degs)'])
    ylabel(['Event count (#)'])
    %title('Pooled event counts across arbitrary angle groups')
    title(['Pooled event counts across arbitrary angle groups',char(10),...
        'Average ',num2str(nanmean( nansum( pooledArbCount , 2 ) ./ floor( (1./pooledArbCountProp(:,1)).*pooledArbCount(:,1) ) )*100),'% coverage (Arb vs Total)'])
    %And stats
    inputData = pooledArbCount;
    barStats(inputData,alphaValue);
    
    %Proportionalised counts
    %subplot(2,2,3)
    subplot(3,2,3)
    errorbar( nanmean(pooledArbCountProp,1) , nanstd(pooledArbCountProp,[],1) / sqrt(size(pooledArbCountProp,1)) )
    %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
    %xlim([0.5,size(altAngGroups,2)+0.5])
    %xticks([1:size(altAngGroups,2)])
    xlim([0.5,size(overAltAngGroups{1},2)+0.5])
    xticks([1:size(overAltAngGroups{1},2)])
    xticklabels(exLabels)
    xlabel(['Arbitrary angle groups (degs)'])
    ylabel(['% of all events (#)'])
    title('Pooled event counts as prop. of total across arbitrary angle groups')
    set(gcf,'Name','Alt PE event counts')
    %And stats
    inputData = pooledArbCountProp;
    barStats(inputData,alphaValue);    
    
    %Counts, separated into inBouts and outBouts
    %subplot(2,2,2)
    subplot(3,2,2)
    exTick = [];
    for sepInd = 1:size(sepIndex,2)
        errorbar( ([0.25:0.5:0.75]+sepInd*size(sepIndex,2))-1, nanmean(pooledArbCountState{sepInd},1) , nanstd(pooledArbCountState{sepInd},[],1) / sqrt(size(pooledArbCountState{sepInd},1)), sepColours{sepInd} )
        exTick = [exTick, [0.25:0.5:0.75]+sepInd*size(sepIndex,2)-1];
        hold on
    end
    xticks(exTick)
    xticklabels(repmat(exLabels,1,2))
    legend([sepIndex],'Color', 'none','AutoUpdate','off')
    ylabel(['Event count (#)'])
    xlabel(['Arbitrary angle groups (degs)'])
    %xlim([0.5,size(sepIndex,2)*size(altAngGroups,2)+0.5])
    xlim([0.5,size(sepIndex,2)*size(overAltAngGroups{1},2)+0.5])
    xtickangle(320)
    title(['Pooled event counts separated by state'])
    %And stats
    %inputData = nan( size(pooledArbCountState{1},1) , size(sepIndex,2)*size(altAngGroups,2) );
    inputData = nan( size(pooledArbCountState{1},1) , size(sepIndex,2)*size(overAltAngGroups{1},2) );
    for sepInd = 1:size(sepIndex,2)
        inputData( : , ([0:1]+sepInd*size(sepIndex,2))-1 ) = pooledArbCountState{sepInd};
    end
    barStats(inputData,alphaValue,exTick);  
    
    %Props, separated into inBouts and outBouts
    %subplot(2,2,4)
    subplot(3,2,4)
    exTick = [];
    for sepInd = 1:size(sepIndex,2)
        errorbar( ([0.25:0.5:0.75]+sepInd*size(sepIndex,2))-1, nanmean(pooledArbCountPropState{sepInd},1) , nanstd(pooledArbCountPropState{sepInd},[],1) / sqrt(size(pooledArbCountPropState{sepInd},1)), sepColours{sepInd} )
        exTick = [exTick, [0.25:0.5:0.75]+sepInd*size(sepIndex,2)-1];
        hold on
    end
    xticks(exTick)
    xticklabels(repmat(exLabels,1,2))
    legend([sepIndex],'Color', 'none','AutoUpdate','off')
    ylabel(['Proportion of total (%)'])
    xlabel(['Arbitrary angle groups (degs)'])
    %xlim([0.5,size(sepIndex,2)*size(altAngGroups,2)+0.5])
    xlim([0.5,size(sepIndex,2)*size(overAltAngGroups{1},2)+0.5])
    xtickangle(320)
    title(['Pooled event props. separated by state'])
    %And stats
    %inputData = nan( size(pooledArbCountPropState{1},1) , size(sepIndex,2)*size(altAngGroups,2) );
    inputData = nan( size(pooledArbCountPropState{1},1) , size(sepIndex,2)*size(overAltAngGroups{1},2) );
    for sepInd = 1:size(sepIndex,2)
        inputData( : , ([0:1]+sepInd*size(sepIndex,2))-1 ) = pooledArbCountPropState{sepInd};
    end
    barStats(inputData,alphaValue,exTick);
    hold off
    
    %Counts as a per/min
    subplot(3,2,5)
    plotData = [];
    plotDataState = [];
    %Pre-QA
    if size( sepIndex,2 ) > 2 || isequal( sepIndex{1},'inBout' ) ~= 1
        ['-# Alert: Plot hardcoded for two states #-']
        crash = yes
    end
    for IIDN = 1:size(overAllPE,2)
        temp = [0;diff(overAllPE(IIDN).allPEStruct.allPERail(:,1))];
        plotData(IIDN,:) = pooledArbCount(IIDN,:) ./  ( nansum( temp ) / 60);
        plotDataState{1}(IIDN,:) = pooledArbCount(IIDN,:) ./  ( nansum( temp( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,3)) ~= 1 ) ) / 60); %inBout
        plotDataState{2}(IIDN,:) = pooledArbCount(IIDN,:) ./  ( nansum( temp( isnan(overAllPE(IIDN).allPEStruct.allPERail(:,5)) ~= 1 ) ) / 60); %outBout
    end
    errorbar( nanmean(plotData,1) , nanstd(plotData,[],1) / sqrt(size(plotData,1)) )
    %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
    %xlim([0.5,size(altAngGroups,2)+0.5])
    %xticks([1:size(altAngGroups,2)])
    xlim([0.5,size(overAltAngGroups{1},2)+0.5])
    xticks([1:size(overAltAngGroups{1},2)])
    xticklabels(exLabels)
    xlabel(['Arbitrary angle groups (degs)'])
    ylabel(['Events/min (#)'])
    %title('Pooled event counts across arbitrary angle groups')
    title(['Pooled event counts/min across arbitrary angle groups'])
    %And stats
    inputData = plotData;
    barStats(inputData,alphaValue);
    
    %Counts as a per/min, separated into inBouts and outBouts
    subplot(3,2,6)
    exTick = [];
    for sepInd = 1:size(sepIndex,2)
        errorbar( ([0.25:0.5:0.75]+sepInd*size(sepIndex,2))-1, nanmean(plotDataState{sepInd},1) , nanstd(plotDataState{sepInd},[],1) / sqrt(size(plotDataState{sepInd},1)), sepColours{sepInd} )
        exTick = [exTick, [0.25:0.5:0.75]+sepInd*size(sepIndex,2)-1];
        hold on
    end
    xticks(exTick)
    xticklabels(repmat(exLabels,1,2))
    legend([sepIndex],'Color', 'none','AutoUpdate','off')
    ylabel(['Events/min (#)'])
    xlabel(['Arbitrary angle groups (degs)'])
    %xlim([0.5,size(sepIndex,2)*size(altAngGroups,2)+0.5])
    xlim([0.5,size(sepIndex,2)*size(overAltAngGroups{1},2)+0.5])
    xtickangle(320)
    title(['Pooled event counts/min separated by state'])
    %And stats
    %inputData = nan( size(pooledArbCountState{1},1) , size(sepIndex,2)*size(altAngGroups,2) );
    inputData = nan( size(plotDataState{1},1) , size(sepIndex,2)*size(overAltAngGroups{1},2) );
    for sepInd = 1:size(sepIndex,2)
        inputData( : , ([0:1]+sepInd*size(sepIndex,2))-1 ) = plotDataState{sepInd};
    end
    barStats(inputData,alphaValue,exTick);
    
    %Sri boxplots
    if doSriBoxPlot == 1
        %Pooled event counts as prop. of total across arbitrary angle groups
        sriBoxPlot(pooledArbCountProp,alphaValue,exLabels,0.2,[],... %Note: Use of exLabels is unstable
            [{'Alt PE event counts'},{'Pooled event counts as prop. of total across arbitrary angle groups'}],0,0)
        
        %Pooled Z-scored event durations separated by state
        inputData = nan( size(pooledArbSizesZScoreState{1},1) , size(sepIndex,2)*size(overAltAngGroups{1},2) );
        for sepInd = 1:size(sepIndex,2)
            inputData( : , ([0:1]+sepInd*size(sepIndex,2))-1 ) = pooledArbSizesZScoreState{sepInd};
        end
        sriBoxPlot(inputData,alphaValue,repmat(exLabels,1,size(sepIndex,2)),0.2,cell2mat( repelem( sepColours, 1, size(sepIndex,2) ) ),...
            [{'Pooled event durs'},{'Pooled Z-scored event durations separated by state'}],0,0)
    end
    
    %----------
    
    %Sizes pooled
    figure
    subplot(2,2,1)
    errorbar( nanmean(pooledArbSizes,1) , nanstd(pooledArbSizes,[],1) / sqrt(size(pooledArbSizes,1)) )
    %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
    %xlim([0.5,size(altAngGroups,2)+0.5])
    %xticks([1:size(altAngGroups,2)])
    xlim([0.5,size(overAltAngGroups{1},2)+0.5])
    xticks([1:size(overAltAngGroups{1},2)])
    xticklabels(exLabels)
    xlabel(['Arbitrary angle groups (degs)'])
    ylabel(['Event sizes (Frames)'])
    %title('Pooled event counts across arbitrary angle groups')
    title(['Pooled event durations across arbitrary angle groups'])
    %And stats
    inputData = pooledArbSizes;
    barStats(inputData,alphaValue);
    
    %Z-scored sizes
    subplot(2,2,3)
    errorbar( nanmean(pooledArbSizesZScore,1) , nanstd(pooledArbSizesZScore,[],1) / sqrt(size(pooledArbSizesZScore,1)) )
    %ylim([0, (nanmax(arbSizeMean)+nanmax(arbSizeSEM))*1.1])
    %xlim([0.5,size(altAngGroups,2)+0.5])
    %xticks([1:size(altAngGroups,2)])
    xlim([0.5,size(overAltAngGroups{1},2)+0.5])
    xticks([1:size(overAltAngGroups{1},2)])
    xticklabels(exLabels)
    xlabel(['Arbitrary angle groups (degs)'])
    ylabel(['Z-scored size'])
    title('Pooled event Z-scored durations across arbitrary angle groups')
    set(gcf,'Name','Alt PE event durations')
    %And stats
    inputData = pooledArbSizesZScore;
    barStats(inputData,alphaValue);    
    
    %Sizes, separated into inBouts and outBouts
    subplot(2,2,2)
    exTick = [];
    for sepInd = 1:size(sepIndex,2)
        errorbar( ([0.25:0.5:0.75]+sepInd*size(sepIndex,2))-1, nanmean(pooledArbSizesState{sepInd},1) , nanstd(pooledArbSizesState{sepInd},[],1) / sqrt(size(pooledArbSizesState{sepInd},1)), sepColours{sepInd} )
        exTick = [exTick, [0.25:0.5:0.75]+sepInd*size(sepIndex,2)-1];
        hold on
    end
    xticks(exTick)
    xticklabels(repmat(exLabels,1,2))
    legend([sepIndex],'Color', 'none','AutoUpdate','off')
    ylabel(['Event duration (Frames)'])
    xlabel(['Arbitrary angle groups (degs)'])
    %xlim([0.5,size(sepIndex,2)*size(altAngGroups,2)+0.5])
    xlim([0.5,size(sepIndex,2)*size(overAltAngGroups{1},2)+0.5])
    xtickangle(320)
    title(['Pooled event durations separated by state'])
    %And stats
    %inputData = nan( size(pooledArbSizesState{1},1) , size(sepIndex,2)*size(altAngGroups,2) );
    inputData = nan( size(pooledArbSizesState{1},1) , size(sepIndex,2)*size(overAltAngGroups{1},2) );
    for sepInd = 1:size(sepIndex,2)
        inputData( : , ([0:1]+sepInd*size(sepIndex,2))-1 ) = pooledArbSizesState{sepInd};
    end
    barStats(inputData,alphaValue,exTick);  
    
    %Z-scored sizes, separated into inBouts and outBouts
    subplot(2,2,4)
    exTick = [];
    for sepInd = 1:size(sepIndex,2)
        errorbar( ([0.25:0.5:0.75]+sepInd*size(sepIndex,2))-1, nanmean(pooledArbSizesZScoreState{sepInd},1) , nanstd(pooledArbSizesZScoreState{sepInd},[],1) / sqrt(size(pooledArbSizesZScoreState{sepInd},1)), sepColours{sepInd} )
        exTick = [exTick, [0.25:0.5:0.75]+sepInd*size(sepIndex,2)-1];
        hold on
    end
    xticks(exTick)
    xticklabels(repmat(exLabels,1,2))
    legend([sepIndex],'Color', 'none','AutoUpdate','off')
    ylabel(['Z-scored size'])
    xlabel(['Arbitrary angle groups (degs)'])
    %xlim([0.5,size(sepIndex,2)*size(altAngGroups,2)+0.5])
    xlim([0.5,size(sepIndex,2)*size(overAltAngGroups{1},2)+0.5])
    xtickangle(320)
    title(['Pooled Z-scored event durations separated by state'])
    %And stats
    %inputData = nan( size(pooledArbSizesZScoreState{1},1) , size(sepIndex,2)*size(altAngGroups,2) );
    inputData = nan( size(pooledArbSizesZScoreState{1},1) , size(sepIndex,2)*size(overAltAngGroups{1},2) );
    for sepInd = 1:size(sepIndex,2)
        inputData( : , ([0:1]+sepInd*size(sepIndex,2))-1 ) = pooledArbSizesZScoreState{sepInd};
    end
    barStats(inputData,alphaValue,exTick);
    hold off
    
    %----------
    
    %Segment counts (if applicable)
    if splitBouts == 1
        figure
        for arbInd = 1:size(overAltAngGroups{1},2)
            %Count
            subplot(2, size(overAltAngGroups{1},2) , arbInd )
            barwitherr( nanstd( pooledArbCountFLID{arbInd} , [] , 1 ) / sqrt(size(pooledArbCountFLID{arbInd},1)) , nanmean(pooledArbCountFLID{arbInd},1) )
            xticklabels(splitDursText)
            xtickangle(300)
            ylabel(['Count'])
            title(['Arb group ',num2str(arbInd),' count'])
            barStats(pooledArbCountFLID{arbInd},alphaValue);
            %Norm count
            subplot(2, size(overAltAngGroups{1},2) , arbInd+size(overAltAngGroups{1},2) )
            barwitherr( nanstd( pooledArbCountFLIDNorm{arbInd} , [] , 1 ) / sqrt(size(pooledArbCountFLIDNorm{arbInd},1)) , nanmean(pooledArbCountFLIDNorm{arbInd},1) )
            xticklabels(splitDursText)
            xtickangle(300)
            ylabel(['Count'])
            title(['Arb group ',num2str(arbInd),' normalised count'])
            barStats(pooledArbCountFLIDNorm{arbInd},alphaValue);
        end        
    end
    
    %----------
    
    %Individual mean traces
    figure
    for IIDN = 1:size(overAllPE,2)
        altAngGroups = overAltAngGroups{IIDN};
        subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        leLabels = [];
        for arbInd = 1:size(altAngGroups,2)
            coords = overAllPE(IIDN).altStruct.probAngMeds >= altAngGroups{arbInd}(1) & overAllPE(IIDN).altStruct.probAngMeds <= altAngGroups{arbInd}(2);
            plotData = nanmean( overAllPE(IIDN).altStruct.probUpps(coords,:) , 1 );
            plotSEM = nanstd( overAllPE(IIDN).altStruct.probUpps(coords,:) , [], 1 ) ./ sqrt( nansum(coords) );
            shadeCoordsX = [ 1:size(plotData,2), flip(1:size(plotData,2)) ];
            shadeCoordsY = [ plotData+plotSEM , flip(plotData-plotSEM) ];
            fill(shadeCoordsX, shadeCoordsY, arbColours(arbInd,:) )
            alpha(0.25)
            hold on
            plot( plotData, 'Color', arbColours(arbInd,:) )
            leLabels{arbInd} = [ 'Arb group ',num2str(arbInd) ];
        end
        legend([repelem(leLabels,1,2)],'Color', 'none','AutoUpdate','off') %Repetition of element necessary because shading
        xlim([0,arbitraryPlotDuration*overVar(IIDN).dataFrameRate])
        xlabel(['Time (frames)'])
        ylabel(['Proboscis event distance (px)'])
        title(overVar(IIDN).flyName)
        hold off
    end
    set(gcf,'Name', 'Individual PE event traces' )
    
    %----------
    
    %Arb coord traces
    coordStruct = struct;
    figure
    for IIDN = 1:size(overAllPE,2)
        altAngGroups = overAltAngGroups{IIDN};
        subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        for arbInd = 1:size(altAngGroups,2)
            coords = overAllPE(IIDN).altStruct.probAngMeds >= altAngGroups{arbInd}(1) ...
                & overAllPE(IIDN).altStruct.probAngMeds <= altAngGroups{arbInd}(2);
            temp = [];
            temp(:,1) = overAllPE(IIDN).altStruct.probInds(coords);
            temp(:,2) = overAllPE(IIDN).altStruct.probSizes(coords);
            temp2 = nan( 2 , nanmax(temp(:,2)) , size(temp,1) ); %Rows - Time, Cols - X/Y, Layers - Events
            for i = 1:size(temp,1)
                temp2( 1:2 , 1:temp(i,2) , i ) = [ overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_x( temp(i,1):temp(i,1)+temp(i,2)-1 ) ,...
                    overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_y( temp(i,1):temp(i,1)+temp(i,2)-1 ) ]'; %Original coords (Uncorrected)
                temp2(2,:,i) = -temp2(2,:,i); %Invert, because reasons
                if baselineCorrectPEs == 1
                    %temp2( = thisData - nanmin(thisData); %Baseline correct data by overall minimum
                    %temp2(1,:,i) = temp2(1,:,i) - nanmin( temp2(1,:,i) );
                    %temp2(2,:,i) = temp2(2,:,i) - nanmin( temp2(2,:,i) );
                    temp2(1,:,i) = temp2(1,:,i) - temp2(1,1,i); %Correct start point to 0
                    temp2(2,:,i) = temp2(2,:,i) - temp2(2,1,i);
                end
            end
            coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).inds = temp(:,1);
            coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).sizes = temp(:,2);
            coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords = temp2;
            
            %And plot
            hold on
            for i = 1:size(coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords,3)
                plot( coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(1,:,i) , coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(2,:,i) , 'Color', arbColours(arbInd,:) )
            end
            %plot( nanmean( coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(1,:,:) ,3) , ...
            %    nanmean( coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(2,:,:) ,3) , 'Color', 'k')
            
%scatter( coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(1,1,i) , coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(2,1,i), 'g', 'filled' )
%scatter( coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(1,end,i) , coordStruct(IIDN).(strcat('arbGroup',num2str(arbInd))).coords(2,end,i), 'r', 'filled' )
            
        end
        hold off
        title([overVar(IIDN).flyName,' Arb coords'])
    end
    set(gcf,'Name', 'Arb coords')
    
    %Testatory plot useful for finding good coords examples
    %{
    for i = 1:size(overAllPE(IIDN).altStruct.probInds,1)
        %if overAllPE(IIDN).altStruct.probAngMeds(i) < 305 && overAllPE(IIDN).altStruct.probSizes(i) > 90 %Reaches
        if overAllPE(IIDN).altStruct.probAngMeds(i) < 290 && overAllPE(IIDN).altStruct.probSizes(i) > 90 %PEs
            clf
            %disp(num2str(i))
            nurg = overAllPE(IIDN).altStruct.probInds(i);
            blx = overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_x(nurg-1000:nurg+1000);
            bly = overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_y(nurg-1000:nurg+1000);
            %%coords = [overAllPE(IIDN).altStruct.probInds(i) : overAllPE(IIDN).altStruct.probInds(i) + overAllPE(IIDN).altStruct.probSizes(i)];
            %%blx = overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_x(coords);
            %%bly = overVar(IIDN).overGlob.(overVar(IIDN).dlcProbDataLocation).proboscis_y(coords);

            %plot( blx, bly )
            plot( smooth(blx,overVar(IIDN).dataFrameRate), smooth(bly,overVar(IIDN).dataFrameRate) )
            title([num2str(i),' (',num2str(coords(1)),':',num2str(coords(end)),')'])

            ylim([130-70,130])
            xlim([100,100+70])
            pause(2)
        end
    end
    %}
    
end
%%
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%Inter-PE-interval individual histogram (Bart-hist)
%cutOffDataAt8H = 1; %Whether to cut off data at 8h to match ephys sleep recordings (Moved up above)

%inBouts + outBouts + all
%{
targPEsMod = [targPEs,{'allLOCS'}]; %Tack on all PEs to the existing PE targets
targPEsIndexMod = [targPEs,{'all'}]; %And ditto for the index
%}
%inBouts + outBouts
targPEsMod = [targPEs]; %Tack on all PEs to the existing PE targets
targPEsIndexMod = [targPEs]; %And ditto for the index

%New style (All plotted on all figures)
%colourDictionary = [{'r'},{'b'},{'k'},{'m'},{'c'}]; %Used for auto colouring certain plots (Note: Ordering caused some confusion wrt inBouts vs outBouts)
%colourDictionary = [{'b'},{'r'},{'k'},{'m'},{'c'}]; %Used for auto colouring certain plots (Reordered)
%for peType = 1:size(targPEsMod,2) %Use previously defined PE categories
%thisPETarget = targPEsMod{peType};
figure
%arbitraryTooFarThreshold = 10*dataFrameRate; %Sets the limit for how far between PEs before interval not counted (in frames)
    %(Mainly used for preventing hist bins from having to be gigantic)
arbitraryTooFarThreshold = 12; %Sets the limit for how far between PEs before interval not counted (in seconds)

%overHist = struct; %Will hold hist data across flies

alphaValues = linspace(1,0,size(targPEsMod,2)+1); %Generate values that will be used for bar alphas (+1 because lazy maths)

for IIDN = 1:size(overAllPE,2)
    typeCapturePercent = [];
    for peType = 1:size(targPEsMod,2) %Use previously defined PE categories
        thisPETarget = targPEsMod{peType};
        thisLocData = []; %Index of all detected PEs (frames since start of recording)
        %locDiffData = []; %Raw difference in indexes between LOCations of all detected PEs
        locDiffDataTime = []; %Ditto above, except converted to seconds through the power of POSIX
        %if isempty(overAllPE(IIDN).allPEStruct.allLOCS) ~= 1 %Not dynamic
        if eval(['isempty(overAllPE(IIDN).allPEStruct.',thisPETarget,') ~= 1']) %Dynamic
            %thisLocData = overAllPE(IIDN).allPEStruct.allLOCS;
            eval(['thisLocData = overAllPE(IIDN).allPEStruct.',thisPETarget,';'])
            if cutOffDataAt8H == 1
                %thisLocData( thisLocData > 8*60*60*dataFrameRate ) = []; %Cut off every LOC larger than 8h*60m*60s*30fps
                thisLocData = thisLocData( ( overAllPE(IIDN).allPEStruct.allPERail( thisLocData , 1) - overAllPE(IIDN).allPEStruct.allPERail( 1 , 1) ) < 8*60*60 ); %Cut off ever LOC that happened more than 8h after the first POSIX
            end
            %locDiffData = diff(thisLocData); %Difference in indices; Frame reference (not seconds)
        end

        %locDiffData = locDiffData / dataFrameRate; %Convert to seconds (Note: Assumption of perfect framerate adherence)
        
        locDiffDataTime = overAllPE(IIDN).allPEStruct.allPERail( circshift(thisLocData,-1) , 1) - overAllPE(IIDN).allPEStruct.allPERail( thisLocData , 1);
        locDiffDataTime = locDiffDataTime(1:end-1); %Remove the last element, since it is meaningless

        %captureNum = nansum(locDiffData <= arbitraryTooFarThreshold); %How many interals fall under the arbitrary threshold (i.e. how many are 'captured' by the hist)
        captureNum = nansum(locDiffDataTime <= arbitraryTooFarThreshold); %How many intervals fall under the arbitrary threshold (i.e. how many are 'captured' by the hist)
        %capturePercent = ( captureNum / size(locDiffData,1) ) * 100;
        capturePercent = ( captureNum / size(locDiffDataTime,1) ) * 100;
        typeCapturePercent(peType) = capturePercent;

        %locDiffData(locDiffData > arbitraryTooFarThreshold) = [];
        locDiffDataTime(locDiffDataTime > arbitraryTooFarThreshold) = [];

        if subPlotMode == 1
            subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        else
            scrollsubplot(4,1,IIDN)
        end
        
        nBins = 128;
        binCentres = linspace(0,arbitraryTooFarThreshold,nBins); %Needed because otherwise hist bin centres vary slightly depending on how close the largest value/s are to arbitraryTooFarThreshold 
        %[N,X] = hist(locDiffData,binCentres);
        [N,X] = hist(locDiffDataTime,binCentres);
        %overHist(IIDN).N = N;
        %overHist(IIDN).X = X;
        overHist(IIDN).(targPEsIndexMod{peType}).N = N;
        overHist(IIDN).(targPEsIndexMod{peType}).X = X;
        %Old, actual bar plot
        %h = bar(X,N);
        %set(h,'FaceColor',colourDictionary{peType});
        %set(h,'Alpha',0.5);
        %BOOTLEG MANUAL BAR PLOT (because 2014b does not support Alpha for bars)
        for barInd = 1:size(X,2)
            xCoords = [ X(barInd)-0.5*(arbitraryTooFarThreshold/(nBins-1)) , X(barInd)-0.5*(arbitraryTooFarThreshold/(nBins-1)), ...
                X(barInd)+0.5*(arbitraryTooFarThreshold/(nBins-1)) , X(barInd)+0.5*(arbitraryTooFarThreshold/(nBins-1)) ];
                %Should place fill in bin centre
            yCoords = [0, N(barInd) , N(barInd) , 0];
            h = fill(xCoords,yCoords,colourDictionary{peType});
            set(h,'FaceAlpha',alphaValues(peType));
            hold on
        end
        
        %hold on
    end
    xlim([0 arbitraryTooFarThreshold])

    line('XData', [arbitraryTooFarThreshold arbitraryTooFarThreshold], 'YData', [0,nanmax(N)], 'LineStyle', '--', 'LineWidth', 1, 'Color','g');

    try
        %figTitle = [overVar(IIDN).flyName, ' - ',num2str(capturePercent),'% captured (0 - ',num2str(arbitraryTooFarThreshold),'s)'];
        figTitle = [overVar(IIDN).flyName, ' - [',num2str(typeCapturePercent),']% captured (0 - ',num2str(arbitraryTooFarThreshold),'s)'];
    catch
        %figTitle = ['Dataset #',num2str(IIDN),' - ',num2str(capturePercent),'% captured (0 - ',num2str(arbitraryTooFarThreshold),'s)']; %Only really likely if this portion is being run without a proper runthrough beforehand
        figTitle = ['Dataset #',num2str(IIDN),' - [',num2str(typeCapturePercent),']% captured (0 - ',num2str(arbitraryTooFarThreshold),'s)'];
    end
    if cutOffDataAt8H == 1
        figTitle = [figTitle,' (Cut off at 8h)'];
    end
    %figTitle = [figTitle,' - [', targPEsIndexMod{:},']'];
    title(figTitle);

    %Ancillary
    if useExclusionCriteria == 1 && doLonesomeExclusion == 1
        line('XData', [(probInterval*overVar(IIDN).dataFrameRate)/overVar(IIDN).dataFrameRate (probInterval*overVar(IIDN).dataFrameRate)/overVar(IIDN).dataFrameRate], 'YData', [0,nanmax(N)], 'LineStyle', '--', 'LineWidth', 1, 'Color','r');
            %Place a line at the interval below which points are excluded because lonesome
    end
end

%Pooled inter-PE-interval histogram (w/ error bars)
overType = struct;

plotDataDesc{1} = 'Raw count';
plotDataDesc{2} = 'Fraction';
plotDataDesc{3} = 'Sum';

plotDataYLabels{1} = 'Count';
plotDataYLabels{2} = 'Prop. of all';
plotDataYLabels{3} = 'Count';

for peType = 1:size(targPEsMod,2)
    thisPETarget = targPEsIndexMod{peType};
    plotDataMean = []; plotDataSEM = []; 
    %plotDataDesc = []; plotDataYLabels = [];
    
    pooledN = []; %Stores all the N values from the preceding plot in one 2D matrix
    pooledNFrac = []; %As above, except normalised according to the max N of each fly
    for IIDN = 1:size(overHist,2)
        %pooledN(IIDN,:) = overHist(IIDN).N;
        pooledN(IIDN,:) = overHist(IIDN).(thisPETarget).N;
        pooledNFrac(IIDN,:) = pooledN(IIDN,:) / nansum(pooledN(IIDN,:));
    end
    
    pooledNMean = nanmean(pooledN,1); %Forced dimensionality because WIS
    pooledNFracMean = nanmean(pooledNFrac,1);
    
    if size(overHist,2) ~= 1
        pooledNSEM = nanstd(pooledN,1) / sqrt(size(pooledN,1));
        pooledNFracSEM = nanstd(pooledNFrac,1) / sqrt(size(pooledNFrac,1));
    else %In case of single dataset, set SEM to be 0
        pooledNSEM = zeros(1,size(pooledN,2)); %Fake, zero equivalent SEMs
        pooledNFracSEM = zeros(1,size(pooledN,2)); %Fake, zero equivalent SEMs
    end

    pooledNSum = nansum(pooledN,1);
    pooledNSumSEM = zeros(1,size(pooledN,2)); %Fake, zero equivalent SEMs

    %Do both plots one after another (because I am too lazy to replicate the code)
    plotDataMean{1} = pooledNMean;
    plotDataMean{2} = pooledNFracMean;
    plotDataMean{3} = pooledNSum;
    plotDataSEM{1} = pooledNSEM;
    plotDataSEM{2} = pooledNFracSEM;
    plotDataSEM{3} = pooledNSumSEM;
    
    %Moved up above
    %{
    plotDataDesc{1} = 'Raw count';
    plotDataDesc{2} = 'Fraction';
    plotDataDesc{3} = 'Sum';

    plotDataYLabels{1} = 'Count';
    plotDataYLabels{2} = 'Prop. of all';
    plotDataYLabels{3} = 'Count';
    %}
    
    overType.(thisPETarget).plotDataMean = plotDataMean;
    overType.(thisPETarget).plotDataSEM = plotDataSEM;
    overType.(thisPETarget).plotDataDesc = plotDataDesc;
    overType.(thisPETarget).plotDataYLabels = plotDataYLabels;
end
plotDataMean = []; plotDataSEM = []; %Just in case of missed referencing update
%plotDataDesc = []; plotDataYLabels = []; 

for i = 1:size(plotDataDesc,2)
    figure

    for peType = 1:size(targPEsMod,2)
        thisPETarget = targPEsIndexMod{peType};
        
        %thisDataMean = plotDataMean{i};
        %thisDataSEM = plotDataSEM{i};
        thisDataMean = overType.(thisPETarget).plotDataMean{i};
        thisDataSEM = overType.(thisPETarget).plotDataSEM{i};
        %h = bar(binCentres,thisDataMean);
        for barInd = 1:size(binCentres,2)
            xCoords = [ binCentres(barInd)-0.5*(arbitraryTooFarThreshold/(nBins-1)) , binCentres(barInd)-0.5*(arbitraryTooFarThreshold/(nBins-1)), ...
                binCentres(barInd)+0.5*(arbitraryTooFarThreshold/(nBins-1)) , binCentres(barInd)+0.5*(arbitraryTooFarThreshold/(nBins-1)) ];
                %Should place fill in bin centre
            yCoords = [0, thisDataMean(barInd) , thisDataMean(barInd) , 0];
            h = fill(xCoords,yCoords,colourDictionary{peType});
            set(h,'FaceAlpha',alphaValues(peType));
            hold on
        end
        %set(h,'FaceColor',[0.3,0.3,0.3]);
        %hold on
        for z = 1:size(binCentres,2)
            %line([binCentres(z),binCentres(z)],[thisDataMean(z) - thisDataSEM(z),thisDataMean(z) + thisDataSEM(z)], 'Color', 'm')
            line([binCentres(z),binCentres(z)],[thisDataMean(z) - thisDataSEM(z),thisDataMean(z) + thisDataSEM(z)], 'Color', colourDictionary{peType})
                %BOOTLEG CUSTOM ERROR BARS
        end
        
    end

    xlim([0,arbitraryTooFarThreshold])
    ylabel([plotDataYLabels{i}])
    xlabel(['Time between PEs (s)'])

    line('XData', [arbitraryTooFarThreshold arbitraryTooFarThreshold], 'YData', [0,nanmax(thisDataMean)], 'LineStyle', '--', 'LineWidth', 1, 'Color','g');

    figTitle = ['Pooled inter-PE-interval (0 - ',num2str(arbitraryTooFarThreshold),'s) - ',plotDataDesc{i}, ' - N = ',num2str(size(overHist,2))];
    if cutOffDataAt8H == 1
        figTitle = [figTitle,' (Cut off at 8h)'];
    end
    %figTitle = [figTitle,' - ', targPEsIndexMod{peType}];
    title(figTitle)

    %Ancillary
    if useExclusionCriteria == 1 && doLonesomeExclusion == 1
        line('XData', [(probInterval*overVar(1).dataFrameRate)/overVar(1).dataFrameRate (probInterval*overVar(1).dataFrameRate)/overVar(1).dataFrameRate], 'YData', [0,nanmax(thisDataMean)], 'LineStyle', '--', 'LineWidth', 1, 'Color','r');
            %Place a line at the interval below which points are excluded because lonesome
            %Use first dataset framerate as exemplar
    end

end
%end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%--------------------------------------------------------------------------

%Plot average perio frequency peaks
if doTimeCalcs == 1 && doFFT == 1

    %overPeak = struct;
    for IIDN = 1:size(overVar,2)
        %Calculate
        peakData = struct;
        for side = 1:size(processList,2)
            peakData.(processList{side}).data = ...
                overVar(IIDN).railStruct.sleepRail( overVar(IIDN).railStruct.sleepRail(:,2+side*2)  == 1 ,3+side*2);
            peakData.(processList{side}).mean = ...
                nanmean( overVar(IIDN).railStruct.sleepRail( overVar(IIDN).railStruct.sleepRail(:,2+side*2)  == 1 ,3+side*2) );
            peakData.(processList{side}).median = ...
                nanmedian( overVar(IIDN).railStruct.sleepRail( overVar(IIDN).railStruct.sleepRail(:,2+side*2)  == 1 ,3+side*2) );
            peakData.(processList{side}).STD = ...
                nanstd( overVar(IIDN).railStruct.sleepRail( overVar(IIDN).railStruct.sleepRail(:,2+side*2)  == 1 ,3+side*2) );
            peakData.(processList{side}).SEM = ...
                nanstd( overVar(IIDN).railStruct.sleepRail( overVar(IIDN).railStruct.sleepRail(:,2+side*2)  == 1 ,3+side*2) ) / ...
                sqrt( size(overVar(IIDN).railStruct.sleepRail( overVar(IIDN).railStruct.sleepRail(:,2+side*2)  == 1 ,3+side*2),1) );
        end
        
        %Plot
        %{
        figure
        hold on
        for side = 1:size(processList,2)
            bar( side , peakData.(processList{side}).median )
            %Bootleg custom error bar
            line( [side,side] , [ peakData.(processList{side}).median+peakData.(processList{side}).SEM , peakData.(processList{side}).median-peakData.(processList{side}).SEM ], 'Color', 'k' )
            %line( [side,side] , [ peakData.(processList{side}).median+peakData.(processList{side}).STD , peakData.(processList{side}).median-peakData.(processList{side}).STD ], 'Color', 'k' )
        end
        %}
        
        %Violin
        figure
        exLabels = [];
        hold on
        plotData = [];
        for side = 1:size(processList,2)
            plotData{side} = peakData.(processList{side}).data;
            exLabels{side} = processList{side};
        end
        for peType = 1:size(targPEsMod,2)
            thisPETarget = targPEsMod{peType};
            temp = [];
            tempN = overHist(IIDN).(thisPETarget).N;
            tempX = overHist(IIDN).(thisPETarget).X;
            for i = 1:size(tempN,2)
                temp = [temp; repmat(1/tempX(i),tempN(i),1) ];
            end
            temp(temp == Inf) = NaN; %Covers the case where interval == 0
            if isempty( temp ) ~= 1
                plotData{ size(plotData,2)+1 } = temp;
                exLabels{ size(exLabels,2)+1 } = thisPETarget;
            end
        end
        %Minor violin QA
        for i = size(plotData,2):-1:1
            if nansum( ~isnan(plotData{i}) ) < 1
                plotData(i) = [];
                exLabels(i) = [];
            end
        end
        if isempty( plotData ) ~= 1
            violin( plotData );
            xticks([1:size(plotData,2)])
            xticklabels(exLabels)
            %Just like, so many points
            hold on
            for i = 1:size(plotData,2)
                text( i , nanmax(plotData{i})*1.2, ['n=',num2str(size(plotData{i},1))] )
                %scatter( [repmat(i,size(plotData{i},1),1)] , plotData{i} )
            end
            ylim('auto')
        end
        title(['Perio and PE freq - ',overVar(IIDN).flyName])
      
        %overPeak(IIDN).peakData = peakData;
        %overPeak(IIDN).plotData = plotData;
        %overPeak(IIDN).labels = exLabels;
        
        overPlot.violin(IIDN).plotData = plotData;
        overPlot.violin(IIDN).labels = exLabels;
    end
    
    %Grand average barplots
        %xRight, xLeft, and probData are from detected periodicity within bouts only
        %inBoutPEsLOCS and outBoutPEsLOCS are calculated from inter-PE-interval data for sleep and wake , respectively
    figure
    hold on
    plotData = [];
    for IIDN = 1:size( overPlot.violin,2 )
        fielNames = overPlot.violin(IIDN).labels;
        for fiel = 1:size(fielNames,2)
            plotData.mean.( fielNames{fiel} )(IIDN) = nanmean( overPlot.violin(IIDN).plotData{fiel} );
            
            plotData.mean.( fielNames{fiel} )( plotData.mean.( fielNames{fiel} ) == 0 ) = NaN; %Running QA for simplicity
                %Note: Techncally excludes a freq of 0, but since that is impossible, it is no big loss
        end
    end
    exLabels = fieldnames( plotData.mean );
    for fiel = 1:size( exLabels,1 )
        bar( [fiel] , [nanmean( plotData.mean.(exLabels{fiel}) )] )
        errorbar( [fiel] , [nanmean( plotData.mean.(exLabels{fiel}) )] , [nanstd(plotData.mean.(exLabels{fiel})) / sqrt(size(plotData.mean.(exLabels{fiel}),2))] )
        scatter( [ repmat(fiel, 1, size(plotData.mean.(exLabels{fiel}),2) ) ] , [plotData.mean.(exLabels{fiel})] )
    end
    xticks([1:size(exLabels,1)]);
    xticklabels(exLabels);
    ylabel(['Mean freq. of periodicity/Inter PE interval (Hz)'])
    figTitle = ['Grand av. perio + PE perio freqs'];
    if doAggPEFlat == 1
        figTitle = [figTitle, char(10), '(Non-PE periodicity aggressively flattened during PEs)'];
    end
    title(figTitle)
    
    %----------------------------------------------------------------------
    
    %Fraction of PEs that coincide with PE periodicity
    if isempty( strfind( [processList{:}] , 'probData' ) ) ~= 1
        plotData = []; %Fraction of (bout) PEs that coincided with PE periodicity
        freqData = []; %Mean freq of periodicity during said coincidences
        for side = 1:size(processList,2)
            if contains( processList{side} , 'probData' ) == 1
                for IIDN = 1:size(overVar,2)
                    plotData{1}(IIDN) = ...
                        nansum( overVar(IIDN).railStruct.sleepRail(:,3) == 1 & overVar(IIDN).railStruct.sleepRail(:,2+side*2) == 1 ) / ...
                        nansum( overVar(IIDN).railStruct.sleepRail(:,3) == 1 & overVar(IIDN).railStruct.sleepRail(:,1) == 1 );
                    %Total number of PEs (during bouts) that were accompanied by PE perio. / total number of (bout) PEs
                        %Note that PE perio is only calculated during bouts, hence the extra boolean on the second line
                    freqData{1}(IIDN) = nanmean( overVar(IIDN).railStruct.sleepRail( [find( overVar(IIDN).railStruct.sleepRail(:,3) == 1 & overVar(IIDN).railStruct.sleepRail(:,2+side*2) == 1 )] ,3+side*2) );
                end
            end
        end
        %{
        %inBouts / outBouts separation
            %Currently infeasible because FFTs/SNR not calculated outside of bouts
        for

        end
        %}
        figure
        subplot(1,4,[1:3])
        hold on
        bar( nanmean(plotData{1}) )
        errorbar( 1, nanmean(plotData{1}) , nanstd( plotData{1} ) / sqrt( size( plotData{1},2 ) ) )
        scatter( repmat(1,1,size(plotData{1},2)) , plotData{1} )
        ylabel(['Fraction of bout PEs'])
        title(['Fraction of bout PEs coinciding with PE perio. (N=',num2str(size( plotData{1},2 )),')'])

        subplot(1,4,[4])
        hold on
        %bar( nanmean(freqData{1}) )
        errorbar( 1, nanmean(freqData{1}) , nanstd( freqData{1} ) / sqrt( size( freqData{1},2 ) ) )
        scatter( repmat(1,1,size(freqData{1},2)) , freqData{1} )
        ylabel(['Freq during coincidence (Hz)'])
        title(['Frequency of PE perio. during PEs'])
    end
    
    %----------------------------------------------------------------------
    
    %PE angle plots
    %if
    plotData = [];
    plotDataInOut = [{},{}]; %%"Gael Stone"
    for IIDN = 1:size(overAllPE,2)
        if isfield(overAllPE(IIDN).allPEStruct, 'locAngs') == 1
            plotData(IIDN, 1:size(overAllPE(IIDN).allPEStruct.locAngs,1) ) = overAllPE(IIDN).allPEStruct.locAngs';
            plotDataInOut{1}(IIDN, 1:size(overAllPE(IIDN).allPEStruct.inBoutPEAngs,1) ) = overAllPE(IIDN).allPEStruct.inBoutPEAngs';
            plotDataInOut{2}(IIDN, 1:size(overAllPE(IIDN).allPEStruct.outBoutPEAngs,1) ) = overAllPE(IIDN).allPEStruct.outBoutPEAngs';
        else
            plotData(IIDN,:) = NaN; %Will fail if first (and/or only) fly empty for this data
            plotDataInOut{1}(IIDN,:) = NaN; 
            plotDataInOut{2}(IIDN,:) = NaN;
        end
    end
    plotData(plotData == 0) = NaN; %Note: True zeroes will be removed, but odds for perfect zero seem low
    plotDataInOut{1}(plotDataInOut{1}==0) = NaN; 
    plotDataInOut{2}(plotDataInOut{2}==0) = NaN; 
    
    %Individual
    figure
    for IIDN = 1:size(overAllPE,2)
        if subPlotMode == 1
            subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        else
            scrollsubplot(4,1,IIDN)
        end
        
        %hist( plotData(IIDN,:) , 128 )
        histogram( plotData(IIDN,:) , 128, 'FaceColor', 'k', 'FaceAlpha', 0.3 ) %All
        hold on
        histogram( overAllPE(IIDN).allPEStruct.outBoutPEAngs , 128, 'FaceColor', 'r', 'FaceAlpha', 0.3 ) %inBouts
        histogram( overAllPE(IIDN).allPEStruct.inBoutPEAngs , 128, 'FaceColor', 'b', 'FaceAlpha', 0.3 ) %inBouts
        
        legend([{'All'},{'outBouts'},{'inBouts'}])
        xlabel(['PE angle'])
        xlim([ nanmin(reshape( plotData, [1,size(plotData,1)*size(plotData,2)] )), ...
            nanmax(reshape( plotData, [1,size(plotData,1)*size(plotData,2)] )) ]) %Not pretty but it works
        titleStr = [num2str(IIDN),' - ',overVar(IIDN).fileDate,' - PE angle hist'];
        if bodyAngleCorrected == 1
            titleStr = [titleStr, char(10), '[Body angle corrected]'];
        else
            titleStr = [titleStr, char(10), '[Body angle not corrected]'];
        end
        title(titleStr)

    end
    set(gcf,'Name', 'PE angles individual')
    
    %Pooled
    figure
    %hist( reshape( plotData, [1,size(plotData,1)*size(plotData,2)] ) , 128 ) %Note that this reshaped array is disordered on account of columnwise operation
    histogram( reshape( plotData, [1,size(plotData,1)*size(plotData,2)] ) , 128, 'FaceColor', 'k' ) %Note that this reshaped array is disordered on account of columnwise operation
    hold on
    histogram( reshape( plotDataInOut{2}, [1,size(plotDataInOut{2},1)*size(plotDataInOut{2},2)] ) , 128, 'FaceColor', 'r', 'FaceAlpha', 0.3 )
    histogram( reshape( plotDataInOut{1}, [1,size(plotDataInOut{1},1)*size(plotDataInOut{1},2)] ) , 128, 'FaceColor', 'b', 'FaceAlpha', 0.3 )
    
    legend([{'All'},{'outBouts'},{'inBouts'}])
    xlabel(['PE angle'])
    titleStr = ['Pooled PE angles'];
    if bodyAngleCorrected == 1
        titleStr = [titleStr, char(10), '[Body angle corrected]'];
    else
        titleStr = [titleStr, char(10), '[Body angle not corrected]'];
    end
    title(titleStr)
    xlim([ nanmin(reshape( plotData, [1,size(plotData,1)*size(plotData,2)] )), ...
        nanmax(reshape( plotData, [1,size(plotData,1)*size(plotData,2)] )) ])
    set(gcf,'Name', 'PE angles pooled')
    
    %end
    
    %Individual Rose plot
    polarBinSize = 64;
    figure
    for IIDN = 1:size(overAllPE,2)
        if subPlotMode == 1
            subplot(ceil(size(overAllPE,2)/2),2,IIDN)
        else
            scrollsubplot(4,1,IIDN)
        end

        [aND,aKD]=rose( deg2rad(plotData(IIDN,:)) ,polarBinSize);
        [iND,iKD]=rose( deg2rad(overAllPE(IIDN).allPEStruct.inBoutPEAngs) ,polarBinSize);
        [oND,oKD]=rose( deg2rad(overAllPE(IIDN).allPEStruct.outBoutPEAngs) ,polarBinSize);
        %KD = KD / (0.5*sum(KD)); %New polar proportioning code
        %polar2(aND,aKD/nanmax(aKD),[0,1],'k')
        %polar2(iND,iKD/nanmax(iKD),[0,1],'b')
        %polar2(oND,oKD/nanmax(oKD),[0,1],'r')
        polar2(aND,aKD,'k')
        hold on
        polar2(iND,iKD,'b')
        polar2(oND,oKD,'r')
        titleStr = [overVar(IIDN).fileDate];
        if bodyAngleCorrected == 1
            titleStr = [titleStr, ' [C.]'];
        else
            titleStr = [titleStr, ' [Not C.]'];
        end
        title(titleStr)
        
    end
    
    %Combined pooled rose plot and pooled hist
    figure
    %Rose
    subplot(1,2,1)
    %[aND,aKD]=rose( deg2rad(plotData(:)) ,polarBinSize);
    [oND,oKD]=rose( deg2rad(plotDataInOut{2}(:)) ,polarBinSize);
    [iND,iKD]=rose( deg2rad(plotDataInOut{1}(:)) ,polarBinSize);
    %polar2(aND,aKD,'k')
    %hold on
    p = polar2(oND,oKD,'r');
    p.Color = [1,0,0,0.5];
    hold on
    p = polar2(iND,iKD,'b');
    p.Color = [0,0,1,0.5];

    titleStr = ['Pooled PE rose (N=',num2str(size(plotData,1)),')'];
    if bodyAngleCorrected == 1
        titleStr = [titleStr, ' [Body angle corrected]'];
    else
        titleStr = [titleStr, ' [Not corrected]'];
    end
    title(titleStr)
    legend([{'outBouts'},{'inBouts'}])
    
    %Hist
    subplot(1,2,2)
    histogram( reshape( plotDataInOut{2}, [1,size(plotDataInOut{2},1)*size(plotDataInOut{2},2)] ) , 128, 'FaceColor', 'r', 'FaceAlpha', 0.3 )
    hold on
    histogram( reshape( plotDataInOut{1}, [1,size(plotDataInOut{1},1)*size(plotDataInOut{1},2)] ) , 128, 'FaceColor', 'b', 'FaceAlpha', 0.3 )
    legend([{'outBouts'},{'inBouts'}])
    xlabel(['PE angle'])
    titleStr = ['Pooled PE angles'];
    if bodyAngleCorrected == 1
        titleStr = [titleStr, char(10), '[Body angle corrected]'];
    else
        titleStr = [titleStr, char(10), '[Body angle not corrected]'];
    end
    title(titleStr)
    xlim([ nanmin(reshape( plotData, [1,size(plotData,1)*size(plotData,2)] )), ...
        nanmax(reshape( plotData, [1,size(plotData,1)*size(plotData,2)] )) ])
    
    %----------------------------------------------------------------------
    
    %Individual Ws
    figure
    %overTargWs = [];
    for targInd = 1:size(targPEs,2)
        overTargWs{targInd} = NaN; %Because special snowflake
    end
    for IIDN = 1:size(overAllPE,2)
        subplot( ceil(size(overAllPE,2)/2),2,IIDN )
        for targInd = 1:size(targPEs,2)
            targWs{targInd} = [];
            temp = intersect( overAllPE(IIDN).allPEStruct.(targPEs{targInd}) , overAllPE(IIDN).allPEStruct.allLOCS );
            for i = 1:size(temp,1)
                targWs{targInd} = [targWs{targInd}; overAllPE(IIDN).allPEStruct.allW( find( overAllPE(IIDN).allPEStruct.allLOCS == temp(i), 1 ) ) ];
            end
            histogram( targWs{targInd} , 128, 'FaceColor', colourDictionary{targInd}, 'FaceAlpha', 0.3 )
            hold on
            overTargWs{targInd} = [overTargWs{targInd}; targWs{targInd}]; %Save for later use
            overTargWs{targInd}( isnan(overTargWs{targInd}) == 1 ) = []; 
        end
        xlabel(['W[idth]'])
        ylabel(['Count'])
        title([num2str(IIDN),' - ',overVar(IIDN).fileDate,' - PE W hist'])
        legend( targPEsIndex )
    end
    set(gcf,'Name', 'Individual_W_Histograms')
    
    %Pooled Ws
    figure
    for targInd = 1:size(targPEs,2)
        histogram( overTargWs{targInd} , 128, 'FaceColor', colourDictionary{targInd}, 'FaceAlpha', 0.3 )
        hold on
    end
    xlabel(['W[idth]'])
    ylabel(['Pooled count'])
    title(['Pooled PE W hist'])
    legend( targPEsIndex )
    set(gcf,'Name', 'Pooled_W_Histogram')
    
end

%--------------------------------------------------------------------------

%Make for loop to save figures
%Mk 3.5 (Borrowed from SASIFRAS and then back from OddballProcessing)
if automatedSavePlots == 1
    tic
    disp(['---- COMMENCING AUTOMATED FIGURE SAVING ----'])
    
    if clearOldFigures == 1
        %disp(['-- Clearing old figures --'])
        %oldName = strcat(autoFigPath,'\', progIdent, '*', additionalFigParams, '*.png');
        %oldName = strcat(autoFigPath,'\', '*.png'); %Removed progIdent
        oldName = strcat(autoFigPath,'\*', additionalFigParams, '*_auto.png');
        oldName = strrep(oldName, '**', '*'); %Quick strrep to convert **'s to *'s (Because otherwise MATLAB complains)
        oldFigList = dir(oldName);
        
        if size(oldFigList,1) > 0
            disp(['-- Old figures detected; Clearing --'])
        end
        
        s = warning('error', 'MATLAB:DELETE:Permission');
        for i = 1:size(oldFigList,1)
            try   
               delete(strcat([autoFigPath, '\', oldFigList(i).name]));
                    %Note: Theoretically only deletes figures generated by this script
               %disp(['-- Old workspace save deleted --'])
            catch
                ['#### Could not delete existing figure ####']
                %error = yes
            end
        end
        if size(oldFigList,1) > 0
            disp(['-- ',num2str(i),' Old figures cleared --'])
        end
    end

    figList = get(groot, 'Children');
    %figList = findall(groot, 'Type', 'figure');
    figNameTally = 0;
    figFailTally = 0;
    for i = 1:size(figList,1)
        try
                %Note: If being run post-hoc, it seems reverse indexing might be required for correct figure numbers
            figure(figList(i)) %Select figure

            set(gcf, 'Color', 'w');
            set(gcf,'units','normalized','outerposition',[0 0 1 1])

            %Save as PNG
            if isempty(figList(i).Name) ~= 1
                %saveName = strcat(autoFigPath,'\', progIdent, '_Fig_', num2str(figList(i).Number), '_', figList(i).Name ,'.png');
                thisFigName = figList(i).Name;
                [thisFigNameSafe, modified] = matlab.lang.makeValidName(figList(i).Name);
                %Report
                if modified == 1
                    disp(['Fig. ',num2str(i),' - "', figList(i).Name, '" renamed "',thisFigNameSafe,'"'])
                    figNameTally = figNameTally + 1;
                end
                %saveName = strcat(autoFigPath,'\', 'Fig_', num2str(figList(i).Number), '_', thisFigNameSafe ,'.png');
            else
                %saveName = strcat(figPath,'\', progIdent, '_Fig_', num2str(figList(i).Number) ,'.png');
                thisFigNameSafe = [];
                %saveName = strcat(autoFigPath,'\', 'Fig_', num2str(figList(i).Number) , additionalFigParams, '.png');
            end
            saveName = strcat(autoFigPath,'\', 'Fig_', num2str(figList(i).Number), '_', thisFigNameSafe, additionalFigParams ,'_auto.png');
            %export_fig(saveName)
            saveas(gcf,saveName,'png')

            if automatedSaveVectors == 1
                %Attempt save as vector if requested
                %saveName = strcat(vectorAutoFigPath,'\', progIdent, '_Fig_', num2str(figList(i).Number) , additionalFigParams, '.pdf');
                vecSaveName = strcat(vectorAutoFigPath,'\', 'Fig_', num2str(figList(i).Number) , thisFigNameSafe, additionalFigParams, '_auto.pdf');
                try
                    saveas(gca,vecSaveName, 'pdf');
                catch
                    disp(['## Could not vector-save Figure ', num2str(figList(i).Number), ' ##'])
                    figFailTally = figFailTally + 1;
                end
            end

            if closeFiguresAfterSaving == 1
                close gcf %Saves memory
            end
        catch
        %pause(0.25)
            disp(['## Could not save Figure ', num2str(figList(i).Number), ' ##'])
            figFailTally = figFailTally + 1;
        end
    end
    disp(['---- ', num2str(size(figList,1)), ' OPEN FIGURES SAVED ("',autoFigPath,'") in ',num2str(toc),'s ----'])
    if figFailTally > 0
        disp(['(There were ',num2str(figFailTally),' failures)'])
    end
end

%--------------------------------------------------------------------------

if doTimeCalcs == 1 && splitBouts == 1
    ['## ALERT: BOTH doTimeCalcs AND splitBouts WERE ACTIVE; CERTAIN METRICS WILL HAVE BEEN AFFECTED ##']
end

toc
%Fin

%Mk 1 - 542 lines
%Mk 2 - 514 lines
%Mk 3 - 980 lines
%Mk 4 - 1995 lines
%Mk 4.5 - 2169 lines
%Mk 4.75XM - 2134 lines
%Mk 4.95 - 2388 lines
%Mk 5XM - 2655 lines
%Mk 5.25XM - 3288 lines
%Mk 5.5XM - 3885 lines
%Mk 5.75XM - 4569 lines
%Mk 5.75 - 5240 lines
%Mk 6.35XM - 7304 lines
%Mk 6.45XM - 7606 lines
%Mk 6.55XM - 8248 lines
%Mk 7XM - 8814 lines
%Mk 7.55XM - 9195 lines

%{
function [P,ANOVATAB,STATS] = barStats(inputData,alphaValue)
    if size(inputData,1) > 1 || size(inputData,2) < 2
        %####
        %Follow-on stats (Pre function form)
        %inputData = plotData;
        %Stats
        statsData = []; %The data
        statsDataGroups = []; %The groups
        for x = 1:size(inputData,2)
            %statsData = [statsData,overFlyPTTs{x}'];
            statsData = [statsData,inputData(:,x)']; %Assumption of double nature, not cells like original
            %statsDataGroups = [statsDataGroups,repmat(x,1,size(overFlyPTTs{x},1))]; 
            statsDataGroups = [statsDataGroups,repmat(x,1,size( inputData(:,x) ,1))]; %Test for differences between segments
            %statsDataGroups = [statsDataGroups, 1:1:size(inputData(:,x),1) )]; %Again, only valid for double arrays (Although not hard to build extra case)
                %Test for differences between flies?
        end
        [P,ANOVATAB,STATS]=anova1([statsData],[statsDataGroups], 'off');
        statCompare = multcompare(STATS, 'CType', 'bonferroni', 'display', 'off');
        %Plotting
        %statBaseHeight = nanmax(get(gca,'YLim'))*1.1; %Default altitude to put stat indication at
        statBaseHeight = nanmax( nanmean(inputData,1) )*1.1; %Default altitude to put stat indication at
        statInterval = 0.04*statBaseHeight; %How much space to leave between each group
        %statOccupation = nan(size(overFlyPTTs,2)*4,size(overFlyPTTs,2)); %WIll indicate what airspace is already occupied by a stat indicator (A convoluted system to cut down on having to make a very high series of indicators needlessly)
        %%statOccupation = nan(size(inputData,2)*size(inputData,2),size(inputData,2)); %Note: Will be ginormous with large number of groups
        statAltitude = statBaseHeight;
        statsDisplayed = 0;
        for i = 1:size(statCompare,1)
            if statCompare(i,6) < alphaValue
                %Check to see if airspace unoccupied
                %{
                %statAltitude = 1;
                statAltitude = statBaseHeight;
                while nansum( isnan(statOccupation(statAltitude,statCompare(i,1):statCompare(i,2))) ) ~= statCompare(i,2) - statCompare(i,1) + 1 %Will probs crash if exceeds number of targets
                    %statAltitude = statAltitude + 1;
                    statAltitude = statAltitude + 0.1*statBaseHeight;
                end
                %}
                %line([statCompare(i,1)+0.05,statCompare(i,2)-0.05],[statBaseHeight+statAltitude*statInterval,statBaseHeight+statAltitude*statInterval],'Color', [0.60,0.60,0.60], 'LineWidth', 1.5)
                line([statCompare(i,1)+0.05,statCompare(i,2)-0.05],[statAltitude,statAltitude],'Color', [0.60,0.60,0.60], 'LineWidth', 1.5)
                statAltitude = statAltitude + 0.05*statBaseHeight; %No checks for occupation
                %statOccupation(statAltitude,statCompare(i,1):statCompare(i,2)) = 1;
                statsDisplayed = statsDisplayed + 1;
            end
        end
        %ylim('auto') %Overrides fixed Y limits
        %Identify outliers
        %{
        for x = 1:size(overFlyPTTs,2)
            outlierStatus = isoutlier(overFlyPTTs{x}); %"More like...outFlier"
            if nansum(outlierStatus) > 0 %Outliers detected
                disp(['## Warning: Fly number/s ',num2str(find(outlierStatus == 1)'),' for Group ', num2str(targsOfInterest(x)) ,' detected to be outliers for PTT plot ##'])
            end
        end
        %}
        %Check if any sigs were plotted above visible space
        if statAltitude > nanmax(get(gca,'YLim')) && statsDisplayed > 0
            disp(['-# Caution: One or more significances plotted above figure Y limits #-'])
        end
        %Append stats info to title
        temp = get(gca,'title');
        %title( [temp.String,char(10),'(p<',num2str(alphaValue),'; One-way ANOVA w/ Bonff)'] );
        try
            title( [temp.String,char(10),'(p<',num2str(alphaValue),'; One-way ANOVA w/ Bonff)',char(10),'ANOVA p = ',num2str(P)] );
        catch
            temp.String{3} = ['(p<',num2str(alphaValue),'; One-way ANOVA w/ Bonff)',char(10),'ANOVA p = ',num2str(P)]; %For cases where title already has multiple rows
            title( temp.String );
        end
        inputData = []; %This is just in case of manual running
        %####
    else
        disp(['-# Cannot barStats with only one individual and/or group #-'])
        P = NaN; ANOVATAB = []; STATS = [];
    end
end
%}

%---------------------------------------------------------------------------------------------



%sleepFriend = [];
%wakeFriend = [];
allFriend = [];
allTimeSets = char;

for IIDN = 1:size(overVar,2)
    sleepFriend = [];
    wakeFriend = [];
    safeRailTimes = overVar(IIDN).railStruct.sleepRail(:,2);
    safeRailTimes( isnan(safeRailTimes) == 1) = safeRailTimes( find( isnan( safeRailTimes ) ~= 1, 1, 'last' ) ); %CRITICAL ASSUMPTION NO NANS ANYWHERE EXCEPT END
    
    sleepBool = [];
    sleepBool = bwlabel( overVar(IIDN).railStruct.sleepRail(:,1) );
    sleepSets = [];
    if sleepBool(1) ~= 0
        sleepSets(1,1) = [0];
    end
    temp = [find(diff(sleepBool)>0)];
    sleepSets(size(sleepSets,1)+1:size(sleepSets,1)+size(temp,1),1) = temp;
    temp = [find(diff(sleepBool)<0)];
    sleepSets(1:size(temp,1) , 2 ) = temp;
    
    sleepSets( sleepSets(:,1) == 0,1 ) = 1;
    sleepSets( sleepSets(:,2) == 0,2 ) = length(sleepBool);
    
    for i = 1:size(sleepSets,1)
        sleepFriend( size(sleepFriend,1)+1 , 1 ) = IIDN;
        sleepFriend( size(sleepFriend,1) , 2 ) = 1;
        sleepFriend( size(sleepFriend,1) , 3:4 ) = sleepSets(i,:);
        sleepFriend( size(sleepFriend,1) , 5:6 ) = safeRailTimes(sleepSets(i,:))';
    end
    
    wakeBool = [];
    wakeBool = bwlabel( ~overVar(IIDN).railStruct.sleepRail(:,1) );
    wakeSets = [];
    if wakeBool(1) ~= 0
        wakeSets(1,1) = [0];
    end
    temp = [find(diff(wakeBool)>0)];
    wakeSets(size(wakeSets,1)+1:size(wakeSets,1)+size(temp,1),1) = temp;
    temp = [find(diff(wakeBool)<0)];
    wakeSets(1:size(temp,1) , 2 ) = temp;
    
    wakeSets( wakeSets(:,1) == 0,1 ) = 1;
    wakeSets( wakeSets(:,2) == 0,2 ) = length(sleepBool);
    
    for i = 1:size(wakeSets,1)
        wakeFriend( size(wakeFriend,1)+1 , 1 ) = IIDN;
        wakeFriend( size(wakeFriend,1) , 2 ) = 0;
        wakeFriend( size(wakeFriend,1) , 3:4 ) = wakeSets(i,:);
        wakeFriend( size(wakeFriend,1) , 5:6 ) = safeRailTimes(wakeSets(i,:))';
    end
    

    allFriend = [allFriend;sleepFriend;wakeFriend];
    
    %{
    figure
    plot(overVar(IIDN).railStruct.sleepRail(:,1),'k')
    hold on
    plot(sleepBool*0.9,'b')
    plot(wakeBool*0.8,'r')
    %temp = [];
    %temp = sleepFriend(isnan(sleepFriend) ~= 1);
    for col = 1:size(sleepFriend,2)
        coords = sleepFriend(:,col);
        coords( isnan(coords) == 1) = [];
        scatter(coords,sleepBool(coords))
        %scatter(sleepFriend(:,2),sleepBool(sleepFriend(:,2)),'c')
    end
    %}
    
end

superFriend = num2str( allFriend(:,1) );
superFriend = [superFriend, repmat(',',size(superFriend,1),1) ];
superFriend = [superFriend, num2str(allFriend(:,2)) ];
superFriend = [superFriend, repmat(',',size(superFriend,1),1) ];
%superFriend = [superFriend, allTimeSets ];
temp = datestr(datetime(allFriend(:,5), 'ConvertFrom', 'posixtime'));
temp = temp(:,end-7:end);
superFriend = [superFriend, temp ];
superFriend = [superFriend, repmat(',',size(superFriend,1),1) ];
temp = datestr(datetime(allFriend(:,6), 'ConvertFrom', 'posixtime'));
temp = temp(:,end-7:end);
superFriend = [superFriend, temp ];

%Final cleaning of IIDNs
for i = 1:size(superFriend,1)
    superFriend(i,:) = replace(superFriend(i,:),' ','0');
end


%}