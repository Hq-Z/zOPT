function [Iout,sinoiRRpw]=gCOR_iRRpw_GPU(sinoI,Config,Debug)
% This function is a demonstration of iRRpw algorithm to correct COR errors
% and reconstruct tomography data using FBP method. This function requires 
% CUDA decives for parallel computing.
% Important: This implementation is verified using MATLAB R2018b (academic use)
%
% Inputs: sinoI - A 3D sinogram (n*m*i) containing n pixels in vertical 
%                 direction and m pixels in horizontal direction, i frames. 
%
%                 IMPORTANT: The rotation axis is along the horizontal axis.
%
%         Config - Configurations for this function.see InitOPT for more
%         details
%
%         Debug - Parameters for debug and plotting.
%
% Outputs: Iout - FBP results (3D) after COR correction
%       
%          sinoiRRpw - (n*m*i) data after COR correction
%
%--------------------------------------------------------------------------
% Please cite our paper:
% "zOPT: an open source Optical Projection Tomography system and methods for
% rapid 3D zebrafish imaging"
% HANQING ZHANG,LAURA WALDMANN,REMY MANUEL,TATJANA HAITINA,AND AMIN ALLALOU
%
% Copyright 2020,  1. BioImage Informatics Facility at SciLifeLab,Sweden
%                  2. Division of Visual information and interaction, 
%                     Department of Information Technology, Uppsala university,Sweden
%
% License: The program is distributed under the terms of the GNU General 
% Public License v3.0
% Contact: zhanghq0088@gmail.com
% Website: https://github.com/Hq-Z/zOPT
%--------------------------------------------------------------------------
disp('IRec: Pairwise correction, translation in y axis only');
if(isGpuAvailable)
    GPUspec=gpuDevice(1);
    disp(['Using GPU ' GPUspec.Name ' for reconstruction.'])
else
    error('Cannot find CUDADevices.')
end
try
    if(isempty(gcp('nocreate')))
        parpool;
        disp('Using parallel computing with parpool.');
    else
        disp('parallel pool is active.');
    end
catch
    delete(gcp('nocreate'))
    error('Cannot use parallel computing.Try again!')
end
% Debug and analysis
CheckSlice=Debug.CheckSlice;
% Configurations
MarginR = Config.Margin;
FillValue = Config.FillValue;
options   = Config.OptSetOptions;
[DataWidth,ColSlices,FullRev,ColorChannel]=size(sinoI);
% Check input data
if(ColorChannel~=1)
    sinoI=sinoI(:,:,:,Config.DefaultChannel);
    disp(['gCOR_iRRpw_GPU: Select channel ', num2str(Config.DefaultChannel) ' by default.']);
end
if(Config.AngValid==1)
    Ang=Config.Ang;
    halfPeriod = floor(length(Ang)/2); 
    FullPeriod=2*halfPeriod; % ! force to even number
else
    AgnRes=360/FullRev;
    Ang=(1:FullRev)*AgnRes-AgnRes;
    halfPeriod=length(Ang)/2;
    FullPeriod=2*halfPeriod; % ! force to even number
end
disp(['gCOR_iRRpw_GPU: Test images contains : ' num2str(length(Ang)) ' frames with resolution of ' num2str(Ang(2)) ' degrees/frame.']);
%% gCOR
tStart = tic;
MIP=sum(sinoI,3);
testIm=MIP;
x0 = [0 0 0]; % Init values
X = fminsearch(@(x)GipY3D(x,FillValue,testIm,MarginR),x0);
scale = [10000 10000 10000]/2;
Global_RHV = X.*scale;
sinoGip = single(zeros(size(sinoI)));
parfor i=1:FullRev
    Global_input=Global_RHV;
    sinoGip(:,:,i) = imtranslate(imrotate(sinoI(:,:,i),Global_input(1),'crop'),[Global_input(2), Global_input(3)],'FillValues',FillValue);
end
  tElapsed = toc(tStart);
  disp(['gCOR: ' num2str(tElapsed) ' s']);
