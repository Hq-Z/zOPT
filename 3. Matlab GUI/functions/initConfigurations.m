function [ConfigMotor,ConfigCamera,ConfigImage]=initConfigurations()
% GUI for zOPT
%
%%-------------------------------------------------------------------------
% Please refer to our paper for more details:
%
% "zOPT: an open source Optical Projection Tomography system and methods for
% rapid 3D zebrafish imaging"
% HANQING ZHANG,LAURA WALDMANN,REMY MANUEL,TATJANA HAITINA,AND AMIN ALLALOU
% 
% Authors information:
%   hanqing.zhang@it.uu.se
%   amin.allalou@it.uu.se
%
% Copyright 2020,  1. BioImage Informatics Facility at SciLifeLab,Sweden
%                  2. Division of Visual information and interaction, 
%                     Department of Information Technology, Uppsala university,Sweden
%
% License: The program is distributed under the terms of the GNU General 
% Public License v3.0
% Contact: Version 1.0 - first release, 20200207, zhanghq0088@gmail.com
% Website: https://github.com/Hq-Z/zOPT
%%-------------------------------------------------------------------------
ConfigMotor.CtrlOn=0;
ConfigMotor.CtlSteps=1600;
ConfigMotor.CtlMode=32;
ConfigMotor.CtlStepDegree=360*ConfigMotor.CtlSteps/200/ConfigMotor.CtlMode;

ConfigMotor.steps=40000; % 200 full steps per rotation
ConfigMotor.stepMode=128; % Full step = 1, half step (1/2) = 2, microsteps (1/4,1/8...) = 4, 8,...
ConfigMotor.stepTime=273; % microseconds
ConfigMotor.numRevolution=ConfigMotor.steps/200/ConfigMotor.stepMode;
ConfigMotor.timePerRevolution=ConfigMotor.steps*ConfigMotor.stepTime/1000000/ConfigMotor.numRevolution;

ConfigCamera.recordFrameTotal=400; % Maximum buffer stream count 3063*1024*1024/1280/1040/3= 804 frames
ConfigCamera.frameRateRecording=52;
ConfigCamera.frameRateDisplay=30;
ConfigCamera.frameResolution=[1280 1040];
ConfigCamera.EstDegreesPerImage=360/(ConfigMotor.timePerRevolution*ConfigCamera.frameRateRecording);
ConfigCamera.EstScanPercent=100*ConfigCamera.recordFrameTotal/ConfigCamera.frameRateRecording/ConfigMotor.timePerRevolution;
ConfigCamera.tTimeOut=60;  % 60 seconds for GETDATA before timed out

ConfigCamera.Preview=1; % activate preview 1
ConfigCamera.PreviewChannel=0; % activate preview 1
ConfigCamera.HighResRecording=1;
ConfigCamera.videoRecordingName='vid_';

ConfigImage.ROI=[];
ConfigImage.Image=[];