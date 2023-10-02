#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Created on Wed Jul  4 11:03:22 2018

@author: uqsjagan
"""
#!/usr/bin/python

#Modified Motion Detection analysis script
#By sjagan and mvandepoll
#Mk 1 - Core functionality
#Mk 2 - Additional saving of raw delta values alongside movement detection, threshold change to 20
#Mk 3 - Segmentation of pooling to avoid suspected cross-reading of anc files
#    .5 - Saving output in data folders, More QA, More specificity of video/CSV detection
#    .75 - Miscellaneous improvements (I forgot what was actually changed)
#Mk 4 - Generalisation for different data types, Alteration to use perfect name matching
#    .5 - Removed necessity of pre-existing CSV files (30/06/20)
#    .75 - Speed improvements [Probably where refFrame issue first appeared] (27/08/20)
#    .85 - Slight expName improvements (24/09/20)
#    .95 - 'Fix' of refFrame grayness between iterations, Dynamic threshold specification in anc (12/08/21)
#Mk 5 - Suppressing of verbose txts unless requested

#Designed for: Python 2.7 (optimally 2.7.11)
#Required SDKs: VC for Python27 (available from internet)
#Required modules: imutils, moviepy, opencv-python, pandas, tqdm, requests and multiprocessing

#ANC file contents (Note: Should be a text file and each value on a new line):
# <X position of top-left corner of ROI window (in pixels)>
# <Y position of top-left corner of ROI window (in pixels)>
# <height of ROI window (in pixels)>
# <width of ROI window (in pixels)>
# <name of analysis type (For example, mov)>
# <whether source data has partner CSVs>
# <threshold for use in image analysis> (Note: Was 20 for vast majority of legacy analysis)

#Note: No quotation marks should be used in the ANC file, even for the identity string on row 5

#How to use:
#1 - Place data folder in directory specified by overFolder
#(i.e. "C:\<Name_of_overFolder>\<Name_of_specific_data_folder>\" and so on)
#
#2 - Next, ensure that there is a *single* anc.txt file in the data folder, containing 6 lines where line 1 is the X position
#    of the top-left of the window to analyse for motion detection in, line 2 is the Y for the same, lines 3 and 4 are the height
#    and width respectively of said window, line 5 is a set of letters to distinguish what is being analysed (for example: prob or mov)
#    and line 6 is whether the data has corresponding CSVs to go alongside it
#    (Three groups of example values can be found commented out further down in the code (Note that only the values themselves are needed
#    in the anc.txt file, not the "x = " and on))
#
#3 - Enter expName and subExpName strings that correspond to the folders and data you wish to analyse respectively
#    (For example, if you wished to only analyse data in folders named SponSleep_LFP and data from a Lateral view
#    of the fly within those folders, your expName would be 'SponSleep_LFP' and your subExpName would be 'Lateral')
#    The script will initially search for all folders containing a name match to expName (e.g. "19 11 2018 SponSleep_LFP") and
#    then for videos/CSVs matching subExpName in said folders (e.g. "19 11 2018 Lateral camera 01.avi"). Only folders fulfilling the
#    criteria of having a matching name and also containing appropriately named data will be added to the analysis queue.
#    (Common mistakes here are to have the data be nested in further levels inside the data folder
#    i.e. "\19 11 2018 SponSleep_LFP\videos\19 11 2018 Lateral camera 01.avi", which would not be added to the analysis queue because
#    there would be no matching data detectable in "\19 11 2018 SponSleep_LFP\")
#    This can be mitigated by entering a string value for subFolderName, whereupon the script will nest according to that string.
#    (Note: This will allow you to analyse data in say, "CentralDataFolder\\Chrim_Exp_Thursday\\data\\data.csv" where "CentralDataFolder" is
#    the overFolder, "Chrim_Exp" is the expName and "data" is the subFolder, but it will not iterate if there is something like "data1", "data2",
#    "data3", etc all within the expName folder)
#    If you do not wish to specify an expName (for example, your data is organised simply as pairs of dates with no mention of experiment
#    type) then simply enter '' for expName and all folders in the directory will be scanned for data (Note that data matching to
#    subExpName must still be detectable in these folders for them to be added to the analysis queue)
#
#4 - Choose whether you want data to be saved in a centralised location (good for debugging or rapidly moving between locations)
#    or to be saved alongside the source files (good for people who are lazy).
#    If you choose to have the data saved in a centralised location (saveInDataFolder = 0) then specify a valid folder for the data
#    to be output to (If the folder does not exist the data may not save correctly)
#
#5 - Run program to enable script to be compiled (the multiprocessing module requires being operated from a compiled script to work).
#    It will finish (and/or crash) in the console window without processing anything.
#    Go to the directory where this script is saved and double click to run the newly created .pyc file that shares a name with this script
#    and was listed as being created at the same time as this script was run. A Python terminal window will appear and the program will begin
#    to analyse the data, one folder at a time. Each individual data file will take ~1hr to analyse on a normal CPU core (If you have 12 cores
#    in your CPU it means that 12 data files can be analysed simultaneously but it will not improve the speed of processing of the individual).
#    A simple way to calculate how long processing will take in total is to divide the number of data files in a given folder (e.g. 16) by the
#    number of cores (e.g. 8) and then multiply by the number of data folders (e.g. 6) to give the number of core-hours required
#    (e.g. 16 files / 8 cores * 6 data folders = 12 core-hours to analyse all the data)
#    (Note: It is theoretically possible to modify this script to run without multiprocessing but it is a hassle and should only be used
#    for extreme debuggging)
#    If you received an error saying something like "NO DATA FOUND" or the console presented with "The number of processes must be at least 1"
#    then Python could not detect any data based on your specified parameters and folders. Check that your folders are separated with double
#    slashes (\\), as single slashes (\) are escape characters in Python. Also check that your data matches the expName and subExpName specified.
#    (It is possible to manually run > glob.glob(basefolderpath + "\\" + subFolderName + subExpName + "*.avi") to see what data the program is trying to find)

#Miscellaneous notes:
#   - It is possible to add new data columns to the output by adjusting lines pertaining to df
#   - Display of the detected motion can be disabled by setting display = False but this may possibly affect script operation
#   - The script unfortunately lacks the ability to analyse the same data set for multiple things (i.e. proboscis extensions
#    and movement) in the one run, so please ensure only one anc.txt file is present in each data folder
#       (But you can copy entire data folders with different ancs to analyse for different features in one run of the script)
#   - The threshold value may or may not be on a 1 - 255 scale; I'm not sure
#   - My email address is m.vandepoll@uq.edu.au if it comes to it

import imutils
from moviepy.editor import VideoFileClip
import cv2
import pandas
from pandas import read_csv
from tqdm import tqdm  
import glob
import multiprocessing
from multiprocessing import Pool
import os
import time
import csv
#import string
import sys

print '-- Commencing analysis --'

overFolder = "C:\\MotionDetection\\Data\\" #This is the root data folder (Trailing \\ necessary)
expName = '' #Folder names to find (Leave empty to find all applicable folders within overFolder)
subFolderName = "" #Whether there are sub-folders within the data folders that contain the data (e.g. "video\\")
    #If there is no subfolder, leave this empty
subExpName = '*fly*_*' #Specific data files to analyse within folder (Note: Wildcards critical for iteration over more than one data file)
saveInDataFolder = 0 #Whether to save the output in the source data folder
if saveInDataFolder != 1:
    savePath = "C:\\MotionDetection\\Output\\" #(Trailing \\ necessary)
else:
    savePath = []
logPath = "C:\\MotionDetection\\Output\\" #Output location for log files
doStateLogging = 0 #Whether to log detailed information on the quantal success of analysis for each file
ancFormat = 'anc*.txt' #Naming format for anc files
dataFormat = '.csv' #Ditto but for frame data
display = True #was true 
#hasCSVs = 0 #Whether source video CSVs are existing

print 'Root data folder:', overFolder

#Find all subfolders in root folder
for root, dirs, files in os.walk(overFolder):
    print 'Detected folders:', dirs
    break

#Iterate to find all files for analysis
##videofilelist = []
##csvfilelist = []
##dirlist = []
##anclist = []

megaList = []

for dirSpec in dirs:
    videofilelist = []
    csvfilelist = []
    dirlist = []
    anclist = []

    basefolderpath = overFolder+dirSpec

    #Find if experimental data exists in this folder name
    nameMatch = str.find(basefolderpath,expName)

    ##basefilename = "13032019_SponSleep_LFP_"
    if nameMatch != -1 or len(expName) == 0: #Path is a match for the experiment in question OR no expName specified
        ##videofilelist = []
        ##for name in glob.glob(basefolderpath + basefilename + "*.avi"):
        
        #Source videos
        if len(glob.glob(basefolderpath + "\\" + subFolderName + subExpName + "*.avi")) != 0:
            for name in glob.glob(basefolderpath + "\\" + subFolderName + subExpName + "*.avi"):
                videofilelist.append(name)
                #Source directory
                dirlist.append(dirSpec) #Necessary for correct saving            
                #Anc file, repeated
                for ancname in glob.glob(basefolderpath + "\\" + subFolderName + "*" + ancFormat):
                    anclist.append(ancname)
                if len(ancname) == 0:
                    print '### ALERT: COULD NOT FIND ANC FOR DIRECTORY ' + dirSpec + " ###"
                    time.sleep(5)
                    error = yes
                if len(glob.glob(basefolderpath + "\\" + subFolderName + ancFormat)) > 1:
                    print '### ALERT: CRITICAL ANC OVERFIND FOR DIRECTORY ' + dirSpec + " ###"
                    time.sleep(5)
                    error = yes
            '''
            #Find name unique position (currently unused)
            rollTemp = []
            for x in range(1,len(videofilelist)):
                for y in range(0,len(videofilelist[0])):
                        if (videofilelist[0][y] == videofilelist[x][y]) == False:
                                rollTemp.append(y)
            idStart = min(rollTemp) #If this crashed, there was an error IDentifying the unique ID
            idEnd = max(rollTemp) #Note: Of the pair, only this one is useful for CSV QA
            #The IDea here is that idStart and idEnd define the unique component of the name, allowing for effective QA
            '''
           #if hasCSVs == 1:
            for videoname in videofilelist:
                #Matched CSV files
                videoFindName = videoname.replace(basefolderpath + '\\', '')
                videoFindName = videoFindName.replace('.avi','')

                for csvname in glob.glob(basefolderpath + '\\' + videoFindName + dataFormat): #Use whole name of video for perfect matching
                    #Note: Original "videoname" contained full folder path within self
                #for csvname in glob.glob(videoname[0:-5] + "_.csv"): #Hardcoded name format (Note: Terminal underscore critical for differentiation)
                #for csvname in glob.glob(videoname[0:idEnd+1] + "_.csv"): #Dynamic name format (Note: Terminal underscore critical for differentiation)
                    csvfilelist.append(csvname)
                try:
                    if len(csvname) == 0: #If this crashes, no CSVs were found
                        print '### ALERT: COULD NOT FIND PARTNER CSV FOR FILE ' + videoname + " ###"
                        time.sleep(5)
                        error = yes
                except:
                    #print '## Error during CSV detection; Non-existence likely ##' %Suppressed because semi-normal (for some people)
                    #csvfilelist = 'X' #Stand-in value
                    csvfilelist.append('X') #May cause huge issues appending rather than just overwriting 
                    
                if len(glob.glob(basefolderpath + '\\' + videoFindName + dataFormat)) > 1:
                #if len(glob.glob(videoname[0:-5] + "_.csv")) > 1:
                    print '### ALERT: CRITICAL CSV OVERFIND FOR FILE ' + videoname + " ###"
                    time.sleep(5)
                    error = yes
                '''
                if len(glob.glob(videoname[0:idEnd+1] + "_.csv")) > 1:
                    print '### ALERT: CRITICAL CSV OVERFIND FOR FILE ' + videoname + " ###"
                    time.sleep(5)
                    error = yes
                '''
                #QA is assured here by virtue of only finding CSVs that match the video name

            indexlength = range(len(videofilelist))
            '''
            if hasCSVs == 1:
                if len(videofilelist) != len(csvfilelist) or len(videofilelist) != len(anclist):
                    print '#### ALERT: DETECTED NUMBER OF VIDEOS AND OTHER FILES DIFFERS ####'
                    time.sleep(5)
                    error = yes
            else:
            '''
            #Check Anc length
            if len(videofilelist) != len(anclist):
                print '#### ALERT: DETECTED NUMBER OF VIDEOS AND OTHER FILES DIFFERS FOR ' + dirSpec + ' ####'
                time.sleep(5)
                error = yes

            if len(videofilelist) != len(csvfilelist):
                print '## Warning: Number of CSV files detected ('+str(len(csvfilelist))+') differs from number of detected videos ('+str(len(videofilelist))+') for ' + dirSpec +' ##' #Either because of error or by design
                time.sleep(5)

        ##fullist = [x for x in zip(videofilelist, csvfilelist, indexlength)]
            #print videofilelist
            #print csvfilelist
            fullist = []
            fullist = [x for x in zip(videofilelist, csvfilelist, indexlength, dirlist,anclist)] #This carries the per-fly information

            megaList.append(fullist) #This is a nested list containing all the data
        else:
            print '## Folder ',dirSpec,' matches expName ("',expName,'") but contains no applicable data ##'
            time.sleep(1)

dirSpec = '' #Clear dirSpec

if len(megaList) == 0 or len(fullist) == 0:
    print '## Warning: No applicable data of type "', expName, '" found ##'
    time.sleep(5)
    error = yes

def multi_run_wrapper(args):
   return motion_detection(*args)
  
def motion_detection(videofile, csvfile, index, dirSpecAc, ancEr):
    #Disable these following three lines for function operation
    '''
    videofile = videofilelist[0]
    csvfile = csvfilelist[0]
    index = 0
    dirSpecAc = dirs[0]
    ancEr = anclist[0]
    '''
    print '[', dirSpecAc, ']'
    functext = "File #" +" :" + videofile
    
    try:

        if doStateLogging == 1:
            state = 0 #Commencement
            stateOg = open(logPath + 'stateLog.txt', 'a')
            print >> stateOg, videofile, ' - ', state, ' - ', time.ctime()
            stateOg.close()


        #Use moviepy to load the clip instead of opencv
        clip = VideoFileClip(videofile) 

        # initialize the first frame in the video stream
        refFrame = None
        cnt = 0
        
        #Read the box parameters from anc
        try:
            reader = csv.reader(open(ancEr,"rb")) #Reading the files (Might have to introduce queuing or similar for this?)
            a = 1
            for row in reader:
                    ##PANEL=row[0]
                ##print row
                if a == 1:
                    x = int(row[0])
                    ##boX = x #This is because x and y are reused down lower
                if a == 2:
                    y = int(row[0])
                    ##boY = y
                if a == 3:
                    height = int(row[0])
                if a == 4:
                    width = int(row[0])
                if a == 5:
                    identity = row[0]
                if a == 6:
                    hasCSVs = int(row[0])
                if a == 7:
                    threshold_value = int(row[0])
                a += 1
                    #Note: This is a precarious system, on the basis of no true row synchronicity checks
        except IOError:
                print '#### ALERT: ERROR IN IMPORTATION OF WINDOW PARAMETERS ####'
                time.sleep(5)
                error = yes
        #AncEr QA
        if str.find(ancEr,dirSpecAc) == -1:
            print '### ALERT: CRITICAL CROSS-READ ERROR IN ANC IMPORTATION ###'
            time.sleep(5)
            error = yes
        #Existence of Identity QA
        try: #Will fail if does not exist
            identity = identity
        except:
            identity = 'mov'
        #Existence of hasCSVs
        try: #Will fail if does not exist
            hasCSVs = hasCSVs
        except:
            hasCSVs = 1 #Default to yes
        #Existence of threshold_value
        try: #Will fail if does not exist
            threshold_value = threshold_value
        except:
            threshold_value = 20 #Default to legacy value

        #Clean identity if required
        identity = str.replace(identity, "'", "")

        if doStateLogging == 1:
            state = 1 #Successful anc read
            stateOg = open(logPath + 'stateLog.txt', 'a')
            print >> stateOg, videofile, ' - ', state, ' - ', time.ctime()
            stateOg.close()
        
        #Prepare save name
        baseFolderPathActive = overFolder+dirSpecAc #Critical to make a new one here, as basefolderpath is not updated per file

        if hasCSVs == 1:
            csvSaveName = csvfile.replace(baseFolderPathActive, '')
        else:
            csvSaveName = videofile.replace(baseFolderPathActive, '')
        csvSaveName = csvSaveName.replace('\\', '')
        csvSaveName = csvSaveName.replace(dataFormat,'')
        csvSaveName = (csvSaveName + "_" + identity + ".csv")
            

        if saveInDataFolder != 1: #Save in separate folder
            ##df.to_csv(savePath + dirSpec + "_" + csvfile[-7:-5] + "_" + identity + ".csv", encoding='utf-8', index=False)
            #print '\n-- Preparing to save data --'
            #print '\n' + savePath + csvfile[str.find(csvfile,dirSpecAc)+len(dirSpecAc)+len(subFolderName)+1:-5] + "_" + identity + ".csv"
            #time.sleep(5)
            #df.to_csv(savePath + csvfile[str.find(csvfile,dirSpecAc)+len(dirSpecAc)+len(subFolderName)+1:-5] + "_" + identity + ".csv", encoding='utf-8', index=False)
            savePathActive = savePath #Pull from the global variable
            #df.to_csv(savePath + csvSaveName, encoding='utf-8', index=False)
        else: #Save next to original file
            #df.to_csv(csvfile[0:-5] + "_" + identity + ".csv", encoding='utf-8', index=False)
            savePathActive = baseFolderPathActive + '\\' #Assemble in-house
        '''
        #Useful outputs for debugging
        print '\nvideofile', videofile
        print 'csvfile:', csvfile
        #print 'basefolderpath:', basefolderpath
        print 'baseFolderPathActive:', baseFolderPathActive
        '''

        if hasCSVs == 1:
            #store the data in a csv file as you go..
            #df = read_csv(csvfile, header=None)
            
            #Pre-load CSV to check header correctness and decide how to load data
            preDF = read_csv(csvfile)

            successFlotation = -1
            try: #If succeeds, column name was not true string
                temp = float(preDF.columns[0])
                successFlotation = 1 #Successful conversion from string to float
            except:
                successFlotation = 0 #Unsuccessful
            
            #Check for absence of header and adjust importation accordingly
            if successFlotation == 1:
                print '\n## Detected aberration in column headers: ##\n'
                print preDF.columns, '\n'
                
                df = read_csv(csvfile, header=None) #Borked or absent headers
                '''
                columnWipe = []
                for i in range(0,len(df.loc[0])):
                    columnWipe.append(0)  
                df.loc[-1] = columnWipe
                df.index = df.index + 1
                df.sort_index(inplace=True)
                '''
            else:
                df = read_csv(csvfile) #Normal file with headers
                    #Note: This if/else loop is experimental
            print '-- hasCSVs is true --'
            #print 'df type:', type(df)
        else:
            #Old system, makes empty dataframe
            '''
            df = pandas.DataFrame()
            #print '# # # # # # # # # # # # # # # # # # # # # # # #' 
            print '#### hasCSVs false; Making empty dataframe ####'
            #print '# # # # # # # # # # # # # # # # # # # # # # # #'
            '''
            #New system, makes dataframe of same size as number of video frames
            df = pandas.DataFrame(index=range(clip.reader.nframes-1))
            print '#### hasCSVs false; Making dataframe of video frame length '+str(clip.reader.nframes-1)+' ####'
            
        
        df['Movement'] = ''
        df['Delta'] = ''
        df['DeltaProp'] = ''
        df['x'] = ''
        df['y'] = ''
        df['height'] = ''
        df['width'] = ''
        df['numCntrs'] = ''
        df['avCntrSize'] = ''

        if hasCSVs == 1:
            length = int(len(df))
        else:
            length = clip.reader.nframes #May cause already-iterated problems for clip usage down below?

        pbar = tqdm(total = length)

        if doStateLogging == 1:
            state = 2 #Successful importation
            stateOg = open(logPath + 'stateLog.txt', 'a')
            print >> stateOg, videofile, ' - ', state, ' - ', time.ctime()
            stateOg.close()

        #pre-define so that appending will work nicely
        sendMovement = []
        sendDelta = []
        sendDeltaProp = [] #Raw pixel difference, summed and proportioned by framesize
        sendX = []
        sendY = []
        sendHeight = []
        sendWidth = []
        sendNumCntrs = []
        sendAvCntrSize = [] #May be susceptible to float issues
        #blarg = []
        
        for readFrame in clip.iter_frames():
                #Note: for iterator used to be 'frame' but this was changed to reduce overlap
            frame = cv2.cvtColor(readFrame, cv2.COLOR_BGR2RGB)
            orig_frame = frame

            #Just load a part of the main scene..
            #Note: Superceded by anc.txt files in vid folders (format should be same as here, minus var names)
            '''
            #Values optimised for foot/ball tracking subtraction analysis on lateral vids
            x = 368
            y = 176
            height = 124 #was 124
            width = 43 #was 43
            identity = 'mov'
            hasCSVs = 1

            #Values optimised for proboscis tracking
            x = 393
            y = 123
            height = 37 #was 124
            width = 34
            identity = 'prob'
            hasCSVs = 1
            
            #Values optimised for antennal tracking subtraction analysis on dorsal vids
            x = 488
            y = 209
            height = 137 #was 124
            width = 37
            identity = 'ant'
            hasCSVs = 1
            '''
            
            boX = x #This is because x and y are reused down lower
            boY = y
            
            frame = frame[y:y+height, x:x+width]

            #Use gray scale images for further processing..
            colordispframe = frame
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            text = "No mov"

            if refFrame is None:
                refFrame = gray # Ref frame is the first frame incase if this is the first frame
            
            # compute the absolute difference between the current frame and previous frame
            frameDelta = cv2.absdiff(refFrame, gray)
            dispframeDelta = colordispframe
            # Set every pixel that changed by 20 to 255, and all others to zero.
            ##threshold_value = 20 #was 20, then 5
            set_to_value = 255
            result = cv2.threshold(frameDelta, threshold_value, set_to_value, cv2.THRESH_BINARY)
            thresh = result[1] 

            # dilate the thresholded image to fill in holes, then find contours on thresholded image
            thresh = cv2.dilate(thresh, None, iterations=2)
            cnts = cv2.findContours(thresh.copy(), cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
            cnts = cnts[0] if imutils.is_cv2() else cnts[1]

            #For later reporting
            cntNum = 0 #Ticker for keeping track of number of contours
            cntrSizes = []
            
            # loop over the contours
            for c in cnts:
                if cv2.contourArea(c) < 75:
                    continue
                cntNum += 1
                cntrSizes.append(cv2.contourArea(c)) #May affect speed
                (rex, rey, rew, reh) = cv2.boundingRect(c)
                cv2.rectangle(dispframeDelta, (rex, rey), (rex + rew, rey + reh), (0, 255, 0), 2)
                text = "Moved"
            
            refFrame = gray # Ref frame is the last frame
            
            #(Disabled to increase speed (Hopefully))
            '''
            r_val = 0
            g_val = 255
            if text == "No mov":
                r_val = 255
                g_val = 0
           
            cv2.putText(dispframeDelta, 
                        "Status: {}".format(text), 
                        (10, dispframeDelta.shape[0] - 300),cv2.FONT_HERSHEY_COMPLEX, 
                        0.75, (0, g_val, r_val), 2)
           '''
            if display:
               cv2.imshow('Fly movement Detector:#' + str(index),dispframeDelta)
            if text == "No mov":
                sendMovement.append("Still")
            else:
                sendMovement.append("Moved")
            sendDelta.append(str(sum(sum(frameDelta))))#Raw pixel difference summed
            sendDeltaProp.append(sum(sum(frameDelta)) / float((height*width))) #Raw pixel difference, summed and proportioned by framesize
            sendX.append(str(boX))
            sendY.append(str(boY))
            sendHeight.append(str(height))
            sendWidth.append(str(width))
            sendNumCntrs.append(str(cntNum))
            if len(cntrSizes) != 0:
                sendAvCntrSize.append(str(sum(cntrSizes)/len(cntrSizes))) #May be susceptible to float issues
            else:
                sendAvCntrSize.append(str(0))
            #blarg.append([sendMovement,sendDelta,sendDeltaProp,sendX,sendY,sendHeight,sendWidth,sendNumCntrs,sendAvCntrSize])
            
            '''
            if text == "No mov":
                df.loc[cnt, 'Movement'] = "Still"
                #df.loc[cnt, 'Delta'] = str(sum(sum(frameDelta)))
            else:
                df.loc[cnt, 'Movement'] = "Moved"
                #df.loc[cnt, 'Delta'] = str(sum(sum(frameDelta)))
            df.loc[cnt, 'Delta'] = str(sum(sum(frameDelta)))#Raw pixel difference summed
            df.loc[cnt, 'DeltaProp'] = sum(sum(frameDelta)) / float((height*width)) #Raw pixel difference, summed and proportioned by framesize
            df.loc[cnt, 'x'] = str(boX)
            df.loc[cnt, 'y'] = str(boY)
            df.loc[cnt, 'height'] = str(height)
            df.loc[cnt, 'width'] = str(width)
            df.loc[cnt, 'numCntrs'] = str(cntNum)
            if len(cntrSizes) != 0:
                df.loc[cnt, 'avCntrSize'] = str(sum(cntrSizes)/len(cntrSizes)) #May be susceptible to float issues
            else:
                df.loc[cnt, 'avCntrSize'] = str(0)
            '''
            cnt = cnt +1 #Not to be confused with cntNum
            
            pbar.update(1) #Makes a progress bar

            cntrSizes = [] #Clear for speed
          
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
            if cnt == length:
                break
            '''
            if cnt >= 320:
                print '\n-- FILE TERMINATING EARLY AS REQUESTED --'
                time.sleep(1)
                break
            '''

        #Loop has ended, add data to df
        if doStateLogging == 1:
            state = 2.5 #Finish processing frames
            stateOg = open(logPath + 'stateLog.txt', 'a')
            print >> stateOg, videofile, ' - ', state, ' - ', time.ctime()
            stateOg.close()
        print '~~~~~~~~~~ Len senders: ', len(sendMovement), ' ~~~~~~~~~~~~~'
        print '$$$$$ Len df: ', len(df), ' $$$$$'
        df.loc[0:,'Movement'] = sendMovement
        df.loc[0:,'Delta'] = sendDelta
        df.loc[0:,'DeltaProp'] = sendDeltaProp
        df.loc[0:,'x'] = sendX
        df.loc[0:,'y'] = sendY
        df.loc[0:,'height'] = sendHeight
        df.loc[0:,'width'] = sendWidth
        df.loc[0:,'numCntrs'] = sendNumCntrs
        df.loc[0:,'avCntrSize'] = sendAvCntrSize
        

        if doStateLogging == 1:
            state = 3 #Finish processing frames
            stateOg = open(logPath + 'stateLog.txt', 'a')
            print >> stateOg, videofile, ' - ', state, ' - ', time.ctime()
            stateOg.close()

        '''    
        #Prepare save name
        csvSaveName = csvfile.replace(basefolderpath + '\\', '')
        csvSaveName = csvSaveName.replace(dataFormat,'')
        csvSaveName = (csvSaveName + "_" + identity + ".csv")
        '''

        #savePathActive code moved prior to processing to assist with exception catching

        print '\nsavePathActive:', savePathActive
        print 'csvSaveName:', csvSaveName
        time.sleep(1)
            
        df.to_csv(savePathActive + csvSaveName, encoding='utf-8', index=False)
        
        #Optimally, the CSV file that is output by either of these conditions should look something like:
        #          'C:\\Users\\labpc\\Desktop\\Matt\\Flytography\\OUTPUT\\fly2Lateral_13_12_18_01_mov.csv'
        #with the first 2/3 varying depending on whether data is chosen to be saved in the same folder as the source or not.  

        if doStateLogging == 1:
            successOg = open(logPath + 'successLog.txt', 'a')
            print >> successOg, videofile, ' - ', time.ctime()
            successOg.close()

        pbar.close()
        #cv2.waitKey(1)
        if display:
           cv2.destroyWindow('Fly movement Detector:#' + str(index))

        if doStateLogging == 1:
            state = 4 #Finish
            stateOg = open(logPath + 'stateLog.txt', 'a')
            print >> stateOg, videofile, ' - ', state, ' - ', time.ctime()
            stateOg.close()

        print '\n-- All analysis and saving successfully completed --\n'

    
    except:
        print '\n## CRITICAL ERROR DURING OPERATION; ATTEMPTING TO SAVE AND PROCEED ##'
        whyFailStr = str(sys.exc_info()[1]) #Should theoretically be the reason for the failure
        failOg = open(logPath + 'failureLog.txt', 'a')
        print >> failOg, videofile, ' - ', time.ctime(), ' - ', whyFailStr
        failOg.close()
        time.sleep(1)

        if str.find(whyFailStr,'[Errno 9]') == -1: 
            try:
                df.to_csv(savePathActive + csvSaveName, encoding='utf-8', index=False)
                #df.to_csv(baseFolderPathActive + '\\' + csvSaveName, encoding='utf-8', index=False)
                print '# Interim data saved #'
            except:
                print '\n## COULD NOT SAVE ##'
                time.sleep(1)
        else:
            print '# Not attempting to save data on account of non-pooled operation #'
          
    return functext

if __name__ == "__main__":
    '''
    pool = Pool(len(videofilelist))
    #results = pool.map(multi_run_wrapper,[(videofilelist[0],csvfilelist[0],0)])
    results = pool.map(multi_run_wrapper,fullist)
    '''
    prog = 1
    for fullist in megaList:
        print '\n------------------------------------------------------------------------------------------'
        print '-- Commencing analysis of directory ', prog, ' of ', len(megaList), ' --'
        print '(', dirs[prog-1], ')'
        #print '(', dirSpecAc, ')'
        #print(str(fullist))
        pool = Pool(len(fullist))
        results = pool.map(multi_run_wrapper,fullist)
        prog += 1
        
            

         

    







  
  
