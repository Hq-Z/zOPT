function varargout =GUIOPT(varargin)
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
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUIOPT_OpeningFcn, ...
    'gui_OutputFcn',  @GUIOPT_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
%% Startup
function GUIOPT_OpeningFcn(hObject, eventdata, handles, varargin)
%% Load path
handles.output = hObject;
if(~isdeployed)
   cPath=mfilename('fullpath');
   [GUIpath,~]=fileparts(cPath);
   lPath_f='functions';
   lPath_f=strcat(GUIpath,'\',lPath_f);
   if~exist((lPath_f),'dir')
      mkdir(lPath_f); 
   end
   addpath(genpath(lPath_f));
end
%% Configurations
global motorConfig
[motorConfig, handles.cameraConfig, handles.imageConfig]=initConfigurations;
%% Contorl of motor
handles=UpdatemotorConfig(handles);
handles=UpdateCtrlConfig(handles);
global s
serialComp=seriallist; % list of serial ports available
serialValid=0;
for i=1:length(serialComp)
    s = serial(serialComp{i});
    set(s,'BaudRate',9600);
    try
        fclose(s)
        fopen(s);
        pause(1);
        if(checkUnoController(s)==1)
           serialValid=1;
           break; 
        end
    catch
        flushinput(s)
        fclose(s);
        disp('Cannot find serial commiunication to Adruino...')
    end
end
%% Control of Camera
handles=UpdateCamConfig(handles);
% Initiate Camera driver
imaqreset
[handles.vidController,~]=InitCamera();
% Customized parameters
set(handles.vidController,'FramesPerTrigger',1);
set(handles.vidController,'TriggerRepeat',Inf);
% Image size
vidRes=get(handles.vidController,'VideoResolution');
nBands = handles.vidController.NumberOfBands;
% Clean memory
flushdata(handles.vidController);
% Start connection
start(handles.vidController);
% Create Axes in Fig
set(handles.figure1,'Name','Controller');
fC = handles.figure1.Children;
fCDefaultAxes = findobj(fC,'Type','Axes');
if(~isempty(fCDefaultAxes))
    delete(fCDefaultAxes);
end
handles.axFigure = axes(handles.figure1,'Position',[0.21 0.21 0.75 0.75],'Box','on');
set(handles.axFigure ,'xticklabel',[]);
set(handles.axFigure ,'yticklabel',[]);
handles.previewIm = image(zeros(vidRes(2),vidRes(1),nBands), 'Parent', handles.axFigure);
previewFLIR(handles.vidController, handles.previewIm,handles.cameraConfig.PreviewChannel);
%Data saving
handles=updateFileSave(handles);
if(serialValid==1)
    Command(s,'m128');
    set(handles.figure1,'windowscrollWheelFcn', {@scrollfunc,handles});
else
    disp('No valid serical port are found.');
end
% Update handles structure
guidata(hObject, handles);
function varargout = GUIOPT_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;
% CloseGUI
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global s
global motorConfig
try
    % Motor obj
fclose(s)
    % Camera obj
closepreview(handles.vidController)
delete(handles.vidController)
clear handles.vidController;
catch
   disp('Cannot close camera object') 
end
delete(hObject);
%% Processes
function scrollfunc(hObject, eventdata, handles) % Motor 
global s
global motorConfig

if(motorConfig.CtrlOn==0)
    Command(s,strcat('f',num2str(200))); % delay time for pulse is 200 by default
    Command(s,strcat('m',num2str(motorConfig.CtlMode)));
    motorConfig.CtrlOn=1;
end

if eventdata.VerticalScrollCount==1
    CommandFast(s,strcat('tr',num2str(motorConfig.CtlSteps)));
else
    CommandFast(s,strcat('tl',num2str(motorConfig.CtlSteps)));
end
if(handles.cameraConfig.Preview==0)
    pause(0.5);
    handles=updateAlignment(handles);
    % Update handles structure
    guidata(hObject, handles);
end 
function buttonPauseMotor_Callback(hObject, eventdata, handles)
global s
Command(s,'p');
handles=disableRotation(handles);
guidata(hObject, handles);
pause(1)
function buttonundoPause_Callback(hObject, eventdata, handles)
global s
Command(s,'w');
pause(1)
handles=enableRotation(handles);
guidata(hObject, handles);
%% Check rotation
function buttonFullRotation_Callback(hObject, eventdata, handles)
global s
global motorConfig
motorConfig.CtrlOn=0;

if(handles.cameraConfig.Preview==0)
    handles.cameraConfig.Preview=1;
    handles=UpdateCtrlConfig(handles);
    guidata(hObject, handles);
end

Command(s,strcat('f',num2str(motorConfig.stepTime)));
Command(s,strcat('m',num2str(motorConfig.stepMode)));
Command(s,strcat('s',num2str(motorConfig.steps)));
function buttonFullRotationFastSpin_Callback(hObject, eventdata, handles)
global s
global motorConfig
motorConfig.CtrlOn=0;
Command(s,'f100');
Command(s,'m1');
CommandFast(s,'v25600');
checkUnoController(s);
%% Recording
function buttonFullRotationRecordVideo_Callback(hObject, eventdata, handles)
global s
global motorConfig
motorConfig.CtrlOn=0;
Command(s,strcat('f',num2str(motorConfig.stepTime)));
Command(s,strcat('m',num2str(motorConfig.stepMode)));
% debug
%Command(s,'f500');
%Command(s,'m128');

closepreview(handles.vidController);
disp('Preview is closed for recording');
disp('Start recording');
num_frames=handles.cameraConfig.recordFrameTotal;
% Clean memory
flushdata(handles.vidController);
while(isrunning(handles.vidController))
    stop(handles.vidController);
    pause(1);
end
% Start connection
set(handles.vidController,'Timeout',handles.cameraConfig.tTimeOut); % 60 seconds for GETDATA before timed out
set(handles.vidController,'TriggerRepeat',num_frames);
set(handles.vidController,'FramesPerTrigger',num_frames);
start(handles.vidController);
pause(1); % release memory
%
disp('Rotating...');
flushdata(handles.vidController);
CommandNoResponds(s,strcat('s',num2str(motorConfig.steps)));
pause(motorConfig.stepTime/1000); % wait for 100 substeps;
[data1,time1] = getdata(handles.vidController,num_frames);
kk=length(time1);
disp(kk);% check total frames
mkdir(handles.FilePath.String);
if(handles.cameraConfig.HighResRecording==1)
    aviobj = VideoWriter([handles.FilePath.String,handles.cameraConfig.videoRecordingName],'Uncompressed AVI');
else
    aviobj = VideoWriter([handles.FilePath.String,handles.cameraConfig.videoRecordingName],'Motion JPEG AVI');
    aviobj.Quality = 40;
end
aviobj.FrameRate = handles.cameraConfig.frameRateRecording;  % Default 30
open(aviobj);
disp('Saving data...');
pause(1); % release memory
for i=1:kk
    if(~isempty(handles.imageConfig.ROI))
        F=imcrop(data1(:,:,:,i),handles.imageConfig.ROI);
    else
        F=data1(:,:,:,i);
    end
    writeVideo(aviobj,F);
end
avgFrameRate=1/mean(diff(time1));
handles.cameraConfig.frameRateRecording=avgFrameRate;
disp(['FPS:' num2str(1/mean(diff(time1)))]);
close(aviobj);
while(islogging(handles.vidController))
    stop(handles.vidController);
    disp('Completed.');
end
checkUnoController(s);
% Clean memory
flushdata(handles.vidController);
% Return to preview mode
handles=UpdateCamConfig(handles);
set(handles.vidController,'TriggerRepeat',Inf);
previewFLIR(handles.vidController, handles.previewIm,handles.cameraConfig.PreviewChannel); 
% 
MaximumIP=max(permute(max(data1(:))-data1(:,:,1,:),[1 2 4 3]),[],3);
figure('Name','Maximum Intensity Projection (Calibration check)');imshow(max(MaximumIP(:))-MaximumIP); %! Check rotation for system calibration
guidata(hObject, handles);

%% Update GUI
function handles=UpdatemotorConfig(handles)
global motorConfig
set(handles.EditMotorSteps,'String',num2str(motorConfig.steps,'%5.0f'));
set(handles.EditMotorMode,'String',num2str(motorConfig.stepMode,'%5.0f'));
set(handles.EditMotorTimeIntv,'String',num2str(motorConfig.stepTime,'%10.0f'));
motorConfig.numRevolution=motorConfig.steps/200/motorConfig.stepMode;
motorConfig.timePerRevolution=motorConfig.steps*motorConfig.stepTime/1000000/motorConfig.numRevolution;
set(handles.EditMotorRevTime,'String',num2str(motorConfig.timePerRevolution,'%5.2f'));
set(handles.EditMotorRevNum,'String',num2str(motorConfig.numRevolution,'%5.2f'));
function handles=UpdateCtrlConfig(handles)
global motorConfig
set(handles.EditCtrlSteps,'String',num2str(motorConfig.CtlSteps,'%5.0f'));
set(handles.EditCtrlStepsMode,'String',num2str(motorConfig.CtlMode,'%5.0f'));
motorConfig.CtlStepDegree=360*motorConfig.CtlSteps/200/motorConfig.CtlMode;
set(handles.EditCtrlStepsInDegree,'String',num2str(motorConfig.CtlStepDegree,'%5.2f'));
if(handles.cameraConfig.Preview==1)
    set(handles.CheckPreview,'Value',1);
    set(handles.CheckShowAlignment,'Value',0);
else
    set(handles.CheckPreview,'Value',0);
    set(handles.CheckShowAlignment,'Value',1);
end
if(handles.cameraConfig.HighResRecording==1)
    set(handles.HighResolution,'Value',1);
else
    set(handles.HighResolution,'Value',0);
end
function handles=UpdateCamConfig(handles)
global motorConfig
set(handles.EditFrames2Record,'String',num2str(handles.cameraConfig.recordFrameTotal,'%5.0f'));
set(handles.EditframeRateRecording,'String',num2str(handles.cameraConfig.frameRateRecording,'%3.2f'));
set(handles.EditframeRateDisplay,'String',num2str(handles.cameraConfig.frameRateDisplay,'%5.0f'));
%set(handles.XX,'String',handles.cameraConfig.frameResolution,'%5.0f');
handles.cameraConfig.EstDegreesPerImage=360/(motorConfig.timePerRevolution*handles.cameraConfig.frameRateRecording);
handles.cameraConfig.EstScanPercent=100*handles.cameraConfig.recordFrameTotal/handles.cameraConfig.frameRateRecording/motorConfig.timePerRevolution;
set(handles.EditEstDegreesPerImage,'String',num2str(handles.cameraConfig.EstDegreesPerImage,'%3.3f'));
set(handles.EditSamplingPercentage,'String',num2str(handles.cameraConfig.EstScanPercent,'%3.3f'));
% 
function handles=disableRotation(handles)
set(handles.buttonFullRotation,'Enable','off');
set(handles.buttonFullRotationRecordVideo,'Enable','off');
set(handles.buttonFullRotationFastSpin,'Enable','off');
set(handles.buttonPauseMotor,'Enable','off');
function handles=enableRotation(handles)
set(handles.buttonFullRotation,'Enable','on');
set(handles.buttonFullRotationRecordVideo,'Enable','on');
set(handles.buttonFullRotationFastSpin,'Enable','on');
set(handles.buttonPauseMotor,'Enable','on');
set(handles.buttonundoPause,'Enable','on');
%% Configurations for motor and video recording
function EditMotorSteps_Callback(hObject, eventdata, handles)
global motorConfig
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(motorConfig.steps));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(motorConfig.steps));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber<=32767000) % 32767 dependent on Andrino
    motorConfig.steps=round(vNumber);
    set(hObject,'String',num2str(motorConfig.steps,'%5.0f'));
