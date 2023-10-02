%Swarmsight Output File Analysis Script (SOFAS)
%      "Still sofa-surfing in 2023"
%Portions of this script heavily plagiarised from CL_Data_Analyser

%This script is designed to preprocess behavioural data and prepare it for analysis with SASIFRAS

%Mk 1 - Core functionality
%Mk 2 - Moved dors/mov matching to overGlob portion with contiguous data
%Mk 3 - Additional data usage (deltaProp/etc)
%Mk 4 - Asynchrony fixing, Video integration
%    .75 - Fixed ref cell nesting (27/2/19)
%Mk 5 - Incorporated left antenna data (1/3/19)
%    .25 - Improved synchronisation and memory usage of video writing scripts
%    .75 - Segmented video output for very large holes (11/3/19)
%Mk 6 - Return to functional writeVids = 0
%Mk 7 - Complete overhaul of writeVids frame assignment/reading code (25/3/19)
%    .5 - Added SwarmSight Terminal File Copy bug detection/mitigation, PSD processing/plotting
%    .75 - Added ability to incorporate proboscis data
%Mk 8 - Incorporation of DeepLabCut data (20/6/19)
%Mk 9 - Automation, auto prob/etc detection (24/6/19)
%Mk 10 - DLC geometry calculations
%Mk 11 - Truly dynamic data importation, Altered naming convention to make original files "BASE" rather than "DORS"
%Mk 12 - Vector input to posix time operations (28/5/20)
%     .25 - Generalisation to handle Rhiannon data
%     .5 - try/catch instead of hard fail on data importation error when running automated
%     .65 - BigBird adjustments
%     .85 - Data detection folder architecture adjustments 
%Mk 13 - Option for using DLC data to do activity/inactivity separation (17/3/22)
%     .25 - Support for annotating vids (Non-collab mode) with online movement/sleep metrics
%     .5 - Miscellaneous improvements, Significant changes to ac/inac detection (04/07/22)
%     .75 - Other misc. improvements
%     .85 - Slight changes to flyName derivation, Added specialParam for saving/figs
%Mk 14 - ZOH for DLC data (6/3/23)


%   To do: Make mov ref assembly implicit when BASE and MOV are same

%
%       ToDo: self-adjusting match window size to A) avoid false minima and B) save time,
%            time-inferencing code for movData when dors data is truncated/NaNed
%
%       Known bugs: Asynchrony between tracker/dors/mov data is not corrected and will lead to misalignment on the scale of the asynchrony
%                   (Deprecated bug?)
%
%       Potential SwarmSight bugs: Seems like SwarmSight in Batch mode may copy second-to-last analysis as last analysis
%           (Current workaround is to ditch the last file when this happens)
%
%       System is currently incapable of not having both a BASE and MOV dataset; If your data is only possessing one, just point both BASE and MOV at the same data

close all
clear
%opengl hardware

['--- Initialising Swarmsight Output File Analysis Script ---']

progIdent = 14;

