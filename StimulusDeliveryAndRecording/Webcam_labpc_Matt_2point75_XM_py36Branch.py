#Mk 2 - Saving to folder, generic Matt improvements
#    .25 - Support for Firewire camera
#    .5 - Setting of camera depth
#    .75 - Manually imposed cropping

import cv2
from datetime import datetime
import time
import csv
import math
import numpy as np
import os

t = datetime.time(datetime.now())

#----------------------------------------------------------------------------

outputFolder = '/home/flylab/Python/data/WT/' #Python syntax asks for no prefolder slash
basefilename = "wt_spd_fly7_m"

useFrameForDims = 1 #Whether to derive dims from frame (1) or from cap (0)
  #This is because CAP can lie

# Create a VideoCapture object
idx = 0
  #Note: Currently hardconfigured for Firewire PGR camera operating at 1600x1200 - Y8 - 15Hz

#detectDepth = 1 #Whether to attempt to autodetect the depth at which image information is stored
  #Currently not implemented

capDepth = 1 #How many layers in the image data is
  #Note: Firewire RGB is depth 0, Firewire 1600x1200 Y8 15Hz is depth 1

cropInput = 1 #Whether to manually crop input
if cropInput == 1:
  cropPosition = [260,200] #Position of the top left corner
  cropSize = [640,480] #Crop box size

#----------------------------------------------------------------------------

cap = cv2.VideoCapture(idx)
#Note: add "+cv2.CAP_DSHOW" or CAP_FFMPEG or others if camera non-functional
Status = cap.isOpened()
#print idx

# Check if camera opened successfully
if (cap.isOpened() == False): 
  print("Unable to read camera feed")
 
ret, frame = cap.read() # This is just for the first frame to be ignored
'''
hardsetWidth = 480 #Because python
hardsetHeight = 640

frame = frame[0:hardsetWidth,0:hardsetHeight] #Will crash on too small vid
'''

print('Frame (Depth 0)')
print(type(frame))
try:
  print(np.size(frame,0))
  print(np.size(frame,1))
  print(np.size(frame,2))
except:
  print('Size report failure')
if capDepth >= 1:
  print('Frame (Depth 1)')
  print(type(frame[0]))
  try:
    print(np.size(frame[0],0))
    print(np.size(frame[0],1))
    print(np.size(frame[0],2))
  except:
    print('Size report failure')
if capDepth >= 2:
  print('Frame (Depth 2)')
  print(type(frame[0][0]))
  try:
    print(np.size(frame[0][0],0))
    print(np.size(frame[0][0],1))
    print(np.size(frame[0][0],2))
  except:
    print('Size report failure')

'''
#Experimental depth detection
depthLimit = False
thisFrameEval = 'frame'
x = 0
while depthLimit == False:
  #eval( print(type(frame)) )
  #print(type(frame[0][0])) 
  eval("print( type( thisFrameEval ) )", {"thisFrameEval": thisFrameEval})
  thisFrameEval = thisFrameEval + '[0]'
'''

'''
print(type(frame))
print(type(frame[0][0]))
try:
  print(np.size(frame,0))
  print(np.size(frame,1))
  print(np.size(frame,2))
except:
  print('Size report failure')
print('---')
'''

#Crop raw frame
if cropInput == 1:
  print('Frame Will be cropped to '+str( cropSize ))
  if capDepth == 1:
    frame = frame[0:cropSize[1],0:cropSize[0]]
  else:
    print('case not coded')
    crash = yes

fps = cap.get(cv2.CAP_PROP_FPS)

if useFrameForDims == 0:
  frame_width = int(math.floor(cap.get(3)/1))
  frame_height = int(math.floor(cap.get(4)/1))
else:
  frame_width = int( np.size(frame,1) )
  frame_height = int( np.size(frame,0) )  
###frame_width = int(hardsetWidth)
###frame_height = int(hardsetHeight)


print('\n','FPS:',str(fps))
print('W:',str(frame_width),', H:',str(frame_height))

font                   = cv2.FONT_HERSHEY_COMPLEX
bottomLeftCornerOfText_1 = (5,50)
bottomLeftCornerOfText_2 = (5,80)
bottomLeftCornerOfText_3 = (frame_width-250,50)
fontScale              = 0.75
fontColor              = (255,255,255)
lineType               = 2

#Make folder if not existing

if os.path.isdir(outputFolder) != True:
  os.makedirs(outputFolder)
  print('Folder made')

fourcc = cv2.VideoWriter_fourcc(*'MJPG')

# allow the camera to warmup,
ret, frame = cap.read() # This is just for the first frame to be ignored
time.sleep(1)

# Now loop and record the video for every 2 hours in a seperate file..
filecnt = 0

videofilerecstatus = 'Close'; # 'Close','Open', 
start_time = 0

# timeduration variable for starting a new video file..
timeout = 1*60*60   # [ in seconds]
expTimeout = 18*60*60
expStartTime = time.time()

quit_now = False
reportCount = 0

