%The script formerly known as preprocess_01_converttdt_Calibration_AllFlies_NoFilter1000Hz
%Mk 1 - Core functionality
%Mk 2 - Folder generalisation (for multiple experiments on one day)
%Mk 3 - Trimmed down use of cd
%    .25 - Network mode, Fixed chunk/block naming issues
%    .5 - Synapse support, MATLAB 2014b compatibility
%    .75 - Empty block armouring improvements
%    .85 - Synapse/Bruno improvements (12/5/21)
%Mk 4 - Integration of calib functionality
%    .25 - Generalisation of data import from Synapse (But not non-Synapse data)
%    .5 - Added subsampling alternative for resampling (04/06/21)
%Mk 5 - Generalisation for all datasets, not just Synapse (07/06/21), Added progIdent field to output files
%    .25 - Changes to resampling (No resampling applied if NaN resampleFreq, rather than resample with input frequency)
%    .35 - Improvements to better handle (and report) corrupted data blocks, QA for empty data
%    .55 - Manual calib block selection when multiple found

%%clc 
clear
close all

progIdent = mfilename;

%% Load all paths here.. 
%-------------------------------------------------
%Params (Mostly)
%{
    %Moved these to superMode for simplicity
networkMode = 0; %Whether to load data from network rather than local
if networkMode == 0
    %dataPath = 'D:\group_swinderen\Bruno\Data\'
    %outPath = 'D:\group_swinderen\Bruno\Processed\'
    dataPath = 'D:\group_swinderen\Matthew\TDTs\Data\'
    outPath = 'D:\group_swinderen\Matthew\TDTs\Processed\'
    %dataPath = 'D:\group_swinderen\Matthew\TEMP STORE\'
    %outPath = 'D:\group_swinderen\Matthew\TEMP STORE\'
else
    dataPath = 'I:\PHDMVDP002-Q1471\LFP\Analysis\Data\'
    outPath = 'I:\PHDMVDP002-Q1471\LFP\Analysis\Processed\'
end
%}
%-------------------------------------------------
%Flags (Mostly)
superMode = 1; %1 for Matt data, 2 for Bruno
if superMode == 1
    dataPath = 'D:\group_swinderen\Matthew\TDTs\Data\'
    outPath = 'D:\group_swinderen\Matthew\TDTs\Processed\'
    expName = 'Red'; %This is the name that will be looked for in all detected folders that exist within dataPath (probably)
        %Note: With Mk 4.25 wildcards no longer necessary here (And will in fact cause issues for tank detection)
        %Secondary note: Capitalisation important
    blockConvention = 'Block'; %This is the string that will be searched for in folders (e.g. if your convention is 'C:\TDT\Tanks\290421\block1' etc, then the blockConvention is 'block' and the value immediately after is the block number)
        %Note: For simplicity this can probably be left as "block", unless there is significant risk of overfinds within the data folders

    calibMode = 1; %Whether to analyse calib data
    if calibMode == 1
        findPolRevers = 1; %Whether to try find the polarity reversal for calb data
    end

    %%dataIsFromSynapse = 0 %Whether data was collected from Synapse (Removed in Mk 5)
    %%specialSubsampleFields = [{'POS_'}]; %These fields will be subsampled with a coordinate technique, rather than resampled
    specialSubsampleFields = [{'InpP'},{'OutP'},{'PDec'}];
        %This is intended for TTL and TTL-like fields that react...poorly to traditional resampling methods
    reSampleFreq = 200 % Desired Sampling Frequency (Set as NaN to use source framerate)
    stimChannelID = 'InpP'; %Designates which of the data streams is Input data (Leave blank to designate no stream as Input)
    dataChannelID = 'Wave'; %Ditto above, but for the LFP data
        %Currently these designators are only used for a little QA and some calib processing, since the idea here is to proceed towards full generalisation
            %This means that analysis scripts specifically referring to "EEG.stims" or "EEG.LFP" will need a small update to be compatible
        %It is possible to leave these fields empty if one wishes and the script should not (hopefully) crash
elseif superMode == 2
    %%dataPath = 'D:\group_swinderen\Bruno\Data\'
    %%outPath = 'D:\group_swinderen\Bruno\Processed\'
    dataPath = 'D:\group_swinderen\Matthew\TEMP STORE\'
    outPath = 'D:\group_swinderen\Matthew\TEMP STORE\Processed\'
    expName = 'TagTrials'; %This is the name that will be looked for in all detected folders that exist within dataPath (probably)
    blockConvention = 'block'; %This is the string that will be searched for in folders (e.g. if your convention is 'C:\TDT\Tanks\290421\block1' etc, then the blockConvention is 'block' and the value immediately after is the block number)
    calibMode = 0; %Whether to analyse calib data
    if calibMode == 1
        findPolRevers = 1; %Whether to try find the polarity reversal for calb data
    end
    specialSubsampleFields = [{'PHOT'},{'ARAA'}];
    reSampleFreq = 300 % Desired Sampling Frequency (Set as NaN to use source framerate)
    stimChannelID = 'ARAA'; %Designates which of the data streams is Input data (Leave blank to designate no stream as Input)
    dataChannelID = 'LFP1'; %Ditto above, but for the LFP data  
end
    
skipExistingFiles = 1; %Whether to skip analysis of already processed files

%-------------------------------------------------

%cd(dataPath)
%paths
addpath(genpath(['D:\group_swinderen\Matthew\Scripts\toolboxes\TDTMatlabSDK'])) %Required
addpath(genpath(['D:\group_swinderen\Matthew\Scripts\toolboxes\basefindpeaks']))
%addpath(genpath(['D:\group_swinderen\Bruno\Toolboxes\TDTMatlabSDK'])) %Required
%addpath(genpath(['D:\group_swinderen\Bruno\Toolboxes\basefindpeaks']))
%cd(raw_path);