%-----------------------------------------------
%Data specifiers
%{
mode = 0 % 0 - Normal operation
if mode == 0
    exp = 'Dorsal' %What data to analyse
end
%}
%{
%Legacy
dataList = [{'BASE'}, {'DORS'}, {'MOV'}, {'PROB'}, {'DLC_ANT'}, {'DLC_PROB'}] %This is used to make data finding/importation dynamic
           %SwarmSight base, Original Sri-code CSV, Movement processed CSV, Proboscis processed CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*_Tracker'}, {'*Dorsal*_.csv'}, {'*_mov.csv'}, {'*_prob.csv'}, {'*DeepCut*.csv'}, {'*DeepCut*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
%}
%{
%Matt current-generation data (2020)
    %Note: Use of 'DORS' is deprecated and may result in data being doubly saved to structures (Or worse)
dataList = [{'BASE'}, {'DORS'}, {'MOV'}, {'PROB'}, {'DLC_ANT'}, {'DLC_PROB'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Swarmsight dors processed CSV, Lat. cam movement processed CSV, Proboscis processed lat. cam CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*Dorsal*_.csv'}, {'*_Tracker'}, {'*_mov.csv'}, {'*_prob.csv'}, {'*DeepCut*.csv'}, {'*DeepCut*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\'}, {'\'}, {'\'}, {'\'}, {'\DLC_ANT\'}, {'\DLC_PROB\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0, 0, 0, 1, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'NULL'}, {'DORS'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
%}
%{
%Rhiannon current-generation data (2020)
dataList = [{'BASE'}, {'MOV'}, {'DLC_PROB'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Lat. cam movement processed CSV, DLC proboscis data
uniqueList = [{'*_mov.csv'}, {'*_mov.csv'},  {'*DeepCut*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
    %Secondar note: This arrangement for Rhiannon data uses the mov data as both BASE and MOV; Unexpected results may occur
uniqueSubFolderList = [{'\movement\'}, {'\movement\'}, {'\proboscis\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
%}
%{
%Matt cutdown
dataList = [{'BASE'}, {'DORS'}, {'MOV'}, {'PROB'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Swarmsight dors processed CSV, Lat. cam movement processed CSV, Proboscis processed lat. cam CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*Dorsal*_.csv'}, {'*_Tracker'}, {'*_mov.csv'}, {'*_prob.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\'}, {'\'}, {'\'}, {'\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0, 0, 0]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'NULL'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
%}    
%{
%Matt slightly less cutdown
dataList = [{'BASE'}, {'DORS'}, {'MOV'}, {'PROB'}, {'DLC_PROB'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Swarmsight dors processed CSV, Lat. cam movement processed CSV, Proboscis processed lat. cam CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*Dorsal*_.csv'}, {'*_Tracker'}, {'*_mov.csv'}, {'*_prob.csv'}, {'*DeepCut*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\'}, {'\'}, {'\'}, {'\'}, {'\DLC_PROB\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0, 0, 0, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'NULL'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
%}
%{
%Matt very cutdown, for LFP data that lacks any dorsal element
dataList = [{'BASE'},{'MOV'}] %This is used to make data finding/importation dynamic (Note: Presence of at least BASE and MOV is critical)
           %Original mov frame base
uniqueList = [{'*Overnight*_mov.csv'},{'*Overnight*_mov.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\'},{'\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0,0]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'},{'NULL'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
%}
%{
%Matt LFP data for 12.85XM
    %Did you remember to switch partList as well?
dataList = [{'BASE'}, {'MOV'}, {'PROB'}, {'DLC_SIDE'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Swarmsight dors processed CSV, Lat. cam movement processed CSV, Proboscis processed lat. cam CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*Lateral*_mov.csv'}, {'*Lateral*_mov.csv'}, {'*Lateral*_prob.csv'}, {'*SkewerPrep*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\Videos\'}, {'\Videos\'}, {'\Videos\'}, {'\DLC\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0,  0, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
%}
%Matt March 2022 with ball
%{
dataList = [{'BASE'}, {'MOV'}, {'PROB'}, {'BALL'}, {'DLC_SIDE'}] %This is used to make data finding/importation dynamic
uniqueList = [{'*Overnight*_mov.csv'}, {'*Overnight*_mov.csv'}, {'*Overnight*_prob.csv'}, {'*Overnight*_ball.csv'}, {'*SkewerPrep*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\Videos\'}, {'\Videos\'}, {'\Videos\'}, {'\Videos\'}, {'\DLC\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0,  0, 0, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'MOV'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference    
        %Note: Ancillary data (e.g. BALL) needs to be tethered to be imported properly
        %(Because it does not have explicit cases like base, mov or prob)
%}
%Matt 2023 resofasing of 2019 historical savOuts
%{
dataList = [{'BASE'}, {'MOV'}, {'PROB'}, {'DLC_ANT'}, {'DLC_PROB'}] %This is used to make data finding/importation dynamic
uniqueList = [{'*Dorsal*_.csv'}, {'*Lateral*_mov.csv'}, {'*Lateral*_prob.csv'}, {'*.csv'}, {'*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\'}, {'\'}, {'\'}, {'\DLC_ANT\'}, {'\DLC_PROB\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0,  0, 1, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'BASE'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference    
        %Note: Ancillary data (e.g. BALL) needs to be tethered to be imported properly
        %(Because it does not have explicit cases like base, mov or prob)
    %Note: This data uses dlcActivitySeparation = 0, because this era does not have leg tracking
        %Also overFolder is different, as are the DLC bodyparts
specialParam = '_NewDLC_'
dlcActivitySeparation = 0;
        %}
%Matt LFP data for 12.85XM (and also Jelena?)
    %"Now with partList!"
%{    
dataList = [{'BASE'}, {'MOV'}, {'PROB'}, {'DLC_SIDE'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Swarmsight dors processed CSV, Lat. cam movement processed CSV, Proboscis processed lat. cam CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*_f_*_mov.csv'}, {'*_f_*_mov.csv'}, {'*_f_*_prob.csv'}, {'*SkewerPrep*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\Videos\'}, {'\Videos\'}, {'\Videos\'}, {'\DLC\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0,  0, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'}, {'NULL'}, {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
specialParam = '_DLCAcInacTesting_' 
partList = [{'proboscis'},{'abdomen'},{'lelbow'}];
%}
%Matt redOvernight LFP data (No motion detection prob)
    %"Now with partList!"
dataList = [{'BASE'}, {'MOV'}, {'DLC_SIDE'}] %This is used to make data finding/importation dynamic
           %Original dors frame base, Swarmsight dors processed CSV, Lat. cam movement processed CSV, Proboscis processed lat. cam CSV, DLC antennal data, DLC proboscis data
uniqueList = [{'*RedOvernight*_mov.csv'}, {'*RedOvernight*_mov.csv'}, {'*SkewerPrep*.csv'}] %This specifies unique elements to capture each data type individually
%uniqueList = [{'*RedControl*_mov.csv'}, {'*RedControl*_mov.csv'}, {'*SkewerPrep*.csv'}] %This specifies unique elements to capture each data type individually
    %Note: Careful assembly of these identifiers to ensure no overlap or underlap is critical
uniqueSubFolderList = [{'\Vids\'}, {'\Vids\'}, {'\DLC\'}] %Stores whether data is contained in subfolders or not
headerIgnoreList = [0, 0, 1]; %How many rows of the header data to ignore when importing files (Only really necessary currently for DLC data, which has odd headers)
tetherList = [{'NULL'}, {'NULL'},  {'MOV'}]; %Tracks what data types the ancillary data types should be tethered to for sync purposes
    %E.g. DLC_ANT data comes from dorsal recordings, so it is tethered to the DORS frame reference
specialParam = ''
dlcActivitySeparation = 0;
partList = [{'proboscis'},{'abdomen'},{'lelbow'}];
%}

%QA
if size(dataList,2) ~= size(uniqueList,2) || size(dataList,2) ~= size(uniqueSubFolderList,2) || size(dataList,2) ~= size(headerIgnoreList,2)
    ['### WARNING: MISMATCH BETWEEN LISTS ###']
    error = yes
end
%-----------------------------------------------
%Switches
eStabGlob = 1 %Whether to eStablish a Global synchronised reference frame between dorsal and lateral vids
fixDorsAs = 0 %Whether to use NaNs to pad out aberrantly truncated Dors files
%%dispVids = 1 %Whether to attempt to display appropriate recordings (Warning: Memory intensive)
%{
if dispVids == 1
    writeVids = 1 %Whether to iterate through and write the collab vids to file (Runs in counter with the display of vids)
    skipExistingVids = 1 %Check for video file already existing (Note: Need to add in file check so corrupt files not skipped)
end
%}
noDispVidsOverride = 1 %Forces vids not to be assembled, even if detected
if noDispVidsOverride == 1
    dispVids = 0;
else
    dispVids = 1;
end

if dispVids == 1
    vidMode = 2; %1 - Collab mode (Hole-based), 2 - Annotation mode (Non-collab, uses source vids)
    if vidMode == 2
        actuallyDrawVid = 0; %Whether to actually display the vid onscreen as it is annotated
    end
    runtimeWrite = 1; %Whether to write vids on every frame to save memory
        %Note: Runtime writing is about 2x faster than the alternative, which is also prone to slowing down over time
        %To add: Assembly of vids locally and then shift to network?
end

doGeometry = 1; %Whether to calculate (and save) tedious geometry rather than making a later script do it
    %Note: This will significantly increase processing time but is a good forward planning thing
if doGeometry == 1
    safeHeight = 480; %Hardcoded video height for centreline extrapolation purposes
    dlcSmoothSize = 30; %How many timepoints to rolling smooth for DLC data display purposes
    doMedianGeometry = 1; %Whether to calculate angles relative to a fixed median intercept point
    if doMedianGeometry == 1
        doIndividualIcptCalcs = 0; %Enable this to calculate the intercept per every frame and calculate the median intercept from that (Note: Extremely slow)
            %When 0, the script instead calculates the median antennal positions and derives one intercept from that
    end
    geometryOnVids = 1; %Whether to draw geometry on output videos
end

rectifyFindDiscontinuities = 1; %Whether to attempt to correct over/underfinds, if occurring

%dlcActivitySeparation = 1; %Whether to use pixel subtraction (0) or DLC data (1) to do activity/inactivity separation
dlcActivitySeparation = dlcActivitySeparation; %Moved above
if dlcActivitySeparation == 1
    dlcHyp = 1; %Whether to calculate a hypotenuse of limb movement
    dlcAcLimb = 'lelbow'; %What DLC data to use
        %Note: If using a hypotenuse then this should refer just to the limb (e.g. "lelbow")
        %If not using hypotenuse then it should point towards the limb and coordinate (e.g. "lelbow_x")
    %dlcAcSDCount = 2; %How many SD above baseline the difference needs to be
    acSDCount = 2; %How many SD above baseline the difference needs to be
    %Note: Single-frame large jitters in detected position will cause false positive movement detection
        %Could be fixed with minimum duration criterion?
    dlcMaxSingleFrameDiff = 50; %Maximum allowable single-frame change in DLC-detected limb position
        %Note that aggressive values here will cause the blanking out of perhaps true rapid motion
else
    acSDCount = 2; %Value for use in contour activity/inactivity separation
end
%minAcTime = 0.1; %For activity to break up an inactivity bout it has to last for longer than half of this
minAcTime = 30; %For activity to break up an inactivity bout it has to be separated from other activity by more than this (Note: This is a departure in 13.5 from previous implementation)

doDLCZOH = 1; %Whether to do a Zero Order Hold (ZOH) on DLC data where the likelihood is lower than a threshold
    %Note: Will add potentially significant time to processing
if doDLCZOH == 1
    likelinessThresh = 0.6; %Arbitrarily based on value that DLC devs use for point display when annotating vids
end

%-----------------------------------------------
%Parameters for DLC (called into being even if their respective switches are not active)
numHeaderRows = 3; %Self-descriptive
%Matt
%partList = [{'LeftAntennaTip'},{'LeftAntennaBase'},{'RightAntennaTip'},{'RightAntennaBase'},{'proboscis'},{'abdomen'}]; %What body parts from the DLC data to incorporate
%Rhiannon
%partList = [{'proboscis'},{'abdomen'}]; %What body parts from the DLC data to incorporate
%Matt new
%partList = [{'proboscis'},{'abdomen'},{'lelbow'}];
%Matt behav data new DLC-ing
%partList = [{'LeftAntennaTip'},{'LeftAntennaBase'},{'RightAntennaTip'},{'RightAntennaBase'},{'proboscis'}];

partList = partList; %Moved above

valList = [{'x'},{'y'},{'likelihood'}]; %What values were calculated for said body parts
writeVids = 0;
skipExistingVids = 1;
useDLCVids = 0;

%-----------------------------------------------
%More switches
saveOutput = 1 %Whether to save workspace for later use
saveFigs = 1 %Whether to save the post-processing figures
skipExisting = 0 %Whether to skip processing for files already detected to have a saved output
overwriteOldOutput = 1 %Overwrite save files that don't match
forceOverwrite = 1 %Blanket force overwrite of save files (You Can Afford The Time)
    %Note: skipExisting takes precedence over overwriteOldOutput and forceOVerwrite, by nature of being much much earlier
        %If skipExisting == 0 and overwriteOldOutput == 0, the program will do all the processing and not save if there is a mismatch
clearRawData = 1; %Whether to clear various raw data structures to save space
    %Note: If this is enabled and estabGlob is false it is questionable anything will be saved

doPSD = 0 %Whether to do the PSD/etc at the end

automation = 0 %Whether to use automation to iterate across every findable folder

networkAnalysis = 1 %Whether to attempt to pull data from the network rather than a locally stored copy

ignoreCalib = 1 %Whether to ignore calibration files by name

%-----------------------------------------------
%More parameters
inactDur = 9000; %Duration in frames (approximately) for a gap in activity to be deemed interesting (1s ~= 30 frames)
    %Too low values here will result in a high false positive rate
    %Too high values will restrict analysis to only very large inactivity blocks
limitBreak = 30000; %Size value at which a video will have to be segmented if it is to be saved to disk
    %(On the current PC, this value equates to a collab that uses ~62GB of RAM)
    %Note: This could potentially be mitigated by saving vids not as collabs, but what would be the point?
    %Secondary note: More memory efficient ways of storing frames may exist
diverWindow = 900; %Size of rolling window used for averaging in divergence calculations (divide by 30 for time width)

originalAxes = 1; %Whether to use the original axes for certain plots (Whole activity trace, etc) rather than post-calculated time
%-----------------------------------------------

%%dataPath = 'C:\Users\labpc\Desktop\Matt\Flytography\data\30 01 19'
%{
%Rhiannon
figPath = 'C:\Users\labpc\Desktop\Matt\Flytography\Rhiannon\FigOut';
savePath = 'C:\Users\labpc\Desktop\Matt\Flytography\Rhiannon\SavOut';
vidPath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\Rhiannon\VidOut';
%}
%{
%Matt local PC
figPath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\FigOut';
savePath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\SavOut\NewData2020';
vidPath = 'C:\Users\labpc\Desktop\Matt\Flytography\MATLAB\VidOut';
%%dlcPath = 'C:\Users\labpc\Desktop\Matt\Flytography\DeepLabCut\Fully analysed\30 01 19'
%}
%Matt BigBird

figPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\FigOut';
savePath = 'D:\group_swinderen\Matthew\TDTs\SleepData\SavOut';
vidPath = 'D:\group_swinderen\Matthew\TDTs\SleepData\VidOut';
toolPath = 'D:\group_swinderen\Matthew\Scripts\toolboxes';
%}
%Jelena BigBird
%{
figPath = 'D:\group_swinderen\Jelena\OUT\FigOut';
savePath = 'D:\group_swinderen\Jelena\OUT\SavOut';
vidPath = 'D:\group_swinderen\Jelena\OUT\VidOut';
toolPath = 'D:\group_swinderen\Matthew\Scripts\toolboxes';
%}
%FLY = 'fly'; %Unless you intend to analyse a different animal model this shouldn't need to change often

addpath(genpath([toolPath filesep 'altmany-export_fig-9676767'])); %export_fig
addpath(genpath([toolPath filesep 'scrollsubplot'])); %export_fig

if networkAnalysis == 0
    overFolder = 'D:\group_swinderen\Matthew\Sleep\data' %Where the data is stored(?)
else
    overFolder = 'I:\PHDMVDP002-Q1471\LFP\COLLATED' %Where the data is stored
    %%overFolder = 'I:\PHDMVDP001-Q1470\Yellena' %Where the data is stored
    %%overFolder = 'I:\PHDMVDP001-Q1470\Flytography\data' %Where the data is stored
    %%overFolder = 'I:\PHDMVDP001-Q1470\Yellena'
end

%Check if output folders exist and make if they don't
if saveOutput == 1 || saveFigs == 1
    %%%%
    if saveFigs == 1
        %Check if figure folder exists and if not, make one
        ping = dir([figPath]);
        if isempty(ping) == 1
            ['-- Figure folder does not exist; Creating manually --']
            mkdir(figPath);
        end
    end
    %%%%

    %%%%
    if saveOutput == 1
        %Check if figure folder exists and if not, make one
        ping = dir([savePath]);
        if isempty(ping) == 1
            ['-- Save folder does not exist; Creating manually --']
            mkdir(savePath);
        end
    end
    %%%%    
end
%Here for files
%Iterate across folders under overFolder and look for presence of data
currentIsErrorDataset = 0; %Whether the current file is an error file (used for breaking later loops)
numOfErrorFiles = 0;
listOfErrorFiles = struct; %In case of errors
if automation == 1
    preFolderList = dir([overFolder]); %Unprocessed  list of all files/folders in overFolder
else
    preFolderList = struct; %Manual specification of folders to process

    %Control (Not Done Yet)
    %{
    preFolderList(1,1).name = '300323'
    preFolderList(1,1).isdir = 1;
    preFolderList(size(preFolderList,1)+1,1).name = '260423'
    preFolderList(size(preFolderList,1),1).isdir = 1;
    preFolderList(size(preFolderList,1)+1,1).name = '270423'
    preFolderList(size(preFolderList,1),1).isdir = 1;
    %}
    
    %RedOvernight

    preFolderList(1,1).name = '210323'
    preFolderList(1,1).isdir = 1;
    preFolderList(size(preFolderList,1),1).isdir = 1;
    preFolderList(size(preFolderList,1)+1,1).name = '190423'
    preFolderList(size(preFolderList,1),1).isdir = 1;
    %}
    %preFolderList(size(preFolderList,1)+1,1).name = '21 12 18'
    %preFolderList(size(preFolderList,1),1).isdir = 1;
    %}

    %{
    preFolderList(1,1).name = '301122'
    preFolderList(1,1).isdir = 1;
    preFolderList(2,1).name = '011222'
    preFolderList(2,1).isdir = 1;
    preFolderList(3,1).name = '041222'
    preFolderList(3,1).isdir = 1;
    preFolderList(4,1).name = '051222'
    preFolderList(4,1).isdir = 1;
    preFolderList(5,1).name = '061222'
    preFolderList(5,1).isdir = 1;
    preFolderList(6,1).name = '071222'
    preFolderList(6,1).isdir = 1;
    preFolderList(7,1).name = '081222'
    preFolderList(7,1).isdir = 1;
    %}
    %preFolderList(1,1).name = '07 02 19'
    %preFolderList(1,1).isdir = 1;
    
    disp(['-- Manual mode specified; Searching for: ',preFolderList.name, ' --'])
end

%QA
for i = 1:size(preFolderList,1)
    if isempty( preFolderList(i).name ) == 1
        ['## Alert: preFolderList error ##']
        crash = yes
    end
end

dataFolderList = []; %Compiled list of folders containing (supposedly) valid data
numDataFolders = 0; %Self-descriptive
for fol = 1:size(preFolderList,1)
    if preFolderList(fol).isdir == 1 && isempty(findstr(preFolderList(fol).name,'.')) == 1 && isempty(findstr(preFolderList(fol).name,'..')) == 1
    %This if statement ensures that we are scoping a folder, not a file (and a non escape-folder to boot)
        %dataPresence = dir([overFolder,'\', preFolderList(fol).name,'\*',FLY,'*.csv']);
        dataPresence = dir([overFolder,'\', preFolderList(fol).name, uniqueSubFolderList{1}, uniqueList{1}, '*']);
            %Check for presence of exemplar data type in main folder (or subfolders if situation merits)
        if length(dataPresence) ~= 0
            dataFolderList = [dataFolderList; {preFolderList(fol).name}];
            numDataFolders = numDataFolders + 1;
        end
    end
end

%Post-analysis report values
totalDatasets = 0; %How many datasets processed succesfully in total
probDatasets = 0; %How many datasets included prob data
dlcDatasets = 0; %How many datasets included DLC data
skippedDatasets = 0; %How many datasets had to be skipped entirely
successFile = 0;

e = 1; %Iterator for error files

['--- ',num2str(numDataFolders),' data folders found ---']
if numDataFolders == 0 && automation == 0
    disp(['Are you sure that data with name "',uniqueList{1}, '" exists in folder "',overFolder,'"?'])
end
disp([dataFolderList])
varSaveList = who;
varSaveList = [varSaveList; {'varSaveList'}]; %A bit silly, but this is needed to prevent the list itself from being wiped
varSaveList = [varSaveList; {'fol'}]; %This is to prevent the iterator from being wiped

%==================================================================================================================================

%Begin folder-wise (immense) loop
for fol = 1:size(dataFolderList,1)
    if exist('fol') ~= 1
        close all %Only clear on program initialisation
    end
    clearvars('-except',varSaveList{:}) %Clear everything except initialisation variables
    disp([char(10),'-----------------------------------------------------------------------------'])
    disp(['-- Commencing analysis of dataset ',num2str(fol), ' of ', num2str(numDataFolders),' --'])
    disp(['Dataset: ',dataFolderList{fol}])

    dataPath = [overFolder,'\', dataFolderList{fol}]; %Now dynamic
    dlcPath = [overFolder,'\', dataFolderList{fol}, '\DLC']; %This folder may or may not exist
    
    %if automation == 1 %Disabled boolean because manual mode sometimes has more than one file
    currentIsErrorDataset = 0;
    %end
    
    %Clear/initialise some flags
    incDorsData = 0;
    incProbData = 0;
    incDLC = 0;
    incAntDLC = 0;
    incProbDLC = 0; 
    %skipThisDataset = 0;
    
    hasDataList = []; %Will mirror dataList, except that it will contain boolean for data existence
    
    %%try
    
        %%%%
        %Find data
        ['-- Attempting to find data --']

        importStruct = struct; %Will hold details of the data found and data imported
        for dataSide = 1:size(dataList,2) %Iterates along the types of data to be captured
            importStruct.(strcat('FILES_',dataList{dataSide})) = [];

            FOUND = dir([dataPath, uniqueSubFolderList{dataSide}, uniqueList{dataSide}, '*']); %Find all matching data
            %FOUND = dir([dataPath, '\*', FLY, '*', uniqueList{dataSide}, '*']); %Find all matching data
                %Note: trailing * is only necessary due to complicated specification for base data (i.e. wildcards cannot be present in its specificier); Deprecated
                    %It should not cause an issue however, as most other specifiers explicitly state their .csv status
                    
            if ignoreCalib == 1
                igCalibCount = 0;
                for rem = size(FOUND,1):-1:1
                    if isempty(strfind( FOUND(rem).name , 'Calib' )) ~= 1
                        FOUND(rem) = [];
                        igCalibCount = igCalibCount + 1;
                    end
                end
                if igCalibCount > 0
                    disp(['-# ',num2str(igCalibCount),' detected calib files ignored #-'])
                end
            end

            if isempty(FOUND) ~= 1
                disp(['--- ', dataList{dataSide}, ' data detected to exist ---'])
                hasDataList.(dataList{dataSide}) = 1;
                %Flag operations (soon to be deprecated (probably))
                if isempty(strfind(dataList{dataSide}, 'DORS')) ~= 1 && ...
                        size(dataList{dataSide},2) == size('DORS',2) %Note: Capitalisation important
                    incDorsData = 1; %Data found, set dors data inclusion to yes
                end
                if isempty(strfind(dataList{dataSide}, 'PROB')) ~= 1 && ...
                        size(dataList{dataSide},2) == size('PROB',2)  %Note: Capitalisation important
                    incProbData = 1; %Data found, set prob data inclusion to yes
                end
                if isempty(strfind(dataList{dataSide}, 'DLC')) ~= 1
                    incDLC = 1; %Data found, set DLC data inclusion to yes
                    if isempty(strfind(dataList{dataSide}, 'ANT')) ~= 1
                        incAntDLC = 1; %DLC data of type ANTENNA found, set inclusion to yes
                    end
                    if isempty(strfind(dataList{dataSide}, 'SIDE')) ~= 1 || isempty(strfind(dataList{dataSide}, 'PROB')) ~= 1
                        incProbDLC = 1; %DLC data of type PROBOSCIS found, set inclusion to yes
                    end
                end
            else
                disp(['## No ', dataList{dataSide}, ' data detected ##'])
                hasDataList.(dataList{dataSide}) = 0;
                %crash = yes
                currentIsErrorDataset = 1;
                break
            end

            importStruct.(strcat('FILES_',dataList{dataSide})) = [importStruct.(strcat('FILES_',dataList{dataSide})); FOUND];
                %Arguably accomplishable without earlier blanking but eh

            eval(['FILES_',dataList{dataSide}, ' = importStruct.',(strcat('FILES_',dataList{dataSide})),';']); %Bad coding habits pt. 8
                %This just takes the importStruct field and turns it back into a variable

            %QA
            if isempty(strfind(dataList{dataSide}, 'BASE')) == 1 && size(importStruct.(strcat('FILES_',dataList{dataSide})),1) > size(importStruct.FILES_BASE,1)
                ['## ALERT: CRITICAL DATA OVER(OR UNDER)FIND FOR ', dataList{dataSide}, ' ##']
                %error = yes %Can probably be ignored, given QA down lower to ensure correct name identification
                if rectifyFindDiscontinuities == 1
                    typeSpec = strcat('FILES_',dataList{dataSide}); %Simplifies referencing
                    %Identify unique identifiers
                    nameTemp = [];
                    for i = 1:size(importStruct.(typeSpec),1)
                        nameTemp(i,:) = (importStruct.(typeSpec)(i).name  ~= importStruct.(typeSpec)(1).name); %Calculates difference of all names relative to first detected data file
                    end
                    sumNameTemp = nansum(nameTemp,1); %Sums to find places of discontinuity
                    identPos = find(sumNameTemp ~= 0,1); %Assumes that first location of discontinuity is unique identifier


                    %Iterate through data and find datasets that do not match base
                    notFoundIdx = []; %List of datasets that do *not* have a match in the BASE
                    for i = 1:size(importStruct.(typeSpec),1)
                        foundNum = 0;
                        for x = 1:size(importStruct.FILES_BASE,1)
                            safeName = strrep(uniqueList{1}, '*', ''); %Hardcoded assumption of base location in uniqueList
                            safeName = strrep(safeName, '.csv', '');
                            preInd = strfind(FILES_BASE(x).name, safeName);
                            truncName = FILES_BASE(x).name(preInd+16:preInd+17);
                            if isempty(strfind(importStruct.(typeSpec)(i).name(identPos:identPos+1), truncName)) ~= 1
                                foundNum = foundNum + 1;
                            end
                        end
                        %Check if no hits
                        if foundNum == 0
                            notFoundIdx = [notFoundIdx, i];
                        end
                    end
                    if isempty(notFoundIdx) ~= 1
                        disp(['## One or more non-matching files found; Discarding ##'])
                        importStruct.(typeSpec)(notFoundIdx) = [];
                    else
                        ['## COULD NOT RESOLVE OVER/UNDERFIND ##']
                        error = yes
                    end
                    
                else
                    ['(Not attempting to correct)']
                    currentIsErrorDataset = 1;
                    break
                %rectifyDiscontinuities end    
                end
            %isempty end
            end
        %dataSide end
        end
        
        if currentIsErrorDataset == 1
            ['## Skipping this dataset on account of early error ##']
            continue
        end

        %%%%

        %%%%
        %Prepare
        %numFiles = length(FILES)
        numFiles = length(FILES_BASE)
        if numFiles == 0
            '## WARNING: NO DATA DETECTED ##'
            return
        else
            %Old
            %{
            %%namiWaEnd = min(strfind(FILES(1).name, '19')); %Correct as long as date precedes file index (...and working with 2019 data)
            %namiWaEnd = min(strfind(FILES_BASE(1).name, dataPath(end-1:end))); %More generalised process but requires consistent folder formatting
                %Note: This uses the last two digits of the folder as the assumed year, but is susceptible to recordings made on the same date value
            temp = strfind(FILES_BASE(1).name, dataPath(end-1:end));
            if size(temp,2) > 2
                ['-# Caution: Multiple instances of year digits ("',num2str(dataPath(end-1:end)),'") found in data names; Using middle #-']
                namiWaEnd = temp(2); %Assumption that hit 1 is date, hit 2 is year, hit 3+ is data file number
            elseif size(temp,2) <= 2
                namiWaEnd = temp(end);
            end
            %}
            %New (Stolen from ManCub)
            nama = [];
            for i = 1:size(FILES_BASE,1)
                nama(i,:) = FILES_BASE(i).name; %Is numbers, not string, but that is okay
            end
            unPos = nanmax( find( nansum(diff(nama,1),1) ~= 0 ) ); %Find last column that differs between filenames
            %QA
            if unPos == -1
                ['## Error finding unique name position ##']
                crash = yes
            end
            %flyName = FILES_BASE(1).name(1:namiWaEnd+1); %Assumption of format (but not a critical failing (assuming data is alone in folder))
            flyName = FILES_BASE(1).name(1:unPos-2); %Note slightly different offset
            flyName = strrep(flyName, '_', ' ')
        end
        
        %Check to see if output already exists, and skip if such and skipping requested
            %Borrowed from workspace saving section
        saveName = [flyName(1:end), '_analysis']
        saveNameFull = [savePath,'\',saveName];
        %Check for existing
        existFiles = dir([saveNameFull '.mat']);
        if isempty(existFiles) ~= 1
            disp(['-# Existing save output ',saveName,' is present #-'])
            if skipExisting == 1
                disp(['###################################################'])
                disp(['-# Skipping this dataset #-'])
                disp(['###################################################'])
                continue
            end
        end
        
        
        %values = [];

        %Identify unique identifiers for base
        nameAssumptionNecessary = 0; %Will be set to 1 if true
        if size(FILES_BASE,1) > 1
            nameTemp = [];
            for i = 1:size(FILES_BASE,1)
                nameTemp(i,:) = (FILES_BASE(i).name  ~= FILES_BASE(1).name); %Calculates difference of all names relative to first detected data file
            end
            sumNameTemp = nansum(nameTemp,1); %Sums to find places of discontinuity
            identPos = find(sumNameTemp ~= 0,1); %Assumes that first location of discontinuity is unique identifier
                %Note: This process critically relies on an intelligent name iteration procedure (i.e. 01, 02, ..., 10, 11, etc rather than 1, 2, ... 10, 11, etc)
            truncPos = identPos;
        else
            disp(['-# Caution: Only one data file detected; Name assumptions will be used #-'])
            truncPos = nanmax( strfind( FILES_BASE(1).name , '01') );
            nameAssumptionNecessary = 1;
        end
        

        %%%%

        %%

        a = 1;
        successFiles = 0;
        skippedFiles = 0; %Count of number of file/s that had to be skipped
        for IIDN = 1:length(FILES_BASE)

            %------------------------------------------------------------------
            %Imports all data and sorts into structures
            %Find unique identifier for base
            baseInd = 0;
            baseIndFound = 0;
            for dataSide = 1:size(dataList,2)
                if isempty(strfind(dataList{dataSide}, 'BASE')) ~= 1
                    baseInd = dataSide;
                    baseIndFound = baseIndFound + 1;
                end
            end
            if baseInd == 0 || baseIndFound > 1
                ['## CRITICAL ERROR IN FINDING POSITION OF BASE IDENTIFIER IN DATALIST ##']
                error = yes
            end
            %{
            %Old technique
            %preInd = strfind(FILES_BASE(IIDN).name, '_Tracker'); %Hardcoded
            %safeName = strrep(uniqueList{baseInd}, '\', ''); %Pull the BASE identifier and use it to derive the name
            %safeName = strrep(safeName, '*', '');
            safeName = strrep(uniqueList{baseInd}, '*', '');
            safeName = strrep(safeName, '.csv', ''); %Necessary to allow uniqueList specificity for prevention of overFinds during FILES
            preInd = strfind(FILES_BASE(IIDN).name, safeName); %This critically relies on symmetry between dataList and uniqueList
                %Strrep is used here to remove terminal folder specifier and wildcard
            %QA
            if isempty(preInd) == 1
                ['## WARNING: FAILURE IN AUTOMATED IDENTIFIER POSITION DETECTION ##']
                error = yes
            end
            %truncName = FILES_BASE(IIDN).name(preInd-7:preInd-6); %Should be the unique name
            %truncName = FILES_BASE(IIDN).name(preInd+16:preInd+17); %Should be the unique name for Matt data (Hardcoded)
                %Note: This is susceptible to multiple data sets from multiple days in one folder
                %(i.e. 'fly2Dorsal_17_12_18_01_.avi_Tracker_labpc_2018-12-19 11-55-25.csv' -> '01')
            %}
            truncName = FILES_BASE(IIDN).name(truncPos:truncPos+1); %Should be the unique name for Rhiannon data

            %QA for name correctness
            if isempty(str2num(truncName)) == 1
                ['## ALERT: POTENTIAL CRITICAL ERROR IN truncName ASSEMBLY ##']
                currentIsErrorDataset = 1;
                break
            end
            %{
            if incDLC == 1
                dlcInd = strfind(FILES_DLC(1).name, '_DeepCut'); %Hardcoded, Uses first file as exemplary
            end
            %}
            %Import base data iteratively and corresponding ancillary data
            %tempDATAE = []; %Stand-in for rawData so that messy structures and evals do not have to be used on every line of importation

            bigDataStruct = struct; %Will hold all data, cleared with each file
            bigDataStruct.procData = [];

            for dataSide = 1:size(dataList,2)            
                typeSpec = strcat('FILES_',dataList{dataSide}); %Simplifies referencing
                rawDataSpec = strcat(dataList{dataSide},'_rawData');
                if isempty(importStruct.(typeSpec)) ~= 1 %Proceed only if data was detected

                    %Identify unique identifiers
                    if nameAssumptionNecessary ~= 1
                        nameTemp = [];
                        for i = 1:size(importStruct.(typeSpec),1)
                            if size(importStruct.(typeSpec)(i).name,2) == size(importStruct.(typeSpec)(1).name,2)
                                nameTemp(i,:) = (importStruct.(typeSpec)(i).name  ~= importStruct.(typeSpec)(1).name); %Calculates difference of all names relative to first detected data file
                            else
                                ['## WARNING: CRITICAL DISCONTINUITY BETWEEN NAMES FOR ',typeSpec,' ##']
                                crash = yes
                            end
                        end
                        sumNameTemp = nansum(nameTemp,1); %Sums to find places of discontinuity
                        identPos = find(sumNameTemp ~= 0,1); %Assumes that first location of discontinuity is unique identifier
                            %Note: This process critically relies on an intelligent name iteration procedure (i.e. 01, 02, ..., 10, 11, etc rather than 1, 2, ... 10, 11, etc)
                    else
                        identPos = nanmax( strfind( importStruct.(typeSpec)(1).name , '01') ); %Only valid as long as only one file, but that is the whole point
                        %QA
                        if size(importStruct.(typeSpec),1) > 1
                            ['## Alert: Name assumptions used but more than one file (apparently) exists ##']
                            crash = yes
                        end
                    end

                    if isempty(strfind(typeSpec, 'FILES_BASE')) == 1
                        %Find data file for this data type that corresponds to base file
                        foundNum = 0;
                        foundIdx = 0; %Corresponds per type to position in FILES of the corresponding data set
                        for i = 1:size(importStruct.(typeSpec),1)
                            if isempty(strfind(importStruct.(typeSpec)(i).name(identPos:identPos+1), truncName)) ~= 1
                                foundNum = foundNum + 1;
                                foundIdx = i;
                            end
                        end                
                    else
                        foundNum = 1;
                        foundIdx = IIDN; %Because self
                        disp(['--------------------------------------------------------------'])
                        disp(['Current base file: ', FILES_BASE(IIDN).name])
                        disp([num2str(IIDN), ' of ', num2str(length(FILES_BASE))])
                    end
                    %QA
                    if foundNum ~= 1 %Either no find or find too many
                        ['## ERROR IN DATA FINDING FOR ', dataList{dataSide},' FILE NO. ', num2str(IIDN),' ##']
                        %error = yes %Enabled for debugging
                        currentIsErrorDataset = 1;
                        %crash = yes
                        break
                    end

                    %Specify path
                    importPath = [dataPath, uniqueSubFolderList{dataSide}, importStruct.(typeSpec)(foundIdx).name]; %changed from "path" because of overlap with MATLAB primaries
                    %importPath2 = 'C:\Users\labpc\Desktop\Matt\Flytography\data\SOFAS TESTING\28 04 19\DLC\fly1Dorsal_28_04_19_01_DeepCut_resnet50_flytographyJul12shuffle1_1030000.csv'

                    %Automatically detect header rows/columns
                    fieldOfNames = []; %Changed from "fieldNames" to avoid overlap with MATLAB primaries
                    %[temp, ~, numHeaderRows] = importdata(importPath); %Old, unsecured against (network) error
                    proceed = 0;
                    g = 1;
                    while proceed == 0 && g < 10
                        [temp, ~, numHeaderRows] = importdata(importPath);
                        if isempty( temp ) ~= 1
                            proceed = 1;
                        else
                            ['## Alert: Error in data importation ##']
                            if networkAnalysis == 1
                                g = g + 1;
                                pause(5) %Wait 5s
                            else
                                crash = yes
                            end
                        end
                    end
                    %QA to see if previous worked
                    if proceed ~= 1
                        ['## Alert: ',dataList{dataSide},' data could not be successfully imported ##']
                        currentIsErrorDataset = 1;
                        break
                    end
                    numHeaderCols = size(temp.textdata,2); %Automatically calculate number of columns from textdata
                        %Note: This will fail with some delimiters and/or odd data types

                    if numHeaderRows > 0
                        for headerRow = 1+headerIgnoreList(dataSide):numHeaderRows

                            %Find all detected header columns and stick together
                            detectedHeaders = [];
                            for headerCol = 1:numHeaderCols
                                detectedHeaders = [detectedHeaders, ',', temp.textdata{headerRow,headerCol}];
                            end

                            %Unstick column headers and nullify empty cells
                            splitHeaders = strsplit(detectedHeaders, ',');
                            for headerCol = size(splitHeaders,2):-1:1
                                if isempty(splitHeaders{headerCol}) == 1
                                    splitHeaders(headerCol) = [];
                                end
                            end
                            %splitHeaders(1) = []; %Fixes minor issue with generalisable delimeters
                                %Note: This is necessary due to variability in headers between <all other> and DLC data
                            for headerCol = 1:size(splitHeaders,2)
                                if headerRow == 1+headerIgnoreList(dataSide)
                                    fieldOfNames{headerCol} = splitHeaders{headerCol}; %First time through
                                else
                                    fieldOfNames{headerCol} = [fieldOfNames{headerCol}, '_', splitHeaders{headerCol}]; %Second or more
                                end
                            end                        
                        end
                        %Name cleaning
                        for i = 1:size(fieldOfNames,2)
                            fieldOfNames{i} = matlab.lang.makeValidName(fieldOfNames{i});
                        end
                    else
                        ['## Alert: No header rows detected in data ##']
                        error = yes
                        %Note: Should implement the blank header rows assignation here
                    end

                    %QA
                    if size(fieldOfNames,2) ~= numHeaderCols
                        ['## Alert: Error in column name autodetection ##']
                        error = yes
                    end


                    bigDataStruct.(dataList{dataSide}).columnFields = fieldOfNames;
                    bigDataStruct.(dataList{dataSide}).corresBaseIdx = foundIdx; %Corresponds to FILES_BASE position

                    %----------------------------------------------------------

                    %Manually identify data format
                    fid = fopen(importPath, 'r');

                    for i = 1:numHeaderRows+1
                        temp = textscan(fid, '%s', numHeaderCols, 'Delimiter',','); %Read one element at a time, iterating across the columns
                            %This returns a temp that corresponds to the first row of actual data
                    end
                    %Assemble data format
                    dataFormatStr = [];
                    for i = 1:size(temp{1},1)
                        isTempAString = str2num(temp{1}{i}); %Attempt to convert to a number
                            %...which will fail for the header row and only succeed on the first data row
                                %Note: Critically relies on column names not ever being only numerical
                        if isempty(isTempAString) == 1
                            dataFormatStr = [dataFormatStr, '%s ']; %Column is string
                        else
                            dataFormatStr = [dataFormatStr, '%f ']; %Column is floatable
                        end
                    end

                    fclose('all');

                    %Actually import data
                    %dataFormatStr = repmat('%s ', 1, numHeaderCols);
                    dataSpec = strcat(dataList{dataSide},'_DATAE'); %Raw imported data

                    bigDataStruct.(dataSpec).dataLength = 0;

                    fid = fopen(importPath, 'r');

                    bigDataStruct.(dataSpec) = textscan(fid, dataFormatStr, 'Delimiter',',', 'Headerlines', numHeaderRows);
                        %Note: This imports all columns as strings, which will need to be converted to integers/floats later
                            %This inconvenience is to allow for presence of text data columns

                    fclose('all');

                    disp([dataList{dataSide},' data successfully imported'])
                    %bigDataStruct.(dataSpec).dataLength = size(bigDataStruct.(dataSpec){1},1)
                    skipThisData = 0; %Will be used in case of asymmetry or for other purposes

                    %----------------------------------------------------------

                    %Marginal pre-processing
                    %rawDataSpec = strcat(dataList{dataSide},'_rawData');
                    %procDataSpec = strcat(dataList{dataSide},'_procData'); %procData is general, not specific

                    bigDataStruct.(rawDataSpec).filename = importStruct.(typeSpec)(foundIdx).name;
                    bigDataStruct.(rawDataSpec).dataLength = size(bigDataStruct.(dataSpec){1},1);
                    %bigDataStruct.(procDataSpec).filename = importStruct.(typeSpec)(foundIdx).name;  

                    %Neaten data
                    empColsFixed = 0;
                    for i = 1:size(fieldOfNames,2) %Technically susceptible to data/name asymmetry
                        if iscell(bigDataStruct.(dataSpec){i}(1)) == 1 %Will catch on strings and empties

                            if isempty(bigDataStruct.(dataSpec){i}{1}) == 1 %Specifically catches empties (But does not distinguish between string column that starts empty and data column that is also starting empty)
                                %preSend = bigDataStruct.(dataSpec){i}; %Deprecated technique
                                empColsFixed = empColsFixed + 1;
                                preSend = [];
                                isTempAString = str2num(bigDataStruct.(dataSpec){i}{end}); %Attempt to convert final cell to a number
                                    %This will be used as a repeated flag down below
                                %Iterate along column and map all empty cells
                                for empInd = 1:size(bigDataStruct.(dataSpec){i},1)
                                    if isempty(bigDataStruct.(dataSpec){i}{empInd}) == 1

                                        %try %If terminal data point is not a string, save as double, else cells
                                        %isTempAString = str2num(bigDataStruct.(dataSpec){i}{end}); %Attempt to convert to a number
                                        if isempty(isTempAString) ~= 1
                                            preSend(empInd,1) = NaN; %Numification passed, save as double
                                        %catch
                                        else
                                            preSend{empInd,1} = NaN; %Numification failed, save as string
                                        end
                                        %end

                                    else

                                        %isTempAString = str2num(bigDataStruct.(dataSpec){i}{end}); %Attempt to convert to a number
                                        if isempty(isTempAString) ~= 1
                                            preSend(empInd,1) = str2num(bigDataStruct.(dataSpec){i}{empInd}); %Numification passed, save as double
                                        else
                                            preSend{empInd,1} = bigDataStruct.(dataSpec){i}{empInd}; %Numification failed, save as string
                                        end  

                                    end
                                end
                            else %Cell is cell but not empty (Note: Current implementation means that columns that by rights should be doubles but might contain just one string/etc will be treated as string columns)
                                preSend = bigDataStruct.(dataSpec){i};
                            end                        

                            %bigDataStruct.(rawDataSpec).(fieldOfNames{i}) = bigDataStruct.(dataSpec){i};
                            %bigDataStruct.(rawDataSpec).(fieldOfNames{i})( isempty(bigDataStruct.(rawDataSpec).(fieldOfNames{i})) == 1 ) = NaN;
                        else
                            preSend = bigDataStruct.(dataSpec){i};
                        end

                        %{
                        bigDataStruct.(rawDataSpec).(fieldOfNames{i}) = bigDataStruct.(dataSpec){i};
                        %}

                        bigDataStruct.(rawDataSpec).(fieldOfNames{i}) = preSend;

                    end

                    if empColsFixed > 0
                        disp(['## ', num2str(empColsFixed),' cols containing empty data had to be fixed during importation for ', dataSpec ,' ##'])
                    end

                    %{
                    %Data format QA (Currently non-feasible for generalisable application)
                    if bigDataStruct.(dataSpec){2}(2) - bigDataStruct.(dataSpec){2}(1) ~= 1 %Check if timestamps consecutive (Crashes usually if format borked)
                        '## WARNING: LIKELY ASYMMETRY DETECTED IN FORMAT APPLIED TO DATA ##'
                        error = yes
                    end
                    %}

                    %----------------------------------------------------------

                else
                    disp([dataList{dataSide},' data not found'])
                %isempty end    
                end
            %dataSide end
            end

            %------------------------------------------------------------------

            if fixDorsAs == 1 %&& isempty(strfind(dataList{dataSide}, 'DORS')) ~= 1 %This portion may have horrible downstream effects; Second half disabled because outside dataSide loop
                dorsDataLength = bigDataStruct.DORS_rawData.dataLength;
                dataLength = bigDataStruct.BASE_rawData.dataLength;

                if dorsDataLength ~= dataLength %dors data is truncated compared to tracker data
                    %This should never be the case except when something has gone wrong,
                    %since dors data is supposed to be for every frame,
                    %and tracker data cannot exist for more frames than 'every'
                    ['-- Alert: Asymmetry detected between base (original) and dors (SwarmSight) data --']
                    disp(['(', num2str(dataLength), ' vs ',num2str(dorsDataLength), ')'])

                    if abs(dorsDataLength - dataLength) <= dorsDataLength*0.005 %Minor asymmetry
                        disp(['-- Fixing presumed minor asymmetry --'])
                        %Note: The likeliest case here is that SwarmSight has duplicated the terminal lines of a file
                        if dorsDataLength > dataLength %"Likely SwarmSight data duplication"
                            for i = 1:size(bigDataStruct.DORS.columnFields,2)
                                colFieldToWipe = bigDataStruct.DORS.columnFields{i};
                                bigDataStruct.DORS_rawData.(colFieldToWipe)(dataLength+1:dorsDataLength) = [];
                            end
                            bigDataStruct.DORS_rawData.dataLength = size(bigDataStruct.DORS_rawData.(colFieldToWipe),1);

                            %----------

                            %Also adjust tethered ancillary data sets (if necessary)
                            for dataSide = 1:size(dataList,2)
                                %ancDataLength = bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength; %Cannot exist here because of situations where does not exist
                                if isempty(strfind(dataList{dataSide}, 'BASE')) == 1 && isempty(strfind(tetherList{dataSide},'BASE')) ~= 1 & ...
                                        isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1% & ancDataLength > dataLength
                                    ancDataLength = bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength;
                                    if ancDataLength > dataLength
                                        rawDataColFields = bigDataStruct.(dataList{dataSide}).columnFields;
                                        sourceColField = bigDataStruct.DORS.columnFields{end};
                                        for colField = 1:size(rawDataColFields,2)
                                            bigDataStruct.(strcat(dataList{dataSide},'_rawData')).(rawDataColFields{colField})(dataLength+1:ancDataLength) = [];
                                        end
                                        bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength = size(bigDataStruct.(strcat(dataList{dataSide},'_rawData')).(rawDataColFields{colField}),1);
                                        disp(['-- Tethered data set ', dataList{dataSide}, ' also had to be fixed --'])
                                    end
                                end
                            end                                              
                            disp(['-- Minor (probably aberrant) data over-extension fixed --'])
                        else %"SwarmSight probably failed to process all lines"
                            %{
                            %--------------
                            %Fix asynchrony
                            for i = 1:size(bigDataStruct.DORS_DATAE,2)
                                try %Normal cells
                                    bigDataStruct.DORS_DATAE{i}(dorsDataLength:dataLength,1) = NaN; %Technically might be safer to use in-line calculated sizes?
                                catch %Nested string cells
                                    for x = dorsDataLength:dataLength
                                        bigDataStruct.DORS_DATAE{i}{x} = NaN;
                                    end
                                %catch end
                                end
                            %i end
                            end
                            %--------------
                            %Redo dorsRawData
                            dorsDataLength = length(bigDataStruct.DORS_DATAE{1});
                            bigDataStruct.DORS_rawData.dataLength = dorsDataLength;
                            disp(['-- New dorsDataLength: ', num2str(dorsDataLength), ' --'])
                            %bigDataStruct.DORS_rawData.dataLength = dorsDataLength; %Reassign value
                            %bigDataStruct.DORS_rawData = []; %Deprecated on account of causing significant downstream problems
                            for i = 1:size(bigDataStruct.DORS.columnFields,2) %Technically susceptible to data/name asymmetry
                                bigDataStruct.DORS_rawData.(bigDataStruct.DORS.columnFields{i}) = bigDataStruct.DORS_DATAE{i};
                            end
                            %}
                            %Better implementation of asynchrony fixing code (Doesn't post-hoc adjust DATAE)
                            for i = 1:size(bigDataStruct.DORS.columnFields,2)
                                colFieldToWipe = bigDataStruct.DORS.columnFields{i};
                                try %Normal conditions
                                    bigDataStruct.DORS_rawData.(colFieldToWipe)(dorsDataLength+1:dataLength) = NaN;
                                catch %Cell conditions
                                    for subInd = dorsDataLength+1:dataLength
                                        bigDataStruct.DORS_rawData.(colFieldToWipe){subInd} = NaN;
                                    end
                                end
                            end
                            bigDataStruct.DORS_rawData.dataLength = size(bigDataStruct.DORS_rawData.(colFieldToWipe),1);

                            %Also adjust tethered ancillary data sets
                            for dataSide = 1:size(dataList,2)
                                if isempty(strfind(dataList{dataSide}, 'BASE')) == 1 && isempty(strfind(tetherList{dataSide},'BASE')) ~= 1 & ...
                                        isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1
                                    rawDataColFields = bigDataStruct.(dataList{dataSide}).columnFields;
                                    sourceColField = bigDataStruct.DORS.columnFields{end}; %Pull NaNs from last of rawData columns (Assumption of non-cell-ness...)
                                    for colField = 1:size(rawDataColFields,2)
                                        bigDataStruct.(strcat(dataList{dataSide},'_rawData')).(rawDataColFields{colField})(isnan(bigDataStruct.DORS_rawData.(sourceColField)) == 1) = NaN;
                                            %Uses first column of DORS (that was fixed just now) as index to Nanify ancillary data at same points
                                    end
                                    bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength = size(bigDataStruct.(strcat(dataList{dataSide},'_rawData')).(rawDataColFields{colField}),1);
                                    disp(['-- Tethered data set ', dataList{dataSide}, ' also fixed --'])
                                end
                            end

                            disp(['-- Minor data truncation fixed --'])
                        end

                        %bigDataStruct.(rawDataSpec).filename = importStruct.(typeSpec)(foundIdx).name;
                        %bigDataStruct.(rawDataSpec).dataLength = size(bigDataStruct.(dataSpec){1},1);
                        %--------------
                    else %Major asymmetry
                        ['### WARNING: SIGNIFICANT ASYMMETRY DETECTED ###']
                        if IIDN == length(FILES_BASE) %Last file; Probably safe to assume SwarmSight terminal file bug occurred
                            ['### Terminal file; Attempting to jettison ###']
                            skipThisData = 1; %Flag to prevent rest of code from executing
                            skippedFiles = skippedFiles + 1;
                        else
                            ['### Current file is non-terminal; Cannot take action without risking continuity integrity ###']
                            %error = yes %Disabled to allow automation
                            currentIsErrorDataset = 1;
                        end
                    end
                %dorsDataLength < dataLength end    
                end
            %fixDorsAs end    
            end

            %QA for missing antennal data
            if isfield(bigDataStruct, 'DORS_rawData') == 1 &&...
                    ( iscell(bigDataStruct.DORS_rawData.LeftAngle) == 1 | iscell(bigDataStruct.DORS_rawData.RightAngle) == 1 )
                %If the rawData of angle is a cell, it probably means something occurred with importation or the source
                    %Note: There is the possibility of over-sensitivity here
                ['## Warning: Error in antennal angle data importation ##']
                if IIDN == length(FILES_BASE) %Last file
                    ['### Terminal file; Attempting to jettison ###']
                    skipThisData = 1; %Flag to prevent rest of code from executing
                    skippedFiles = skippedFiles + 1;
                else
                    ['### Current file is non-terminal; Cannot take action without risking continuity integrity ###']
                    %error = yes
                    %skipThisFile = 1;
                    %skipThisDataset = 1; %Break from doing entire dataset
                    currentIsErrorDataset = 1;
                    %skippedDatasets = skippedDatasets + 1;
                end
            end

            %Check if necessary to break (shifted below fixDorsAs to improve effectiveness)
            if currentIsErrorDataset == 1
                break
            end

            %Block commented because this is normal
            %{
            if abs(dlcDataLength - dataLength) > 0.01*dataLength % >1% deviation
                disp(['### ALERT: DISPARITY BETWEEN DLC AND DORS DATA ###'])
                if automation == 0
                    error = yes %Might convert this to a non-critical error if it becomes a persistent issue
                else
                    listOfErrorFiles(IIDN).fol = fol;
                    listOfErrorFiles(IIDN).SwarmSightName = [dataPath,'\',FILES(IIDN).name];
                    listOfErrorFiles(IIDN).BaseName = [dataPath,'\',FILES_DORS(dorsIdx).name];
                    listOfErrorFiles(IIDN).MovName = [dataPath,'\',FILES_MOV(movIdx).name];
                    listOfErrorFiles(IIDN).DLCName = [dlcPath,'\',FILES_DLC(dlcIdx).name];
                    listOfErrorFiles(IIDN).Reason = ['DLC/Dors disparity'];
                    numOfErrorFiles = numOfErrorFiles + 1;
                    currentIsErrorFile = 1;
                    break
                end
            end
            %}

            %-------------------------------

            if skipThisData ~= 1

                %--------------------------------------------------------------

                if automation == 1
                    %disp([' '])
                    disp([char(10),'-- Establishing global reference structure for base --'])
                end

                %Establish global reference struct
                globRef = struct;

                %------
                globRef.BaseName = bigDataStruct.BASE_rawData.filename; %Altered to be not reliant on FILES_DORS; Used to be Dors*Name (No asterisk)
                globRef.movName = bigDataStruct.MOV_rawData.filename; %Ditto
                if incDorsData == 1
                    globRef.SwarmName = bigDataStruct.DORS_rawData.filename;
                    globRef.SwarmFrame = bigDataStruct.DORS_rawData.Frame;
                end
                globRef.BaseFrame = bigDataStruct.BASE_rawData.nFrames; %Used to be Dors*Frame
                %{
                globRef.BaseName = bigDataStruct.DORS_rawData.filename; %Altered to be not reliant on FILES_DORS
                globRef.movName = bigDataStruct.MOV_rawData.filename; %Ditto
                globRef.SwarmName = bigDataStruct.BASE_rawData.filename;
                globRef.SwarmFrame = bigDataStruct.BASE_rawData.Frame;
                globRef.DorsFrame = bigDataStruct.DORS_rawData.nFrames;
                %}
                globRef.movFrameRaw = bigDataStruct.MOV_rawData.nFrames;
                globRef.movFrameMovRaw = bigDataStruct.MOV_rawData.Movement;
                globRef.movFrameMovNumRaw = [];
                %------
                globRef.movFrameMovDeltaPropRaw = bigDataStruct.MOV_rawData.DeltaProp;
                globRef.movFrameMovCntrNum = bigDataStruct.MOV_rawData.numCntrs;
                globRef.movFrameMovCntrAvSize = bigDataStruct.MOV_rawData.avCntrSize;     
                %------            
                %{
                globRef.BaseName = FILES_DORS(dorsIdx).name;
                globRef.movName = FILES_MOV(movIdx).name;
                globRef.SwarmName = procData.filename;
                globRef.SwarmFrame = rawData.Frame;
                globRef.DorsFrame = dorsRawData.nFrames;
                globRef.movFrameRaw = movRawData.nFrames;
                globRef.movFrameMovRaw = movRawData.Movement;
                globRef.movFrameMovNumRaw = [];
                %------
                globRef.movFrameMovDeltaPropRaw = movRawData.DeltaProp;
                globRef.movFrameMovCntrNum = movRawData.numCntrs;
                globRef.movFrameMovCntrAvSize = movRawData.avCntrSize;
                %}
                %------
                %globRef.DorsFrameTime = [];
                %------
                if incProbData == 1
                    globRef.probName = bigDataStruct.PROB_rawData.filename;
                    globRef.probFrameRaw = bigDataStruct.PROB_rawData.nFrames;
                    globRef.probFrameMovRaw = bigDataStruct.PROB_rawData.Movement;
                    globRef.probFrameMovNumRaw = [];
                    globRef.probFrameMovCntrAvSizeRaw = bigDataStruct.PROB_rawData.avCntrSize; %Some contour-associated metrics skipped
                end

                %%percDone = 0; %Ticker of completion to stave off despair
                %%percActual = 0; %The actual completion percentage
                %%percTime = []; %Timer for ETA purposes
                tic;

                %New, much faster method
                    %Note: This method may not handle NaNs the same way
                globRef.BaseFrameTime(1:size(globRef.BaseFrame,1),1) = NaN; %Used to be Dors*FrameTime

                nanSafeIndices = isnan(globRef.BaseFrame) ~= 1;

                dAAll = num2str(bigDataStruct.BASE_rawData.Year(nanSafeIndices));
                dBAll = num2str(bigDataStruct.BASE_rawData.Month(nanSafeIndices));
                dCAll = num2str(bigDataStruct.BASE_rawData.Date(nanSafeIndices));
                dDAll = num2str(bigDataStruct.BASE_rawData.Hour(nanSafeIndices));
                dEAll = num2str(bigDataStruct.BASE_rawData.Mins(nanSafeIndices));
                dFAll = num2str(bigDataStruct.BASE_rawData.Seconds(nanSafeIndices));

                predGAll = num2str(bigDataStruct.BASE_rawData.usec(nanSafeIndices));
                predGAll(predGAll == ' ') = '0';
                dGAll = predGAll;

                holdStringTemp = strcat(dAAll(1,:),'/',dBAll(1,:),'/',dCAll(1,:),'-', dDAll(1,:),':',dEAll(1,:),':',dFAll(1,:),'.',dGAll(1,:));
                holdStringArray = [{dAAll(:,:)},{'/'},{dBAll(:,:)},{'/'},{dCAll(:,:)},{'-'},{dDAll(:,:)},{':'},...
                    {dEAll(:,:)},{':'},{dFAll(:,:)},{'.'},{dGAll(:,:)}];

                combStringAll = repmat( repmat('0', 1, size(holdStringTemp,2)) , size(dAAll,1),1);

                combIt = 1;
                for timeSpecInd = 1:size(holdStringArray,2)
                    colCoords = [combIt : combIt + size(holdStringArray{timeSpecInd},2) - 1];
                    combStringAll(:,colCoords) = holdStringArray{timeSpecInd};
                    combIt = combIt + size(holdStringArray{timeSpecInd},2);
                end

                %combStringAll = strcat(dAAll,'/',dBAll,'/',dCAll,'-', dDAll,':',dEAll,':',dFAll,'.',dGAll); %Incredibly slow
                baseFrameTimeAll = datetime(combStringAll,'Format', 'yy/MM/dd-HH:mm:ss.SSSSSS'); %Used to be dors*FrameTimeAll
                posixBaseFrameTimeAll = posixtime(baseFrameTimeAll);
                globRef.BaseFrameTime(nanSafeIndices,1) = posixtime(baseFrameTimeAll);

                %baseFrame QA
                naNi = 0; %Oumae wa mo, shindeiru
                for i = 1:size(globRef.BaseFrameTime,1)
                    if globRef.BaseFrameTime(i) == 0
                        globRef.BaseFrameTime(i) = NaN;
                        naNi = naNi + 1; 
                    end
                end
                if naNi ~= 0
                    ['-- Alert: ', num2str(naNi), ' instance/s of zero had to be replaced in dors frametime data --']
                end
                if nansum(isnan(globRef.BaseFrameTime) == 1) > 0
                    disp(['-- Alert: ', num2str(nansum(isnan(globRef.BaseFrameTime) == 1)) , ' instances of NaN occurred in frametime data --'])
                end

                %Post-hoc apply reference frame to any tethered ancillary data sets
                for dataSide = 1:size(dataList,2)
                    if isempty(strfind(dataList{dataSide}, 'BASE')) == 1 && isempty(strfind(tetherList{dataSide},'BASE')) ~= 1 & ...
                            isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1
                        if bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength == size(globRef.BaseFrame,1)
                            globRef.(strcat(dataList{dataSide},'_Name')) = bigDataStruct.(strcat(dataList{dataSide},'_rawData')).filename;
                            globRef.(strcat(dataList{dataSide},'_FrameRaw')) = globRef.BaseFrame;
                            globRef.(strcat(dataList{dataSide},'_FrameTimeRaw')) = globRef.BaseFrameTime;
                        else
                            ['## Warning: Critical size disparity during attempted tethering ##']
                            error = yes
                        end
                    end
                end

                if automation == 1
                    disp(['-- Base global reference established in ', num2str(round(toc,2)) , ' seconds --'])
                end

                %--------------------------------------------------------------

                if automation == 1
                    disp(['-- Establishing global reference structure for mov --'])
                end
                tic
                
                %Duplicate if BASE and MOV data identical
                if isequal( globRef.BaseName , globRef.movName ) == 1
                    disp(['(BASE and MOV identical; Duplicating)'])
                    
                    globRef.movFrameTimeRaw = globRef.BaseFrameTime;
                    globRef.movFrameRaw = globRef.BaseFrame;
                    
                    globRef.movFrameMovRaw = bigDataStruct.MOV_rawData.Movement(:);
                    if incProbData == 1
                        globRef.probFrameMovRaw = bigDataStruct.PROB_rawData.Movement(:);
                    end
                    
                    %Vectorised determination of movement vs still
                    globRef.movFrameMovNumRaw = nan( size(globRef.movFrameRaw,1) , 1 );
                    temp = strfind(globRef.movFrameMovRaw, 'Moved');
                    temp = ~cellfun('isempty',temp);
                    globRef.movFrameMovNumRaw( temp ) = 1;
                    globRef.movFrameMovNumRaw( ~temp ) = 0;
                    if incProbData == 1
                        globRef.probFrameMovNumRaw = nan( size(globRef.movFrameRaw,1) , 1 );
                        temp = strfind(globRef.probFrameMovRaw, 'Moved');
                        temp = ~cellfun('isempty',temp);
                        globRef.probFrameMovNumRaw( temp ) = 1;
                        globRef.probFrameMovNumRaw( ~temp ) = 0;
                    end
                    
                    %movFrame QA (May be redundant if QA already applied to BASE data)
                    naNi = 0; %Oumae wa mo, shindeiru
                    for i = 1:size(globRef.movFrameTimeRaw,1)
                        if globRef.movFrameTimeRaw(i) == 0
                            globRef.movFrameTimeRaw(i) = NaN;
                            naNi = naNi + 1; 
                        end
                    end
                    if naNi ~= 0
                        disp(['-- Alert: ', num2str(naNi), ' instance/s of zero had to be replaced in mov frametime data --'])
                    end
                    
                    %Post-hoc apply reference frame to any tethered ancillary data sets
                    for dataSide = 1:size(dataList,2)
                        if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                                isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1
                            if bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength == size(globRef.movFrameRaw,1)
                                globRef.(strcat(dataList{dataSide},'_Name')) = bigDataStruct.(strcat(dataList{dataSide},'_rawData')).filename;
                                globRef.(strcat(dataList{dataSide},'_FrameRaw')) = globRef.movFrameRaw;
                                globRef.(strcat(dataList{dataSide},'_FrameTimeRaw')) = globRef.movFrameTimeRaw;
                            else
                                ['## Warning: Critical size disparity during attempted tethering ##']
                                error = yes
                            end
                        end
                    end
                    
                    
                else

                    %{
                    %Repeat above for mov frames (not actually that computationally inefficient to do this separate)
                    percDone = 0; %Ticker of completion to stave off despair
                    percActual = 0; %The actual completion percentage
                    percTime = []; %Timer for ETA purposes
                    %}
                    %tic;

                    %New, much faster method for mov
                    globRef.movFrameTimeRaw(1:size(globRef.movFrameRaw,1),1) = NaN;

                    nanSafeIndices = isnan(globRef.movFrameRaw) ~= 1;

                    mAAll = num2str(bigDataStruct.MOV_rawData.Year(nanSafeIndices));
                    mBAll = num2str(bigDataStruct.MOV_rawData.Month(nanSafeIndices));
                    mCAll = num2str(bigDataStruct.MOV_rawData.Date(nanSafeIndices));
                    mDAll = num2str(bigDataStruct.MOV_rawData.Hour(nanSafeIndices));
                    mEAll = num2str(bigDataStruct.MOV_rawData.Mins(nanSafeIndices));
                    mFAll = num2str(bigDataStruct.MOV_rawData.Seconds(nanSafeIndices));

                    premGAll = num2str(bigDataStruct.MOV_rawData.usec(nanSafeIndices));
                    premGAll(premGAll == ' ') = '0';
                    mGAll = premGAll;

                    holdStringTemp = strcat(mAAll(1,:),'/',mBAll(1,:),'/',mCAll(1,:),'-', mDAll(1,:),':',mEAll(1,:),':',mFAll(1,:),'.',mGAll(1,:));
                    holdStringArray = [{mAAll(:,:)},{'/'},{mBAll(:,:)},{'/'},{mCAll(:,:)},{'-'},{mDAll(:,:)},{':'},...
                        {mEAll(:,:)},{':'},{mFAll(:,:)},{'.'},{mGAll(:,:)}];

                    combStringAll = repmat( repmat('0', 1, size(holdStringTemp,2)) , size(mAAll,1),1);

                    combIt = 1;
                    for timeSpecInd = 1:size(holdStringArray,2)
                        colCoords = [combIt : combIt + size(holdStringArray{timeSpecInd},2) - 1];
                        combStringAll(:,colCoords) = holdStringArray{timeSpecInd};
                        combIt = combIt + size(holdStringArray{timeSpecInd},2);
                    end

                    %combStringAll = strcat(dAAll,'/',dBAll,'/',dCAll,'-', dDAll,':',dEAll,':',dFAll,'.',dGAll); %Incredibly slow
                    movFrameTimeAll = datetime(combStringAll,'Format', 'yy/MM/dd-HH:mm:ss.SSSSSS');
                    posixMovFrameTimeAll = posixtime(movFrameTimeAll);
                    globRef.movFrameTimeRaw(nanSafeIndices,1) = posixtime(movFrameTimeAll);

                    %Process for movement and prob.
                    %Note: This loop reordered in line with reducing assumption of probData existence
                    globRef.movFrameMovRaw = bigDataStruct.MOV_rawData.Movement(:);
                    if incProbData == 1
                        globRef.probFrameMovRaw = bigDataStruct.PROB_rawData.Movement(:);
                    end
                    for i = 1:size(globRef.movFrameRaw,1)
                        movFrameNo = globRef.movFrameRaw(i); 
                        if incProbData == 1
                            probFrameNo = globRef.probFrameRaw(i);
                            if probFrameNo ~= movFrameNo %This is to safeguard the tethering assumption between prob and mov
                                disp(['### ALERT: CRITICAL DISPARITY BETWEEN PROB AND MOV FRAME NUMBERS ###'])
                                error = yes
                            end
                            %Prob.
                            if isempty(strfind(globRef.probFrameMovRaw{probFrameNo,1},'Moved')) ~= 1 %Whether fly moved
                                globRef.probFrameMovNumRaw(probFrameNo,1) = 1; %Record as movement
                            else
                                globRef.probFrameMovNumRaw(probFrameNo,1) = 0; %Record as still
                            end
                        end
                        %globRef.movFrameMovRaw(movFrameNo,1) = {bigDataStruct.MOV_rawData.Movement(movFrameNo)}; %Old method
                        %Mov
                        if isempty(strfind(globRef.movFrameMovRaw{movFrameNo,1},'Moved')) ~= 1 %Fly moved
                            globRef.movFrameMovNumRaw(movFrameNo,1) = 1; %Record as movement
                        else
                            globRef.movFrameMovNumRaw(movFrameNo,1) = 0; %Record as still
                        end
                    end

                    %movFrame QA
                    naNi = 0; %Oumae wa mo, shindeiru
                    for i = 1:size(globRef.movFrameTimeRaw,1)
                        if globRef.movFrameTimeRaw(i) == 0
                            globRef.movFrameTimeRaw(i) = NaN;
                            naNi = naNi + 1; 
                        end
                    end
                    if naNi ~= 0
                        disp(['-- Alert: ', num2str(naNi), ' instance/s of zero had to be replaced in mov frametime data --'])
                    end

                    %Post-hoc apply reference frame to any tethered ancillary data sets
                    for dataSide = 1:size(dataList,2)
                        if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                                isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1
                            if bigDataStruct.(strcat(dataList{dataSide},'_rawData')).dataLength == size(globRef.movFrameRaw,1)
                                globRef.(strcat(dataList{dataSide},'_Name')) = bigDataStruct.(strcat(dataList{dataSide},'_rawData')).filename;
                                globRef.(strcat(dataList{dataSide},'_FrameRaw')) = globRef.movFrameRaw;
                                globRef.(strcat(dataList{dataSide},'_FrameTimeRaw')) = globRef.movFrameTimeRaw;
                            else
                                ['## Warning: Critical size disparity during attempted tethering ##']
                                error = yes
                            end
                        end
                    end

                end
                
                if automation == 1
                    disp(['-- Mov global reference established in ', num2str(round(toc,2)) , ' seconds --'])
                end

                %--------------------------------------------------------------

            end
            %eStabGlob end
            %end

            if skipThisData ~= 1
                if incDorsData == 1
                    %----------
                    %Collate left and right antennal angular positions
                    %leftTheta = rawData.LeftAngle;
                    %rightTheta = rawData.RightAngle;
                    leftTheta = bigDataStruct.DORS_rawData.LeftAngle; %Adjusted to be DORS rather than BASE
                    rightTheta = bigDataStruct.DORS_rawData.RightAngle; %Adjusted to be DORS rather than BASE

                    %Filter likely anomalous cases out of data
                    anomThresh = 2; %Antennal angle changes of greater than anomThresh SDs assumed to be anomalous
                    %---------------------------------------------------
                    %Right
                    rightThetaProc = []; %Filtered right antennal angles
                    rightThetaSTD = nanstd(rightTheta);
                    rightThetaProc(1,1) = rightTheta(1);
                    anomInstances = 0;
                    for i = 2:size(rightTheta,1) 
                        if abs(rightTheta(i) - rightTheta(i-1)) > anomThresh*rightThetaSTD
                            rightThetaProc(i,1) = rightTheta(i-1); %Not the prettiest but it should work
                            anomInstances = anomInstances + 1;
                        else
                            rightThetaProc(i,1) = rightTheta(i);
                        end
                    end
                    %---------------------------------------------------
                    %Left
                    leftThetaProc = []; %Filtered right antennal angles
                    leftThetaSTD = nanstd(leftTheta);
                    leftThetaProc(1,1) = leftTheta(1);
                    for i = 2:size(leftTheta,1) 
                        if abs(leftTheta(i) - leftTheta(i-1)) > anomThresh*leftThetaSTD
                            leftThetaProc(i,1) = leftTheta(i-1); %Not the prettiest but it should work
                            anomInstances = anomInstances + 1;
                        else
                            leftThetaProc(i,1) = leftTheta(i);
                        end
                    end
                    %---------------------------------------------------
                    ['-- ', num2str(anomInstances), ' presumably anomalous antennal angle values filtered --']
                    %----------
                end
                %DLC data
                successPullDLC = 0; 
                if incDLC == 1 %&& incAntDLC == 1
                    hasPartList = zeros( 1 , size(partList,2) );
                    for i = 1:size(partList,2) 
                        for x = 1:size(valList,2)
                            for DLCInd = 1:size(dataList,2)
                                if isempty(strfind(dataList{DLCInd},'DLC')) ~= 1
                                    try %Attempt to pull requisite data from DLC dataset, catch on failure
                                        bigDataStruct.procData.(strcat('dlc',partList{i},'_',valList{x})) = bigDataStruct.(strcat(dataList{DLCInd},'_rawData')).(strcat(partList{i},'_',valList{x}));
                                        successPullDLC = 1;
                                        hasPartList(i) = 1;
                                    catch
                                        temp = [];
                                    end
                                end
                            end
                        end                
                    end
                    %QA for lack of part data
                    if nansum( hasPartList == 0 ) > 0
                        ['## Alert: DLC data lacks one or more necessary bodyparts ##']
                        partList{ hasPartList == 0 }
                        crash = yes
                    end
                end
                %QA
                if incDLC == 1 && incAntDLC == 1 && successPullDLC == 0
                    ['## Alert: Failed to successfully pull DLC data ##']
                    error = yes
                end
                
                %And other ancillary (Not DLC)
                tethAnc = 0;
                ancDataSpecs = [];
                ancFielNames = {};
                for t = 1:size( tetherList,2 )
                    ancFielNames{t} = {};
                    if contains( dataList{t} , 'DLC' ) ~= 1 && contains( tetherList{t} , 'NULL' ) ~= 1 %Don't act on DLC or regular data
                        fielNames = fieldnames( bigDataStruct.(strcat(dataList{t},'_rawData')) );
                        for fiel = 1:size( fielNames , 1 )
                            if contains( fielNames{fiel} , 'filename' ) ~= 1 && contains( fielNames{fiel} , 'dataLength' ) ~= 1 %Note: Weak to extra rawData ancillary fields being added
                                bigDataStruct.procData.(strcat(dataList{t},'_',fielNames{fiel})) = bigDataStruct.(strcat(dataList{t},'_rawData')).( fielNames{fiel} );
                                ancFielNames{t} = [ ancFielNames{t} ; { strcat( dataList{t},'_', fielNames{fiel} ) } ]  ;
                            end
                        end
                        ancDataSpecs{t} = strcat(dataList{t},'_procData');
                        
                        tethAnc = tethAnc + 1;
                    end
                end
                if tethAnc > 0
                    disp(['-- ',num2str(tethAnc),' tethered ancillary dataset/s were imported to procData --'])
                end

                %Save data for overuse
                if incDorsData == 1
                    bigDataStruct.DORS_rawData.leftTheta = leftTheta; %Adjusted to be DORS rather than BASE
                    bigDataStruct.DORS_rawData.rightTheta = rightTheta; %Adjusted to be DORS rather than BASE

                    bigDataStruct.procData.leftThetaProc = leftThetaProc;
                    bigDataStruct.procData.rightThetaProc = rightThetaProc;
                else
                    bigDataStruct.DORS_rawData = []; %May be unnecessary...
                end
                bigDataStruct.procData.globRef = globRef;
                %{
                rawData.leftTheta = leftTheta;
                rawData.rightTheta = rightTheta;

                procData.leftThetaProc = leftThetaProc;
                procData.rightThetaProc = rightThetaProc;
                procData.globRef = globRef;
                %}
                %values{a} = rawData; %a only iterates with successful threshold meet
                %valuesProc{a} = procData;
                %values{a} = bigDataStruct.DORS_rawData; %a only iterates with successful threshold meet
                valuesProc{a} = bigDataStruct.procData;

                successFiles = successFiles + 1;

                a = a + 1;
                %-------------------------------------------------------------------------------------
            %skipThisData end
            end

        %IIDN end
        end
        if currentIsErrorDataset == 1 %&& automation == 1
            ['### Breaking on account of error ###']
            skippedDatasets = skippedDatasets + 1;
            continue
        end

        %-----------------------
        %Start block run point
        ['-- Establishing overGlob --']

        %Perform over-processing on successful data sets
        if eStabGlob == 1
            overGlob = struct; %Container structure
            overGlob.dataList = dataList; %List of data that was to be found
            overGlob.hasDataList = hasDataList; %List of data that actually was found for this dataset
            overGlob.importStruct = importStruct; %List of all data files used for this analysis
            overGlob.rightThetaProc = []; %Pooled right antennal angles
            overGlob.leftThetaProc = []; %Pooled left antennal angles
            overGlob.BaseFrame = []; %Pooled base frame numbers (previously dorsal)
            overGlob.BaseFrameTime = []; %Pooled base frame times (previously dorsal)
            overGlob.BaseFrameRef = []; %Same as BaseFrame but with a partner column for dataset number (previously BaseFrameRef)
            %------
            overGlob.movFrameRefRaw = []; %Original movement frame numbers (unmatched)
            overGlob.movFrameTimeRaw = []; %Pooled movement frame times (unmatched)
            overGlob.movFrameMovRaw = []; %Pooled movement frame movement converted-to-number (unmatched)
            overGlob.movFrameMovNumRaw = []; %Pooled movement frame movement converted-to-number (unmatched)
            %------
            overGlob.movFrameMovDeltaPropRaw = []; %Pooled movement frame proportioned pixel differences (unmatched)
            overGlob.movFrameMovCntrNumRaw = []; %Pooled movement frame number of detected contours (unmatched)
            overGlob.movFrameMovCntrAvSizeRaw = []; %Pooled movement frame average contour size (unmatched)
            %------
            overGlob.movFrameRef = []; %Pooled movement frame original frame numbers (matched)
            overGlob.movFrameRefID = []; %Pooled movement frame original frame corresponding vid numbers (matched)
            overGlob.movFrameTime = []; %Pooled movement frame times (matched)
            overGlob.movFrameMov = []; %Pooled movement frame activity (matched)
            overGlob.movFrameMovNum = []; %Pooled movement frame activity-converted-to-number (matched)
            %------
            overGlob.movFrameMovDeltaProp = []; %Pooled movement frame proportioned pixel differences (matched)
            overGlob.movFrameMovCntrNum = []; %Pooled movement frame number of detected contours (matched)
            overGlob.movFrameMovCntrAvSize = []; %Pooled movement frame average contour size (matched)
            %------
            overGlob.firstBaseFrameTimeIdx = []; %List of the overglob data positions for use in plotting (previously DorsFrame)
            overGlob.firstBaseFrameTimeTime = []; %Associated (posix) times for overglob data positions (previously DorsFrame)
            %overGlob.firstDorsFrameTimeTimeDate = []; %Associated julian times for overglob data positions (previously DorsFrame)
            overGlob.dorsMovDeviation = []; %Self-detected deviation between dors frame time and mov frame time, per frame
            %------

            totalDatasets = totalDatasets + 1;
            %Hardcoded probData
            if incProbData == 1
                overGlob.probFrameRefRaw = []; %Original proboscis frame numbers (unmatched)
                overGlob.probFrameRef = []; %Pooled proboscis frame original frame numbers (matched)
                overGlob.probFrameMovNumRaw = []; %Pooled movement frame movement converted-to-number (unmatched)
                overGlob.probFrameMovNum = []; %Pooled proboscis frame activity converted-to-number (matched)
                overGlob.probFrameMovCntrAvSizeRaw = [];
                overGlob.probFrameMovCntrAvSize = []; %Pooled proboscis frame average contour size (matched)

                probDatasets = probDatasets + 1;
            end
            %DLC data (but could probably be pretty easily extended to other data sets?)
            if incDLC == 1
                for dataSide = 1:size(dataList,2)
                    if isfield(globRef,strcat(dataList{dataSide},'_Name')) == 1

                        overGlob.(strcat(dataList{dataSide},'_FrameRefRaw')) = []; %Pooled <ancillary data> frame original frame numbers (unmatched)
                        overGlob.(strcat(dataList{dataSide},'_FrameRef')) = []; %Pooled <ancillary data> frame original frame numbers (matched)

                        %{
                        %Pre-define data fields according to rawData (Deprecated on account of non-desire to have filename/etc be sent to overGlob)
                        eval([' existingDLCDataFields = fieldnames(bigDataStruct.', strcat(dataList{dataSide},'_rawData') ,'); ']); %Bad habits pt. 39
                        for i = 1:size(existingDLCDataFields,1)
                            %overGlob.dlcData.(strcat('dlc_',existingDLCDataFields{i})) = [bigDataStruct.(strcat(dataList{dataSide}, '_rawData')).(existingDLCDataFields{i})]; %Precocious
                            overGlob.dlcData.(strcat(existingDLCDataFields{i})) = [];
                        end
                        %}

                        if incDLC == 1 %Doubling up on ifs
                            %Pre-define data fields according to total list but only if existing in rawData as well
                            for i = 1:size(partList,2) 
                                for x = 1:size(valList,2)
                                    if isfield(bigDataStruct.(strcat(dataList{dataSide},'_rawData')), strcat(partList{i},'_',valList{x})) == 1
                                        %Check if part exists in DLC file and pre-define a blank field if so
                                        overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{i},'_',valList{x})) = [];
                                    end
                                end                
                            end
                        end
                    %isfield end    
                    end
                %dataSide end
                end
                dlcDatasets = dlcDatasets + 1;

                %Prepare list of part/value combinations to cut down on use of strcat and speed up mov frame matching
                partValList = []; %Matches to actual names
                procPartValList = []; %Inclusion of preceding 'dlc' for matching with valuesProc
                d = 1;
                for partI = 1:size(partList,2) 
                    for valX = 1:size(valList,2)
                        partValList{d} = strcat(partList{partI},'_',valList{valX});
                        procPartValList{d} = strcat('dlc',partList{partI},'_',valList{valX});
                        d = d + 1;
                    end
                end

            %DLC end
            end
        %eStabGlob end
        end

        percDone = 0; %Ticker of completion to stave off despair
        percActual = 0; %The actual completion percentage
        percTime = []; %Timer for ETA purposes
        tic;

        idxTemp = 1;
        a = 1;
        for IIDN = 1:size(valuesProc,2) %Dataset number    
            if eStabGlob == 1
                if incDorsData == 1
                    overGlob.rightThetaProc = [overGlob.rightThetaProc; valuesProc{IIDN}.rightThetaProc];
                    overGlob.leftThetaProc = [overGlob.leftThetaProc; valuesProc{IIDN}.leftThetaProc];
                end
                overGlob.BaseFrame = [overGlob.BaseFrame; valuesProc{IIDN}.globRef.BaseFrame];
                %{
                tempDouble = [];
                for i = 1:size(valuesProc{IIDN}.globRef.DorsFrame,1) %This loop is so that dorsFrameRef ends up as a matrix of doubles, rather than the native cells
                    if isnan(valuesProc{IIDN}.globRef.DorsFrame{i,1}) ~= 1
                        tempDouble(i,1:2) = [str2num(valuesProc{IIDN}.globRef.DorsFrame{i,1}) IIDN];
                    else
                        tempDouble(i,1:2) = [NaN NaN];
                    end
                    a = a + 1;
                end
                overGlob.DorsFrameRef = [overGlob.DorsFrameRef; tempDouble];  %Deprecated on account of more rigorous importation checks
                %}
                overGlob.BaseFrameRef = [overGlob.BaseFrameRef; valuesProc{IIDN}.globRef.BaseFrame repmat(IIDN,size(valuesProc{IIDN}.globRef.BaseFrame,1),1)];
                overGlob.BaseFrameTime = [overGlob.BaseFrameTime; valuesProc{IIDN}.globRef.BaseFrameTime];
                %------
                overGlob.movFrameRefRaw = [overGlob.movFrameRefRaw; valuesProc{IIDN}.globRef.movFrameRaw repmat(IIDN,size(valuesProc{IIDN}.globRef.movFrameRaw,1),1)]; %2 columns of doubles
                overGlob.movFrameTimeRaw = [overGlob.movFrameTimeRaw; valuesProc{IIDN}.globRef.movFrameTimeRaw];
                overGlob.movFrameMovRaw = [overGlob.movFrameMovRaw; valuesProc{IIDN}.globRef.movFrameMovRaw];
                overGlob.movFrameMovNumRaw = [overGlob.movFrameMovNumRaw; valuesProc{IIDN}.globRef.movFrameMovNumRaw];
                %------
                overGlob.movFrameMovDeltaPropRaw = [overGlob.movFrameMovDeltaPropRaw; valuesProc{IIDN}.globRef.movFrameMovDeltaPropRaw];
                overGlob.movFrameMovCntrNumRaw = [overGlob.movFrameMovCntrNumRaw; valuesProc{IIDN}.globRef.movFrameMovCntrNum];
                overGlob.movFrameMovCntrAvSizeRaw = [overGlob.movFrameMovCntrAvSizeRaw; valuesProc{IIDN}.globRef.movFrameMovCntrAvSize];
                %------
                %overGlob.movFrameMovNum = [overGlob.movFrameMovNum; valuesProc{IIDN}.globRef.movFrameMovNum];
                %overGlob.movFrameMovNumBinned = [overGlob.movFrameMovNumBinned; valuesProc{IIDN}.globRef.movFrameMovNumBinned];
                overGlob.firstBaseFrameTimeIdx = [overGlob.firstBaseFrameTimeIdx; idxTemp];
                overGlob.firstBaseFrameTimeTime = [overGlob.firstBaseFrameTimeTime; valuesProc{IIDN}.globRef.BaseFrameTime(1)];
                overGlob.firstBaseFrameTimeTimeDate{IIDN,1} = datestr(datetime(overGlob.firstBaseFrameTimeTime(IIDN), 'ConvertFrom', 'posixtime'));
                %------
                if incProbData == 1
                    overGlob.probFrameMovNumRaw = [overGlob.probFrameMovNumRaw; valuesProc{IIDN}.globRef.probFrameMovNumRaw];
                    overGlob.probFrameMovCntrAvSizeRaw = [overGlob.probFrameMovCntrAvSizeRaw; valuesProc{IIDN}.globRef.probFrameMovCntrAvSizeRaw];
                    overGlob.probFrameRefRaw = [overGlob.probFrameRefRaw; valuesProc{IIDN}.globRef.probFrameRaw repmat(IIDN,size(valuesProc{IIDN}.globRef.probFrameRaw,1),1)];
                end
                %------
                if incDLC == 1 && incAntDLC == 1
                    %Generalised data synchronisation clone parent (Dors data variant)
                    %dlcFieldsToFind = fieldnames(overGlob.dlcData); %Stores list of DLC data columns to find from 
                    for dataSide = 1:size(dataList,2)
                        if isempty(strfind(dataList{dataSide}, 'BASE')) == 1 && isempty(strfind(tetherList{dataSide},'BASE')) ~= 1 & ...
                            isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1 
                            %Note: FrameRefRaw excluded on account of BaseFrame being base for reference
                            overGlob.(strcat(dataList{dataSide},'_FrameRef')) = [overGlob.(strcat(dataList{dataSide},'_FrameRef')); overGlob.BaseFrameRef];

                            if incDLC == 1 %&& incAntDLC == 1 %Doubling up on ifs in preparation for future generalisation away from DLC

                                %-------------------
                                for i = 1:size(partList,2) 
                                    for x = 1:size(valList,2)
                                        if isfield(bigDataStruct.(strcat(dataList{dataSide},'_rawData')), strcat(partList{i},'_',valList{x})) == 1
                                            overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{i},'_',valList{x})) = ...
                                                [overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{i},'_',valList{x})); valuesProc{IIDN}.(strcat('dlc',partList{i},'_',valList{x}))];
                                        end
                                    end                
                                end
                                %This section attempts to find the part/value in the rawData and appends it to overGlob
                                %Only data types that are tethered to dors will be appended during this phase of overGlob assembly
                                %-------------------

                            end

                        end
                    end
                %incDLC and incAntDLC end    
                end
                %------

                idxTemp = idxTemp + size(valuesProc{IIDN}.globRef.BaseFrameTime,1);
            end

            percActual = IIDN/size(valuesProc,2);
            percTime = toc;
            tic;
            disp([num2str(round(IIDN/size(valuesProc,2)*100),3),'% done establishing (ETA: ',num2str((1-percActual)*10*percTime), 's)'])
            %%['ETA: ',num2str((1-percActual)*10*percTime), ' seconds']
        end

        %-------------------------------

        if incDorsData == 1
            %Custom variables to workspace for later analysis purposes
            rightThetaProcAll = overGlob.rightThetaProc;
            leftThetaProcAll = overGlob.leftThetaProc;

            %Legacy variables for same
            rightThetaProc = overGlob.rightThetaProc;
            leftThetaProc = overGlob.leftThetaProc;
        end
        
        %QA DLC data (if existing) for correct architecture
        for dataSide = 1:size(dataList,2)
            if isempty( strfind( dataList{dataSide} , 'DLC' ) ) ~= 1 && isfield( overGlob , [dataList{dataSide},'_dlcData'] ) == 1
                dlcFiels = fieldnames( overGlob.([dataList{dataSide},'_dlcData']) );
                for fiel = 1:size(dlcFiels,1)
                    thisFiel = dlcFiels{fiel};
                    if size( overGlob.([dataList{dataSide},'_dlcData']).( thisFiel ) , 2 ) > size( overGlob.([dataList{dataSide},'_dlcData']).( thisFiel ) , 1 )
                            %Note: This effectively enforces all data to be arranged in rows
                            %Secondary note: Theoretically, high column number low row data could be falsely picked up here, but it seems unlikely outside of very odd architectures
                        disp(['-# ',dataList{dataSide},' field ',thisFiel,' architecture incorrect (',...
                            num2str(size( overGlob.([dataList{dataSide},'_dlcData']).( thisFiel ) , 1 )),...
                            ' x ',num2str(size( overGlob.([dataList{dataSide},'_dlcData']).( thisFiel ) , 2 )),'); Correcting #-'])
                        crash = yes %Currently large problem, due to potential zeroification of data
                        %overGlob.([dataList{dataSide},'_dlcData']).( thisFiel ) = overGlob.([dataList{dataSide},'_dlcData']).( thisFiel )';
                    end
                end
            end
        end
        
        %-------------------------------

        ['-- Finished establishment of overGlob --']

        %-------------------------------
        %New position for slow-processing dors/mov matching
        ['-- Beginning matching of mov data --']
        
        %Minimise later strcat use
        rawSpecs = []; %Used for rawDataSpec
        dlcSpecs = []; %Used for dlcDataSpec (where applicable, empty elsewhere)
        refSpecs = []; %Used for references to <>_FrameRef
        for dataSide = 1:size(dataList,2)
            rawSpecs{dataSide} = strcat(dataList{dataSide},'_rawData');
            if incDLC == 1 && contains( dataList{dataSide} , 'DLC' ) == 1
                dlcSpecs{dataSide} = strcat(dataList{dataSide},'_dlcData');
            end
            refSpecs{dataSide} = strcat(dataList{dataSide},'_FrameRef');
        end
        
        %Check to see if MOV is in fact BASE
        if isequal( globRef.BaseName , globRef.movName ) == 1
            disp(['--- MOV detected to be identical to BASE; Duplicating ---'])
            tic
            
            %###
            overGlob.movFrameRef(:,1) = overGlob.BaseFrameRef(:,1); %Original mov frame number, plus video number
            overGlob.movFrameRefID(:,1) = overGlob.BaseFrameRef(:,2);
            overGlob.movFrameTime(:,1) = overGlob.BaseFrameTime; %Posix time of mov frame
            overGlob.movFrameMov = overGlob.movFrameMovRaw; %Whether mov frame had detected movement
            overGlob.movFrameMovNum(:,1) = overGlob.movFrameMovNumRaw(:,1); %As above, but as a number
            %------
            overGlob.movFrameMovDeltaProp(:,1) = overGlob.movFrameMovDeltaPropRaw(:,1);
            overGlob.movFrameMovCntrNum(:,1) = overGlob.movFrameMovCntrNumRaw(:,1);
            overGlob.movFrameMovCntrAvSize(:,1) = overGlob.movFrameMovCntrAvSizeRaw(:,1);
            %------
            overGlob.dorsMovDeviation(:,1) = zeros( size(overGlob.movFrameRef,1) , 1 );
                %Warning: High likelihood of aberrant zeroes in between holes in data
            %------
            if incProbData == 1
                overGlob.probFrameRef(:,1) = overGlob.probFrameRefRaw(:,1); %Assumption of duality here
                overGlob.probFrameMovNum(:,1) = overGlob.probFrameMovNumRaw(:,1); %Ditto
                overGlob.probFrameMovCntrAvSize(:,1) = overGlob.probFrameMovCntrAvSizeRaw(:,1); %Tritto
            end
            
            %And tethered DLC
            %-------
            %Generalised data synchronisation clone (Mov duplication variant)
                %Note: This version significantly diffes from its other clones insofar as it is vectorised and the acquisition of DLC data is different
            for dataSide = 1:size(dataList,2)
                %rawDataSpec = strcat(dataList{dataSide},'_rawData');
                rawDataSpec = rawSpecs{dataSide};
                if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                    isfield(bigDataStruct,(rawDataSpec)) == 1
                    %overGlob.(strcat(dataList{dataSide},'_FrameRef'))(baseFrameNo,1) = overGlob.movFrameRefRaw(scanTemp(idx,2),2); %Extreme assumption of synchronicity here
                    refSpecData = refSpecs{dataSide};
                    overGlob.(refSpecData)(:,1) = overGlob.movFrameRefRaw(:,2); %Extreme assumption of synchronicity here
                    
                    %QA before pulling DLC data raw from valuesProc
                    temp = 0;
                    for i = 1:size(valuesProc,2)
                        temp = temp + size(valuesProc{i}.(procPartValList{1}),1); %Use first DLC as search for data size
                            %Might crash if no DLC
                    end
                    if temp ~= size(overGlob.movFrameRefRaw,1)
                        ['## Alert: Critical mismatch between valuesProc sizes and MOV reference ##']
                        crash = yes
                    end
                    
                    if incDLC == 1 && contains( dataList{dataSide} , 'DLC' ) == 1
                        dlcDataSpec = dlcSpecs{dataSide};
                        for partIvalX = 1:size(partValList,2)
                            if isfield(valuesProc{1}, procPartValList{partIvalX}) == 1 & isfield(bigDataStruct.(rawDataSpec),partValList{partIvalX}) == 1 %Assumption that all files contain same data types as first
                                overGlob.(dlcDataSpec).(partValList{partIvalX}) = zeros( size(overGlob.movFrameRefRaw,1) , 1 );
                                roll = 0; %Rolling iterator used to keep track of row index
                                for i = 1:size(valuesProc,2)
                                    overGlob.(dlcDataSpec).(partValList{partIvalX})( roll+1:roll+size( valuesProc{i}.(procPartValList{partIvalX}),1 ) ,1) = valuesProc{i}.(procPartValList{partIvalX});
                                    roll = roll + size( valuesProc{i}.(procPartValList{partIvalX}) ,1);
                                end
                            end
                        end
                    end
                                      
                    %Tethered ancillary data (Tether assumption checked above)
                    if contains( dataList{dataSide} , 'DLC' ) ~= 1
                       ancDataSpec = ancDataSpecs{dataSide}; %Use strings catted above
                       for fiel = 1:size( ancFielNames{dataSide} , 1 )
                           overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                    valuesProc{1}.( ancFielNames{dataSide}{fiel} )(stPos);                                                                                   
                       end
                    end
                    
                    %end

                end
            %dataSide end
            end
            %-------
            
            %####
            disp(['-- Reference frame duplicated in ',num2str(toc),'s --'])
            
        else
            
            %('Normal' situation where MOV isn't BASE)
            %Account for instance where dorsal cam started before lateral cam
            initialMovFrameTimePosix = overGlob.movFrameTimeRaw(1);
            initialMovFrameTime = datetime(overGlob.movFrameTimeRaw(1), 'ConvertFrom', 'posixtime');
            %initialMovFrameTime = datetime(strcat(mA,'/',mB,'/',mC,'-', mD,':',mE,':',mF,'.',mG),'Format', 'yy/MM/dd-HH:mm:ss.SSSSSS'); %Deprecated

            %Account for instance where lateral cam ended before dorsal cam
            finalMovFrameTimePosix = overGlob.movFrameTimeRaw(end);
            finalMovFrameTime = datetime(overGlob.movFrameTimeRaw(end), 'ConvertFrom', 'posixtime');
            %finalMovFrameTime = datetime(strcat(mA,'/',mB,'/',mC,'-', mD,':',mE,':',mF,'.',mG),'Format', 'yy/MM/dd-HH:mm:ss.SSSSSS'); %Deprecated

            percDone = 0; %Ticker of completion to stave off despair
            percActual = 0; %The actual completion percentage
            percTime = []; %Timer for ETA purposes
            tic;

            scanInd = 10; %Rolling scan window start point (Hardcoded)
            scanWindowSize = 16; %(Hardcoded)
            for i = 1:size(overGlob.BaseFrameTime,1) 
                percDone = percDone + 1;
                if percDone > 0.1*size(overGlob.BaseFrameTime,1) 
                    percActual = percActual + 0.1;
                    percTime = toc;
                    tic;
                    disp([num2str(percActual*100),'% done matching (ETA: ',num2str((1-percActual)*10*percTime),'s)'])
                    %%['ETA: ',num2str((1-percActual)*10*percTime), ' seconds']
                    percDone = 0;
                end

                %#########
                %Note: Significant assumption of symmetry between SwarmFrames and BaseFrames here (previously DorsFrame)
                %#########
                %globRef.DorsFrameTime(globRef.DorsFrame{i}) = (dorsRawData.Hour(globRef.DorsFrame{i}) / 24) + (dorsRawData.Mins(globRef.DorsFrame{i}) / 60)
                %dorsFrameNo = str2num(overGlob.DorsFrame{i}); %This used because odd conversion of MATLAB strings to floats
                baseFrameNo = i; %Note: This value is not guaranteed consistent with actual rawData frame numbers (previously dorsFrameNo)

                %%%
                if isnan(overGlob.BaseFrameTime(i)) ~= 1 %not NaN data
                    thisBaseFrameTimePosix = overGlob.BaseFrameTime(i);    

                    if thisBaseFrameTimePosix < initialMovFrameTimePosix %If dors precedes mov
                        %%overGlob.movFrameRef(dorsFrameNo,1:2) = [NaN NaN]; 
                        overGlob.movFrameRef(baseFrameNo,1) = NaN;
                        overGlob.movFrameRefID(baseFrameNo,1) = NaN; 
                        overGlob.movFrameTime(baseFrameNo,1) = NaN;
                        %Note: mov frames tethered to dors standard
                        %overGlob.movFrameMov(dorsFrameNo,1) = {NaN}; %This QA removed to allow for more generalised QA later
                        overGlob.movFrameMovNum(baseFrameNo,1) = NaN;
                        %scanInd = dorsFrameNo+scanWindowSize/2; %Brings dorsFrameNo to current time to reduce load on scan window
                        if incProbData == 1
                            overGlob.probFrameRef(baseFrameNo,1) = NaN;
                            overGlob.probFrameRefID(baseFrameNo,1) = NaN; 
                            overGlob.probFrameTime(baseFrameNo,1) = NaN;
                        end
                        %----------------------------------------------------------               
                        %-------
                        %Generalised data synchronisation clone (NaN variant)
                        %Note: May adversely affect program speed
                        for dataSide = 1:size(dataList,2)
                            if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                                isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1 & isempty(strfind(dataList{dataSide}, 'DLC')) ~= 1
                                overGlob.(strcat(dataList{dataSide},'_FrameRef'))(baseFrameNo,1) = NaN;

                                if incDLC == 1  && contains( dataList{dataSide} , 'DLC' ) == 1%&& incAntDLC == 1 %Doubling up on ifs in preparation for future generalisation away from DLC
                                    %-------------------
                                    for partI = 1:size(partList,2) 
                                        for valX = 1:size(valList,2)
                                            if isfield(bigDataStruct.(strcat(dataList{dataSide},'_rawData')), strcat(partList{partI},'_',valList{valX})) == 1
                                                overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{partI},'_',valList{valX}))(baseFrameNo,1) = NaN;
                                            end
                                        end                
                                    end
                                    %-------------------
                                end

                                %Tethered ancillary data (Tether assumption checked above)
                                if contains( dataList{dataSide} , 'DLC' ) ~= 1
                                   ancDataSpec = ancDataSpecs{dataSide}; %Use strings catted above
                                   for fiel = 1:size( ancFielNames{dataSide} , 1 )
                                       try
                                           overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                    NaN;
                                       catch
                                           overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                    {NaN}; %Case for data fields that are cells  
                                       end
                                   end
                                end

                            end
                        end
                        %-------

                    elseif thisBaseFrameTimePosix > finalMovFrameTimePosix %If dors runs after mov
                        %%overGlob.movFrameRef(dorsFrameNo,1:2) = [NaN NaN];
                        overGlob.movFrameRef(baseFrameNo,1) = NaN;
                        overGlob.movFrameRefID(baseFrameNo,1) = NaN;
                        overGlob.movFrameTime(baseFrameNo,1) = NaN;
                        %Note: mov frames tethered to dors standard
                        %overGlob.movFrameMov(dorsFrameNo,1) = {NaN}; %This QA removed to allow for more generalised QA later
                        overGlob.movFrameMovNum(baseFrameNo,1) = NaN;
                        if incProbData == 1
                            overGlob.probFrameRef(baseFrameNo,1) = NaN;
                            overGlob.probFrameRefID(baseFrameNo,1) = NaN; 
                            overGlob.probFrameTime(baseFrameNo,1) = NaN;
                        end

                        %-------
                        %Generalised data synchronisation clone (NaN variant)
                        %Note: May adversely affect program speed
                        for dataSide = 1:size(dataList,2)
                            if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                                isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1 & isempty(strfind(dataList{dataSide}, 'DLC')) ~= 1
                                overGlob.(strcat(dataList{dataSide},'_FrameRef'))(baseFrameNo,1) = NaN;

                                if incDLC == 1  && contains( dataList{dataSide} , 'DLC' ) == 1%&& incAntDLC == 1 %Doubling up on ifs in preparation for future generalisation away from DLC
                                    %-------------------
                                    for partI = 1:size(partList,2) 
                                        for valX = 1:size(valList,2)
                                            if isfield(bigDataStruct.(strcat(dataList{dataSide},'_rawData')), strcat(partList{partI},'_',valList{valX})) == 1
                                                overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{partI},'_',valList{valX}))(baseFrameNo,1) = NaN;
                                            end
                                        end                
                                    end
                                    %-------------------
                                end

                                %Tethered ancillary data (Tether assumption checked above)
                                if contains( dataList{dataSide} , 'DLC' ) ~= 1
                                   ancDataSpec = ancDataSpecs{dataSide}; %Use strings catted above
                                   for fiel = 1:size( ancFielNames{dataSide} , 1 )
                                       try
                                           overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                    NaN;
                                       catch
                                           overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                    {NaN}; %Case for data fields that are cells  
                                       end
                                   end
                                end

                            end
                        end
                        %-------

                    else
                        %try
                            scanTemp = [];
                            if scanInd + scanWindowSize/2 <= size(overGlob.movFrameTimeRaw,1)
                                b = 1;
                                for x = scanInd - scanWindowSize/2:scanInd + scanWindowSize/2
                                    %Note: Current technique extremely susceptible to too-small scanWindow abberations
                                    %tic
                                    thisMovFrameTimePosix = overGlob.movFrameTimeRaw(x);
                                    %datetime(thisMovFrameTimePosix, 'ConvertFrom', 'posixtime')
                                    %%thisMovFrameTime = datetime(strcat(mA,'/',mB,'/',mC,'-', mD,':',mE,':',mF,'.',mG),'Format', 'yy/MM/dd-HH:mm:ss.SSSSSS');
                                    %toc
                                    %%scanTemp(b,1) = abs(posixtime(thisDorsFrameTime) - posixtime(thisMovFrameTime)); %Difference
                                    scanTemp(b,1) = abs(thisBaseFrameTimePosix - thisMovFrameTimePosix); %Difference
                                    scanTemp(b,2) = x; %movFrame index
                                    scanTemp(b,3) = baseFrameNo; %dorsFrame index
                                    scanTemp(b,4) = thisMovFrameTimePosix; %movFrame unix time

                                    b = b + 1;
                                end

                                [val,idx] = min(scanTemp(:,1)); %Gives us the movFrame index of the movFrameTime that is closest
                                                                %to the current dorsFrameTime
                                scanInd = scanTemp(idx,2)+scanWindowSize/2; %CRITICAL TO NOT GETTING LEFT BEHIND
                                %%overGlob.movFrameRef(dorsFrameNo,1:2) = overGlob.movFrameRefRaw(scanTemp(idx,2),1:2); %Original mov frame number, plus video number
                                overGlob.movFrameRef(baseFrameNo,1) = overGlob.movFrameRefRaw(scanTemp(idx,2),1); %Original mov frame number, plus video number
                                overGlob.movFrameRefID(baseFrameNo,1) = overGlob.movFrameRefRaw(scanTemp(idx,2),2);
                                overGlob.movFrameTime(baseFrameNo,1) = scanTemp(idx,4); %Posix time of mov frame
                                overGlob.movFrameMov{baseFrameNo,1} = overGlob.movFrameMovRaw{scanTemp(idx,2)}; %Whether mov frame had detected movement
                                overGlob.movFrameMovNum(baseFrameNo,1) = overGlob.movFrameMovNumRaw(scanTemp(idx,2)); %As above, but as a number
                                %------
                                overGlob.movFrameMovDeltaProp(baseFrameNo,1) = overGlob.movFrameMovDeltaPropRaw(scanTemp(idx,2));
                                overGlob.movFrameMovCntrNum(baseFrameNo,1) = overGlob.movFrameMovCntrNumRaw(scanTemp(idx,2));
                                overGlob.movFrameMovCntrAvSize(baseFrameNo,1) = overGlob.movFrameMovCntrAvSizeRaw(scanTemp(idx,2));
                                %------
                                overGlob.dorsMovDeviation(baseFrameNo,1) = scanTemp(idx,1);
                                    %Warning: High likelihood of aberrant zeroes in between holes in data
                                %------
                                if incProbData == 1
                                    overGlob.probFrameRef(baseFrameNo,1) = overGlob.probFrameRefRaw(scanTemp(idx,2),1); %Assumption of duality here
                                    overGlob.probFrameMovNum(baseFrameNo,1) = overGlob.probFrameMovNumRaw(scanTemp(idx,2)); %Ditto
                                    overGlob.probFrameMovCntrAvSize(baseFrameNo,1) = overGlob.probFrameMovCntrAvSizeRaw(scanTemp(idx,2)); %Tritto
                                end

                                %-------
                                %Generalised data synchronisation clone (Data variant)
                                %"Gotta Go Fast" (i.e. minimal strcat) [Now even more minimal]
                                for dataSide = 1:size(dataList,2)
                                    %rawDataSpec = strcat(dataList{dataSide},'_rawData');
                                    rawDataSpec = rawSpecs{dataSide};
                                    if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                                        isfield(bigDataStruct,(rawDataSpec)) == 1
                                        %overGlob.(strcat(dataList{dataSide},'_FrameRef'))(baseFrameNo,1) = overGlob.movFrameRefRaw(scanTemp(idx,2),2); %Extreme assumption of synchronicity here
                                        refSpecData = refSpecs{dataSide};
                                        overGlob.(refSpecData)(baseFrameNo,1) = overGlob.movFrameRefRaw(scanTemp(idx,2),2); %Extreme assumption of synchronicity here

                                        stPos = overGlob.movFrameRefRaw(scanTemp(idx,2),1); %The relative position within the video of the (tethered) frame
                                        stVid = overGlob.movFrameRefRaw(scanTemp(idx,2),2); %The video number

                                        if incDLC == 1 && contains( dataList{dataSide} , 'DLC' ) == 1 %&& incAntDLC == 1 %Doubling up on ifs in preparation for future generalisation away from DLC
                                            %dlcDataSpec = strcat(dataList{dataSide},'_dlcData');
                                            dlcDataSpec = dlcSpecs{dataSide};
                                            %stPos = overGlob.movFrameRefRaw(scanTemp(idx,2),1); %The relative position within the video of the (tethered) frame
                                            %stVid = overGlob.movFrameRefRaw(scanTemp(idx,2),2); %The video number
                                            %-------------------
                                            for partIvalX = 1:size(partValList,2)
                                                if isfield(valuesProc{stVid}, procPartValList{partIvalX}) == 1 & isfield(bigDataStruct.(rawDataSpec),partValList{partIvalX}) == 1
                                                    overGlob.(dlcDataSpec).(partValList{partIvalX})(baseFrameNo,1) = ...
                                                        valuesProc{stVid}.(procPartValList{partIvalX})(stPos);
                                                        %This works by selecting the correct cell of valuesProc and the correct row and assigning that to baseFrameNo row

                                                    %reference to valuesProc wrong here?
                                                    %    partList is DLC specific
                                                    %   non dlc data does not exist in valuesProc?

                                                end
                                            end
                                            %This portion assumes *perfect* synchronicity between DLC and tethered mov files (and also no funny business with valuesProc indexing).
                                            %It uses the mov frameRef to find what index to pull data at from valuesProc.
                                            %A safer implementation would be to natively include the DLC data in overGlob, but that would
                                            %needlessly double the size of an already giant structure.
                                            %-------------------
                                        end

                                        %Tethered ancillary data (Tether assumption checked above)
                                        if contains( dataList{dataSide} , 'DLC' ) ~= 1
                                           ancDataSpec = ancDataSpecs{dataSide}; %Use strings catted above
                                           for fiel = 1:size( ancFielNames{dataSide} , 1 )
                                               overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                        valuesProc{stVid}.( ancFielNames{dataSide}{fiel} )(stPos);                                                                                   
                                           end
                                        end

                                    end
                                %dataSide end
                                end
                                %-------

                            else
                            %catch %Note: This may open up code to unbeknowst suppressed data errors
                                %scanInd = scanTemp(idx,2)+scanWindowSize/2; %CRITICAL TO NOT GETTING LEFT BEHIND
                                %%overGlob.movFrameRef(dorsFrameNo,1:2) = [NaN NaN];
                                overGlob.movFrameRef(baseFrameNo,1) = NaN;
                                overGlob.movFrameRefID(baseFrameNo,1) = NaN;
                                overGlob.movFrameTime(baseFrameNo,1) = NaN; 
                                %overGlob.movFrameMov{dorsFrameNo,1} = NaN; %Not fixed here for later QA purposes
                                overGlob.movFrameMovNum(baseFrameNo,1) = NaN;
                                %------
                                overGlob.movFrameMovDeltaProp(baseFrameNo,1) = NaN;
                                overGlob.movFrameMovCntrNum(baseFrameNo,1) = NaN;
                                overGlob.movFrameMovCntrAvSize(baseFrameNo,1) = NaN;
                                %------
                                overGlob.dorsMovDeviation(baseFrameNo,1) = NaN;
                                    %Note: If lat-cam ended before dors-cam this variable set may be naturally truncated compared to dors-cam
                                %------
                                if incProbData == 1
                                    overGlob.probFrameRef(baseFrameNo,1) = NaN;
                                    overGlob.probFrameMovNum(baseFrameNo,1) = NaN;
                                    overGlob.probFrameMovCntrAvSize(baseFrameNo,1) = NaN;
                                end

                                %-------
                                %Generalised data synchronisation clone (NaN variant)
                                %Note: May adversely affect program speed
                                for dataSide = 1:size(dataList,2)
                                    if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                                        isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1 & isempty(strfind(dataList{dataSide}, 'DLC')) ~= 1
                                        overGlob.(strcat(dataList{dataSide},'_FrameRef'))(baseFrameNo,1) = NaN;

                                        if incDLC == 1  && contains( dataList{dataSide} , 'DLC' ) == 1%&& incAntDLC == 1 %Doubling up on ifs in preparation for future generalisation away from DLC
                                            %-------------------
                                            for partI = 1:size(partList,2) 
                                                for valX = 1:size(valList,2)
                                                    if isfield(bigDataStruct.(strcat(dataList{dataSide},'_rawData')), strcat(partList{partI},'_',valList{valX})) == 1
                                                        overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{partI},'_',valList{valX}))(baseFrameNo,1) = NaN;
                                                    end
                                                end                
                                            end
                                            %-------------------
                                        end

                                        %Tethered ancillary data (Tether assumption checked above)
                                        if contains( dataList{dataSide} , 'DLC' ) ~= 1
                                           ancDataSpec = ancDataSpecs{dataSide}; %Use strings catted above
                                           for fiel = 1:size( ancFielNames{dataSide} , 1 )
                                               try
                                                   overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                            NaN;
                                               catch
                                                   overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                            {NaN}; %Case for data fields that are cells  
                                               end
                                           end
                                        end

                                    end
                                end
                                %-------
                        %end
                            %scanInd overrun catcher end
                            end
                    %posixtime end    
                    end
                else %is NaN data because truncation
                    %%overGlob.movFrameRef(dorsFrameNo,1:2) = [NaN NaN];
                    overGlob.movFrameRef(baseFrameNo,1) = NaN;
                    overGlob.movFrameRefID(baseFrameNo,1) = NaN;
                    overGlob.movFrameTime(baseFrameNo,1) = NaN;
                    overGlob.movFrameMovNum(baseFrameNo,1) = NaN;
                    %------
                    overGlob.movFrameTime(baseFrameNo,1) = NaN; 
                    overGlob.movFrameMovNum(baseFrameNo,1) = NaN;
                    %------
                    overGlob.movFrameMovDeltaProp(baseFrameNo,1) = NaN;
                    overGlob.movFrameMovCntrNum(baseFrameNo,1) = NaN;
                    overGlob.movFrameMovCntrAvSize(baseFrameNo,1) = NaN;
                    %------
                    overGlob.dorsMovDeviation(baseFrameNo,1) = NaN;
                    %------
                    if incProbData == 1
                        overGlob.probFrameRef(baseFrameNo,1) = NaN;
                        overGlob.probFrameMovNum(baseFrameNo,1) = NaN;
                        overGlob.probFrameMovCntrAvSize(baseFrameNo,1) = NaN;
                    end

                    %-------
                    %Generalised data synchronisation clone (NaN variant)
                    %Note: May adversely affect program speed
                    for dataSide = 1:size(dataList,2)
                        if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                            isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1 & isempty(strfind(dataList{dataSide}, 'DLC')) ~= 1
                            overGlob.(strcat(dataList{dataSide},'_FrameRef'))(baseFrameNo,1) = NaN;

                            if incDLC == 1  && contains( dataList{dataSide} , 'DLC' ) == 1%&& incAntDLC == 1 %Doubling up on ifs in preparation for future generalisation away from DLC
                                %-------------------
                                for partI = 1:size(partList,2) 
                                    for valX = 1:size(valList,2)
                                        if isfield(bigDataStruct.(strcat(dataList{dataSide},'_rawData')), strcat(partList{partI},'_',valList{valX})) == 1
                                            overGlob.(strcat(dataList{dataSide},'_dlcData')).(strcat(partList{partI},'_',valList{valX}))(baseFrameNo,1) = NaN;
                                        end
                                    end                
                                end
                                %-------------------
                            end

                            %Tethered ancillary data (Tether assumption checked above)
                            if contains( dataList{dataSide} , 'DLC' ) ~= 1
                               ancDataSpec = ancDataSpecs{dataSide}; %Use strings catted above
                               for fiel = 1:size( ancFielNames{dataSide} , 1 )
                                   try
                                       overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                NaN;
                                   catch
                                       overGlob.(ancDataSpec).( ancFielNames{dataSide}{fiel} )(baseFrameNo,1) = ...
                                                {NaN}; %Case for data fields that are cells  
                                   end
                               end
                            end

                        end
                    end
                    %-------

                %isnan end    
                end
                %%%
            %dorsFrame matching end
            end
        
        end
        
        ['-- Done matching mov data --']

        %Mov-Dors frame asynchrony QA and fixing
        if size(overGlob.movFrameRef,1) ~= size(overGlob.BaseFrameRef,1)
            ['## Alert: Critical asynchrony between mov and dors ##']
            error = yes
        end
        movFrameRefNanIdx = (isnan(overGlob.movFrameRef) == 1);
        %------
        overGlob.movFrameMovDeltaProp(movFrameRefNanIdx,1) = NaN;
        overGlob.movFrameMovCntrNum(movFrameRefNanIdx,1) = NaN;
        overGlob.movFrameMovCntrAvSize(movFrameRefNanIdx,1) = NaN;
        %------
        overGlob.dorsMovDeviation(movFrameRefNanIdx,1) = NaN;
            %Warning: High likelihood of aberrant zeroes in between holes in data
        %------
        if incProbData == 1
            overGlob.probFrameRef(movFrameRefNanIdx,1) = NaN; %Assumption of duality here
            overGlob.probFrameMovNum(movFrameRefNanIdx,1) = NaN; %Ditto
            overGlob.probFrameMovCntrAvSize(movFrameRefNanIdx,1) = NaN; %Tritto
        end


        %Nanify mov-tethered ancillary data to bring in line with mov data
        for dataSide = 1:size(dataList,2)
            if isempty(strfind(dataList{dataSide}, 'MOV')) == 1 && isempty(strfind(tetherList{dataSide},'MOV')) ~= 1 & ...
                    isfield(bigDataStruct,(strcat(dataList{dataSide},'_rawData'))) == 1 && contains( dataList{dataSide}, 'DLC' ) == 1
                rawDataColFields = bigDataStruct.(dataList{dataSide}).columnFields;
                %sourceColField = bigDataStruct.DORS.columnFields{1};
                for colField = 1:size(rawDataColFields,2)
                    overGlob.(strcat(dataList{dataSide},'_dlcData')).(rawDataColFields{colField})(isnan(overGlob.movFrameRef) == 1) = NaN;
                        %Uses first column of DORS (that was fixed just now) as index to Nanify ancillary data at same points
                end
            end
        end

        %End block run point
        
        %Apply ZOH to DLC data that is sub-likeliness
        if incDLC == 1 && doDLCZOH == 1
            overGlob.dlcLikelinessZOH = struct;
            overGlob.dlcLikelinessZOH.applied = 1;
            overGlob.dlcLikelinessZOH.threshold = likelinessThresh;
            overGlob.dlcLikelinessZOH.list = [];
            a = 1;
            figure %Testatory
            for dataSide = 1:size(dataList,2)
                if isempty( strfind( dataList{dataSide} , 'DLC' ) ) ~= 1 && isfield( overGlob , [dataList{dataSide},'_dlcData'] ) == 1
                    dlcFiels = fieldnames( overGlob.([dataList{dataSide},'_dlcData']) );
                    for partI = 1:size(partList,2)
                        thisPart = partList{partI};
                        if nansum( contains(dlcFiels,partList{partI}) ) > 0 && isempty( overGlob.([dataList{dataSide},'_dlcData']).( strcat(thisPart,'_likelihood') ) ) ~= 1 %"This dataSide contains this part"
                            tic
                            %thisPart = partList{partI};
                            thisLikely = overGlob.([dataList{dataSide},'_dlcData']).( strcat(thisPart,'_likelihood') ); %Will crash if likelihood does not exist (For some reason)
                            for valI = 1:size(valList,2)
                                if contains( valList{valI} , 'likelihood' ) ~= 1
                                    temp = overGlob.([dataList{dataSide},'_dlcData']).( strcat(thisPart,'_',valList{valI}) ); 
                                    
                                    %New, bwlabel based system
                                    tempLower = temp;
                                    tempLower( thisLikely > likelinessThresh ) = 0; %CAREFUL: Note inversion compared to usual
                                        %Note: Coords could be calculated above, to save having to redo for both X/Y, but it wouldn't save much time
                                    %blirgLower( isnan(blirgLower) == 1 ) = 0;
                                    tempLabel = bwlabel(tempLower); %"All cases where likelihood < likelinessThresh"
                                    for i = 1:nanmax(tempLabel)
                                        try
                                            temp( tempLabel == i ) = temp( find( tempLabel == i , 1, 'first')-1 ); %Hold data immediately prior to sub-likelihood
                                        catch %Most likely if first frame sub-likelihood
                                            temp( tempLabel == i ) = 0;
                                        end
                                    end
                                    %Overwrite data with new copy 
                                    overGlob.([dataList{dataSide},'_dlcData']).( strcat(thisPart,'_',valList{valI}) ) = temp;
                                end
                            end
                            disp([thisPart,' likeliness processed in ',num2str(toc),'s'])
                            try
                                subplot( size(partList,2) , 1 , a )
                                h = histogram( thisLikely, 128 );
                                ylim([ 0 , nanmax( h.Values( h.BinEdges < likelinessThresh ) )*1.1 ])
                                title(thisPart)
                            catch
                                ['#- Failure to plot likeliness for ',thisPart,' -#']
                            end
                            overGlob.dlcLikelinessZOH.list{a} = thisPart;
                            a = a + 1;
                        end
                    end
                end
            end
            set(gcf,'Name', [flyName, ' likeliness ZOH hist'])
        end

        %-------------------------------

        %Activity binning code
            %Probably analytically deprecated
        %Separate active and inactive times
        %Find average of matched average contour size data (technique probably improvable)
        separationMode = [];
        if dlcActivitySeparation == 1 & incDLC == 1 & isfield( overGlob, 'DLC_SIDE_dlcData' ) == 1 %& isfield( overGlob.DLC_SIDE_dlcData, dlcAcLimb ) == 1 %Final boolean not (easily) functional with hyp
            disp(['-- Using DLC data (',dlcAcLimb,') for activity/inactivity separation --'])
            if dlcHyp ~= 1
                acDiffData = abs(diff(overGlob.DLC_SIDE_dlcData.([dlcAcLimb,'_x'])));
            else
                temp = [ abs(diff(overGlob.DLC_SIDE_dlcData.(strcat(dlcAcLimb,'_x')))).^2 + ...
                    abs(diff(overGlob.DLC_SIDE_dlcData.(strcat(dlcAcLimb,'_y')))).^2 ];
                temp = sqrt( temp );
                %temp = [0 ; temp];
                acDiffData = temp;
                %QA for architecture
                    %Disabled, because architecture failure is larger problem than expected
                %{
                if size( acDiffData , 1 ) == 1 && size( acDiffData , 2 ) > 1
                    disp(['-# acDiffData architecture incorrect; Fixing #-'])
                    acDiffData = acDiffData';
                elseif size( acDiffData , 1 ) > 1 && size( acDiffData , 2 ) > 1
                    ['## Alert: acDiffData possess unknown architecture ##']
                    crash = yes
                end
                %}
            end
            acMean = nanmean( acDiffData );
            acSTD = nanstd( acDiffData );
            acUpper = [0;acDiffData]; %Correcting diff nature
            acRaw = acUpper; %Copy of tempUpper before lower portion subtracted
            %tempUpper( tempUpper < acMean + dlcAcSDCount*acSTD) = NaN;
            acUpper( acUpper < acMean + acSDCount*acSTD) = NaN;
            separationMode = 'DLC';
        else
            disp(['-- Using pixel detection contours for activity/inactivity separation --'])
            trueAv = nanmean(overGlob.movFrameMovCntrAvSize); %Base mean of average contour size across whole experiment (Note: movFrameMovCntrAvSize is matched)
            acCntrs = overGlob.movFrameMovCntrAvSize;
            adjAv = nanmean(acCntrs(overGlob.movFrameMovCntrAvSize > trueAv)); %Adjusted average from average contour size data where <mean data was removed
            acDiffData = acCntrs;
            
            %Separate fractions of contour size data
            acUpper = acCntrs;
            acRaw = acUpper;
            acUpper(acCntrs < adjAv) = NaN;
            %tempLower = tempCntrs;
            %tempLower(tempCntrs > adjAv) = NaN;
            separationMode = 'contours';
        end
        
        %Form structure
        inStruct = struct; %Structure for eventually holding activity/inactivity intervals, indexes, etc
        inStruct.separationMode = separationMode;
        
        %Iterate along activity portions to map inactivity 'holes'
        %Note: Current method susceptible to being thrown by single-unit spikes of activity (i.e. 10 minutes with 1 single spike in middle -> 2 x 5 mins)
        %Quick QA
        if size(acUpper,1) ~= size(overGlob.BaseFrameTime,1)
            ['## ALERT: ASYNCHRONY EXISTS BETWEEN MATCHED MOV DATA AND DORS DATA ##']
            error = yes
        end

        %Quickly calculate approximate data framerate
        BaseFrameRate = 1 / nanmedian( diff( overGlob.BaseFrameTime ) );
        %QA
        temp = nanstd( diff( overGlob.BaseFrameTime ) );
        if temp > 0.05*BaseFrameRate
            ['-# Warning: Potential large variation in data framerate detected #-']
        end
        
        %Initialise (Prevents later portions from crashing if no holes)
        inStruct.holeStarts = [];
        inStruct.holeEnds = [];
        inStruct.holeSizes = [];
        inStruct.holeRanges = [];
        inStruct.holeStartsTimes = [];
        inStruct.holeEndsTimes = [];
        inStruct.holeSizesSeconds = [];
        inStruct.holeRangesBaseFrameMatched = [];
        inStruct.holeRangesMovFrameMatched = [];
        
        
        ['-- Beginning activity/inactivity separation calculations --']
        %New, BWLabel based method
        minActivityTime = minAcTime * BaseFrameRate;
        tic
        tempUpperBinary = isnan( acUpper ) ~= 1;
        tempUpperBW = bwlabel( tempUpperBinary );
        invTempUpperBW = bwlabel(~tempUpperBinary);
        for i = 1:nanmax(unique(tempUpperBW))
            thisLastCoord = find( tempUpperBW == i , 1 , 'last' );
            if nansum( invTempUpperBW == (i + 1) ) > minActivityTime %Effectively ligates all activity blocks separated by < minActivityTime
                %tempUpperBW( invTempUpperBW == (i + 1) ) = i;
                tempUpperBW( tempUpperBW == i ) = 0;
            %else
            %    tempUpperBW( tempUpperBW == i ) = 0;
            end
        end
        tempUpperBinary = tempUpperBW ~= 0; %Recalculate binary ac/inac
        tempUpperBW = bwlabel( tempUpperBinary );
        invTempUpperBW = bwlabel(~tempUpperBinary);  
        
        a = 1;
        for i = 1:nanmax(unique( invTempUpperBW )) 
            if nansum( invTempUpperBW == i ) > 300*BaseFrameRate
                currentHoleStart = find( invTempUpperBW == i , 1 ,'first' );
                currentHoleEnd = find( invTempUpperBW == i , 1 ,'last' );
                %disp([num2str(i)])
                inStruct.holeStarts(a) = currentHoleStart; %Save memory of hole starting location to struct
                inStruct.holeEnds(a) = currentHoleEnd; %Save hole ending location to struct
                inStruct.holeSizes(a) = currentHoleEnd - currentHoleStart + 1; %Ditto, for hole size
                inStruct.holeRanges{a} = [currentHoleStart:currentHoleEnd]; %Save X coords of hole (based on matched mov-centric coordinate space)
                inStruct.holeStartsTimes{a} = datestr(datetime(overGlob.BaseFrameTime(currentHoleStart), 'ConvertFrom', 'posixtime')); %If crashes, probs because asynchrony
                inStruct.holeEndsTimes{a} = datestr(datetime(overGlob.BaseFrameTime(currentHoleEnd), 'ConvertFrom', 'posixtime')); %If crashes, probs because asynchrony
                inStruct.holeSizesSeconds(a) = overGlob.BaseFrameTime(currentHoleEnd) - overGlob.BaseFrameTime(currentHoleStart); %Duration of hole in seconds (theoretically)
                inStruct.holeRangesBaseFrameMatched{a} = overGlob.BaseFrameRef(inStruct.holeRanges{a},:); %(Theoretically) Matched dors vid frames with hole range (to account for holes across vid junctions)
                inStruct.holeRangesMovFrameMatched{a} = [overGlob.movFrameRef(inStruct.holeRanges{a},:) overGlob.movFrameRefID(inStruct.holeRanges{a},:)]; %(Theoretically) Matched mov vid frames with hole range (to account for holes across vid junctions) - 2 cols
                    %Note: Will have to figure out how to maintain framerate synchronicity betweeen dors and mov vids
                    %Also note: High suspicion mov vid tracking will be lost if a junction is crossed, due to current probable matching inadequacies
                a = a + 1;
            end
        end        
        toc
        
        %Old method
        %{
        tic
        a = 1; %Iterator
        intSize = 0; %Running size of current hole
        currentHoleStart = 0; %Memory of [Earth] starting position of current hole, for later ID purposes
        currentlyHole = 0; %Whether a hole is being mapped currently
        for i = 1:size(tempUpper,1)
            forwardCoords = [i: i + floor( minAcTime * BaseFrameRate )];
            forwardCoords( forwardCoords > size(tempUpper,1) ) = [];%May crash at end              
            if isnan(tempUpper(i)) ~= 1 && currentlyHole == 0 %Activity occurring, not mapping -> Continue not mapping
                intSize = 0;
                currentlyHole = 0; %Do nothing, effectively
                currentHoleStart = 0;
            elseif isnan(tempUpper(i)) ~= 1 && currentlyHole == 1 && nansum( isnan( tempUpper(forwardCoords) ) ~= 1 ) > 0.5*minAcTime*BaseFrameRate %Activity occurring, was mapping -> Cease mapping
                if intSize > inactDur %Only save if hole larger than threshold
                    inStruct.holeStarts(a) = currentHoleStart; %Save memory of hole starting location to struct
                    inStruct.holeEnds(a) = i-1; %Save hole ending location to struct
                    inStruct.holeSizes(a) = intSize; %Ditto, for hole size
                    inStruct.holeRanges{a} = [currentHoleStart:i-1]; %Save X coords of hole (based on matched mov-centric coordinate space)
                    inStruct.holeStartsTimes{a} = datestr(datetime(overGlob.BaseFrameTime(currentHoleStart), 'ConvertFrom', 'posixtime')); %If crashes, probs because asynchrony
                    inStruct.holeEndsTimes{a} = datestr(datetime(overGlob.BaseFrameTime(i-1), 'ConvertFrom', 'posixtime')); %If crashes, probs because asynchrony
                    inStruct.holeSizesSeconds(a) = overGlob.BaseFrameTime(i) - overGlob.BaseFrameTime(currentHoleStart); %Duration of hole in seconds (theoretically)
                    inStruct.holeRangesBaseFrameMatched{a} = overGlob.BaseFrameRef(inStruct.holeRanges{a},:); %(Theoretically) Matched dors vid frames with hole range (to account for holes across vid junctions)
                    %%inStruct.holeRangesMovFrameMatched{a} = overGlob.movFrameRef(inStruct.holeRanges{a},:); %(Theoretically) Matched mov vid frames with hole range (to account for holes across vid junctions) - 1 column
                    inStruct.holeRangesMovFrameMatched{a} = [overGlob.movFrameRef(inStruct.holeRanges{a},:) overGlob.movFrameRefID(inStruct.holeRanges{a},:)]; %(Theoretically) Matched mov vid frames with hole range (to account for holes across vid junctions) - 2 cols
                        %Note: Will have to figure out how to maintain framerate synchronicity betweeen dors and mov vids
                        %Also note: High suspicion mov vid tracking will be lost if a junction is crossed, due to current probable matching inadequacies
                    a = a + 1;
                end
                intSize = 0; %Reset
                currentHoleStart = 0; %Reset
                currentlyHole = 0; %Reset
            elseif isnan(tempUpper(i)) == 1 && currentlyHole == 0 %Hole occurring, wasn't mapping -> Begin mapping
                currentlyHole = 1;
                currentHoleStart = i; %Save memory of hole starting location
                intSize = intSize + 1; %Increase size to 1
            elseif isnan(tempUpper(i)) == 1 && currentlyHole == 1 %Hole occurring, is mapping -> Continue mapping
                intSize = intSize + 1; %Increase size by 1
                currentlyHole = 1; %Continue on mapping
            end
        end
        toc
        %}
        ['-- ', num2str(a-1), ' holes found in activity data, according to specified threshold --']
                
        %Reporter figure
        try
            tickCoords = overGlob.BaseFrameTime - overGlob.BaseFrameTime(1);
            %QA
            if size( tickCoords,1 ) == size( acDiffData , 1 ) + 1 %acDiff is shorter by 1 because diff
                tickCoords = tickCoords(2:end);
            elseif abs( size( tickCoords,1 ) - size( acDiffData , 1 ) ) > 0.05*size( acDiffData , 1 )
                ['## Alert: Significant difference in BASE and activity data lengths ##']
            end 
            figure
            hold on
            %plot( acDiffData )
            %plot( tickCoords(2:end), acDiffData )
            plot( tickCoords, acDiffData )
            %plot( tempUpper )
            if size( acUpper,1 ) == size( acDiffData,1 )
                plot( tickCoords, acUpper )
            elseif size( acUpper,1 ) == size( acDiffData,1 ) + 1
                plot( tickCoords, acUpper(1:end-1) )
            end
            yLims = get(gca,'YLim');
            for boutInd = 1:size( inStruct.holeStarts,2 )
                %line( [ inStruct.holeStarts(boutInd) , inStruct.holeStarts(boutInd) ] , [ 0 , nanmax(yLims) ], 'LineStyle', '--', 'Color', 'k' )
                %line( [ inStruct.holeEnds(boutInd) , inStruct.holeEnds(boutInd) ] , [ 0 , nanmax(yLims) ], 'LineStyle', '--', 'Color', 'r' )
                %line( [ inStruct.holeStarts(boutInd) , inStruct.holeEnds(boutInd) ] , [ nanmax(yLims)*0.95 , nanmax(yLims)*0.95 ], 'LineStyle', ':', 'Color', 'b' )
                line( [ tickCoords( inStruct.holeStarts(boutInd) ) , tickCoords( inStruct.holeStarts(boutInd) ) ] , [ 0 , nanmax(yLims) ], 'LineStyle', '--', 'Color', 'k' )
                line( [ tickCoords( inStruct.holeEnds(boutInd) ) , tickCoords( inStruct.holeEnds(boutInd) ) ] , [ 0 , nanmax(yLims) ], 'LineStyle', '--', 'Color', 'r' )
                line( [ tickCoords( inStruct.holeStarts(boutInd) ) , tickCoords( inStruct.holeEnds(boutInd) ) ] , [ nanmax(yLims)*0.95 , nanmax(yLims)*0.95 ], 'LineStyle', ':', 'Color', 'b' )
            end
            vidBoundaries = find( diff( overGlob.BaseFrameRef(:,1) ) < 0 );
            for boundInd = 1:size( vidBoundaries,1 )
                %line( [ vidBoundaries(boundInd) , vidBoundaries(boundInd) ] , [ 0 , nanmax(yLims) ], 'LineStyle', ':', 'Color', 'k' )
                line( [ tickCoords( vidBoundaries(boundInd) ) , tickCoords( vidBoundaries(boundInd) ) ] , [ 0 , nanmax(yLims) ], 'LineStyle', ':', 'Color', 'k' )
            end
            xlim([0,nanmax(tickCoords)])
            try
                xTimesProc = overGlob.firstBaseFrameTimeTimeDate; %Legacy data
            catch
                xTimesProc = overGlob.firstBaseFrameTimeTimeDate; %Modern data
            end
            for i = 1:size(xTimesProc,1)
                xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
            end
            xticks( [overGlob.firstBaseFrameTimeTime - overGlob.BaseFrameTime(1)] )
            xticklabels( [xTimesProc] )
            xlabel(['Time (ZT)'])
            titleStr = [dataFolderList{fol}, ' - activity/inactivity separation (Min ac. time: ',num2str(minAcTime),'s)'];
            if dlcActivitySeparation == 1 & incDLC == 1 & isfield( overGlob, 'DLC_SIDE_dlcData' ) == 1
                titleStr = [titleStr,'(DLC separation)'];
            else
                titleStr = [titleStr,'(MOV separation)'];
            end
            title(titleStr) 
            set(gcf,'Name',['AcInac separation - ', flyName])
            %Save
            if saveFigs == 1
                %saveName = strcat(figPath,'\',flyName,'_AcInacSeparation','.png');
                saveName = strcat(figPath,'\',flyName, specialParam, '_AcInacSeparation','.png');
                %Plot preparation
                set(gcf, 'Color', 'w');
                set(gcf,'units','normalized','outerposition',[0 0 1 1])
                %export_fig(saveName)
                saveas(gcf,saveName,'png')
            end
        catch
            ['## Warning: Failure to plot ac/inac plot ##']
        end
        
        %Save some (more) variables to overGlob
        overGlob.acRaw = acRaw;
        
        %QA warning/s
        %{
        if size(overGlob.rightThetaProc,1) ~= size(overGlob.movFrameMovNumBinned,1)
            ['## WARNING: ANTENNAL ANGLE DATA TIMING MAY BE INCORRECT BY AS MUCH AS ',num2str(abs(size(overGlob.rightThetaProc,1) - size(overGlob.movFrameMovNumBinned,1))), ' FRAMES ##']
        end
        %}
        if skippedFiles ~= 0
            ['## Warning: ', num2str(skippedFiles), ' file/s had to be skipped ##']
                %Note: Since this is probably only enacted for terminal files, it can only ever report a value of 1 here
        end

        %-----------------------

        %Data processing

        ['-- Initialising data processing suite --']
        if incDorsData == 1

            %%tic

            %Bootleg divergence
            %'Why calculate correlation when you can calculate divergence instead'
            righT = overGlob.rightThetaProc; %Raw copy of right theta processed data
            lefT = overGlob.leftThetaProc; %Ditto, left

            rightTWindowAv = []; %Rolling right theta average
            leftTWindowAv = []; %Ditto, left
            righTDiver = []; 
            lefTDiver = [];

            combDiver = []; %Divergence between right and left theta divergence values
                %Note: This is in SDs. So, a 'good' divergence (0) might be 0.4 SDs for right minus 0.5 SDs for left
                %Secondary note: The signing on this is currently pretty poor

            percDone = 0.0;    
            %%intDone = 0;
            %tic
            for i = 1:diverWindow:size(righT,1)
                %{
                intDone = intDone + i;
                if intDone >= size(righT,1) * 0.1
                    error = yes
                    intDone = -intDone;
                    percDone = i/size(righT,1);
                    ['- ',num2str(percDone*100) , '% completed bootleg divergence processing (ETA: ', num2str(toc*(1-percDone)*10),'s) -']
                    ['- ETA: ', num2str(toc*(1-percDone)*10),' -']
                %%tic
                end
                %}
                windowLowBound = i;
                if i >= size(righT,1) - diverWindow 
                    windowHighBound = size(righT,1);
                else
                    windowHighBound = i + diverWindow;
                end

                righTWindowAv = nanmean(righT(windowLowBound:windowHighBound)); %Average right theta angle in window (degrees)
                lefTWindowAv = nanmean(lefT(windowLowBound:windowHighBound));
                righTWindowSD = nanstd(righT(windowLowBound:windowHighBound)); %As above but SD
                lefTWindowSD = nanstd(lefT(windowLowBound:windowHighBound));
                relTemp = (righT(windowLowBound:windowHighBound) - repmat(righTWindowAv,[size(righT(windowLowBound:windowHighBound)),1]))/repmat(righTWindowSD,[size(righT(windowLowBound:windowHighBound)),1]);
                    %Calculate per-row difference from average, then divide by SD
                %%righTWindowRel = (righT(windowLowBound:windowHighBound) - repmat(righTWindowAv,[size(righT(windowLowBound:windowHighBound)),1]))/repmat(righTWindowSD,[size(righT(windowLowBound:windowHighBound)),1]);
                righTWindowRel = relTemp(:,1);
                %%lefTWindowRel = (lefT(windowLowBound:windowHighBound) - repmat(lefTWindowAv,[size(lefT(windowLowBound:windowHighBound)),1]))/repmat(lefTWindowSD,[size(lefT(windowLowBound:windowHighBound)),1]);
                relTemp = (lefT(windowLowBound:windowHighBound) - repmat(lefTWindowAv,[size(lefT(windowLowBound:windowHighBound)),1]))/repmat(lefTWindowSD,[size(lefT(windowLowBound:windowHighBound)),1]);
                    %As above
                lefTWindowRel = relTemp(:,1);
                %%righTWindowRel = righT(windowLowBound:windowHighBound) - repmat(righTWindowAv,[size(righT(windowLowBound:windowHighBound)),1]);
                %%lefTWindowRel = lefT(windowLowBound:windowHighBound) - repmat(lefTWindowAv,[size(lefT(windowLowBound:windowHighBound)),1]);
                    %This implementation suitable for simultaneous whole-window application
                %%righTWindowRel = righT(i) - righTWindowAv; %Raw instantaneous divergence from average (degrees)
                %%lefTWindowRel = lefT(i) - lefTWindowAv; 
                %righTDiver(windowLowBound:windowHighBound) = righTWindowRel / righTWindowSD; %Distance between instantaneous value and mean in SDs
                %lefTDiver(windowLowBound:windowHighBound) = lefTWindowRel / lefTWindowSD;
                %%righTDiver(i) = righTWindowRel / righTWindowSD; %Distance between instantaneous value and mean in SDs
                %%lefTDiver(i) = lefTWindowRel / lefTWindowSD;    
                combDiver(windowLowBound:windowHighBound) =  repmat(nansum(abs(righTWindowRel - lefTWindowRel)), [windowHighBound-windowLowBound+1,1]);
                %%combDiver(windowLowBound:windowHighBound) =  repmat(nanmean(righTWindowRel - lefTWindowRel), [windowHighBound-windowLowBound+1,1]);
                %%combDiver(i) = righTDiver(i) - lefTDiver(i); %SD difference between right and left rels
                %%combDiver(i) = righTWindowRel - lefTWindowRel; %Difference between divergences from average angle (degrees)
            end

        end
        %-----------------------

        %DLC geometries
        if incDLC == 1 && doGeometry == 1
            if incAntDLC == 1

                dlcLeftAntennaTip_x = overGlob.DLC_ANT_dlcData.LeftAntennaTip_x;
                dlcLeftAntennaTip_y = overGlob.DLC_ANT_dlcData.LeftAntennaTip_y;
                dlcRightAntennaTip_x = overGlob.DLC_ANT_dlcData.RightAntennaTip_x;
                dlcRightAntennaTip_y = overGlob.DLC_ANT_dlcData.RightAntennaTip_y;

                dlcLeftAntennaBase_x = overGlob.DLC_ANT_dlcData.LeftAntennaBase_x;
                dlcLeftAntennaBase_y = overGlob.DLC_ANT_dlcData.LeftAntennaBase_y;
                dlcRightAntennaBase_x = overGlob.DLC_ANT_dlcData.RightAntennaBase_x;
                dlcRightAntennaBase_y = overGlob.DLC_ANT_dlcData.RightAntennaBase_y;

                %Calculate median positions
                %Note: This calculation can be a major slowing factor in bulk, hence why it is done here
                medLTipX = nanmedian(dlcLeftAntennaTip_x);
                medLTipY = nanmedian(dlcLeftAntennaTip_y);
                medRTipX = nanmedian(dlcRightAntennaTip_x);
                medRTipY = nanmedian(dlcRightAntennaTip_y);

                %Calculate centrepoint between fly antennae
                centreX = (medLTipX + medRTipX) / 2.0;
                centreY = (medLTipY + medRTipY) / 2.0;

                %Calculate distance between antenna
                interTipDistance = sqrt( ( abs( centreX - medLTipX ) *2 )^2 + ( abs( centreY - medLTipY ) *2 )^2);
                %Simple geometry...

                %--------------------------------------------------------------
                %Hypotenuse calcs
                %{
                %Calculate relative distance from centrepoint for data
                dlcLeftAntennaTipX_rel = dlcLeftAntennaTip_x - centreX;
                dlcLeftAntennaTipY_rel = dlcLeftAntennaTip_y - centreY;
                dlcRightAntennaTipX_rel = dlcRightAntennaTip_x - centreX;
                dlcRightAntennaTipY_rel = dlcRightAntennaTip_y - centreY;

                %Calculate hypotenuse between every antennal position and median positions
                dlcLeftAntennaTip_hyp = [];
                dlcRightAntennaTip_hyp = [];
                for i = 1:size(dlcLeftAntennaTip_x,1)
                    dlcLeftAntennaTip_hyp(i,1) = sqrt( ( abs( dlcLeftAntennaTip_x(i,1) - medLTipX ) *2 )^2 + ( abs( dlcLeftAntennaTip_y(i,1) - medLTipY ) *2 )^2);
                    dlcRightAntennaTip_hyp(i,1) = sqrt( ( abs( dlcRightAntennaTip_x(i,1) - medRTipX ) *2 )^2 + ( abs( dlcRightAntennaTip_y(i,1) - medRTipY ) *2 )^2);
                end

                %Smooth data because reasons
                %%smoothBinSize = 60; %~2s, flattens everything faster than 0.5Hz inclusive
                dlcLeftAntennaTip_hyp_smoothed = [];
                dlcRightAntennaTip_hyp_smoothed = [];
                for i = dlcSmoothSize+1:size(dlcLeftAntennaTip_hyp,1)
                    dlcLeftAntennaTip_hyp_smoothed(i,1) = nanmean(dlcLeftAntennaTip_hyp(i-dlcSmoothSize:i));
                    dlcRightAntennaTip_hyp_smoothed(i,1) = nanmean(dlcRightAntennaTip_hyp(i-dlcSmoothSize:i));
                end
                %}
                %--------------------------------------------------------------
                %Angle calcs

                %Set up
                %%centreX = (nanmedian(overGlob.dlcLeftAntennaTip_x) + nanmedian(overGlob.dlcRightAntennaTip_x))/2;
                centreLineX = [centreX centreX];
                centreLineY = [0 safeHeight];
                dlcLeftAntennaAngle = zeros(size(dlcLeftAntennaTip_x,1),1); %Unadjusted angle to vertical centreline
                dlcRightAntennaAngle = zeros(size(dlcRightAntennaTip_x,1),1);
                dlcLeftAntennaAngleAdj = zeros(size(dlcLeftAntennaTip_x,1),1); %Adjusted angle to correctly rotated centreline
                dlcRightAntennaAngleAdj = zeros(size(dlcRightAntennaTip_x,1),1);

                roofLineX = [nanmedian(dlcLeftAntennaTip_x)  nanmedian(dlcRightAntennaTip_x)];
                roofLineY = [nanmedian(dlcLeftAntennaTip_y)  nanmedian(dlcRightAntennaTip_y)];
                %%mapshow(roofLineX,roofLineY,'Marker','o','Color', 'c');
                roofLineSlope = (roofLineY(2) - roofLineY(1)) ./ (roofLineX(2) - roofLineX(1));
                roofLineAngle = atand(roofLineSlope); %Angle of incorrect left-rightness
                adjCentreLineSlope = -1 / roofLineSlope;
                adjCentreLineAngle = atand(adjCentreLineSlope);
                adjCentreLineY = [nansum(roofLineY)/2 safeHeight];
                adjCentreLineX = [centreX centreX-tan(deg2rad(90+atand(adjCentreLineSlope)))*(safeHeight-adjCentreLineY(1))];

                tic
                if doIndividualIcptCalcs == 1
                    %Calculate extrapolated adjusted centreline intercepts for every single point
                    percDone = 0; %Ticker of completion to stave off despair
                    percActual = 0; %The actual completion percentage
                    percTime = []; %Timer for ETA purposes

                    %rightAntennaExtrapIcptCoords = [];
                    rightAntennaExtrapIcptCoords = zeros(size(dlcLeftAntennaTip_x,1),2);
                    %leftAntennaExtrapIcptCoords = [];
                    leftAntennaExtrapIcptCoords = zeros(size(dlcLeftAntennaTip_x,1),2);

                    for i2 = 1:size(dlcLeftAntennaTip_x,1)
                        percDone = percDone + 1;
                        if percDone > 0.1*size(dlcLeftAntennaTip_x,1)
                            percActual = percActual + 0.1;
                            percTime = toc;
                            tic;
                            %%disp([num2str(percActual*100),'% done preparing DLC geometries'])
                            disp([num2str(percActual*100),'% done preparing DLC geometries (ETA: ',num2str((1-percActual)*10*percTime),'s)'])
                            %['ETA: ',num2str((1-percActual)*10*percTime), ' seconds']
                            percDone = 0;
                        end


                        rightAntennaWholeX = [dlcRightAntennaTip_x(i2) dlcRightAntennaBase_x(i2)];
                        rightAntennaWholeY = [dlcRightAntennaTip_y(i2) dlcRightAntennaBase_y(i2)];
                        leftAntennaWholeX = [dlcLeftAntennaTip_x(i2) dlcLeftAntennaBase_x(i2)];
                        leftAntennaWholeY = [dlcLeftAntennaTip_y(i2) dlcLeftAntennaBase_y(i2)];

                        %rightExtrapPoly = polyfit(rightAntennaWholeX,rightAntennaWholeY,1); %Deprecated because overkill to use such a function for simple rise/run calcs
                        %leftExtrapPoly = polyfit(leftAntennaWholeX,leftAntennaWholeY,1);
                            %This function is responsible for about 50% of the time loss in this section

                        rightExtrapPolyBootleg(1) = (rightAntennaWholeY(2) - rightAntennaWholeY(1)) / (rightAntennaWholeX(2) - rightAntennaWholeX(1));
                        rightExtrapPolyBootleg(2) = (rightAntennaWholeY(1)) - (rightExtrapPolyBootleg(1)*rightAntennaWholeX(1));
                        leftExtrapPolyBootleg(1) = (leftAntennaWholeY(2) - leftAntennaWholeY(1)) / (leftAntennaWholeX(2) - leftAntennaWholeX(1));
                        leftExtrapPolyBootleg(2) = (leftAntennaWholeY(1)) - (leftExtrapPolyBootleg(1)*leftAntennaWholeX(1));
                            %"(1) - Calculate rise/run"
                            %"(2) - Calculate intercept"

                        rightAntennaWholeExtrapX = [dlcLeftAntennaBase_x(i2),dlcRightAntennaBase_x(i2)]; %L ant. base to R ant. base
                        %rightAntennaWholeExtrapY = polyval(rightExtrapPoly,rightAntennaWholeExtrapX);
                        rightAntennaWholeExtrapY = polyval(rightExtrapPolyBootleg,rightAntennaWholeExtrapX);
                        leftAntennaWholeExtrapX = [dlcLeftAntennaBase_x(i2),dlcRightAntennaBase_x(i2)]; %L ant. base to R ant. base
                        %leftAntennaWholeExtrapY = polyval(leftExtrapPoly,leftAntennaWholeExtrapX);
                        leftAntennaWholeExtrapY = polyval(leftExtrapPolyBootleg,leftAntennaWholeExtrapX);

                        [xi,yi] = polyxpoly(rightAntennaWholeExtrapX,rightAntennaWholeExtrapY,adjCentreLineX,adjCentreLineY); %Valid up to 45 degrees
                        if isempty(xi) ~= 1 && isempty(yi) ~= 1
                            rightAntennaExtrapIcptCoords(i2,1) = xi;
                            rightAntennaExtrapIcptCoords(i2,2) = yi;
                        else
                            rightAntennaExtrapIcptCoords(i2,1) = NaN;
                            rightAntennaExtrapIcptCoords(i2,2) = NaN;                    
                        end
                        [xi,yi] = polyxpoly(leftAntennaWholeExtrapX,leftAntennaWholeExtrapY,adjCentreLineX,adjCentreLineY);
                        if isempty(xi) ~= 1 && isempty(yi) ~= 1
                            leftAntennaExtrapIcptCoords(i2,1) = xi;
                            leftAntennaExtrapIcptCoords(i2,2) = yi;
                        else
                            leftAntennaExtrapIcptCoords(i2,1) = NaN;
                            leftAntennaExtrapIcptCoords(i2,2) = NaN;                    
                        end

                    end

                    rightAntennaExtrapIcptCoordsMed(1,1) = nanmedian(rightAntennaExtrapIcptCoords(:,1));
                    rightAntennaExtrapIcptCoordsMed(1,2) = nanmedian(rightAntennaExtrapIcptCoords(:,2));
                    leftAntennaExtrapIcptCoordsMed(1,1) = nanmedian(leftAntennaExtrapIcptCoords(:,1));
                    leftAntennaExtrapIcptCoordsMed(1,2) = nanmedian(leftAntennaExtrapIcptCoords(:,2));
                else
                    %Find median points and calculate intercept from there    
                    medRightAntennaWholeX = nanmedian([dlcRightAntennaTip_x(:), dlcRightAntennaBase_x(:)]);
                    medRightAntennaWholeY = nanmedian([dlcRightAntennaTip_y(:), dlcRightAntennaBase_y(:)]);
                    medLeftAntennaWholeX = nanmedian([dlcLeftAntennaTip_x(:), dlcLeftAntennaBase_x(:)]);
                    medLeftAntennaWholeY = nanmedian([dlcLeftAntennaTip_y(:), dlcLeftAntennaBase_y(:)]);

                    medRightExtrapPolyBootleg(1) = (medRightAntennaWholeY(2) - medRightAntennaWholeY(1)) / (medRightAntennaWholeX(2) - medRightAntennaWholeX(1));
                    medRightExtrapPolyBootleg(2) = (medRightAntennaWholeY(1)) - (medRightExtrapPolyBootleg(1)*medRightAntennaWholeX(1));
                    medLeftExtrapPolyBootleg(1) = (medLeftAntennaWholeY(2) - medLeftAntennaWholeY(1)) / (medLeftAntennaWholeX(2) - medLeftAntennaWholeX(1));
                    medLeftExtrapPolyBootleg(2) = (medLeftAntennaWholeY(1)) - (medLeftExtrapPolyBootleg(1)*medLeftAntennaWholeX(1));
                        %"(1) - Calculate rise/run"
                        %"(2) - Calculate intercept"

                    medRightAntennaWholeExtrapX = [nanmedian(dlcLeftAntennaBase_x(:)),nanmedian(dlcRightAntennaBase_x(:))]; %L ant. base to R ant. base
                    medRightAntennaWholeExtrapY = polyval(medRightExtrapPolyBootleg,medRightAntennaWholeExtrapX);
                    medLeftAntennaWholeExtrapX = [nanmedian(dlcLeftAntennaBase_x(:)),nanmedian(dlcRightAntennaBase_x(:))]; %L ant. base to R ant. base
                    medLeftAntennaWholeExtrapY = polyval(medLeftExtrapPolyBootleg,medLeftAntennaWholeExtrapX);

                    [xi,yi] = polyxpoly(medRightAntennaWholeExtrapX,medRightAntennaWholeExtrapY,adjCentreLineX,adjCentreLineY); %Valid up to 45 degrees
                    if isempty(xi) ~= 1 && isempty(yi) ~= 1
                        rightAntennaExtrapIcptCoordsMed(1,1) = xi;
                        rightAntennaExtrapIcptCoordsMed(1,2) = yi;
                    else
                        rightAntennaExtrapIcptCoordsMed(1,1) = NaN;
                        rightAntennaExtrapIcptCoordsMed(1,2) = NaN;              
                    end
                    [xi,yi] = polyxpoly(medLeftAntennaWholeExtrapX,medLeftAntennaWholeExtrapY,adjCentreLineX,adjCentreLineY);
                    if isempty(xi) ~= 1 && isempty(yi) ~= 1
                        leftAntennaExtrapIcptCoordsMed(1,1) = xi;
                        leftAntennaExtrapIcptCoordsMed(1,2) = yi;
                    else
                        leftAntennaExtrapIcptCoordsMed(1,1) = NaN;
                        leftAntennaExtrapIcptCoordsMed(1,2) = NaN;                
                    end

                    disp(['-- Median ant. geometries calculated in ', num2str(round(toc,2)) ,' s --'])
                %doIndividualIcptCalcs end
                end

                %Calculate for all instances
                for i1 = 1:size(dlcLeftAntennaTip_x,1)
                    %Display roof and adjusted centreline
                    %mapshow(roofLineX,roofLineY,'Marker','o','Color', 'c'); %Roof
                    %mapshow(adjCentreLineX,adjCentreLineY,'Marker','o','Color', 'c'); %Adjusted centreline
                    %Map left antenna
                    leftAntennaWholeX = [dlcLeftAntennaTip_x(i1) dlcLeftAntennaBase_x(i1)];
                    leftAntennaWholeY = [dlcLeftAntennaTip_y(i1) dlcLeftAntennaBase_y(i1)];
                    %mapshow(leftAntennaWholeX,leftAntennaWholeY,'Marker','+','Color', 'm');
                    %Map right antenna
                    rightAntennaWholeX = [dlcRightAntennaTip_x(i1) dlcRightAntennaBase_x(i1)];
                    rightAntennaWholeY = [dlcRightAntennaTip_y(i1) dlcRightAntennaBase_y(i1)];
                    %mapshow(rightAntennaWholeX,rightAntennaWholeY,'Marker','+','Color', 'm');
                    %Calculate left antenna slope/angle
                    leftAntennaWholeSlope = (leftAntennaWholeY(2) - leftAntennaWholeY(1)) ./ (leftAntennaWholeX(2) - leftAntennaWholeX(1));
                        %Note: This is between the tip actual location and the base actual location
                    leftAntennaWholeAngle = atand(leftAntennaWholeSlope);
                    %%text(leftAntennaWholeX(1), leftAntennaWholeY(1)-0.05*safeHeight, num2str(round(leftAntennaWholeAngle,0)), 'Color', 'c','FontSize',safeHeight*0.02);
                    dlcLeftAntennaAngle(i1,1) = leftAntennaWholeAngle; %May cause slowing over time
                    %Calculate right antenna slope/angle
                    rightAntennaWholeSlope = (rightAntennaWholeY(1) - rightAntennaWholeY(2)) ./ (rightAntennaWholeX(1) - rightAntennaWholeX(2));
                        %Note: This is between the tip actual location and the base actual location
                    rightAntennaWholeAngle = atand(rightAntennaWholeSlope);
                    %%text(rightAntennaWholeX(1), rightAntennaWholeY(1)-0.05*safeHeight, num2str(round(rightAntennaWholeAngle,0)), 'Color', 'c','FontSize',safeHeight*0.02);
                    dlcRightAntennaAngle(i1,1) = rightAntennaWholeAngle; %May cause slowing over time
                    %Calculate adjusted left and right antennal tip angles
                    leftAntennaWholeAngleAdj = abs(atand((tan(deg2rad(leftAntennaWholeAngle))-tan(deg2rad(roofLineAngle)))/(1+tan(deg2rad(leftAntennaWholeAngle))*tan(deg2rad(roofLineAngle)))));
                    rightAntennaWholeAngleAdj = abs(atand((tan(deg2rad(rightAntennaWholeAngle))-tan(deg2rad(roofLineAngle)))/(1+tan(deg2rad(rightAntennaWholeAngle))*tan(deg2rad(roofLineAngle)))));
                    dlcLeftAntennaAngleAdj(i1,1) = leftAntennaWholeAngleAdj;
                    dlcRightAntennaAngleAdj(i1,1) = rightAntennaWholeAngleAdj;
                        %Angle between the roof line and the outward component of the antenna that would be extrapolated above said roof line
                    %text(leftAntennaWholeX(1), leftAntennaWholeY(1)-0.05*safeHeight, num2str(round(leftAntennaWholeAngleAdj,0)), 'Color', 'c','FontSize',safeHeight*0.02);
                    %text(rightAntennaWholeX(1), rightAntennaWholeY(1)-0.05*safeHeight, num2str(round(rightAntennaWholeAngleAdj,0)), 'Color', 'c','FontSize',safeHeight*0.02);
                    %Calculate tip-medianCentrelineIntercept angle
                    rightAntennaTipIcptSlope = (rightAntennaExtrapIcptCoordsMed(1,2) - rightAntennaWholeY(2)) ./ (rightAntennaExtrapIcptCoordsMed(1,1) - rightAntennaWholeX(2));
                    leftAntennaTipIcptSlope = (leftAntennaWholeY(2) - leftAntennaExtrapIcptCoordsMed(1,2)) ./ (leftAntennaWholeX(2) - leftAntennaExtrapIcptCoordsMed(1,1));
                    rightAntennaTipIcptAngle = atand(rightAntennaTipIcptSlope);
                    leftAntennaTipIcptAngle = atand(leftAntennaTipIcptSlope);                
                    rightAntennaTipIcptAngleAdj = abs(atand((tan(deg2rad(rightAntennaTipIcptAngle))-tan(deg2rad(roofLineAngle)))/(1+tan(deg2rad(rightAntennaTipIcptAngle))*tan(deg2rad(roofLineAngle)))));
                    leftAntennaTipIcptAngleAdj = abs(atand((tan(deg2rad(leftAntennaTipIcptAngle))-tan(deg2rad(roofLineAngle)))/(1+tan(deg2rad(leftAntennaTipIcptAngle))*tan(deg2rad(roofLineAngle)))));                                
                    dlcRightAntennaTipIcptAngleAdj(i1,1) = rightAntennaTipIcptAngleAdj;
                    dlcLeftAntennaTipIcptAngleAdj(i1,1) = leftAntennaTipIcptAngleAdj;
                end

                %Smooth
                dlcLeftAntennaAngleAdj_smoothed = [];
                dlcRightAntennaAngleAdj_smoothed = [];
                dlcLeftAntennaTipIcptAngleAdj_smoothed = [];
                dlcRightAntennaTipIcptAngleAdj_smoothed = [];
                for i = dlcSmoothSize+1:size(dlcLeftAntennaAngleAdj,1)
                    dlcLeftAntennaAngleAdj_smoothed(i,1) = nanmean(dlcLeftAntennaAngleAdj(i-dlcSmoothSize:i));
                    dlcRightAntennaAngleAdj_smoothed(i,1) = nanmean(dlcRightAntennaAngleAdj(i-dlcSmoothSize:i));
                    dlcLeftAntennaTipIcptAngleAdj_smoothed(i,1) = nanmean(dlcLeftAntennaTipIcptAngleAdj(i-dlcSmoothSize:i));
                    dlcRightAntennaTipIcptAngleAdj_smoothed(i,1) = nanmean(dlcRightAntennaTipIcptAngleAdj(i-dlcSmoothSize:i));
                end

                %--------------------------------------------------------------        

                if doIndividualIcptCalcs == 1
                    overGlob.dlcDataProc.leftAntennaExtrapIcptCoords = leftAntennaExtrapIcptCoords;
                    overGlob.dlcDataProc.rightAntennaExtrapIcptCoords = rightAntennaExtrapIcptCoords;
                end
                %overGlob.dlcDataProc.leftAntennaExtrapIcptCoords = leftAntennaExtrapIcptCoords; %Not calculated during 'fast' operation
                overGlob.dlcDataProc.leftAntennaExtrapIcptCoordsMed = leftAntennaExtrapIcptCoordsMed;
                %overGlob.dlcDataProc.rightAntennaExtrapIcptCoords = rightAntennaExtrapIcptCoords; %Not calculated during 'fast' operation
                overGlob.dlcDataProc.rightAntennaExtrapIcptCoordsMed = rightAntennaExtrapIcptCoordsMed;
                overGlob.dlcDataProc.dlcLeftAntennaAngleAdj = dlcLeftAntennaAngleAdj;
                overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed = dlcLeftAntennaAngleAdj_smoothed;
                overGlob.dlcDataProc.dlcLeftAntennaTipIcptAngleAdj = dlcLeftAntennaTipIcptAngleAdj;
                overGlob.dlcDataProc.dlcLeftAntennaTipIcptAngleAdj_smoothed = dlcLeftAntennaTipIcptAngleAdj_smoothed;
                overGlob.dlcDataProc.dlcRightAntennaAngleAdj = dlcRightAntennaAngleAdj;
                overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed = dlcRightAntennaAngleAdj_smoothed;
                overGlob.dlcDataProc.dlcRightAntennaTipIcptAngleAdj = dlcRightAntennaTipIcptAngleAdj;
                overGlob.dlcDataProc.dlcRightAntennaTipIcptAngleAdj_smoothed = dlcRightAntennaTipIcptAngleAdj_smoothed;
            %incAntDLC end
            end

            if incProbDLC == 1
                
                
                %Calculate proboscis positions and hypotenii
                try
                    dlcProboscis_x = overGlob.DLC_SIDE_dlcData.proboscis_x;
                    dlcProboscis_y = overGlob.DLC_SIDE_dlcData.proboscis_y;
                catch
                    dlcProboscis_x = overGlob.DLC_PROB_dlcData.proboscis_x;
                    dlcProboscis_y = overGlob.DLC_PROB_dlcData.proboscis_y;
                end
                dlcProboscisMedCoords = [nanmedian(dlcProboscis_x), nanmedian(dlcProboscis_y)];
                %dlcProboscisMed_x = nanmedian(dlcProboscis_x);
                %dlcProboscisMed_y = nanmedian(dlcProboscis_y);

                dlcProboscisHyp = sqrt( ( abs( dlcProboscis_x - dlcProboscisMedCoords(1) ) ).^2 + ( abs( dlcProboscis_y - dlcProboscisMedCoords(2) ) ).^2 );

                %Save to overGlob
                %overGlob.dlcProboscis_x = dlcProboscis_x;
                %overGlob.dlcProboscis_y = dlcProboscis_y;
                %overGlob.dlcProboscisMedCoords = dlcProboscisMedCoords;
                %overGlob.dlcProboscisMed_x = dlcProboscisMed_x;
                %overGlob.dlcProboscisMed_y = dlcProboscisMed_y;
                overGlob.dlcDataProc.dlcProboscisMedCoords = dlcProboscisMedCoords;
                overGlob.dlcDataProc.dlcProboscisHyp = dlcProboscisHyp;

            end
        %incDLC and doGeometry end    
        end
        %-----------------------

        %%toc
        ['-- Data processing completed --']
        
        clear valuesProc
        clear dlcProboscis_x dlcProboscis_y dlcProboscisHyp 

        %-----------------------


        %%

        %-----------------------------------------------------------------------------------------------------------------------------
        try
            %Plot smoothed average contour size and antennal angles in one graph
            if eStabGlob == 1
                %Assemble nice timing X tick labels
                xTimesProc = overGlob.firstBaseFrameTimeTimeDate;
                for i = 1:size(xTimesProc,1)
                    xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
                end    

                figure

                if incDorsData == 1
                    %Antennal angle
                    %Note: Consider replacing with inbuilt smooth function
                    if exist('rightThetaSmoothed') ~= 1 || exist('leftThetaSmoothed') ~= 1 
                        rightThetaSmoothed = [];
                        leftThetaSmoothed = [];
                        for i = 31:size(overGlob.rightThetaProc,1)-31
                            rightThetaSmoothed(i,1) = nanmean(overGlob.rightThetaProc(i-30:i));
                            leftThetaSmoothed(i,1) = nanmean(overGlob.leftThetaProc(i-30:i));
                        end
                    end

                    hold on
                    plot(rightThetaSmoothed, 'c')
                    hold on
                    plot(leftThetaSmoothed, 'b')
                    %title('Right antennal angle')
                else
                    plot([0,size(overGlob.BaseFrameTime,1)],[45,45], 'r:') %Stand-in antennal angle so that ax works correctly
                end
                
                ax = gca;
                if originalAxes ~= 1
                    ax.XTick = overGlob.firstBaseFrameTimeIdx;
                    ax.XTickLabel = [xTimesProc];
                    ax.XColor = 'k';
                    ax.YColor = 'k';
                    xlabel('Time of day (24h)')
                end
                ylabel(flyName)

                axPos = get(ax,'Position');
                ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
                hold on
                %Average contour size
                if exist('avContourSizeSmoothed') ~= 1
                    avContourSizeSmoothed = [];
                    %tic
                    %Old, reduces size
                    for i = 31:size(overGlob.movFrameMovCntrAvSize,1)-31 %Smooth over the course of roughly one second
                        avContourSizeSmoothed(i,1) = nanmean(overGlob.movFrameMovCntrAvSize(i-30:i));
                    end
                    %toc
                    %avContourSizeSmoothed = smooth( overGlob.movFrameMovCntrAvSize , floor(0.5*BaseFrameRate) );
                end

                plot(avContourSizeSmoothed, 'black')
                %{
                if incDorsData == 1
                    title(['Smoothed right (black) and left (blue) antennal angle along with average contour size (blue) over time'])
                else
                    title(['Average contour size (blue) over time (and stand-in antennal angle (r))'])
                end
                %}
                %ax2 = gca;
                if originalAxes ~= 1
                    ax2.XTick = overGlob.firstBaseFrameTimeIdx;
                    ax2.XTickLabel = [xTimesProc];
                    xlabel('Time of day (24h)')
                end
                %ylabel('Detected movement events in window (#)')
                %ylim([0 nanmax(avContourSizeSmoothed)*2])

                %Proboscis data
                if incProbData == 1
                    %Average contour size
                    %{
                    if exist('avProbContourSizeSmoothed') ~= 1
                        avProbContourSizeSmoothed = [];
                        %{
                        %Old
                        for i = 31:size(overGlob.probFrameMovCntrAvSize,1)-31 %Smooth over the course of roughly one second
                            avProbContourSizeSmoothed(i,1) = nanmean(overGlob.probFrameMovCntrAvSize(i-30:i));
                        end
                        %}
                        %New
                        avProbContourSizeSmoothed = smooth( overGlob.probFrameMovCntrAvSize , 0.5*BaseFrameRate );
                        plot(overGlob.probFrameMovCntrAvSize , 'green' )
                    else
                        plot(avProbContourSizeSmoothed, 'green')
                    end

                    %plot(avProbContourSizeSmoothed, 'green')
                    %}
                    plot( overGlob.probFrameMovCntrAvSize )
                    %DLC 
                    if isfield(overGlob,'dlcDataProc') == 1
                        plot(overGlob.dlcDataProc.dlcProboscisHyp, 'Color', [1,1,0])
                    end
                    
                end
                %{
                hold on
                %Plot true mean for separation purposes
                xVals = [1:size(avContourSizeSmoothed,1)];
                yVals = [repmat(trueAv,1,size(avContourSizeSmoothed,1))];
                plot(xVals, yVals, 'MarkerFaceColor', 'g');
                %}
                hold on
                %Plot true mean for separation purposes
                xVals = [1:size(avContourSizeSmoothed,1)];
                if dlcActivitySeparation == 1 & incDLC == 1 & isfield( overGlob, 'DLC_SIDE_dlcData' ) == 1
                    yVals = [repmat(acMean + acSDCount*acSTD,1,size(avContourSizeSmoothed,1))]; %DLC
                else
                    yVals = [repmat(adjAv,1,size(avContourSizeSmoothed,1))]; %Motion detection
                end
                plot(xVals, yVals, 'MarkerFaceColor', 'r');
                %hold off

                %Plot hole numbers on graph
                xVals = [];
                yVals = [];
                yLims = ylim;
                for i = 1:size(inStruct.holeStarts,2)
                    shadeX = [ inStruct.holeStarts(i) , inStruct.holeEnds(i) , inStruct.holeEnds(i) , inStruct.holeStarts(i) ];
                    shadeY = [ nanmax(avContourSizeSmoothed)*1.5 ,  nanmax(avContourSizeSmoothed)*1.5 , 0 , 0 ];
                    fill(shadeX,shadeY,'b')
                    alpha(0.15)

                    xVals = [xVals inStruct.holeStarts(i)];
                    yVals = [yVals 0.85*yLims(2)];
                    text(xVals(i), yVals(i), num2str(i), 'Color', 'r');
                end

                hold off
                try
                    xTimesProc = overGlob.firstBaseFrameTimeTimeDate; %Legacy data
                catch
                    xTimesProc = overGlob.firstBaseFrameTimeTimeDate; %Modern data
                end
                for i = 1:size(xTimesProc,1)
                    xTimesProc{i} = xTimesProc{i}(end-7:end-3); %Hardcoded datetime format assumption here      
                end
                xticks( [overGlob.firstBaseFrameTimeIdx] )
                xticklabels( [xTimesProc] )
                xlim([0,size(overGlob.BaseFrameTime,1)])
                title(['Whole activity trace - ', flyName])

                %Save
                if saveFigs == 1
                    %saveName = strcat(figPath,'\',flyName,'_WholeActivityTrace','.png');
                    saveName = strcat(figPath,'\',flyName,specialParam,'_WholeActivityTrace','.png');
                    %Plot preparation
                    set(gcf, 'Color', 'w');
                    set(gcf,'units','normalized','outerposition',[0 0 1 1])
                    export_fig(saveName)
                end

            end
        catch
            ['## Warning: Could not plot activity/proboscis angles over time ##']
        end

        %-------------

        try
            %Plot antennal angles during extracted sleep bouts ('holes'[aka hole plot]) 
            if eStabGlob == 1
                figure
                for i = 1:size(inStruct.holeRanges,2)
                    scrollsubplot(3,3,i)
                    if incDorsData == 1
                        plot(rightThetaSmoothed(inStruct.holeRanges{i}), 'k')
                        hold on
                        plot(leftThetaSmoothed(inStruct.holeRanges{i}), 'b')
                    else
                       plot([0, size(inStruct.holeRanges{i},2)],[45,45], 'r:') %Stand-in antennal angle so that ax works correctly 
                    end
                    if incAntDLC == 1
                        plot(overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'm')
                        hold on
                        plot(overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed(inStruct.holeRanges{i}), 'b')
                    end
                    %%hold on
                    xlim([0 inStruct.holeSizes(i)])
                    ax = gca;
                    %exTicks = 0:60:inStruct.holeSizesSeconds(i);
                    %exTicks = ax.XTick;
                    exTicks = linspace(0,inStruct.holeSizes(i),5);
                    exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                    %%maxTick = max(get(gca,'Xtick'));
                    maxTick = inStruct.holeSizes(i);
                    %%xTickScale = maxTick/size(exTicks,2); %Get existing number of X tick labels, calculate behind the scenes scaler
                    ax.XTick = exTicks;
                    ax.XTickLabel = [exTicksSeconds/60];
                    if i == 1
                        xlabel('Time (m)')
                    end

                    ylim([0 50]) %Hardcoded
                    ylabel('Angle (degs)')

                    title(strcat(inStruct.holeStartsTimes{i}, ' : ',  inStruct.holeEndsTimes{i}(end-8:end) , ' (k= ', num2str(i), ')'))

                    if incProbData == 1
                        axPos = get(ax,'Position');
                        ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
                        hold on
                        plot(avProbContourSizeSmoothed( inStruct.holeRanges{i} ), 'green') %Old; Fails if hole occurring all the way up to end of 
                        xlim([0 size(inStruct.holeRanges{i},2)])
                        try
                            tempProb = avProbContourSizeSmoothed(inStruct.holeRanges{i});
                            tempProb = tempProb(tempProb ~= 0);
                            tempProb(tempProb > nanmean(tempProb)+2*nanstd(tempProb)) = NaN;
                            ylim([1 nanmean(tempProb)*15])
                        catch
                            ylim([0 max(avProbContourSizeSmoothed(inStruct.holeRanges{i}))*3+1])
                        end
                        ax2.XTick = [];
                    end

                end

                %Save
                if saveFigs == 1
                    %saveName = strcat(figPath,'\',flyName,'_HoleFig','.png');
                    saveName = strcat(figPath,'\',flyName,specialParam,'_HoleFig','.png');
                    %Plot preparation
                    set(gcf, 'Color', 'w');
                    set(gcf,'units','normalized','outerposition',[0 0 1 1])
                    %export_fig(saveName)
                    saveas(gcf,saveName,'png')
                end

            %estabglob end    
            end
        catch
            ['## Warning: Could not plot extracted inactivity bouts ##']
        end
        
        %Specific hole plot
        specHole = 3;
        bufferSize = 0.1; %Size of pre and post buffer (fraction of bout size) to additionally display
        try
            figure
            for i = specHole%1:size(inStruct.holeRanges,2) %
                thisSpecRange = [ inStruct.holeRanges{i}(1) - floor(bufferSize*size(inStruct.holeRanges{i},2)) : ...
                    inStruct.holeRanges{i}(end) + floor(bufferSize*size(inStruct.holeRanges{i},2)) ];
                thisSpecRange( thisSpecRange < 0 ) = []; thisSpecRange( thisSpecRange > size(acRaw,1) ) = []; 
                %scrollsubplot(3,3,i)
                if incDorsData == 1
                    plot(rightThetaSmoothed(thisSpecRange), 'k')
                    hold on
                    plot(leftThetaSmoothed(thisSpecRange), 'b')
                else
                   plot([0, size(thisSpecRange,2)],[45,45], 'r:') %Stand-in antennal angle so that ax works correctly 
                end
                if incAntDLC == 1
                    plot(overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed(thisSpecRange), 'm')
                    hold on
                    plot(overGlob.dlcDataProc.dlcLeftAntennaAngleAdj_smoothed(thisSpecRange), 'b')
                end

                plot( acRaw( thisSpecRange )*0.01, 'Color', 'k' )
                line([floor(bufferSize*size(inStruct.holeRanges{i},2)),floor(bufferSize*size(inStruct.holeRanges{i},2))], ...
                    [ 0 , nanmax(acRaw( thisSpecRange )) ], 'Color', 'r', 'LineStyle', ':')
                line([floor(bufferSize*size(inStruct.holeRanges{i},2))+size(inStruct.holeRanges{i},2),floor(bufferSize*size(inStruct.holeRanges{i},2))+size(inStruct.holeRanges{i},2)], ...
                    [ 0 , nanmax(acRaw( thisSpecRange )) ], 'Color', 'r', 'LineStyle', ':')

                %%hold on
                %%xlim([0 inStruct.holeSizes(i)])
                xlim([0,size(thisSpecRange,2)])
                ax = gca;
                %exTicks = 0:60:inStruct.holeSizesSeconds(i);
                %exTicks = ax.XTick;
                %exTicks = linspace(0,inStruct.holeSizes(i),5);
                exTicks = [0:60*BaseFrameRate:size(thisSpecRange,2)]+floor(bufferSize*size(inStruct.holeRanges{i},2));
                %exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(i),5);
                exTicksSeconds = 0:1:floor( size(thisSpecRange,2)/BaseFrameRate/60 );
                %%maxTick = max(get(gca,'Xtick'));
                %%maxTick = inStruct.holeSizes(i);
                %%xTickScale = maxTick/size(exTicks,2); %Get existing number of X tick labels, calculate behind the scenes scaler
                ax.XTick = exTicks;
                %ax.XTickLabel = [exTicksSeconds/60];
                ax.XTickLabel = [exTicksSeconds];
                if i == 1
                    xlabel('Time (m)')
                end

                ylim([-5 50]) %Hardcoded
                ylabel('Angle (degs)')

                title(strcat(inStruct.holeStartsTimes{i}, ' : ',  inStruct.holeEndsTimes{i}(end-8:end) , ' (k= ', num2str(i), ')'))

                if incProbData == 1
                    axPos = get(ax,'Position');
                    ax2 = axes('Position', axPos, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
                    hold on

                    plot(avProbContourSizeSmoothed(thisSpecRange), 'green')
                    xlim([0 size(thisSpecRange,2)])
                    try
                        tempProb = avProbContourSizeSmoothed(thisSpecRange);
                        tempProb = tempProb(tempProb ~= 0);
                        tempProb(tempProb > nanmean(tempProb)+2*nanstd(tempProb)) = NaN;
                        %ylim([-5 nanmean(tempProb)*15])
                        ylim([-0.1*nanmean(tempProb)*15 nanmean(tempProb)*15])
                    catch
                        %ylim([-5 max(avProbContourSizeSmoothed(thisSpecRange))*3+1])
                        ylim([-0.1*(max(avProbContourSizeSmoothed(thisSpecRange))*3+1) max(avProbContourSizeSmoothed(thisSpecRange))*3+1])
                    end
                end
                %{    
                drawnow
                pause(4)
                clf
                %}
            end
        catch
            disp(['#- Could not plot specific hole ',num2str(specHole),' -#'])
            close(gcf) %Because failure
        end
        
        
        %-----------------------------------------------------------------------------------------------------------------------------

        %Clear raw data (if requested)
        if clearRawData == 1
            clear bigDataStruct
            clear valuesProc
        end
        
        %Save workspace
        %Note: This new position will be useful for quick regeneration of figures but is susceptible to figure crashes resulting in a non-save
        if saveOutput == 1
            tic
            %saveName = [flyName(1:end), '_analysis']
            saveName = [flyName(1:end), specialParam, '_analysis']
            saveNameFull = [savePath,'\',saveName];

            %Check for existing
            existFiles = dir([saveNameFull '.mat']);

            if length(existFiles) ~= 0 && forceOverwrite ~= 1
                %checkAnalysis = load([saveNameFull, '.mat']);
                existAnalysisLen = length(who('-file', [saveNameFull,'.mat']));

                if existAnalysisLen ~= length(who) || overwriteOldOutput ~= 1
                    if existAnalysisLen ~= length(who)
                        '--- Mismatch between existing saved analysis data and current workspace ---'
                        proceed = input('Would you like to proceed and overwrite? (0 for No, 1 for Yes)')
                        if proceed ~= 1
                            error('Program terminated as requested')
                        end
                    else
                        '--- No major difference detected in analyses; Overwriting existing analysis by default however ---' 
                    end
                    s = warning('error', 'MATLAB:DELETE:Permission');
                    try   
                       delete([saveNameFull '.mat']);
                    catch
                        '#### Could not delete existing data file ####'
                        error('Planned failure halt')
                    end
                    save(saveNameFull);        
                else
                    '--- No detected major difference between analyses or mandated overwriting ---'
                    '--- Existing analysis not overwritten ---'
                %mismatch len/overwrite end   
                end
            else
                '--- Saving analysis data to file ---'
                %%save(saveNameFull, '-v7.3');
                try
                    warning('');
                    lastwarn('');
                    save(saveNameFull);

                    [warnMsg, warnId] = lastwarn;
                    %Correct saving QA
                    if isempty(warnId) ~= 1 & isempty(findstr( warnId, 'sizeTooBig' )) ~= 1
                        ['## Warning: Error when trying to save one or more variables; Switching to alternative save method ##']
                        error = yes
                    end
                    '--- Analsis data successfully saved ---'
                catch
                    save(saveNameFull, '-v7.3');
                    listOfErrorFiles(e).fol = fol;
                    listOfErrorFiles(e).SaveName = [saveNameFull];
                    listOfErrorFiles(e).Reason = ['Save error'];
                    numOfErrorFiles = numOfErrorFiles + 1;
                    currentIsErrorDataset = 1;
                    e = e + 1;
                    '--- Analsis data save error; Less compressed method used ---'
                end
            %existFiles end     
            end
            toc
        %saveOutput end
        end

        %-----------------------

        %-----------------------------------------------------------------------------------------------------------------------------

        %Play videos (experimental)
        if dispVids == 1 && noDispVidsOverride ~= 1
            
            if vidMode == 1
                disp(['-- Preparing vids in collab mode --'])
                %-------------------------------------------------------------------------

                %Overload collab frames
                %Begin block operation here

                if writeVids ~= 1 %If writing vids, don't save as going (MATLAB will memory-crash)
                    overCollab = struct; %This structure ends up being immense in size
                    ['-- Commencing overLoad of collab frames --']
                end
                %List of what to overload or write, respectively
                if writeVids ~= 1
                    holeNumList = [4]
                else
                    holeNumList = [1:size(inStruct.holeStarts,2)]
                end
                if size(holeNumList,2) > 3 && writeVids ~= 1
                    ['-- Alert: Requested number of holes to store in memory too large --']
                    safety = halt
                end
                if limitBreak < 15000
                    ['## Alert: Potentially aberrant limitBreak value in place ##']
                    safety = halt        
                end

                for holeNum = holeNumList
                    skipThisVid = 0; %Whether or not to skip processing of this video
                    tic
                    ['-----------------------------------------------------']
                    ['-- Hole number: ', num2str(holeNum), ' of ', num2str(size(inStruct.holeStarts,2)), ' --']
                    ['-- Hole size: ',  num2str(inStruct.holeSizes(holeNum)), ' --']
                    %-------
                    reqVids = 1; %Number of videos required to process this hole
                    emergencyWriteVid = 0; %This allows automatic switching to video writing rather than storage for large holes that would exceed memory limits
                    %%reqVidIdx = 1; %Corresponding index
                    segParts = 1;
                    segBreak = 0;
                    segIdx = 0;
                    readErrorDors = 0;
                    readErrorMov = 0;

                    %-------
                    %Check for large hole
                    if inStruct.holeSizes(holeNum) > limitBreak*0.9 && writeVids ~= 1 %Hardcoded memory threshold value based on experimentation
                        ['## Warning: Hole size likely too large to store in memory; Switching to memory efficient write mode ##']
                        emergencyWriteVid = 1; %Note down that it is an emergency write, not a planned write
                        writeVids = 1; %Engage writing mode
                            %Since memory efficient writing is now the default, this will only be active when writeVids was not initially active
                    end
                    %Check for dangerously large hole
                    %{
                    if inStruct.holeSizes(holeNum) > 40000
                        ['## ALERT: HOLE SIZE ALMOST CERTAINLY TOO LARGE TO SAFELY STORE OR WRITE TO VIDEO; SKIPPING ##']
                        skipThisVid = 1;
                    end
                    %}
                    if inStruct.holeSizes(holeNum) > limitBreak
                        ['## Warning: Hole too large to store in memory; Segmentation will be deployed ##']
                        writeVids = 1; %Just in case
                        segParts = ceil(inStruct.holeSizes(holeNum) / limitBreak); %Video will be segmented into reqVids x 40,000 row segments
                        %%segActive = 1; %Indicates that the segmenter is active (duh)
                        %%segIdx = 0; %Identity of segmented parts (i.e. Part 1, Part 2, etc)
                    end

                    %-------
                    %Check for video boundary crossing
                    if inStruct.holeRangesMovFrameMatched{holeNum}(1,2) ~= inStruct.holeRangesMovFrameMatched{holeNum}(end,2) || inStruct.holeRangesBaseFrameMatched{holeNum}(1,2) ~= inStruct.holeRangesBaseFrameMatched{holeNum}(end,2)
                        ['-- Video boundary crossing detected --'] % #buildThatWall
                        reqVids = reqVids + 1; %Technically weak to a second or third crossing (but that would involve a sleep bout of > 1h)
                            %Note: This QA becomes weaker the stronger the starting time asynchrony is between dors and mov vids
                    end
                    %-------
                    if writeVids == 1
                        writeName = [strcat(flyName, '_hole_', num2str(holeNum))];
                        %%collabRail = []; %Horizontal matched list of all dors/mov frames and positions for reqVid/seg looping
                        if skipExistingVids == 1 && size(dir(strcat(vidPath,'\',writeName, '*')),1) >= 1 %Video exists; Skip
                            %Note: This is weak to the existence of part 1 of a multipart video causing a skip when remaining parts do not actually exist
                            ['-- Output video already exists; Skipping --']
                            skipThisVid = 1;
                        elseif skipExistingVids == 0 && size(dir(strcat(vidPath,'\',writeName, '*')),1) >= 1 %Video exists, overwrite
                            ['-- Output video already exists; Overwriting --']
                            skipThisVid = 0; 
                        end
                    end

                    if skipThisVid ~= 1 %Video does not already exist

                        %Assemble list of frames from start to finish
                        %Note: Possibility of framerate asynchrony problems without implementation of placementScalingFactor
                        collabRail = [];
                        collabRail(1:2,:) = transpose(inStruct.holeRangesBaseFrameMatched{holeNum}); %Row 1 - BaseFrame no., Row 2 - Dors vid no.
                        collabRail(3:4,:) = transpose(inStruct.holeRangesMovFrameMatched{holeNum}); %Row 3 - movFrame no., Row 4 - Mov vid no.
                        if size(inStruct.holeRangesBaseFrameMatched{holeNum},1) ~= size(inStruct.holeRangesMovFrameMatched{holeNum},1)
                            ['## Warning: Asynchrony present between matched dors and mov frames ##']
                        end
                        %Assemble list of seg parts
                        for segID = 1:segParts %Iterate along number of segs
                            if segID == segParts %Further segmentation not required
                                segIterEnd = size(collabRail,2);
                            else %Not final segmentation block
                                segIterEnd = segID*limitBreak;
                            end
                            for i = 1+(segID-1)*limitBreak:segIterEnd %A tad shonky and may induce small asymmetries
                                collabRail(5,i) = segID; %Row 5 - Part no.
                            end
                        end
                        collabRail(6,:) = transpose(inStruct.holeRanges{holeNum}); %Row 6 - overGlob positions (BaseFrame reference (probably...))

                        %Preliminary preparations
                        %##
                        currentDorsVid = collabRail(2,1); %Select starting dors vid
                        currentMovVid = collabRail(4,1); %Select starting mov vid
                        corrVidDors = currentDorsVid; %Value used for active dors handler work
                        corrVidMov = currentMovVid; %Value used for active mov handler work
                        if useDLCVids ~= 1
                            handlerDors = VideoReader([dataPath,'\',VIDS_DORS(corrVidDors).name]);
                        else
                            handlerDors = VideoReader([dlcPath,'\',VIDS_DLC(corrVidDors).name]);
                        end
                        handlerMov = VideoReader([dataPath,'\',VIDS_MOV(corrVidMov).name]);
                        %##
                        %Calculate nominal frame size for usage in rest of loops
                        %Note: Relies on assumption that frame 1 not borked
                        vidDorsWidth = handlerDors.Width;
                        vidDorsHeight = handlerDors.Height;
                        vidMovWidth = handlerMov.Width;
                        vidMovHeight = handlerMov.Height;
                        safeHeight = max([vidDorsHeight vidMovHeight]);
                        safeWidth = vidDorsWidth + vidMovWidth;
                        %##

                        %Main assembly and writing loop
                        for segIdx = 1:segParts
                            %Assemble empty collab3
                            collab3 = struct('cdata',zeros(safeHeight,safeWidth,3,'uint8'), 'colormap',[]); %Almost certainly will need rethinking when segVids implemented
                            k = 1;
                            j = 1;
                            fixedFrames = 0;
                            %##

                            %Find correct rolling iterator positions
                            railStart = 1+(segIdx-1)*limitBreak; %This is a relatively safe assumption
                            if segIdx < segParts
                                railEnd = segIdx*limitBreak;
                            elseif segIdx == segParts
                                railEnd = size(collabRail,2);
                            else
                                ['## Alert: Critical boolean failure in rail iteration']
                                error = yes
                            end
                            if railStart < 0 || railEnd > size(collabRail,2)
                                ['## ALERT: CRITICAL VALUE FAILURE IN RAIL ITERATION ##']
                                error = yes
                            end

                            %Iterate along dors/mov frames simultaneously
                            %%for i = 1:size(collabRail,2) %Deprecated
                            for i = railStart:railEnd

                                if isnan(collabRail(1,i)) ~= 1 %Normal frame operations (Note: Assumption of row-wise NaN placement symmetry)
                                    %Dors
                                    corrVidDors = collabRail(2,i); %Find current video
                                    if corrVidDors ~= currentDorsVid %Detect if change to new video has occurred
                                        if useDLCVids ~= 1
                                            handlerDors = VideoReader([dataPath,'\',VIDS_DORS(corrVidDors).name]);
                                        else
                                            handlerDors = VideoReader([dlcPath,'\',VIDS_DLC(corrVidDors).name]); %Assumption of symmetry
                                        end
                                        %Note: This is done only on detection as it is probably a slow step
                                        currentDorsVid = corrVidDors; %Otherwise will catch forever after
                                    end
                                    %%preRead = read(handlerDors,collabRail(1,i));
                                    try
                                        preRead = read(handlerDors,collabRail(1,i)); %Read dors frame of index given by collabRail
                                    catch
                                        preRead = zeros(vidDorsHeight,vidDorsWidth,3,'uint8'); %Make black frame of correct size
                                        if readErrorDors ~= 1
                                            ['## Warning: Non-critical error occurred in dors frame reading ##']
                                            readErrorDors = 1;
                                        end
                                    end
                                    if size(preRead,1) ~= vidDorsHeight || size(preRead,2) ~= vidDorsWidth || size(preRead,3) ~= 3
                                        %This is called into being when an abnormal frame size is encountered
                                        preRead = zeros(vidDorsHeight,vidDorsWidth,3,'uint8'); %Make black frame of correct size
                                            %Note: Assumption here of vidDorsHeight/Width correctness, which will be true as long as
                                            %first frame of video not borked
                                        fixedFrames = fixedFrames + 1;
                                    end
                                    collab3(k).cdata(1:vidDorsHeight,1:vidDorsWidth,1:3) = preRead;
                                    k = k + 1;

                                    %Mov
                                    corrVidMov = collabRail(4,i); %Find current video
                                    if corrVidMov ~= currentMovVid %Detect if change to new video has occurred
                                        handlerMov = VideoReader([dataPath,'\',VIDS_MOV(corrVidMov).name]);
                                        %Note: This is done only on detection as it is probably a slow step
                                        currentMovVid = corrVidMov; %Otherwise will catch forever after
                                    end
                                    %%preRead = read(handlerMov,collabRail(3,i));
                                    try %In case of frame fuckery
                                        preRead = read(handlerMov,collabRail(3,i));  %Read mov frame of index given by collabRail
                                    catch %Note: This will cause suppression of abnormal frames and may mask programmatic issues
                                        preRead = zeros(vidMovHeight,vidMovWidth,3,'uint8'); %Make black frame of correct size
                                        if readErrorMov ~= 1
                                            ['## Warning: Non-critical error occurred in mov frame reading ##']
                                            readErrorMov = 1;
                                        end
                                    end
                                    if size(preRead,1) ~= vidMovHeight || size(preRead,2) ~= vidMovWidth || size(preRead,3) ~= 3
                                        preRead = zeros(vidMovHeight,vidMovWidth,3,'uint8'); %Make black frame of correct size
                                        fixedFrames = fixedFrames + 1;
                                    end
                                    collab3(j).cdata(1:vidMovHeight,vidDorsWidth+1:vidDorsWidth+vidMovWidth,1:3) = preRead;
                                    j = j + 1;
                                else %Nan gap
                                    preRead = zeros(vidDorsHeight,vidDorsWidth,3,'uint8'); %Make black frame of correct size
                                    %%corrVidDors = collabRail(2,i); %It may be useful to active these two lines at some point
                                    %%corrVidMov = collabRail(4,i);
                                    %Make both left and right black
                                    collab3(k).cdata(1:vidDorsHeight,1:vidDorsWidth,1:3) = preRead;
                                    k = k + 1;
                                    collab3(j).cdata(1:vidMovHeight,vidDorsWidth+1:vidDorsWidth+vidMovWidth,1:3) = preRead;
                                    j = j + 1;
                                end

                            %collabRail end
                            end

                            if segIdx == 1 && segParts == 1 %Only one part
                                ['-- Writing out video in entirety --']
                                writeName = [strcat(flyName, '_hole_', num2str(holeNum))]    
                            else %More than one parts
                                ['-- Writing out video part ', num2str(segIdx), ' --']
                                %Write
                                writeName = [strcat(flyName, '_hole_', num2str(holeNum), '_part_',num2str(segIdx))]
                            end
                            %%['-- Writing out video part ', num2str(segIdx), ' --']
                            %Write
                            %%writeName = [strcat(flyName, '_hole_', num2str(holeNum), '_part_',num2str(segIdx))]
                            vidWrite = VideoWriter(strcat(vidPath,'\',writeName), 'MPEG-4')
                            open(vidWrite)
                            initSize = size(collab3,2); %Starting size of collab3 to tick to (since size will change dynamically)
                            a = 1;
                            while a <= initSize
                                writeVideo(vidWrite,collab3(1)) %Write current first frame of collab3
                                collab3(1) = []; %Delete current first frame of collab3
                                a = a + 1; %Tick by 1
                            end
                            close(vidWrite)
                            ['## Video written out successfully ##']
                        end

                    %skipThisVidEnd
                    end        
                    toc

                %holeNum end
                end

                %End block operation

                if writeVids ~= 1
                    %-------------------------------------------------------------------------
                    %Show videos and plot data

                    %{
                    %Dors
                    hfDors = figure;
                    set(hfDors,'position',[150 150 vidDorsWidth*2 vidDorsHeight]);
                    movie(hfDors,movDors,1,handlerDors.FrameRate*20);
                    %%hold on
                    %Mov
                    %%hfMov = figure;
                    %%set(hfMov,'position',[300 150 vidMovWidth*2 vidMovHeight]);
                    %%movie(hfMov,movMov,1,handlerMov.FrameRate, [vidDorsWidth 0 0 0]);
                    movie(hfDors,movMov,1,handlerMov.FrameRate*20, [vidDorsWidth 0 0 0]);
                    %}
                    %{
                    %Collab (movie implementation)
                    %This version has an easily controlled FPS but is hard to merge with plots
                    hfCollab = figure;
                    set(hfCollab,'position',[150 150 vidDorsWidth*2 vidDorsHeight]);
                    movie(hfCollab,collab2,1,handlerDors.FrameRate*20);
                    %}

                    %Collab (image implementation)
                    %FPS control is tricky here but it is more easily merged with plots
                    %%holeNumList
                    holeNum = 10
                    hfCollab = figure;
                    set(hfCollab,'position',[150 150 640*2 480]);
                    i1 = 1;    
                    %-------------------------------------------------------------------------

                    %Image + plots
                    %Plot first frame to prepare
                    subplot(3,1,[1 2])
                    %%image(collab2(i1).cdata)
                    image(overCollab(holeNum).collab3(i1).cdata)
                    %hold on
                    subplot(3,1,3)
                    %plot(rightThetaSmoothed(inStruct.holeRanges{holeNum}(1):inStruct.holeRanges{holeNum}(i1)), 'k')
                    plot(rightThetaSmoothed(inStruct.holeRanges{holeNum}(1)), 'b')
                    plot(leftThetaSmoothed(inStruct.holeRanges{holeNum}(1)), 'c')
                    title(datestr(datetime(overGlob.BaseFrameTime(inStruct.holeRanges{holeNum}(i1)), 'ConvertFrom', 'posixtime'))); %May slow down plots and may be inaccurate
                    xlim([0 size(inStruct.holeRanges{holeNum},2)])
                    ylim([40 100])
                    ax = gca;
                    %exTicks = 0:60:inStruct.holeSizesSeconds(holeNum);
                    %maxTick = max(get(gca,'Xtick'));
                    %xTickScale = maxTick/size(exTicks,2); %Get existing number of X tick labels, calculate behind the scenes scaler
                    exTicks = linspace(0,inStruct.holeSizes(holeNum),5);
                    exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(holeNum),5);
                    %ax.XTick = 0:xTickScale:maxTick;
                    ax.XTick = exTicks;
                    %ax.XTickLabel = [exTicks/60];
                    ax.XTickLabel = [exTicks/60];
                    ax.XTickLabel = [exTicksSeconds/60];
                    %%while i1 < size(overCollab(holeNum).collab3,2)
                    while i1 < inStruct.holeSizes(holeNum) %Small amount of video frames may not end up being displayed
                        subplot(3,1,[1 2])
                        %%image(collab2(i1).cdata)
                        image(overCollab(holeNum).collab3(i1).cdata)
                        %hold on
                        subplot(3,1,3)
                        plot(rightThetaSmoothed(inStruct.holeRanges{holeNum}(1):inStruct.holeRanges{holeNum}(i1)), 'k')
                        hold on
                        plot(leftThetaSmoothed(inStruct.holeRanges{holeNum}(1):inStruct.holeRanges{holeNum}(i1)), 'c')
                        hold off
                        title(datestr(datetime(overGlob.BaseFrameTime(inStruct.holeRanges{holeNum}(i1)), 'ConvertFrom', 'posixtime'))); %May slow down plots and may be inaccurate
                        xlim([0 inStruct.holeSizes(holeNum)])
                        ylim([40 100])
                        exTicks = linspace(0,inStruct.holeSizes(holeNum),5);
                        exTicksSeconds = linspace(0,inStruct.holeSizesSeconds(holeNum),5);
                        %%ax.XTick = 0:xTickScale:maxTick;
                        ax.XTick = exTicks;
                        %%ax.XTickLabel = [exTicks/60];
                        ax.XTickLabel = [exTicksSeconds/60];     

                        %hold off
                        i1 = i1 + 1;
                        drawnow
                    end
                    if inStruct.holeSizes(holeNum) < size(overCollab(holeNum).collab3,2)
                        ['-- ', num2str(size(overCollab(holeNum).collab3,2) - inStruct.holeSizes(holeNum)), ' trailing frames were not shown --']
                    end

                    %Image alone
                    %{
                    while i1 < size(collab2,2)
                        %subplot(2,1,1)
                        image(collab2(i1).cdata)
                        i1 = i1 + 1;
                        drawnow
                    end
                    %}

                    %-------------------------------------------------------------------------

                    %{
                    %Alternative
                    %Again from https://stackoverflow.com/questions/7797794/simultaneous-playback-of-multiple-videos-with-matlab
                    handlerDors = VideoReader([dataPath,'\',VIDS_DORS(corrVidDors).name]);
                    handlerMov = VideoReader([dataPath,'\',VIDS_MOV(corrVidMov).name]);

                    startDorsFrame = str2num(inStruct.holeRangesDorsFrameMatched{holeNum}{1,1});
                    endDorsFrame = str2num(inStruct.holeRangesDorsFrameMatched{holeNum}{end,1});
                    startMovFrame = inStruct.holeRangesMovFrameMatched{holeNum}(1,1);
                    endMovFrame = inStruct.holeRangesMovFrameMatched{holeNum}(end,1);

                    i1 = startDorsFrame;
                    %%i1 = 1;
                    i2 = startMovFrame;
                    %%i2 = 1;
                    hfComb = figure;
                    set(hfComb,'position',[150 150 vidDorsWidth*2.125 vidDorsHeight]);

                    %%while i1 < handlerDors.NumberOfFrames && i2 < handlerMov.NumberOfFrames
                    while i1 < endDorsFrame && i2 < endMovFrame
                        %%if i1 < handlerDors.NumberOfFrames
                        if i1 < endDorsFrame
                            i1 = i1+1;
                            subplot(1,2,1)
                            image(handlerDors.read(i1))
                            %%image(movDors(i1).cdata) %Use for reading from preloaded stack
                        end

                        %%if i2 < handlerMov.NumberOfFrames
                        if i2 < endMovFrame
                            i2 = i2+1;
                            subplot(1,2,2)
                            image(handlerMov.read(i2))
                            %%image(movMov(i2).cdata) %Use for reading from preloaded stack
                        end
                        drawnow
                    end
                    %}
                %writeVids end
                end
            else
                disp(['-- Preparing vids in annotation mode --'])
                
                %Assemble rail
                annRail = []; 
                annRail = overGlob.BaseFrameRef; %Col 1 - Vid-specific frame numbers, Col 2 - Vid ID
                %And attach movement information
                if size( overGlob.acRaw,1 ) == size( annRail,1 )
                    annRail(:,3) = overGlob.acRaw; %Col 3 - Activity/Inactivity separation raw values 
                else
                    ['## Alert: Mismatch between size of activity data and base frame reference ##']
                    crash = yes
                end
                %And hole information
                annRail(:,4) = zeros( size(annRail,1) , 1 ); %Col - Hole yes/no
                for i = 1:size(inStruct.holeRanges,2)
                    annRail( inStruct.holeRanges{i} , 4 ) = 1;
                end
                %Add DLC point annotating?
                
                %Find all vids
                    %Add support for using DLC-already-annotated vids
                vidList = dir( [overGlob.importStruct.FILES_BASE(1).folder,filesep,'*.avi'] );
                
                %Iterate across all
                vidMatchList = [];
                for vid = 1:nanmax( unique(annRail(:,2)) ) %The reference here is importStruct
                    thisBaseName = overGlob.importStruct.FILES_BASE(vid).name; %Might crash if uniques ever exceed list, but that is unlikely
                    %Attempt to match to all vids in list
                    vidMatchScores = [];
                    for x = 1:size(vidList,1)
                        temp = repmat('~', 2 , nanmax( [ size( thisBaseName,2 ) , size( vidList(x).name,2 ) ] ) );
                        temp(1, 1:size(thisBaseName,2) ) = thisBaseName;
                        temp(2, 1:size(vidList(x).name,2) ) = vidList(x).name;
                        vidMatchScores(x) = nansum( temp(1,:) == temp(2,:) ); %Works under assumption that matching vid will mirror this base name the closest (even if only by one character)
                    end
                    %Find best match
                    [~,bestMatchInd] = nanmax(vidMatchScores);
                    %QA for overfind (or under)
                    if isempty( bestMatchInd ) == 1 | nansum( vidMatchScores == vidMatchScores(bestMatchInd) ) > 1
                        ['## Alert: Critical matching failure for vids ##']
                        crash = yes
                    end
                    thisVidPath = [vidList(bestMatchInd).folder, filesep, vidList(bestMatchInd).name];
                    
                    %Save path
                    vidMatchList{vid} = thisVidPath;
                end
                
                %Load vid
                %{
                if useDLCVids ~= 1
                    handlerDors = VideoReader([dataPath,'\',VIDS_DORS(corrVidDors).name]);
                else
                    handlerDors = VideoReader([dlcPath,'\',VIDS_DLC(corrVidDors).name]);
                end
                %}

                %--------Ann
                
                if actuallyDrawVid == 1 
                    annCollab = figure;
                    
                    %set(annCollab,'units','pixels','outerposition',[0 0 safeWidth*2 safeHeight*2])
                    set(annCollab, 'Color', 'w');
                    
                    %{
                else
                    annCollab = figure('visible', 'off');
                    %}
                end
                    %Note: There might be combinations of flags now that won't run due to figure non-existence etc

                tic
                pFrames = floor( linspace( 1 , size(annRail,1) , 100 ) );
                
                %Prepare to load in order
                %i = 1; %Rail iterator (Will never decrement)
                %k = 1; %Frame iterator (Will return to 1 at start of new videos)
                currentVid = NaN;
                currentAcState = NaN;
                
                %Prepare some indexes
                acIndex = [{'Wake'},{'Sleep'}];
                acColours = [{'red'},{'blue'}];

                preVidVars = who;
                varSaveList = [varSaveList; {'preVidVars'}];
                varSaveList = [varSaveList; {'i'}];
                varSaveList = [varSaveList; {'thisVidID'}];
                
                currentStateDuration = 0;
                
                for i = 1:size( annRail,1 )
                    %Check to see if same vid
                    thisVidID = annRail(i,2);
                    if thisVidID ~= currentVid
                        %Check to see if current vid needs to be closed (if existing)
                        %{
                        if i > 1 && size(collab4,2) > 1 && runtimeWrite ~= 1
                            %(Copy of below)
                            disp(['-- Writing previous vid to file --'])
                            vidOutName = strrep( thisVidPath , '.avi', '_annotated.mp4');
                                %Note: Will need to be made general for DLC vids
                            vidWrite = VideoWriter(vidOutName, 'MPEG-4')
                            open(vidWrite)
                            for a = 1:size( collab4,2 )
                                writeVideo(vidWrite,collab4(a));
                            end
                            close(vidWrite)
                        end
                        %}
                        
                        if runtimeWrite == 1
                            try
                                close(vidWrite);
                                disp(['- Video writing closed-'])
                            end
                        else
                            if i > 1 && size(collab4,2) > 1 
                                %(Copy of below)
                                disp(['-- Writing previous vid to file --'])
                                vidOutName = strrep( thisVidPath , '.avi', '_annotated.mp4');
                                    %Note: Will need to be made general for DLC vids
                                vidWrite = VideoWriter(vidOutName, 'MPEG-4')
                                open(vidWrite)
                                for a = 1:size( collab4,2 )
                                    writeVideo(vidWrite,collab4(a));
                                end
                                close(vidWrite)
                            end
                        end
                        
                        %Aggressive memory clearing
                        %{
                        clearvars('-except',varSaveList{:})
                        disp(['- Runtime variables cleared -'])
                        %}
                        
                        thisVidPath = vidMatchList{thisVidID};
                        currentVid = thisVidID;
                        handlerVid = VideoReader([thisVidPath]);
                        vidWidth = handlerVid.Width;
                        vidHeight = handlerVid.Height;
                        disp(['-- ',thisVidPath,' (ID ',num2str(currentVid),') loaded --'])    
                        %Assemble video structure
                        if runtimeWrite ~= 1
                            collab4 = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'), 'colormap',[]);

                            k = 1;
                        end
                        if actuallyDrawVid == 1
                            clf %May be unnecessary
                        end
                        
                        if runtimeWrite == 1
                            %Prepare output
                                %Will probs add functionality not to write vids here
                            vidOutName = strrep( thisVidPath , '.avi', '_annotated.mp4');
                                %Note: Will need to be made general for DLC vids
                            vidWrite = VideoWriter(vidOutName, 'MPEG-4')
                            open(vidWrite)
                        end
                        
                        %And some reporters/QA variables
                        fixedFrames = 0;
                        readError = 0;
                        
                        disp(['-- Commencing annotating of next vid --'])
                    end
                    
                    %Keep track of state
                    thisAcState = annRail(i,4);
                    if thisAcState ~= currentAcState
                        disp(['- Ac. state changed from ',num2str(currentAcState),' to ',num2str(thisAcState),' (i:',num2str(i),') -'])
                        currentStateDuration = 0;
                        currentAcState = thisAcState;
                    else
                        currentStateDuration = currentStateDuration + 1;
                    end

                    %Load frame
                    try
                        preRead = read(handlerVid,annRail(i,1)); %Read dors frame of index given by collabRail
                    catch
                        preRead = zeros(vidHeight,vidDorsWidth,3,'uint8'); %Make black frame of correct size
                        if readError ~= 1
                            ['## Warning: Non-critical error occurred in dors frame reading ##']
                            readError = 1;
                        end
                    end
                    if size(preRead,1) ~= vidHeight || size(preRead,2) ~= vidWidth || size(preRead,3) ~= 3
                        %This is called into being when an abnormal frame size is encountered
                        preRead = zeros(vidHeight,vidWidth,3,'uint8'); %Make black frame of correct size
                            %Note: Assumption here of vidDorsHeight/Width correctness, which will be true as long as
                            %first frame of video not borked
                        fixedFrames = fixedFrames + 1;
                    end
                    if runtimeWrite ~= 1
                        collab4(k).cdata(1:vidHeight,1:vidWidth,1:3) = preRead;
                            %Note: It might be unnecessary to have collab4 be more than a single frame at a time
                    end
                    
                    if actuallyDrawVid == 1
                        %Place image onto plot and add accoutrements (Borrowed from CIVIC 3.45_XM)
                        if runtimeWrite ~= 1
                            image(collab4(k).cdata)
                        else
                            image(preRead)
                        end
                        hold on

                        %Activity/inactivity metric
                        text(0+0.05*vidWidth, 0+0.32*vidHeight, num2str(annRail(i,3)), 'Color', 'white','FontSize',vidHeight*0.04);

                        %Additional readouts
                        if annRail(i,4) ~= 1 %Hole
                            text(0+0.05*vidWidth, 0+0.25*vidHeight, 'Activity', 'Color', 'r','FontSize',vidHeight*0.04);
                        else %Not hole
                            text(0+0.05*vidWidth, 0+0.25*vidHeight, 'Inactivity', 'Color', 'b','FontSize',vidHeight*0.04);
                        end

                        %Axes and things
                        set(gca,'xtick',[]);
                        set(gca,'ytick',[]);
                    
                        drawnow
                        
                        if runtimeWrite == 1
                            thisFrame = getframe(annCollab);
                        end
                        clf
                        
                    else
                        acState = annRail(i,4);
                        %textData = [];
                        textData = [{acIndex{ acState+1 }},{num2str(annRail(i,3),'%0.3f')},{ strcat( num2str(currentStateDuration/BaseFrameRate,'%0.2f'),'s' ) }];
                        colourData = { acColours{ acState+1 } , 'white' , 'white' };
                        posData = [ 0+0.05*vidWidth , 0+0.25*vidHeight ; 0+0.05*vidWidth, 0+0.32*vidHeight ; 0+0.05*vidWidth, 0+0.39*vidHeight ];
                        
                        %collab4(k).cdata = insertText(collab4(k).cdata, [100 315 ], 'Peppers are good for you!');
                        %tic
                        if runtimeWrite ~= 1
                            collab4(k).cdata = insertText(collab4(k).cdata, posData, textData, 'TextColor', colourData , 'BoxColor', 'white', 'BoxOpacity', 0.1 );
                        else
                            preRead = insertText(preRead, posData, textData, 'TextColor', colourData , 'BoxColor', 'white', 'BoxOpacity', 0.1 );
                        end
                        %toc
                        
                        if runtimeWrite == 1
                            thisFrame = preRead;
                        end
                    end

                    if runtimeWrite == 1
                        proceed = 0;
                        while proceed ~= 1
                            try
                                writeVideo(vidWrite,thisFrame);
                                proceed = 1;
                            catch
                                proceed = proceed - 1;
                            end
                            if proceed < -10
                                ['## Alert: 10 subsequent write failures of video ##']
                                proceed = 0;
                                %crash = yes
                            end
                        end
                    end
                    
                    %Progress bar
                    if nansum(i == pFrames) > 0
                        progress = ( (find(pFrames == i) - 1) / size(pFrames,2) )*100;
                            %Find i in pFrames, back-calculate what percentage of completion that index relates to
                        eta = floor( (toc / progress) * ( 100 - progress ) );
                        fps = i / toc;    
                        disp([num2str(progress),'% complete (',num2str(toc),'s elapsed; ETA: ',num2str(eta),' s) - Frame ',num2str(i),' of ',num2str(size( annRail,1 )),' (',num2str(fps,'%0.1f'),'fps)'])
                    end
                    
                    if runtimeWrite ~= 1
                        k = k + 1;
                    end
                end
                
                %Close out runtime vids
                if runtimeWrite == 1
                    try
                        close(vidWrite);
                        disp(['- Video writing closed-'])
                    end
                end
                %--------Grea
                
                
            end
        %dispVids end
        end

        %-----------------------------------------------------------------------------------------------------------------------------

        %%

        %--------------------------------------------------------------------------
        %PSD and all that jazz
        if doPSD == 1
            if eStabGlob == 1
                fouriStruct = struct;
                fs = nanmedian( 1.0 ./ diff( overGlob.BaseFrameTime ) ); %Assumed limited variability
                for i = 1:size(inStruct.holeRanges,2)
                    %%i = 3;
                    %x = rightThetaSmoothed(inStruct.holeRanges{i})';
                    %%x = fakeData3;
                    %fs = 30; %Sampling rate of data
                    if incDorsData == 1
                        x = rightThetaSmoothed(inStruct.holeRanges{i})';
                    end
                    if incAntDLC == 1
                        x = overGlob.dlcDataProc.dlcRightAntennaAngleAdj_smoothed(inStruct.holeRanges{i});
                    end

                    % Compute the discrete Fourier transform of the signal. Find the phase of the transform and plot it as a function of frequency.
                    y = fft(x);
                    L = length(x);
                    P2 = abs(y/L);
                    P1 = P2(1:L/2+1);
                    P1(2:end-1) = 2*P1(2:end-1);
                    f = fs*(0:(L/2))/L; % find the frequency vector

                    fouriStruct(i).f = f;
                    fouriStruct(i).P1 = P1;

                    %%figure
                    %%plot(f,P1)
                    %%xlim([0 1])
                    %%ylim([0 1])
                end
            end
            %Plot all holes Fouriers
            try
                %Plot antennal angles during extracted sleep bouts ('holes')
                if eStabGlob == 1
                    figure
                    for i = 1:size(inStruct.holeRanges,2)
                        scrollsubplot(3,3,i)
                        plot(fouriStruct(i).f,fouriStruct(i).P1)
                        xlim([0 1])
                        ylim([0 1])
                        if i == 1
                            xlabel('Frequency (Hz)')
                        end
                        ylabel('Power (???)')

                        title(strcat(inStruct.holeStartsTimes(i), ' -- (k= ', num2str(i), ') -- ', inStruct.holeEndsTimes(i)))
                    end
                    set(gcf,'Name','Right antennal fouris')
                end
            catch
                ['## Warning: Could not plot PSDs ##']
            end
            
            %Plot specific fouri
            try
                specFour = 18;
                figure
                plot(fouriStruct(specFour).f,fouriStruct(specFour).P1)
                xlim([0 1])
                ylim([0 1])
                xlabel('Frequency (Hz)')
                ylabel(['Power'])
                title(['Specific right ant. fouri - ',dataFolderList{fol},' - hole ',num2str(specFour)])
            catch
                disp(['#- Could not plot specific fouri ',num2str(specFour),' #-'])
            end
        end

        %{
        preData = rightThetaSmoothed(inStruct.holeRanges{3});

        fakeData = []; %Ballooned data
        a = 1;
        b = 1;
        it = 1;
        for i = 1:size(preData,1)
            fakeData(b) = preData(a);
            b = b + 1;
            fakeData(b) = preData(a);
            b = b + 1;
            a = a + 1;
        end

        fakeData2 = []; %Squished data
        a = 1;
        b = 1;
        it = 1;
        for i = 1:size(preData,1)
            fakeData2(round(b,0)) = preData(a);
            b = b + 0.5;
            a = a + 1;
        end

        fakeData3 = []; %Flat data
        a = 1;
        b = 1;
        it = 1;
        for i = 1:size(preData,1)
            fakeData3(b) = preData(1);
            b = b + 1;
            a = 1 + 1;
        end

        %}
        %--------------------------------------------------------------------------

        %QA reiteration
        if skippedFiles ~= 0
            ['## Reiteration: ', num2str(skippedFiles), ' file/s had to be skipped (Probably for SwarmSight reasons) ##']
                %Note: Since this is probably only enacted for terminal files, it can only ever report a value of 1 here
        end
        
        successFile = successFile + 1;
    %{    
    catch
        ['## Alert: Critical error during processing of ',dataFolderList{fol}, ' ##']
        listOfErrorFiles(e).fol = fol;
        %listOfErrorFiles(IIDN).SaveName = [saveNameFull];
        listOfErrorFiles(e).Reason = ['General error'];
        numOfErrorFiles = numOfErrorFiles + 1; %May double up if crashes for certain reasons
        currentIsErrorDataset = 1;
        e = e + 1;
    end
    %}
    
['-- Finished analysis of dataset ', num2str(fol), ' of ', num2str(numDataFolders),' --']    
end
%folderwise end
%Note: Might want to armour this against normal errors and things

%==================================================================================================================================

if automation == 1
    ['-- ', num2str(successFile), ' datasets analysed successfully (of ', num2str(numDataFolders),' total detected datasets) --']
    dataFolderList
    ['-- ', num2str(probDatasets), ' datasets contained proboscis data --']
    ['-- ', num2str(dlcDatasets), ' datasets contained DeepLabCut data --']
    if numOfErrorFiles > 0
        disp(['### Not all datasets were successfully analysed ###'])
        for i = 1:size(listOfErrorFiles,2)
            if isempty(listOfErrorFiles(i).fol) ~= 1
                [strcat(num2str(listOfErrorFiles(i).fol), ' - ', dataFolderList(listOfErrorFiles(i).fol))]
            end
        end
    end
end