%% iRRpw
scale = 10000;
for j=1:Config.Iteration
    disp(['iRRpw iteration : ' num2str(j)]); 
    if(j==1)
        sinoLoop= single(sinoGip);
    end
    %% Reconstructions 
    tStart = tic;
    resizeF=0.6;
    stepsF=1/resizeF;
    checkodd=mod(DataWidth,2);
    CenterWidth=(DataWidth+1)/2;
    HalfSampleNum=round(ceil(CenterWidth-1)*resizeF);
    gpuArraySlice=gpuArray(permute(sinoLoop(:,1,:),[1 3 2]));
    [XqC,YqC]=meshgrid(1:1:size(gpuArraySlice,2),CenterWidth-stepsF*HalfSampleNum:stepsF:CenterWidth+stepsF*HalfSampleNum); % always odd number of rows
    tmp = interp2(gpuArraySlice,XqC,YqC,'linear');
    tmp(isnan(tmp))=0;
    SliceWidth=size(tmp,1);
    tmp = iradon(tmp,Ang,SliceWidth);
    % Maskout artifects
    %IMask=MaskOPT(tmp,Config.Margin);
    %tmp(IMask)=0;
    TempCenter=(size(XqC,1)+1)/2;
    if(checkodd==1)
        TempSamples=floor((DataWidth)/2);
        checklist=TempCenter-resizeF*TempSamples:resizeF:TempCenter+resizeF*TempSamples;
    else
        TempSamples=floor((DataWidth)/2);
        checklist=TempCenter+resizeF/2-resizeF*TempSamples:resizeF:TempCenter+resizeF*TempSamples-resizeF/2;
    end
    [XqC2,YqC2]=meshgrid(checklist,checklist);
    ReconstructedData = interp2(tmp,XqC2,YqC2,'cubic');
    ReconstructedData(isnan(ReconstructedData))=0;
    Reconstructed_all=single(zeros(DataWidth,DataWidth,ColSlices));
    Reconstructed_all(:,:,1)=gather(ReconstructedData);
    for i=2:ColSlices
        gpuArraySlice=gpuArray(permute(sinoLoop(:,i,:),[1 3 2]));
        tmp = interp2(gpuArraySlice,XqC,YqC,'linear');
        tmp(isnan(tmp))=0;
        tmp = iradon(tmp,Ang,SliceWidth);
        %tmp(IMask)=0;
        tmp = interp2(tmp,XqC2,YqC2,'linear');
        tmp(isnan(tmp))=0;
        Reconstructed_all(:,:,i) =gather(tmp);
    end
    tElapsed = toc(tStart);
    disp(['iradon: ' num2str(tElapsed) ' s']);
    %% check rotation direction
    tStart = tic;
    if(j==1)
        [RecAng,~,~]=CheckRotationDirection(Reconstructed_all(:,:,CheckSlice),squeeze(sinoI(:,CheckSlice,:)),Ang);
    end
    tElapsed = toc(tStart);
    disp(['check rotation: ' num2str(tElapsed) ' s']);
    %% Projections 
    tStart = tic;
    sinoProjections = OPT_FPAstra3D(Reconstructed_all,RecAng/360*2*pi,DataWidth);
    tElapsed = toc(tStart);
    disp(['radon: ' num2str(tElapsed) ' s']);
    %% iRec
    sinoRec=single(zeros(size(sinoI)));
    tStart = tic;
    parfor i=1:FullPeriod
        Global_input=Global_RHV;
        testIm1 = gpuArray(sinoGip(:,:,i));
        refIm1 = gpuArray(sinoProjections(:,:,i));
        x0 = [0 0 0];
        X = fminsearch(@(x)iReg3D(x,refIm1,testIm1,MarginR),x0,options);
        localV = X*scale;
        
        tmp =imrotate(gpuArray(sinoI(:,:,i)),localV(1)+Global_input(1),'crop');
        [XqC,YqC]=meshgrid(1+localV(2)+Global_input(2):1:size(tmp,2)+localV(2)+Global_input(2),Global_input(3)+1+localV(3):1:Global_input(3)+size(tmp,1)+localV(3));
        tmp = interp2(tmp,XqC,YqC,'linear');
        tmp(isnan(tmp))=0;
        sinoRec(:,:,i)=gather(tmp);    
    end
    tElapsed = toc(tStart);
    disp(['Registration: ' num2str(tElapsed) ' s']);
    %% 
    tStart = tic;
    sinoRecSecond=sinoRec(:,:,halfPeriod+1:end);
    sinoRecPairFirst=single(zeros(size(sinoI,1),size(sinoI,2),halfPeriod));
    sinoRecPairSecond=single(zeros(size(sinoI,1),size(sinoI,2),halfPeriod));
    parfor i=1:halfPeriod
        refIm  = gpuArray(sinoRec(:,:,i));
        testIm = gpuArray(sinoRecSecond(:,:,i)); 
        x = 0; % Init values
        X = fminsearch(@(x)PairWise3D(x,refIm,testIm,MarginR),x,options);
        localV    = X*scale/2;
        
        [XqC,YqC]=meshgrid(1:1:size(refIm,2),1+localV:1:size(refIm,1)+localV);
        tmp = interp2(refIm,XqC,YqC,'linear');
        tmp(isnan(tmp))=0;
        sinoRecPairFirst(:,:,i)=gather(tmp);
        tmp2 = interp2(testIm,XqC,YqC,'linear');
        tmp2(isnan(tmp2))=0;
        sinoRecPairSecond(:,:,i)=gather(tmp2);   
    end
    tElapsed = toc(tStart);
    disp(['Pairwise: ' num2str(tElapsed) ' s']);
    sinoiRRpw=cat(3,sinoRecPairFirst,sinoRecPairSecond);
    sinoLoop=sinoiRRpw;