%Begin actual processing
%fly_list = dir('*290520*'); % changed from Analyzed*
fly_list = dir([dataPath, filesep, '*']); % changed from Analyzed*
%expName = '*290421*';

if length(fly_list) == 0
    ['## ERROR: NO DATA FOUND ##']
    crash = yes
end
%Remove operating system 'folders' from fly_list
osExcludeList = [{'.'},{'..'}];
for osInd = 1:size(osExcludeList,2)
    for flyInd = size(fly_list,1):-1:1
        %if ( contains( fly_list(flyInd).name , osExcludeList{osInd} ) == 1 && size( fly_list(flyInd).name,2 ) == size(osExcludeList{osInd},2) )
        if ( isempty( strfind( fly_list(flyInd).name , osExcludeList{osInd} ) ) ~= 1 && size( fly_list(flyInd).name,2 ) == size(osExcludeList{osInd},2) )
            fly_list(flyInd) = [];
        end
    end
end
%Remove non-directory hits
for flyInd = size(fly_list,1):-1:1
    if fly_list(flyInd).isdir ~= 1
        fly_list(flyInd) = [];
    end
end

%Prepare QA for corrupted blocks
grandFailList = []; %Will hold list of all blocks which failed preprocessing
grandFailIt = 0; 

for fly_number = 1:length(fly_list)
    disp([char(10),'#######################################################################################################'])
    % locpathappend = Path1;

    %% Dataset path here..
    datasetname = [fly_list(fly_number).name];

    datasetname

    %datasetPath = [dataPath,filesep, datasetname];
    datasetPath = [dataPath, datasetname]; %dataPath contains a filesep under normal conditions anyway
        %Folder structure reminder:
        %"...\Data\<Date of experiment (i.e. 031220)>\<Block name (i.e. 031220_Overnight)>\Block <1 : etc>"

    %all_dir = dir([datasetPath, filesep, expName]);
    all_dir = dir([datasetPath, filesep, '*']);
    validAllSets = [];
    a = 1;
    for i = 1:size(all_dir,1)
        if calibMode == 0 %"Not running in calib preprocess mode"
            if isempty(strfind(all_dir(i).name, 'Calib')) == 1 && isempty(strfind(all_dir(i).name, '.')) == 1 && isempty(strfind(all_dir(i).name, expName)) ~= 1
                validAllSets{a} = all_dir(i).name;
                a = a + 1;
            end
        else %"Yes calib preprocess"
            if isempty(strfind(all_dir(i).name, 'Calib')) ~= 1 && isempty(strfind(all_dir(i).name, '.')) == 1
                validAllSets{a} = all_dir(i).name;
                a = a + 1;
            end
        end
    end
    disp(['-- ', num2str(a-1), ' valid datasets detected for ',datasetname, ' --'])
    
    if size(validAllSets,2) == 0
        ['## ALERT: NO VALID "',expName,'" DATA DETECTED FOR ', datasetname, ' ##']
        continue
    end

    varSaveList = who;
    varSaveList = [varSaveList; {'varSaveList'}; {'subExpNum'}];
    
    for subExpNum = 1:size(validAllSets,2)        
        %close all
        clearvars('-except',varSaveList{:})
        thisSubExpName = validAllSets{subExpNum};
        disp(['------------------------------------------------------------------------'])
        disp(['-- Now processing ',thisSubExpName, ' (',num2str(subExpNum), ' of ', num2str(size(validAllSets,2)), ') --'])
        
        allsetname = validAllSets{subExpNum};
        %cd(allsetname)

        %%cd([dataPath, filesep, datasetname, filesep, allsetname]) %Full location referencing because relative referencing fails in loops
        % calib_data_path = [data_path filesep calibsetname];
        % cd(calib_data_path)
        %allsetPath = [dataPath, filesep, datasetname, filesep, allsetname];
        allsetPath = [dataPath, datasetname, filesep, allsetname]; %Removed filesep because terminal filesep already existing in dataPath

        detExpName = strrep(allsetname, datasetname, ''); %Determine experiment title
        %QA in case of name emptiness
        if isempty(detExpName) == 1 %This can happen with odd names (e.g. "TESTTANK" and so on)
            detExpName = datasetname;
        end
        while nanmin(strfind(detExpName,'_')) == 1
            detExpName(1) = ''; %Remove proximal underscores
        end

        %block_list = dir('Block*'); % changed from Analyzed*

        %New
        %blockMode = 0; %Determines whether blocks are readily detectable (OpenEx) or if they are in a more...arcane format (Synapse)
        block_list = dir([allsetPath,filesep,'*',blockConvention,'*']); % changed from Analyzed*
        if isempty(block_list) == 1 %&& dataIsFromSynapse == 1
            disp(['#- Warning: No detected blocks with name "',blockConvention,'"; Attempting with expName ("',expName,'") instead #-'])
            block_list = dir([allsetPath,filesep,'*',expName,'*']);
            %blockMode = 1; %Switch to Synapse mode
        %elseif isempty(block_list) == 1 %&& dataIsFromSynapse == 0
        %    ['## Alert: No valid block detected ##']
        %    crash = yes
        end
        if isempty(block_list) == 1
            ['## No blocks found ##']
            continue
        end
        
        %Check if calib
        if calibMode == 1 && size(block_list,1) > 1
            ['-# Multiple calib blocks detected; Please specify which to use #-']
            for tempInd = 1:size(block_list,1)
                disp([num2str(tempInd),' - ', block_list(tempInd).name])
            end
            whichBlock = input('Block selection: ')
            block_list = block_list(whichBlock)
        end

        numErrorChunks = 0; %Hopefully will not iterate, but may do if there are empty data blocks/etc
        thisChunkIsError = 0; %Will be overwritten later if case
        
        totalchunks = length(block_list);

        %New
        for blockInd = 1:size(block_list,1)
            %unPos = strfind(block_list(blockInd).name,'-'); %Old, searched for hyphen
            unPos = strfind(block_list(blockInd).name,blockConvention); %New, searches for word 'block'
            if isempty(unPos) ~= 1
                block_list(blockInd).blocknumber = str2num( block_list(blockInd).name(unPos+size(blockConvention,2):end) );
            else
                ['## Alert: Block identity could not be derived from block name ##']
                crash = yes
            end
        end
        temp = struct2table(block_list); % convert the struct array to a table
        temp = sortrows(temp, 'blocknumber'); % sort the table by blocknumber
            %Note: Unstable use of temp but w/e
        block_list = table2struct(temp);

        for chunkidx = 1:totalchunks
            
            processingStartTime = clock;
            %%Step 1: Extract data in segments of 1 hour each..
            %blockname = ['Block-' char(sprintf("%d",chunkidx))]; %Old
            blockname = [block_list(chunkidx).name]; %New
            %blockpath = [allsetname filesep blockname];
            %%blockPathFull = [dataPath, filesep, datasetname, filesep, blockpath];
            blockPathFull = [allsetPath, filesep, blockname];
            blockID = blockname(strfind(blockname, '-')+1:end);
            if size(blockID,2) < 2
                blockID = ['0',blockID]; %Cover for up to block 99
            end
            
            %Detect if Synapse data
            dataIsSynapse = 0; %Default
            synapsePresence = dir([blockPathFull, filesep, '*.tin']); %.tin files (apparently) unambiguously indicate Synapse was used to record
            if isempty( synapsePresence ) ~= 1
                dataIsSynapse = 1;
            else
                dataIsSynapse = 0;
            end

            disp([char(10),'-- Reading detected block #',num2str(chunkidx),' (',blockname,') of ',num2str(totalchunks),' --'])
            %blockpath = char(horzcat(blockpath(1:length(blockpath))));

            locpathappend = [outPath, datasetname];
            %outputfolder = [locpathappend filesep 'LFP' filesep 'Analyzed_LFP_' blockname];
            outputfolder = [locpathappend filesep 'LFP' filesep 'Analyzed_' detExpName '_' blockname];
            S.output_folder  = outputfolder;
            %S.eeg_filename = [datasetname  '_chunk_' char(sprintf("%0.2d",chunkidx))];
            S.eeg_filename = [datasetname,  '_chunk_', blockID]; %Dynamic detection of block/chunk number
            mat_name = [S.output_folder filesep S.eeg_filename '.mat'];
            
            try
                fileIsExist = isfile(mat_name); %Will fail on MATLAB 2014b, but that's why this is in a try-catch
            catch
                fileIsExist = exist(mat_name);
            end
            if fileIsExist ~= 0 && skipExistingFiles == 1
                warning('Block already processed. Skipping file.');
                continue
            elseif fileIsExist ~= 0 && skipExistingFiles == 0
                disp(['-# Block already exists but files requested not to be skipped #-'])
            end
            %check the timeduration to start and end..
            tdt_dur_load = 0;
            a = 0; %Iterator to prevent infiniloop
            %tdt_load_count =0;
            tic
            while tdt_dur_load == 0 && a < 3
                try
                 %[timeduration, info] = TDTduration(blockpath);
                    [timeduration, info] = TDTduration(blockPathFull);
                    disp('TDTduration read successful.');
                    tdt_dur_load = 1;
                catch
                    disp(['TDTduration read failed; Retrying (in 5s)...'])
                    pause(5)
                    a = a + 1;
                end
            end
            if tdt_dur_load == 0
                ['## Alert: TDT duration could not be successfully read ##']
                %crash = yes
                numErrorChunks = numErrorChunks + 1;
                grandFailIt = grandFailIt + 1;
                grandFailList{grandFailIt} = [datasetname,'-',blockname];
                disp(['(Skipping)'])
                continue
            end
            
            disp(['TDTduration performed in ',num2str(toc),'s'])

            %fprintf('Reading detected block %d of %d..\n', chunkidx, totalchunks);
            

            %fprintf('Total time duration of recording is: %0.2f secs..\n', timeduration);

            if ~isdir(locpathappend)
                mkdir(locpathappend);
            end

            %check the timeduration to start and end.

            %fprintf('Reading block %d of %d..\n', chunkidx, totalchunks);
 
            fprintf('Total time duration of recording is: %0.2f secs..\n', timeduration);
            fprintf('Equivalent to: %0.2f minutes..\n', timeduration/60);

            starttime = 0;
            endtime = timeduration;
            
            %#########################
            %QA for corrupted chunk
            if isfield(info,'headerstoptime') ~= 1
                ['-# Warning: headerstoptime is missing from chunk; Approximating value #-']
                info.headerstoptime = info.headerstarttime + endtime; %May not be identical to proper data
            end
            %#########################
                        
            %data = TDTbin2mat(blockpath, 'T1', starttime, 'T2', endtime);
            block_read = 0;
            %block_read_count = 0;
            a = 0;
            while block_read == 0 && a < 10
                try
                    data = TDTbin2mat(blockPathFull);
                    disp('TDTbin2mat read successful.')
                    block_read = 1;
                catch
                    disp(['TDTbin2mat read failed; Retrying (in 10s)...'])
                    pause(10)
                    a = a + 1;
                    %{
                    warning('TDTbin2mat read unsuccessful. Trying again in 30 seconds...')
                    pause(30)
                    block_read = 0;
                    block_read_count = block_read_count +1;
                    if block_read_count == 5
                        warning('TDTbin2mat read failed too many times. Skipping file.');
                        block_read = 1;
                        continue
                    end
                    %}
                end
            end
            if block_read == 0
                ['## Alert: Detected chunk #',num2str(chunkidx),' - ',blockname,' could not be read ##']
                crash = yes
            end
                  
            %Returned data
                %Note: The structure formerly known as waveData has been renamed allData in Mk 5 to reflect its now-generalised nature
            %New, generalised system that is same between Synapse and non-Synapse data
            try
                dataFiels = fieldnames(data.streams);
                allData = struct;
                for fielInd = 1:size(dataFiels,1)
                    allData.(dataFiels{fielInd}) = data.streams.(dataFiels{fielInd}); %Note: This means that Synapse data has a fundamentally different (Read: Expanded) architecture compared to non-Synapse
                end
            catch
                ['## Warning: Error collecting real data for chunk #',num2str(chunkidx),' - ',blockname,' ##']
                thisChunkIsError = 1; %Flag
                allData = struct;
                allData.data = []; %Blank these for less effort error handling
                allData.fs = reSampleFreq;  %This cannot be blank else the rat fails
                chandata_resamp = []; %Generate a blank value for this ahead of time, since it won't be generated by the normal loop (Because chandata size 0)
                dataFiels = [];
            end
            
            disp(['Data fields: ',transpose(dataFiels)])
            

            %set the starttime in the eeglab struct..
            eegtimestart = info.headerstarttime + starttime;
            eegtimeend = info.headerstarttime + endtime;

            %%Step 2:  Downsample the data..
            
            %###
            if isnan(reSampleFreq) == 1 
                disp(['-- NaN resample frequency specified; Data will not be resampled --'])
            end
            
            %New
            %Iterate across all, regardless of 'real' data or input data
            allData_resamp = [];
            resFreqs = []; %Stores the calculated resample freqs
            for fielInd = 1:size(dataFiels,1) %Use dataFiels from above

                thisFiel = dataFiels{fielInd};
                
                subSampleProceed = 0; %Will be adjusted if such
                for subInd = 1:size(specialSubsampleFields,2)
                    if nansum( thisFiel == specialSubsampleFields{subInd} ) == size(thisFiel,2) %"Field name is perfect match for an element of specialSubsampleFields"
                        subSampleProceed = 1;
                        disp(['-- Field ',thisFiel,' will be subsampled as per request --'])
                    end
                end
                
                inputfreq = allData.(thisFiel).fs;% Actual Sampling Frequency (Now dynamic between Synapse and OpenEx)
                %%thisData = chandata.(thisFiel).data;
                thisData = allData.(thisFiel).data;
                if isnan(reSampleFreq) ~= 1
                    resamplefreq = reSampleFreq; % Desired Sampling Frequency 
                    [N,D] = rat(resamplefreq/inputfreq); % Rational Fraction Approximation
                    
                    if subSampleProceed == 1
                        %'New' artefact-free subsampling
                        subCoords = round([1 : inputfreq/reSampleFreq : size(thisData,2)]); 
                            %Note: Will introduce variably sized timing errors depending on much of a not-multiple reSampleFreq is into inputfreq
                        %Quick supersampling QA
                        if reSampleFreq > inputfreq
                            ['-# Caution: reSampleFreq (',num2str(reSampleFreq),'Hz) exceeds inputfreq (',num2str(inputfreq),'Hz); Oversampling will occur #-']                            
                        end
                        allData_resamp.(thisFiel) = []; %Clear each time
                        for idx = 1:size(thisData,1)
                            allData_resamp.(thisFiel)(idx,:) = nan( 1, size( resample(double(thisData(idx,:)), N, D) ,2 ) ); %Use alternative system to derive proper length
                            %Quick QA in case subsampling larger
                            if size( subCoords , 2 ) > size( allData_resamp.(thisFiel) , 2 )
                                ['-# Caution: Subsampling coordinates larger than resampled data; subCoords have been truncated #-']
                                subCoords = subCoords( 1 : size( allData_resamp.(thisFiel) , 2 ) );
                            end
                            allData_resamp.(thisFiel)(idx,1:size(subCoords,2)) = double( thisData(idx,subCoords) );% Subsampled Signal
                                %Note: This method can be up to inputfreq/reSampleFreq points different in length from data sampled the other way
                                    %E.g. Subsampling a 3Khz signal at 200Hz means that every ~15th point is grabbed and thus the resampled data
                                    %can be only ever exactly as long or up to 15 points shorter (based on how MATLAB iterators work)
                        end    
                    else
                        %'Old' system
                        %[N,D] = rat(resamplefreq/inputfreq); % Rational Fraction Approximation
                        allData_resamp.(thisFiel) = []; %Clear each time
                        for idx = 1:size(thisData,1)
                            %allData_resamp.(thisFiel)(idx,:) = resample(double(chandata.(thisFiel).data(idx,:)), N, D);% Resampled Signal  
                            allData_resamp.(thisFiel)(idx,:) = resample(double(thisData(idx,:)), N, D);% Resampled Signal  
                        end
                    end
                    
                    
                else
                    resamplefreq = inputfreq;
                    
                    allData_resamp.(thisFiel) = allData.(thisFiel);
                    
                    if subSampleProceed == 1
                       disp(['-# Field ',thisFiel,' was requested to be subsampled, but NaN resampling is in effect -#']) 
                    end
                    
                end
                %[N,D] = rat(resamplefreq/inputfreq); % Rational Fraction Approximation %Removed from here in Mk5.25 in accordance with "No Resample When NaN"
                
                resFreqs(fielInd) = resamplefreq;
                
            end

            %###
            
            
            %Calculate size disparity between virtual and real channels, if any
            if ( isempty(stimChannelID) ~= 1 && isempty(dataChannelID) ~= 1 ) && ( isempty(allData.(stimChannelID)) ~= 1 && isempty(allData.(dataChannelID)) ~= 1 )
                %New
                virtualDur =  ( size(allData.(stimChannelID).data,2) / allData.(stimChannelID).fs );
                dataDur = ( size(allData.(dataChannelID).data,2) / allData.(dataChannelID).fs );
                if abs(dataDur - virtualDur) >= 0.001 %Disparity larger than 1ms
                    disp(['# Warning: Size disparity of approx. ',num2str(dataDur - virtualDur),'s exists between real and virtual channels #'])
                end
            end
                      
            %%clear chandata_resamp stimdata_resamp

            %%Step 3:  Store it in a EEGlab file.. % note RJ: this is not clock time, but time of recording
            samplerate = resamplefreq; %Use resample frequency as go-forward sampling rate

            timeres = 1/samplerate;
            Tottime = endtime - starttime - timeres; %60 min duration..
            timepoints = 0: timeres : Tottime;

            %%Step 4: Create EEGlab file for LfP data..
            EEG = [];
            EEG.setname = [blockname];
            EEG.filename = [datasetname];
            % EEG.filepath = [calib_data_path];
            %New, full generalised structure
            for fielInd = 1:size(dataFiels,1)
                if isstruct( allData_resamp.(thisFiel) ) ~= 1
                    thisFiel = dataFiels{fielInd};
                    EEG.(thisFiel).nbchan = size(allData_resamp.(thisFiel),1);
                    EEG.(thisFiel).data = double(allData_resamp.(thisFiel));
                    EEG.(thisFiel).pnts = length(allData_resamp.(thisFiel));
                    EEG.(thisFiel).chanlocs(1).labels = thisFiel;
                else
                    thisFiel = dataFiels{fielInd};
                    EEG.(thisFiel).nbchan = size(allData_resamp.(thisFiel).data,1);
                    EEG.(thisFiel).data = double(allData_resamp.(thisFiel).data);
                    EEG.(thisFiel).pnts = length(allData_resamp.(thisFiel).data);
                    EEG.(thisFiel).chanlocs(1).labels = thisFiel;
                end
                %QA for empty data (Re: The Great Photodiode Phuckening of 2022)
                if superMode == 1 && nansum( nansum( EEG.(thisFiel).data ) ) == 0
                    ['## ALERT: NO NON-ZERO DATA DETECTED IN ',thisFiel,' ##']
                        %This may aberrantly proc for legacy data with empty InpP and/or PDec but should not occur on modernData
                        %It may also accidentally proc on Bruno data, hence superMode subspecification
                    %if chunkidx == totalchunks && timeduration < 300 %Note: chunkidx assumption will fail if analysing calib/etc data in same folder as well
                    if chunkidx == 1 || timeduration < 300 %Note: Script operates in reverse to recording, so chunkidx 1 is actually last block
                        disp('(But it is likely that this is the end of the recording or a truncated block)')
                    else
                        crash = yes
                    end
                end
            end
            EEG.dataFiels = dataFiels;
            EEG.stimChannelID = stimChannelID;
            EEG.dataChannelID = dataChannelID;
                       
            %%EEG.stims = double(STIM); %Disabled in Mk 5
            EEG.times  = timepoints;
            EEG.xmax = max(EEG.times);
            EEG.xmin = min(EEG.times);

            EEG.icawinv =[];
            EEG.icaweights =[];
            EEG.icasphere =[];
            EEG.icaact = [];
            EEG.trials = 1;
            EEG.srate = samplerate;
            
            %Matt additions of useful
            try
                %EEG.sourceFramerates.InpP = data.streams.InpP.fs;
                EEG.sourceFramerates.InpP = allData.(stimChannelID).fs;
            catch
                EEG.sourceFramerates.InpP = [];
            end
            %EEG.sourceFramerates.Wave = data.streams.Wave.fs;
            if isfield(allData,'fs') == 1
                EEG.sourceFramerates.Wave = allData.fs;
            else
                for fielInd = 1:size(dataFiels,1)
                    thisFiel = dataFiels{fielInd};
                    EEG.(thisFiel).sourceFramerates.Wave = allData.(thisFiel).fs; %This is a bit of unnecessary architecture but it might be important
                end
            end

            %evalexp = 'eeg_checkset(EEG)'; %Seems to be redundant
            % [T,EEG] = evalc(evalexp);

            tmpval = datestr(datenum([1970, 1, 1, 0, 0, eegtimestart]),'HH:MM:SS');
            d = datetime(tmpval,'TimeZone','UTC');
            d.TimeZone = 'Australia/Brisbane';
            eegtimestart = datestr(d,'HH:MM:SS');
            tmpval = datestr(datenum([1970, 1, 1, 0, 0, eegtimeend]),'HH:MM:SS');
            d = datetime(tmpval,'TimeZone','UTC');
            d.TimeZone = 'Australia/Brisbane';
            eegtimeend = datestr(d,'HH:MM:SS');

            EEG.timestart = eegtimestart;
            EEG.timeend = eegtimeend;

            % Added by RJ 01/05/2019 % the info structure from TDTduration has
            % posixtime information inside, so I will use this for relating the video
            % to the data file.
            EEG.info = info;
            %date_format = 'yyyy:mm:dd';% '2016-07-29 10:05:24'; from posixtime Matlab website

            EEG.epoch_start = EEG.info.headerstarttime;
            EEG.epoch_end = EEG.info.headerstoptime;
            
            %New
            for fielInd = 1:size(dataFiels,1)
                thisFiel = dataFiels{fielInd};
                EEG.(thisFiel).epoch_times = linspace(EEG.info.headerstarttime, EEG.info.headerstoptime, length(EEG.(thisFiel).data));
                %QA
                if size(EEG.(thisFiel).epoch_times,2) ~= size(EEG.(thisFiel).data,2)
                    ['## Alert: Disparity between size of epoch_times and source data ##']
                    crash = yes
                end
            end

            % EEG.stimdata_resamp = stimdata_resamp;

            %EEG.data(17,:) = stimdata_resamp;
            
            EEG.ancillary.preprocessIdent = progIdent; %Stores the name of this script in the EEG file
            EEG.ancillary.dataIsSynapse = dataIsSynapse; %Stores whether the data detected to be from Synapse
                %This is intended to be a lazy way to post-hoc know if data was analysed with a new version of preprocessing

            %fprintf('Block %d start time: %s...\n',chunkidx,eegtimestart);
            %fprintf('Block %d end time: %s...\n',chunkidx,eegtimeend);
            disp(['Block #',num2str(chunkidx),' start time: ',eegtimestart,'...']);
            disp(['Block #',num2str(chunkidx),' end time: ',eegtimeend,'...']);
            
            %#######
            %Step 4.5 - Find pol. reversal if requested for calib data (Note: Will probably crash horribly on Synapse data)
            if calibMode == 1 && findPolRevers == 1
                polReverseChan = [];
                %Find stimulus peaks (all)
                stimSepTime = 1; %Assumed time between calibration peaks (s)
                
                %Find stimulus data (By looping if necessary)
                prosChan = 1;
                proceed = 0;
                while proceed == 0 && prosChan <= size(  EEG.(stimChannelID).data , 1 )
                    %New
                    stimData = EEG.(stimChannelID).data(prosChan,:); %Only take row 1 of stims
                    %Old
                    %stimData = EEG.stims(1,:); %Only take row 1 of stims
                    stimDataMean = nanmean(stimData);
                    stimDataSD = nanstd(stimData(1:EEG.srate)); %Use 1st second of data to find std

                    %##
                    [stimDataHist, stimDataHistCenters] = hist(stimData,256); %Make hist
                    stimDataHist(1:floor(size(stimDataHist,2)*0.75)) = NaN; %Remove lower 75% of data
                    [ ~ , stimSignalConsistentPeakHeightIdx] = nanmax(stimDataHist); %Find bin position of peak of hist (Coincides with peak of sine wave)
                    stimSignalConsistentPeakHeight = stimDataHistCenters(stimSignalConsistentPeakHeightIdx); %Find Y value of bin position
                    %##

                    %[stimPKS,stimLOCS] = findpeaks(stimData,'MinPeakHeight',stimDataMean+2*stimDataSD, 'MinPeakDistance',stimSepTime*EEG.srate*0.75);
                        %"Find peaks more than mean+2*SD in height, separated by at least 75% of a cycle"
                    [stimPKS,stimLOCS] = findpeaksbase(stimData,'MinPeakHeight',stimSignalConsistentPeakHeight-0.25*stimSignalConsistentPeakHeight, 'MinPeakDistance',stimSepTime*EEG.srate*0.25);
                        %Same as above version, except MinPeakDistance is reduced to 25% to catch both start and end spikes (this will factor into following filtering)
                    %[stimPKS,stimLOCS] = findpeaks(stimData,'MinPeakProminence',8*stimDataSD, 'MinPeakDistance',stimSepTime*EEG.srate*0.25);
                        %Same again, but swapped MinPeakHeight for MinPeakProminence, to account for non-zero baselines
                    %Filter stimPeaks according to whether they are onset or offset
                    stimLOCSProc = []; %Filtered copies of parents
                    stimPKSProc = [];
                    for i = 1:size(stimLOCS,2)
                        if floor(stimLOCS(i) + stimSepTime*EEG.srate*0.25) < length(stimData) && stimData( floor(stimLOCS(i) + stimSepTime*EEG.srate*0.25) ) >= stimDataMean+4*stimDataSD
                            stimLOCSProc = [stimLOCSProc,stimLOCS(i)];
                            stimPKSProc = [stimPKSProc,stimPKS(i)];
                        end
                    end
                    %QA
                    if isempty(stimLOCSProc) == 1 %|| size(stimLOCSProc,2) > 36*3 %First statement is complete miss of detection (or no stims), Second statement is potential overfind
                        ['#- Warning: No stimuli found in input channel ',num2str(prosChan),' -#']
                        %crash = yes
                        prosChan = prosChan + 1;
                    else
                        disp(['-- Stimulus data successfully detected in input channel ',num2str(prosChan),' --'])
                        proceed = 1;
                    end
                end
                %QA
                if isempty(stimLOCSProc) == 1 %|| size(stimLOCSProc,2) > 36*3 %First statement is complete miss of detection (or no stims), Second statement is potential overfind
                    ['#- Warning: No stimuli found in any input channel -#']
                    figure
                    for chan = 1:size( EEG.(stimChannelID).data , 1 )
                        plot( EEG.(stimChannelID).data(chan,:) )
                        hold on
                    end
                    crash = yes
                end
                
                %Testatory figure
                figure
                plot(stimData, 'b')
                hold on
                scatter(stimLOCS,stimPKS,'k')
                scatter(stimLOCSProc,stimPKSProc,'g')
                %title([datasetname,' - ',allsetname,' - Stim data (all peaks - black, valid peaks - green)'])
                title([datasetname,' - ',allsetname,' - Stim data (all peaks - black, valid peaks - green)'])

                %Collect channel data at all stim peaks into hyperData
                captureWindowSize = floor(stimSepTime*EEG.srate*0.4); %Collect 90% of cycle following stimulus onset
                %New
                lfpData = EEG.(dataChannelID).data;
                %Old
                %lfpData = EEG.data;
                lfpDataProc = lfpData - nanmean(lfpData,2); %Adjust to mean (Note dimension specification)
                for chanInd = 1:size(lfpDataProc,1)
                    lfpDataProc(chanInd,:) = smooth(lfpDataProc(chanInd,:),20); %Arbitrarily smooth
                        %Note: Smoothing may affect detections
                end

                stimHyperData = [];
                for i = 1:size(stimLOCSProc,2)
                    stimHyperData(:,:,i) = lfpDataProc(:, stimLOCSProc(i):stimLOCSProc(i)+captureWindowSize );
                end

                meanHyperData = nanmean(stimHyperData(:,:,:),3);

                %Calculate local maxima within capture window (for each channel)
                tfData = [];
                firstTFs = [];
                for chanInd = 1:size(stimHyperData,1)
                    %%tfData(chanInd,:) = islocalmax(meanHyperData(chanInd,:),'MinProminence',nanmax(meanHyperData(chanInd,:))/2); %Use half max as threshold
                    %tfData(chanInd,:) = islocalmax( abs(meanHyperData(chanInd,:)),'MinProminence', nanmax(abs(meanHyperData(chanInd,:)))/2 ); %Use half max as threshold
                    tfData(chanInd,:) = islocalmax( abs(meanHyperData(chanInd,:)),'MinProminence', nanmax(abs(meanHyperData(chanInd,:)))/4 ); %Use quarter max as threshold
                    tfData(chanInd,1:10) = NaN; %Artefact detection removal
                    if nansum(tfData(chanInd,:)) >= 1
                        firstTFs(chanInd) = find(tfData(chanInd,:) == 1,1);
                    else
                        firstTFs(chanInd) = NaN; %No TF found
                    end
                end

                %Find channel values at median first TF location
                medianFirstTF = floor(nanmedian(firstTFs));
                channelVals = meanHyperData(:,medianFirstTF);
                channelValsDeflection = abs(channelVals - nanmean(meanHyperData,2)); %These values represent which channels were most deviated from their own mean during the first TF
                [~,prosPolReverseChanMin] = nanmin(channelValsDeflection);

                %Testatory to show vals
                figure
                plot(channelVals, '-or')
                hold on
                plot(channelValsDeflection, '-ob')
                title([datasetname,' - ',allsetname,' - Values of channels at first TF'])

                %QA
                if prosPolReverseChanMin >= 15 || prosPolReverseChanMin <= 8
                    ['#- Warning: Detected polarity reversal channel index (',num2str(prosPolReverseChanMin),') outside of expected range -#']
                    %crash = yes %May be overkill
                end
                %Check to see if next or prior channel was a flip
                confirmedFlip = 0;
                if prosPolReverseChanMin ~= size(stimHyperData,1) &&  prosPolReverseChanMin ~= 1
                    if ( abs(channelVals(prosPolReverseChanMin-1)) ~= channelVals(prosPolReverseChanMin-1) && abs(channelVals(prosPolReverseChanMin+1)) == channelVals(prosPolReverseChanMin+1) ) || ...
                            ( abs(channelVals(prosPolReverseChanMin-1)) == channelVals(prosPolReverseChanMin-1) && abs(channelVals(prosPolReverseChanMin+1)) ~= channelVals(prosPolReverseChanMin+1) )
                        disp(['-- Polarity flip confirmed around prospective (minima) channel ',num2str(prosPolReverseChanMin),' --'])
                            %Note: Does not check for more than one flip
                        confirmedFlip = 1;
                    else
                        ['#- Warning: No polarity flip detected around prospective (minima) channel ',num2str(prosPolReverseChanMin),' -#']
                        confirmedFlip = 0;
                    end
                end

                %Find literal polarity reversal by iterating through all channels
                prosPolReverseChanFlips = [];
                numPolFlips = 0;
                for i = 2:size(stimHyperData,1)-1
                    if ( abs(channelVals(i-1)) ~= channelVals(i-1) && abs(channelVals(i+1)) == channelVals(i+1) ) || ...
                            ( abs(channelVals(i-1)) == channelVals(i-1) && abs(channelVals(i+1)) ~= channelVals(i+1) )
                            %"Find when prior channel is negative and current is positive OR prior is positive and current is negative"
                        if confirmedFlip ~= 1
                            disp(['-- Polarity flip confirmed around channel ',num2str(i),' --'])
                        end
                        numPolFlips = numPolFlips + 1;
                        %if numPolFlips == 1
                        prosPolReverseChanFlips = [prosPolReverseChanFlips,i];
                        %end
                    else
                        if confirmedFlip ~= 1
                            disp(['#- Warning: No polarity flip detected around channel ',num2str(i),' -#'])
                        end
                    end
                end
                
                %Testatory (Shift with processing writing)
                figure
                for chanInd = 1:size(stimHyperData,1)
                    %plotData = nanmean(stimHyperData(chanInd,:,:),3);
                    plotData = meanHyperData(chanInd,:); %Original
                    %%plotData = plotData - plotData(1); %Correct start to 0
                    %%plotData = abs(plotData); %Abs as used for firstTFs calculations (Optional)
                        %Note: Not completely representative, given lack of 0 correction in firstTFs calculation
                    %Minima result
                    if chanInd == prosPolReverseChanMin
                        plot( plotData , 'LineWidth' , 2 , 'Color', 'k', 'LineStyle', ':' )
                    end
                    %Flip result
                    if isempty(prosPolReverseChanFlips) ~= 1 && chanInd == prosPolReverseChanFlips(1)
                        plot( plotData , 'LineWidth' , 2 , 'Color', 'g', 'LineStyle', '--' )
                    end
                    plot( plotData )
                    hold on
                    %pause(1)
                    %(Attempt to) Add in first TF location
                    try
                        scatter(firstTFs(chanInd),plotData( firstTFs(chanInd) ))
                        text(firstTFs(chanInd),plotData( firstTFs(chanInd) ),num2str(chanInd), 'FontSize', 9, 'Color', 'r')
                    end
                    
                end
                title([datasetname,' - ',allsetname,' - Average ERPs at stimulus onset (G-First flip, K-Minima)'])

                %See if minima method and flip method agree on polarity reversal location
                if isempty(prosPolReverseChanFlips) ~= 1
                    if prosPolReverseChanFlips(1) == prosPolReverseChanMin
                        disp(['-- Polarity reversal (minimum) and first polarity reversal (flip) agree (',num2str(prosPolReverseChanMin),') --'])
                        polReverseChan = prosPolReverseChanMin;
                    else
                        ['#- Polarity reversal (minimum) and Polarity reversals (flip) disagree (',num2str(prosPolReverseChanMin),' vs ',num2str(prosPolReverseChanFlips(1)),'); Using first flip channel (',num2str(prosPolReverseChanFlips(1)),') -#']
                        polReverseChan = prosPolReverseChanFlips(1);
                    end
                else
                    ['#- Polarity reversals (flip) list is empty; Using minima result (',num2str(prosPolReverseChanMin),') -#']
                     polReverseChan = prosPolReverseChanMin;
                end

                EEG.detectedPolReversalChan = polReverseChan;

                %Pretty plot
                figure
                maxVal = nanmax(nanmax(stimHyperData(:,:,end)));
                for chanInd = 1:size(stimHyperData,1)
                    %plotData = meanHyperData(chanInd,:); %Original
                    plotData = stimHyperData(chanInd,:,end); %Original
                    plotData = plotData - plotData(1) + (size(stimHyperData,1)-chanInd)*maxVal ; %Correct start to 0
                    %%plotData = abs(plotData); %Abs as used for firstTFs calculations (Optional)
                        %Note: Not completely representative, given lack of 0 correction in firstTFs calculation
                    %{
                    %Minima result
                    if chanInd == prosPolReverseChanMin
                        plot( plotData , 'LineWidth' , 2 , 'Color', 'k', 'LineStyle', ':' )
                    end
                    %Flip result
                    if isempty(prosPolReverseChanFlips) ~= 1 && chanInd == prosPolReverseChanFlips(1)
                        plot( plotData , 'LineWidth' , 2 , 'Color', 'g', 'LineStyle', '--' )
                    end
                    %}
                    plot( plotData, 'LineWidth', 1.25 )
                    hold on
                    %pause(1)
                    %{
                    %Add in first TF location
                    scatter(firstTFs(chanInd),plotData( firstTFs(chanInd) ))
                    text(firstTFs(chanInd),plotData( firstTFs(chanInd) ),num2str(chanInd), 'FontSize', 9, 'Color', 'r')
                    %}
                end
                title([datasetname,' - ',allsetname,' - Stacked ERPs at stimulus onset (fs: ',num2str(resamplefreq),')'])
                xlim([0,size(plotData,2)])
                %taishi

            end            
            %#######

            %%Step 5: Create EEGlab file for LfP data..
            S = [];
            %S.eeg_filename = [datasetname  '_chunk_' char(sprintf("%0.2d",chunkidx))];
            S.eeg_filename = [datasetname,'_chunk_',num2str(blockID)];
            try
                S.eeg_filename = [char(horzcat(S.eeg_filename{1:length(S.eeg_filename)}))];
            catch
                S.eeg_filename = [char(horzcat(S.eeg_filename(1:length(S.eeg_filename))))];
            end
            % S.output_folder  = outputfolder; % I had to add char(horzcat( due to the
            % way the new code finds the directory to loop through
            outputfolder = char(horzcat(outputfolder(1:length(outputfolder))));
            S.output_folder  = outputfolder;

            %fprintf(['Saving to %s.set.\n',S.eeg_filename]);
            disp(['-- Attempting to save to ',S.eeg_filename, ' --'])

            new_dir = outputfolder;
             if ~isdir(new_dir)
                 mkdir(new_dir);
             end
             save_flag = 0;

             while save_flag == 0
                 try
                     %  pop_saveset(EEG,'filepath',S.output_folder,'filename',[S.eeg_filename '.set']);
                     varDetails = whos();
                     findEgg = [];
                     for eggInd = 1:size(varDetails,1)
                         if isempty( strfind( varDetails(eggInd).name , 'EEG' ) ) ~= 1
                            findEgg = eggInd; %Technically susceptible to nested names
                            continue
                         end
                     end
                     %if whos('EEG').bytes < 1000 * 1000 * 1000 * 2
                     if varDetails(findEgg).bytes < 1000 * 1000 * 1000 * 2
                         save([new_dir filesep S.eeg_filename '.mat'],['EEG']);
                     else
                         disp(['EEG structure larger than 2GB; Saving with alternative method'])
                         save([new_dir filesep S.eeg_filename '.mat'],['EEG'], '-v7.3');
                     end
                     save_flag = 1;
                     disp('Successfully saved data.');
                 catch
                     pause(5)
                     warning('Save failed. Trying again in 5 seconds...');
                     save_flag = 0;
                 end
             end    

             clear chandata stimdata %data %data not cleared so as to be used slightly lower
             clear chandata_resamp stimdata_resamp
             clear EEG stimdata_resamp data LFP %Added more clearing to improve memory use
             
             processingEndTime = clock;
             disp(['(Chunk processed in ',num2str(etime(processingEndTime,processingStartTime)),'s)',char(10),...
                 '--------------------------------------------------------'])
             
             %Check if error occurred and iterate value if so
            if thisChunkIsError == 1
                numErrorChunks = numErrorChunks + 1;
            end
        end

        % tempval = [];
        % disp('Turning diary off...'); diary OFF;
        % 
        % if length(fopen('all')) > 5
        %     disp('Using fclose to close open file connections.');
        %     fclose('all')
        % end
        
        if numErrorChunks > 0
            ['## Caution: ',num2str(numErrorChunks),' chunks reported an error during processing ##']
        end

        
    end

end

disp(['Completed extraction of selected data'])

%QA for failures
if grandFailIt > 0
    ['#- ',num2str(grandFailIt),' chunks failed preprocessing -#']
    disp(grandFailList)
end