end
handles=UpdatemotorConfig(handles);
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditMotorSteps_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditMotorMode_Callback(hObject, eventdata, handles)
global motorConfig
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(motorConfig.stepMode));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(motorConfig.stepMode));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber< 512)
    motorConfig.stepMode=2^(floor(log2(vNumber)));
    set(hObject,'String',num2str(motorConfig.stepMode,'%5.0f'));
end
handles=UpdatemotorConfig(handles);
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditMotorMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditMotorTimeIntv_Callback(hObject, eventdata, handles)
global motorConfig
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(motorConfig.stepTime));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(motorConfig.stepTime));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber<= 1000000)
    motorConfig.stepTime=round(vNumber);
    set(hObject,'String',num2str(motorConfig.stepTime,'%5.0f'));
end
handles=UpdatemotorConfig(handles);
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditMotorTimeIntv_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditMotorRevTime_Callback(hObject, eventdata, handles)
handles=UpdatemotorConfig(handles);
guidata(hObject, handles);
function EditMotorRevTime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditMotorRevNum_Callback(hObject, eventdata, handles)
handles=UpdatemotorConfig(handles);
guidata(hObject, handles);
function EditMotorRevNum_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditFrames2Record_Callback(hObject, eventdata, handles)
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(handles.cameraConfig.recordFrameTotal));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(handles.cameraConfig.recordFrameTotal));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber< 99999)
    handles.cameraConfig.recordFrameTotal=vNumber;
    set(hObject,'String',num2str(handles.cameraConfig.recordFrameTotal,'%5.0f'));
