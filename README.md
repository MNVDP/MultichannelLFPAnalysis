# MultichannelLFPAnalysis
Contains MATLAB and Python code for working with multichannel LFP data

-----------------------------------------------------------------------

1 - Stimuli are generated and sent, and behavioural videos recorded by scripts in the StimulusDeliveryAndRecording folder

2 - Behavioural videos are preprocessed and then processed by scripts in the Behavioural Processing folder

3 - LFP data is preprocessed and processed by scripts in the LFP Processing folder

-----------------------------------------------------------------------

Section 1 - Stimulus delivery and behavioural recording

1.1 - Webcam_labpc_Matt_2point75_XM_py36Branch.py is used in conjunction with a camera to begin acquisition of behavioural data from an individual
1.2 - Calibration_2point85_XM.m is used while TDT hardware is running in Preview or Record mode to send calibration stimuli
1.3 - Coloured_Oddball_03_Matt_10_XM.m, based on input parameters, generates an experiment's worth of stimuli and then delivers it while TDT hardware records
1.4 - Experiment and stimuli end automatically, behavioural video recording is terminated manually
1.5 - LFP data tanks are zipped and moved to network storage, videos are copied to network storage and a temporary staging area for preprocessing

Section 2 - Behavioural data preprocessing and processing

2.1 - From one of the video recordings, an example frame is saved as a snapshot, from which an ROI can be calculated in XY terms that encapsulates the legs of the fly, the values of which are entered into an ANC file
2.2 - Step 2.1 is repeated for proboscis and any other salient body features in fresh ANC files, which are placed in copied video recording folders (As in, the entire set of recordings are copied, with only the ANC different)
2.3 - motiondetection_thread_autoBranch_5.py operates across the valid folders and reads ANC files to detect motion in the videos
2.4 - Output CSVs from motion detection are copied to network
2.5 - DeepLabCut is run on videos to track requested body features
2.6 - Output CSVs from DLC are copied to network
2.7 - On analysis computer, SOFAS_14_XM.m reads both motion detection CSVs and DLC CSVs to generate a savOut file
2.8 - SASIFRAS_9_XM.m is pointed towards savout file/s and generates behavioural metrics and graphs of interest, along with an integOut file

Section 3 -