while(quit_now == False):
  frame = []
  ret, frame = cap.read()

  #Crop raw frame
  if cropInput == 1:
    #print('Frame Will be cropped to '+str( cropSize ))
    if capDepth == 1:
      #frame = frame[0:cropSize[1],0:cropSize[0]] #If this crashes, check your crop position and size to make sure it's not too big
      frame = frame[cropPosition[1]+0:cropPosition[1]+cropSize[1],cropPosition[0]+0:cropPosition[0]+cropSize[0]] #If this crashes, check your crop position and size to make sure it's not too big
    else:
      print('case not coded')
      crash = yes

  #time.sleep(2)
  #print(type(frame))

  ###frame = frame[0:hardsetWidth,0:hardsetHeight] #HARDCODED DEBUG CROPPING
 
  if ret == True: 
      
          if videofilerecstatus == 'Close':
              
             filecnt = filecnt + 1
              
             #out = cv2.VideoWriter(basefilename + '_' + str("%02d"%filecnt) + '_' + ".avi",fourcc,30.0,(frame_width,frame_height))
             out = cv2.VideoWriter(outputFolder + basefilename + '_' + str("%02d"%filecnt) + '_' + ".avi",fourcc,fps,(frame_width,frame_height))
             #out = cv2.VideoWriter("output.avi", fourcc, 15,(frame_width,frame_height))
         
             
             with open(outputFolder + basefilename + '_' + str("%02d"%filecnt) + '_' + '.csv', 'w') as file:
                 fieldnames = ['Year','Month','Date', 'Hour', 'Mins', 'Seconds','usec', 'nFrames']
                 writer = csv.DictWriter(file, fieldnames=fieldnames)
                 writer.writeheader()
              
             #Clear variables.. 
             nFrames = 0
             videofilerecstatus = 'Open' 
             
             #Start timer now..
             start_time = time.time()
 
    
          nFrames = nFrames + 1
          txtlen = int(round(len(str(abs(nFrames)))-4)*20)
          bottomLeftCornerOfText_3 = (frame_width-250-txtlen,50)
          t = datetime.now()
          cv2.putText(frame,str(t.date()), 
                      bottomLeftCornerOfText_1, 
                      font, 
                      fontScale,
                      fontColor,
                      lineType)
          cv2.putText(frame,str(t.time()), 
                      bottomLeftCornerOfText_2, 
                      font, 
                      fontScale,
                      fontColor,
                      lineType)
          cv2.putText(frame, 'Frames =' + str(nFrames), 
                      bottomLeftCornerOfText_3, 
                      font, 
                      fontScale,
                      fontColor,
                      lineType)
          # Write the frame into the file 'output.avi'
          if reportCount < 1:
            print('----')
            print('Pre-frame')
            #print(np.size(frame,2))
            print(type(frame))
            print(type(frame[0]))
            print(type(frame[0][0]))
            try:
              if idx == 0:
                print(type(frame[0][0][0]))
              print(np.size(frame,0))
              print(np.size(frame[0],0))
              if idx == 0:
                print(np.size(frame[0][0],0))
              #print(np.size(frame[0][0][0],0))
            except:
              print("Failure of depth")
            '''
            if idx != 0 or idx == 0:
              frame = np.expand_dims(frame,2)
              frameRep = np.repeat(frame,3,axis=2).astype('uint8')
            else:
              frameRep = frame
            '''
            if time.time() - start_time < 0.1:
              print('----')
              print('FrameRep')
              try:
                print(np.size(frame,2))
                print(type(frameRep))
                print(type(frame[0][0][0]))
              except:
                print("Failure of depth")
              try:
                print(np.size(frameRep,0))
                print(np.size(frameRep,1))
                print(np.size(frameRep,2))
              except:
                print('Size report failure')
              reportCount = reportCount + 1


          #Depth
          if capDepth == 0:
            frameRep = frame
          elif capDepth == 1:
            frame = np.expand_dims(frame,2)
            frameRep = np.repeat(frame,3,axis=2).astype('uint8')
          elif capDepth == 2:
            frame = np.expand_dims(frame[0],2)
            frameRep = np.repeat(frame,3,axis=2).astype('uint8')

          # Display the resulting frame
          #cv2.imshow('Flycam',frame)

          #out.write( np.repeat(frame,3,axis=2).astype('uint8') ) #REENABLE THIS
          out.write( frameRep )
          # out.write(np.random.randint(0, 255, (480,640,3)).astype('uint8'))
    
          filecsv = open(outputFolder + basefilename + '_' + str("%02d"%filecnt) + '_' + '.csv', 'a+') #writing to csv log file
          writer = csv.writer(filecsv)
          stuff = [t.year, t.month, t.day, t.hour, t.minute, t.second, t.microsecond, nFrames]
          writer.writerow(stuff)
          filecsv.close()
    
          # Display the resulting frame
          cv2.imshow('Flycam',frame) #Old position
          
          #check if time to open a new file..
          
          if time.time() > start_time + timeout:
              videofilerecstatus = 'Close' 
              out.release()
              print('Elapsed time reached')
              #quit_now = True

          #...or quit
          if time.time() > expStartTime + expTimeout:
              videofilerecstatus = 'Close' 
              out.release()
              print('Experiment duration reached')
              quit_now = True
              
          
          # Press Q on keyboard to stop recording
          if cv2.waitKey(1) & 0xFF == ord('q'):
             break
 
  # Break the loop
  else:
      break 
 
# When everything done, release the video capture and video write objects
cap.release()
out.release()

cv2.waitKey() 
# Closes all the frames
cv2.destroyAllWindows()
print('All processes finished')