end
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditFrames2Record_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditframeRateRecording_Callback(hObject, eventdata, handles)
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditframeRateRecording_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditEstDegreesPerImage_Callback(hObject, eventdata, handles)
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditEstDegreesPerImage_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditframeRateDisplay_Callback(hObject, eventdata, handles)
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(handles.cameraConfig.frameRateDisplay));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(handles.cameraConfig.frameRateDisplay));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber<= 1000)
    handles.cameraConfig.frameRateDisplay=round(vNumber);
    set(hObject,'String',num2str(handles.cameraConfig.frameRateDisplay,'%5.0f'));
end
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditframeRateDisplay_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditSamplingPercentage_Callback(hObject, eventdata, handles)
handles=UpdateCamConfig(handles);
guidata(hObject, handles);
function EditSamplingPercentage_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%% Preview and control parameters
function EditCtrlSteps_Callback(hObject, eventdata, handles)
global motorConfig
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(motorConfig.CtlSteps));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(motorConfig.CtlSteps));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber<= 50000)
    motorConfig.CtlSteps=round(vNumber);
    set(hObject,'String',num2str(motorConfig.CtlSteps,'%5.0f'));
end
handles=UpdateCtrlConfig(handles);
guidata(hObject, handles);
function EditCtrlSteps_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditCtrlStepsMode_Callback(hObject, eventdata, handles)
global motorConfig
Numstring=get(hObject,'String');
if(isempty(Numstring))
    set(hObject,'String',num2str(motorConfig.CtlMode));
    guidata(hObject, handles);
    return
