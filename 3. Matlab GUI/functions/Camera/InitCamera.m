function [vid,vidInfo]=InitCamera()
%% Find .dll of Spinnaker adaptor in MATLAB.
defaultAddress='functions\Image\mwspinnakerimaq.dll';
if isfile(defaultAddress)
    DriverPath=strcat(pwd,'\',defaultAddress); 
else
     [fileName,pathName]=uigetfile({'*.dll','DLL files(*.dll)';'*.*','ALL Files(*.*)'},'Select a camera adaptor file (.dll)');
     DriverPath=[pathName fileName];   
end
%% Register camera adaptor to MATLAB
try
    imDevices=imaqhwinfo;
    driverName='mwspinnakerimaq';
    driverValid=0;
    for i=1:length(imDevices.InstalledAdaptors)
        if(strcmp(imDevices.InstalledAdaptors{i},driverName))
            driverValid=1;
            break;
        end
    end
    if(driverValid==0)
        imaqregister(DriverPath)
        vidInfo = imaqhwinfo(driverName);
    else
        vidInfo = imaqhwinfo(driverName);
    end

    %% Create a video input object.
    vid = videoinput(vidInfo.AdaptorName,1); 
    disp(['AdaptorName: '  vid.AdaptorName]);
catch
    disp('Camera drivers mwspinnakerimaq is missing, using default settings.');
    imDevices=imaqhwinfo;
     for i=1:length(imDevices.InstalledAdaptors)
           vidInfo = imaqhwinfo(imDevices.InstalledAdaptors{i});
           vid = videoinput(vidInfo.AdaptorName,1);
           disp(['AdaptorName: '  vidInfo.AdaptorName]);
           break;
     end
end
