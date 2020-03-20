% This is a demo of iRRpw algorithm to correct COR errors and reconstruct 
% 3D tomography data.
%
% Run the script, load input data by selecting an OPT video with full rotation,
% set the region-of-interest in a pop-up window, comfirm the selection by a
% double-click, then the algorithm automatically attenuates intensities (optional),
% find 360 degrees rotation, apply the COR analysis and reconstruction
% the results in .vtk format under the folder "save" in the local path.
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
%
% Debug: 1. CUDA_ERROR_LAUNCH_FAILED appears when the data size is too big,
% try to load the data with scale less than 1 and use ROI to select a
% smaller region.
%
%%-------------------------------------------------------------------------
close all;clear all;Config=InitOPT();
disp('Assumption 1, the cetner of rotation (COR) is in the horizontal direction of video frame.');
disp('Assumption 2, depth of field covers almost the entire object, abberation and distortion from optics are minimized.');
disp('Note! This algorithm apply rigid transform (translation,rotation) to correct COR error.');
%% Configurations
Config.RegCOR.Iteration=1;          % ! Iterations for 3D analysis. 
Config.Preprocess.BrightField=1;    % Only attenuation is applied for brighfield OPT data
Config.Preprocess.BrightFieldBG=1;  % Apply background detection and intensity attenuation
Config.Preprocess.SCALE=1;          % Scale factor for image size (optional)
Config.Preprocess.Ch=2;             % Select from color channel (RGB): R-1, G-2, B-3.
Slice=100;                          % Select single slice (see the following).
Config.Debug.CheckSlice=round(Slice*Config.Preprocess.SCALE); % Slice used in checking capilary rotation direction
%% Input
[filename, pathname] = uigetfile( ...
    {'*.tif;*.avi;*.mpg;*.mpeg;*.wmv;*.mp4;*.mj2;*.mov;',...
    'Load Media Files (*.tif,*.avi,*.mpg,*.mpeg,*.wmv,*.mp4,*.mj2,*.mov;)';
    '*.*',  'All Files (*.*)'}, ...
    'Select a media file');
obj.fullpath=[pathname filename];
[obj.path, obj.name,obj.extension] = fileparts(obj.fullpath);
if(strcmp(obj.extension,'.tif'))
    info = imfinfo(obj.fullpath);
    for i=1:length(info)
        obj.data(:,:,i)=imread(obj.fullpath,i);
    end
else
    readerobj = VideoReader(obj.fullpath);
    obj.data = read(readerobj);
end
if(isa(obj.data,'uint8'))
    a=1/255;
    disp( 'uint8 converted to single precision.');
elseif(isa(obj.data,'uint16'))
    a=1/65535;
    disp( 'uint16 converted to single precision.');
else
    obj.data = single(obj.data);
    disp( 'double truncated to single precision.');
end
if(strcmp(obj.extension,'.tif'))
    obj.data = single(obj.data(:,:,Config.Preprocess.Ch,:))*a;
else
    obj.data = single(permute(obj.data(:,:,Config.Preprocess.Ch,:),[1 2 4 3]))*a;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Preprocessing
% Select channel and 2D resize
if(ndims(obj.data)==3)
    Config.Preprocess.Ch=1;
end
if(Config.Preprocess.SCALE~=1)
    for i=1:size(obj.data,3)
        data(:,:,i) = imresize(obj.data(:,:,i,Config.Preprocess.Ch), Config.Preprocess.SCALE);
    end
else
    data=obj.data(:,:,:,Config.Preprocess.Ch);
end
disp(['Test image rescaled factor: ' num2str(Config.Preprocess.SCALE) ' .']);
%% Select ROI
fh=figure(1);
imshow(double(data(:,:,1,1))/double(max(max(data(:,:,1,1)))));
% Update Region-of-interest
ROI=selectROI(data,Config.ROI,gca);
data = data (ROI(2):ROI(2)+ROI(4),ROI(1):ROI(1)+ROI(3),:,:);
close(fh);
disp(['Test image in region of interest: [ ' num2str(ROI) ' ].']);
%% Preprocessing (brightfield OPT)
if(Config.Preprocess.BrightField==1)
    if(Config.Preprocess.BrightFieldBG==1)
        bG=getOPTbG(data,Config.bG.nSample);
        bG=bG/max(bG(:));
        InvbG=1./(bG+eps);
        for i=1:size(data,3)
            data(:,:,i)=data(:,:,i).*InvbG;
        end
    end
    data=ImageAttenuation(data);
    fh=figure(1);
    if(Config.Preprocess.BrightFieldBG==1)
        imshow(cat(1,bG,data(:,:,1)));
    else
        imshow(data(:,:,1));
    end
    pause(1);
    disp('Intensity normalized.')
else
    fh=figure(1);
    imshow(data(:,:,1));
    pause(1);
    disp('No pre-processing')
end
pause(2)
close(fh);
%% Find 360 degrees
% Pre-align data using gCOR method (Optional)
% [~,data]=gCOR(data,Config.RegCOR,0);
% Find frames and angle interval for a full 360 degrees rotation
[data,totalFrames,Ang]=getOPT360(data,Config.find360);
AgnRes=Ang(end)/totalFrames;
HalfAng=length(Ang)/2;
disp(['Test images contains : ' num2str(length(Ang)) ' frames with resolution of ' num2str(AgnRes) ' degrees/frame.']);
disp(['Video frames are scaled : ' num2str(Config.Preprocess.SCALE), ' Frame size are ' num2str(size(data,1)),' X ', num2str(size(data,2)),' .']);
disp(['Checking frames at column : ' num2str(round(Config.Debug.CheckSlice/Config.Preprocess.SCALE)) ', channel '  num2str(Config.Preprocess.Ch) ' in the original image.'])
% Update COR correction parameters
Config.RegCOR.AngValid=1; %!
Config.RegCOR.Ang=Ang; % !
%% COR correction and Reconstruction
disp('..................................................................');
% two-steps method (gCOR+iRRpw)
%[I_MotionCorrected3D, ~]=gCOR(data,Config.RegCOR,1);
[I_MotionCorrected3D, ~]=gCOR_iRRpw_GPU(data,Config.RegCOR,Config.Debug);
%% Write data
% Save with nomalized intensity, uint8 format, resized(optional)
Resize=1; % 0.5 for reducing the resolution by half
writeVTKRGB(uint8(255*ImageNorm(imresize3(I_MotionCorrected3D,Resize))),strcat(Config.savePath,obj.name,'_iRRpw.vtk'), 1);
