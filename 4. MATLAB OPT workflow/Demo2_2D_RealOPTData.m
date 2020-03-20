% This is a demo of iRRpw algorithm to correct COR errors and reconstruct 
% 2D tomography data.
%
% The 2D tomography need to be pre-selected first by setting the "Slice"
% parameter in the code.
%
% Run the script, load input data by selecting an OPT video with full rotation,
% then the algorithm automatically attenuates intensities (optional),
% find 360 degrees rotation, apply the COR analysis and reconstruction
% the results and present in a figure.
%
% Intermediate steps in the iRRpw algorithm are saved in the "save" folder in
% the local path by default.
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
close all;clear all;Config=InitOPT();
disp('Assumption 1, the cetner of rotation is in the horizontal direction of video frame.');
disp('Assumption 2, depth of field covers almost the entire object, abberation and distortion from optics are minimized.');
disp('Note! This algorithm apply translation to correct COR error for each slice.');
%% Select channel and column number in video
disp('Note! The slice number for reconstruction is related to the column of the video');
Ch=2; % Select from color channel (RGB): R-1, G-2, B-3.
Slice=300; % Select single slice for reconstruction.
disp(['Sampled from the slice ' num2str(Slice) ' in channel '  num2str(Ch)]);
%% For brightfield OPT data
Config.Preprocess.BrightField=1;   % Only attenuation is applied for brighfield OPT data
Config.Preprocess.BrightFieldBG=0; % Apply background detection and intensity attenuation
%% Load from video data
[filename, pathname] = uigetfile( ...
    {'*.avi;*.mpg;*.mpeg;*.wmv;*.mp4;*.mj2;*.mov;',...
    'Load Media Files (*.avi,*.mpg,*.mpeg,*.wmv,*.mp4,*.mj2,*.mov;)';
    '*.*',  'All Files (*.*)'}, ...
    'Select a media file');
obj.fullpath=[pathname filename];
[obj.path, obj.name,obj.extension] = fileparts(obj.fullpath);
readerobj = VideoReader(obj.fullpath);
obj.data = read(readerobj);
if(isa(obj.data,'uint8'))
    a=1/255;
    obj.data = single(permute(obj.data(:,:,Ch,:),[1 2 4 3]))*a;
    fprintf( 'uint8 converted to single precision');
elseif(isa(obj.data,'uint16'))
    a=1/65535;
    obj.data = single(permute(obj.data(:,:,Ch,:),[1 2 4 3]))*a;
    fprintf( 'uint16 converted to single precision');
else
    %obj.data = single(obj.data);
    obj.data = single(permute(obj.data(:,:,Ch,:),[1 2 4 3]));
    fprintf( 'double truncated to single precision');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Preprocessing
if(Config.Preprocess.BrightField==1)
    if(Config.Preprocess.BrightFieldBG==1)
        bG=getOPTbG(obj.data(:,:,:,1),Config.bG.nSample);
        bG=bG/max(bG(:));
        InvbG=1./(bG+eps);
        for i=1:size(obj.data,3)
            obj.data(:,:,i,1)=obj.data(:,:,i,1).*InvbG;
        end
    end
    obj.data(:,:,:,1)=ImageAttenuation(obj.data(:,:,:,1));
    fh=figure(1);
    if(Config.Preprocess.BrightFieldBG==1)
        imshow(cat(1,bG,obj.data(:,:,1,1)));
    else
        imshow(obj.data(:,:,1,1));
    end
    pause(1);
    disp('Intensity attenuated.')
else
    fh=figure(1);
    imshow(obj.data(:,:,1,1));
    pause(1);
    disp('No pre-processing')
end
disp(['Data contains ' num2str(size(obj.data,2)) ' slices.']);
pause(2)
close(fh)
disp('Finding 360 degrees rotation...');
[obj.data,totalFrames,Ang]=getOPT360(obj.data(:,:,:,1),Config.find360);
ObjMotionError = permute(obj.data(:,Slice,:),[1 3 2 4]);
AgnRes=Ang(end)/totalFrames;
HalfAng=length(Ang)/2;
Ang=(1:size(ObjMotionError,2))*AgnRes-AgnRes;
phantomsize=size(ObjMotionError,1);
RadonOutputSize=phantomsize;
disp(['Test images contains :' num2str(length(Ang)) ' frames with resolution of ' num2str(AgnRes) ' degrees/frame.']);
ObjMotionError= 100*ObjMotionError; % !! Rescale intensity for presentation
I_MotionError = iradon(ObjMotionError,Ang,phantomsize);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% COR correction and Reconstruction
disp('................................................................');
disp(['Recovering the 2D phantom.'])
[I_MotionCorrected,dataPairM]=gCOR_iRRpw2D(double(ObjMotionError),Ang,phantomsize,RadonOutputSize,Config,double(I_MotionError));
%% Analysis
% Total variance
tvCORRECT=totalvariance2d(I_MotionCorrected);
tvER_3=totalvariance2d(I_MotionError);
tvCORRECT2=var(I_MotionCorrected(:));
tvER2_3=var(I_MotionError(:));
% Plot
figure('name','final results comparison')
subplot(2,2,1)
imshow(ObjMotionError/255)
title('Sinogram of test video slice')
subplot(2,2,2)
imshow(I_MotionError)
title(['Phantom with Motion Errors : ' num2str(tvER_3,'%3.3e')  '  , ' num2str(tvER2_3,'%3.3e') ])
subplot(2,2,3)
imshow(dataPairM/255)
title('Sinogram Corrected')
subplot(2,2,4)
imshow(I_MotionCorrected)
title(['Phantom with Motion Correction : ' num2str(tvCORRECT,'%3.3e') '  , ' num2str(tvCORRECT2,'%3.3e') ])