end
[vNumber, status] = str2num(Numstring);
if(status==0)
    set(hObject,'String',num2str(motorConfig.CtlMode));
    guidata(hObject, handles);
    return
end
if(vNumber>0 && vNumber< 512)
    motorConfig.CtlMode=2^(floor(log2(vNumber)));
    set(hObject,'String',num2str(motorConfig.CtlMode,'%5.0f'));
end
handles=UpdateCtrlConfig(handles);
guidata(hObject, handles);
function EditCtrlStepsMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function EditCtrlStepsInDegree_Callback(hObject, eventdata, handles)
handles=UpdateCtrlConfig(handles);
guidata(hObject, handles);
function EditCtrlStepsInDegree_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% Update Preview and alignment
function handles=updateAlignment(handles)
set(handles.figure1,'windowscrollWheelFcn', {@scrollfunc,handles});
set(handles.vidController,'ReturnedColorSpace', 'RGB');
im = getsnapshot(handles.vidController); 
if(~isempty(handles.imageConfig.ROI))
    im=imcrop(im,handles.imageConfig.ROI);
end
hold(handles.axFigure,'off');
handles.previewIm = image(im, 'Parent', handles.axFigure);

function handles=updatePreview(handles)
% Update preview of the captured frame from Camera
set(handles.figure1,'windowscrollWheelFcn', {@scrollfunc,handles});
set(handles.vidController,'ReturnedColorSpace', 'RGB');
im = getsnapshot(handles.vidController); 
hold(handles.axFigure,'off');
handles.previewIm = image(im, 'Parent', handles.axFigure);
previewFLIR(handles.vidController, handles.previewIm,handles.cameraConfig.PreviewChannel); 

