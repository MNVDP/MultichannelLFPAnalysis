%% Overnight Block Stitcher (OBS)
%Stitches together data from separate chunks of overnight data into one giant MAT file

%Mk 1 - Core functionality
%    .5 - MAT file stitching, Various TDT crash armourings and miscellaneous improvements
%    .65 - Adjustments to be compatible with full generalisation of Mk 5 of preprocessing script (08/06/21)
%Mk 2 - Support for multiple stitch files within one directory (19/04/22)

clear 
close all

%-----------------------------------------
%Parameters/flags

%#########
datasetName = '270423';
%#########

dataPath = ['D:\group_swinderen\Matthew\TDTs\Processed\',datasetName,'\LFP']
%dataPath = ['D:\group_swinderen\Matthew\TDTs\TEMP STORE\',datasetName,'\LFP']

conformityList = [{'filename'},{'srate'}]; %List of fields that will be checked for conformity between chunks

padMethod = 2; %Whether to not pad (0), pad with zeroes (1) or pad with NaNs (2)

stitchMATFiles = 1; %Whether to attempt to find and stitch corresponding MAT files
if stitchMATFiles == 1
    %%dataFolder = ['D:\group_swinderen\Matthew\TDTs\Data\',datasetName]
    %dataFolder = ['D:\group_swinderen\Matthew\TDTs\TEMP STORE\',datasetName]
    useOnlyLast = 1; %Whether to only 'stitch' the last MAT file
        %This works on the (currently valid) assumption that later files contain all the information of preceding files
        %It is useful in cases where saveStruct has become desynchronised from the data chunk
end

handleEmptyData = 1; %Whether to ignore (0), delete (1) or attempt to 'fix' (2) blocks containing empty data (usually because of TDT crashes)

skipExistingFiles = 1; %Whether to skip repreprocessing files that have already been done

%-----------------------------------------
%Initialise some runtime variables
dataNew = 0; %Denotes whether dataset was processed with preprocessing script Mk 5 or later (For the purposes of generalisation)
    %(Not a flag/parameter)
%-----------------------------------------

csvList = dir([dataPath,filesep,'*.csv']);
%QA
%if size(csvList,1) > 1
%    ['## Alert: Too many CSVs detected ##']
%    crash = yes
if size(csvList,1) == 0
    ['## Alert: No CSV/s detected ##']
    crash = yes
end
%Report
disp(['-- ',num2str(size(csvList,1)),' CSV/s detected --'])
csvList(:).name

%Check to see if MAT-specific useOnlyLast needs to be overridden
if size(csvList,1) > 1 && useOnlyLast == 1
    disp(['-## Caution: useOnlyLast is active but multiple stitches detected; useOnlyLast will be disabled #-'])
    useOnlyLast = 0;
end

varList = who;
varList = [varList;{'fol'};{'varList'}];

for fol = 1:size( csvList,1 )
    clearvars('-except',varList{:}) %Clear everything except initialisation variables

    %csvToUse = csvList(1);
    csvToUse = csvList(fol);
    csvNameProc = strrep( csvToUse.name , '.csv' , '' );
    %blockList = readtable([csvToUse.folder,filesep,csvToUse.name]);
    fid = fopen([csvToUse.folder,filesep,csvToUse.name]);
    blockList = textscan(fid, '%s');
    fclose(fid);

    blockList{:}

    %%

    overBlock = struct;
    for blockInd = 1:size(blockList{1},1)
        overBlock(blockInd).origName = blockList{1}{blockInd};
        overBlock(blockInd).blockID = str2num( blockList{1}{blockInd}( strfind(blockList{1}{blockInd},'Block')+6 : end ) );
        overBlock(blockInd).portion = blockInd;
        matchBlocks = dir([dataPath,filesep,blockList{1}{blockInd}]);
        if isempty(matchBlocks) ~= 1
            matchChunks = dir([matchBlocks(1).folder,filesep,'*chunk*.mat']);
            if size(matchChunks,1) == 1
                disp([char(10),'-- Data found for ',overBlock(blockInd).origName,'; Now loading... --'])
                tic
                preLoad = load( [matchChunks(1).folder,filesep,matchChunks(1).name] );
                overBlock(blockInd).EEG = preLoad.EEG;
                disp(['-- ',overBlock(blockInd).origName,' loaded as portion ',num2str(blockInd),' in ',num2str(toc),'s --'])
            else
                ['## Invalid number of chunks detected in folder ##']
                crash = yes
            end
        else
            ['## No data found for target ',blockList{1}{blockInd},' (Are you sure names within CSV are matching?) ##']
            crash = yes
        end
        %QA for emptiness
        if isfield(overBlock(blockInd).EEG,'dataChannelID') ~= 1 %Old
            if isempty( overBlock(blockInd).EEG.data ) ~= 1
                overBlock(blockInd).dataStatus = 1;
            else
                overBlock(blockInd).dataStatus = 0;
                disp(['-# Caution: portion ',num2str(blockInd),' (',overBlock(blockInd).origName,') data detected to be empty #-'])
            end
        else %New
            if isempty( overBlock(blockInd).EEG.(overBlock(blockInd).EEG.dataChannelID).data ) ~= 1
                overBlock(blockInd).dataStatus = 1;
            else
                overBlock(blockInd).dataStatus = 0;
                disp(['-# Caution: portion ',num2str(blockInd),' (',overBlock(blockInd).origName,') ',overBlock(blockInd).EEG.dataChannelID,' data detected to be empty #-'])
            end
            dataNew = 1; %Set this to simplify later processing
            dataChannelID = overBlock(1).EEG.dataChannelID; 
            stimChannelID = overBlock(1).EEG.stimChannelID;
                %Technically relies on assumption that data fiels are constant over blocks, but that is a pretty safe assumption
        end
    end

    %Check conformity
    for conInd = 1:size(conformityList,2)
        conformToCheck = conformityList{conInd};
        for porInd = 1:size(overBlock,2)
            if isequal( overBlock(porInd).EEG.(conformToCheck) , overBlock(1).EEG.(conformToCheck) ) ~= 1
                ['## Alert: Portion ',num2str(porInd),' does not match for field ',conformToCheck,' ##']
                crash = yes
            end
        end
    end

    disp(char(10)) %Make newline

    %Correct virtual channel timing
    %(Note: This is good in theory, but in practice it is not feasible to know where in a recording the desync has begun, so it is not really wise to apply correction blindly)
    %   (This may be possible in future if the OutP fields are preserved from the original TDT files (possibly))
    for i = 1:size(overBlock,2)
        if dataNew == 1 %New
            sizeDisparity = (size(overBlock(i).EEG.( dataChannelID ).data,2) - size(overBlock(i).EEG.( stimChannelID ).data,2));
            realDataSize = size(overBlock(i).EEG.( dataChannelID ).data,2);
            stimDataSize = size(overBlock(i).EEG.( stimChannelID ).data,2);
        else %Old
            sizeDisparity = (size(overBlock(i).EEG.data,2) - size(overBlock(i).EEG.stims,2));
            realDataSize = size(overBlock(i).EEG.data,2);
            stimDataSize = size(overBlock(i).EEG.stims,2);
        end

        %QA
        if abs(sizeDisparity / overBlock(i).EEG.srate) > 1*overBlock(i).EEG.srate %Disparity of at least 1s
            ['## Warning: Disparity of at least 1s present in ',overBlock(i).origName,' ##']
            crash = yes
        end

        if realDataSize > stimDataSize
            disp(['#- Virtual channel smaller than data channel by ',num2str( sizeDisparity / overBlock(i).EEG.srate ),'s for ',overBlock(i).origName,' -#'])
                %Destructive testing shows that heavy PC lag will result in a shortened virtual channel as compared to the real data channel
            if dataNew == 1 %New
                overBlock(i).EEG.( stimChannelID ).data( : , stimDataSize : realDataSize ) = 0;
                overBlock(i).EEG.( stimChannelID ).pnts = realDataSize; %Fix this, since data size of stim channel has changed
                overBlock(i).EEG.( stimChannelID ).epoch_times( : , stimDataSize : realDataSize ) = overBlock(i).EEG.( dataChannelID ).epoch_times( : , stimDataSize : realDataSize );
            else %Old
                overBlock(i).EEG.stims( : , size(overBlock(i).EEG.stims,2) : size(overBlock(i).EEG.data,2) ) = 0; %Pads end with zeros, which does not affect any timing
            end
            disp(['-# Timing was padded but not corrected #-'])
        elseif realDataSize < stimDataSize
            disp(['#- Virtual channel larger than data channel by ',num2str( abs( sizeDisparity / overBlock(i).EEG.srate ) ),'s for ',overBlock(i).origName,' -#'])
            if dataNew == 1 %New
                overBlock(i).EEG.( stimChannelID ).data( : , realDataSize+1 : stimDataSize ) = []; %Removes data after end of real data
                overBlock(i).EEG.( stimChannelID ).pnts = size( overBlock(i).EEG.( stimChannelID ).data , 2 ); %Fix this, since data size of stim channel has changed
                overBlock(i).EEG.( stimChannelID ).epoch_times( : , realDataSize+1 : stimDataSize ) = [];
            else %Old
                overBlock(i).EEG.stims( : , size(overBlock(i).EEG.data,2)+1 : size(overBlock(i).EEG.stims,2) ) = []; %Removes data after end of real data
            end
            disp(['-# "Extra" values were deleted #-'])
        end

    end

    disp(char(10)) %Make newline

    %Pull exemplar durations from all non-empty blocks (Precedes potential deleting/fixing so that exemplar durations accurately reflect all data)
    exDurs = []; %Will hold the extracted calculated chunk durations
    for blockInd = 1:size(overBlock,2)
        exDurs(blockInd) = overBlock(blockInd).EEG.info.headerstoptime - overBlock(blockInd).EEG.info.headerstarttime; %Might be NaNs sometimes if headerstoptime NaN/missing
    end
    %QA for odd block durations
    for blockInd = 1:size(overBlock,2)
        if abs( exDurs(blockInd) -  nanmedian(exDurs) ) > nanstd(exDurs) %Will probably be less accurate if all data is fine
            disp(['-# Caution: Portion ',num2str(blockInd),' duration (',num2str(exDurs(blockInd)),') significantly (±',num2str(nanstd(exDurs)),') differs from "standard" duration (',num2str(nanmedian(exDurs)),') #-'])
            %Note: This is entirely normal in the case of overnight recordings where the last chunk might be anywhere from the normal chunk duration to 0 minutes in length
        end
    end


    %Testing plot of all data for sync purposes
    %{
    for i = 1:size(overBlock,2)
        figure
        plot( overBlock(i).EEG.data(1,:) / nanmax(overBlock(i).EEG.data(1,:)) )
        hold on
        plot( overBlock(i).EEG.stims(4,:) / nanmax(overBlock(i).EEG.stims(4,:)) )
    end
    %}

    %QA for empty blocks
    if nansum([overBlock.dataStatus] == 0) == size(overBlock,2)
        ['## Warning: All data blocks apparently empty ##']
        crash = yes
    end
    %Else
    if nansum([overBlock.dataStatus] == 0) > 0
        if handleEmptyData == 0
            disp([char(10),'-# Caution: One or more blocks contains no data but script is set to ignore #-'])
        elseif handleEmptyData == 1
            disp([char(10),'-# Caution: One or more blocks contains no data; Deleting... #-'])
            for blockInd = size(overBlock,2):-1:1
                if overBlock(blockInd).dataStatus == 0 %Data clearly missing
                    overBlock(blockInd) = [];
                elseif blockInd > 1 && overBlock(blockInd).dataStatus == 1 && nansum(  [overBlock(1 : blockInd - 1).dataStatus] == 0 ) > 0 %"Data is present but preceding data is missing"
                    disp(['Portion ',num2str(blockInd),' (',overBlock(blockInd).origName,') contains data but is preceded by data-empty blocks'])
                    proceed = input(['Do you still wish to delete? (0/1) '])
                    if proceed == 1
                        overBlock(blockInd) = [];
                    end
                end
            end
        else

            disp([char(10),'-# Caution: One or more blocks contains no data; Attempting to fix #-'])
            %Iterate over blocks, if data missing try to extrapolate block time and make NaNs to fill
            for blockInd = 1:size(overBlock,2)
                if overBlock(blockInd).dataStatus == 0 %"Block empty"
                    if blockInd ~= size(overBlock,2) %"Not terminal block"
                        prosNewEnd = overBlock(blockInd + 1).EEG.epoch_start; %Use start of next block as end of this one, since empty data seems to bork block epoch_end (and associated values)
                        %Quick QA 
                        if prosNewEnd - overBlock(blockInd).EEG.epoch_start < 5 %"Prospective new end point less than 5 seconds from current start point" 
                            %(Probably indicates a failure to get a valid prospective end point, but is also possible with super short blocks (i.e. Failure during chunking, rather than sporadic))
                            ['## Error: Insufficient time distance between current start and prospective new end ##']
                            crash = yes
                        end
                        overBlock(blockInd).EEG.epoch_end = prosNewEnd - 1; %Replace current end with start of next block (minus 1s to avoid overlap)
                        %Calculate human-readable time (From preprocess_01)
                        tmpval = datestr(datenum([1970, 1, 1, 0, 0, overBlock(blockInd).EEG.epoch_end]),'HH:MM:SS');
                        d = datetime(tmpval,'TimeZone','UTC');
                        d.TimeZone = 'Australia/Brisbane';
                        eegtimeend = datestr(d,'HH:MM:SS');
                        overBlock(blockInd).EEG.timeend = eegtimeend;

                        if dataNew == 1
                            dataFiels = overBlock(blockInd).EEG.dataFiels
                            for fielInd = 1:size(dataFiels,1) %Note: Section not tested with real data yet
                                thisFiel = dataFiels{fielInd};
                                %Assemble NaN data to size
                                numFakePoints = floor( (overBlock(blockInd).EEG.epoch_end - overBlock(blockInd).EEG.epoch_start) * overBlock(blockInd).EEG.srate ); %Calculate time between start and new end, multiply by sampling rate, remove decimals
                                numChans = overBlock( nanmin( find( [overBlock.dataStatus] == 1 ) ) ).EEG.(thisFiel).nbchan; %Find first instance of non-empty data, pull nbchan from that
                                numStimChans =  size( overBlock( nanmin( find( [overBlock.dataStatus] == 1 ) ) ).EEG.(stimChannelID).data , 1); %Ditto, but for stim

                                overBlock(blockInd).EEG.(thisFiel).data = nan( numChans , numFakePoints );
                                overBlock(blockInd).EEG.(thisFiel).stims = nan( numStimChans , numFakePoints );
                                overBlock(blockInd).EEG.(thisFiel).pnts = numFakePoints;
                                overBlock(blockInd).EEG.(thisFiel).nbchan = numChans;
                            end
                        else %Old
                            %Assemble NaN data to size
                            numFakePoints = floor( (overBlock(blockInd).EEG.epoch_end - overBlock(blockInd).EEG.epoch_start) * overBlock(blockInd).EEG.srate ); %Calculate time between start and new end, multiply by sampling rate, remove decimals
                            numChans =  overBlock( nanmin( find( [overBlock.dataStatus] == 1 ) ) ).EEG.nbchan; %Find first instance of non-empty data, pull nbchan from that
                            numStimChans =  size( overBlock( nanmin( find( [overBlock.dataStatus] == 1 ) ) ).EEG.stims , 1); %Ditto, but for stim

                            overBlock(blockInd).EEG.data = nan( numChans , numFakePoints );
                            overBlock(blockInd).EEG.stims = nan( numStimChans , numFakePoints );
                            overBlock(blockInd).EEG.pnts = numFakePoints;
                            overBlock(blockInd).EEG.nbchan = numChans;
                        end
                        overBlock(blockInd).EEG.epoch_times = linspace( overBlock(blockInd).EEG.epoch_start , overBlock(blockInd).EEG.epoch_end , numFakePoints );

                    else %"Yes terminal block"
                        disp(['#- Terminal block is empty; Deleting... #-'])
                        overBlock(blockInd) = [];
                    end
                end
            end

        end    
    end
    %%
    %For new data, reconstruct times field for each data field
    for blockInd = 1:size(overBlock,2)
        if overBlock(blockInd).dataStatus == 1
            dataFiels = overBlock(blockInd).EEG.dataFiels;
            for fielInd = 1:size(dataFiels,1)
                thisFiel = dataFiels{fielInd};
                overBlock(blockInd).EEG.(thisFiel).times = overBlock(blockInd).EEG.(thisFiel).epoch_times - overBlock(blockInd).EEG.(thisFiel).epoch_times(1); %Bootleg reconstruction of relative times
            end
        else
            ['Contingency not yet prepared here']
            %Need to see an actual empty dataset to know what to do here (Specifically, whether the dataFiels are included in empty sets, etc)
            crash = yes
        end
    end


    %%
    %Stitch files together
    disp([char(10),'-- Now stitching together ',num2str(size(overBlock,2)),' portions --'])
    tic
    sRate = overBlock(1).EEG.srate;

    %Begin
    stitchEEG = overBlock(1).EEG;

    %Wipe some fields that might otherwise contain soon to be incorrect information
    stitchEEG.setname = NaN;
    stitchEEG.timestart = NaN; %Will be fixed at end, once full time range is known
    stitchEEG.timeend = NaN; %Will be fixed at end, once full time range is known
    stitchEEG.pnts = NaN;
    stitchEEG.epoch_start = NaN;
    stitchEEG.epoch_end = NaN;


    %rollTimeStart = posixtime(datetime(strcat(overBlock(1).EEG.info.date,'-', overBlock(1).EEG.info.utcStartTime),'Format', 'yyyy-MMM-dd-HH:mm:ss')); %Note: Not checked against date boundary effects
    %rollTimeEnd = posixtime(datetime(strcat(overBlock(1).EEG.info.date,'-', overBlock(1).EEG.info.utcStopTime),'Format', 'yyyy-MMM-dd-HH:mm:ss')); %Posix time of end of first portion
    if dataNew == 1
        %rollTimeStart = overBlock(1).EEG.( dataChannelID ).epoch_times(1); %Note: May be incorrect timezone
        %rollTimeEnd = overBlock(1).EEG.( dataChannelID ).epoch_times(end); %Note: May be incorrect timezone
        stitchEEG.Stitch.nPoints = overBlock(1).EEG.( dataChannelID ).pnts; %Based on the listed data channel (Although, as long as resampling happened then all channels should be same length)
    else
        rollTimeStart = overBlock(1).EEG.epoch_times(1); %Note: May be incorrect timezone
        rollTimeEnd = overBlock(1).EEG.epoch_times(end); %Note: May be incorrect timezone
        stitchEEG.Stitch.nPoints = overBlock(1).EEG.pnts; %Moved up for laziness
    end
    pointsSize = stitchEEG.Stitch.nPoints;

    %Ready some novel fields
    stitchEEG.Stitch.stitchPortionList = 1;
    stitchEEG.Stitch.setnames{1} = overBlock(1).EEG.setname;
    %stitchEEG.Stitch.startEndTimes = [rollTimeStart, rollTimeEnd];
    %stitchEEG.Stitch.nPoints = overBlock(1).EEG.pnts;
    stitchEEG.Stitch.Date{1} = overBlock(1).EEG.info.date;

    %New-specific preparation
    if dataNew == 1
        for fielInd = 1:size(dataFiels,1)
            thisFiel = dataFiels{fielInd};
            rollTimeStart = overBlock(1).EEG.( thisFiel ).epoch_times(1); %Note: May be incorrect timezone
            rollTimeEnd = overBlock(1).EEG.( thisFiel ).epoch_times(end); %Note: May be incorrect timezone
            stitchEEG.Stitch.( thisFiel ).startEndTimes = [rollTimeStart, rollTimeEnd];
            stitchEEG.Stitch.( thisFiel ).nPoints = overBlock(1).EEG.( thisFiel ).pnts;
        end
    end

    %Append portions
    for porInd = 2:size(overBlock,2)
        if dataNew == 1
            thisPorStartPosixUTC = overBlock(porInd).EEG.( dataChannelID ).epoch_times(1);
            thisPorEndPosixUTC = overBlock(porInd).EEG.( dataChannelID ).epoch_times(end);        
        else
            thisPorStartPosixUTC = overBlock(porInd).EEG.epoch_times(1);
            thisPorEndPosixUTC = overBlock(porInd).EEG.epoch_times(end);
        end
        timeGap = thisPorStartPosixUTC - rollTimeEnd; %How much time between end of last and start of current
        %Quick QAs
        %if timeGap > ( overBlock(1).EEG.pnts / overBlock(1).EEG.srate ) * 0.1
        if timeGap > ( pointsSize / overBlock(1).EEG.srate ) * 0.1 %"Gap between end of previous and start of current more than 10% of first chunk duration"
                %Note: First chunk used because only one guaranteed to be full chunkDuration
            ['## Warning: Potential sequence break detected when appending portions ##']
            crash = yes        
        end
        %{
        %(This QA inoperable because epoch_times is based on a different timezone to utcStartTime it seems)
        altTime = posixtime(datetime(strcat(overBlock(porInd).EEG.info.date,'-', overBlock(porInd).EEG.info.utcStartTime),'Format', 'yyyy-MMM-dd-HH:mm:ss'));
        if abs(altTime - thisPorStartPosixUTC) > 10 %Disparity of more than 10s exists between two methods of determining chunk start time
            ['## Alert: Significant posix time disparity detected ##']
            crash = yes
        end
        %}

        %Assemble padding, if requested
        pad = [];
        if padMethod == 0
            pad = [];
        elseif padMethod == 1
            pad = zeros(1,floor(timeGap*sRate));
        elseif padMethod == 2
            pad = nan(1,floor(timeGap*sRate));
        end
        stitchEEG.Stitch.pad{porInd} = pad; %Keep track of pad applied
        %Apply padding
        if dataNew == 1
            dataFiels = overBlock(porInd).EEG.dataFiels;
            for fielInd = 1:size(dataFiels,1)
                thisFiel = dataFiels{fielInd};
                padCoords = [size(stitchEEG.(thisFiel).data,2)+1 : size(stitchEEG.(thisFiel).data,2) + size(pad,2)];
                stitchEEG.(thisFiel).data( : , padCoords ) = repmat( pad , size(stitchEEG.(thisFiel).data,1) , 1 ); %Add padding to end of previous data
                %stitchEEG.stims( : , padCoords ) = repmat( pad , size(stitchEEG.stims,1) , 1 ); %Add padding to end of previous stims (Note: Synchrony only assured due to earlier QA); Disabled due to full generalisation

                %###
                %Interpolate times of padding
                interpEpochTime = linspace( 0 , timeGap , size(pad,2) ) + stitchEEG.(thisFiel).epoch_times(end); %Interpolate the posix timepoints of the pad
                stitchEEG.(thisFiel).epoch_times( 1 , padCoords ) = interpEpochTime; %Ditto for epoch_times
                pointGap = [ size(stitchEEG.(thisFiel).data,2) - size(stitchEEG.(thisFiel).times,2) ]; %EEG.times is different
                relTimeCoords = [size(stitchEEG.(thisFiel).times,2)+1 : size(stitchEEG.(thisFiel).times,2) + pointGap];
                interpRelTime = linspace( 0 , timeGap , pointGap ) + stitchEEG.(thisFiel).times(end); %Interpolate the posix timepoints of the pad
                stitchEEG.(thisFiel).times( 1 , relTimeCoords ) = interpRelTime; %Add interpTime to last value of times to infer pad relative time
                    %Note: EEG.times appears to be longer than real data but approx. 15 points on average per block and I don't know why
                    %Also note: Technically these both will have a single-frame stutter at the first point of the pad, but I honestly can't be bothered fixing such a minor issue

                %Stitch on new portion
                stitchCoords = [size(stitchEEG.(thisFiel).data,2)+1 : size(stitchEEG.(thisFiel).data,2) + size(overBlock(porInd).EEG.(thisFiel).data,2)];
                stitchEEG.(thisFiel).data( : , stitchCoords ) = overBlock(porInd).EEG.(thisFiel).data; %Data
                %stitchEEG.stims( : , stitchCoords ) = overBlock(porInd).EEG.stims; %Stims
                stitchEEG.(thisFiel).epoch_times( : , stitchCoords ) = overBlock(porInd).EEG.(thisFiel).epoch_times; %Posix times
                timeStitchCoords = [size(stitchEEG.(thisFiel).times,2)+1 : size(stitchEEG.(thisFiel).times,2) + size(overBlock(porInd).EEG.(thisFiel).times,2)];
                stitchEEG.(thisFiel).times( : , timeStitchCoords ) = overBlock(porInd).EEG.(thisFiel).times; %Relative times

                %Prepare for next
                rollTimeStart = overBlock(porInd).EEG.(thisFiel).epoch_times(1);
                rollTimeEnd = overBlock(porInd).EEG.(thisFiel).epoch_times(end);

                %...and specific ancillary
                stitchEEG.Stitch.(thisFiel).startEndTimes(porInd,:) = [rollTimeStart, rollTimeEnd];
                stitchEEG.Stitch.(thisFiel).nPoints(porInd,1) = overBlock(porInd).EEG.(thisFiel).pnts;
                %###
            end
            %Special dataNew nPoints assignation
            stitchEEG.Stitch.nPoints(porInd,1) = overBlock(porInd).EEG.( dataChannelID ).pnts; %Use data channel as basis for number of points
                %Note: It is currently unknown if the number of points between different data fields is likely or even possible to drift
        else
            padCoords = [size(stitchEEG.data,2)+1 : size(stitchEEG.data,2) + size(pad,2)];
            stitchEEG.data( : , padCoords ) = repmat( pad , size(stitchEEG.data,1) , 1 ); %Add padding to end of previous data
            stitchEEG.stims( : , padCoords ) = repmat( pad , size(stitchEEG.stims,1) , 1 ); %Add padding to end of previous stims (Note: Synchrony only assured due to earlier QA)

            %###
            %Interpolate times of padding
            interpEpochTime = linspace( 0 , timeGap , size(pad,2) ) + stitchEEG.epoch_times(end); %Interpolate the posix timepoints of the pad
            stitchEEG.epoch_times( 1 , padCoords ) = interpEpochTime; %Ditto for epoch_times
            pointGap = [ size(stitchEEG.data,2) - size(stitchEEG.times,2) ]; %EEG.times is different
            relTimeCoords = [size(stitchEEG.times,2)+1 : size(stitchEEG.times,2) + pointGap];
            interpRelTime = linspace( 0 , timeGap , pointGap ) + stitchEEG.times(end); %Interpolate the posix timepoints of the pad
            stitchEEG.times( 1 , relTimeCoords ) = interpRelTime; %Add interpTime to last value of times to infer pad relative time
                %Note: EEG.times appears to be longer than real data but approx. 15 points on average per block and I don't know why
                %Also note: Technically these both will have a single-frame stutter at the first point of the pad, but I honestly can't be bothered fixing such a minor issue

            %Stitch on new portion
            stitchCoords = [size(stitchEEG.data,2)+1 : size(stitchEEG.data,2) + size(overBlock(porInd).EEG.data,2)];
            stitchEEG.data( : , stitchCoords ) = overBlock(porInd).EEG.data; %Data
            stitchEEG.stims( : , stitchCoords ) = overBlock(porInd).EEG.stims; %Stims
            stitchEEG.epoch_times( : , stitchCoords ) = overBlock(porInd).EEG.epoch_times; %Posix times
            timeStitchCoords = [size(stitchEEG.times,2)+1 : size(stitchEEG.times,2) + size(overBlock(porInd).EEG.times,2)];
            stitchEEG.times( : , timeStitchCoords ) = overBlock(porInd).EEG.times; %Relative times

            %Prepare for next
            rollTimeStart = overBlock(porInd).EEG.epoch_times(1);
            rollTimeEnd = overBlock(porInd).EEG.epoch_times(end);

            %...and specific ancillary
            stitchEEG.Stitch.startEndTimes(porInd,:) = [rollTimeStart, rollTimeEnd];
            stitchEEG.Stitch.nPoints(porInd,1) = overBlock(porInd).EEG.pnts;
            %###
        end

        %...and general ancillary
        stitchEEG.Stitch.stitchPortionList(porInd,1) = porInd;
        stitchEEG.Stitch.setnames{porInd} = overBlock(porInd).EEG.setname;
        stitchEEG.Stitch.Date{porInd} = overBlock(porInd).EEG.info.date;

    end

    %Adjust info fields to match new structure
    stitchEEG.info.blockname = 'Block-1'; %As befitting new stitched identity (Note: Considered using last block setname as identity but opted no because block identity set to 1 during stitching)
    %Append end times
    stitchEEG.info.headerstoptime = overBlock(porInd).EEG.info.headerstoptime; %Use stop time from last portion (Note: Assumption of validity from last portion)
    temp = stitchEEG.info.headerstoptime - stitchEEG.info.headerstarttime;
    temp = seconds(temp);
    temp.Format = 'hh:mm:ss'; %Yet more unstable use of temps
    stitchEEG.info.duration = char(temp);
    if isnan(overBlock(porInd).EEG.info.utcStopTime) ~= 1
        stitchEEG.info.utcStopTime = overBlock(porInd).EEG.info.utcStopTime; %Use stop time from last portion (Note: Assumption of validity from last portion)
    else
        ['-# Warning: No UTC stop time could be detected; Approximating from headerstoptime #-']
        stitchEEG.info.utcStopTime = datestr(datetime(stitchEEG.info.headerstoptime, 'ConvertFrom', 'posixtime', 'TimeZone', '+10:00'), 'HH:MM:SS');
            %Note: This is not 100% guaranteed to be correct (The mechanism that calculates headerstoptime appears to be better armoured against abnormal block termination, but it is probably not infallible)
    end
    stitchEEG.epoch_start = overBlock(1).EEG.epoch_start;
    stitchEEG.epoch_end = overBlock(end).EEG.epoch_end; %Not guaranteed to perfectly match utcStopTime or headerstoptime

    %stitchEEG.info.stopDate = overBlock(porInd).EEG.info.date; %Date of end of experiment (But not actually, since date does not update automatically)
    if dataNew == 1
        stitchEEG.pnts = size(stitchEEG.(dataChannelID).data,2); %Use specified data channel as exemplar
    else
        stitchEEG.pnts = size(stitchEEG.data,2);
    end

    disp(['-- Portions stitched together in ',num2str(toc),'s --',char(10)])


    %%
    %Save stitched block
    disp(['-- Now saving stitched block --'])

    saveName = matchChunks(1).name; %Pull a sample name
    saveName( strfind(saveName,'chunk_')+6:end ) = []; %Remove old chunk number
    saveName = [saveName,'01.mat']; %Replace with new

    expName = matchChunks(1).name( 1 : strfind(saveName,'chunk_') - 2 ) %Practically hardcoded
    %outputFolder = [dataPath,filesep,'Stitched_',expName,'_',stitchEEG.info.blockname];
    outputFolder = [dataPath,filesep,'Stitched_',csvNameProc,'_',stitchEEG.info.blockname];

    if isdir(outputFolder) ~= 1
        mkdir(outputFolder);
    end

    saveNameFull = [outputFolder,filesep,saveName];

    try
        fileIsExist = isfile(saveNameFull); %Will fail on MATLAB 2014b, but that's why this is in a try-catch
    catch
        fileIsExist = exist(saveNameFull);
    end
    if fileIsExist ~= 0 && skipExistingFiles == 1
        warning('Block already processed. Skipping file.');
    elseif  fileIsExist ~= 0 && skipExistingFiles == 0 
        disp(['-# Block already exists but files requested not to be skipped #-'])
        save([outputFolder,filesep,saveName],['stitchEEG'], '-v7.3');
    elseif fileIsExist == 0
        save([outputFolder,filesep,saveName],['stitchEEG'], '-v7.3');
    end
    %save([outputFolder,filesep,saveName],['stitchEEG'], '-v7.3');


    disp(['-- Stitched block (',saveName,') saved (or not) in ',num2str(toc),'s --',char(10)])


    %%
    %Find and stitch MAT files
    if stitchMATFiles == 1
        disp(['-- Now stitching MAT files --'])
        tic

        expName = blockList{1}{1}; %Pull first element of blockList as exemplar name
        expName = strrep(expName,'Analyzed_',''); %Strip "Analyzed_" from name
        expName( strfind( expName , ['_',overBlock(1).EEG.setname] ) : end ) = []; %Strip the block identity from the name (Note: Will not work properly if blocks desynced for any reason)
        %Old
        %{
        validFolderList = dir( [dataFolder , filesep , '*', expName, '*'] );
        %QA
        if isempty(validFolderList) == 1
            ['## Warning: No valid folders found for ',expName]
            crash = yes
        end
        if size(validFolderList,1) > 1
            ['## Warning: Too many folders found for ',expName]
            crash = yes
        end

        dataLocation = [validFolderList(1).folder,filesep,validFolderList(1).name]; %Inside the data folder
        %}

        %Find and stitch MAT files within folders
        stitchMAT = struct;

        if useOnlyLast == 0 %"Attempt to match each data block to its specific MAT file"
            lastInterchunkDuration = 0;

            for blockInd = 1:size(overBlock,2)
                %Try to find MAT file
                %%prosMATFiles = dir( [dataLocation,filesep,overBlock(blockInd).EEG.setname,filesep,'*.mat'] );
                searchStr = ['**\*B',num2str(overBlock(blockInd).blockID),'.mat'];
                %prosMATFiles = dir(fullfile(dataLocation, searchStr)); %Altered functionality; Looks for MATs (in the raw data folder) that match the Block num, rather than blocks within a particular named folder
                prosMATFiles = dir(fullfile(dataPath, searchStr)); %Altered functionality; Looks for MATs  (in the processed data folder) that match the Block num, rather than blocks within a particular named folder
                %{
                %Check likely secondary location if none found in primary location
                if isempty(prosMATFiles) == 1
                    ['## MAT file not found in primary location; Checking secondary location ##']
                    prosMATFiles = dir( [dataLocation,filesep,overBlock(blockInd).EEG.setname,filesep, 'MAT' , filesep, '*.mat'] );
                end
                %QA
                %}
                if isempty(prosMATFiles) == 1 || size(prosMATFiles,1) > 1
                    ['## Error in MAT file finding ##']
                        %Note: This may be due to either a true failure or a failsafe-related saving 'hiccup' 
                    proceed = input('Do you wish to ignore? (0/1) ')
                    if proceed == 0
                        crash = yes
                    else
                        disp(['#- Ignoring -#'])
                    end
                    %crash = yes
                end

                if isempty(prosMATFiles) ~= 1
                    %Load found MAT file
                    preLoad = load([ prosMATFiles(1).folder , filesep , prosMATFiles(1).name ]);

                    %And stitch
                    if blockInd == 1 %First block, accept as is
                        stitchMAT = preLoad;
                        lastInterchunkDuration = stitchMAT.saveStruct.ancillary.stimduration;

                        disp(['Portion ',num2str(blockInd),' (Block ',num2str(overBlock(blockInd).blockID),') stitched, T:',num2str(toc),'s)'])

                    else %Not first block, check for location

                        stitchCoords = [size(stitchMAT.saveStruct.sentStimuli,2)+1 : size(preLoad.saveStruct.sentStimuli,2)]; %Use assumption that this is next file

                        if size(stitchCoords,2) > 0
                            %firstSentBlockPosix = posixtime(datetime(strcat(preLoad.saveStruct.sentStimuli(1).trialSendDatestr),'Format', 'yyyy dd/MM HH:mm:ss:SSS'));
                            lastStitchBlockPosix = posixtime(datetime(strcat(stitchMAT.saveStruct.sentStimuli(end).trialSendDatestr),'Format', 'yyyy dd/MM HH:mm:ss:SSS')); %Current last block of stitch

                            stitchMAT.saveStruct.sentStimuli( stitchCoords ) = preLoad.saveStruct.sentStimuli(stitchCoords);

                            thisFirstSentStimuliPosix = posixtime(datetime(strcat(stitchMAT.saveStruct.sentStimuli(stitchCoords(1)).trialSendDatestr),'Format', 'yyyy dd/MM HH:mm:ss:SSS'));
                            %QA for mistiming
                            %if thisFirstSentStimuliPosix - lastStitchBlockPosix > lastInterchunkDuration*3 %"More than 2.5x the last inter-chunk duration between edges"
                            if thisFirstSentStimuliPosix - lastStitchBlockPosix > 0.5 * nanmedian(exDurs) %"More than half the standard block duration"
                                ['## Warning: Potential sequence break detected when stitching MAT files ##']
                                crash = yes
                            end
                            if thisFirstSentStimuliPosix < lastStitchBlockPosix %"This MAT file precedes (supposed) first MAT file"
                                ['## Warning: Potential misordering detected when stitching MAT files ##']
                                crash = yes
                            end

                            lastInterchunkDuration = thisFirstSentStimuliPosix - lastStitchBlockPosix; %Update this value
                            disp(['Portion ',num2str(blockInd),' (Block ',num2str(overBlock(blockInd).blockID),') stitched (ICI: ',num2str(thisFirstSentStimuliPosix - lastStitchBlockPosix),'s, T:',num2str(toc),'s)'])
                        else
                            disp(['-# Warning: Portion ',num2str(blockInd),' (Block ',num2str(overBlock(blockInd).blockID),') contained no new information to be stitched #-'])
                        end

                    end

                    stitchMAT.saveStruct.Stitch.sentEndTimes(blockInd,1) = posixtime( datetime( preLoad.saveStruct.sentStimuli(end).trialSendDatestr , 'Format', 'yyyy dd/MM HH:mm:ss:SSS' , 'Timezone', '+10:00' ) ); %Adding new field to saveStruct like this might cause trouble

                    lastMATToStitch = prosMATFiles(1).name;
                else
                    disp(['MAT not found for Portion ',num2str(blockInd),' (Block ',num2str(overBlock(blockInd).blockID),')'])
                    %Note: The only reason this is feasible to not be a crash event is the fact that currently, saveStruct files hold all preceding data, and so it is theoretically to skip all except the last
                        %Deprecated
                    crash = yes
                end

            end
        else %"Use the last MAT file under the assumption it contains all preceding data"
            searchStr = ['**\*B*.mat'];
            %prosMATFiles = dir(fullfile(dataLocation, searchStr)); %Look in raw data folder
            prosMATFiles = dir(fullfile(dataPath, searchStr)); %Look in LFP folder
            %Quick QA
            if isempty(prosMATFiles) == 1
                ['## Alert: Critical failure in finding MAT file/s ##']
                crash = yes
            end
            %Identify which file is last (Based on date)
            for i = 1:size(prosMATFiles,1)
                prosMATFiles(i).datePosix = posixtime( datetime( prosMATFiles(i).date , 'Format', 'yyyy dd/MM HH:mm:ss:SSS' , 'Timezone', '+10:00' ) );
            end
            [~,lastInd] = nanmax([prosMATFiles.datePosix]);
            lastMATToStitch = prosMATFiles(lastInd).name;
            disp(['-- Stitching only final MAT file (',lastMATToStitch,') --'])
            %Load found MAT file
            preLoad = load([ prosMATFiles(lastInd).folder , filesep , lastMATToStitch ]);
            %Save as only contribution to stitchMAT
            stitchMAT = preLoad;
            stitchMAT.saveStruct.Stitch.sentEndTimes(1,1) = posixtime( datetime( preLoad.saveStruct.sentStimuli(end).trialSendDatestr , 'Format', 'yyyy dd/MM HH:mm:ss:SSS' , 'Timezone', '+10:00' ) ); %Send to the 1 position because only loading one MAT file
        end

        %QA for timing of stitched EEG to MAT
            %Note: It is highly likely that the stitched EEG timing is a different timezone to UTC+10
        figure
        if dataNew == 1
            for i = 1:size(stitchEEG.Stitch.( dataChannelID ).startEndTimes,1)
                line([stitchEEG.Stitch.( dataChannelID ).startEndTimes(i,1),stitchEEG.Stitch.( dataChannelID ).startEndTimes(i,1)] , [0,1], 'LineStyle','--', 'Color', 'r')
                hold on
                line([stitchEEG.Stitch.( dataChannelID ).startEndTimes(i,2),stitchEEG.Stitch.( dataChannelID ).startEndTimes(i,2)] , [0,1], 'LineStyle','--', 'Color', 'b')
            end
            temp = diff([stitchEEG.Stitch.( dataChannelID ).startEndTimes(end,2) , stitchMAT.saveStruct.Stitch.sentEndTimes(end,1) ]);
        else
            for i = 1:size(stitchEEG.Stitch.startEndTimes,1)
                line([stitchEEG.Stitch.startEndTimes(i,1),stitchEEG.Stitch.startEndTimes(i,1)] , [0,1], 'LineStyle','--', 'Color', 'r')
                hold on
                line([stitchEEG.Stitch.startEndTimes(i,2),stitchEEG.Stitch.startEndTimes(i,2)] , [0,1], 'LineStyle','--', 'Color', 'b')
            end
            temp = diff([stitchEEG.Stitch.startEndTimes(end,2) , stitchMAT.saveStruct.Stitch.sentEndTimes(end,1) ]);
        end
        for i = 1:size(stitchMAT.saveStruct.Stitch.sentEndTimes,1)
            line([stitchMAT.saveStruct.Stitch.sentEndTimes(i,1),stitchMAT.saveStruct.Stitch.sentEndTimes(i,1)] , [1,2], 'LineStyle','-.', 'Color', 'm')
        end

        disp([char(10),'Difference of ',num2str(temp),'s between saveStruct (',lastMATToStitch,') and end of last chunk (',overBlock(end).origName,') --'])
        %To do: Add crash QA here if this value is too large?
            %(But what is too large?)

        stitchMAT.saveStruct.blockNum = 1; %Set to 1, because stitched

        disp([char(10),'-- MAT files stitched in ',num2str(toc),' --'])
        tic

        %Save stitched MAT file
        saveStruct = stitchMAT.saveStruct;
        saveName = [];
        %saveName = strrep( prosMATFiles(1).name , ['B',num2str(overBlock(blockInd).blockID),'.mat'] , ['B1.mat'] ); %Use the last MAT name as exemplar, remove block ID and replace with block ID of 1
        %saveName =['Stitched_saveStruct_B1.mat']; %Custom name, to cut down on multiple versions of saveStruct being assembled in folder when data handling used
        
        saveName = strrep( prosMATFiles(1).name , ['B',num2str(overBlock(blockInd).blockID),'.mat'] , ['B1.mat'] ); %Use the last MAT name as exemplar, remove block ID and replace with block ID of 1
        saveName( 1 : strfind( saveName , '_saveStruct' ) ) = [];
        saveName = ['Stitched_',saveName]; %Similar to above, except preserves original experiment name
            %Note: There should be no risk of MAT saving overlap if multiple stitches exist, on account of output folder derivation from CSV name
                %...unless the CSVs share the same name

        saveNameFull = [outputFolder,filesep,saveName];

        try
            fileIsExist = isfile(saveNameFull); %Will fail on MATLAB 2014b, but that's why this is in a try-catch
        catch
            fileIsExist = exist(saveNameFull);
        end
        if fileIsExist ~= 0 && skipExistingFiles == 1
            warning('MAT already processed. Skipping file.');
        elseif  fileIsExist ~= 0 && skipExistingFiles == 0 
            disp(['-# MAT already exists but files requested not to be skipped #-'])
            save([outputFolder,filesep,saveName],['saveStruct'], '-v7.3');
        elseif fileIsExist == 0
            save([outputFolder,filesep,saveName],['saveStruct'], '-v7.3');
        end

        %save(saveNameFull,['saveStruct'],'-v7.3');

        disp(['-- MAT files saved (or not) in ',num2str(toc),' --'])

    end

    %Check timing linearity
    sentPosixes = [];
    for sentInd = 1:size(stitchMAT.saveStruct.sentStimuli,2)
        sentPosixes(sentInd) = posixtime(datetime(strcat(stitchMAT.saveStruct.sentStimuli(sentInd).trialSendDatestr),'Format', 'yyyy dd/MM HH:mm:ss:SSS', 'TimeZone', '+10:00'));
    end
    %Plot
    figure
    if dataNew == 1
        plot(stitchEEG.( dataChannelID ).epoch_times, 'r')
    else
        plot(stitchEEG.epoch_times, 'r')
    end
    xlabel(['Frame'])
    ylabel(['Posix time'])
    title(['Stitched EEG posix time linearity'])
    figure
    plot(sentPosixes, 'b')
    xlabel(['Block number'])
    ylabel(['Posix time'])
    title(['sentStimuli posix time linearity'])

%fol end
end


%Fin
%close all
clear all