end
%% CLEAR memory
clear sinoGip sinoRec sinoRecSecond sinoRecPairFirst sinoRecPairSecond sinoLoop
%%
tStart = tic;
disp('Reconstruction: FBP method');
Iout=single(zeros(size(sinoiRRpw,1),size(sinoiRRpw,1),size(sinoiRRpw,2)));
for i=1:ColSlices
    gpuArraySlice=gpuArray(permute(sinoiRRpw(:,i,:),[1 3 2]));
    Iout(:,:,i) = gather(iradon(gpuArraySlice,Ang,DataWidth));
end
Iout(Iout<0)=0;
% Maskout artifects
IMask=MaskOPT(Iout(:,:,1),Config.Margin);
Iout(repmat(IMask,[1 1 ColSlices]))=0;
tElapsed = toc(tStart);
disp(['Reconstruction: ' num2str(tElapsed) ' s']);
end

function fval  = GipY3D(x,FillValue,testIm,MarginR)
scale = 10000;
x=x*scale;
I_mirror = imrotate(testIm,x(1),'bilinear','crop');
I_mirror = imtranslate(I_mirror,[x(2), x(3)],'FillValues',FillValue);
I_mirror = flip(I_mirror,1);
fval=1-corr2(testIm(MarginR:end-MarginR,MarginR:end-MarginR),I_mirror(MarginR:end-MarginR,MarginR:end-MarginR));
end

function fval  = PairWise3D(x,refIm,testIm,MarginR)
scale = 10000;
x=x.*scale;
[Xq,Yq]=meshgrid(1:1:size(refIm,2),1+x(1):1:size(refIm,1)+x(1));
I_180 = interp2(testIm,Xq,Yq,'linear');
I_180(isnan(I_180))=0;
I_180 = flip(I_180,1);
fval=gather(-corr2(refIm(MarginR:end-MarginR,MarginR:end-MarginR),I_180(MarginR:end-MarginR,MarginR:end-MarginR)));
end

function fval  = iReg3D(x,refIm,testIm,MarginR)
scale = 10000;
x=x.*scale;
testIm = imrotate(testIm,x(1),'bilinear','crop');
[Xq,Yq]=meshgrid(1+x(2):1:size(refIm,2)+x(2),1+x(3):1:size(refIm,1)+x(3));
I_shift = interp2(testIm,Xq,Yq,'linear');
I_shift(isnan(I_shift))=0;
fval=gather(-corr2(refIm(MarginR:end-MarginR,MarginR:end-MarginR),I_shift(MarginR:end-MarginR,MarginR:end-MarginR)));
end