function CheckPreview_Callback(hObject, eventdata, handles)
% hObject    handle to CheckPreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
value=get(hObject,'Value');
if(value==1)
    handles.cameraConfig.Preview=1;
    handles=updatePreview(handles);
end
guidata(hObject, handles);
function CheckShowAlignment_Callback(hObject, eventdata, handles)
% hObject    handle to CheckShowAlignment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
value=get(hObject,'Value');
if(value==1)
     handles.cameraConfig.Preview=0;
     handles=updateAlignment(handles);
end
guidata(hObject, handles);
%% Data save
function handles=updateFileSave(handles)
set(handles.EditFileName,'String',handles.cameraConfig.videoRecordingName);
set(handles.FilePath,'String',[pwd,'\data\']);
function EditFileName_Callback(hObject, eventdata, handles)
FileName=get(hObject,'String');
if(isempty(FileName))
    set(hObject,'String',num2str(handles.cameraConfig.videoRecordingName));
    guidata(hObject, handles);
    return
end
handles.cameraConfig.videoRecordingName=FileName;
handles=updateFileSave(handles);
guidata(hObject, handles);
function EditFileName_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% screenshot
function Snapshot_Callback(hObject, eventdata, handles)
set(handles.vidController,'ReturnedColorSpace', 'RGB');
im = getsnapshot(handles.vidController); 
imwrite(im,[handles.cameraConfig.videoRecordingName datestr(now,'yy-mm-dd-HH-MM-SS','local') '.tiff'],'TIFF','WriteMode','overwrite');
function FilePath_Callback(hObject, eventdata, handles)
function FilePath_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% save as uncompressed avi format
function HighResolution_Callback(hObject, eventdata, handles)
% hObject    handle to HighResolution (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
value=get(hObject,'Value');
if(value==1)
     handles.cameraConfig.HighResRecording=1;
else
     handles.cameraConfig.HighResRecording=0;
end
guidata(hObject, handles);
%% ROI
function ROI_Callback(hObject, eventdata, handles)
 im = getsnapshot(handles.vidController); 
 fh=figure(1);
 imshow(im);
 if(isempty(handles.imageConfig.ROI))
    handles.imageConfig.ROI=[1 1 size(im,2) size(im,1)];
 end
 imrecth = imrect(fh.CurrentAxes,handles.imageConfig.ROI);
 addNewPositionCallback(imrecth,@(p) title(mat2str(p,3)));
 fcn = makeConstrainToRectFcn('imrect',get(gca,'XLim'),get(gca,'YLim'));
 setPositionConstraintFcn(imrecth,fcn);
 handles.imageConfig.ROI = wait(imrecth);
 close(fh);
 guidata(hObject, handles);
 set(handles.SHOWROI,'String',num2str(handles.imageConfig.ROI(3:4),'%4.0f'));
