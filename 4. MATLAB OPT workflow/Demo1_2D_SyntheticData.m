% This program simulate OPT system errrors using a synthetic phantom image
% , correct COR using iRRpw and apply FBP reconstruction.
%
% Run the script and it will generate synthetic data and apply
% reconstructions. Results will be presented in the figure.
%
% Intermediate steps in the iRRpw algorithm are saved in the "save" folder in
% the local path by default.
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
close all;clear all;Config=InitOPT();
disp('Assumption 1: the capillary motion is simulated (only) in the vertical direction.');
disp('Assumption 2: depth of field covers the entire object, no blurring errors.');
disp('Note! For simulation, the horizontal direction is defined perpendicular to the image plane.');
%% Configurations
% 1. Included error types
errorTypes=[1 1 1]; % 1. constant shift 2. periodic shift 3. Random shift
%% Create a 'Phantom' image
AgnRes=1;
Ang=0:AgnRes:359;
phantomsize=512;
phantomMargin=20; % ! add some margins for synthetic errors
P = phantom(phantomsize);
RadonOutputSize=round(phantomsize*2^(0.5))+2*phantomMargin;
disp(['Synthetic phantom images contains :' num2str(length(Ang)) ' frames with resolution of ' num2str(AgnRes) ' degrees/frame.']);
%% Creating projection image from the Phantom image
RotateSample={};
for i=1:length(Ang)
    RotateSample{i}=imrotate(P,-Ang(i),'crop'); % ! The same rotation direction as in the experiment.
end
Projection_Static=zeros(RadonOutputSize,length(Ang));
for i=1:length(Ang)
    temp=imtranslate(RotateSample{i},[0.5 0]);
    temp=imtranslate(temp,[-0.5 0]);% ! This redundant process is to
    % include the interpolation errors from the function 'imtranslate'
    % in the comparison between original phantom and other
    % phantom images.
    Projection_Static(:,i)=radon(temp,0,RadonOutputSize);
end
I_static = iradon(Projection_Static,Ang,phantomsize); % Ground truth
%% Add synthetic errors
shiftPixelsX=10; % in the verfical direction
shiftPixelsY=0;  % in the horizontal direction
% Type I
if(errorTypes(1)==1)
    CoRConstantX=shiftPixelsX; % X -> Verfical shift
    CoRConstantY=shiftPixelsY; % Y -> Horizontal shift
end
disp(['Synthetic Constant error: ' num2str(CoRConstantX) ' pixels in vertical direction.']);
% Type II (Periodic)
if(errorTypes(2)==1)
    CapAmpX=shiftPixelsX/2; % X -> Verfical shift
    CapAmpY=shiftPixelsY/2; % Y -> Horizontal shift
    Rotations=Ang;
    thitaX=75;
    thitaY=120;
    MotionPeriodicX=CapAmpX*sin(2*pi/360*(Rotations+thitaX));
    MotionPeriodicY=CapAmpY*sin(2*pi/360*(Rotations+thitaY));
else
    MotionPeriodicX=zeros(size(Ang));
    MotionPeriodicY=zeros(size(Ang));
end
if(errorTypes(2)==1)
    disp(['Synthetic periodic error amp: ' num2str(CapAmpX) ' pixels, ' num2str(thitaX) ' degrees phase shift in vertical direction.']);
    disp(['Synthetic periodic error amp: ' num2str(CapAmpY) ' pixels, ' num2str(thitaY) ' degrees phase shift in horizontal direction.']);
end
% Type II (Random)
if(errorTypes(3)==1)
    NoiseAmpX=shiftPixelsX/2;
    NoiseAmpY=shiftPixelsY/2;
    MotionRandX=NoiseAmpX*(2*(rand(length(Ang),1)-0.5));
    MotionRandY=NoiseAmpY*(2*(rand(length(Ang),1)-0.5));
else
    MotionRandX=zeros(size(Ang));
    MotionRandY=zeros(size(Ang));
end
if(errorTypes(3)==1)
    disp(['Synthetic rand motion error amp: ' num2str(NoiseAmpX) ' pixels in vertical direction.']);
    disp(['Synthetic rand motion error amp: ' num2str(NoiseAmpY) ' pixels in horizontal direction.']);
end
% Add all COR errors
fprintf('Creating synthetic data...');
OPTErrorALL=zeros(RadonOutputSize,360);
ObjCORError=zeros(RadonOutputSize,360);
ObjPeriodicError=zeros(RadonOutputSize,360);
ObjRandError=zeros(RadonOutputSize,360);
for i=1:length(Ang)
    temp=imtranslate(RotateSample{i},[CoRConstantX CoRConstantY]);
    ObjCORError(:,i)=radon(temp,0,RadonOutputSize);
    temp=imtranslate(RotateSample{i},[MotionPeriodicX(i) MotionPeriodicY(i)]);
    ObjPeriodicError(:,i)=radon(temp,0,RadonOutputSize);
    temp=imtranslate(RotateSample{i},[MotionRandX(i) MotionRandY(i)]);
    ObjRandError(:,i)=radon(temp,0,RadonOutputSize);
    temp=imtranslate(RotateSample{i},[MotionPeriodicX(i)+MotionRandX(i)+CoRConstantX MotionPeriodicY(i)+MotionRandY(i)+CoRConstantY]);
    OPTErrorALL(:,i)=radon(temp,0,RadonOutputSize);
end
% FBP projection
I_ObjCORError = iradon(ObjCORError,Ang,phantomsize);
I_ObjPeriodicError = iradon(ObjPeriodicError,Ang,phantomsize);
I_MotionError  = iradon(OPTErrorALL,Ang,phantomsize);
I_ObjRandError  = iradon(ObjRandError,Ang,phantomsize);
disp('Done! ');
%% Reconstruct synthetic phantom
fprintf('Recovering the 2D phantom...')
[I_Corrected,SinePair]=gCOR_iRRpw2D(OPTErrorALL,Ang,phantomsize,RadonOutputSize,Config,I_static);
disp('Done! ');
%% Analysis
I_RecPair = iradon(SinePair,Ang,phantomsize);
% total variance 2d
tvP=totalvariance2d(I_static);
tvCORRECT=totalvariance2d(I_Corrected);
tvER=totalvariance2d(I_MotionError);
% total variance 
tvP2=var(I_static(:));
tvCORRECT2=var(I_Corrected(:));
tvER2=var(I_MotionError(:));
% Plot results
figure('name','final results comparison')
subplot(3,2,1)
imshow(OPTErrorALL)
title('Sinogram with added noise')
subplot(3,2,2)
imshow(I_MotionError)
title(['Phantom with Motion Errors : ' num2str(tvER,'%3.3e')  '  , ' num2str(tvER2,'%3.3e') ])
subplot(3,2,3)
imshow(SinePair)
title('Sinogram Corrected')
subplot(3,2,4)
imshow(I_Corrected)
title(['Phantom with Motion Correction : ' num2str(tvCORRECT,'%3.3e') '  , ' num2str(tvCORRECT2,'%3.3e') ])
subplot(3,2,5)
imshowpair(Projection_Static,SinePair)
title('Comparison to original phantom')
subplot(3,2,6)
imshowpair(I_static,I_Corrected)
title(['Phantom : ' num2str(tvP,'%3.3e') '  , ' num2str(tvP2,'%3.3e')  ])